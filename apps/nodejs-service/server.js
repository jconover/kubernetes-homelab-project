const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const redis = require('redis');
const { Pool } = require('pg');
const amqp = require('amqplib');
const client = require('prom-client');
const winston = require('winston');
require('dotenv').config();

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'app.log' })
  ]
});

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(express.json());

// Database connection
const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'postgresql',
  port: process.env.POSTGRES_PORT || 5432,
  database: process.env.POSTGRES_DB || 'homelab',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'postgres123',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Redis connection
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || 'redis',
  port: process.env.REDIS_PORT || 6379,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      logger.error('Redis server connection refused');
      return new Error('Redis server connection refused');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      logger.error('Redis retry time exhausted');
      return new Error('Retry time exhausted');
    }
    if (options.attempt > 10) {
      logger.error('Redis max retry attempts reached');
      return undefined;
    }
    return Math.min(options.attempt * 100, 3000);
  }
});

redisClient.on('error', (err) => {
  logger.error('Redis Client Error:', err);
});

redisClient.on('connect', () => {
  logger.info('Connected to Redis');
});

// RabbitMQ connection
let rabbitmqConnection = null;
let rabbitmqChannel = null;

async function connectRabbitMQ() {
  try {
    rabbitmqConnection = await amqp.connect({
      hostname: process.env.RABBITMQ_HOST || 'rabbitmq',
      port: process.env.RABBITMQ_PORT || 5672,
      username: process.env.RABBITMQ_USER || 'admin',
      password: process.env.RABBITMQ_PASSWORD || 'admin123',
      vhost: process.env.RABBITMQ_VHOST || '/'
    });
    
    rabbitmqChannel = await rabbitmqConnection.createChannel();
    logger.info('Connected to RabbitMQ');
  } catch (error) {
    logger.error('Failed to connect to RabbitMQ:', error);
  }
}

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Kubernetes Homelab Node.js Service',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    services: {
      postgresql: 'disconnected',
      redis: 'disconnected',
      rabbitmq: 'disconnected'
    }
  };

  // Check PostgreSQL
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    health.services.postgresql = 'connected';
  } catch (error) {
    logger.error('PostgreSQL health check failed:', error);
  }

  // Check Redis
  try {
    await redisClient.ping();
    health.services.redis = 'connected';
  } catch (error) {
    logger.error('Redis health check failed:', error);
  }

  // Check RabbitMQ
  if (rabbitmqConnection && rabbitmqChannel) {
    health.services.rabbitmq = 'connected';
  }

  res.json(health);
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/api/tasks', async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT * FROM tasks ORDER BY created_at DESC LIMIT 10');
    client.release();
    res.json({ tasks: result.rows });
  } catch (error) {
    logger.error('Failed to get tasks:', error);
    res.status(500).json({ error: 'Failed to get tasks' });
  }
});

app.post('/api/tasks', async (req, res) => {
  const { title, description, priority = 'medium' } = req.body;
  
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }

  try {
    const client = await pool.connect();
    const result = await client.query(
      'INSERT INTO tasks (title, description, priority, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [title, description, priority, 'pending']
    );
    client.release();
    
    // Cache the result
    await redisClient.setex(`task:${result.rows[0].id}`, 3600, JSON.stringify(result.rows[0]));
    
    res.status(201).json({ task: result.rows[0] });
  } catch (error) {
    logger.error('Failed to create task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

app.get('/api/cache/:key', async (req, res) => {
  try {
    const value = await redisClient.get(req.params.key);
    if (!value) {
      return res.status(404).json({ error: 'Key not found' });
    }
    res.json({ key: req.params.key, value: JSON.parse(value) });
  } catch (error) {
    logger.error('Failed to get cache value:', error);
    res.status(500).json({ error: 'Failed to get cache value' });
  }
});

app.post('/api/cache/:key', async (req, res) => {
  try {
    await redisClient.setex(req.params.key, 3600, JSON.stringify(req.body));
    res.json({ key: req.params.key, value: req.body, status: 'set' });
  } catch (error) {
    logger.error('Failed to set cache value:', error);
    res.status(500).json({ error: 'Failed to set cache value' });
  }
});

app.post('/api/messages', async (req, res) => {
  const { message, queue = 'default' } = req.body;
  
  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

  if (!rabbitmqChannel) {
    return res.status(503).json({ error: 'RabbitMQ service unavailable' });
  }

  try {
    await rabbitmqChannel.assertQueue(queue, { durable: true });
    
    const messageData = {
      id: `msg_${Date.now()}`,
      message,
      queue,
      timestamp: new Date().toISOString()
    };

    await rabbitmqChannel.sendToQueue(queue, Buffer.from(JSON.stringify(messageData)), {
      persistent: true
    });

    res.json({ message: 'Message sent successfully', data: messageData });
  } catch (error) {
    logger.error('Failed to send message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  if (rabbitmqConnection) {
    await rabbitmqConnection.close();
  }
  
  redisClient.quit();
  await pool.end();
  
  process.exit(0);
});

// Start server
async function startServer() {
  try {
    await redisClient.connect();
    await connectRabbitMQ();
    
    app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Node.js service running on port ${PORT}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

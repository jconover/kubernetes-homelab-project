from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime
import os
import redis
import psycopg2
from psycopg2.extras import RealDictCursor
import pika
import json
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

app = FastAPI(
    title="Kubernetes Homelab API",
    description="Python FastAPI backend for Kubernetes homelab",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connections
def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=os.getenv("POSTGRES_HOST", "postgresql"),
            port=os.getenv("POSTGRES_PORT", "5432"),
            database=os.getenv("POSTGRES_DB", "homelab"),
            user=os.getenv("POSTGRES_USER", "postgres"),
            password=os.getenv("POSTGRES_PASSWORD", "postgres123"),
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        return None

def get_redis_connection():
    try:
        r = redis.Redis(
            host=os.getenv("REDIS_HOST", "redis"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            decode_responses=True
        )
        r.ping()
        return r
    except Exception as e:
        logger.error(f"Redis connection error: {e}")
        return None

def get_rabbitmq_connection():
    try:
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(
                host=os.getenv("RABBITMQ_HOST", "rabbitmq"),
                port=int(os.getenv("RABBITMQ_PORT", "5672")),
                virtual_host=os.getenv("RABBITMQ_VHOST", "/"),
                credentials=pika.PlainCredentials(
                    os.getenv("RABBITMQ_USER", "admin"),
                    os.getenv("RABBITMQ_PASSWORD", "admin123")
                )
            )
        )
        return connection
    except Exception as e:
        logger.error(f"RabbitMQ connection error: {e}")
        return None

# Pydantic models
class HealthResponse(BaseModel):
    status: str
    message: str
    timestamp: str
    version: str
    services: dict

class MessageRequest(BaseModel):
    message: str
    priority: str = "normal"

class MessageResponse(BaseModel):
    id: str
    message: str
    status: str
    timestamp: str

# Routes
@app.get("/")
async def root():
    REQUEST_COUNT.labels(method="GET", endpoint="/").inc()
    return {"message": "Kubernetes Homelab API", "version": "1.0.0"}

@app.get("/health", response_model=HealthResponse)
async def health_check():
    REQUEST_COUNT.labels(method="GET", endpoint="/health").inc()
    
    services = {
        "postgresql": "disconnected",
        "redis": "disconnected",
        "rabbitmq": "disconnected"
    }
    
    # Check PostgreSQL
    db_conn = get_db_connection()
    if db_conn:
        try:
            with db_conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                services["postgresql"] = "connected"
            db_conn.close()
        except Exception as e:
            logger.error(f"PostgreSQL health check failed: {e}")
    
    # Check Redis
    redis_conn = get_redis_connection()
    if redis_conn:
        try:
            redis_conn.ping()
            services["redis"] = "connected"
        except Exception as e:
            logger.error(f"Redis health check failed: {e}")
    
    # Check RabbitMQ
    rabbitmq_conn = get_rabbitmq_connection()
    if rabbitmq_conn:
        try:
            rabbitmq_conn.close()
            services["rabbitmq"] = "connected"
        except Exception as e:
            logger.error(f"RabbitMQ health check failed: {e}")
    
    return HealthResponse(
        status="healthy",
        message="API is running",
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0",
        services=services
    )

@app.get("/metrics")
async def metrics():
    REQUEST_COUNT.labels(method="GET", endpoint="/metrics").inc()
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/messages", response_model=MessageResponse)
async def send_message(message_request: MessageRequest):
    REQUEST_COUNT.labels(method="POST", endpoint="/messages").inc()
    
    rabbitmq_conn = get_rabbitmq_connection()
    if not rabbitmq_conn:
        raise HTTPException(status_code=503, detail="RabbitMQ service unavailable")
    
    try:
        channel = rabbitmq_conn.channel()
        queue_name = f"messages_{message_request.priority}"
        
        # Declare queue
        channel.queue_declare(queue=queue_name, durable=True)
        
        # Publish message
        message_id = f"msg_{datetime.utcnow().timestamp()}"
        message_body = {
            "id": message_id,
            "message": message_request.message,
            "priority": message_request.priority,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        channel.basic_publish(
            exchange="",
            routing_key=queue_name,
            body=json.dumps(message_body),
            properties=pika.BasicProperties(delivery_mode=2)  # Make message persistent
        )
        
        channel.close()
        rabbitmq_conn.close()
        
        return MessageResponse(
            id=message_id,
            message=message_request.message,
            status="sent",
            timestamp=datetime.utcnow().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Failed to send message: {e}")
        raise HTTPException(status_code=500, detail="Failed to send message")

@app.get("/cache/{key}")
async def get_cache(key: str):
    REQUEST_COUNT.labels(method="GET", endpoint="/cache").inc()
    
    redis_conn = get_redis_connection()
    if not redis_conn:
        raise HTTPException(status_code=503, detail="Redis service unavailable")
    
    try:
        value = redis_conn.get(key)
        if value is None:
            raise HTTPException(status_code=404, detail="Key not found")
        return {"key": key, "value": value}
    except Exception as e:
        logger.error(f"Failed to get cache value: {e}")
        raise HTTPException(status_code=500, detail="Failed to get cache value")

@app.post("/cache/{key}")
async def set_cache(key: str, value: str):
    REQUEST_COUNT.labels(method="POST", endpoint="/cache").inc()
    
    redis_conn = get_redis_connection()
    if not redis_conn:
        raise HTTPException(status_code=503, detail="Redis service unavailable")
    
    try:
        redis_conn.set(key, value, ex=3600)  # Expire in 1 hour
        return {"key": key, "value": value, "status": "set"}
    except Exception as e:
        logger.error(f"Failed to set cache value: {e}")
        raise HTTPException(status_code=500, detail="Failed to set cache value")

@app.get("/database/users")
async def get_users():
    REQUEST_COUNT.labels(method="GET", endpoint="/database/users").inc()
    
    db_conn = get_db_connection()
    if not db_conn:
        raise HTTPException(status_code=503, detail="Database service unavailable")
    
    try:
        with db_conn.cursor() as cursor:
            cursor.execute("SELECT * FROM users ORDER BY created_at DESC LIMIT 10")
            users = cursor.fetchall()
        db_conn.close()
        return {"users": [dict(user) for user in users]}
    except Exception as e:
        logger.error(f"Failed to get users: {e}")
        raise HTTPException(status_code=500, detail="Failed to get users")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

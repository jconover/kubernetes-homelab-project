-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email) VALUES 
('admin', 'admin@homelab.local'),
('user1', 'user1@homelab.local'),
('user2', 'user2@homelab.local')
ON CONFLICT (username) DO NOTHING;

INSERT INTO tasks (title, description, priority, status) VALUES 
('Setup Kubernetes', 'Deploy Kubernetes cluster', 'high', 'completed'),
('Configure Monitoring', 'Setup Prometheus and Grafana', 'high', 'completed'),
('Deploy Applications', 'Deploy React, Python, and Node.js apps', 'medium', 'in-progress'),
('Setup CI/CD', 'Configure GitHub Actions and ArgoCD', 'medium', 'pending')
ON CONFLICT DO NOTHING;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- PostgreSQL initialization script for Abhimanyu CTF
-- Creates tables for Layer 3 exploitation

-- Create flags table
CREATE TABLE IF NOT EXISTS flags (
    id SERIAL PRIMARY KEY,
    layer INTEGER NOT NULL,
    flag VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table for potential SQL injection
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(100),
    password VARCHAR(255),
    role VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create secrets table
CREATE TABLE IF NOT EXISTS secrets (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    value TEXT,
    layer INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Layer 3 flag
INSERT INTO flags (layer, flag, description)
VALUES (3, 'CTF{BREACHED_REDIS_AND_DATABASE_LAYER3}', 'Layer 3 - Database Breach Flag')
ON CONFLICT DO NOTHING;

-- Insert sample users (for potential SQL injection exploration)
INSERT INTO users (username, email, password, role)
VALUES 
    ('admin', 'admin@chakravyuha.ctf', 'admin_secret_password_123', 'admin'),
    ('ctf_user', 'user@chakravyuha.ctf', 'ctf_user_pass_456', 'user'),
    ('test', 'test@chakravyuha.ctf', 'test_pass_789', 'user')
ON CONFLICT DO NOTHING;

-- Insert secrets for Layer 3
INSERT INTO secrets (key, value, layer)
VALUES 
    ('layer3_hint', 'Look for the flags table to retrieve the flag', 3),
    ('api_key', 'ctf_api_key_12345', 3),
    ('db_admin_pass', 'super_secret_admin_password_xyz', 3)
ON CONFLICT DO NOTHING;

-- Grant permissions to ctf_user
GRANT CONNECT ON DATABASE ctf_db TO ctf_user;
GRANT USAGE ON SCHEMA public TO ctf_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ctf_user;

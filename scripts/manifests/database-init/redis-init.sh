#!/bin/bash
# Redis initialization script

# Set some default cache values
redis-cli SET "app:version" "1.0.0"
redis-cli SET "app:status" "running"
redis-cli SET "cache:ttl" "3600"

# Set some sample data
redis-cli HSET "user:1" "name" "admin" "role" "administrator"
redis-cli HSET "user:2" "name" "user1" "role" "user"
redis-cli HSET "user:3" "name" "user2" "role" "user"

echo "Redis initialization completed"

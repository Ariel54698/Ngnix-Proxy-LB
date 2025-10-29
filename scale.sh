#!/bin/bash

# Script to scale application containers
# Usage: ./scale.sh <number_of_replicas>

if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_replicas>"
    echo "Example: $0 5"
    exit 1
fi

REPLICAS=$1

if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
    echo "Error: Number of replicas must be a positive integer"
    exit 1
fi

if [ "$REPLICAS" -lt 1 ]; then
    echo "Error: Number of replicas must be at least 1"
    exit 1
fi

echo "Scaling application to $REPLICAS replicas..."

# Create a temporary docker-compose override file for scaling
cat > docker-compose.scale.yml <<EOF
version: '3.8'

services:
  nginx:
    volumes:
      - ./nginx.dynamic.conf:/etc/nginx/nginx.conf:ro
EOF

# Generate dynamic nginx configuration
echo "Generating nginx configuration for $REPLICAS replicas..."

cat > nginx.dynamic.conf <<'NGINX_START'
events {
    worker_connections 1024;
}

http {
    # Upstream definition for app containers
    # Using hash based on cookie for sticky sessions
    upstream app_backend {
        hash $cookie_server_ip consistent;
NGINX_START

# Add server entries for each replica
for i in $(seq 1 $REPLICAS); do
    echo "        server app$i:5000;" >> nginx.dynamic.conf
done

cat >> nginx.dynamic.conf <<'NGINX_END'
    }

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    server {
        listen 80;
        server_name localhost;

        location / {
            # Proxy settings
            proxy_pass http://app_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Cookie handling - preserve cookies
            proxy_pass_header Set-Cookie;
            
            # Connection settings
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Disable buffering for real-time responses
            proxy_buffering off;
        }

        location /showcount {
            # Proxy settings for showcount endpoint
            proxy_pass http://app_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            # Health check endpoint
            proxy_pass http://app_backend;
            access_log off;
        }
    }
}
NGINX_END

# Generate docker-compose file with scaled services
cat > docker-compose.scaled.yml <<EOF
version: '3.8'

services:
  # Nginx Load Balancer
  nginx:
    image: nginx:latest
    container_name: nginx_loadbalancer
    ports:
      - "80:80"
    volumes:
      - ./nginx.dynamic.conf:/etc/nginx/nginx.conf:ro
      - nginx_logs:/var/log/nginx
    depends_on:
EOF

# Add dependencies for all app replicas
for i in $(seq 1 $REPLICAS); do
    echo "      - app$i" >> docker-compose.scaled.yml
done

cat >> docker-compose.scaled.yml <<EOF
    networks:
      - app_network
    restart: unless-stopped

  # MySQL Database
  mysql:
    image: mysql:8.0
    container_name: mysql_db
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: appdb
      MYSQL_USER: appuser
      MYSQL_PASSWORD: apppassword
    volumes:
      - mysql_data:/var/lib/mysql
      - mysql_logs:/var/log/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - app_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-prootpassword"]
      interval: 10s
      timeout: 5s
      retries: 5

EOF

# Generate app service definitions
for i in $(seq 1 $REPLICAS); do
    cat >> docker-compose.scaled.yml <<EOF
  # Application Replica $i
  app$i:
    build: .
    container_name: app$i
    environment:
      DB_HOST: mysql
      DB_USER: appuser
      DB_PASSWORD: apppassword
      DB_NAME: appdb
    volumes:
      - app${i}_logs:/app/logs
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - app_network
    restart: unless-stopped

EOF
done

# Add networks and volumes
cat >> docker-compose.scaled.yml <<EOF
networks:
  app_network:
    driver: bridge

volumes:
  mysql_data:
    driver: local
  mysql_logs:
    driver: local
  nginx_logs:
    driver: local
EOF

# Add volume definitions for all app logs
for i in $(seq 1 $REPLICAS); do
    echo "  app${i}_logs:" >> docker-compose.scaled.yml
    echo "    driver: local" >> docker-compose.scaled.yml
done

echo "Stopping existing containers..."
docker-compose down

echo "Starting $REPLICAS application replicas..."
docker-compose -f docker-compose.scaled.yml up -d --build

echo "Waiting for services to be ready..."
sleep 10

echo "Scaling complete!"
echo "Application is now running with $REPLICAS replicas"
echo ""
echo "Container status:"
docker-compose -f docker-compose.scaled.yml ps

echo ""
echo "To view logs: docker-compose -f docker-compose.scaled.yml logs -f"
echo "To stop: docker-compose -f docker-compose.scaled.yml down"


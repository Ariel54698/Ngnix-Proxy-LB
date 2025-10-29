# Docker Load Balanced Python Application

A scalable Python Flask web application with Nginx load balancing, MySQL database, and cookie-based sticky sessions.

## Architecture

- **Nginx Load Balancer**: Routes traffic to application containers with sticky sessions based on cookies
- **Python Flask Application**: 3 replicas (scalable) with persistent logging
- **MySQL Database**: Persistent data and logs storage

## Features

- Cookie-based sticky sessions (5-minute duration)
- Global counter tracking across all requests
- Access logging with client IP and internal IP tracking
- Persistent volumes for logs and database data
- Health check endpoints
- Easy scaling with bash script

## Prerequisites

- Docker
- Docker Compose
- Git

## Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd <repo-directory>
```

### 2. Start the Application (3 replicas)

```bash
docker-compose up -d --build
```

Wait for all services to be healthy (about 30 seconds).

### 3. Test the Application

**Access the main route:**

```bash
curl http://localhost/
```

Returns the internal IP of the server that handled the request.

**Check the global counter:**

```bash
curl http://localhost/showcount
```

Returns the current global counter value.

### 4. Scale the Application

**Scale to 5 replicas:**

```bash
chmod +x scale.sh
./scale.sh 5
```

**Scale to 10 replicas (for testing):**

```bash
./scale.sh 10
```

## Routes

### `/` - Main Route

- Increments global counter by 1
- Creates a cookie with server's internal IP (5-minute expiration)
- Logs: timestamp, client IP, and server internal IP to database
- Returns: Server internal IP

### `/showcount` - Counter Display

- Returns: Current global counter value

### `/health` - Health Check

- Returns: OK status (200)

## Sticky Sessions

The application uses **cookie-based sticky sessions**. When you visit the site:

1. The application sets a `server_ip` cookie with the container's internal IP
2. Nginx uses this cookie to route subsequent requests to the same container
3. Cookie expires after 5 minutes
4. After expiration, the next request will be routed to a different container

## Testing Sticky Sessions

1. **Open browser developer tools** (F12) → Application/Storage → Cookies
2. **Visit** `http://localhost/`
3. **Note the IP address** displayed and the `server_ip` cookie value
4. **Refresh multiple times** - IP should remain the same
5. **Delete the cookie** and refresh - IP should change
6. **Repeat** to verify different servers are being used

### Testing with 10 Replicas

```bash
# Scale to 10 replicas
./scale.sh 10

# Wait for containers to start
docker-compose -f docker-compose.scaled.yml ps

# Access the site and delete cookies between requests
# You should see 10 different IP addresses
```

## Viewing Logs

**Application logs (retained after container stops):**

```bash
# View logs from app1
docker run --rm -v pythonproject_app1_logs:/logs alpine ls -la /logs
docker run --rm -v pythonproject_app1_logs:/logs alpine cat /logs/app.log
```

**Database logs:**

```bash
docker run --rm -v pythonproject_mysql_logs:/logs alpine ls -la /logs
```

**Nginx logs:**

```bash
docker run --rm -v pythonproject_nginx_logs:/logs alpine cat /logs/access.log
```

**View logs while running:**

```bash
docker-compose logs -f app1
docker-compose logs -f nginx
docker-compose logs -f mysql
```

## Database Access

**Connect to MySQL:**

```bash
docker exec -it mysql_db mysql -u appuser -papppassword appdb
```

**View access logs:**

```sql
SELECT * FROM access_log ORDER BY timestamp DESC LIMIT 10;
```

**View global counter:**

```sql
SELECT * FROM global_counter;
```

## Volume Management

All data is persisted in Docker volumes:

- `mysql_data` - Database data
- `mysql_logs` - Database logs
- `nginx_logs` - Nginx access and error logs
- `app1_logs`, `app2_logs`, `app3_logs`, etc. - Application logs

**List volumes:**

```bash
docker volume ls | grep pythonproject
```

**Remove all volumes (WARNING: deletes all data):**

```bash
docker-compose down -v
```

## Stopping the Application

**Stop containers (keep volumes):**

```bash
docker-compose down
```

**Stop and remove volumes:**

```bash
docker-compose down -v
```

## Troubleshooting

**Check container status:**

```bash
docker-compose ps
```

**View container logs:**

```bash
docker-compose logs -f
```

**Restart a specific service:**

```bash
docker-compose restart app1
```

**Rebuild after code changes:**

```bash
docker-compose up -d --build
```

**Check Nginx configuration:**

```bash
docker exec nginx_loadbalancer nginx -t
```

## Project Structure

```
.
├── app.py                    # Flask application
├── requirements.txt          # Python dependencies
├── Dockerfile               # Application container definition
├── docker-compose.yml       # Docker Compose configuration (3 replicas)
├── nginx.conf              # Nginx load balancer configuration
├── init.sql                # Database initialization script
├── scale.sh                # Scaling script
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Environment Variables

Application containers use these environment variables:

- `DB_HOST` - MySQL hostname (default: mysql)
- `DB_USER` - Database user (default: appuser)
- `DB_PASSWORD` - Database password (default: apppassword)
- `DB_NAME` - Database name (default: appdb)

## Development

**Make changes to the application:**

1. Edit `app.py`
2. Rebuild and restart: `docker-compose up -d --build`

**Change number of default replicas:**

1. Edit `docker-compose.yml`
2. Add/remove app service definitions
3. Update Nginx dependencies and upstream servers in `nginx.conf`

## Production Considerations

- Change default passwords in `docker-compose.yml`
- Use environment variables for sensitive data
- Set up proper logging rotation
- Configure Nginx with SSL/TLS
- Use a reverse proxy for external access
- Implement proper monitoring and alerting
- Regular database backups

## License

MIT License

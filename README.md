# Docker Load Balanced Python Application

A scalable Python Flask web application with Nginx load balancing, MySQL database, and cookie-based sticky sessions.

## Architecture

- **Nginx Load Balancer**: Routes traffic to application containers with 5-minute sticky sessions based on cookies.  
- **Python Flask Application**: Single service (`app`) that can be scaled dynamically (e.g., 10 replicas).  
- **MySQL Database**: Stores global counter and access logs.

## Features

- Cookie-based sticky sessions (5-minute lifetime)
- Global counter shared across all replicas
- Access logging (client IP, container internal IP, timestamp)
- Persistent volumes for database and logs
- Health check for MySQL in Docker Compose
- Easy scaling via `scale.sh`

## Prerequisites

- Docker Desktop
- Docker Compose v2+
- Git

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/arielcohen/WhistTask.git
cd WhistTask

2. Build and start the system
docker compose build
docker compose up -d
Wait at least 30 seconds for MySQL to become healthy.

3. Scale the application
docker compose up -d --scale app=10 --no-recreate
Check:
docker compose ps
(You should see app-1 … app-10.)

4. Test:
curl http://localhost/
(Returns internal IP of the serving container.)

5. Test Sticky Sessions:
Open browser → http://localhost/
Open DevTools → Application → Cookies → app_node
Refresh — IP remains the same
Delete cookie → Refresh — IP changes
Repeat → You’ll see all 10 different container IPs.

6. Database Access:
docker compose exec mysql mysql -uappuser -papppassword appdb -e "SELECT * FROM access_log;"

7. Stopping the System:
docker compose down
To remove all data (volumes):
docker compose down -v





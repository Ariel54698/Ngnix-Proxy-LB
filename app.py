from flask import Flask, request, make_response
import mysql.connector
from datetime import datetime, timedelta
import socket
import time
import os
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)

# Configure logging
if not os.path.exists('logs'):
    os.makedirs('logs')

file_handler = RotatingFileHandler('logs/app.log', maxBytes=10240000, backupCount=10)
file_handler.setFormatter(logging.Formatter(
    '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
))
file_handler.setLevel(logging.INFO)
app.logger.addHandler(file_handler)
app.logger.setLevel(logging.INFO)
app.logger.info('Application startup')

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'mysql'),
    'user': os.getenv('DB_USER', 'appuser'),
    'password': os.getenv('DB_PASSWORD', 'apppassword'),
    'database': os.getenv('DB_NAME', 'appdb')
}

def get_internal_ip():
    """Get the internal IP address of the container"""
    return socket.gethostbyname(socket.gethostname())

def get_db_connection():
    """Create a database connection with retry logic"""
    max_retries = 5
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            return conn
        except mysql.connector.Error as err:
            app.logger.warning(f"Database connection attempt {attempt + 1} failed: {err}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                app.logger.error("Failed to connect to database after all retries")
                raise

def initialize_database():
    """Initialize database tables and counter"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create access_log table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS access_log (
                id INT AUTO_INCREMENT PRIMARY KEY,
                timestamp DATETIME NOT NULL,
                client_ip VARCHAR(45) NOT NULL,
                internal_ip VARCHAR(45) NOT NULL,
                INDEX idx_timestamp (timestamp)
            )
        """)
        
        # Create counter table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS global_counter (
                id INT PRIMARY KEY DEFAULT 1,
                count BIGINT NOT NULL DEFAULT 0,
                CHECK (id = 1)
            )
        """)
        
        # Initialize counter if it doesn't exist
        cursor.execute("""
            INSERT IGNORE INTO global_counter (id, count) VALUES (1, 0)
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        app.logger.info("Database initialized successfully")
    except Exception as e:
        app.logger.error(f"Database initialization error: {e}")
        raise

# Initialize database on startup
initialize_database()

@app.route('/')
def index():
    """Main route: increment counter, log access, set cookie"""
    try:
        # Get internal and client IPs
        internal_ip = get_internal_ip()
        client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
        if ',' in client_ip:
            client_ip = client_ip.split(',')[0].strip()
        
        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Increment global counter
        cursor.execute("""
            UPDATE global_counter SET count = count + 1 WHERE id = 1
        """)
        
        # Log access
        current_time = datetime.now()
        cursor.execute("""
            INSERT INTO access_log (timestamp, client_ip, internal_ip)
            VALUES (%s, %s, %s)
        """, (current_time, client_ip, internal_ip))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        # Create response with cookie
        response = make_response(f"Server Internal IP: {internal_ip}\n")
        response.set_cookie(
            'server_ip',
            internal_ip,
            max_age=300,  # 5 minutes
            httponly=False
        )
        
        app.logger.info(f"Request processed - Client: {client_ip}, Internal: {internal_ip}")
        return response
        
    except Exception as e:
        app.logger.error(f"Error processing request: {e}")
        return f"Error: {str(e)}", 500

@app.route('/showcount')
def showcount():
    """Show the current global counter value"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT count FROM global_counter WHERE id = 1")
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result:
            count = result[0]
            app.logger.info(f"Counter requested: {count}")
            return f"Global Counter: {count}\n"
        else:
            return "Counter not initialized\n", 500
            
    except Exception as e:
        app.logger.error(f"Error fetching counter: {e}")
        return f"Error: {str(e)}", 500

@app.route('/health')
def health():
    """Health check endpoint"""
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)


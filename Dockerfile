FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN echo "ASIA/Jerusalem" > /etc/timezone

# Copy application code
COPY app.py .

# Create logs directory
RUN mkdir -p /app/logs

# Expose port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]


-- Initialize database schema
USE appdb;

-- Create access_log table
CREATE TABLE IF NOT EXISTS access_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME NOT NULL,
    client_ip VARCHAR(45) NOT NULL,
    internal_ip VARCHAR(45) NOT NULL,
    INDEX idx_timestamp (timestamp)
);

-- Create global_counter table
CREATE TABLE IF NOT EXISTS global_counter (
    id INT PRIMARY KEY DEFAULT 1,
    count BIGINT NOT NULL DEFAULT 0,
    CHECK (id = 1)
);

-- Initialize counter
INSERT IGNORE INTO global_counter (id, count) VALUES (1, 0);


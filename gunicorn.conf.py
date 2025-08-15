# Configuration Gunicorn pour Rocky Converter Web
# Fichier: gunicorn.conf.py

import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests, to help prevent memory leaks
max_requests = 1000
max_requests_jitter = 50

# Logging
accesslog = "/var/log/rockyconverter/access.log"
errorlog = "/var/log/rockyconverter/error.log"
loglevel = "info"

# Process naming
proc_name = "rockyconverter"

# Server mechanics
daemon = False
pidfile = None
user = None
group = None
tmp_upload_dir = None

# SSL (if using HTTPS directly with Gunicorn)
# keyfile = "/path/to/ssl/key.pem"
# certfile = "/path/to/ssl/cert.pem"

# Environment variables
raw_env = [
    "DJANGO_SETTINGS_MODULE=RockyConverterWeb.settings",
]

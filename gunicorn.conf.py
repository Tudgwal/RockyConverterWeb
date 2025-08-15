# Configuration Gunicorn pour Rocky Converter Web
# Fichier: gunicorn.conf.py

import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes - Réduit pour économiser la mémoire lors des conversions
workers = max(2, multiprocessing.cpu_count() // 2)  # Moins de workers pour les tâches intensives
worker_class = "sync"
worker_connections = 1000
timeout = 1800  # 30 minutes pour les conversions longues
keepalive = 2

# Restart workers after this many requests, to help prevent memory leaks
max_requests = 100  # Redémarrage plus fréquent pour éviter les fuites mémoire
max_requests_jitter = 10

# Limite mémoire par worker (optionnel, nécessite psutil)
# worker_memory_limit = 2 * 1024 * 1024 * 1024  # 2GB par worker

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

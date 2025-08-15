#!/bin/bash
# Script d'installation rapide pour Rocky Converter Web
# Supporte l'installation pour développement et production

set -e  # Arrêter en cas d'erreur

# Variables par défaut
ENVIRONMENT="dev"
INSTALL_REQUIREMENTS="requirements.txt"
CREATE_ENV_FILE=true

# Fonction d'aide
show_help() {
    echo "🚀 Installation de Rocky Converter Web"
    echo "======================================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environnement: 'dev' ou 'prod' (défaut: dev)"
    echo "  -h, --help              Afficher cette aide"
    echo "  --no-env-file           Ne pas créer/modifier le fichier .env"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Installation pour développement"
    echo "  $0 -e dev               # Installation pour développement (explicite)"
    echo "  $0 -e prod              # Installation pour production"
    echo "  $0 --environment prod   # Installation pour production (forme longue)"
    echo ""
    exit 0
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        --no-env-file)
            CREATE_ENV_FILE=false
            shift
            ;;
        *)
            echo "❌ Option inconnue: $1"
            echo "Utilisez -h ou --help pour voir l'aide"
            exit 1
            ;;
    esac
done

# Valider l'environnement
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "❌ Environnement invalide: $ENVIRONMENT"
    echo "   Utilise 'dev' ou 'prod'"
    exit 1
fi

# Configurer selon l'environnement
if [[ "$ENVIRONMENT" == "prod" ]]; then
    INSTALL_REQUIREMENTS="requirements-production.txt"
fi

echo "🚀 Installation de Rocky Converter Web (Environnement: $ENVIRONMENT)"
echo "======================================"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "manage.py" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis le répertoire du projet"
    echo "   Assurez-vous d'être dans le dossier RockyConverterWeb/"
    exit 1
fi

# Vérifier les prérequis
echo "🔍 Vérification des prérequis..."

# Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 n'est pas installé"
    echo "   Installez avec: sudo apt install python3 python3-pip python3-venv"
    exit 1
fi

echo "✅ Prérequis vérifiés"

# Créer l'environnement virtuel
echo "🐍 Création de l'environnement virtuel..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✅ Environnement virtuel créé"
else
    echo "✅ Environnement virtuel existant trouvé"
fi

# Activer l'environnement virtuel
source venv/bin/activate

# Installer les dépendances
echo "📦 Installation des dépendances ($INSTALL_REQUIREMENTS)..."
pip install --upgrade pip
pip install -r "$INSTALL_REQUIREMENTS"
echo "✅ Dépendances installées"

# Créer le fichier .env si il n'existe pas
if [[ "$CREATE_ENV_FILE" == true ]]; then
    if [ ! -f ".env" ]; then
        echo "⚙️ Création du fichier de configuration (.env)..."
        
        # Générer une nouvelle SECRET_KEY
        SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
        
        # Configuration selon l'environnement
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            cat > .env << EOF
# Configuration de production pour Rocky Converter Web
# ⚠️  IMPORTANT: Modifiez ces valeurs pour votre environnement de production
DEBUG=False
SECRET_KEY=$SECRET_KEY
ALLOWED_HOSTS=localhost,127.0.0.1,votre-domaine.com
DATABASE_URL=sqlite:///db.sqlite3
CLEANUP_DAYS=14
CLEANUP_LOG_PATH=/var/log/rocky_converter_cleanup.log
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
STATIC_ROOT=/var/www/rockyconverter/static
MEDIA_ROOT=/var/www/rockyconverter/media
EOF
            echo "✅ Fichier .env de production créé"
            echo "⚠️  IMPORTANT: Éditez le fichier .env pour configurer:"
            echo "   - ALLOWED_HOSTS avec votre domaine"
            echo "   - DATABASE_URL avec vos paramètres de base de données"
            echo "   - Configuration email si nécessaire"
            echo "   - Chemins STATIC_ROOT et MEDIA_ROOT"
        else
            cat > .env << EOF
# Configuration de développement pour Rocky Converter Web
DEBUG=True
SECRET_KEY=$SECRET_KEY
ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=sqlite:///db.sqlite3
CLEANUP_DAYS=14
CLEANUP_LOG_PATH=$HOME/rocky_converter_cleanup.log
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EOF
            echo "✅ Fichier .env de développement créé"
        fi
    else
        echo "✅ Fichier .env existant trouvé"
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            echo "⚠️  Vérifiez que votre fichier .env est configuré pour la production"
        fi
    fi
else
    echo "⏭️  Création du fichier .env ignorée (--no-env-file)"
fi

# Appliquer les migrations
echo "🗄️ Configuration de la base de données..."
python manage.py migrate
echo "✅ Base de données configurée"

# Créer le dossier media
echo "📁 Configuration des dossiers..."
mkdir -p media/albums
chmod 755 media/albums
echo "✅ Dossiers configurés"

# Configuration spécifique à la production
if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo ""
    echo "🔧 Configuration de production..."
    
    # Tester Gunicorn
    echo "🧪 Test de Gunicorn..."
    if python -m gunicorn --version >/dev/null 2>&1; then
        echo "✅ Gunicorn installé et fonctionnel"
    else
        echo "❌ Problème avec Gunicorn"
        exit 1
    fi
    
    # Créer la configuration Gunicorn si elle n'existe pas
    if [ ! -f "gunicorn.conf.py" ]; then
        echo "⚙️ Création de la configuration Gunicorn..."
        cat > gunicorn.conf.py << 'EOF'
# Configuration Gunicorn pour Rocky Converter Web
import multiprocessing

# Serveur
bind = "127.0.0.1:8000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
loglevel = "info"
accesslog = "/var/log/gunicorn/access.log"
errorlog = "/var/log/gunicorn/error.log"

# Process naming
proc_name = "rockyconverter_gunicorn"

# Security
limit_request_fields = 100
limit_request_field_size = 8190
limit_request_line = 4094

# Performance
preload_app = True
max_requests = 1000
max_requests_jitter = 50
EOF
        echo "✅ Configuration Gunicorn créée"
    else
        echo "✅ Configuration Gunicorn existante trouvée"
    fi
    
    # Créer les dossiers de logs
    echo "📝 Configuration des logs de production..."
    sudo mkdir -p /var/log/gunicorn 2>/dev/null || {
        echo "⚠️  Impossible de créer /var/log/gunicorn (permissions)"
        echo "   Vous devrez le créer manuellement :"
        echo "   sudo mkdir -p /var/log/gunicorn"
        echo "   sudo chown -R $USER:$USER /var/log/gunicorn"
    }
    
    # Collecter les fichiers statiques
    echo "📦 Collection des fichiers statiques..."
    python manage.py collectstatic --noinput 2>/dev/null || {
        echo "⚠️  Collection des fichiers statiques échouée (normal si STATIC_ROOT non configuré)"
        echo "   Configurez STATIC_ROOT dans .env puis relancez :"
        echo "   python manage.py collectstatic"
    }
    
    # Créer le fichier de service systemd
    echo "🔧 Création du service systemd..."
    if [ ! -f "rockyconverter.service" ]; then
        cat > rockyconverter.service << EOF
[Unit]
Description=Rocky Converter Web Django App
After=network.target

[Service]
Type=exec
User=$USER
Group=$USER
WorkingDirectory=$(pwd)
Environment=PATH=$(pwd)/venv/bin
ExecStart=$(pwd)/venv/bin/gunicorn --config gunicorn.conf.py RockyConverterWeb.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        echo "✅ Fichier de service systemd créé"
        echo "   Pour l'installer : sudo cp rockyconverter.service /etc/systemd/system/"
        echo "   Pour l'activer : sudo systemctl enable rockyconverter"
        echo "   Pour le démarrer : sudo systemctl start rockyconverter"
    else
        echo "✅ Fichier de service systemd existant trouvé"
    fi
    
    echo "✅ Configuration de production terminée"
    echo ""
fi

# Rendre le script de nettoyage exécutable
chmod +x cleanup_cron.sh
echo "✅ Script de nettoyage configuré"

# Créer le fichier de log
if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "📝 Configuration des logs de production..."
    echo "⚠️  Vous devrez peut-être créer /var/log/rocky_converter_cleanup.log avec les bonnes permissions"
    echo "   sudo touch /var/log/rocky_converter_cleanup.log"
    echo "   sudo chown www-data:www-data /var/log/rocky_converter_cleanup.log"
else
    touch ~/rocky_converter_cleanup.log
    echo "✅ Fichier de log créé"
fi

echo ""
echo "🎉 Installation terminée avec succès !"
echo ""
echo "🔍 Vérification des dépendances :"
python check_dependencies.py
echo ""

if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "🚀 Prochaines étapes pour la PRODUCTION :"
    echo ""
    echo "1️⃣ Configurer les paramètres de production :"
    echo "   • Éditer le fichier .env avec vos paramètres"
    echo "   • Configurer ALLOWED_HOSTS avec votre domaine"
    echo "   • Configurer STATIC_ROOT et MEDIA_ROOT si nécessaire"
    echo ""
    echo "2️⃣ Créer un superutilisateur :"
    echo "   python manage.py createsuperuser"
    echo ""
    echo "3️⃣ Installer et démarrer le service systemd :"
    echo "   sudo cp rockyconverter.service /etc/systemd/system/"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl enable rockyconverter"
    echo "   sudo systemctl start rockyconverter"
    echo "   sudo systemctl status rockyconverter"
    echo ""
    echo "4️⃣ Installer et configurer Nginx :"
    echo "   sudo apt install nginx"
    echo "   # Utiliser le fichier de configuration fourni :"
    echo "   sudo cp nginx.conf.example /etc/nginx/sites-available/rockyconverter"
    echo "   # Éditer et personnaliser :"
    echo "   sudo nano /etc/nginx/sites-available/rockyconverter"
    echo "   # (Remplacer votre-domaine.com et /path/to/RockyConverterWeb)"
    echo ""
    echo "📝 Configuration Nginx recommandée :"
    echo "-------------------------------------"
    echo "server {"
    echo "    listen 80;"
    echo "    server_name votre-domaine.com www.votre-domaine.com;"
    echo ""
    echo "    # Fichiers statiques"
    echo "    location /static/ {"
    echo "        alias $(pwd)/static/;"
    echo "        expires 30d;"
    echo "        add_header Cache-Control \"public, immutable\";"
    echo "    }"
    echo ""
    echo "    # Fichiers média (uploads)"
    echo "    location /media/ {"
    echo "        alias $(pwd)/media/;"
    echo "        expires 30d;"
    echo "    }"
    echo ""
    echo "    # Proxy vers Gunicorn"
    echo "    location / {"
    echo "        proxy_pass http://127.0.0.1:8000;"
    echo "        proxy_set_header Host \$host;"
    echo "        proxy_set_header X-Real-IP \$remote_addr;"
    echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
    echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
    echo "        proxy_connect_timeout 300;"
    echo "        proxy_send_timeout 300;"
    echo "        proxy_read_timeout 300;"
    echo "        client_max_body_size 5G;"
    echo "    }"
    echo "}"
    echo "-------------------------------------"
    echo ""
    echo "5️⃣ Activer le site Nginx :"
    echo "   sudo ln -s /etc/nginx/sites-available/rockyconverter /etc/nginx/sites-enabled/"
    echo "   sudo nginx -t"
    echo "   sudo systemctl restart nginx"
    echo ""
    echo "6️⃣ Configurer le cron job de nettoyage :"
    echo "   crontab -e"
    echo "   Ajouter: 0 2 * * * $(pwd)/cleanup_cron.sh"
    echo ""
    echo "7️⃣ Configurer HTTPS avec Let's Encrypt (optionnel) :"
    echo "   sudo apt install certbot python3-certbot-nginx"
    echo "   sudo certbot --nginx -d votre-domaine.com -d www.votre-domaine.com"
    echo ""
    echo "🔥 Services utiles :"
    echo "   • Voir les logs : sudo journalctl -u rockyconverter -f"
    echo "   • Redémarrer l'app : sudo systemctl restart rockyconverter"
    echo "   • Voir le statut : sudo systemctl status rockyconverter"
    echo ""
    echo "💡 Pour une base de données plus robuste, modifiez DATABASE_URL dans .env"
    echo "📖 Consultez le README.md section 'Configuration de production'"
else
    echo "🔧 Prochaines étapes pour le DÉVELOPPEMENT :"
    echo "1. Créer un superutilisateur :"
    echo "   python manage.py createsuperuser"
    echo "2. Lancer le serveur de développement :"
    echo "   python manage.py runserver"
    echo "3. Accéder à l'application :"
    echo "   http://127.0.0.1:8000"
    echo "4. Configurer le cron job (optionnel) :"
    echo "   crontab -e"
    echo "   Ajouter: 0 2 * * * $(pwd)/cleanup_cron.sh"
    echo ""
    echo "📖 Consultez le README.md pour plus d'informations"
fi

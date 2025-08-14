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

# ImageMagick
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick n'est pas installé"
    echo "   Installez avec: sudo apt install imagemagick"
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
    echo "1. Vérifier la configuration de la base de données dans .env (SQLite par défaut)"
    echo "2. Éditer le fichier .env avec vos paramètres de production"
    echo "3. Collecter les fichiers statiques :"
    echo "   python manage.py collectstatic"
    echo "4. Créer un superutilisateur :"
    echo "   python manage.py createsuperuser"
    echo "5. Configurer votre serveur web (Nginx + Gunicorn)"
    echo "6. Configurer le cron job :"
    echo "   crontab -e"
    echo "   Ajouter: 0 2 * * * $(pwd)/cleanup_cron.sh"
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

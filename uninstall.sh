#!/bin/bash
# Script de désinstallation pour Rocky Converter Web
# Nettoie proprement tous les éléments installés

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/rocky_converter_backup_$(date +%Y%m%d_%H%M%S)"
FORCE_REMOVE=false
KEEP_DATA=false
REMOVE_VENV=true

# Fonction d'aide
show_help() {
    echo -e "${BLUE}🗑️  Désinstallation de Rocky Converter Web${NC}"
    echo "=============================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --force             Forcer la suppression sans confirmation"
    echo "  -k, --keep-data         Garder les données utilisateur (base de données, médias)"
    echo "  --no-venv              Ne pas supprimer l'environnement virtuel"
    echo "  -h, --help              Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                      # Désinstallation interactive"
    echo "  $0 --force              # Désinstallation forcée"
    echo "  $0 --keep-data          # Garder les données utilisateur"
    echo "  $0 -f -k                # Forcé + garder les données"
    echo ""
    echo -e "${YELLOW}⚠️  ATTENTION: Cette action est irréversible !${NC}"
    echo ""
    exit 0
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_REMOVE=true
            shift
            ;;
        -k|--keep-data)
            KEEP_DATA=true
            shift
            ;;
        --no-venv)
            REMOVE_VENV=false
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Option inconnue: $1${NC}"
            echo "Utilisez -h ou --help pour voir l'aide"
            exit 1
            ;;
    esac
done

# Fonction de confirmation
confirm_action() {
    if [[ "$FORCE_REMOVE" == true ]]; then
        return 0
    fi
    
    local message="$1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    read -p "Continuer ? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ️  Opération annulée${NC}"
        exit 0
    fi
}

# Fonction de sauvegarde
create_backup() {
    echo -e "${BLUE}📦 Création d'une sauvegarde...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder la configuration
    if [ -f ".env" ]; then
        cp ".env" "$BACKUP_DIR/"
        echo -e "${GREEN}✅ Configuration (.env) sauvegardée${NC}"
    fi
    
    # Sauvegarder la base de données
    if [ -f "db.sqlite3" ]; then
        cp "db.sqlite3" "$BACKUP_DIR/"
        echo -e "${GREEN}✅ Base de données sauvegardée${NC}"
    fi
    
    # Sauvegarder les médias si ils existent et sont petits
    if [ -d "media/albums" ] && [ "$(du -s media/albums 2>/dev/null | cut -f1)" -lt 102400 ]; then
        cp -r "media/albums" "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}✅ Médias sauvegardés (< 100MB)${NC}"
    elif [ -d "media/albums" ]; then
        echo -e "${YELLOW}⚠️  Dossier média trop volumineux pour la sauvegarde${NC}"
        echo -e "${YELLOW}   Sauvegardez manuellement: media/albums/${NC}"
    fi
    
    echo -e "${GREEN}✅ Sauvegarde créée dans: $BACKUP_DIR${NC}"
}

# Fonction pour arrêter les services
stop_services() {
    echo -e "${BLUE}🛑 Arrêt des services...${NC}"
    
    # Arrêter le service systemd si il existe
    if systemctl is-active --quiet rockyconverter 2>/dev/null; then
        echo "Arrêt du service rockyconverter..."
        sudo systemctl stop rockyconverter
        sudo systemctl disable rockyconverter
        echo -e "${GREEN}✅ Service rockyconverter arrêté${NC}"
    fi
    
    # Arrêter les processus Django en cours
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*rockyconverter" 2>/dev/null || true
    echo -e "${GREEN}✅ Processus Django arrêtés${NC}"
}

# Fonction pour supprimer les tâches cron
remove_cron_jobs() {
    echo -e "${BLUE}⏰ Suppression des tâches cron...${NC}"
    
    # Créer une copie du crontab sans nos tâches
    crontab -l 2>/dev/null | grep -v "cleanup_cron.sh\|rocky_converter" > /tmp/new_crontab || true
    
    # Vérifier s'il y a des changements
    if ! crontab -l 2>/dev/null | diff - /tmp/new_crontab >/dev/null 2>&1; then
        crontab /tmp/new_crontab
        echo -e "${GREEN}✅ Tâches cron supprimées${NC}"
    else
        echo -e "${GREEN}✅ Aucune tâche cron à supprimer${NC}"
    fi
    
    rm -f /tmp/new_crontab
}

# Fonction pour supprimer les fichiers système
remove_system_files() {
    echo -e "${BLUE}🗂️  Suppression des fichiers système...${NC}"
    
    # Supprimer le fichier de service systemd
    if [ -f "/etc/systemd/system/rockyconverter.service" ]; then
        sudo rm -f "/etc/systemd/system/rockyconverter.service"
        sudo systemctl daemon-reload
        echo -e "${GREEN}✅ Fichier de service supprimé${NC}"
    fi
    
    # Supprimer les logs système
    sudo rm -f /var/log/rocky_converter*.log 2>/dev/null || true
    echo -e "${GREEN}✅ Logs système supprimés${NC}"
}

# Fonction pour supprimer l'environnement virtuel
remove_virtual_env() {
    if [[ "$REMOVE_VENV" == true ]] && [ -d "venv" ]; then
        echo -e "${BLUE}🐍 Suppression de l'environnement virtuel...${NC}"
        rm -rf venv/
        echo -e "${GREEN}✅ Environnement virtuel supprimé${NC}"
    else
        echo -e "${BLUE}ℹ️  Environnement virtuel conservé${NC}"
    fi
}

# Fonction pour supprimer les données
remove_data() {
    if [[ "$KEEP_DATA" == true ]]; then
        echo -e "${BLUE}ℹ️  Données utilisateur conservées${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🗄️  Suppression des données...${NC}"
    
    # Supprimer la base de données
    if [ -f "db.sqlite3" ]; then
        rm -f db.sqlite3
        echo -e "${GREEN}✅ Base de données supprimée${NC}"
    fi
    
    # Supprimer les médias
    if [ -d "media/albums" ]; then
        rm -rf media/albums/*
        echo -e "${GREEN}✅ Fichiers média supprimés${NC}"
    fi
    
    # Supprimer les logs locaux
    rm -f ~/rocky_converter*.log 2>/dev/null || true
    if [ -d "logs" ]; then
        rm -rf logs/
        echo -e "${GREEN}✅ Logs locaux supprimés${NC}"
    fi
}

# Fonction pour supprimer les fichiers de configuration
remove_config() {
    echo -e "${BLUE}⚙️  Suppression de la configuration...${NC}"
    
    # Supprimer le fichier .env
    if [ -f ".env" ]; then
        rm -f .env
        echo -e "${GREEN}✅ Fichier .env supprimé${NC}"
    fi
    
    # Supprimer les fichiers de cache Python
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    echo -e "${GREEN}✅ Cache Python nettoyé${NC}"
}

# Fonction pour nettoyer les fichiers temporaires
cleanup_temp_files() {
    echo -e "${BLUE}🧹 Nettoyage des fichiers temporaires...${NC}"
    
    # Supprimer les fichiers temporaires
    rm -rf /tmp/rocky_converter_* 2>/dev/null || true
    rm -rf /tmp/django_* 2>/dev/null || true
    
    # Supprimer les fichiers de sauvegarde
    rm -f *.backup *.bak *.old 2>/dev/null || true
    
    echo -e "${GREEN}✅ Fichiers temporaires supprimés${NC}"
}

# Fonction principale
main() {
    cd "$SCRIPT_DIR"
    
    echo -e "${BLUE}🗑️  Rocky Converter Web - Désinstallation${NC}"
    echo "=============================================="
    echo ""
    
    # Afficher les paramètres
    echo -e "${BLUE}Paramètres de désinstallation:${NC}"
    echo "  - Forcer: $FORCE_REMOVE"
    echo "  - Garder les données: $KEEP_DATA"
    echo "  - Supprimer venv: $REMOVE_VENV"
    echo "  - Sauvegarde: $BACKUP_DIR"
    echo ""
    
    # Confirmation finale
    confirm_action "Voulez-vous vraiment désinstaller Rocky Converter Web ?"
    
    # Créer une sauvegarde
    create_backup
    
    # Arrêter les services
    stop_services
    
    # Supprimer les tâches cron
    remove_cron_jobs
    
    # Supprimer les fichiers système (nécessite sudo)
    if command -v sudo >/dev/null 2>&1; then
        remove_system_files
    else
        echo -e "${YELLOW}⚠️  sudo non disponible, ignoré les fichiers système${NC}"
    fi
    
    # Supprimer les données
    remove_data
    
    # Supprimer la configuration
    remove_config
    
    # Supprimer l'environnement virtuel
    remove_virtual_env
    
    # Nettoyer les fichiers temporaires
    cleanup_temp_files
    
    echo ""
    echo -e "${GREEN}🎉 Désinstallation terminée avec succès !${NC}"
    echo ""
    echo -e "${BLUE}📦 Sauvegarde disponible dans:${NC}"
    echo "   $BACKUP_DIR"
    echo ""
    
    if [[ "$KEEP_DATA" == true ]]; then
        echo -e "${YELLOW}ℹ️  Les données utilisateur ont été conservées${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}Pour supprimer complètement le dossier du projet:${NC}"
    echo "   rm -rf $SCRIPT_DIR"
    echo ""
    echo -e "${BLUE}Merci d'avoir utilisé Rocky Converter Web ! 👋${NC}"
}

# Vérifier qu'on est dans le bon dossier
if [ ! -f "manage.py" ] || [ ! -f "install.sh" ]; then
    echo -e "${RED}❌ Erreur: Ce script doit être exécuté depuis le dossier Rocky Converter Web${NC}"
    echo "   Dossier actuel: $(pwd)"
    echo "   Fichiers requis: manage.py, install.sh"
    exit 1
fi

# Lancer la désinstallation
main "$@"

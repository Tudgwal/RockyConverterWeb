#!/bin/bash
# Script de nettoyage automatique des albums anciens
# À exécuter quotidiennement via cron

# Configuration
VENV_DIR="./venv"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Obtenir la configuration depuis Django
source "$VENV_DIR/bin/activate"

# Obtenir les paramètres depuis Django settings
DJANGO_SETTINGS=$(python -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'RockyConverterWeb.settings')
django.setup()
from django.conf import settings
print(f'{settings.CLEANUP_DAYS},{settings.CLEANUP_LOG_PATH}')
")

# Parser les paramètres
IFS=',' read -r DAYS_TO_KEEP LOG_FILE <<< "$DJANGO_SETTINGS"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Début du script
log "=== DÉBUT DU NETTOYAGE AUTOMATIQUE ==="
log "Suppression des albums de plus de $DAYS_TO_KEEP jours"

# Activer l'environnement virtuel et exécuter la commande
cd "$PROJECT_DIR"
source "$VENV_DIR/bin/activate"

# Exécuter la commande de nettoyage et capturer la sortie
OUTPUT=$(python manage.py cleanup_old_albums --days="$DAYS_TO_KEEP" 2>&1)
EXIT_CODE=$?

# Logger la sortie
log "Sortie de la commande:"
echo "$OUTPUT" | while IFS= read -r line; do
    log "  $line"
done

if [ $EXIT_CODE -eq 0 ]; then
    log "Nettoyage terminé avec succès (code de sortie: $EXIT_CODE)"
else
    log "ERREUR: Le nettoyage a échoué (code de sortie: $EXIT_CODE)"
fi

log "=== FIN DU NETTOYAGE AUTOMATIQUE ==="
log ""

# Optionnel: Nettoyer les anciens logs (garder seulement les 30 derniers jours)
find ~/ -name "rocky_converter_cleanup.log.*" -mtime +30 -delete 2>/dev/null || true

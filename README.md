# Rocky Converter Web

Une application web Django pour la gestion et la conversion automatique d'albums photo avec ImageMagick.

## 📋 Description

Rocky Converter Web est une application qui permet aux utilisateurs de :
- Uploader des albums photo (fichiers individuels ou archives ZIP/TAR)
- Convertir automatiquement les images au format 1920x1080 avec ImageMagick
- Suivre le statut de conversion en temps réel
- Télécharger les albums convertis en ZIP
- Gérer les albums avec suppression automatique après 14 jours

## ✨ Fonctionnalités

- 🔐 **Système d'authentification** avec approbation d'utilisateurs
- 📤 **Upload flexible** : photos individuelles ou archives compressées
- 🖼️ **Conversion automatique** avec ImageMagick (redimensionnement 1920x1080)
- 📊 **Statuts de conversion** : En attente → En cours → Converti/Erreur
- 📥 **Téléchargement ZIP** des albums convertis
- 🗑️ **Nettoyage automatique** des anciens albums (cron job)
- 💾 **Support multi-formats** : JPG, PNG, TIFF, GIF, BMP, WebP
- 📦 **Archives supportées** : ZIP, TAR, TAR.GZ, TAR.BZ2

## 🛠️ Technologies

- **Backend** : Django 5.0, Python 3.12
- **Base de données** : SQLite (PostgreSQL/MySQL supportées)
- **Conversion d'images** : ImageMagick
- **Frontend** : HTML/CSS/JavaScript
- **Gestion des archives** : zipfile, tarfile (bibliothèques standard Python)
- **Configuration** : python-dotenv

## ⚙️ Configuration requise

Le projet utilise des variables d'environnement pour la configuration. **Un fichier `.env` est obligatoire**.

### Variables obligatoires :
- `SECRET_KEY` : Clé secrète Django (générer avec `get_random_secret_key()`)
- `DEBUG` : Mode debug (`True` pour développement, `False` pour production)

### Variables optionnelles :
- `ALLOWED_HOSTS` : Hosts autorisés (séparés par virgules)
- `DATABASE_URL` : URL de base de données (défaut: SQLite)
- `CLEANUP_DAYS` : Durée de rétention des albums (défaut: 14 jours)
- `EMAIL_*` : Configuration email pour les notifications

## � Installation rapide

Le projet inclut un script d'installation automatique qui gère le développement et la production :

```bash
# Installation pour développement (par défaut)
./install.sh

# Installation pour production
./install.sh -e prod

# Voir toutes les options
./install.sh --help
```

### Options du script d'installation :
- `-e dev` : Installation pour développement (SQLite, DEBUG=True)
- `-e prod` : Installation pour production (PostgreSQL, DEBUG=False, sécurité activée)
- `--no-env-file` : Ne pas créer automatiquement le fichier .env
- `--help` : Afficher l'aide

## �📦 Installation manuelle

### Prérequis

```bash
# Installer Python 3.12+
sudo apt update
sudo apt install python3 python3-pip python3-venv

# Installer ImageMagick
sudo apt install imagemagick

# Vérifier l'installation
convert --version
```

### Configuration du projet

1. **Cloner et installer les dépendances**

```bash
# Cloner le projet
git clone <votre-repo>
cd RockyConverterWeb

# Installation automatique pour développement
./install.sh

# OU installation automatique pour production
./install.sh -e prod

# OU installation manuelle
# Créer l'environnement virtuel
python3 -m venv venv
source venv/bin/activate

# Installer les dépendances
# Développement
pip install -r requirements.txt

# Production (inclut gunicorn, psycopg2, etc.)
pip install -r requirements-production.txt
```

2. **Configuration de la base de données**

```bash
# Appliquer les migrations
python manage.py migrate

# Le script d'installation crée automatiquement un fichier .env
# Si vous l'installez manuellement, copiez le template :
cp .env.example .env

# Générer une nouvelle clé secrète
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
# Copier la clé générée dans le fichier .env

# Créer un superutilisateur
python manage.py createsuperuser
```

3. **Configuration des médias**

```bash
# Créer le dossier media
mkdir -p media/albums
chmod 755 media/albums
```

4. **Tester l'installation**

```bash
# Vérifier les dépendances
python check_dependencies.py

# Lancer le serveur de développement
python manage.py runserver

# Accéder à l'application
# http://127.0.0.1:8000
```

## ⚙️ Configuration de production

### 1. Variables d'environnement

Créer un fichier `.env` à partir du template :

```bash
# Copier le template
cp .env.example .env

# Générer une nouvelle clé secrète
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Éditer le fichier .env
nano .env
```

Exemple de configuration de production :
```bash
DEBUG=False
SECRET_KEY=votre-clé-secrète-très-longue-générée
ALLOWED_HOSTS=votre-domaine.com,www.votre-domaine.com
DATABASE_URL=postgresql://user:password@localhost:5432/rockyconverter
CLEANUP_DAYS=14
```

### 2. Serveur web (exemple avec Nginx + Gunicorn)

```bash
# Installer Gunicorn
pip install gunicorn

# Tester Gunicorn
gunicorn RockyConverterWeb.wsgi:application --bind 0.0.0.0:8000

# Configuration Nginx (exemple)
# /etc/nginx/sites-available/rockyconverter
server {
    listen 80;
    server_name votre-domaine.com;
    
    location /static/ {
        alias /path/to/RockyConverterWeb/static/;
    }
    
    location /media/ {
        alias /path/to/RockyConverterWeb/media/;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🕐 Configuration du Cron Job (Nettoyage automatique)

### 1. Script de nettoyage

Le projet inclut un script `cleanup_cron.sh` qui supprime automatiquement les albums de plus de 14 jours.

### 2. Configuration du cron

```bash
# Ouvrir la crontab
crontab -e

# Ajouter cette ligne pour exécuter le nettoyage tous les jours à 02:00
0 2 * * * /path/to/RockyConverterWeb/cleanup_cron.sh

# Exemple complet :
0 2 * * * /home/user/RockyConverterWeb/cleanup_cron.sh
```

### 3. Personnalisation du nettoyage

Modifier le script `cleanup_cron.sh` :

```bash
# Configuration dans cleanup_cron.sh
DAYS_TO_KEEP=14  # Changer pour modifier la durée de rétention
LOG_FILE="/home/user/rocky_converter_cleanup.log"  # Chemin du log
```

### 4. Commandes manuelles de nettoyage

```bash
# Mode dry-run (voir ce qui serait supprimé)
python manage.py cleanup_old_albums --dry-run

# Supprimer les albums de plus de 14 jours
python manage.py cleanup_old_albums --days=14

# Supprimer les albums de plus de 7 jours
python manage.py cleanup_old_albums --days=7
```

## 🔧 Administration

### Gestion des utilisateurs

1. Accéder à l'admin Django : `http://votre-domaine.com/admin/`
2. Aller dans **Converter → User profiles**
3. Approuver les nouveaux utilisateurs en cochant "Approved"

### Monitoring

```bash
# Voir les logs de nettoyage
tail -f /home/user/rocky_converter_cleanup.log

# Statistiques des albums
python manage.py shell -c "
from converter.models import Album
print(f'Total albums: {Album.objects.count()}')
print(f'En attente: {Album.objects.filter(conversion_status=\"pending\").count()}')
print(f'Convertis: {Album.objects.filter(conversion_status=\"completed\").count()}')
"
```

## 🚀 Utilisation

### Pour les utilisateurs

1. **Inscription** : Créer un compte (nécessite approbation admin)
2. **Upload** : Cliquer sur "Nouvel Album" et uploader des photos
3. **Conversion** : Cliquer sur "Convertir" pour redimensionner les images
4. **Téléchargement** : Une fois converti, télécharger l'album en ZIP
5. **Statuts** :
   - ⏳ **En attente** : Album uploadé, pas encore converti
   - 🔄 **En cours de conversion** : Conversion en cours
   - ✅ **Converti** : Prêt à télécharger
   - ❌ **Erreur** : Problème lors de la conversion

### Formats supportés

**Images** : JPG, JPEG, PNG, TIFF, GIF, BMP, WebP  
**Archives** : ZIP, TAR, TAR.GZ, TGZ, TAR.BZ2

## 🐛 Dépannage

### Problèmes courants

**ImageMagick non trouvé** :
```bash
sudo apt install imagemagick
which convert  # Vérifier l'installation
```

**Permissions de fichiers** :
```bash
chmod 755 media/albums
chown -R www-data:www-data media/  # Pour Apache/Nginx
```

**Espace disque** :
```bash
# Vérifier l'espace disponible
df -h

# Nettoyer manuellement les anciens albums
python manage.py cleanup_old_albums --days=7
```

### Logs utiles

```bash
# Logs Django (mode debug)
tail -f nohup.out

# Logs de nettoyage
tail -f /home/user/rocky_converter_cleanup.log

# Logs du serveur web
tail -f /var/log/nginx/error.log
```

## 📁 Structure du projet

```
RockyConverterWeb/
├── converter/                 # Application principale
│   ├── management/commands/   # Commandes Django personnalisées
│   ├── migrations/           # Migrations de base de données
│   ├── templates/            # Templates HTML
│   ├── views/               # Vues (logique métier)
│   ├── models.py            # Modèles de données
│   └── urls.py              # URLs de l'application
├── RockyConverterWeb/        # Configuration Django
├── media/albums/            # Stockage des albums uploadés
├── cleanup_cron.sh          # Script de nettoyage automatique
├── requirements.txt         # Dépendances Python
└── manage.py               # Script de gestion Django
```


---

**Auteur** : Développé avec ❤️ pour la troupe TheTimeSlips

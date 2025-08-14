#!/usr/bin/env python3
"""
Script de vérification des dépendances pour Rocky Converter Web
Vérifie que toutes les dépendances nécessaires sont installées et fonctionnelles
"""

import sys
import subprocess

def check_dependency(module_name, import_name=None, description=""):
    """Vérifie qu'une dépendance est installée et importable"""
    if import_name is None:
        import_name = module_name
    
    try:
        __import__(import_name)
        print(f"✅ {module_name} - {description}")
        return True
    except ImportError:
        print(f"❌ {module_name} - {description} (MANQUANT)")
        return False

def check_external_command(command, description=""):
    """Vérifie qu'une commande externe est disponible"""
    try:
        subprocess.run([command, '--version'], 
                      capture_output=True, check=True)
        print(f"✅ {command} - {description}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"❌ {command} - {description} (MANQUANT)")
        return False

def main():
    print("🔍 Vérification des dépendances Rocky Converter Web")
    print("=" * 50)
    
    all_ok = True
    
    # Dépendances Python obligatoires
    print("\n📦 Dépendances Python obligatoires:")
    deps = [
        ("django", "django", "Framework web Django"),
        ("python-dotenv", "dotenv", "Gestion des variables d'environnement"),
        ("django-cache-memoize", "cache_memoize", "Utilitaires de cache Django"),
    ]
    
    for module, import_name, desc in deps:
        if not check_dependency(module, import_name, desc):
            all_ok = False
    
    # Modules de la bibliothèque standard utilisés
    print("\n🐍 Modules Python standard utilisés:")
    stdlib_modules = [
        ("os", "os", "Opérations système"),
        ("zipfile", "zipfile", "Gestion des archives ZIP"),
        ("tarfile", "tarfile", "Gestion des archives TAR"),
        ("subprocess", "subprocess", "Exécution de commandes externes"),
        ("tempfile", "tempfile", "Fichiers temporaires"),
        ("urllib.parse", "urllib.parse", "Parsing d'URLs"),
    ]
    
    for module, import_name, desc in stdlib_modules:
        check_dependency(module, import_name, desc)
    
    # Commandes externes
    print("\n🔧 Commandes externes requises:")
    commands = [
        ("convert", "ImageMagick (conversion d'images)"),
        ("python3", "Interpréteur Python 3"),
    ]
    
    for command, desc in commands:
        if not check_external_command(command, desc):
            all_ok = False
    
    # Dépendances optionnelles pour la production
    print("\n🚀 Dépendances de production (optionnelles):")
    prod_deps = [
        ("gunicorn", "gunicorn", "Serveur WSGI"),
        ("psycopg2", "psycopg2", "Driver PostgreSQL"),
        ("mysqlclient", "MySQLdb", "Driver MySQL"),
    ]
    
    for module, import_name, desc in prod_deps:
        check_dependency(module, import_name, desc)
    
    print("\n" + "=" * 50)
    if all_ok:
        print("🎉 Toutes les dépendances obligatoires sont installées !")
        print("✅ Le projet devrait fonctionner correctement.")
    else:
        print("⚠️  Certaines dépendances obligatoires sont manquantes.")
        print("📦 Installez-les avec: pip install -r requirements.txt")
        if "convert" in [cmd for cmd, _ in commands]:
            print("🖼️  ImageMagick: sudo apt install imagemagick")
    
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())

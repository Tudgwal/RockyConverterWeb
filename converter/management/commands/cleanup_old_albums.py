import os
import shutil
from datetime import datetime, timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from converter.models import Album


class Command(BaseCommand):
    help = 'Supprime tous les albums qui ont plus de 14 jours'

    def add_arguments(self, parser):
        parser.add_argument(
            '--days',
            type=int,
            default=14,
            help='Nombre de jours après lesquels supprimer les albums (défaut: 14)'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Affiche ce qui serait supprimé sans effectuer la suppression'
        )

    def handle(self, *args, **options):
        days = options['days']
        dry_run = options['dry_run']
        
        # Calculer la date limite (il y a X jours)
        cutoff_date = timezone.now() - timedelta(days=days)
        
        # Trouver tous les albums plus anciens que la date limite
        old_albums = Album.objects.filter(date__lt=cutoff_date)
        
        if not old_albums.exists():
            self.stdout.write(
                self.style.SUCCESS(f'Aucun album de plus de {days} jours trouvé.')
            )
            return

        total_albums = old_albums.count()
        total_size = 0
        deleted_count = 0
        error_count = 0

        self.stdout.write(f'Trouvé {total_albums} album(s) de plus de {days} jours:')
        
        for album in old_albums:
            age_days = (timezone.now() - album.date).days
            album_size = 0
            
            # Calculer la taille du dossier
            if os.path.exists(album.old_path):
                try:
                    for dirpath, dirnames, filenames in os.walk(album.old_path):
                        for filename in filenames:
                            filepath = os.path.join(dirpath, filename)
                            if os.path.exists(filepath):
                                album_size += os.path.getsize(filepath)
                except (OSError, IOError):
                    pass
            
            total_size += album_size
            size_mb = album_size / (1024 * 1024) if album_size > 0 else 0
            
            self.stdout.write(
                f'  - "{album.name}" (créé il y a {age_days} jours, {size_mb:.1f} MB, '
                f'statut: {album.get_conversion_status_display()})'
            )
            
            if not dry_run:
                try:
                    # Supprimer le dossier physique
                    if os.path.exists(album.old_path):
                        shutil.rmtree(album.old_path)
                        self.stdout.write(f'    ✓ Dossier supprimé: {album.old_path}')
                    
                    # Supprimer l'enregistrement de la base de données
                    album.delete()
                    self.stdout.write(f'    ✓ Enregistrement supprimé de la base de données')
                    deleted_count += 1
                    
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(f'    ✗ Erreur lors de la suppression: {str(e)}')
                    )
                    error_count += 1

        total_size_mb = total_size / (1024 * 1024)
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f'\n=== MODE DRY-RUN ===\n'
                    f'{total_albums} album(s) seraient supprimés.\n'
                    f'Espace libéré: {total_size_mb:.1f} MB\n'
                    f'Utilisez la commande sans --dry-run pour effectuer la suppression.'
                )
            )
        else:
            if deleted_count > 0:
                self.stdout.write(
                    self.style.SUCCESS(
                        f'\n=== NETTOYAGE TERMINÉ ===\n'
                        f'{deleted_count} album(s) supprimé(s) avec succès.\n'
                        f'Espace libéré: {total_size_mb:.1f} MB'
                    )
                )
            
            if error_count > 0:
                self.stdout.write(
                    self.style.ERROR(f'{error_count} erreur(s) rencontrée(s).')
                )

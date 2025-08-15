from django.shortcuts import render, redirect
from django.http import HttpResponse, JsonResponse
from django.template import loader
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone
from functools import wraps
import os
import zipfile
import tarfile
import shutil
import glob
import tempfile
from django.conf import settings
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.http import HttpResponse, Http404
from django.utils.encoding import smart_str
from PIL import Image, ImageOps
import logging

from ..models import Album, UserProfile
from ..forms import AlbumUploadForm

# Configuration du logging
logger = logging.getLogger(__name__)

def is_image_file(filename):
    """Vérifie si le fichier est une image supportée"""
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp']
    return any(filename.lower().endswith(ext) for ext in image_extensions)

def extract_archive(archive_file, extract_path):
    """Extrait les fichiers d'une archive et retourne la liste des fichiers extraits"""
    extracted_files = []
    
    try:
        # Sauvegarder temporairement le fichier uploadé
        temp_archive_path = os.path.join(extract_path, 'temp_archive')
        with open(temp_archive_path, 'wb+') as destination:
            for chunk in archive_file.chunks():
                destination.write(chunk)
        
        # Tenter d'extraire selon le type de fichier
        if archive_file.name.lower().endswith(('.zip',)):
            with zipfile.ZipFile(temp_archive_path, 'r') as zip_ref:
                for member in zip_ref.namelist():
                    if not member.endswith('/') and is_image_file(member):
                        zip_ref.extract(member, extract_path)
                        extracted_files.append(os.path.join(extract_path, member))
        
        elif archive_file.name.lower().endswith(('.tar', '.tar.gz', '.tgz', '.tar.bz2')):
            with tarfile.open(temp_archive_path, 'r:*') as tar_ref:
                for member in tar_ref.getmembers():
                    if member.isfile() and is_image_file(member.name):
                        tar_ref.extract(member, extract_path)
                        extracted_files.append(os.path.join(extract_path, member.name))
    
    except Exception as e:
        raise Exception(f"Erreur lors de l'extraction de l'archive: {str(e)}")
    
    return extracted_files

def save_uploaded_files(album_name, photos=None, compressed_file=None):
    """Sauvegarde les fichiers uploadés et retourne le nombre de fichiers traités"""
    # Créer le dossier de destination
    album_dir = os.path.join(settings.MEDIA_ROOT, 'albums', album_name)
    os.makedirs(album_dir, exist_ok=True)
    
    file_count = 0
    
    # Traiter les photos individuelles
    if photos:
        for photo in photos:
            if is_image_file(photo.name):
                file_path = os.path.join(album_dir, photo.name)
                with open(file_path, 'wb+') as destination:
                    for chunk in photo.chunks():
                        destination.write(chunk)
                file_count += 1
    
    # Traiter le fichier compressé
    if compressed_file:
        temp_extract_path = os.path.join(album_dir, 'temp_extract')
        os.makedirs(temp_extract_path, exist_ok=True)
        
        try:
            extracted_files = extract_archive(compressed_file, temp_extract_path)
            
            # Déplacer les fichiers extraits vers le dossier principal
            for extracted_file in extracted_files:
                filename = os.path.basename(extracted_file)
                destination_path = os.path.join(album_dir, filename)
                shutil.move(extracted_file, destination_path)
                file_count += 1
            
        finally:
            # Nettoyer le dossier temporaire
            if os.path.exists(temp_extract_path):
                shutil.rmtree(temp_extract_path)
    
    return file_count

def resize_images_with_pillow(input_dir, output_dir, album=None):
    """
    Redimensionne toutes les images d'un dossier à 1920x1080 en utilisant Pillow
    Met à jour la progression si un album est fourni
    """
    # Extensions d'images supportées par Pillow
    image_extensions = ['*.jpg', '*.jpeg', '*.png', '*.tiff', '*.bmp', '*.webp', 
                       '*.JPG', '*.JPEG', '*.PNG', '*.TIFF', '*.BMP', '*.WEBP']
    
    # Trouver tous les fichiers images dans le dossier
    image_files = []
    for extension in image_extensions:
        image_files.extend(glob.glob(os.path.join(input_dir, extension)))
        # Recherche récursive dans les sous-dossiers
        image_files.extend(glob.glob(os.path.join(input_dir, '**', extension), recursive=True))
    
    if not image_files:
        raise Exception("Aucune image trouvée dans le dossier")
    
    # Créer le dossier de sortie s'il n'existe pas
    os.makedirs(output_dir, exist_ok=True)
    
    total_files = len(image_files)
    converted_count = 0
    errors = []
    
    for i, image_file in enumerate(image_files):
        try:
            # Nom du fichier de sortie
            output_filename = os.path.basename(image_file)
            # Changer l'extension en .jpg pour optimiser l'espace
            name_without_ext = os.path.splitext(output_filename)[0]
            output_filename = f"{name_without_ext}.jpg"
            output_path = os.path.join(output_dir, output_filename)
            
            # Ouvrir l'image avec Pillow
            with Image.open(image_file) as img:
                # Corriger l'orientation EXIF si nécessaire
                img = ImageOps.exif_transpose(img)
                
                # Convertir en RGB si nécessaire (pour les images RGBA, CMYK, etc.)
                if img.mode in ('RGBA', 'LA', 'P'):
                    # Créer un fond blanc pour les images transparentes
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                    img = background
                elif img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Redimensionner l'image en conservant les proportions
                # Utilise LANCZOS pour une meilleure qualité
                img.thumbnail((1920, 1080), Image.LANCZOS)
                
                # Sauvegarder l'image redimensionnée
                img.save(output_path, 'JPEG', quality=90, optimize=True)
                
            converted_count += 1
            
            # Calculer le progrès et mettre à jour l'album si fourni
            progress = ((i + 1) * 100) // total_files
            
            if album:
                # Mettre à jour la progression dans la base de données
                album.conversion_progress = progress
                album.current_file_index = i + 1
                album.current_file_name = output_filename
                album.save(update_fields=['conversion_progress', 'current_file_index', 'current_file_name'])
            
            logger.info(f"Progression: {progress}% ({i + 1}/{total_files}) - {output_filename}")
            
        except Exception as e:
            error_msg = f"Erreur lors de la conversion de {image_file}: {str(e)}"
            logger.error(error_msg)
            errors.append(error_msg)
            
            # Mettre à jour la progression même en cas d'erreur
            if album:
                progress = ((i + 1) * 100) // total_files
                album.conversion_progress = progress
                album.current_file_index = i + 1
                album.current_file_name = f"Erreur: {os.path.basename(image_file)}"
                album.save(update_fields=['conversion_progress', 'current_file_index', 'current_file_name'])
            
            continue
    
    if errors:
        logger.warning(f"Conversion terminée avec {len(errors)} erreur(s)")
        for error in errors[:5]:  # Afficher seulement les 5 premières erreurs
            logger.warning(error)
    
    return converted_count, total_files

def approved_user_required(view_func):
    """Décorateur pour vérifier que l'utilisateur est connecté et approuvé"""
    @wraps(view_func)
    def _wrapped_view(request, *args, **kwargs):
        if not request.user.is_authenticated:
            messages.error(request, 'Vous devez être connecté pour accéder à cette page.')
            return redirect('login')
        
        try:
            user_profile = UserProfile.objects.get(user=request.user)
            if not user_profile.approved:
                messages.error(request, 'Votre compte n\'est pas encore approuvé par un administrateur.')
                return redirect('login')
        except UserProfile.DoesNotExist:
            messages.error(request, 'Profil utilisateur non trouvé.')
            return redirect('login')
        
        return view_func(request, *args, **kwargs)
    return _wrapped_view

@approved_user_required
def index(request):
    latest_album_list = Album.objects.order_by("-date")
    template = loader.get_template("converter/index.html")
    context = {
        "latest_album_list": latest_album_list,
    }
    return HttpResponse(template.render(context, request))

@approved_user_required
def add(request):
    if request.method == 'POST':
        form = AlbumUploadForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                album_name = form.cleaned_data['name']
                # Nettoyer le nom de l'album : remplacer les caractères problématiques
                album_name = album_name.replace('/', '-').replace('\\', '-')
                photos = request.FILES.getlist('photos')
                compressed_file = form.cleaned_data.get('compressed_file')
                
                # Sauvegarder les fichiers et compter
                file_count = save_uploaded_files(album_name, photos, compressed_file)
                
                if file_count > 0:
                    # Créer l'album dans la base de données
                    album = Album.objects.create(
                        name=album_name,
                        old_path=os.path.join(settings.MEDIA_ROOT, 'albums', album_name),
                        file_count=file_count
                    )
                    
                    messages.success(request, f'Album "{album_name}" créé avec succès ! {file_count} fichier(s) uploadé(s).')
                    return redirect('index')
                else:
                    messages.error(request, 'Aucun fichier valide n\'a été uploadé.')
                    
            except Exception as e:
                messages.error(request, f'Erreur lors de l\'upload: {str(e)}')
        else:
            for field, errors in form.errors.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
    else:
        form = AlbumUploadForm()
    
    return render(request, 'converter/upload.html', {'form': form})

@approved_user_required
def delete(request):
    if request.method == 'POST' and 'album_id' in request.POST:
        try:
            album_id = request.POST.get('album_id')
            album = Album.objects.get(id=album_id)
            
            # Supprimer le dossier physique
            album_path = album.old_path
            if os.path.exists(album_path):
                shutil.rmtree(album_path)
            
            # Supprimer l'enregistrement de la base de données
            album_name = album.name
            album.delete()
            
            messages.success(request, f'Album "{album_name}" supprimé avec succès !')
            
        except Album.DoesNotExist:
            messages.error(request, 'Album non trouvé.')
        except Exception as e:
            messages.error(request, f'Erreur lors de la suppression: {str(e)}')
    
    return redirect('index')

@approved_user_required
def download(request, album_id):
    try:
        album = Album.objects.get(id=album_id)
        album_path = album.old_path
        
        if not os.path.exists(album_path):
            messages.error(request, 'Le dossier de l\'album n\'existe pas.')
            return redirect('index')
        
        # Créer un fichier ZIP temporaire
        import tempfile
        import re
        temp_dir = tempfile.mkdtemp()
        
        # Nettoyer le nom du fichier pour éviter les problèmes
        safe_name = re.sub(r'[^a-zA-Z0-9_\-\s]', '', album.name)
        safe_name = re.sub(r'\s+', '_', safe_name.strip())
        zip_filename = f"{safe_name}.zip"
        zip_path = os.path.join(temp_dir, zip_filename)
        
        try:
            # Créer le fichier ZIP
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_file:
                for root, dirs, files in os.walk(album_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        # Nom relatif dans le ZIP
                        arcname = os.path.relpath(file_path, album_path)
                        zip_file.write(file_path, arcname)
            
            # Retourner le fichier en téléchargement
            with open(zip_path, 'rb') as zip_file:
                response = HttpResponse(zip_file.read(), content_type='application/zip')
                response['Content-Disposition'] = f'attachment; filename="{smart_str(zip_filename)}"'
                
            return response
            
        finally:
            # Nettoyer le fichier temporaire
            if os.path.exists(zip_path):
                os.remove(zip_path)
            if os.path.exists(temp_dir):
                os.rmdir(temp_dir)
                
    except Album.DoesNotExist:
        raise Http404("Album non trouvé")
    except Exception as e:
        messages.error(request, f'Erreur lors du téléchargement: {str(e)}')
        return redirect('index')

@approved_user_required
def convert(request):
    if request.method == 'POST' and 'album_id' in request.POST:
        try:
            album_id = request.POST.get('album_id')
            album = Album.objects.get(id=album_id)
            
            # Vérifier que le dossier source existe
            source_dir = album.old_path
            if not os.path.exists(source_dir):
                album.conversion_status = 'error'
                album.save()
                error_msg = f'Le dossier source n\'existe pas: {source_dir}'
                
                # Retourner JSON pour les requêtes AJAX
                if request.headers.get('X-Requested-With') == 'XMLHttpRequest' or request.content_type == 'application/json':
                    return JsonResponse({'success': False, 'error': error_msg}, status=400)
                
                messages.error(request, error_msg)
                return redirect('index')
            
            # Mettre le statut à "en cours de conversion" et réinitialiser la progression
            album.conversion_status = 'converting'
            album.conversion_progress = 0
            album.current_file_index = 0
            album.current_file_name = ''
            album.save()
            
            # Pour les requêtes AJAX, démarrer la conversion en arrière-plan
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest' or 'fetch' in request.META.get('HTTP_SEC_FETCH_MODE', ''):
                # Importer threading pour exécuter en arrière-plan
                import threading
                
                def background_conversion():
                    try:
                        # Créer le nom du dossier de sortie (avec suffixe _resized)
                        base_dir = os.path.dirname(source_dir)
                        dir_name = os.path.basename(source_dir)
                        output_dir = os.path.join(base_dir, f"{dir_name}_resized")
                        
                        # Effectuer la conversion avec Pillow
                        converted_count, total_files = resize_images_with_pillow(source_dir, output_dir, album)
                        
                        if converted_count > 0:
                            # Supprimer l'ancien dossier et renommer le nouveau
                            if os.path.exists(source_dir):
                                shutil.rmtree(source_dir)
                            os.rename(output_dir, source_dir)
                            
                            # Mettre à jour la base de données
                            album.conversion_status = 'completed'
                            album.conversion_date = timezone.now()
                            album.conversion_progress = 100
                            album.save()
                        else:
                            album.conversion_status = 'error'
                            album.save()
                            # Nettoyer le dossier de sortie s'il est vide
                            if os.path.exists(output_dir) and not os.listdir(output_dir):
                                os.rmdir(output_dir)
                    except Exception as e:
                        # En cas d'erreur, mettre le statut à "error"
                        album.conversion_status = 'error'
                        album.save()
                        logger.error(f'Erreur lors de la conversion: {str(e)}')
                        # En cas d'erreur, nettoyer le dossier de sortie s'il existe
                        if 'output_dir' in locals() and os.path.exists(output_dir):
                            try:
                                shutil.rmtree(output_dir)
                            except:
                                pass
                
                # Démarrer la conversion en arrière-plan
                thread = threading.Thread(target=background_conversion)
                thread.daemon = True
                thread.start()
                
                return JsonResponse({
                    'success': True, 
                    'message': f'Conversion de l\'album "{album.name}" démarrée',
                    'album_id': album.id
                })
            
            # Pour les requêtes classiques (form submit), traitement synchrone
            else:
                # Créer le nom du dossier de sortie (avec suffixe _resized)
                base_dir = os.path.dirname(source_dir)
                dir_name = os.path.basename(source_dir)
                output_dir = os.path.join(base_dir, f"{dir_name}_resized")
                
                # Effectuer la conversion avec Pillow
                messages.info(request, f'Début de la conversion de l\'album "{album.name}"...')
                
                converted_count, total_files = resize_images_with_pillow(source_dir, output_dir, album)
                
                if converted_count > 0:
                    # Supprimer l'ancien dossier et renommer le nouveau
                    if os.path.exists(source_dir):
                        shutil.rmtree(source_dir)
                    os.rename(output_dir, source_dir)
                    
                    # Mettre à jour la base de données
                    album.conversion_status = 'completed'
                    album.conversion_date = timezone.now()
                    album.save()
                    
                    messages.success(request, 
                        f'Album "{album.name}" converti avec succès ! '
                        f'{converted_count}/{total_files} images redimensionnées à 1920x1080.'
                    )
                else:
                    album.conversion_status = 'error'
                    album.save()
                    messages.error(request, 'Aucune image n\'a pu être convertie.')
                    # Nettoyer le dossier de sortie s'il est vide
                    if os.path.exists(output_dir) and not os.listdir(output_dir):
                        os.rmdir(output_dir)
                
                return redirect('index')
            
        except Album.DoesNotExist:
            error_msg = 'Album non trouvé.'
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest' or 'fetch' in request.META.get('HTTP_SEC_FETCH_MODE', ''):
                return JsonResponse({'success': False, 'error': error_msg}, status=404)
            messages.error(request, error_msg)
        except Exception as e:
            error_msg = f'Erreur lors de la conversion: {str(e)}'
            logger.error(error_msg)
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest' or 'fetch' in request.META.get('HTTP_SEC_FETCH_MODE', ''):
                return JsonResponse({'success': False, 'error': error_msg}, status=500)
            messages.error(request, error_msg)
    
    return redirect('index')

@approved_user_required
def debug_settings(request):
    """Vue de debug pour afficher les paramètres d'upload"""
    from django.conf import settings
    
    debug_info = f"""
    <h2>Paramètres d'upload Django</h2>
    <p><strong>DATA_UPLOAD_MAX_NUMBER_FILES:</strong> {getattr(settings, 'DATA_UPLOAD_MAX_NUMBER_FILES', 'Non défini')}</p>
    <p><strong>DATA_UPLOAD_MAX_MEMORY_SIZE:</strong> {getattr(settings, 'DATA_UPLOAD_MAX_MEMORY_SIZE', 'Non défini')} bytes</p>
    <p><strong>FILE_UPLOAD_MAX_MEMORY_SIZE:</strong> {getattr(settings, 'FILE_UPLOAD_MAX_MEMORY_SIZE', 'Non défini')} bytes</p>
    <p><a href="{request.META.get('HTTP_REFERER', '/')}">Retour</a></p>
    """
    
    return HttpResponse(debug_info)

@approved_user_required
def get_conversion_progress(request, album_id):
    """Vue AJAX pour récupérer la progression de conversion d'un album"""
    try:
        album = Album.objects.get(id=album_id)
        
        data = {
            'album_id': album.id,
            'album_name': album.name,
            'status': album.conversion_status,
            'progress': album.conversion_progress,
            'current_file_index': album.current_file_index,
            'current_file_name': album.current_file_name,
            'total_files': album.file_count,
        }
        
        # Ajouter des informations supplémentaires selon le statut
        if album.conversion_status == 'completed':
            data['completion_date'] = album.conversion_date.strftime('%d/%m/%Y %H:%M:%S') if album.conversion_date else None
            data['message'] = f'Conversion terminée ! {album.current_file_index}/{album.file_count} images traitées.'
        elif album.conversion_status == 'converting':
            data['message'] = f'Conversion en cours... {album.current_file_index}/{album.file_count} images'
            if album.current_file_name:
                data['current_message'] = f'Traitement de: {album.current_file_name}'
        elif album.conversion_status == 'error':
            data['message'] = 'Erreur lors de la conversion'
            data['error'] = True
        else:  # pending
            data['message'] = 'En attente de conversion'
        
        return JsonResponse(data)
        
    except Album.DoesNotExist:
        return JsonResponse({'error': 'Album non trouvé'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

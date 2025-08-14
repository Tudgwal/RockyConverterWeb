from django import forms
from .models import Album

class MultipleFileInput(forms.ClearableFileInput):
    allow_multiple_selected = True

class MultipleFileField(forms.FileField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("widget", MultipleFileInput())
        super().__init__(*args, **kwargs)

    def clean(self, data, initial=None):
        single_file_clean = super().clean
        if isinstance(data, (list, tuple)):
            result = [single_file_clean(d, initial) for d in data]
        else:
            result = single_file_clean(data, initial)
        return result

class AlbumUploadForm(forms.ModelForm):
    # Champ pour le nom de l'album
    name = forms.CharField(
        max_length=255,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Nom de l\'album'
        }),
        label='Nom de l\'album'
    )
    
    # Champ pour télécharger plusieurs fichiers images
    photos = MultipleFileField(
        widget=MultipleFileInput(attrs={
            'accept': 'image/*',
            'class': 'form-control'
        }),
        required=False,
        label='Photos individuelles'
    )
    
    # Champ pour télécharger un fichier compressé
    compressed_file = forms.FileField(
        widget=forms.FileInput(attrs={
            'accept': '.zip,.rar,.7z,.tar,.tar.gz',
            'class': 'form-control'
        }),
        required=False,
        label='Fichier compressé (.zip, .rar, .7z, .tar)'
    )
    
    class Meta:
        model = Album
        fields = ['name']
    
    def clean(self):
        cleaned_data = super().clean()
        photos = self.files.getlist('photos')
        compressed_file = cleaned_data.get('compressed_file')
        
        # Vérifier qu'au moins un type de fichier est fourni
        if not photos and not compressed_file:
            raise forms.ValidationError(
                "Veuillez sélectionner soit des photos individuelles, soit un fichier compressé."
            )
        
        return cleaned_data

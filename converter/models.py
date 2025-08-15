from django.db import models
from django.contrib.auth.models import User

class Album(models.Model):
    CONVERSION_STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('converting', 'En cours de conversion'),
        ('completed', 'Converti'),
        ('error', 'Erreur'),
    ]
    
    name = models.CharField(max_length=255)
    old_path = models.CharField(max_length=255, default="~/pics/old/") 
    new_path = models.CharField(max_length=255, null=True, blank=True)
    date = models.DateTimeField(auto_now_add=True)
    file_count = models.IntegerField(default=0)
    conversion_date = models.DateTimeField(null=True, blank=True)
    conversion_status = models.CharField(max_length=20, choices=CONVERSION_STATUS_CHOICES, default='pending')
    
    # Champs pour le suivi de progression
    conversion_progress = models.IntegerField(default=0)  # Pourcentage de progression (0-100)
    current_file_index = models.IntegerField(default=0)  # Index du fichier en cours
    current_file_name = models.CharField(max_length=255, blank=True)  # Nom du fichier en cours

    def __str__(self):
        return self.name

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    approved = models.BooleanField(default=False)
    
    def __str__(self):
        return f"{self.user.username} - {'Approuvé' if self.approved else 'En attente'}"
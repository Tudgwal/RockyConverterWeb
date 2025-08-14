from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import UserProfile

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """
    Signal pour créer automatiquement un UserProfile 
    quand un User est créé
    """
    if created:
        UserProfile.objects.get_or_create(user=instance)

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """
    Signal pour sauvegarder le UserProfile 
    quand le User est sauvegardé
    """
    if hasattr(instance, 'userprofile'):
        instance.userprofile.save()

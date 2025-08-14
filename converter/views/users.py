from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login
from django.contrib import messages
from django.http import HttpResponse
from django.shortcuts import render, redirect
from ..models import UserProfile

class UserRegistrationForm(UserCreationForm):
    email = forms.EmailField(required=True)
    first_name = forms.CharField(max_length=30, required=True)
    last_name = forms.CharField(max_length=30, required=True)

    class Meta:
        model = User
        fields = ('username', 'first_name', 'last_name', 'email', 'password1', 'password2')

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data['email']
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        if commit:
            user.save()
            # Le UserProfile sera créé automatiquement par le signal
            # Pas besoin de le créer manuellement ici
        return user

def register(request):
    if request.method == 'POST':
        form = UserRegistrationForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, 'Inscription réussie ! Votre compte est en attente d\'approbation par un administrateur.')
            return redirect('login')
        else:
            messages.error(request, 'Erreur lors de l\'inscription. Veuillez corriger les erreurs ci-dessous.')
    else:
        form = UserRegistrationForm()
    return render(request, 'converter/register.html', {'form': form})

def user_login(request):
    if request.method == 'POST':
        username = request.POST['username']
        password = request.POST['password']
        
        user = authenticate(request, username=username, password=password)
        if user is not None:
            # Vérifier si l'utilisateur est approuvé
            try:
                user_profile = UserProfile.objects.get(user=user)
                if user_profile.approved:
                    login(request, user)
                    return redirect('index')
                else:
                    messages.error(request, 'Votre compte n\'est pas encore approuvé par un administrateur.')
            except UserProfile.DoesNotExist:
                messages.error(request, 'Profil utilisateur non trouvé.')
        else:
            messages.error(request, 'Nom d\'utilisateur ou mot de passe incorrect.')
    
    return render(request, 'converter/login.html')

def user_logout(request):
    from django.contrib.auth import logout
    logout(request)
    messages.success(request, 'Vous avez été déconnecté avec succès.')
    return redirect('login')

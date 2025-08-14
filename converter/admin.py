from django.contrib import admin
from django.contrib.auth.models import User
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

# Register your models here.
from .models import Album, UserProfile

class UserProfileInline(admin.StackedInline):
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profil utilisateur'

class UserAdmin(BaseUserAdmin):
    inlines = (UserProfileInline,)
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'get_approved')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'userprofile__approved')
    
    def get_approved(self, obj):
        return hasattr(obj, 'userprofile') and obj.userprofile.approved
    get_approved.boolean = True
    get_approved.short_description = 'Approuvé'

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'approved')
    list_filter = ('approved',)
    actions = ['approve_users', 'disapprove_users']
    
    def approve_users(self, request, queryset):
        queryset.update(approved=True)
        self.message_user(request, f"{queryset.count()} utilisateur(s) approuvé(s).")
    approve_users.short_description = "Approuver les utilisateurs sélectionnés"
    
    def disapprove_users(self, request, queryset):
        queryset.update(approved=False)
        self.message_user(request, f"{queryset.count()} utilisateur(s) désapprouvé(s).")
    disapprove_users.short_description = "Désapprouver les utilisateurs sélectionnés"

# Re-register UserAdmin
admin.site.unregister(User)
admin.site.register(User, UserAdmin)
admin.site.register(Album)
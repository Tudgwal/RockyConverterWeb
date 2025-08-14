from django.urls import path

from .views import converter, users

urlpatterns = [
    path("", converter.index, name="index"),
    path("register/", users.register, name="register"),
    path("login/", users.user_login, name="login"),
    path("logout/", users.user_logout, name="logout"),
    path("upload/", converter.add , name="upload"),
    path("convert/", converter.convert, name="convert"),
    path("delete/", converter.delete, name="delete"),
    path("download/<int:album_id>/", converter.download, name="download"),
    path("debug/", converter.debug_settings, name="debug_settings"),
]
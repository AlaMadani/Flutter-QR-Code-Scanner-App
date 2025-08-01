from django.contrib import admin
from django.urls import path, include
from firestore_admin import views

urlpatterns = [
    path('', views.firestore_dashboard, name='firestore_dashboard'),
    path('admin/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),
    path('add_user/', views.add_user, name='add_user'),
    path('update_user/<str:user_id>/', views.update_user, name='update_user'),
    path('add_video/', views.add_video, name='add_video'),
    path('update_video/<str:video_id>/', views.update_video, name='update_video'),
    path('generate_qr_code/', views.generate_qr_code, name='generate_qr_code'),
    path('update_app_url/', views.update_app_url, name='update_app_url'),
]
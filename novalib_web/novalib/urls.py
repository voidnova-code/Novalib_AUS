from django.urls import path
from . import views

urlpatterns = [
    # ...existing code...
    path('api/send-otp/', views.send_otp, name='send_otp'),
    path('api/verify-otp/', views.verify_otp, name='verify_otp'),
    path('notifications/', views.DeveloperNotifications, name='developer_notifications'),
    path('library-notifications/', views.notifications, name='library_notifications'),  # <-- Add this line for library notifications
    # ...existing code...
]
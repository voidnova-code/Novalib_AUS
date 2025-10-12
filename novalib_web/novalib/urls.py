from django.urls import path
from . import views

urlpatterns = [
    # ...existing code...
    path('api/send-otp/', views.send_otp, name='send_otp'),
    path('api/verify-otp/', views.verify_otp, name='verify_otp'),
    path('notifications/', views.DeveloperNotifications, name='developer_notifications'),
    path('library-notifications/', views.notifications, name='library_notifications'),
    path('book-log/', views.book_log_list, name='book_log_list'),  # <-- Add this line for book log API
    path('user-wishlist/', views.user_wishlist, name='user_wishlist'),  # New: wishlist via User table (resolve user, then filter BooksLog.wishlist)
    # ...existing code...
]
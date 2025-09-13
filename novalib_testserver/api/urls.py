from django.urls import path
from . import views
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_exempt

urlpatterns = [
    path('login/', views.login, name='login'),                                   # POST: student_id → sends OTP
    path('send-otp/', views.login, name='send_otp'),                            # Alias for login if desired
    path('verify-otp/', views.verify_otp, name='verify_otp'),                   # POST: student_id + otp → verify OTP
    path('students/<str:cardnumber>/issued-books/', views.get_issued_books, name='issued_books'),  # GET issued books
    path('books/recommended/', views.get_recommended_books, name='recommended_books'),              # GET recommended books
    path('books/', views.search_books, name='search_books'),                    # GET: ?search=title_or_author
    path('issue-book/', views.issue_book, name='issue_book'),                   # POST: student_id + isbn → issue book
    path('return-book/', views.return_book, name='return_book'),                # POST: student_id + isbn → return book
    path('renew-book/', views.renew_book, name='renew_book'),                   # POST: student_id + isbn → renew book
    path('students/<str:cardnumber>/wishlist/', views.get_wishlist, name='get_wishlist'),          # GET wishlist
    path('add-to-wishlist/', views.add_to_wishlist, name='add_to_wishlist'),                             # POST add book
    path('remove-from-wishlist/', views.remove_from_wishlist, name='remove_from_wishlist'),              # POST remove book
    path('search-books/', views.search_books, name='search_books_api'),
    path('update-profile-picture/', views.update_profile_picture, name='update_profile_picture'),
    path('students/<str:cardnumber>/profile/', views.get_user_profile, name='get_user_profile'),
]

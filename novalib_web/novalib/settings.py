from django.contrib import admin
from django.urls import reverse, path
from django.utils.html import format_html
from django.shortcuts import redirect, render
from .models import User, BooksLog, Login, ReturnDesk, Department, Notification  # Add Notification

from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent

# Register your models here.

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('barcode_number', 'first_name', 'last_name', 'phone_number', 'email', 'department',)
    search_fields = ('barcode_number', 'first_name', 'last_name', 'email', 'phone_number', 'department')
    actions = ['view_profile_action', 'view_wishlist_action', 'view_bookhold_action']

    def profile_link(self, obj):
        url = reverse('admin:novalib_user_change', args=[obj.pk])
        return format_html('<a href="{}">Profile</a>', url)
    profile_link.short_description = 'Profile'

    def wishlist_link(self, obj):
        url = reverse('admin:novalib_bookslog_changelist') + f'?user__id__exact={obj.pk}&avalible=1'
        return format_html('<a href="{}">Wishlist</a>', url)
    wishlist_link.short_description = 'Wishlist'

    def bookhold_link(self, obj):
        url = reverse('admin:novalib_bookslog_changelist') + f'?user__id__exact={obj.pk}&avalible=0'
        return format_html('<a href="{}">Book Hold</a>', url)
    bookhold_link.short_description = 'Book Hold'

    def view_profile_action(self, request, queryset):
        if queryset.count() == 1:
            obj = queryset.first()
            url = reverse('admin:novalib_user_change', args=[obj.pk])
            return redirect(url)
        else:
            self.message_user(request, "Please select exactly one user to view profile.")
    view_profile_action.short_description = "View Profile"

    def view_wishlist_action(self, request, queryset):
        if queryset.count() == 1:
            obj = queryset.first()
            # Show only wishlist books for the selected user (avalible=True)
            wishlist_books = BooksLog.objects.filter(user=obj, avalible=True)
            context = dict(
                self.admin_site.each_context(request),
                user=obj,
                wishlist_books=wishlist_books,
            )
            return render(request, "admin/wishlist_list.html", context)
        else:
            self.message_user(request, "Please select exactly one user to view wishlist.")
    view_wishlist_action.short_description = "View Wishlist"

    def view_bookhold_action(self, request, queryset):
        if queryset.count() == 1:
            obj = queryset.first()
            # Show only books held by the selected user (avalible=False)
            bookholds = BooksLog.objects.filter(user=obj, avalible=False)
            context = dict(
                self.admin_site.each_context(request),
                user=obj,
                bookholds=bookholds,
            )
            return render(request, "admin/bookhold_list.html", context)
        else:
            self.message_user(request, "Please select exactly one user to view book hold.")
    view_bookhold_action.short_description = "View Book Hold"

@admin.register(BooksLog)
class BooksLogAdmin(admin.ModelAdmin):
    list_display = ('book_barcode', 'user', 'get_wishlist_users', 'book_title', 'auther', 'avalible', 'issued_date', 'return_date')  # Updated 'get_wishlist_users'
    search_fields = ('user__barcode_number', 'wishlist__barcode_number', 'book_title', 'auther')
    fieldsets = (
        (None, {
            'fields': ('book_barcode', 'user', 'wishlist', 'book_title', 'auther', 'avalible', 'issued_date', 'return_date')  # Added 'wishlist'
        }),
    )

    def get_wishlist_users(self, obj):
        return ", ".join([f"{user.first_name} {user.last_name}" for user in obj.wishlist.all()])
    get_wishlist_users.short_description = 'Wishlist Users'

    def view_available_books(self, request, queryset):
        from django.shortcuts import render
        available_books = BooksLog.objects.filter(avalible=True)
        context = dict(
            self.admin_site.each_context(request),
            books=available_books,
            title="Available Books"
        )
        return render(request, "admin/available_books.html", context)
    view_available_books.short_description = "Show Available Books (separate page)"

    def view_unavailable_books(self, request, queryset):
        from django.shortcuts import render
        unavailable_books = BooksLog.objects.filter(avalible=False)
        context = dict(
            self.admin_site.each_context(request),
            books=unavailable_books,
            title="Unavailable Books"
        )
        return render(request, "admin/unavailable_books.html", context)
    view_unavailable_books.short_description = "Show Unavailable Books (separate page)"

@admin.register(Login)
class LoginAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'login_time', 'ip_address', 'authorized')  # Corrected 'authorized'
    search_fields = ('user__barcode_number', 'ip_address')

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                "bookhold/<int:user_id>/",
                self.admin_site.admin_view(self.bookhold_view),
                name="novalib_login_bookhold",
            )
        ]
        return custom_urls + urls

    def bookhold_view(self, request, user_id):
        user = User.objects.get(pk=user_id)
        # Show all BooksLog for this user where avalible=False (book hold)
        bookholds = BooksLog.objects.filter(user=user, avalible=False)
        context = dict(
            self.admin_site.each_context(request),
            user=user,
            bookholds=bookholds,
        )
        return render(request, "admin/bookhold_list.html", context)

@admin.register(ReturnDesk)
class ReturnDeskAdmin(admin.ModelAdmin):
    list_display = (
        'student_barcode', 'student_name', 'book', 'fine', 'otp', 'otp_expired'
    )
    search_fields = ('student__barcode_number', 'student__first_name', 'student__last_name', 'book', 'otp')

    def student_barcode(self, obj):
        return obj.student.barcode_number
    student_barcode.short_description = 'Student Barcode Number'

    def student_name(self, obj):
        return f"{obj.student.first_name} {obj.student.last_name}"
    student_name.short_description = 'Name'

@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'total_users')
    search_fields = ('name',)
    actions = ['view_users']

    def total_users(self, obj):
        return User.objects.filter(department=obj).count()  # Filter by the Department object itself
    total_users.short_description = 'Total Users'

    def view_users(self, request, queryset):
        if queryset.count() == 1:
            department = queryset.first()
            users = User.objects.filter(department=department)
            context = dict(
                self.admin_site.each_context(request),
                department=department,
                users=users,
            )
            return render(request, "admin/department_users.html", context)
        else:
            self.message_user(request, "Please select exactly one department to view users.")
    view_users.short_description = "View Users from Selected Department"

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'uploaded_by', 'message', 'uploaded_image')
    search_fields = ('title', 'uploaded_by__username', 'message')
    readonly_fields = ('uploaded_image_preview',)

    def uploaded_image_preview(self, obj):
        if obj.uploaded_image:
            return format_html('<img src="{}" style="max-height:100px;"/>', obj.uploaded_image.url)
        return "-"
    uploaded_image_preview.short_description = "Image Preview"

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
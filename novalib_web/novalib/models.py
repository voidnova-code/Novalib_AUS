from django.db import models
from django.utils import timezone
from django.utils.timezone import now
from django.conf import settings
import random
import string
import os
from django.db.models.signals import post_delete
from django.dispatch import receiver


class User(models.Model):
    barcode_number = models.CharField(max_length=100, unique=True)  # No primary_key here
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=15)
    email = models.EmailField()
    department = models.ForeignKey('Department', on_delete=models.SET_NULL, null=True, blank=True)
    otp = models.CharField(max_length=7, blank=True, null=True)
    otp_created_at = models.DateTimeField(blank=True, null=True)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.barcode_number})"

class BooksLog(models.Model):
    book_barcode = models.CharField(max_length=100)
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    wishlist = models.ManyToManyField(User, related_name='wishlist_books', blank=True)  # Changed to ManyToManyField
    book_title = models.CharField(max_length=255)
    auther = models.CharField(max_length=255)
    avalible = models.BooleanField(default=True)
    issued_date = models.DateField(null=True, blank=True)
    return_date = models.DateField(null=True, blank=True)

    class Meta:
        db_table = 'books_log'

    def __str__(self):
        user_display = str(self.user) if self.user else "No User"
        return f"{self.book_title} ({self.book_barcode}) - {user_display}"

    def save(self, *args, **kwargs):
        # If user is null, mark as available; else, mark as unavailable
        if self.user is None:
            self.avalible = True
        else:
            self.avalible = False
        super().save(*args, **kwargs)

class Login(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    login_time = models.DateTimeField(default=now)
    ip_address = models.GenericIPAddressField()
    authorized = models.BooleanField(default=False)  # Ensure this field exists

    class Meta:
        db_table = 'login'

    def __str__(self):
        return f"Login: {self.user.barcode_number} at {self.login_time}"

class ReturnDesk(models.Model):
    student = models.ForeignKey(User, on_delete=models.CASCADE)
    book = models.CharField(max_length=255)
    fine = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    otp = models.CharField(max_length=6)
    otp_expired = models.BooleanField(default=False)

    class Meta:
        db_table = 'return_desk'

    def __str__(self):
        return f"{self.student.barcode_number} - {self.student.first_name} {self.student.last_name} - {self.book}"

class Department(models.Model):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        db_table = 'departments'

    def __str__(self):
        return self.name

def notification_image_upload_path(instance, filename):
    # Use .jpeg extension regardless of original file extension
    notification_id = instance.notification_id or 'temp'
    return f'notifications/{notification_id}.jpeg'

class Notification(models.Model):
    notification_id = models.CharField(max_length=8, unique=True, editable=False, null=True, blank=True)
    title = models.CharField(max_length=200)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications'
    )
    message = models.TextField()
    uploaded_image = models.ImageField(upload_to=notification_image_upload_path, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        # First, generate notification_id if not present
        if not self.notification_id:
            while True:
                letters = ''.join(random.choices(string.ascii_uppercase, k=3))
                numbers = ''.join(random.choices(string.digits, k=5))
                new_id = f"{letters}{numbers}"
                if not Notification.objects.filter(notification_id=new_id).exists():
                    self.notification_id = new_id
                    break
        # If the uploaded_image exists and its name does not match the notification_id, re-save it
        if self.uploaded_image and self.uploaded_image.name != f'notifications/{self.notification_id}.jpeg':
            from django.core.files.base import ContentFile
            img_content = self.uploaded_image.read()
            self.uploaded_image.save(f'{self.notification_id}.jpeg', ContentFile(img_content), save=False)
        super().save(*args, **kwargs)

@receiver(post_delete, sender=Notification)
def delete_notification_image(sender, instance, **kwargs):
    if instance.uploaded_image and instance.uploaded_image.storage.exists(instance.uploaded_image.name):
        instance.uploaded_image.delete(save=False)

def developer_notification_image_upload_path(instance, filename):
    # Use .jpeg extension regardless of original file extension
    notification_id = instance.notification_id or 'temp'
    return f'developer_notifications/{notification_id}.jpeg'

class DeveloperNotification(models.Model):
    notification_id = models.CharField(max_length=8, unique=True, editable=False, null=True, blank=True)
    title = models.CharField(max_length=200)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='developer_notifications'
    )
    message = models.TextField()
    uploaded_image = models.ImageField(upload_to=developer_notification_image_upload_path, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        # First, generate notification_id if not present
        if not self.notification_id:
            while True:
                letters = ''.join(random.choices(string.ascii_uppercase, k=3))
                numbers = ''.join(random.choices(string.digits, k=5))
                new_id = f"{letters}{numbers}"
                if not DeveloperNotification.objects.filter(notification_id=new_id).exists():
                    self.notification_id = new_id
                    break
        # If the uploaded_image exists and its name does not match the notification_id, re-save it
        if self.uploaded_image and self.uploaded_image.name != f'developer_notifications/{self.notification_id}.jpeg':
            from django.core.files.base import ContentFile
            img_content = self.uploaded_image.read()
            self.uploaded_image.save(f'{self.notification_id}.jpeg', ContentFile(img_content), save=False)
        super().save(*args, **kwargs)

@receiver(post_delete, sender=DeveloperNotification)
def delete_developer_notification_image(sender, instance, **kwargs):
    if instance.uploaded_image and instance.uploaded_image.storage.exists(instance.uploaded_image.name):
        instance.uploaded_image.delete(save=False)
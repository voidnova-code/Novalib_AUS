from django.db import models
from datetime import datetime, timedelta
from django.utils import timezone


# Your existing database tables (managed=False)
class Biblio(models.Model):
    biblionumber = models.AutoField(primary_key=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    author = models.CharField(max_length=255, blank=True, null=True)
    
    class Meta:
        managed = False
        db_table = 'biblio'
    
    def __str__(self):
        return f"{self.title} by {self.author}"


class Borrowers(models.Model):
    cardnumber = models.CharField(
        max_length=50,
        primary_key=True,
        db_column='cardnumber'
    )
    firstname = models.CharField(max_length=50, db_column='firstname')
    surname   = models.CharField(max_length=50, db_column='surname')
    phone     = models.CharField(max_length=20, db_column='phone')
    profile_picture = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'borrowers'
    
    def __str__(self):
        return f"{self.firstname} {self.surname} ({self.cardnumber})"


class Items(models.Model):
    itemnumber = models.AutoField(primary_key=True)
    biblionumber = models.ForeignKey(Biblio, models.DO_NOTHING, db_column='biblionumber', blank=True, null=True)
    barcode = models.CharField(unique=True, max_length=100, blank=True, null=True)
    
    class Meta:
        managed = False
        db_table = 'items'
    
    def get_book_details(self):
        """Get the book details for this item"""
        if self.biblionumber:
            return {
                'title': self.biblionumber.title,
                'author': self.biblionumber.author,
                'biblionumber': self.biblionumber.biblionumber
            }
        return None


# New Django-managed tables for circulation (since your DB doesn't have them)
class Issues(models.Model):
    cardnumber = models.CharField(max_length=50)  # Reference to borrowers
    itemnumber = models.IntegerField()  # Reference to items
    barcode = models.CharField(max_length=100)
    issue_date = models.DateTimeField(auto_now_add=True)
    due_date = models.DateTimeField()
    renewals = models.IntegerField(default=0)
    returned_date = models.DateTimeField(null=True, blank=True)
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    class Meta:
        db_table = 'issues'
    
    def save(self, *args, **kwargs):
        if not self.due_date:
            self.due_date = datetime.now() + timedelta(days=14)
        super().save(*args, **kwargs)
    
    def is_overdue(self):
        return self.due_date.date() < datetime.now().date() and not self.returned_date
    
    def calculate_fine(self):
        if self.is_overdue():
            days_overdue = (datetime.now().date() - self.due_date.date()).days
            return days_overdue * 1.0  # ₹1 per day
        return 0.0


class OTPVerification(models.Model):
    student_id = models.CharField(max_length=50)
    phone_number = models.CharField(max_length=15)
    otp_code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)
    
    def is_expired(self):
        return timezone.now() > self.expires_at
    
    class Meta:
        db_table = 'otp_verification'


class BookSuggestion(models.Model):
    title = models.CharField(max_length=200)
    author = models.CharField(max_length=200)
    cover_url = models.URLField(blank=True)
    isbn = models.CharField(max_length=20)
    
    def __str__(self):
        return self.title


# Wishlist model for managing users' wishlist items
class Wishlist(models.Model):
    student = models.ForeignKey(Borrowers, on_delete=models.CASCADE)
    item = models.ForeignKey(Items, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'wishlist'
        unique_together = ('student', 'item')

    def __str__(self):
        return f"Wishlist: {self.student.cardnumber} - {self.item.barcode}"

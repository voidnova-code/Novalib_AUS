from django.contrib import admin
from .models import Issues, BookSuggestion, OTPVerification, Borrowers, Biblio, Items

@admin.register(Issues)
class IssuesAdmin(admin.ModelAdmin):
    list_display = ['get_borrower_name', 'get_book_title', 'barcode', 'issue_date', 'due_date', 'is_overdue_display', 'renewals', 'returned_date']
    list_filter = ['issue_date', 'due_date', 'returned_date', 'renewals']
    search_fields = ['cardnumber', 'barcode']
    ordering = ['-issue_date']
    
    def get_borrower_name(self, obj):
        try:
            borrower = Borrowers.objects.get(cardnumber=obj.cardnumber)
            return f"{borrower.firstname} {borrower.surname} ({obj.cardnumber})"
        except Borrowers.DoesNotExist:
            return f"Unknown ({obj.cardnumber})"
    get_borrower_name.short_description = 'Borrower'
    
    def get_book_title(self, obj):
        try:
            item = Items.objects.get(itemnumber=obj.itemnumber)
            if item.biblionumber:
                return f"{item.biblionumber.title} by {item.biblionumber.author}"
            return f"Item #{obj.itemnumber}"
        except Items.DoesNotExist:
            return f"Unknown Item ({obj.itemnumber})"
    get_book_title.short_description = 'Book'
    
    def is_overdue_display(self, obj):
        if obj.returned_date:
            return "Returned"
        elif obj.is_overdue():
            return "⚠️ OVERDUE"
        else:
            return "✅ Current"
    is_overdue_display.short_description = 'Status'

@admin.register(Borrowers)
class BorrowersAdmin(admin.ModelAdmin):
    list_display = ['cardnumber', 'firstname', 'surname', 'phone', 'get_active_issues_count']
    search_fields = ['cardnumber', 'firstname', 'surname', 'phone']
    
    def get_active_issues_count(self, obj):
        count = Issues.objects.filter(cardnumber=obj.cardnumber, returned_date__isnull=True).count()
        return f"{count} book(s)"
    get_active_issues_count.short_description = 'Current Issues'

@admin.register(Biblio)
class BiblioAdmin(admin.ModelAdmin):
    list_display = ['biblionumber', 'title', 'author']
    search_fields = ['title', 'author']

@admin.register(Items)
class ItemsAdmin(admin.ModelAdmin):
    list_display = ['itemnumber', 'get_book_title', 'barcode', 'is_currently_issued']
    search_fields = ['barcode']
    
    def get_book_title(self, obj):
        if obj.biblionumber:
            return f"{obj.biblionumber.title} by {obj.biblionumber.author}"
        return "No Book Info"
    get_book_title.short_description = 'Book'
    
    def is_currently_issued(self, obj):
        issued = Issues.objects.filter(itemnumber=obj.itemnumber, returned_date__isnull=True).exists()
        return "🔴 Issued" if issued else "🟢 Available"
    is_currently_issued.short_description = 'Availability'

@admin.register(BookSuggestion)
class BookSuggestionAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'isbn']

@admin.register(OTPVerification)
class OTPVerificationAdmin(admin.ModelAdmin):
    list_display = ['student_id', 'phone_number', 'created_at', 'is_verified', 'is_expired_display']
    list_filter = ['is_verified', 'created_at']
    
    def is_expired_display(self, obj):
        return "❌ Expired" if obj.is_expired() else "✅ Valid"
    is_expired_display.short_description = 'Status'

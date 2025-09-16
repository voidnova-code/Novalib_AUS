import random
from datetime import timedelta
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.db import connection
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import Borrowers, Items, Issues, OTPVerification, BookSuggestion, Wishlist
import os
from dotenv import load_dotenv

# Endpoint to get user profile data
@api_view(['GET'])
@permission_classes([AllowAny])
def get_user_profile(request, cardnumber):
    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    profile_url = borrower.profile_picture if borrower.profile_picture else ''
    return Response({
        'student_id': borrower.cardnumber,
        'name': borrower.firstname + ' ' + borrower.surname,
        'email': '',
        'phone': borrower.phone,
        'profile_image_url': profile_url,
    }, status=status.HTTP_200_OK)
from django.views.decorators.csrf import csrf_exempt
from django.db import connection
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import Borrowers, Items, Issues, OTPVerification, BookSuggestion, Wishlist
import os
from dotenv import load_dotenv

load_dotenv("C:\\Users\\sayan\\Desktop\\c++\\project_library\\NovaLiB\\novalib_testserver\\security.env")

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def issue_book(request):
    cardnumber = request.data.get('cardnumber')
    isbn = request.data.get('isbn')
    if not cardnumber or not isbn:
        return Response({'error': 'cardnumber and isbn required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
    try:
        item = Items.objects.get(barcode=isbn)
    except Items.DoesNotExist:
        return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)
    if Issues.objects.filter(barcode=item.barcode, returned_date__isnull=True).exists():
        return Response({'error': 'Book already issued'}, status=status.HTTP_400_BAD_REQUEST)
    issue = Issues(
        cardnumber=borrower.cardnumber,
        itemnumber=item.itemnumber,
        barcode=item.barcode,
        issue_date=timezone.now(),
        due_date=timezone.now() + timedelta(days=14),
        renewals=0
    )
    issue.save()
    return Response({'message': 'Book issued successfully'}, status=status.HTTP_200_OK)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def return_book(request):
    cardnumber = request.data.get('cardnumber')
    isbn = request.data.get('isbn')
    if not cardnumber or not isbn:
        return Response({'error': 'cardnumber and isbn required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        issue = Issues.objects.get(cardnumber=cardnumber, barcode=isbn, returned_date__isnull=True)
    except Issues.DoesNotExist:
        return Response({'error': 'Issue record not found'}, status=status.HTTP_404_NOT_FOUND)
    issue.returned_date = timezone.now()
    issue.save()
    return Response({'message': 'Book returned successfully'}, status=status.HTTP_200_OK)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def renew_book(request):
    cardnumber = request.data.get('cardnumber')
    isbn = request.data.get('isbn')
    if not cardnumber or not isbn:
        return Response({'error': 'cardnumber and isbn required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        issue = Issues.objects.get(cardnumber=cardnumber, barcode=isbn, returned_date__isnull=True)
    except Issues.DoesNotExist:
        return Response({'error': 'Issue record not found'}, status=status.HTTP_404_NOT_FOUND)
    if issue.renewals >= 2:
        return Response({'error': 'Maximum renewals reached'}, status=status.HTTP_400_BAD_REQUEST)
    issue.due_date += timedelta(days=14)
    issue.renewals += 1
    issue.save()
    return Response({'message': 'Book renewed successfully', 'new_due_date': issue.due_date.isoformat()}, status=status.HTTP_200_OK)


# SMS sending function (fill with your SMS provider, e.g., Twilio)
def send_otp_sms(phone_number, otp_code):
    try:
        from twilio.rest import Client
        account_sid = os.getenv("TWILIO_SID")  # Check this env variable name
        auth_token = os.getenv("TWILIO_AUTH_TOKEN")  # Check this env variable name
        twilio_phone = os.getenv("TWILIO_PHONE")  # Check this env variable name

        print(f"Sending OTP {otp_code} to {phone_number}")
        print(f"Using Account SID: {account_sid}")  # Debug print
        print(f"Using Twilio Phone: {twilio_phone}")  # Debug print

        client = Client(account_sid, auth_token)
        message = client.messages.create(
            body=f'Your NovaLib OTP: {otp_code}. Valid for 10 minutes.',
            from_=twilio_phone,
            to=phone_number
        )
        print(f"SMS sent: {message.sid}")
        return True, message.sid

    except Exception as e:
        print(f"Failed to send SMS: {e}")
        return False, str(e)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    cardnumber = request.data.get('cardnumber')
    if not cardnumber:
        return Response({'error': 'cardnumber required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'Borrower not found'}, status=status.HTTP_404_NOT_FOUND)

    otp_code = f"{random.randint(100000, 999999)}"
    expires_at = timezone.now() + timedelta(minutes=10)

    OTPVerification.objects.create(
        student_id=cardnumber,  # keeping student_id in OTPVerification model for now
        phone_number=borrower.phone,
        otp_code=otp_code,
        created_at=timezone.now(),
        expires_at=expires_at,
        is_verified=False
    )

    success, result = send_otp_sms(borrower.phone, otp_code)
    if not success:
        return Response({'error': 'Failed to send OTP', 'details': result}, status=status.HTTP_502_BAD_GATEWAY)

    return Response({'phone': borrower.phone, 'message': 'OTP sent successfully'}, status=status.HTTP_200_OK)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    cardnumber = request.data.get('cardnumber')
    otp = request.data.get('otp')
    if not cardnumber or not otp:
        return Response({'error': 'cardnumber and otp required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        otp_record = OTPVerification.objects.get(student_id=cardnumber, otp_code=otp, is_verified=False)
    except OTPVerification.DoesNotExist:
        return Response({'error': 'Invalid or used OTP'}, status=status.HTTP_400_BAD_REQUEST)

    if otp_record.expires_at < timezone.now():
        return Response({'error': 'OTP expired'}, status=status.HTTP_400_BAD_REQUEST)

    otp_record.is_verified = True
    otp_record.save()

    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    return Response({
        'success': True,
        'patron': {
            'firstname': borrower.firstname,
            'surname': borrower.surname,
            'borrowernumber': borrower.cardnumber,
            'email': '',  # Provide if available
            'phone': borrower.phone,
            'cardnumber': borrower.cardnumber,
        }
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def get_issued_books(request, cardnumber):
    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    issues = Issues.objects.filter(cardnumber=borrower.cardnumber, returned_date__isnull=True)
    issued_list = []
    for issue in issues:
        try:
            item = Items.objects.get(itemnumber=issue.itemnumber)
            book = item.biblionumber
            issued_list.append({
                'title': book.title if book else 'Unknown',
                'author': book.author if book else 'Unknown',
                'cover_url': '',  # Add if available
                'due_date': issue.due_date.isoformat(),
                'fine': float(issue.calculate_fine()),
                'is_due_soon': (issue.due_date - timezone.now()).days <= 3,
                'is_returned': False,
                'isbn': '',  # Add if available
                'is_available': False,
            })
        except Items.DoesNotExist:
            continue

    return Response(issued_list)


@api_view(['GET'])
@permission_classes([AllowAny])
def get_recommended_books(request):
    suggestions = BookSuggestion.objects.all()[:10]
    rec_list = []
    for book in suggestions:
        rec_list.append({
            'title': book.title,
            'author': book.author,
            'cover_url': book.cover_url or '',
            'isbn': book.isbn,
        })
    return Response(rec_list)


@api_view(['GET'])
@permission_classes([AllowAny])
def search_books(request):
    query = request.GET.get('search', '')
    if not query:
        return Response([])

    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT DISTINCT b.title, b.author, i.barcode
            FROM biblio b
            LEFT JOIN items i ON b.biblionumber = i.biblionumber
            WHERE LOWER(b.title) LIKE LOWER(%s) OR LOWER(b.author) LIKE LOWER(%s)
            LIMIT 20
        """, [f'%{query}%', f'%{query}%'])
        rows = cursor.fetchall()

    results = []
    for title, author, barcode in rows:
        available = True
        if barcode:
            if Issues.objects.filter(barcode=barcode, returned_date__isnull=True).exists():
                available = False
        results.append({
            'title': title or 'Unknown',
            'author': author or 'Unknown',
            'isbn': '',  # Add if available
            'cover_url': '',
            'is_available': available,
        })

    return Response(results)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def issue_book(request):
    student_id = request.data.get('student_id')
    isbn = request.data.get('isbn')
    if not student_id or not isbn:
        return Response({'error': 'student_id and isbn required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        borrower = Borrowers.objects.get(cardnumber=student_id)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    try:
        item = Items.objects.get(barcode=isbn)  # Adjust if needed
    except Items.DoesNotExist:
        return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)

    if Issues.objects.filter(barcode=item.barcode, returned_date__isnull=True).exists():
        return Response({'error': 'Book already issued'}, status=status.HTTP_400_BAD_REQUEST)

    issue = Issues(
        cardnumber=borrower.cardnumber,
        itemnumber=item.itemnumber,
        barcode=item.barcode,
        issue_date=timezone.now(),
        due_date=timezone.now() + timedelta(days=14),
        renewals=0
    )
    issue.save()

    return Response({'message': 'Book issued successfully'}, status=status.HTTP_200_OK)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def return_book(request):
    student_id = request.data.get('student_id')
    isbn = request.data.get('isbn')
    if not student_id or not isbn:
        return Response({'error': 'student_id and isbn required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        issue = Issues.objects.get(cardnumber=student_id, barcode=isbn, returned_date__isnull=True)
    except Issues.DoesNotExist:
        return Response({'error': 'Issue record not found'}, status=status.HTTP_404_NOT_FOUND)

    issue.returned_date = timezone.now()
    issue.save()

    return Response({'message': 'Book returned successfully'}, status=status.HTTP_200_OK)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def renew_book(request):
    student_id = request.data.get('student_id')
    isbn = request.data.get('isbn')
    if not student_id or not isbn:
        return Response({'error': 'student_id and isbn required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        issue = Issues.objects.get(cardnumber=student_id, barcode=isbn, returned_date__isnull=True)
    except Issues.DoesNotExist:
        return Response({'error': 'Issue record not found'}, status=status.HTTP_404_NOT_FOUND)

    if issue.renewals >= 2:
        return Response({'error': 'Maximum renewals reached'}, status=status.HTTP_400_BAD_REQUEST)

    issue.due_date += timedelta(days=14)
    issue.renewals += 1
    issue.save()

    return Response({'message': 'Book renewed successfully', 'new_due_date': issue.due_date.isoformat()}, status=status.HTTP_200_OK)


# Wishlist Model should be defined in models.py as:
# class Wishlist(models.Model):
#     student = models.ForeignKey(Borrowers, on_delete=models.CASCADE)
#     item = models.ForeignKey(Items, on_delete=models.CASCADE)
#     added_at = models.DateTimeField(auto_now_add=True)
#
#     class Meta:
#         unique_together = ('student', 'item')

@api_view(['GET'])
@permission_classes([AllowAny])
def get_wishlist(request, cardnumber):
    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    wishlist_items = Wishlist.objects.filter(student=borrower).select_related('item')
    data = []
    for w in wishlist_items:
        book = w.item.biblionumber
        data.append({
            'title': book.title if book else 'Unknown',
            'author': book.author if book else 'Unknown',
            'isbn': w.item.barcode,
            'cover_url': '',  # Add if available
            'is_available': not Issues.objects.filter(barcode=w.item.barcode, returned_date__isnull=True).exists(),
        })
    return Response(data)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def add_to_wishlist(request):
    cardnumber = request.data.get('cardnumber')
    isbn = request.data.get('isbn')
    if not cardnumber or not isbn:
        return Response({'error': 'cardnumber and isbn required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
        item = Items.objects.get(barcode=isbn)
    except (Borrowers.DoesNotExist, Items.DoesNotExist):
        return Response({'error': 'User or Book not found'}, status=status.HTTP_404_NOT_FOUND)

    wishlist_entry, created = Wishlist.objects.get_or_create(student=borrower, item=item)
    if created:
        return Response({'message': 'Added to wishlist'}, status=status.HTTP_200_OK)
    else:
        return Response({'message': 'Already in wishlist'}, status=status.HTTP_200_OK)


@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def remove_from_wishlist(request):
    cardnumber = request.data.get('cardnumber')
    isbn = request.data.get('isbn')
    if not cardnumber or not isbn:
        return Response({'error': 'cardnumber and isbn required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
        item = Items.objects.get(barcode=isbn)
        wishlist_entry = Wishlist.objects.get(student=borrower, item=item)
    except (Borrowers.DoesNotExist, Items.DoesNotExist, Wishlist.DoesNotExist):
        return Response({'error': 'Entry not found'}, status=status.HTTP_404_NOT_FOUND)

    wishlist_entry.delete()
    return Response({'message': 'Removed from wishlist'}, status=status.HTTP_200_OK)

# Endpoint to update user profile picture
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def update_profile_picture(request):
    cardnumber = request.data.get('cardnumber')
    image = request.FILES.get('profile_picture')
    if not cardnumber or not image:
        return Response({'error': 'cardnumber and profile_picture required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        borrower = Borrowers.objects.get(cardnumber=cardnumber)
    except Borrowers.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    # Save image to media/profile_pictures/<cardnumber>.jpg
    file_path = f"profile_pictures/{cardnumber}.jpg"
    full_path = os.path.join(file_path)
    # Ensure the directory exists
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    path = default_storage.save(full_path, ContentFile(image.read()))

    # Save the relative path to the Borrowers model
    borrower.profile_picture = file_path
    borrower.save()

    # Return a URL that can be served by Django's media endpoint
    profile_picture_url = request.build_absolute_uri(f"{file_path}")

    return Response({'message': 'Profile picture updated successfully', 'profile_picture_url': profile_picture_url}, status=status.HTTP_200_OK)

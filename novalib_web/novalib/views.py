from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.mail import send_mail
from novalib.models import User, Login, Notification, DeveloperNotification
from django.utils.timezone import now, timedelta
import json
import random

@csrf_exempt
def ping(request):
    return JsonResponse({'status': 'ok', 'message': 'Django server is running'})

def generate_otp():
    return str(random.randint(100000, 999999))

@csrf_exempt
def send_otp(request):
    if request.method == 'POST':
        data = json.loads(request.body.decode('utf-8'))
        barcode = data.get('barcode')
        otp = generate_otp()
        try:
            user = User.objects.get(barcode_number=barcode)  # Updated field name
            email = user.email
            subject = "NovaLib OTP Verification Code"
            message = (
                f"Dear {user.first_name},\n\n"
                f"Your One-Time Password (OTP) for accessing NovaLib is: {otp}\n\n"
                f"This OTP is valid for 5 minutes. Please do not share this code with anyone.\n\n"
                f"If you did not request this OTP, please ignore this email.\n\n"
                f"Thank you,\n"
                f"The NovaLib Team"
            )
            from_email = "sayan.kumar.roy@aus.ac.in"
            send_mail(subject, message, from_email, [email], fail_silently=False)

            # Store OTP and timestamp in the database
            user.otp = otp
            user.otp_created_at = now()
            user.save()

            # Capture the user's IP address
            ip_address = get_client_ip(request)

            # Log the login attempt in the login table
            Login.objects.create(user=user, login_time=now(), ip_address=ip_address)

            return JsonResponse({'user': {'name': f"{user.first_name} {user.last_name}", 'phone': user.phone_number}, 'email': email}, status=200)
        except User.DoesNotExist:
            return JsonResponse({'error': 'User not found'}, status=404)
    return JsonResponse({'error': 'Invalid request'}, status=400)

def get_client_ip(request):
    """Retrieve the client's IP address from the request."""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip

@csrf_exempt
def verify_otp(request):
    if request.method == 'POST':
        data = json.loads(request.body.decode('utf-8'))
        barcode = data.get('barcode')
        otp = data.get('otp')
        try:
            user = User.objects.get(barcode_number=barcode)
            # Check if OTP matches and is not expired
            if user.otp == otp and user.otp_created_at >= now() - timedelta(minutes=5):
                # Mark the user as authorized in the Login table
                login_entry = Login.objects.filter(user=user).latest('login_time')
                login_entry.authorized = True
                login_entry.save()

                return JsonResponse({'message': 'OTP verified successfully'}, status=200)
            else:
                return JsonResponse({'error': 'Invalid or expired OTP'}, status=400)
        except User.DoesNotExist:
            return JsonResponse({'error': 'User not found'}, status=404)
        except Login.DoesNotExist:
            return JsonResponse({'error': 'No login record found for this user'}, status=400)
    return JsonResponse({'error': 'Invalid request'}, status=400)

def DeveloperNotifications(request):
    notifications = DeveloperNotification.objects.all().order_by('-created_at')
    data = []
    for notification in notifications:
        uploaded_by = notification.uploaded_by
        if hasattr(uploaded_by, "get_full_name") and callable(uploaded_by.get_full_name):
            uploaded_by_name = uploaded_by.get_full_name()
            if not uploaded_by_name.strip():
                uploaded_by_name = getattr(uploaded_by, "username", str(uploaded_by))
        elif hasattr(uploaded_by, "username"):
            uploaded_by_name = uploaded_by.username
        else:
            uploaded_by_name = str(uploaded_by)

        image_url = ""
        if notification.uploaded_image:
            image_url = request.build_absolute_uri(notification.uploaded_image.url)
        # Format timestamp as "Monday 14:30"
        if hasattr(notification, "created_at") and notification.created_at:
            timestamp = notification.created_at.strftime("%A %H:%M")
        else:
            timestamp = ""
        data.append({
            "title": notification.title,
            "message": notification.message,
            "uploaded_by": uploaded_by_name,
            "uploaded_image": image_url,
            "timestamp": timestamp,
        })
    return JsonResponse(data, safe=False)

def notifications(request):
    notifications = Notification.objects.all().order_by('-created_at')
    data = []
    for notification in notifications:
        uploaded_by = notification.uploaded_by
        if hasattr(uploaded_by, "get_full_name") and callable(uploaded_by.get_full_name):
            uploaded_by_name = uploaded_by.get_full_name()
            if not uploaded_by_name.strip():
                uploaded_by_name = getattr(uploaded_by, "username", str(uploaded_by))
        elif hasattr(uploaded_by, "username"):
            uploaded_by_name = uploaded_by.username
        else:
            uploaded_by_name = str(uploaded_by)

        image_url = ""
        if notification.uploaded_image:
            image_url = request.build_absolute_uri(notification.uploaded_image.url)
        # Format timestamp as "Monday 14:30"
        if hasattr(notification, "created_at") and notification.created_at:
            timestamp = notification.created_at.strftime("%A %H:%M")
        else:
            timestamp = ""
        data.append({
            "title": notification.title,
            "message": notification.message,
            "uploaded_by": uploaded_by_name,
            "uploaded_image": image_url,
            "timestamp": timestamp,
        })
    return JsonResponse(data, safe=False)
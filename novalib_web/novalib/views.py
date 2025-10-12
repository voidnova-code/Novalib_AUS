from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.mail import send_mail
from novalib.models import User, Login, Notification, DeveloperNotification
from novalib.models import BooksLog  # fixed import
from django.utils.timezone import now, timedelta
from django.db.models import Q  # add this
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
            user = User.objects.get(barcode_number=barcode)
            email = user.email
            subject = "NovaLib verification code"
            
            # Plain text message remains the same
            message = (
                f"Please verify your identity, {user.first_name}\n\n"
                f"Here is your NovaLib verification code:\n\n"
                f"{otp}\n\n"
                f"This code is valid for 15 minutes and can only be used once.\n\n"
                f"Please don't share this code with anyone: we'll never ask for it on the phone "
                f"or via email.\n\n"
                f"Thanks,\n"
                f"The NovaLib Team"
            )
            
            # Updated HTML message with copy functionality
            html_message = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                <img src="https://auslogo.link" alt="NovaLib Logo" style="display: block; margin: 0 auto; width: 50px;">
                <h2 style="text-align: center; color: #333;">Please verify your identity, {user.first_name}</h2>
                <div style="background-color: #f9f9f9; border: 1px solid #ddd; border-radius: 5px; padding: 20px; margin: 20px 0;">
                    <p style="text-align: center; margin-bottom: 10px;">Here is your NovaLib verification code:</p>
                    
                    <!-- Code container with copy button styling -->
                    <div style="position: relative; max-width: 300px; margin: 0 auto;">
                        <!-- The OTP code with special styling -->
                        <div style="background-color: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 12px; 
                                    text-align: center; font-family: monospace; font-size: 24px; font-weight: bold; 
                                    letter-spacing: 4px; margin-bottom: 10px;">
                            {otp}
                        </div>
                        
                        <!-- Copy button with instructions -->
                        <a href="https://novalib-aus.web.app/copy?code={otp}" 
                           style="display: block; text-align: center; background-color: #2EA44F; color: white; 
                                  text-decoration: none; padding: 8px 16px; border-radius: 4px; font-weight: bold; 
                                  margin: 0 auto; width: 100px;">
                            Copy Code
                        </a>
                        <p style="text-align: center; color: #666; font-size: 12px; margin-top: 8px;">
                            Click the button above to open a page where you can easily copy your code
                        </p>
                    </div>
                </div>
                <p>This code is valid for <strong>5 minutes</strong> and can only be used once.</p>
                <p><strong>Please don't share this code with anyone:</strong> we'll never ask for it on the phone or via email.</p>
                <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                <p>Thanks,<br>The NovaLib Team</p>
                
                <!-- Alternative manual copy instructions -->
                <div style="font-size: 12px; color: #666; margin-top: 20px;">
                    <p>If the button doesn't work, you can manually copy this code: <strong>{otp}</strong></p>
                </div>
            </div>
            """
            
            from_email = "sayan.kumar.roy@aus.ac.in"
            
            # Send email with both text and HTML versions
            from django.core.mail import EmailMultiAlternatives
            msg = EmailMultiAlternatives(subject, message, from_email, [email])
            msg.attach_alternative(html_message, "text/html")
            msg.send(fail_silently=False)

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

@csrf_exempt
def book_log_list(request):
    """
    API endpoint to list/search issued books from BooksLog.
    Supports user filters via:
      - ?username= (full display name)
      - ?barcode= or ?barcode_number=
      - ?email=
      - ?user_id=
    And optional ?search= for title/author/barcode.
    If a user is resolved, return only that user's issued books (avalible=False).
    Otherwise, return global list (optionally filtered by ?search).
    """
    if request.method == 'GET':
        search = (request.GET.get('search') or '').strip()
        username = (request.GET.get('username') or '').strip()
        barcode = (request.GET.get('barcode') or request.GET.get('barcode_number') or '').strip()
        email = (request.GET.get('email') or '').strip()
        user_id = (request.GET.get('user_id') or '').strip()

        logs = BooksLog.objects.all().order_by('-issued_date')

        # Resolve users from User table first
        def _norm(s):
            return ' '.join(str(s or '').split()).lower()

        resolved_users = User.objects.none()

        # Priority resolution by strong identifiers
        if barcode:
            resolved_users = User.objects.filter(barcode_number__iexact=barcode)
        elif user_id.isdigit():
            resolved_users = User.objects.filter(id=int(user_id))
        elif email:
            resolved_users = User.objects.filter(email__iexact=email)
        elif username:
            # Broad pre-filter
            parts = [p for p in username.split() if p]
            pre_q = Q(first_name__icontains=username) | Q(last_name__icontains=username)
            if parts:
                pre_q |= Q(first_name__icontains=parts[0]) | Q(last_name__icontains=parts[-1])
            candidates = User.objects.filter(pre_q)

            # Exact-like match on normalized "first last"
            target = _norm(username)
            exact_ids = [u.id for u in candidates if _norm(f"{u.first_name} {u.last_name}") == target]

            if exact_ids:
                resolved_users = User.objects.filter(id__in=exact_ids)
            else:
                # Fallback to candidates if no exact normalized match
                resolved_users = candidates

        if resolved_users.exists():
            # User-scoped issued books only
            logs = logs.filter(user__in=resolved_users, avalible=False)
            if search:
                logs = logs.filter(
                    Q(book_title__icontains=search) |
                    Q(auther__icontains=search) |
                    Q(book_barcode__icontains=search)
                )
        else:
            # No user identified: global listing (for general search)
            if search:
                logs = logs.filter(
                    Q(book_title__icontains=search) |
                    Q(auther__icontains=search) |
                    Q(book_barcode__icontains=search)
                )

        data = []
        for log in logs:
            data.append({
                'book_title': getattr(log, 'book_title', ''),
                'book_author': getattr(log, 'auther', ''),
                'issued_date': getattr(log, 'issued_date', None),
                'return_date': getattr(log, 'return_date', None),
                # Include owner name to help client UX/debug
                'username': (f"{getattr(log.user, 'first_name', '')} {getattr(log.user, 'last_name', '')}").strip() if getattr(log, 'user', None) else '',
            })
        return JsonResponse(data, safe=False)

    return JsonResponse({'error': 'Invalid request'}, status=400)
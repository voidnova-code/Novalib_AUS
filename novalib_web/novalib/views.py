from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.mail import send_mail
from novalib.models import User, Login, Notification, DeveloperNotification
from novalib.models import BooksLog  # fixed import
from novalib.models import BooksDetail  # new import for issued/held book details
from django.utils.timezone import now, timedelta
from django.db.models import Q, Count
import json
import random
from collections import defaultdict

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

def _coerce_bool(v):
    """Coerce DB values like True/False/1/0/'true'/'false'/'yes'/'no' to a Python bool."""
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return v != 0
    s = str(v).strip().lower()
    if s in ('1', 'true', 'yes', 'y'):
        return True
    if s in ('0', 'false', 'no', 'n', ''):
        return False
    # fallback: any other non-empty strings treated as False (safe)
    return False

def _to_int(v):
    """Parse any numeric-like value to int; returns 0 on failure."""
    try:
        if v is None:
            return 0
        if isinstance(v, (int, float)):
            return int(v)
        s = str(v).strip()
        return int(s) if s else 0
    except Exception:
        return 0

def _normalize_key(title, author):
    """Normalize (title, author) tuple for consistent dict lookups."""
    t = (title or '').strip()
    a = (author or '').strip()
    return (t.lower(), a.lower())

@csrf_exempt
def book_log_list(request):
    """
    API endpoint to list/search issued books from BooksLog.
    Supports user filters via:
      - ?username= (full display name) or X-User header
      - ?barcode= or ?barcode_number= or X-User-Barcode header
      - ?email=
      - ?user_id= or X-User-Id header
    And optional ?search= for title/author/barcode.
    If a user is resolved, return only that user's issued books (sourced from BooksDetail).
    Otherwise, return global BooksLog list (optionally filtered by ?search).
    """
    if request.method == 'GET':
        search = (request.GET.get('search') or '').strip()
        username = (request.GET.get('username') or '').strip()
        barcode = (request.GET.get('barcode') or request.GET.get('barcode_number') or '').strip()
        email = (request.GET.get('email') or '').strip()
        user_id = (request.GET.get('user_id') or '').strip()
        wishlist_param = (request.GET.get('wishlist') or '').strip().lower()
        avalible_param = (request.GET.get('avalible') or '').strip().lower()

        # also accept user identity from headers (helpful for app pages that cannot set query params)
        header_user = (request.META.get('HTTP_X_USER') or request.META.get('HTTP_X_USERNAME') or '').strip()
        header_barcode = (request.META.get('HTTP_X_USER_BARCODE') or request.META.get('HTTP_X_BARCODE') or '').strip()
        header_user_id = (request.META.get('HTTP_X_USER_ID') or '').strip()

        # prefer explicit query params; fall back to headers
        if not username and header_user:
            username = header_user
        if not barcode and header_barcode:
            barcode = header_barcode
        if not user_id and header_user_id:
            user_id = header_user_id

        # issued_date was moved to BooksDetail; order by id here to avoid FieldError.
        logs = BooksLog.objects.all().order_by('-id')

        # Resolve users first if any identifier is provided
        users_qs = None
        if barcode or user_id or email or username:
            users = User.objects.all()
            q = Q()
            if barcode:
                q |= Q(barcode_number__iexact=barcode)
            if user_id.isdigit():
                q |= Q(id=int(user_id))
            if email:
                q |= Q(email__iexact=email)
            if username:
                parts = [p for p in username.split() if p]
                if len(parts) >= 2:
                    q |= (Q(first_name__iexact=parts[0]) & Q(last_name__iexact=parts[-1]))
                # broaden username matching (either name part matches)
                q |= Q(first_name__icontains=username) | Q(last_name__icontains=username)
                # also try if someone passes barcode/email via username param
                q |= Q(barcode_number__iexact=username) | Q(email__iexact=username)
            users_qs = users.filter(q)

        # REMOVE any global pre-aggregation of counts
        # Parse avalible filter if provided
        avalible_value = None
        if avalible_param in ('1', 'true', 'yes'):
            avalible_value = True
        elif avalible_param in ('0', 'false', 'no'):
            avalible_value = False

        # Wishlist branch (still uses BooksLog)
        if users_qs is not None and wishlist_param in ('1', 'true', 'yes'):
            logs = BooksLog.objects.filter(wishlist__in=users_qs).distinct()
            if search:
                logs = logs.filter(
                    Q(book_title__icontains=search) |
                    Q(auther__icontains=search) |
                    Q(book_barcode__icontains=search)
                )

        # Issued-books branch
        elif users_qs is not None:
            details = BooksDetail.objects.filter(user__in=users_qs)
            if avalible_value is None:
                details = details.filter(avalible=False)
            else:
                details = details.filter(avalible=avalible_value)
            if search:
                details = details.filter(
                    Q(book_title__icontains=search) |
                    Q(auther__icontains=search) |
                    Q(book_barcode__icontains=search)
                )

            # Pre-compute available_count per (title, author) from BooksDetail (unassigned + available)
            avail_count_map = {}
            for row in (BooksDetail.objects
                        .filter(user__isnull=True, avalible=True)
                        .values('book_title', 'auther')
                        .annotate(c=Count('id'))):
                key = _normalize_key(row.get('book_title'), row.get('auther'))
                avail_count_map[key] = row['c']

            data = []
            for d in details.order_by('-id'):
                title = (getattr(d, 'book_title', '') or '').strip()
                author = (getattr(d, 'auther', '') or '').strip()
                key = _normalize_key(title, author)
                avail_count = int(avail_count_map.get(key, 0))
                data.append({
                    'book_title': title,
                    'book_author': author,
                    'book_barcode': getattr(d, 'book_barcode', ''),
                    'available': (avail_count > 0),
                    'available_count': avail_count,
                    'issued_date': getattr(d, 'issued_date', None),
                    'return_date': getattr(d, 'return_date', None),
                    'username': (f"{getattr(d.user, 'first_name', '')} {getattr(d.user, 'last_name', '')}").strip() if getattr(d, 'user', None) else '',
                })
            return JsonResponse(data, safe=False)

        else:
            # Global listing/search (no user identified)
            if avalible_value is not None:
                logs = logs.filter(avalible=avalible_value)
            if search:
                logs = logs.filter(
                    Q(book_title__icontains=search) |
                    Q(auther__icontains=search) |
                    Q(book_barcode__icontains=search)
                )

        # Pre-compute available_count per (title, author) for global listing from BooksDetail (unassigned + available)
        avail_count_map = {}
        for row in (BooksDetail.objects
                    .filter(user__isnull=True, avalible=True)
                    .values('book_title', 'auther')
                    .annotate(c=Count('id'))):
            key = _normalize_key(row.get('book_title'), row.get('auther'))
            avail_count_map[key] = row['c']

        data = []
        for log in logs:
            title = (getattr(log, 'book_title', '') or '').strip()
            author = (getattr(log, 'auther', '') or '').strip()
            key = _normalize_key(title, author)
            avail_count = int(avail_count_map.get(key, 0))
            data.append({
                'book_title': title,
                'book_author': author,
                'book_barcode': getattr(log, 'book_barcode', ''),
                'available': (avail_count > 0),
                'available_count': avail_count,
                'issued_date': getattr(log, 'issued_date', None),
                'return_date': getattr(log, 'return_date', None),
                'username': (f"{getattr(log.user, 'first_name', '')} {getattr(log.user, 'last_name', '')}").strip() if getattr(log, 'user', None) else '',
            })
        return JsonResponse(data, safe=False)

    return JsonResponse({'error': 'Invalid request'}, status=400)

@csrf_exempt
def user_wishlist(request):
    """
    GET wishlist items for a user resolved from the User table.
    Accepts one of:
      - ?barcode= or ?barcode_number=
      - ?user_id=
      - ?email=
      - ?username= (full name or parts)
    Optional:
      - ?search= (title/author/barcode)
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'Invalid request'}, status=400)

    search = (request.GET.get('search') or '').strip()
    username = (request.GET.get('username') or '').strip()
    barcode = (request.GET.get('barcode') or request.GET.get('barcode_number') or '').strip()
    email = (request.GET.get('email') or '').strip()
    user_id = (request.GET.get('user_id') or '').strip()

    # Resolve user(s) from User table
    users_qs = User.objects.none()
    q = Q()
    if barcode:
        q |= Q(barcode_number__iexact=barcode)
    if user_id.isdigit():
        q |= Q(id=int(user_id))
    if email:
        q |= Q(email__iexact=email)
    if username:
        parts = [p for p in username.split() if p]
        if len(parts) >= 2:
            q |= (Q(first_name__iexact=parts[0]) & Q(last_name__iexact=parts[-1]))
        q |= Q(first_name__icontains=username) | Q(last_name__icontains=username)
    if q:
        users_qs = User.objects.filter(q)

    if not users_qs.exists():
        return JsonResponse([], safe=False)

    # Fetch BooksLog entries where wishlist includes the resolved users
    logs = BooksLog.objects.filter(wishlist__in=users_qs).distinct().order_by('-id')

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
            'book_barcode': getattr(log, 'book_barcode', ''),
            'available': _coerce_bool(getattr(log, 'avalible', False)),  # was bool(...), now coerced
            # include wishlist users for debugging if needed
            'wishlist_users': [f"{u.first_name} {u.last_name}".strip() for u in log.wishlist.all()],
        })
    return JsonResponse(data, safe=False)

@csrf_exempt
def book_suggestions(request):
    """
    GET /book-suggestions/?search=term
    Returns up to 20 distinct suggestions with minimal fields:
      - book_title, book_author
    """
    if request.method != 'GET':
      return JsonResponse({'error': 'Invalid request'}, status=400)
    q = (request.GET.get('search') or '').strip()
    if not q:
      return JsonResponse([], safe=False)

    qs = (BooksLog.objects
          .filter(Q(book_title__icontains=q) |
                  Q(auther__icontains=q) |
                  Q(book_barcode__icontains=q))
          .values('book_title', 'auther')
          .distinct()[:20])

    # Ensure unique titles in Python as well (extra safety)
    seen = set()
    data = []
    for row in qs:
        title = (row.get('book_title') or '').strip()
        if not title or title in seen:
            continue
        seen.add(title)
        data.append({
            'book_title': title,
            'book_author': (row.get('auther') or '').strip(),
        })

    return JsonResponse(data, safe=False)

@csrf_exempt
def wishlist(request):
    """
    Wishlist endpoint:
      - POST: add a book to a user's wishlist
      - DELETE: remove a book from a user's wishlist
      - GET: proxy to user_wishlist (use same query params)
    Expected user identifiers (any one):
      - user_barcode / barcode_number / email / user_id / username
    Expected book identifiers (prefer in this order):
      - book_barcode, or (title + author)
      - optionally 'isbn' will be tried against book_barcode too
    """
    if request.method == 'GET':
        # Reuse existing listing behavior
        return user_wishlist(request)

    if request.method not in ('POST', 'DELETE'):
        return JsonResponse({'error': 'Invalid request'}, status=400)

    try:
        data = json.loads(request.body.decode('utf-8') or '{}')
    except Exception:
        data = {}

    # Resolve user
    def _resolve_user():
        username = (data.get('username') or '').strip()
        email = (data.get('email') or '').strip()
        user_id = (str(data.get('user_id') or '')).strip()
        # Prefer explicit user_barcode to avoid clashing with book_barcode
        user_barcode = (data.get('user_barcode') or data.get('barcode_number') or '').strip()
        # As a last resort, if client only sent 'barcode' and no book_barcode, treat it as user barcode
        if not user_barcode and not data.get('book_barcode'):
            user_barcode = (data.get('barcode') or '').strip()

        q = Q()
        if user_barcode:
            q |= Q(barcode_number__iexact=user_barcode)
        if user_id.isdigit():
            q |= Q(id=int(user_id))
        if email:
            q |= Q(email__iexact=email)
        if username:
            parts = [p for p in username.split() if p]
            if len(parts) >= 2:
                q |= (Q(first_name__iexact=parts[0]) & Q(last_name__iexact=parts[-1]))
            q |= Q(first_name__icontains=username) | Q(last_name__icontains=username)
            # also try if someone passed barcode/email via username param
            q |= Q(barcode_number__iexact=username) | Q(email__iexact=username)

        return User.objects.filter(q).first()

    user = _resolve_user()
    if not user:
        return JsonResponse({'error': 'User not found for wishlist operation'}, status=404)

    # Resolve book
    book_barcode = (data.get('book_barcode') or '').strip()
    isbn = (data.get('isbn') or '').strip()
    title = (data.get('title') or data.get('book_title') or '').strip()
    author = (data.get('author') or data.get('book_author') or data.get('auther') or '').strip()

    books_qs = BooksLog.objects.all()

    if book_barcode:
        books_qs = books_qs.filter(book_barcode__iexact=book_barcode)
    elif isbn:
        # Try matching ISBN against barcode if your DB stores it there
        books_qs = books_qs.filter(Q(book_barcode__iexact=isbn) | Q(book_title__iexact=title) | Q(auther__iexact=author))
    elif title:
        qs = Q(book_title__iexact=title)
        if author:
            qs &= Q(auther__iexact=author)
        books_qs = books_qs.filter(qs)
    else:
        return JsonResponse({'error': 'Insufficient book identifiers'}, status=400)

    if not books_qs.exists():
        # Relax matching if strict match failed
        relaxed = BooksLog.objects.all()
        if book_barcode:
            relaxed = relaxed.filter(book_barcode__icontains=book_barcode)
        elif title:
            q = Q(book_title__icontains=title)
            if author:
                q &= Q(auther__icontains=author)
            relaxed = relaxed.filter(q)
        if not relaxed.exists():
            return JsonResponse({'error': 'Book not found for wishlist'}, status=404)
        books_qs = relaxed

    # Prefer an available copy if multiple entries
    book = books_qs.filter(avalible=True).first() or books_qs.first()

    if request.method == 'POST':
        book.wishlist.add(user)
        return JsonResponse({
            'message': 'Added to wishlist',
            'book_title': getattr(book, 'book_title', ''),
            'book_author': getattr(book, 'auther', ''),
            'book_barcode': getattr(book, 'book_barcode', ''),
            'user': {'id': user.id, 'name': f'{user.first_name} {user.last_name}'.strip()},
        }, status=200)

    # DELETE
    book.wishlist.remove(user)
    return JsonResponse({
        'message': 'Removed from wishlist',
        'book_title': getattr(book, 'book_title', ''),
        'book_author': getattr(book, 'auther', ''),
        'book_barcode': getattr(book, 'book_barcode', ''),
        'user': {'id': user.id, 'name': f'{user.first_name} {user.last_name}'.strip()},
    }, status=200)

@csrf_exempt
def books_detail_list(request):
    """
    API endpoint to list/search issued books from BooksDetail.
    Supports same filters as book_log_list:
      - ?username=, ?barcode=, ?email=, ?user_id=
      - ?search= for title/author/barcode
      - ?avalible= (true/false)
    If a user is resolved, return BooksDetail rows assigned to that user.
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'Invalid request'}, status=400)
    
    search = (request.GET.get('search') or '').strip()
    username = (request.GET.get('username') or '').strip()
    barcode = (request.GET.get('barcode') or request.GET.get('barcode_number') or '').strip()
    email = (request.GET.get('email') or '').strip()
    user_id = (request.GET.get('user_id') or '').strip()
    avalible_param = (request.GET.get('avalible') or '').strip().lower()

    qs = BooksDetail.objects.all().order_by('-id')

    # Resolve users if identifier provided (reuse logic similar to book_log_list)
    users_qs = None
    if barcode or user_id or email or username:
        users = User.objects.all()
        q = Q()
        if barcode:
            q |= Q(barcode_number__iexact=barcode)
        if user_id.isdigit():
            q |= Q(id=int(user_id))
        if email:
            q |= Q(email__iexact=email)
        if username:
            parts = [p for p in username.split() if p]
            if len(parts) >= 2:
                q |= (Q(first_name__iexact=parts[0]) & Q(last_name__iexact=parts[-1]))
            q |= Q(first_name__icontains=username) | Q(last_name__icontains=username)
            q |= Q(barcode_number__iexact=username) | Q(email__iexact=username)
        users_qs = users.filter(q)

    # parse avalible filter
    avalible_value = None
    if avalible_param in ('1', 'true', 'yes'):
        avalible_value = True
    elif avalible_param in ('0', 'false', 'no'):
        avalible_value = False

    # If user(s) resolved: return only books assigned to those users
    if users_qs is not None:
        qs = qs.filter(user__in=users_qs)
        # optionally filter by availability if provided
        if avalible_value is not None:
            qs = qs.filter(avalible=avalible_value)
        # search filtering
        if search:
            qs = qs.filter(
                Q(book_title__icontains=search) |
                Q(auther__icontains=search) |
                Q(book_barcode__icontains=search)
            )
    else:
        # global listing/search
        if avalible_value is not None:
            qs = qs.filter(avalible=avalible_value)
        if search:
            qs = qs.filter(
                Q(book_title__icontains=search) |
                Q(auther__icontains=search) |
                Q(book_barcode__icontains=search)
            )

    data = []
    for item in qs:
        data.append({
            'book_title': getattr(item, 'book_title', ''),
            'book_author': getattr(item, 'auther', ''),
            'book_barcode': getattr(item, 'book_barcode', ''),
            'available': _coerce_bool(getattr(item, 'avalible', False)),  # fixed
            'issued_date': getattr(item, 'issued_date', None),
            'return_date': getattr(item, 'return_date', None),
            'username': (f"{getattr(item.user, 'first_name', '')} {getattr(item.user, 'last_name', '')}").strip() if getattr(item, 'user', None) else '',
        })
    return JsonResponse(data, safe=False)
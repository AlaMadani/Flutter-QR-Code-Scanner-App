from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from firebase_config import db
from django.http import JsonResponse, HttpResponse
import re
import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors
from io import BytesIO
import os
from PIL import Image

@login_required
def firestore_dashboard(request):
    if not request.user.is_authenticated:
        return redirect('admin:login')

    # Get filter parameters from GET request
    user_filter_id = request.GET.get('user_filter_id', '').lower()
    user_filter_name = request.GET.get('user_filter_name', '').lower()
    user_filter_role = request.GET.get('user_filter_role', '').lower()
    video_filter_id = request.GET.get('video_filter_id', '').lower()

    # Fetch and filter users
    users = [{'id': doc.id, **doc.to_dict()} for doc in db.collection('users').stream() if doc.exists]
    if user_filter_id:
        users = [user for user in users if user_filter_id in user['id'].lower()]
    if user_filter_name:
        users = [user for user in users if user_filter_name in user.get('name', '').lower()]
    if user_filter_role:
        users = [user for user in users if user_filter_role in user.get('role', '').lower()]

    # Fetch and filter videos
    videos = []
    for doc in db.collection('videos').stream():
        if doc.exists:
            data = doc.to_dict()
            video_id = data.get('videoUrl', '')
            if 'youtube.com/watch' in video_id:
                match = re.search(r'v=([^\&]+)', video_id)
                video_id = match.group(1) if match else ''
            elif 'youtu.be' in video_id:
                match = re.search(r'youtu.be/([^\?]+)', video_id)
                video_id = match.group(1) if match else ''
            else:
                video_id = ''
            videos.append({'id': doc.id, 'videoUrl': data.get('videoUrl', ''), 'videoId': video_id})
    if video_filter_id:
        videos = [video for video in videos if video_filter_id in video['id'].lower()]

    # Fetch app URL
    app_url_doc = db.collection('App').document('appurl').get()
    app_url = app_url_doc.to_dict().get('url', '') if app_url_doc.exists else ''

    if request.method == 'POST' and 'delete_user' in request.POST:
        user_id = request.POST['user_id']
        try:
            db.collection('users').document(user_id).delete()
            messages.success(request, 'User deleted successfully!')
        except Exception as e:
            messages.error(request, f'Failed to delete user: {str(e)}')
        return redirect('firestore_dashboard')

    if request.method == 'POST' and 'delete_video' in request.POST:
        video_id = request.POST['video_id']
        try:
            db.collection('videos').document(video_id).delete()
            messages.success(request, 'Video deleted successfully!')
        except Exception as e:
            messages.error(request, f'Failed to delete video: {str(e)}')
        return redirect('firestore_dashboard')

    context = {
        'users': users,
        'videos': videos,
        'user_filter_id': user_filter_id,
        'user_filter_name': user_filter_name,
        'user_filter_role': user_filter_role,
        'video_filter_id': video_filter_id,
        'app_url': app_url,
    }
    return render(request, 'firestore_dashboard.html', context)

@login_required
def add_user(request):
    if request.method == 'POST':
        user_id = request.POST['id']
        name = request.POST['name']
        role = request.POST['role']
        try:
            db.collection('users').document(user_id).set({'name': name, 'role': role})
            messages.success(request, 'User added successfully!')
        except Exception as e:
            messages.error(request, f'Failed to add user: {str(e)}')
        return redirect('firestore_dashboard')
    return render(request, 'firestore_dashboard.html')

@login_required
def update_user(request, user_id):
    if request.method == 'POST':
        name = request.POST['name']
        role = request.POST['role']
        try:
            db.collection('users').document(user_id).update({'name': name, 'role': role})
            messages.success(request, 'User updated successfully!')
        except Exception as e:
            messages.error(request, f'Failed to update user: {str(e)}')
        return redirect('firestore_dashboard')
    user = db.collection('users').document(user_id).get().to_dict() or {}
    return render(request, 'firestore_dashboard.html', {'edit_user': user, 'user_id': user_id})

@login_required
def add_video(request):
    if request.method == 'POST':
        video_id = request.POST['id']
        video_url = request.POST['video_url']
        try:
            db.collection('videos').document(video_id).set({'videoUrl': video_url})
            messages.success(request, 'Video added successfully!')
        except Exception as e:
            messages.error(request, f'Failed to add video: {str(e)}')
        return redirect('firestore_dashboard')
    return render(request, 'firestore_dashboard.html')

@login_required
def update_video(request, video_id):
    if request.method == 'POST':
        video_url = request.POST['video_url']
        try:
            db.collection('videos').document(video_id).update({'videoUrl': video_url})
            messages.success(request, 'Video updated successfully!')
        except Exception as e:
            messages.error(request, f'Failed to update video: {str(e)}')
        return redirect('firestore_dashboard')
    video = db.collection('videos').document(video_id).get().to_dict() or {}
    return render(request, 'firestore_dashboard.html', {'edit_video': video, 'video_id': video_id})

@login_required
def update_app_url(request):
    if request.method == 'POST':
        app_url = request.POST['app_url']
        try:
            db.collection('App').document('appurl').set({'url': app_url})
            messages.success(request, 'App URL updated successfully!')
        except Exception as e:
            messages.error(request, f'Failed to update app URL: {str(e)}')
        return redirect('firestore_dashboard')
    app_url_doc = db.collection('App').document('appurl').get()
    app_url = app_url_doc.to_dict().get('url', '') if app_url_doc.exists else ''
    return render(request, 'firestore_dashboard.html', {'edit_app_url': app_url})

@login_required
def generate_qr_code(request):
    if request.method == 'POST':
        qr_text = request.POST.get('qr_text', '')
        if not qr_text:
            messages.error(request, 'No text provided for QR code.')
            return redirect('firestore_dashboard')

        try:
            # Generate main QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=1,
            )
            qr.add_data(qr_text)
            qr.make(fit=True)
            qr_img = qr.make_image(fill_color="black", back_color="white")

            # Generate app URL QR code
            app_url_doc = db.collection('App').document('appurl').get()
            app_url = app_url_doc.to_dict().get('url', '') if app_url_doc.exists else ''
            app_qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=5,  # Smaller size for app QR code
                border=2,
            )
            app_qr.add_data(app_url)
            app_qr.make(fit=True)
            app_qr_img = app_qr.make_image(fill_color="black", back_color="white")

            # Load Android logo and overlay it on the app QR code
            android_logo_path = os.path.join(os.path.dirname(__file__), 'android_logo.png')
            android_logo_img = Image.open(android_logo_path)
            if android_logo_img.mode != 'RGBA':
                android_logo_img = android_logo_img.convert('RGBA')
            
            # Resize Android logo to fit in the center (20% of QR code size)
            app_qr_size_pixels = app_qr_img.size[0]  # Assuming square QR code
            android_logo_size_pixels = int(app_qr_size_pixels * 0.2)  # 20% of QR code size
            android_logo_img = android_logo_img.resize((android_logo_size_pixels, android_logo_size_pixels), Image.Resampling.LANCZOS)
            
            # Calculate position to center the logo
            logo_position = ((app_qr_size_pixels - android_logo_size_pixels) // 2, 
                           (app_qr_size_pixels - android_logo_size_pixels) // 2)
            
            # Create a new image for the combined QR code and logo
            combined_qr_img = Image.new('RGBA', app_qr_img.size, (255, 255, 255, 0))
            combined_qr_img.paste(app_qr_img.convert('RGBA'), (0, 0))
            combined_qr_img.paste(android_logo_img, logo_position, android_logo_img)
            
            # Create a new BytesIO buffer for the PDF
            buffer = BytesIO()
            c = canvas.Canvas(buffer, pagesize=A4)
            width, height = A4

            # Save main QR code image to a separate BytesIO buffer
            img_buffer = BytesIO()
            qr_img.save(img_buffer, format="PNG")
            img_data = img_buffer.getvalue()
            img_buffer.close()

            # Save combined app QR code image to a separate BytesIO buffer
            app_img_buffer = BytesIO()
            combined_qr_img.save(app_img_buffer, format="PNG")
            app_img_data = app_img_buffer.getvalue()
            app_img_buffer.close()

            # Use ImageReader to handle the QR code images
            img_reader = ImageReader(BytesIO(img_data))
            app_img_reader = ImageReader(BytesIO(app_img_data))

            # Position main QR code (moved up)
            main_qr_size = 300  # Main QR code size in points
            main_qr_x = (width - main_qr_size) / 2  # Center horizontally
            main_qr_y = (height - main_qr_size) / 2 + 90  # Move up 90 points

            # Position app QR code (below main QR code)
            app_qr_size = 100  # Smaller size for app QR code
            app_qr_x = (width - app_qr_size) / 2  # Center horizontally
            app_qr_y = main_qr_y - app_qr_size - 180  # 180 points below main QR code

            # Add a header
            c.setFont("Helvetica-Bold", 24)
            c.setFillColor(colors.darkblue)
            c.drawCentredString(width / 2, height - 160, qr_text)

            # Draw a border around the main QR code
            c.setStrokeColor(colors.grey)
            c.setLineWidth(2)
            c.rect(main_qr_x - 10, main_qr_y - 10, main_qr_size + 20, main_qr_size + 20, stroke=1, fill=0)

            # Draw main QR code
            c.drawImage(img_reader, main_qr_x, main_qr_y, width=main_qr_size, height=main_qr_size)

            # Draw a border around the app QR code
            c.setStrokeColor(colors.grey)
            c.setLineWidth(2)
            border_width = app_qr_size + 10  # Reduced border size since no logo or label
            border_height = app_qr_size + 10
            border_x = (width - border_width) / 2
            border_y = app_qr_y - 5
            c.rect(border_x, border_y, border_width, border_height, stroke=1, fill=0)

            # Draw app QR code
            c.drawImage(app_img_reader, app_qr_x, app_qr_y, width=app_qr_size, height=app_qr_size)

            # Add label for app QR code
            c.setFont("Helvetica", 12)
            c.setFillColor(colors.black)
            c.drawCentredString(width / 2, app_qr_y - 20, "Download Our App")

            # Add logo in top right corner of the page with transparency
            logo_path = os.path.join(os.path.dirname(__file__), 'logo.png')
            logo_size = 70  # Logo size in points
            logo_x = width - logo_size - 15  # 15 points margin from right
            logo_y = height - logo_size - 8  # 8 points margin from top
            logo_img = Image.open(logo_path)
            if logo_img.mode != 'RGBA':
                logo_img = logo_img.convert('RGBA')
            logo_buffer = BytesIO()
            logo_img.save(logo_buffer, format="PNG")
            logo_data = logo_buffer.getvalue()
            logo_buffer.close()
            c.drawImage(ImageReader(BytesIO(logo_data)), logo_x, logo_y, width=logo_size, height=logo_size, mask='auto')

            # Add footer with generation date
            from datetime import datetime
            c.setFont("Helvetica-Oblique", 10)
            c.setFillColor(colors.grey)
            c.drawCentredString(width / 2, 30, f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

            c.showPage()
            c.save()

            # Prepare response
            buffer.seek(0)
            response = HttpResponse(content_type='application/pdf')
            response['Content-Disposition'] = 'inline; filename="qr_code.pdf"'
            response.write(buffer.getvalue())
            buffer.close()
            return response
        except Exception as e:
            messages.error(request, f'Failed to generate QR code: {str(e)}')
            return redirect('firestore_dashboard')
    return redirect('firestore_dashboard')
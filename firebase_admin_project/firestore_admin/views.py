from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from firebase_config import db
from django.http import JsonResponse, HttpResponse
import re
import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from io import BytesIO

@login_required
def firestore_dashboard(request):
    if not request.user.is_authenticated:
        return redirect('admin:login')

    users = [{'id': doc.id, **doc.to_dict()} for doc in db.collection('users').stream() if doc.exists]
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
def generate_qr_code(request):
    if request.method == 'POST':
        qr_text = request.POST.get('qr_text', '')
        if not qr_text:
            messages.error(request, 'No text provided for QR code.')
            return redirect('firestore_dashboard')

        try:
            # Generate QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(qr_text)
            qr.make(fit=True)
            qr_img = qr.make_image(fill_color="black", back_color="white")

            # Create PDF
            buffer = BytesIO()
            c = canvas.Canvas(buffer, pagesize=A4)
            width, height = A4

            # Convert QR code image to a format reportlab can use
            qr_img.save(buffer, format="PNG")
            buffer.seek(0)
            from reportlab.graphics.shapes import Image
            img = Image(100, height - 400, 300, 300, buffer.getvalue())

            # Draw QR code and text on PDF
            c.drawString(100, height - 100, f"QR Code for: {qr_text}")
            c.drawImage(img, 100, height - 400)
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
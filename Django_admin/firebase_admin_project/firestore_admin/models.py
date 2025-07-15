from django.db import models
from firebase_config import db

class FirestoreUser(models.Model):
      id = models.CharField(max_length=100, primary_key=True)  # Device ID as document ID
      name = models.CharField(max_length=100)
      role = models.CharField(max_length=50)

      class Meta:
          app_label = 'firestore_admin'
          managed = False  # Mark as unmanaged to prevent Django from managing the table

      def save(self, *args, **kwargs):
          db.collection('users').document(self.id).set({
              'name': self.name,
              'role': self.role
          })

      def delete(self, *args, **kwargs):
          db.collection('users').document(self.id).delete()

      @classmethod
      def get_all(cls):
          docs = db.collection('users').stream()
          return [cls(id=doc.id, name=doc.to_dict().get('name'), role=doc.to_dict().get('role')) for doc in docs if doc.exists]

      def __str__(self):
          return f"{self.name} ({self.role})"

class FirestoreVideo(models.Model):
      id = models.CharField(max_length=200, primary_key=True)  # QR code + role as document ID
      video_url = models.URLField()

      class Meta:
          app_label = 'firestore_admin'
          managed = False  # Mark as unmanaged

      def save(self, *args, **kwargs):
          db.collection('videos').document(self.id).set({
              'videoUrl': self.video_url
          })

      def delete(self, *args, **kwargs):
          db.collection('videos').document(self.id).delete()

      @classmethod
      def get_all(cls):
          docs = db.collection('videos').stream()
          return [cls(id=doc.id, video_url=doc.to_dict().get('videoUrl')) for doc in docs if doc.exists]

      def __str__(self):
          return self.id
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Initialize Firebase Admin SDK
cred = credentials.Certificate("firebase.json")
firebase_admin.initialize_app(cred)

# Initialize Firestore client
db = firestore.client()
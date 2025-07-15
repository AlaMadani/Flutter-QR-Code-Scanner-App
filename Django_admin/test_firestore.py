from firebase_config import db

def test_firestore():
        try:
            # Add a test document
            db.collection('test').document('test_doc').set({'test_field': 'Hello, Firestore!'})
            print("Firestore connection successful!")
        except Exception as e:
            print(f"Firestore connection failed: {str(e)}")

if __name__ == "__main__":
    test_firestore()
import os
import json
import logging
from typing import List, Dict, Any, Optional
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import google.generativeai as genai
import requests
import re
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta

# Load environment variables
load_dotenv()

# API Keys and Configuration
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
SERPER_API_KEY = os.getenv("SERPER_API_KEY")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")

# Validate required environment variables
required_vars = {
    "GOOGLE_API_KEY": GOOGLE_API_KEY,
    "SERPER_API_KEY": SERPER_API_KEY,
    "FIREBASE_CREDENTIALS_PATH": FIREBASE_CREDENTIALS_PATH
}

for var_name, var_value in required_vars.items():
    if not var_value:
        raise RuntimeError(f"{var_name} is missing in the environment variables.")

# Initialize Firebase Admin
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Configure Google AI
genai.configure(api_key=GOOGLE_API_KEY)

# Initialize Flask with CORS
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})
logging.basicConfig(level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")

def get_cached_recommendations(user_id: str) -> Optional[List[Dict[str, Any]]]:
    """
    Retrieve cached recommendations for a user if they exist and aren't expired.
    Cache expires after 24 hours.
    """
    try:
        doc_ref = db.collection('users').document(user_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            return None
            
        data = doc.to_dict()
        last_updated = data.get('lastUpdated')
        
        # Check if cache is expired (24 hours)
        if last_updated:
            last_updated = last_updated.replace(tzinfo=None)
            if datetime.now() - last_updated > timedelta(hours=24):
                return None
                
        return data.get('recommendations')
    except Exception as e:
        logging.error(f"Error retrieving cached recommendations: {e}")
        return None

def is_valid_url(url: str) -> bool:
    """Validate if a given string is a valid URL."""
    try:
        return url.startswith(('http://', 'https://')) and not url.endswith(('.gif', '.svg'))
    except Exception:
        return False

def clean_ai_response(response_text: str) -> str:
    """Clean the AI response by removing markdown code blocks and formatting."""
    try:
        cleaned = re.sub(r'```(?:json)?\s*([\s\S]*?)\s*```', r'\1', response_text)
        return cleaned.strip()
    except Exception as e:
        logging.error(f"Error cleaning AI response: {e}")
        return response_text

def fetch_destination_images(destination: str, num_images: int = 4) -> List[str]:
    """Fetch images for a destination using Serper Image Search API."""
    headers = {
        "X-API-KEY": SERPER_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "q": f"{destination} tourist attractions landmarks scenic high resolution",
        "num": num_images * 2
    }
    try:
        response = requests.post(
            "https://google.serper.dev/images",
            headers=headers,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        image_results = response.json().get('images', [])
        
        valid_images = [img['imageUrl'] for img in image_results if is_valid_url(img.get('imageUrl', ''))][:num_images]
        return valid_images if valid_images else ['https://via.placeholder.com/400x250?text=No+Image+Available']
    except requests.RequestException as e:
        logging.error(f"Error fetching images for {destination}: {e}")
        return ['https://via.placeholder.com/400x250?text=No+Image+Available']

def format_recommendation(rec: Dict[str, Any]) -> Dict[str, Any]:
    """Format the recommendation to match the frontend's expected structure."""
    try:
        destination_name = rec.get("destination", "Unknown Destination").strip()
        activities = rec.get("activities", [])
        if isinstance(activities, str):
            activities = [act.strip() for act in activities.split(',')][:3]
        while len(activities) < 3:
            activities.append("Explore local attractions")

        return {
            "id": str(abs(hash(destination_name))),
            "name": destination_name,
            "description": rec.get("description", "No description available.").strip(),
            "activities": activities,
            "budget": rec.get("budget", "$100-$200 per day").strip(),
            "bestTimeToVisit": rec.get("bestTimeToVisit", "Year-round").strip(),
            "travelTip": rec.get("travelTip", "Plan ahead.").strip(),
            "images": rec.get("images", []),
            "bookingUrl": f"https://booking.com/destination/{destination_name.lower().replace(' ', '-')}"
        }
    except Exception as e:
        logging.error(f"Error formatting recommendation: {e}")
        return {
            "id": "error",
            "name": "Error Processing Destination",
            "description": "An error occurred while processing this destination.",
            "activities": ["Explore local attractions", "Visit cultural sites", "Experience local cuisine"],
            "budget": "$100-$200 per day",
            "bestTimeToVisit": "Year-round",
            "travelTip": "Book accommodations in advance",
            "images": ['https://via.placeholder.com/400x250?text=Error'],
            "bookingUrl": "https://booking.com"
        }

def store_user_recommendations(user_id: str, recommendations: List[Dict[str, Any]], preferences: Dict[str, Any]) -> bool:
    """Store user recommendations and preferences in Firestore."""
    try:
        doc_ref = db.collection('users').document(user_id)
        doc_ref.set({
            'recommendations': recommendations,
            'preferences': preferences,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        }, merge=True)
        return True
    except Exception as e:
        logging.error(f"Error storing recommendations: {e}")
        return False

@app.route('/recommendations', methods=['POST'])
def generate_recommendations():
    """Generate and store travel recommendations based on quiz responses."""
    logging.debug("Received travel quiz submission.")
    try:
        data = request.get_json()
        user_id = data.get('userId')
        
        if not user_id:
            return jsonify({"error": "User ID is required"}), 400
            
        # Check cache first
        cached_recommendations = get_cached_recommendations(user_id)
        if cached_recommendations:
            return jsonify(cached_recommendations), 200
        
        # Extract preferences
        preferences = {
            'travelStyle': data.get('travelStyle', ''),
            'groupType': data.get('groupType', ''),
            'duration': data.get('duration', ''),
            'vibes': data.get('vibes', []),
            'budget': data.get('budget', ''),
            'mustHaves': data.get('mustHaves', [])
        }
        
        # Generate prompt for AI
        prompt = f"""
        Generate 3 unique travel destination recommendations based on these preferences:
        -
        - Travel Style: {preferences['travelStyle']}
        - Group Type: {preferences['groupType']}
        - Duration: {preferences['duration']}
        - Desired Vibes: {', '.join(preferences['vibes'])}
        - Budget Level: {preferences['budget']}
        - Must-Have Features: {', '.join(preferences['mustHaves'])}

        For each destination, provide:
        1. destination 
        2. description (2-3 sentences about why it's perfect for them)
        3. activities (3 must-do activities that match their preferences)
        4. budget (estimated daily cost range)
        5. bestTimeToVisit (best season or months)
        6. travelTip (one key tip based on their preferences)

        Format as a valid JSON array. Example:
        [
            {{
                "destination": "Bali, Indonesia",
                "description": "Bali is perfect for...",
                "activities": ["Visit Ubud Monkey Forest", "Relax on Seminyak Beach", "Explore Uluwatu Temple"],
                "budget": "$50-$100 per day",
                "bestTimeToVisit": "April to October",
                "travelTip": "Rent a scooter for easy transportation."
            }},
            {{
                "destination": "Kyoto, Japan",
                "description": "Kyoto offers...",
                "activities": ["Visit Fushimi Inari Shrine", "Explore Arashiyama Bamboo Grove", "Experience a tea ceremony"],
                "budget": "$100-$200 per day",
                "bestTimeToVisit": "March to May",
                "travelTip": "Book accommodations early during cherry blossom season."
            }}
        ]
        """
        
        # Generate recommendations using Google AI
        model = genai.GenerativeModel('gemini-2.0-flash')
        response = model.generate_content(prompt)
        
        if not response.text:
            return jsonify({"error": "Failed to generate recommendations."}), 500
        
        # Clean and validate the AI response
        cleaned_response = clean_ai_response(response.text)
        logging.debug(f"Raw AI response: {response.text}")
        logging.debug(f"Cleaned AI response: {cleaned_response}")
        
        try:
            recommendations = json.loads(cleaned_response)
            if not isinstance(recommendations, list):
                recommendations = [recommendations]
        except json.JSONDecodeError as e:
            logging.error(f"Failed to parse AI response: {e}")
            return jsonify({"error": "Invalid response format from AI"}), 500
        
        # Add images for each recommendation
        for rec in recommendations:
            rec['images'] = fetch_destination_images(rec['destination'])
        
        formatted_recommendations = [format_recommendation(rec) for rec in recommendations[:3]]
        
        # Store recommendations in Firestore
        store_success = store_user_recommendations(user_id, formatted_recommendations, preferences)
        if not store_success:
            logging.warning(f"Failed to store recommendations for user {user_id}")
        
        return jsonify(formatted_recommendations), 200
    except Exception as e:
        logging.error(f"Error processing quiz submission: {e}")
        return jsonify({"error": "An internal error occurred"}), 500

@app.route('/user-recommendations/<user_id>', methods=['GET'])
def get_user_recommendations(user_id):
    """Retrieve stored recommendations for a user."""
    try:
        recommendations = get_cached_recommendations(user_id)
        if not recommendations:
            return jsonify({"error": f"No recommendations found for user {user_id}"}), 404
            
        return jsonify(recommendations), 200
    except Exception as e:
        logging.error(f"Error retrieving recommendations: {e}")
        return jsonify({"error": "An internal error occurred"}), 500

@app.route('/refresh-recommendations/<user_id>', methods=['POST'])
def refresh_recommendations(user_id):
    """Force refresh recommendations for a user."""
    try:
        doc_ref = db.collection('users').document(user_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            return jsonify({"error": "User preferences not found"}), 404
            
        # Get stored preferences and generate new recommendations
        data = doc.to_dict()
        preferences = data.get('preferences', {})
        
        # Add userId to preferences for the generate_recommendations function
        preferences['userId'] = user_id
        
        # Create a new request with stored preferences
        with app.test_request_context('/recommendations', 
                                    method='POST',
                                    json=preferences):
            return generate_recommendations()
    except Exception as e:
        logging.error(f"Error refreshing recommendations: {e}")
        return jsonify({"error": "An internal error occurred"}), 500

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
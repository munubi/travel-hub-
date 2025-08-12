# Xplore - Travel Destination Recommender

A personalized travel recommendation app built with Flutter and Python Flask that helps users discover their perfect destinations through an interactive preference quiz.

## Overview

Xplore takes the guesswork out of travel planning by providing tailored destination recommendations based on your unique preferences. Through an engaging quiz experience, users can express their travel preferences, including:

- Budget constraints
- Preferred activities and experiences
- Desired destination vibes
- Travel style and pace
- Season and weather preferences

## Project Structure

```
travel-project/
├── lib/               # Flutter frontend code
└── backend/           # Python Flask backend
    ├── app.py        # Main backend server
    ├── .env          # Environment variables (not in git)
    └── requirements.txt
```

## Features

- **Personalized Quiz**: Interactive questionnaire to understand your travel preferences
- **Smart Recommendations**: AI-powered destination matching using Google's Gemini API
- **Rich Destination Details**: Comprehensive information about recommended locations
- **Favorites System**: Save and manage your preferred destinations
- **User Profiles**: Track your preferences and recommendations history

## Getting Started

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Backend Setup

1. Navigate to the backend directory:

```bash
cd backend
```

2. Create a Python virtual environment:

```bash
python -m venv venv
.\venv\Scripts\activate
```

3. Install dependencies:

```bash
pip install -r requirements.txt
```

4. Create a `.env` file in the backend directory with the following:

```env
GOOGLE_API_KEY=your_google_gemini_api_key
SERPER_API_KEY=your_serper_api_key
FIREBASE_CREDENTIALS_PATH=path_to_firebase_credentials.json
```

5. Firebase Admin SDK Setup:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Generate new private key
   - Save as `travel-project-ba441-firebase-adminsdk-mzcmn-e33d09bed1.json` in backend folder
   - Add to .gitignore to prevent committing sensitive data

## Required API Keys

1. **Google Gemini API**

   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create API key for Gemini model
   - Add to `.env` as `GOOGLE_API_KEY`

2. **Serper API**

   - Sign up at [Serper.dev](https://serper.dev)
   - Get API key from dashboard
   - Add to `.env` as `SERPER_API_KEY`

3. **Firebase Admin SDK**
   - Go to Firebase Console
   - Navigate to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save file as `travel-project-ba441-firebase-adminsdk-mzcmn-e33d09bed1.json`
   - Move to backend folder
   - Update `FIREBASE_CREDENTIALS_PATH` in `.env`

## Running the Backend

```bash
cd backend
.\venv\Scripts\activate
python app.py
```

The server will start at `http://localhost:5000`

## Frontend Setup

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, email ernestkorongo@gmail.com or raise an issue in the repository.

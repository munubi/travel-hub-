// preferences_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'display_recommendations_page.dart'; // Import the display page

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  _PreferencesPageState createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late TravelPreference _preferences;
  bool _isLoading = false;
  bool _isInitialized = false;
  int _currentStep = 0;

  // Quiz questions and options definition
  final List<Map<String, dynamic>> _questions = [
    {
      'title': "What's your travel style? 🌎",
      'type': 'single',
      'options': [
        {
          'label': 'Adventure Seeker',
          'description': 'Love exploring off-beat paths and trying new things',
          'icon': Icons.explore
        },
        {
          'label': 'Beach Lover',
          'description': 'Sunny skies, warm sand, and total relaxation',
          'icon': Icons.beach_access
        },
        {
          'label': 'Culture Explorer',
          'description': 'Museums, local food, and historical sites',
          'icon': Icons.museum
        },
        {
          'label': 'Luxury Enthusiast',
          'description': 'Premium experiences and comfort all the way',
          'icon': Icons.star
        }
      ]
    },
    {
      'title': "Who's joining your adventure? ✈️",
      'type': 'single',
      'options': [
        {
          'label': 'Solo Journey',
          'description': 'Just me and the world',
          'icon': Icons.person
        },
        {
          'label': 'Dynamic Duo',
          'description': 'Traveling with a partner',
          'icon': Icons.people
        },
        {
          'label': 'Family Fun',
          'description': 'Kids in tow!',
          'icon': Icons.family_restroom
        },
        {
          'label': 'Friend Squad',
          'description': 'The more the merrier',
          'icon': Icons.groups
        }
      ]
    },
    {
      'title': 'How long is your perfect getaway? 📅',
      'type': 'single',
      'options': [
        {
          'label': 'Quick Escape',
          'description': '3-4 days',
          'icon': Icons.timer
        },
        {
          'label': 'Week of Wonder',
          'description': '7-8 days',
          'icon': Icons.calendar_today
        },
        {
          'label': 'Full Experience',
          'description': '2 weeks',
          'icon': Icons.date_range
        },
        {
          'label': 'Extended Adventure',
          'description': '3+ weeks',
          'icon': Icons.calendar_month
        }
      ]
    },
    {
      'title': 'Pick your vacation vibes! 🌟',
      'type': 'multiple',
      'description': 'Choose up to 3 that speak to you',
      'options': [
        {
          'label': 'City Buzz',
          'description': 'Urban exploration and nightlife',
          'icon': Icons.location_city
        },
        {
          'label': "Nature's Call",
          'description': 'Mountains, forests, and wildlife',
          'icon': Icons.forest
        },
        {
          'label': 'Beach Life',
          'description': 'Coastal beauty and water activities',
          'icon': Icons.waves
        },
        {
          'label': 'Food Journey',
          'description': 'Culinary discoveries',
          'icon': Icons.restaurant
        },
        {
          'label': 'Cultural Deep-Dive',
          'description': 'Local traditions and history',
          'icon': Icons.theater_comedy
        },
        {
          'label': 'Active & Sporty',
          'description': 'Adventure activities',
          'icon': Icons.sports
        }
      ]
    },
    {
      'title': "What's your style for spending? 💰",
      'type': 'single',
      'options': [
        {
          'label': 'Budget-Friendly',
          'description': 'Smart traveling, great experiences',
          'icon': Icons.savings
        },
        {
          'label': 'Middle Ground',
          'description': 'Comfortable with occasional splurges',
          'icon': Icons.account_balance_wallet
        },
        {
          'label': 'High-End',
          'description': 'Luxury and comfort priority',
          'icon': Icons.diamond
        }
      ]
    },
    {
      'title': 'Your travel must-haves? ✨',
      'type': 'multiple',
      'description': 'Pick what matters most to you',
      'options': [
        {
          'label': 'WiFi Everywhere',
          'description': 'Stay connected',
          'icon': Icons.wifi
        },
        {
          'label': 'Local Food Scene',
          'description': 'Authentic cuisine',
          'icon': Icons.restaurant_menu
        },
        {
          'label': 'Easy Transport',
          'description': 'Good connections',
          'icon': Icons.directions_bus
        },
        {
          'label': 'Quiet Spaces',
          'description': 'Peace and relaxation',
          'icon': Icons.nature_people
        },
        {
          'label': 'Shopping',
          'description': 'Retail therapy',
          'icon': Icons.shopping_bag
        },
        {
          'label': 'Photography Spots',
          'description': 'Instagram-worthy views',
          'icon': Icons.camera_alt
        }
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    String? storedUserId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _preferences = TravelPreference(userId: storedUserId);
      _isInitialized = true;
    });

    // Check for cached recommendations
    _checkCachedRecommendations();
  }

  void _handleSelection(String value) {
    final currentQuestion = _questions[_currentStep];
    setState(() {
      if (currentQuestion['type'] == 'multiple') {
        switch (_currentStep) {
          case 3:
            List<String> updatedVibes = List.from(_preferences.vibes);
            if (updatedVibes.contains(value)) {
              updatedVibes.remove(value);
            } else if (updatedVibes.length < 3) {
              updatedVibes.add(value);
            }
            _preferences.vibes = updatedVibes;
            break;
          case 5:
            List<String> updatedMustHaves = List.from(_preferences.mustHaves);
            if (updatedMustHaves.contains(value)) {
              updatedMustHaves.remove(value);
            } else if (updatedMustHaves.length < 3) {
              updatedMustHaves.add(value);
            }
            _preferences.mustHaves = updatedMustHaves;
            break;
        }
      } else {
        switch (_currentStep) {
          case 0:
            _preferences.travelStyle = value;
            _moveToNextStep();
            break;
          case 1:
            _preferences.groupType = value;
            _moveToNextStep();
            break;
          case 2:
            _preferences.duration = value;
            _moveToNextStep();
            break;
          case 4:
            _preferences.budget = value;
            _moveToNextStep();
            break;
        }
      }
    });
  }

  Future<void> _submitPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'https://flask-backend-6vht.onrender.com/recommendations'), // Use Render backend
        headers: {'Content-Type': 'application/json'},
        body: json.encode(_preferences.toJson()),
      );

      if (response.statusCode == 200) {
        final recommendations = json.decode(response.body);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DisplayRecommendationsPage(
                recommendations: recommendations,
                userId: _preferences.userId,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to generate recommendations. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkCachedRecommendations() async {
    try {
      final baseUrl = 'https://flask-backend-6vht.onrender.com'; // Use Render backend
      final url =
          Uri.parse('$baseUrl/user-recommendations/${_preferences.userId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // You can handle the cached recommendations here if needed
        // final cachedRecommendations = json.decode(response.body);
        // Optionally use cachedRecommendations
      }
    } catch (e) {
      print('Error occurred while checking recommendations: $e');
    }
  }

  void _moveToNextStep() {
    if (_currentStep < _questions.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _moveToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _canMoveToNext() {
    final currentQuestion = _questions[_currentStep];
    if (currentQuestion['type'] == 'multiple') {
      switch (_currentStep) {
        case 3:
          return _preferences.vibes.isNotEmpty;
        case 5:
          return _preferences.mustHaves.isNotEmpty;
        default:
          return true;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Preferences Quiz'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: <Widget>[
                      if (_currentStep > 0)
                        ElevatedButton(
                          onPressed: _moveToPreviousStep,
                          child: const Text('Back'),
                        ),
                      const SizedBox(width: 8),
                      if (_currentStep < _questions.length - 1)
                        ElevatedButton(
                          onPressed: _canMoveToNext() ? _moveToNextStep : null,
                          child: const Text('Next'),
                        ),
                      if (_currentStep == _questions.length - 1)
                        ElevatedButton(
                          onPressed:
                              _canMoveToNext() ? _submitPreferences : null,
                          child: const Text('Get Recommendations'),
                        ),
                    ],
                  ),
                );
              },
              steps: _questions
                  .map((question) => Step(
                        title: Text(question['title']),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (question['description'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  question['description'],
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),
                              ),
                            ...question['options']
                                .map<Widget>((option) => Card(
                                      margin:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: ListTile(
                                        leading: Icon(option['icon']),
                                        title: Text(option['label']),
                                        subtitle: Text(option['description']),
                                        selected: question['type'] == 'multiple'
                                            ? (_currentStep == 3 &&
                                                    _preferences.vibes.contains(
                                                        option['label'])) ||
                                                (_currentStep == 5 &&
                                                    _preferences.mustHaves
                                                        .contains(
                                                            option['label']))
                                            : false,
                                        onTap: () =>
                                            _handleSelection(option['label']),
                                      ),
                                    ))
                                .toList(),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

// Models
class TravelPreference {
  String userId;
  String travelStyle;
  String groupType;
  String duration;
  List<String> vibes;
  String budget;
  List<String> mustHaves;

  TravelPreference({
    String? userId,
    this.travelStyle = '',
    this.groupType = '',
    this.duration = '',
    List<String>? vibes,
    this.budget = '',
    List<String>? mustHaves,
  })  : userId = userId ?? const Uuid().v4(),
        vibes = vibes ?? [],
        mustHaves = mustHaves ?? [];

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'travelStyle': travelStyle,
        'groupType': groupType,
        'duration': duration,
        'vibes': vibes,
        'budget': budget,
        'mustHaves': mustHaves,
      };
}

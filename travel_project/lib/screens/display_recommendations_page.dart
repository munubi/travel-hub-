// display_recommendations_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class DisplayRecommendationsPage extends StatefulWidget {
  final List<dynamic> recommendations;
  final String userId;

  const DisplayRecommendationsPage({
    super.key,
    required this.recommendations,
    required this.userId,
  });

  @override
  State<DisplayRecommendationsPage> createState() =>
      _DisplayRecommendationsPageState();
}

class _DisplayRecommendationsPageState
    extends State<DisplayRecommendationsPage> {
  Set<String> likedDestinations = {};

  @override
  void initState() {
    super.initState();
    _loadLikedDestinations();
  }

  Future<void> _loadLikedDestinations() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('favorites')
        .get();

    setState(() {
      likedDestinations = snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> recommendation) async {
    final destinationId = recommendation['id'];
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('favorites')
        .doc(destinationId);

    setState(() {
      if (likedDestinations.contains(destinationId)) {
        likedDestinations.remove(destinationId);
        userRef.delete();
      } else {
        likedDestinations.add(destinationId);
        userRef.set(recommendation);
      }
    });
  }

  Future<void> addToFavorites(
      String userId, Map<String, dynamic> destination) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(destination['id'])
          .set({
        'name': destination['name'],
        'description': destination['description'],
        'imageUrl': destination['imageUrl'],
        'budget': destination['budget'],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to favorites: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Perfect Destinations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse(
                    'https://flask-backend-6vht.onrender.com/refresh-recommendations/${widget.userId}',
                  ),
                );
                if (response.statusCode == 200) {
                  final newRecommendations = json.decode(response.body);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DisplayRecommendationsPage(
                          recommendations: newRecommendations,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to refresh recommendations'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: widget.recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = widget.recommendations[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: PageView.builder(
                    itemCount: recommendation['images'].length,
                    itemBuilder: (context, imageIndex) {
                      return Image.network(
                        recommendation['images'][imageIndex],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            recommendation['name'],
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: Icon(
                              likedDestinations.contains(recommendation['id'])
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () => _toggleLike(recommendation),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(recommendation['description']),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Activities:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...List<Widget>.from(
                        recommendation['activities'].map((activity) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(activity)),
                                ],
                              ),
                            )),
                      ),
                      const SizedBox(height: 16.0),
                      InfoRow(
                        icon: Icons.attach_money,
                        label: 'Budget',
                        value: recommendation['budget'],
                      ),
                      InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Best Time to Visit',
                        value: recommendation['bestTimeToVisit'],
                      ),
                      InfoRow(
                        icon: Icons.tips_and_updates,
                        label: 'Travel Tip',
                        value: recommendation['travelTip'],
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.flight_takeoff),
                          label: const Text('Check Availability'),
                          onPressed: () async {
                            final url = recommendation['bookingUrl'];
                            if (await canLaunch(url)) {
                              await launch(url);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

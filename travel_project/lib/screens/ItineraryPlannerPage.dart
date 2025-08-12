import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ItineraryPlannerPage extends StatefulWidget {
  final String destinationId;
  final String destinationName;

  const ItineraryPlannerPage({
    super.key,
    required this.destinationId,
    required this.destinationName,
  });

  @override
  State<ItineraryPlannerPage> createState() => _ItineraryPlannerPageState();
}

class _ItineraryPlannerPageState extends State<ItineraryPlannerPage> {
  late Future<List<dynamic>> _itinerary;

  @override
  void initState() {
    super.initState();
    _itinerary = _fetchItinerary();
  }

  Future<List<dynamic>> _fetchItinerary() async {
    final url = Uri.parse(
        'http://127.0.0.1:5000/itinerary/${widget.destinationId}'); // Backend endpoint
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['activities'];
    } else {
      throw Exception('Failed to load itinerary');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.destinationName} Itinerary'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _itinerary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error loading itinerary: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No activities available for this destination.'),
            );
          }

          final activities = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(activity['name']),
                  subtitle: Text(activity['description']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

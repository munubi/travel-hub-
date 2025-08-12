import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'preferences_page.dart';
// ignore: unused_import
import 'favorites_page.dart';
// ignore: unused_import
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Recommendation> recommendations = [];
  bool isLoading = true;
  final Color primaryColor = Color(0xFF1A4A8B); // Primary brand color

  @override
  void initState() {
    super.initState();
    loadRecommendations(); // Load recommendations when the page is initialized
  }

  Future<void> loadRecommendations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!response.exists) {
        setState(() {
          isLoading = false;
          recommendations = [];
        });
        return;
      }

      final data = response.data();
      if (data != null && data.containsKey('recommendations')) {
        final recsData = data['recommendations'] as List<dynamic>;
        if (recsData.isNotEmpty) {
          setState(() {
            recommendations = recsData
                .map((json) =>
                    Recommendation.fromJson(json as Map<String, dynamic>))
                .toList();
          });
        } else {
          setState(() => recommendations = []);
        }
      } else {
        setState(() => recommendations = []);
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? _buildLoading()
            : recommendations.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
      floatingActionButton: _buildQuizFAB(),
    );
  }

  Widget _buildQuizFAB() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PreferencesPage()),
        );
      },
      backgroundColor: primaryColor,
      child: Icon(Icons.travel_explore, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          SizedBox(height: 16),
          Text('Finding your perfect destinations...',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 80),
            Icon(Icons.travel_explore, size: 100, color: primaryColor),
            SizedBox(height: 40),
            Text('Ready to Explore?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                )),
            SizedBox(height: 16),
            Text(
              'Take our quick quiz to get personalized travel recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PreferencesPage()),
                );
              },
              child: Text('Take Travel Quiz',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Simplified app bar
        SliverAppBar(
          expandedHeight: 80,
          floating: true,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(left: 24, bottom: 16),
            title: Text(
              'Discover',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ),
        ),
        // Featured Destination section
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Featured Destination',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildFeaturedDestination(),
        ),
        // Recommended section
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended for You',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text('See All', style: TextStyle(color: primaryColor)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildRecommendedDestinations(),
        ),
        // Add bottom padding
        SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  Widget _buildFeaturedDestination() {
    final featured = recommendations.first;
    return Container(
      height: 240,
      margin: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(featured.images.first),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    featured.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.amber, size: 20),
                      Text(
                        featured.budget,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      Text(
                        '4.8',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedDestinations() {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          return _buildRecommendationCard(index);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(int index) {
    final rec = recommendations[index];
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      margin: EdgeInsets.only(right: 16, left: index == 0 ? 24 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Add this
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  rec.images.first,
                  height: 160, // Reduced height
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_outline,
                      size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(12), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Add this
              children: [
                Text(
                  rec.name,
                  style: TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey, size: 14),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rec.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.amber, size: 16),
                    Text(
                      rec.budget,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(
                      '4.8',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _navigateToDetail(rec),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _navigateToDetail(Recommendation recommendation) {
    // TODO: Implement navigation to detail page
    print('Navigate to detail page for ${recommendation.name}');
  }
}

class Recommendation {
  final String id;
  final String name;
  final String description;
  final String budget;
  final List<String> images;
  final List<String> activities;
  final String travelTip;

  Recommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.budget,
    required this.images,
    required this.activities,
    required this.travelTip,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      budget: json['budget'],
      images: List<String>.from(json['images'] ?? []),
      activities: List<String>.from(json['activities'] ?? []),
      travelTip: json['travelTip'] ?? '',
    );
  }
}

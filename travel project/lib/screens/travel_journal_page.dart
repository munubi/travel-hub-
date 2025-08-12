import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;

class TravelJournalPage extends StatefulWidget {
  const TravelJournalPage({Key? key}) : super(key: key);

  @override
  State<TravelJournalPage> createState() => _TravelJournalPageState();
}

class _TravelJournalPageState extends State<TravelJournalPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  File? _selectedImage;
  File? _commentImage;
  bool _isLoading = false;
  Set<String> _likedPosts = {};

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Get temporary directory
        final dir = await path_provider.getTemporaryDirectory();
        final targetPath =
            path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

        // Compress image
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          image.path,
          targetPath,
          quality: 85,
          minWidth: 1024,
          minHeight: 1024,
        );

        if (compressedFile != null) {
          setState(() {
            _selectedImage = File(compressedFile.path);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }


  Future<void> _createPost() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (_selectedImage != null) {
        // Create unique filename
        final fileName =
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('journal_images')
            .child(fileName);

        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': user.uid},
        );
        await ref.putFile(_selectedImage!, metadata);
        imageUrl = await ref.getDownloadURL();
      }

      // Create post with location and timestamp
      final post = {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'userPhotoUrl': user.photoURL,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [], // Add this to track who liked
        'comments': [],
        'location': '', // Optional: Add location if you want to implement it
      };

      // Add post to Firestore
      await FirebaseFirestore.instance.collection('travel_posts').add(post);

      // Clear form
      if (mounted) {
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _selectedImage = null;
          _isLoading = false;
        });

        Navigator.pop(context); // Close dialog if open

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike(String postId, List<String> likedBy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    try {
      final postRef =
          FirebaseFirestore.instance.collection('travel_posts').doc(postId);

      if (likedBy.contains(user.uid)) {
        // Unlike
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        // Like
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like: $e')),
      );
    }
  }

  void _showComments(
      BuildContext context, String postId, List<dynamic> comments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Comments'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: comment['userPhotoUrl'] != null
                                  ? NetworkImage(comment['userPhotoUrl'])
                                  : null,
                              child: comment['userPhotoUrl'] == null
                                  ? Text(comment['userName'][0].toUpperCase())
                                  : null,
                            ),
                            title: Text(comment['userName'] ?? 'Anonymous'),
                            subtitle: Text(
                              comment['timestamp']?.toDate().toString() ?? '',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(comment['content'] ?? ''),
                          ),
                          if (comment['imageUrl'] != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CachedNetworkImage(
                                imageUrl: comment['imageUrl'],
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _addComment(postId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addComment(String postId) async {
    if (_commentController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    try {
      // Upload comment image if selected
      String? commentImageUrl;
      if (_commentImage != null) {
        final fileName =
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}_comment.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('comment_images')
            .child(fileName);

        await ref.putFile(_commentImage!);
        commentImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('travel_posts')
          .doc(postId)
          .update({
        'comments': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'userName': user.displayName ?? 'Anonymous',
            'userPhotoUrl': user.photoURL,
            'content': _commentController.text.trim(),
            'imageUrl': commentImageUrl,
            'timestamp': FieldValue.serverTimestamp(),
          }
        ])
      });

      _commentController.clear();
      setState(() => _commentImage = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final likedPosts = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('liked_posts')
          .get();

      setState(() {
        _likedPosts = likedPosts.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      print('Error loading liked posts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePostDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('travel_posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return const Center(child: Text('No posts yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(post['userName'] ?? 'Anonymous'),
                      subtitle: Text(
                        post['timestamp']?.toDate().toString() ?? 'No date',
                      ),
                    ),
                    if (post['imageUrl'] != null)
                      CachedNetworkImage(
                        imageUrl: post['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['title'] ?? '',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(post['content'] ?? ''),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _likedPosts.contains(postId)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    onPressed: () => _toggleLike(
                                      postId,
                                      List<String>.from(post['likedBy'] ?? []),
                                    ),
                                  ),
                                  Text('${post['likes'] ?? 0}'),
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () => _showComments(
                                      context,
                                      postId,
                                      post['comments'] ?? [],
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () => Share.share(
                                  '${post['title']}\n\n${post['content']}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Add Image'),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              Image.file(_selectedImage!, height: 100),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    _titleController.clear();
                    _contentController.clear();
                    setState(() => _selectedImage = null);
                  },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                    _createPost();
                  },
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}

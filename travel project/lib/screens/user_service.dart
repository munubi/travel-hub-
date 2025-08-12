// user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isFirstTimeUser(String uid) async {
    final docSnapshot = await _firestore.collection('users').doc(uid).get();
    return !docSnapshot.exists;
  }

  Future<void> createUserProfile(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createHouse(String name) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houseName = name.trim();

    if (houseName.isEmpty) {
      throw Exception("House name cannot be empty");
    }

    final doc = _firestore.collection('houses').doc();

    await doc.set({
      'id': doc.id,
      'name': houseName,
      'ownerId': user.uid,
      'memberIds': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await doc.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? "unknown",
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<String> joinHouseFromInput(String input) async {
    final houseId = _extractHouseId(input);

    await joinHouse(houseId);

    return houseId;
  }

  Future<void> joinHouse(String houseId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houseRef = _firestore.collection('houses').doc(houseId);
    final houseDoc = await houseRef.get();

    if (!houseDoc.exists) {
      throw Exception("House not found");
    }

    final memberRef = houseRef.collection('members').doc(user.uid);
    final memberDoc = await memberRef.get();

    await houseRef.update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
    });

    if (memberDoc.exists) return;

    await memberRef.set({
      'uid': user.uid,
      'email': user.email ?? "unknown",
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMessage(String houseId, String text) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final message = text.trim();

    if (message.isEmpty) return;

    await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('messages')
        .add({
      'text': message,
      'uid': user.uid,
      'email': user.email ?? "unknown",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTask(String houseId, String title) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final taskTitle = title.trim();

    if (taskTitle.isEmpty) return;

    await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('tasks')
        .add({
      'title': taskTitle,
      'assignedTo': user.uid,
      'assignedEmail': user.email ?? "",
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

   Future<void> toggleTask(
    String houseId,
    String taskId,
    bool currentValue,
  ) async {
    await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'isDone': !currentValue,
    });
  }

  Future<void> logActivity(String houseId, String action) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('activity')
        .add({
      'uid': user.uid,
      'email': user.email ?? "unknown",
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _extractHouseId(String input) {
    final value = input.trim();

    if (value.isEmpty) {
      throw Exception("House ID cannot be empty");
    }

    final uri = Uri.tryParse(value);

    if (uri != null && uri.queryParameters['houseId'] != null) {
      return uri.queryParameters['houseId']!;
    }

    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    return value;
  }
}



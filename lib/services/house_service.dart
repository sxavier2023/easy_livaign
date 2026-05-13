import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createHouse(String name) async {
    final user = FirebaseAuth.instance.currentUser;

    final doc = _db.collection('houses').doc();

    await doc.set({
      'id': doc.id,
      'name': name,
      'ownerId': user!.uid,
      'members': [
        {
          'uid': user.uid,
          'email': user.email ?? "unknown",
        }
      ],
    });

    return doc.id;
  }

  Future<void> joinHouse(String houseId) async {
    final user = FirebaseAuth.instance.currentUser;

    await _db.collection('houses').doc(houseId).update({
      'members': FieldValue.arrayUnion([
        {
          'uid': user!.uid,
          'email': user.email ?? "unknown",
        }
      ])
    });
  }
}
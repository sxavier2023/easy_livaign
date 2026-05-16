import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getItems(String houseId) {
    return _inventoryRef(
      houseId,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addItem({
    required String houseId,
    required String name,
    required int quantity,
    required String unit,
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    final itemName = name.trim();

    if (itemName.isEmpty) return;

    await _inventoryRef(houseId).add({
      'name': itemName,
      'quantity': quantity < 0 ? 0 : quantity,
      'unit': unit,
      'addedBy': user.uid,
      'addedByEmail': user.email ?? "",
      'addedByName': user.displayName ?? "House member",
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem({
    required String houseId,
    required String itemId,
    required String name,
    required int quantity,
    required String unit,
  }) {
    return _inventoryRef(houseId).doc(itemId).update({
      'name': name.trim(),
      'quantity': quantity < 0 ? 0 : quantity,
      'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateQuantity({
    required String houseId,
    required String itemId,
    required int quantity,
  }) {
    return _inventoryRef(houseId).doc(itemId).update({
      'quantity': quantity < 0 ? 0 : quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String houseId, String itemId) {
    return _inventoryRef(houseId).doc(itemId).delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> currentMemberStream(
    String houseId,
  ) {
    final user = _auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    return _firestore
        .collection('houses')
        .doc(houseId)
        .collection('members')
        .doc(user.uid)
        .snapshots();
  }

  CollectionReference<Map<String, dynamic>> _inventoryRef(String houseId) {
    return _firestore.collection('houses').doc(houseId).collection('inventory');
  }
}

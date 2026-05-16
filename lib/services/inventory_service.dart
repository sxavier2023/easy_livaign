import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

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

    final quantityValue = quantity < 0 ? 0 : quantity;
    final doc = await _inventoryRef(houseId).add({
      'name': itemName,
      'quantity': quantityValue,
      'unit': unit,
      'addedBy': user.uid,
      'addedByEmail': user.email ?? "",
      'addedByName': user.displayName ?? "House member",
      'updatedBy': user.uid,
      'updatedByEmail': user.email ?? "",
      'updatedByName': user.displayName ?? "House member",
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logItemChange(
      houseId: houseId,
      itemId: doc.id,
      action: 'added',
      itemName: itemName,
      newQuantity: quantityValue,
      unit: unit,
    );

    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: 'inventory_added',
      title: 'Inventory updated',
      message: '$itemName was added to inventory.',
      data: {'itemId': doc.id},
    );
  }

  Future<void> updateItem({
    required String houseId,
    required String itemId,
    required String name,
    required int quantity,
    required String unit,
  }) async {
    final user = _currentUser();
    final itemRef = _inventoryRef(houseId).doc(itemId);
    final previous = await itemRef.get();
    final previousData = previous.data() ?? {};
    final quantityValue = quantity < 0 ? 0 : quantity;
    final itemName = name.trim();

    await itemRef.update({
      'name': name.trim(),
      'quantity': quantityValue,
      'unit': unit,
      'updatedBy': user.uid,
      'updatedByEmail': user.email ?? "",
      'updatedByName': user.displayName ?? "House member",
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logItemChange(
      houseId: houseId,
      itemId: itemId,
      action: 'edited',
      itemName: itemName,
      oldQuantity: (previousData['quantity'] as num?)?.toInt(),
      newQuantity: quantityValue,
      unit: unit,
    );
  }

  Future<void> updateQuantity({
    required String houseId,
    required String itemId,
    required int quantity,
  }) async {
    final user = _currentUser();
    final itemRef = _inventoryRef(houseId).doc(itemId);
    final previous = await itemRef.get();
    final previousData = previous.data() ?? {};
    final previousQuantity = (previousData['quantity'] as num?)?.toInt() ?? 0;
    final quantityValue = quantity < 0 ? 0 : quantity;
    final itemName = previousData['name']?.toString() ?? 'Inventory item';
    final unit = previousData['unit']?.toString() ?? 'pcs';

    await itemRef.update({
      'quantity': quantityValue,
      'updatedBy': user.uid,
      'updatedByEmail': user.email ?? "",
      'updatedByName': user.displayName ?? "House member",
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logItemChange(
      houseId: houseId,
      itemId: itemId,
      action: quantityValue > previousQuantity ? 'increased' : 'decreased',
      itemName: itemName,
      oldQuantity: previousQuantity,
      newQuantity: quantityValue,
      unit: unit,
    );

    if (quantityValue <= 1) {
      await NotificationService().createHouseNotification(
        houseId: houseId,
        type: 'inventory_low_stock',
        title: quantityValue <= 0 ? 'Out of stock' : 'Low stock',
        message: '$itemName is now $quantityValue $unit.',
        data: {'itemId': itemId},
      );
    }
  }

  Future<void> deleteItem(String houseId, String itemId) async {
    final itemRef = _inventoryRef(houseId).doc(itemId);
    final previous = await itemRef.get();
    final previousData = previous.data() ?? {};
    final itemName = previousData['name']?.toString() ?? 'Inventory item';

    await _logItemChange(
      houseId: houseId,
      itemId: itemId,
      action: 'removed',
      itemName: itemName,
      oldQuantity: (previousData['quantity'] as num?)?.toInt(),
      unit: previousData['unit']?.toString() ?? 'pcs',
      includeHouseHistory: true,
    );

    await itemRef.delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> itemHistoryStream(
    String houseId,
    String itemId,
  ) {
    return _inventoryRef(houseId)
        .doc(itemId)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots();
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

  User _currentUser() {
    final user = _auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    return user;
  }

  Future<void> _logItemChange({
    required String houseId,
    required String itemId,
    required String action,
    required String itemName,
    int? oldQuantity,
    int? newQuantity,
    required String unit,
    bool includeHouseHistory = false,
  }) async {
    final user = _currentUser();
    final payload = {
      'itemId': itemId,
      'itemName': itemName,
      'action': action,
      'oldQuantity': oldQuantity,
      'newQuantity': newQuantity,
      'unit': unit,
      'updatedBy': user.uid,
      'updatedByEmail': user.email ?? "",
      'updatedByName': user.displayName ?? "House member",
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _inventoryRef(houseId).doc(itemId).collection('history').add(payload);

    if (includeHouseHistory) {
      await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('inventoryHistory')
          .add(payload);
    }
  }
}

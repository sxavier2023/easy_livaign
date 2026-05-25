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

  Future<QuerySnapshot<Map<String, dynamic>>> getItemsSnapshot(String houseId) {
    return _inventoryRef(houseId).orderBy('createdAt', descending: true).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> purchasesStream(String houseId) {
    return _purchasesRef(
      houseId,
    ).orderBy('purchasedAt', descending: true).limit(100).snapshots();
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
      'normalizedName': _normalizedItemName(itemName),
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

    final houseName = await _houseName(houseId);

    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: 'inventory_added',
      title: 'Inventory updated',
      message: '$itemName was added to inventory in $houseName.',
      data: {'itemId': doc.id, 'houseName': houseName},
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
      'normalizedName': _normalizedItemName(itemName),
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
      final houseName = await _houseName(houseId);

      await NotificationService().createHouseNotification(
        houseId: houseId,
        type: 'inventory_low_stock',
        title: quantityValue <= 0 ? 'Out of stock' : 'Low stock',
        message: '$itemName is now $quantityValue $unit in $houseName.',
        data: {'itemId': itemId, 'houseName': houseName},
      );
    }
  }

  Future<void> addPurchase({
    required String houseId,
    String? itemId,
    required String itemName,
    required int quantity,
    required String unit,
    required double price,
    String? store,
    required DateTime purchasedAt,
    bool addToStock = true,
  }) async {
    final user = _currentUser();
    final trimmedName = itemName.trim();
    final trimmedStore = store?.trim() ?? '';

    if (trimmedName.isEmpty) return;

    final quantityValue = quantity < 0 ? 0 : quantity;
    String? resolvedItemId = itemId;

    if (addToStock) {
      if (resolvedItemId == null || resolvedItemId.isEmpty) {
        resolvedItemId = await _findMatchingInventoryItem(houseId, trimmedName);
      }

      if (resolvedItemId == null || resolvedItemId.isEmpty) {
        resolvedItemId = await _createStockItemFromPurchase(
          houseId: houseId,
          itemName: trimmedName,
          quantity: quantityValue,
          unit: unit,
          user: user,
        );
      } else {
        final itemRef = _inventoryRef(houseId).doc(resolvedItemId);
        final itemDoc = await itemRef.get();
        final previousData = itemDoc.data() ?? {};
        final currentQuantity =
            (previousData['quantity'] as num?)?.toInt() ?? 0;

        await itemRef.update({
          'normalizedName': _normalizedItemName(trimmedName),
          'quantity': currentQuantity + quantityValue,
          'unit': unit,
          'updatedBy': user.uid,
          'updatedByEmail': user.email ?? "",
          'updatedByName': user.displayName ?? "House member",
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final purchaseDoc = await _purchasesRef(houseId).add({
      'itemId': resolvedItemId,
      'itemName': trimmedName,
      'quantity': quantityValue,
      'unit': unit,
      'price': price < 0 ? 0 : price,
      'store': trimmedStore,
      'purchasedBy': user.uid,
      'purchasedByEmail': user.email ?? "",
      'purchasedByName': user.displayName ?? "House member",
      'boughtBy': user.uid,
      'boughtByEmail': user.email ?? "",
      'boughtByName': user.displayName ?? "House member",
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (resolvedItemId != null && resolvedItemId.isNotEmpty) {
      await _logItemChange(
        houseId: houseId,
        itemId: resolvedItemId,
        action: 'purchased',
        itemName: trimmedName,
        newQuantity: quantityValue,
        unit: unit,
      );
    }

    final houseName = await _houseName(houseId);

    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: 'purchase_added',
      title: 'Purchase added',
      message:
          '${user.displayName ?? user.email ?? 'Someone'} bought $quantityValue $unit of $trimmedName for $houseName.',
      data: {
        'purchaseId': purchaseDoc.id,
        'itemId': resolvedItemId,
        'houseName': houseName,
      },
    );
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

  CollectionReference<Map<String, dynamic>> _purchasesRef(String houseId) {
    return _firestore.collection('houses').doc(houseId).collection('purchases');
  }

  String _normalizedItemName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String?> _findMatchingInventoryItem(
    String houseId,
    String itemName,
  ) async {
    final normalizedName = _normalizedItemName(itemName);

    if (normalizedName.isEmpty) return null;

    final normalizedQuery = await _inventoryRef(
      houseId,
    ).where('normalizedName', isEqualTo: normalizedName).limit(1).get();

    if (normalizedQuery.docs.isNotEmpty) {
      return normalizedQuery.docs.first.id;
    }

    final existingItems = await _inventoryRef(houseId).limit(100).get();

    for (final item in existingItems.docs) {
      final data = item.data();
      final existingName = data['name']?.toString() ?? '';

      if (_normalizedItemName(existingName) == normalizedName) {
        return item.id;
      }
    }

    return null;
  }

  Future<String> _createStockItemFromPurchase({
    required String houseId,
    required String itemName,
    required int quantity,
    required String unit,
    required User user,
  }) async {
    final itemDoc = await _inventoryRef(houseId).add({
      'name': itemName,
      'normalizedName': _normalizedItemName(itemName),
      'quantity': quantity,
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

    return itemDoc.id;
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

  Future<String> _houseName(String houseId) async {
    final doc = await _firestore.collection('houses').doc(houseId).get();

    return doc.data()?['name']?.toString() ?? 'this house';
  }
}

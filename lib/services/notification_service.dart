import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _listenerAttached = false;

  Future<void> initialize() async {
    await registerCurrentUserToken();

    if (_listenerAttached) return;

    _listenerAttached = true;

    FirebaseMessaging.onMessage.listen((message) {
      // ignore: avoid_print
      print("FCM MESSAGE: ${message.notification?.title ?? message.data}");
    });

    _messaging.onTokenRefresh.listen((token) {
      _saveToken(token);
    });
  }

  Future<void> registerCurrentUserToken() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) return;

      await _saveToken(token);
    } catch (e) {
      // Web push needs Firebase web push credentials. Keep auth/chat/tasks
      // working even before the production FCM setup is complete.
      // ignore: avoid_print
      print("FCM TOKEN SAVE FAILED: $e");
    }
  }

  Future<void> createHouseNotification({
    required String houseId,
    required String type,
    required String title,
    required String message,
    String? targetUserId,
    Map<String, dynamic> data = const {},
  }) async {
    final user = _auth.currentUser;

    try {
      final notification = {
        'type': type,
        'title': title,
        'message': message,
        'houseId': houseId,
        'userId': targetUserId,
        'createdBy': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        ...data,
      };

      await _db
          .collection('houses')
          .doc(houseId)
          .collection('notifications')
          .add(notification);

      try {
        await _db.collection('houses').doc(houseId).collection('activity').add({
          ...notification,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // House activity is local UI history; notification delivery should
        // still succeed if activity rules are temporarily stricter.
        // ignore: avoid_print
        print("ACTIVITY WRITE FAILED: $e");
      }

      try {
        await _cleanupOldHouseNotifications(houseId);
      } catch (e) {
        // Cleanup can be retried later and should not block the notification.
        // ignore: avoid_print
        print("NOTIFICATION CLEANUP FAILED: $e");
      }

      await _db.collection('pushQueue').add({
        ...notification,
        'houseId': houseId,
        'targetUserId': targetUserId,
        'status': 'pending',
        'queuedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Notification failures should not block the user action.
      // ignore: avoid_print
      print("NOTIFICATION WRITE FAILED: $e");
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
          'token': token,
          'platform': 'flutter',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _cleanupOldHouseNotifications(
    String houseId, {
    int keepLatest = 25,
  }) async {
    final snapshot = await _db
        .collection('houses')
        .doc(houseId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .get();

    final staleDocs = snapshot.docs.skip(keepLatest).toList();

    for (var index = 0; index < staleDocs.length; index += 450) {
      final batch = _db.batch();
      final chunk = staleDocs.sublist(
        index,
        index + 450 > staleDocs.length ? staleDocs.length : index + 450,
      );

      for (final doc in chunk) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }
}

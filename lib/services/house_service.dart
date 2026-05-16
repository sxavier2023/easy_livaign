import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class HouseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> houseRef(String houseId) {
    return _firestore.collection('houses').doc(houseId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userHousesStream(String userId) {
    return _firestore
        .collection('houses')
        .where('memberIds', arrayContains: userId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> houseStream(String houseId) {
    return houseRef(houseId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String houseId) {
    return houseRef(houseId).collection('members').snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberStream(
    String houseId,
    String userId,
  ) {
    return houseRef(houseId).collection('members').doc(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activityStream(String houseId) {
    return houseRef(
      houseId,
    ).collection('activity').orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String houseId, {
    int limit = 50,
  }) {
    return houseRef(houseId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> inventoryStream(String houseId) {
    return houseRef(houseId)
        .collection('inventory')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
    String houseId,
  ) {
    return houseRef(houseId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots();
  }

  Future<String> createHouse({
    required String name,
    required String country,
    required String city,
    required String postCode,
    required String address,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houseName = name.trim();
    final inviteCode = _generateInviteCode();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );

    if (houseName.isEmpty) {
      throw Exception("House name cannot be empty");
    }

    final doc = _firestore.collection('houses').doc();

    await doc.set({
      'id': doc.id,
      'name': houseName,
      'country': country.trim(),
      'city': city.trim(),
      'postCode': postCode.trim(),
      'address': address.trim(),
      'ownerId': user.uid,
      'inviteCode': inviteCode,
      'inviteExpiresAt': expiresAt,
      'memberIds': [user.uid],
      'members': {
        user.uid: {
          'role': 'admin',
          'email': user.email ?? "unknown",
          'joinedAt': Timestamp.now(),
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await doc.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'role': 'admin',
      'email': user.email ?? "unknown",
      'displayName': user.displayName ?? "Unknown member",
      'photoUrl': user.photoURL,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<String> joinHouseFromInput(String input) async {
    final inviteCode = _extractInviteCode(input);

    // ignore: avoid_print
    print("JOIN INVITE CODE: $inviteCode");

    final houseQuery = await _firestore
        .collection('houses')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (houseQuery.docs.isEmpty) {
      throw Exception(
        "Invalid invite code. Check that you pasted the invite code, not the house ID.",
      );
    }

    final houseDoc = houseQuery.docs.first;
    final data = houseDoc.data();
    final expiresAt = data['inviteExpiresAt'];

    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw Exception("Invite link expired");
    }

    await joinHouse(houseDoc.id, inviteCode: inviteCode);

    return houseDoc.id;
  }

  Future<void> joinHouse(String houseId, {String? inviteCode}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houseRef = this.houseRef(houseId);

    final houseDoc = await houseRef.get();

    if (!houseDoc.exists) {
      throw Exception("House not found");
    }

    final houseData = houseDoc.data() ?? {};
    final currentCode = houseData['inviteCode']?.toString().toUpperCase();
    final expiresAt = houseData['inviteExpiresAt'];

    if (inviteCode == null || inviteCode.trim().isEmpty) {
      throw Exception("Invite code is required");
    }

    if (currentCode != inviteCode.trim().toUpperCase()) {
      throw Exception("Invalid invite code");
    }

    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw Exception("Invite link expired");
    }

    final memberRef = houseRef.collection('members').doc(user.uid);

    final memberPayload = {
      'uid': user.uid,
      'role': 'member',
      'email': user.email ?? "unknown",
      'displayName': user.displayName ?? "Unknown member",
      'photoUrl': user.photoURL,
      'joinedWithInviteCode': inviteCode,
      'joinedAt': FieldValue.serverTimestamp(),
    };

    await memberRef.set(memberPayload, SetOptions(merge: true));

    await houseRef.update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'members.${user.uid}': {
        'role': 'member',
        'email': user.email ?? "unknown",
        'joinedWithInviteCode': inviteCode,
        'joinedAt': Timestamp.now(),
      },
    });

    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: 'member_joined',
      title: 'New member joined',
      message: '${user.displayName ?? user.email ?? 'A new member'} joined.',
      targetUserId: user.uid,
    );
  }

  Future<void> sendMessage(String houseId, String text) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final message = text.trim();

    if (message.isEmpty) return;

    final doc = await _firestore
        .collection('houses')
        .doc(houseId)
        .collection('messages')
        .add({
          'text': message,
          'uid': user.uid,
          'email': user.email ?? "unknown",
          'timestamp': FieldValue.serverTimestamp(),
        });

    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: 'chat_message',
      title: 'New chat message',
      message: '${user.displayName ?? user.email ?? 'Someone'}: $message',
      data: {'messageId': doc.id},
    );
  }

  Future<void> deleteHouse(String houseId) {
    return houseRef(houseId).delete();
  }

  Future<void> updateCurrentMemberAvatar(
    String houseId,
    String imageUrl,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    await houseRef(
      houseId,
    ).collection('members').doc(user.uid).update({'photoUrl': imageUrl});
  }

  Future<void> updateAvatarAcrossMemberships(String imageUrl) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houses = await _firestore
        .collection('houses')
        .where('memberIds', arrayContains: user.uid)
        .get();

    final batch = _firestore.batch();

    for (final house in houses.docs) {
      batch.set(
        house.reference.collection('members').doc(user.uid),
        {'photoUrl': imageUrl},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> sendEmailInvite(String houseId, String email) async {
    final inviteEmail = email.trim();

    if (inviteEmail.isEmpty) return;

    final inviteLink = await inviteLinkForHouse(houseId);

    await _firestore.collection('mail').add({
      'to': [inviteEmail],
      'message': {
        'subject': 'Join my house on Easy LivAIgn',
        'text':
            '''
You have been invited to join a house on Easy LivAIgn.

Invite link: $inviteLink
''',
        'html':
            '''
<p>You have been invited to join a house on <b>Easy LivAIgn</b>.</p>
<p><a href="$inviteLink">Join the house</a></p>
''',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'houseId': houseId,
      'type': 'house_invite',
    });

    await houseRef(houseId).collection('invites').add({
      'type': 'email',
      'email': inviteEmail,
      'houseId': houseId,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createPhoneInvite(String houseId, String phone) async {
    final invitePhone = phone.trim();

    if (invitePhone.isEmpty) return;

    await houseRef(houseId).collection('invites').add({
      'type': 'phone',
      'phone': invitePhone,
      'houseId': houseId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> inviteLinkForHouse(String houseId) async {
    final inviteCode = await ensureInviteCode(houseId);

    return "https://easylivaign.app/join?code=$inviteCode";
  }

  Future<String> ensureInviteCode(String houseId) async {
    final doc = await houseRef(houseId).get();
    final data = doc.data();

    if (data == null) {
      throw Exception("House not found");
    }

    final currentCode = data['inviteCode']?.toString();
    final expiresAt = data['inviteExpiresAt'];
    final isExpired =
        expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now());

    if (currentCode != null && currentCode.isNotEmpty && !isExpired) {
      return currentCode;
    }

    final inviteCode = _generateInviteCode();

    await houseRef(houseId).update({
      'inviteCode': inviteCode,
      'inviteExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
    });

    return inviteCode;
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
          'message': action,
          'action': action,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  String _extractInviteCode(String input) {
    final value = input
        .trim()
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'''^[<"']+|[>"']+$'''), '');

    if (value.isEmpty) {
      throw Exception("Invite code cannot be empty");
    }

    final codeMatch = RegExp(
      r'(?:code|inviteCode)=([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(value);

    if (codeMatch != null) {
      return codeMatch.group(1)!.trim().toUpperCase();
    }

    final uri = Uri.tryParse(value);

    if (uri != null && uri.queryParameters['code'] != null) {
      return uri.queryParameters['code']!.trim().toUpperCase();
    }

    if (uri != null && uri.fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(uri.fragment);

      if (fragmentUri != null && fragmentUri.queryParameters['code'] != null) {
        return fragmentUri.queryParameters['code']!.trim().toUpperCase();
      }

      if (fragmentUri != null && fragmentUri.pathSegments.isNotEmpty) {
        return fragmentUri.pathSegments.last.trim().toUpperCase();
      }
    }

    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last.trim();

      if (lastSegment.isNotEmpty && lastSegment.toLowerCase() != 'join') {
        return lastSegment.toUpperCase();
      }
    }

    final plainCode = RegExp(r'[A-Za-z0-9]{6,12}').firstMatch(value);

    if (plainCode != null) {
      return plainCode.group(0)!.toUpperCase();
    }

    throw Exception("Invite code not found in pasted text");
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

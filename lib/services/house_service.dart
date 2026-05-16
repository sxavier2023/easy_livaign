import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String houseId) {
    return houseRef(
      houseId,
    ).collection('messages').orderBy('timestamp', descending: true).snapshots();
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
    final houseId = _extractHouseId(input);

    await joinHouse(houseId);

    return houseId;
  }

  Future<void> joinHouse(String houseId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final houseRef = this.houseRef(houseId);

    final houseDoc = await houseRef.get();

    if (!houseDoc.exists) {
      throw Exception("House not found");
    }

    final memberRef = houseRef.collection('members').doc(user.uid);

    final memberDoc = await memberRef.get();

    // Prevent duplicate joins
    if (memberDoc.exists) return;

    // Update house document
    await houseRef.update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'members.${user.uid}': {
        'role': 'member',
        'email': user.email ?? "unknown",
        'joinedAt': Timestamp.now(),
      },
    });

    // Create member subcollection document
    await memberRef.set({
      'uid': user.uid,
      'role': 'member',
      'email': user.email ?? "unknown",
      'displayName': user.displayName ?? "Unknown member",
      'photoUrl': user.photoURL,
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

    final inviteLink = "https://easylivaign.app/join/$houseId";

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

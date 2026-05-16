import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AvatarService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickAvatar() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
  }

  Future<String> uploadAvatar(XFile imageFile) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) throw Exception("Not logged in");

    final ref = _storage.ref().child('avatars').child('${user.uid}.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final Uint8List bytes = await imageFile.readAsBytes();

    await ref.putData(bytes, metadata);

    return ref.getDownloadURL();
  }
}

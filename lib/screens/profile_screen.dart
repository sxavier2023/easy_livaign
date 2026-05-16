import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/house_service.dart';
import '../widgets/brand_icon.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();
  final HouseService _houseService = HouseService();

  bool _isUploading = false;
  String? _photoUrl;

  Future<void> _uploadAvatar() async {
    setState(() => _isUploading = true);

    try {
      final image = await _avatarService.pickAvatar();

      if (image == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final imageUrl = await _avatarService.uploadAvatar(image);

      await _authService.updateProfilePhoto(imageUrl);
      await _houseService.updateAvatarAcrossMemberships(imageUrl);

      if (!mounted) return;

      setState(() {
        _photoUrl = imageUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Avatar updated")));
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Avatar Error: $e")));
    }
  }

  String _initials(User user) {
    final displayName = user.displayName?.trim() ?? '';
    final email = user.email?.trim() ?? '';
    final source = displayName.isNotEmpty ? displayName : email;

    return source.isNotEmpty ? source[0].toUpperCase() : "?";
  }

  Widget _brandIcon(String asset, {double size = 24}) {
    return BrandIcon(asset, size: size, fallback: Icons.person);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = _photoUrl ?? user?.photoURL;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _brandIcon('assets/brand/icons/people.svg'),
            const SizedBox(width: 8),
            const Text("Profile"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Center(child: Text("No user logged in"))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Text(
                                  _initials(user),
                                  style: const TextStyle(fontSize: 28),
                                )
                              : null,
                        ),
                        IconButton.filled(
                          tooltip: "Upload avatar",
                          onPressed: _isUploading ? null : _uploadAvatar,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user.displayName ?? "No name",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(user.email ?? "No email", textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: _brandIcon('assets/brand/icons/people.svg', size: 20),
                    label: Text(_isUploading ? "Uploading..." : "Upload Image"),
                    onPressed: _isUploading ? null : _uploadAvatar,
                  ),
                ],
              ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/house_service.dart';
import '../widgets/app_panel.dart';
import '../widgets/brand_icon.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

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
  bool _isSavingName = false;
  bool _isLoggingOut = false;
  String? _photoUrl;

  Future<void> _editDisplayName(User user) async {
    final controller = TextEditingController(text: user.displayName ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Display Name"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Display name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isSavingName = true);

    try {
      await _authService.updateDisplayName(name);
      await _houseService.updateDisplayNameAcrossMemberships(name);

      if (!mounted) return;

      setState(() => _isSavingName = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Display name updated")));
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSavingName = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Name Error: $e")));
    }
  }

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

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoggingOut = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout Error: $e")));
    }
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: user == null
                  ? const Center(child: Text("No user logged in"))
                  : AppPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundImage:
                                      photoUrl != null && photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null || photoUrl.isEmpty
                                      ? Text(
                                          _initials(user),
                                          style: const TextStyle(fontSize: 30),
                                        )
                                      : null,
                                ),
                                IconButton.filled(
                                  tooltip: "Upload avatar",
                                  onPressed: _isUploading
                                      ? null
                                      : _uploadAvatar,
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
                          const SizedBox(height: 18),
                          Text(
                            FirebaseAuth.instance.currentUser?.displayName ??
                                user.displayName ??
                                "No name",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.email ?? "No email",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            icon: _brandIcon(
                              'assets/brand/icons/people.svg',
                              size: 20,
                            ),
                            label: Text(
                              _isUploading ? "Uploading..." : "Upload Image",
                            ),
                            onPressed: _isUploading ? null : _uploadAvatar,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: _isSavingName
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.edit),
                            label: Text(
                              _isSavingName ? "Saving..." : "Edit Display Name",
                            ),
                            onPressed: _isSavingName
                                ? null
                                : () => _editDisplayName(user),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text("Settings"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            icon: _isLoggingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout),
                            label: Text(
                              _isLoggingOut ? "Logging out..." : "Logout",
                            ),
                            onPressed: _isLoggingOut ? null : _logout,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

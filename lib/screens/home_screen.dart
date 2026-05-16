import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/house_service.dart';
import '../services/rbac_service.dart';
import '../widgets/app_state.dart';
import '../widgets/app_panel.dart';
import '../widgets/brand_icon.dart';
import '../widgets/brand_logo.dart';
import '../widgets/theme_picker.dart';
import 'house_dashboard_screen.dart';
import 'profile_screen.dart';
import 'qr_scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HouseService _houseService = HouseService();

  final TextEditingController houseNameController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController houseIdController = TextEditingController();
  bool _isCreatingHouse = false;
  bool _isJoiningHouse = false;

  @override
  void dispose() {
    houseNameController.dispose();
    countryController.dispose();
    houseIdController.dispose();
    super.dispose();
  }

  Future<void> _deleteHouse(String houseId, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete House"),
          content: Text("Delete $name?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _houseService.deleteHouse(houseId);

      // ignore: avoid_print
      print("DELETE SUCCESS");
    } catch (e) {
      // ignore: avoid_print
      print("DELETE FAILED: $e");
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("House deleted")));
  }

  Future<void> _joinHouseWithInput(String input) async {
    if (input.trim().isEmpty || _isJoiningHouse) return;

    try {
      setState(() => _isJoiningHouse = true);

      final houseId = await _houseService.joinHouseFromInput(input);

      await _houseService.logActivity(houseId, "joined the house");

      houseIdController.clear();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HouseDashboardScreen(houseId: houseId),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isJoiningHouse = false);
      }
    }
  }

  Future<void> _scanInviteQr() async {
    final scannedValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (scannedValue == null || scannedValue.trim().isEmpty) return;

    houseIdController.text = scannedValue;
    await _joinHouseWithInput(scannedValue);
  }

  String _initialsFromMember(Map<String, dynamic> member) {
    final displayName = (member['displayName'] ?? '').toString().trim();
    final email = (member['email'] ?? '').toString().trim();
    final source = displayName.isNotEmpty ? displayName : email;

    return source.isNotEmpty ? source[0].toUpperCase() : "?";
  }

  Widget _memberAvatar(Map<String, dynamic> member) {
    final photoUrl = member['photoUrl'] as String?;

    return CircleAvatar(
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(_initialsFromMember(member))
          : null,
    );
  }

  Widget _brandIcon(String asset, {double size = 24, IconData? fallback}) {
    return BrandIcon(asset, size: size, fallback: fallback ?? Icons.circle);
  }

  EdgeInsets _pagePadding(double width) {
    return EdgeInsets.symmetric(
      horizontal: width >= 900 ? 32 : 16,
      vertical: width >= 700 ? 24 : 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.lock_outline,
          title: "You are signed out",
          message: "Log in to see your houses and shared spaces.",
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(width: 30),
            const SizedBox(width: 8),
            const Text("Easy LivAIgn"),
          ],
        ),
        actions: [
          const ThemePickerButton(),
          PopupMenuButton<String>(
            tooltip: "More",
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }

              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text("Profile"),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text("Settings"),
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: _pagePadding(constraints.maxWidth),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: houseNameController,
                              decoration: const InputDecoration(
                                labelText: "Create House Name",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: countryController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: "Country",
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: _brandIcon(
                                'assets/brand/icons/home.svg',
                                size: 20,
                                fallback: Icons.home,
                              ),
                              onPressed: () async {
                                try {
                                  final name = houseNameController.text.trim();

                                  if (name.isEmpty || _isCreatingHouse) return;

                                  setState(() => _isCreatingHouse = true);

                                  final houseId = await _houseService
                                      .createHouse(
                                        name: name,
                                        country: countryController.text,
                                        city: '',
                                        postCode: '',
                                        address: '',
                                      );

                                  await _houseService.logActivity(
                                    houseId,
                                    "created the house",
                                  );

                                  houseNameController.clear();
                                  countryController.clear();

                                  if (!context.mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HouseDashboardScreen(
                                        houseId: houseId,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isCreatingHouse = false);
                                  }
                                }
                              },
                              label: Text(
                                _isCreatingHouse
                                    ? "Creating..."
                                    : "Create House",
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "My Houses",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _houseService.userHousesStream(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return AppErrorState(
                              title: "Could not load houses",
                              error: snapshot.error,
                              onRetry: () => setState(() {}),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const AppLoadingState(
                              message: "Loading houses...",
                            );
                          }

                          final houses = snapshot.data!.docs;

                          if (houses.isEmpty) {
                            return const AppEmptyState(
                              icon: Icons.home_outlined,
                              title: "No houses yet",
                              message:
                                  "Create a house or join one with an invite link.",
                            );
                          }

                          return Column(
                            children: houses.map((house) {
                              final data = house.data();
                              final name = data['name'] ?? 'Unnamed House';

                              return Card(
                                child:
                                    StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: _houseService.memberStream(
                                        house.id,
                                        user.uid,
                                      ),
                                      builder: (context, memberSnapshot) {
                                        final member =
                                            memberSnapshot.data?.data() ?? {};
                                        final role = member['role'] ?? 'member';
                                        final joinedAt = member['joinedAt'];

                                        final formattedDate = joinedAt != null
                                            ? DateFormat(
                                                'dd MMM yyyy',
                                              ).format(joinedAt.toDate())
                                            : 'Unknown date';

                                        final roleText =
                                            role == 'admin' || role == 'owner'
                                            ? 'Admin'
                                            : 'Member';

                                        final subtitleText = roleText == 'Admin'
                                            ? 'Admin - Created $formattedDate'
                                            : 'Member - Joined $formattedDate';

                                        return ListTile(
                                          leading: _memberAvatar(member),
                                          title: Text(name),
                                          subtitle: Text(subtitleText),
                                          trailing:
                                              RbacService.canDeleteHouse(member)
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
                                                  color: Colors.red,
                                                  onPressed: () {
                                                    _deleteHouse(
                                                      house.id,
                                                      name,
                                                    );
                                                  },
                                                )
                                              : const Icon(
                                                  Icons.arrow_forward_ios,
                                                ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    HouseDashboardScreen(
                                                      houseId: house.id,
                                                    ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const Divider(),
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: houseIdController,
                              decoration: const InputDecoration(
                                labelText: "Enter Invite Link or Code",
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: _brandIcon(
                                'assets/brand/icons/people.svg',
                                size: 20,
                                fallback: Icons.group_add,
                              ),
                              onPressed: () async {
                                await _joinHouseWithInput(
                                  houseIdController.text.trim(),
                                );
                              },
                              label: Text(
                                _isJoiningHouse ? "Joining..." : "Join House",
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text("Scan Invite QR"),
                              onPressed: _isJoiningHouse ? null : _scanInviteQr,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

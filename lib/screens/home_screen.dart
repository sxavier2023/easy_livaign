import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/house_service.dart';
import '../services/rbac_service.dart';
import 'house_dashboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HouseService _houseService = HouseService();

  final TextEditingController houseNameController = TextEditingController();
  final TextEditingController houseIdController = TextEditingController();

  @override
  void dispose() {
    houseNameController.dispose();
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
      await FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .delete();

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("LivAIgn"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: houseNameController,
              decoration: const InputDecoration(
                labelText: "Create House Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  final name = houseNameController.text.trim();

                  if (name.isEmpty) return;

                  final houseId = await _houseService.createHouse(name);

                  await _houseService.logActivity(houseId, "created the house");

                  houseNameController.clear();

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HouseDashboardScreen(houseId: houseId),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Create House"),
            ),
            const SizedBox(height: 24),
            const Text(
              "My Houses",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('houses')
                    .where('memberIds', arrayContains: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final houses = snapshot.data!.docs;

                  if (houses.isEmpty) {
                    return const Center(child: Text("No houses yet"));
                  }

                  return ListView.separated(
                    itemCount: houses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final house = houses[index];
                      final data = house.data();
                      final name = data['name'] ?? 'Unnamed House';

                      return Card(
                        child:
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: house.reference
                                  .collection('members')
                                  .doc(user.uid)
                                  .snapshots(),
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
                                  leading: CircleAvatar(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(subtitleText),
                                  trailing: RbacService.canDeleteHouse(member)
                                      ? IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          onPressed: () {
                                            _deleteHouse(house.id, name);
                                          },
                                        )
                                      : const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => HouseDashboardScreen(
                                          houseId: house.id,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            TextField(
              controller: houseIdController,
              decoration: const InputDecoration(
                labelText: "Enter Invite Link",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  final input = houseIdController.text.trim();

                  if (input.isEmpty) return;

                  final houseId = await _houseService.joinHouseFromInput(input);

                  await _houseService.logActivity(houseId, "joined the house");

                  houseIdController.clear();

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HouseDashboardScreen(houseId: houseId),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Join House"),
            ),
          ],
        ),
      ),
    );
  }
}

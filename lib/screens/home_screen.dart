import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/house_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HouseService _houseService = HouseService();

  final TextEditingController houseNameController = TextEditingController();
  final TextEditingController houseIdController = TextEditingController();

  String? currentHouseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Easy LivAIgn 🏠"),
      ),
      body: Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    children: [

      TextField(
        controller: houseNameController,
        decoration: const InputDecoration(
          labelText: "Create House Name",
        ),
      ),

      const SizedBox(height: 10),

      ElevatedButton(
        onPressed: () async {
          final id = await _houseService.createHouse(
            houseNameController.text.trim(),
          );

          setState(() {
            currentHouseId = id;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("House Created: $id")),
          );
        },
        child: const Text("Create House"),
      ),
TextField(
  controller: houseIdController,
  decoration: const InputDecoration(
    labelText: "Enter House ID",
  ),
),

const SizedBox(height: 10),

ElevatedButton(
  onPressed: () async {
    await _houseService.joinHouse(
      houseIdController.text.trim(),
    );

    setState(() {
      currentHouseId = houseIdController.text.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Joined House 🚀")),
    );
  },
  child: const Text("Join House"),
),
            const Divider(height: 40),

      currentHouseId == null
          ? const Text("No house joined yet")
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('houses')
                  .doc(currentHouseId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>;

                final name = data['name'];
                final members =
                    List<String>.from(data['members'] ?? []);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🏠 House: $name",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("👥 Members: ${members.length}"),
                    const SizedBox(height: 10),
                    Text("House ID: $currentHouseId"),
                  ],
                );
              },
            ),
    ],
  ),
),
    );
  }
}
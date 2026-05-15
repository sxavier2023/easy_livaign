import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/house_service.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HouseDashboardScreen extends StatefulWidget {
  final String houseId;

  const HouseDashboardScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<HouseDashboardScreen> createState() => _HouseDashboardScreenState();
}

class _HouseDashboardScreenState extends State<HouseDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final HouseService _houseService = HouseService();

  DocumentReference<Map<String, dynamic>> get houseRef =>
      FirebaseFirestore.instance.collection('houses').doc(widget.houseId);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteLink() async {
    final link = "https://easylivaign.app/join/${widget.houseId}";

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite link copied")),
    );
  }

  Future<void> _joinCurrentUserToHouse() async {
    await _houseService.joinHouse(widget.houseId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Joined house")),
    );
  }

  Future<void> _sendEmailInvite() async {
    final email = emailController.text.trim();

    if (email.isEmpty) return;

    final inviteLink = "https://easylivaign.app/join/${widget.houseId}";

    await FirebaseFirestore.instance.collection('mail').add({
      'to': [email],
      'message': {
        'subject': 'Join my house on Easy LivAIgn',
        'text': '''
You have been invited to join a house on Easy LivAIgn.

House ID: ${widget.houseId}
Invite link: $inviteLink
''',
        'html': '''
<p>You have been invited to join a house on <b>Easy LivAIgn</b>.</p>
<p><b>House ID:</b> ${widget.houseId}</p>
<p><a href="$inviteLink">Join the house</a></p>
''',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'houseId': widget.houseId,
      'type': 'house_invite',
    });

    await houseRef.collection('invites').add({
      'type': 'email',
      'email': email,
      'houseId': widget.houseId,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });

    emailController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invite email sent")),
    );
  }

  Future<void> _sendPhoneInvite() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) return;

    await houseRef.collection('invites').add({
      'type': 'phone',
      'phone': phone,
      'houseId': widget.houseId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    phoneController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Phone invite created")),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: houseRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}

final data = snapshot.data!.data();

if (data == null) {
  return const Center(
    child: Text("House not found"),
  );
}

final taskCount = data['taskCount'] ?? 0;
        return Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Text(
        "🏠 ${data['name']}",
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 20),

      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: houseRef.collection('members').snapshots(),
        builder: (context, memberSnapshot) {
          final memberCount = memberSnapshot.data?.docs.length ?? 0;

          return Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _overviewCard(
                "Members",
                Icons.people,
                memberCount.toString(),
              ),

              _overviewCard(
                "Tasks",
                Icons.check_box,
                taskCount.toString(),
              ),

              _overviewCard(
                "Chat",
                Icons.chat,
                "Live",
              ),
            ],
          );
        },
      ),

      const SizedBox(height: 30),

      const Text(
        "📌 Recent Activity",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 10),

      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('houses')
              .doc(widget.houseId)
              .collection('activity')
              .orderBy(
                'timestamp',
                descending: true,
              )
              .snapshots(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final items = snapshot.data!.docs;

            if (items.isEmpty) {
              return const Center(
                child: Text("No activity yet"),
              );
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {

                final data =
                    items[index].data()
                        as Map<String, dynamic>;

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: Text(
                      data['message'] ?? "",
                    ),
                    subtitle: Text(
                      data['email'] ?? "",
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  ),
);
      },
    );
  }

  Widget _overviewCard(
    String title,
    IconData icon,
    String value,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(title),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: houseRef.collection('members').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = snapshot.data!.docs;
            final isMember = currentUser != null &&
                members.any((doc) => doc.id == currentUser.uid);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMember) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text("Join This House"),
                    onPressed: () async {
                      try {
                        await _joinCurrentUserToHouse();
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  "People in this House",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  const Text("No members yet")
                else
                  ...members.map((doc) {
                    final data = doc.data();
                    final role = data['role'] ?? "member";

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          role == 'owner' ? Icons.star : Icons.person,
                          color: role == 'owner' ? Colors.orange : null,
                        ),
                        title: Text(data['email'] ?? "Unknown"),
                        subtitle: Text(role),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          "Invite People",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text("Copy Invite Link"),
          onPressed: _copyInviteLink,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Email address",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.email),
          label: const Text("Send Email Invite"),
          onPressed: _sendEmailInvite,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Phone number",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.phone),
          label: const Text("Create Phone Invite"),
          onPressed: _sendPhoneInvite,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("House: ${widget.houseId}"),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Chat"),
            Tab(text: "Tasks"),
            Tab(text: "Inventory"),
            Tab(text: "People"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          ChatTab(houseId: widget.houseId),
          TasksTab(houseId: widget.houseId),
          const Center(child: Text("📦 Inventory coming soon")),
          _buildPeopleTab(),
        ],
      ),
    );
  }
}

class ChatTab extends StatefulWidget {
  final String houseId;

  const ChatTab({
    super.key,
    required this.houseId,
  });

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController controller = TextEditingController();
  final HouseService houseService = HouseService();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
  try {
    await houseService.sendMessage(widget.houseId, controller.text);

    await houseService.logActivity(
      widget.houseId,
      "sent a message",
    );

    controller.clear();
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Message Error: $e")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection('houses')
        .doc(widget.houseId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: messagesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              if (messages.isEmpty) {
                return const Center(child: Text("No messages yet"));
              }

              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;

                  return ListTile(
                    title: Text(data['text'] ?? ""),
                    subtitle: Text(data['email'] ?? "unknown"),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TasksTab extends StatefulWidget {
  final String houseId;

  const TasksTab({
    super.key,
    required this.houseId,
  });

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final TextEditingController taskController = TextEditingController();
  final HouseService houseService = HouseService();

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksRef = FirebaseFirestore.instance
        .collection('houses')
        .doc(widget.houseId)
        .collection('tasks')
        .orderBy('createdAt', descending: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: taskController,
                  decoration: const InputDecoration(
                    hintText: "New task...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  try {
                    await houseService.addTask(
                      widget.houseId,
                      taskController.text,
                    );
                    taskController.clear();
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Task Error: $e")),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: tasksRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("No tasks yet"));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final taskId = docs[index].id;
                  final isDone = data['isDone'] ?? false;

                  return ListTile(
                    leading: Checkbox(
                      value: isDone,
                      onChanged: (_) async {
                        await houseService.toggleTask(
                          widget.houseId,
                          taskId,
                          isDone,
                        );
                      },
                    ),
                    title: Text(
                      data['title'] ?? "",
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      "Assigned to: ${data['assignedEmail'] ?? ""}",
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

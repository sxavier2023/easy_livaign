import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../services/avatar_service.dart';
import '../services/auth_service.dart';
import '../services/house_service.dart';
import '../services/rbac_service.dart';
import '../services/task_service.dart';
import '../widgets/app_state.dart';
import '../widgets/brand_icon.dart';
import 'inventory_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HouseDashboardScreen extends StatefulWidget {
  final String houseId;

  const HouseDashboardScreen({super.key, required this.houseId});

  @override
  State<HouseDashboardScreen> createState() => _HouseDashboardScreenState();
}

class _HouseDashboardScreenState extends State<HouseDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final HouseService _houseService = HouseService();
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();

  DocumentReference<Map<String, dynamic>> get houseRef =>
      _houseService.houseRef(widget.houseId);

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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Invite link copied")));
  }

  Future<void> _joinCurrentUserToHouse() async {
    await _houseService.joinHouse(widget.houseId);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Joined house")));
  }

  Future<void> _sendEmailInvite() async {
    final email = emailController.text.trim();

    if (email.isEmpty) return;

    await _houseService.sendEmailInvite(widget.houseId, email);

    emailController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Invite email sent")));
  }

  Future<void> _sendPhoneInvite() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) return;

    await _houseService.createPhoneInvite(widget.houseId, phone);

    phoneController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Phone invite created")));
  }

  Future<void> _uploadCurrentUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final image = await _avatarService.pickAvatar();

      if (image == null) return;

      final imageUrl = await _avatarService.uploadAvatar(image);

      await _authService.updateProfilePhoto(imageUrl);
      await _houseService.updateCurrentMemberAvatar(widget.houseId, imageUrl);
      await _houseService.updateAvatarAcrossMemberships(imageUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Avatar updated")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Avatar Error: $e")));
    }
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

  EdgeInsets _contentPadding(double width) {
    return EdgeInsets.symmetric(
      horizontal: width >= 900 ? 32 : 16,
      vertical: width >= 700 ? 24 : 16,
    );
  }

  Widget _responsiveContent({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: _contentPadding(constraints.maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _houseService.houseStream(widget.houseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            title: "Could not load house",
            error: snapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return const AppLoadingState(message: "Loading house...");
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return const AppEmptyState(
            icon: Icons.home_outlined,
            title: "House not found",
            message: "This house may have been deleted or is unavailable.",
          );
        }

        final taskCount = data['taskCount'] ?? 0;
        return _responsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? "House",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _houseService.membersStream(widget.houseId),
                builder: (context, memberSnapshot) {
                  final memberCount = memberSnapshot.data?.docs.length ?? 0;
                  if (memberSnapshot.hasError) {
                    return AppErrorState(
                      title: "Could not load members",
                      error: memberSnapshot.error,
                      onRetry: () => setState(() {}),
                    );
                  }

                  if (!memberSnapshot.hasData) {
                    return const AppLoadingState(
                      message: "Loading overview...",
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth >= 720
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth >= 420
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _overviewCard(
                            "Members",
                            'assets/brand/icons/people.svg',
                            memberCount.toString(),
                            width: cardWidth,
                          ),
                          _overviewCard(
                            "Tasks",
                            'assets/brand/icons/tasks.svg',
                            taskCount.toString(),
                            width: cardWidth,
                          ),
                          _overviewCard(
                            "Chat",
                            'assets/brand/icons/chat.svg',
                            "Live",
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 30),

              const Text(
                "Recent Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _houseService.activityStream(widget.houseId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const AppLoadingState(
                        message: "Loading activity...",
                      );
                    }

                    final items = snapshot.data!.docs;

                    if (items.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.bolt_outlined,
                        title: "No activity yet",
                        message:
                            "House updates will appear here as people chat, join, and complete tasks.",
                      );
                    }

                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data =
                            items[index].data() as Map<String, dynamic>;

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.bolt),
                            title: Text(data['message'] ?? ""),
                            subtitle: const Text("House activity"),
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
    String iconAsset,
    String value, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _brandIcon(iconAsset, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleTab() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return _responsiveContent(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _houseService.membersStream(widget.houseId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorState(
                  title: "Could not load members",
                  error: snapshot.error,
                  onRetry: () => setState(() {}),
                );
              }

              if (!snapshot.hasData) {
                return const AppLoadingState(message: "Loading members...");
              }

              final members = snapshot.data!.docs;
              final isMember =
                  currentUser != null &&
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

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (isMember) ...[
                    OutlinedButton.icon(
                      icon: _brandIcon(
                        'assets/brand/icons/people.svg',
                        size: 20,
                        fallback: Icons.photo_camera,
                      ),
                      label: const Text("Upload Avatar"),
                      onPressed: _uploadCurrentUserAvatar,
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    "People in this House",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (members.isEmpty)
                    const AppEmptyState(
                      icon: Icons.people_outline,
                      title: "No members yet",
                      message: "Invite people to start aligning this house.",
                    )
                  else
                    ...members.map((doc) {
                      final data = doc.data();
                      final isAdmin = RbacService.isAdmin(data);
                      final displayName = data['displayName'];
                      final email = data['email'];
                      final joinedAt = data['joinedAt'];
                      final formattedDate = joinedAt != null
                          ? DateFormat('dd MMM yyyy').format(joinedAt.toDate())
                          : 'Unknown date';
                      final roleText = isAdmin ? 'Admin' : 'Member';

                      return Card(
                        child: ListTile(
                          leading: _memberAvatar(data),
                          title: Text(displayName ?? email ?? "Unknown user"),
                          subtitle: Text("$roleText - Joined $formattedDate"),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _houseService.houseStream(widget.houseId),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            return Text(data?['name'] ?? "House");
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: "Notifications",
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: _brandIcon(
              'assets/brand/icons/people.svg',
              fallback: Icons.person,
            ),
            tooltip: "Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: _brandIcon(
              'assets/brand/icons/settings.svg',
              fallback: Icons.settings,
            ),
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
          tabs: [
            Tab(
              icon: _brandIcon(
                'assets/brand/icons/home.svg',
                size: 22,
                fallback: Icons.home,
              ),
              text: "Overview",
            ),
            Tab(
              icon: _brandIcon(
                'assets/brand/icons/chat.svg',
                size: 22,
                fallback: Icons.chat,
              ),
              text: "Chat",
            ),
            Tab(
              icon: _brandIcon(
                'assets/brand/icons/tasks.svg',
                size: 22,
                fallback: Icons.check_box,
              ),
              text: "Tasks",
            ),
            Tab(
              icon: _brandIcon(
                'assets/brand/icons/more.svg',
                size: 22,
                fallback: Icons.inventory_2,
              ),
              text: "Inventory",
            ),
            Tab(
              icon: _brandIcon(
                'assets/brand/icons/people.svg',
                size: 22,
                fallback: Icons.people,
              ),
              text: "People",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          ChatTab(houseId: widget.houseId),
          TasksTab(houseId: widget.houseId),
          InventoryScreen(houseId: widget.houseId),
          _buildPeopleTab(),
        ],
      ),
    );
  }

  Future<void> _showNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _houseService.notificationsStream(widget.houseId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                title: "Could not load notifications",
                error: snapshot.error,
              );
            }

            if (!snapshot.hasData) {
              return const AppLoadingState(message: "Loading notifications...");
            }

            final notifications = snapshot.data!.docs;

            if (notifications.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_none,
                title: "No notifications yet",
                message: "Task assignments and completions will appear here.",
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data = notifications[index].data();
                final createdAt = data['createdAt'];
                final formattedDate = createdAt is Timestamp
                    ? DateFormat('dd MMM, h:mm a').format(createdAt.toDate())
                    : 'Just now';

                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      data['type'] == 'task_completed'
                          ? Icons.task_alt
                          : Icons.assignment_ind,
                    ),
                  ),
                  title: Text(data['title'] ?? 'Notification'),
                  subtitle: Text("${data['message'] ?? ''}\n$formattedDate"),
                  isThreeLine: true,
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatTab extends StatefulWidget {
  final String houseId;

  const ChatTab({super.key, required this.houseId});

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

      try {
        await houseService.logActivity(widget.houseId, "sent a message");
      } catch (e) {
        // ignore: avoid_print
        print("ACTIVITY LOG FAILED: $e");
      }

      controller.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Message Error: $e")));
    }
  }

  Widget _responsiveChat({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _responsiveChat(
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: houseService.messagesStream(widget.houseId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorState(
                    title: "Could not load messages",
                    error: snapshot.error,
                    onRetry: () => setState(() {}),
                  );
                }

                if (!snapshot.hasData) {
                  return const AppLoadingState(message: "Loading chat...");
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: "No messages yet",
                    message: "Start the first house conversation.",
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(data['text'] ?? ""),
                      subtitle: const Text("Message"),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}

class TasksTab extends StatefulWidget {
  final String houseId;

  const TasksTab({super.key, required this.houseId});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final TextEditingController taskController = TextEditingController();
  final HouseService houseService = HouseService();
  final TaskService taskService = TaskService();
  String _taskFilter = 'all';
  String _completionFilter = 'active';
  static const Map<String, String> _taskStatuses = {
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'done': 'Done',
  };

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  Widget _responsiveTasks({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth >= 900 ? 24 : 12,
                vertical: 12,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  String _initialsFromMember(Map<String, dynamic> member) {
    final displayName = (member['displayName'] ?? '').toString().trim();
    final email = (member['email'] ?? '').toString().trim();
    final source = displayName.isNotEmpty ? displayName : email;

    return source.isNotEmpty ? source[0].toUpperCase() : "?";
  }

  Widget _assigneeAvatar(Map<String, dynamic>? member) {
    if (member == null) {
      return const CircleAvatar(child: Icon(Icons.person_outline));
    }

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

  String _taskStatus(Map<String, dynamic> task) {
    final status = task['status']?.toString();

    if (status != null && status.isNotEmpty) return status;

    return task['isDone'] == true ? 'done' : 'pending';
  }

  DateTime? _taskDueDate(Map<String, dynamic> task) {
    final dueDate = task['dueDate'];

    if (dueDate is Timestamp) return dueDate.toDate();

    return null;
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final dueDate = _taskDueDate(task);

    if (dueDate == null || _taskStatus(task) == 'done') return false;

    final today = DateTime.now();
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final currentDay = DateTime(today.year, today.month, today.day);

    return dueDay.isBefore(currentDay);
  }

  String _dueDateText(Map<String, dynamic> task) {
    final dueDate = _taskDueDate(task);

    if (dueDate == null) return 'No due date';

    return 'Due ${DateFormat('dd MMM yyyy').format(dueDate)}';
  }

  Future<void> _showTaskDialog({
    DocumentReference<Map<String, dynamic>>? docRef,
    Map<String, dynamic>? task,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  }) async {
    final titleController = TextEditingController(
      text: task?['title']?.toString() ?? '',
    );
    String? selectedMemberId = task?['assignedTo']?.toString();
    String selectedStatus = task == null ? 'pending' : _taskStatus(task);
    DateTime? selectedDueDate = task == null ? null : _taskDueDate(task);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(docRef == null ? "Add Task" : "Edit Task"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: "Task title",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedMemberId,
                      decoration: const InputDecoration(
                        labelText: "Assign to",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("Unassigned"),
                        ),
                        ...members.map((member) {
                          final data = member.data();
                          final label =
                              data['displayName'] ?? data['email'] ?? "Member";

                          return DropdownMenuItem<String?>(
                            value: member.id,
                            child: Text(label),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedMemberId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                      items: _taskStatuses.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() => selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        selectedDueDate == null
                            ? "Add Due Date"
                            : DateFormat(
                                'dd MMM yyyy',
                              ).format(selectedDueDate!),
                      ),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate == null) return;

                        setDialogState(() => selectedDueDate = pickedDate);
                      },
                    ),
                    if (selectedDueDate != null)
                      TextButton(
                        onPressed: () {
                          setDialogState(() => selectedDueDate = null);
                        },
                        child: const Text("Clear due date"),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();

                    if (title.isEmpty) return;

                    final selectedMember = selectedMemberId == null
                        ? null
                        : members
                              .where((member) => member.id == selectedMemberId)
                              .firstOrNull;
                    final selectedMemberData = selectedMember?.data();

                    if (docRef == null) {
                      await taskService.addTask(
                        widget.houseId,
                        title,
                        assignedTo: selectedMember?.id,
                        assignedEmail: selectedMemberData?['email'],
                        assignedName: selectedMemberData?['displayName'],
                        dueDate: selectedDueDate,
                        status: selectedStatus,
                      );
                    } else {
                      await taskService.updateTask(
                        widget.houseId,
                        docRef.id,
                        title: title,
                        assignedTo: selectedMember?.id,
                        assignedEmail: selectedMemberData?['email'],
                        assignedName: selectedMemberData?['displayName'],
                        dueDate: selectedDueDate,
                        status: selectedStatus,
                      );
                    }

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },
                  child: Text(docRef == null ? "Add" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
    String? userId,
  ) {
    final completionFiltered = tasks.where((task) {
      final isDone = _taskStatus(task.data()) == 'done';
      return _completionFilter == 'completed' ? isDone : !isDone;
    }).toList();

    if (_taskFilter == 'mine') {
      return completionFiltered
          .where((task) => task.data()['assignedTo'] == userId)
          .toList();
    }

    if (_taskFilter == 'unassigned') {
      return completionFiltered.where((task) {
        final assignedTo = task.data()['assignedTo'];
        return assignedTo == null || assignedTo.toString().isEmpty;
      }).toList();
    }

    return completionFiltered;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: houseService.membersStream(widget.houseId),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.hasError) {
          return AppErrorState(
            title: "Could not load task permissions",
            error: memberSnapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (!memberSnapshot.hasData) {
          return const AppLoadingState(message: "Loading tasks...");
        }

        final members = memberSnapshot.data!.docs;
        final memberMap = {
          for (final member in members) member.id: member.data(),
        };
        final currentMember = currentUser == null
            ? null
            : memberMap[currentUser.uid];
        final isAdmin =
            currentMember != null && RbacService.isAdmin(currentMember);

        return Scaffold(
          body: _responsiveTasks(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'active',
                            label: Text("Active"),
                            icon: Icon(Icons.pending_actions),
                          ),
                          ButtonSegment(
                            value: 'completed',
                            label: Text("Completed"),
                            icon: Icon(Icons.task_alt),
                          ),
                        ],
                        selected: {_completionFilter},
                        onSelectionChanged: (selection) {
                          setState(() => _completionFilter = selection.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text("All")),
                          ButtonSegment(value: 'mine', label: Text("My Tasks")),
                          ButtonSegment(
                            value: 'unassigned',
                            label: Text("Unassigned"),
                          ),
                        ],
                        selected: {_taskFilter},
                        onSelectionChanged: (selection) {
                          setState(() => _taskFilter = selection.first);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: taskService.getTasks(widget.houseId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return AppErrorState(
                          title: "Could not load tasks",
                          error: snapshot.error,
                          onRetry: () => setState(() {}),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const AppLoadingState(
                          message: "Loading tasks...",
                        );
                      }

                      final docs = _filteredTasks(
                        snapshot.data!.docs,
                        currentUser?.uid,
                      );

                      if (docs.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.task_alt,
                          title: _completionFilter == 'completed'
                              ? "No completed tasks yet"
                              : "No active tasks here yet",
                          message: _completionFilter == 'completed'
                              ? "Completed tasks move here automatically."
                              : _taskFilter == 'mine'
                              ? "Tasks assigned to you will show here."
                              : _taskFilter == 'unassigned'
                              ? "Unassigned tasks will show here."
                              : "Add the first shared house task.",
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final taskId = doc.id;
                          final status = _taskStatus(data);
                          final isDone = status == 'done';
                          final isOverdue = _isOverdue(data);
                          final assignedTo = data['assignedTo']?.toString();
                          final assignee = assignedTo == null
                              ? null
                              : memberMap[assignedTo];
                          final assignedName =
                              data['assignedName'] ??
                              assignee?['displayName'] ??
                              data['assignedEmail'] ??
                              assignee?['email'] ??
                              "Unassigned";
                          final statusText =
                              _taskStatuses[status] ??
                              _taskStatuses['pending']!;

                          return Card(
                            color: isOverdue
                                ? Theme.of(context).colorScheme.errorContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _assigneeAvatar(assignee),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['title'] ?? "",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Assigned to: $assignedName\nStatus: $statusText\n${_dueDateText(data)}${isOverdue ? ' - Overdue' : ''}",
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            IconButton.outlined(
                                              tooltip: isDone
                                                  ? "Reopen"
                                                  : "Complete",
                                              icon: Icon(
                                                isDone
                                                    ? Icons
                                                          .radio_button_unchecked
                                                    : Icons.check_circle,
                                              ),
                                              onPressed: () async {
                                                await taskService.toggleTask(
                                                  widget.houseId,
                                                  taskId,
                                                  isDone,
                                                );
                                              },
                                            ),
                                            if (isAdmin)
                                              IconButton.outlined(
                                                tooltip: "Edit",
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _showTaskDialog(
                                                      docRef: doc.reference,
                                                      task: data,
                                                      members: members,
                                                    ),
                                              ),
                                            if (isAdmin)
                                              IconButton.outlined(
                                                tooltip: "Delete",
                                                icon: const Icon(Icons.delete),
                                                onPressed: () =>
                                                    taskService.deleteTask(
                                                      widget.houseId,
                                                      taskId,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text("Add Task"),
            onPressed: () => _showTaskDialog(members: members),
          ),
        );
      },
    );
  }
}

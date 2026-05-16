import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/avatar_service.dart';
import '../services/auth_service.dart';
import '../services/house_service.dart';
import '../services/rbac_service.dart';
import '../services/task_service.dart';
import '../widgets/app_state.dart';
import '../widgets/brand_icon.dart';
import '../widgets/theme_picker.dart';
import 'inventory_screen.dart';
import 'settings_screen.dart';

class HouseDashboardScreen extends StatefulWidget {
  final String houseId;
  final int initialTabIndex;

  const HouseDashboardScreen({
    super.key,
    required this.houseId,
    this.initialTabIndex = 0,
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
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final Set<String> _seenOverviewHighlights = {};

  DocumentReference<Map<String, dynamic>> get houseRef =>
      _houseService.houseRef(widget.houseId);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _tabController.addListener(_clearHighlightForCurrentTab);
    _clearHighlightForCurrentTab();
  }

  @override
  void dispose() {
    _tabController.removeListener(_clearHighlightForCurrentTab);
    _tabController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteLink() async {
    try {
      final link = await _houseService.inviteLinkForHouse(widget.houseId);

      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invite link copied")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invite Error: $e")));
    }
  }

  Future<void> _showInviteQr() async {
    try {
      final link = await _houseService.inviteLinkForHouse(widget.houseId);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Invite QR Code"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: link, size: 240),
                const SizedBox(height: 12),
                SelectableText(
                  link,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("Copy Link"),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));

                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invite QR Error: $e")));
    }
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

  bool _hasRecentActivity(
    QuerySnapshot<Map<String, dynamic>>? snapshot, {
    String primaryField = 'updatedAt',
    String fallbackField = 'createdAt',
  }) {
    if (snapshot == null || snapshot.docs.isEmpty) return false;

    for (final doc in snapshot.docs.take(3)) {
      final data = doc.data();
      final timestamp = data[primaryField] ?? data[fallbackField];

      if (timestamp is Timestamp) {
        final age = DateTime.now().difference(timestamp.toDate());

        if (age.inHours < 24) return true;
      }
    }

    return false;
  }

  bool _shouldHighlightOverview(String key, bool hasRecentActivity) {
    return hasRecentActivity && !_seenOverviewHighlights.contains(key);
  }

  String? _overviewKeyForTab(int index) {
    return switch (index) {
      1 => 'chat',
      2 => 'tasks',
      3 => 'inventory',
      4 => 'people',
      _ => null,
    };
  }

  void _clearHighlightForCurrentTab() {
    final key = _overviewKeyForTab(_tabController.index);

    if (key == null || _seenOverviewHighlights.contains(key)) return;

    setState(() => _seenOverviewHighlights.add(key));
  }

  void _openOverviewTarget(String key, int tabIndex) {
    setState(() => _seenOverviewHighlights.add(key));
    _tabController.animateTo(tabIndex);
  }

  Widget _adminAnalyticsPanel({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> inventory,
  }) {
    final doneTasks = tasks.where((task) {
      final data = task.data();
      return data['status'] == 'done' || data['isDone'] == true;
    }).length;
    final openTasks = tasks.length - doneTasks;
    final lowStock = inventory.where((item) {
      final quantity = (item.data()['quantity'] as num?)?.toInt() ?? 0;
      return quantity <= 1;
    }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Admin Analytics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip("Members", members.length.toString()),
                _metricChip("Open tasks", openTasks.toString()),
                _metricChip("Completed", doneTasks.toString()),
                _metricChip("Low stock", lowStock.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
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

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _taskService.getTasks(widget.houseId),
                    builder: (context, taskSnapshot) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _houseService.inventoryStream(widget.houseId),
                        builder: (context, inventorySnapshot) {
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: _houseService.messagesStream(
                              widget.houseId,
                              limit: 50,
                            ),
                            builder: (context, messageSnapshot) {
                              final memberCount =
                                  memberSnapshot.data?.docs.length ?? 0;
                              final taskCount =
                                  taskSnapshot.data?.docs.length ?? 0;
                              final inventoryCount =
                                  inventorySnapshot.data?.docs.length ?? 0;
                              final messageCount =
                                  messageSnapshot.data?.docs.length ?? 0;
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              final currentMember = currentUser == null
                                  ? null
                                  : memberSnapshot.data!.docs
                                        .where(
                                          (member) =>
                                              member.id == currentUser.uid,
                                        )
                                        .firstOrNull
                                        ?.data();
                              final isAdmin =
                                  currentMember != null &&
                                  RbacService.isAdmin(currentMember);
                              final recentPeople = _hasRecentActivity(
                                memberSnapshot.data,
                                primaryField: 'joinedAt',
                              );
                              final recentChat = _hasRecentActivity(
                                messageSnapshot.data,
                                primaryField: 'timestamp',
                              );
                              final recentInventory = _hasRecentActivity(
                                inventorySnapshot.data,
                              );
                              final recentTask = _hasRecentActivity(
                                taskSnapshot.data,
                              );

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final cardWidth = constraints.maxWidth >= 820
                                      ? (constraints.maxWidth - 36) / 4
                                      : constraints.maxWidth >= 520
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          _overviewCard(
                                            "People",
                                            'assets/brand/icons/people.svg',
                                            memberCount.toString(),
                                            width: cardWidth,
                                            highlighted:
                                                _shouldHighlightOverview(
                                                  'people',
                                                  recentPeople,
                                                ),
                                            onTap: () => _openOverviewTarget(
                                              'people',
                                              4,
                                            ),
                                          ),
                                          _overviewCard(
                                            "Chat",
                                            'assets/brand/icons/chat.svg',
                                            messageCount.toString(),
                                            width: cardWidth,
                                            highlighted:
                                                _shouldHighlightOverview(
                                                  'chat',
                                                  recentChat,
                                                ),
                                            onTap: () =>
                                                _openOverviewTarget('chat', 1),
                                          ),
                                          _overviewCard(
                                            "Tasks",
                                            'assets/brand/icons/tasks.svg',
                                            taskCount.toString(),
                                            width: cardWidth,
                                            highlighted:
                                                _shouldHighlightOverview(
                                                  'tasks',
                                                  recentTask,
                                                ),
                                            onTap: () =>
                                                _openOverviewTarget('tasks', 2),
                                          ),
                                          _overviewCard(
                                            "Inventory",
                                            'assets/brand/icons/inventory.svg',
                                            inventoryCount.toString(),
                                            width: cardWidth,
                                            highlighted:
                                                _shouldHighlightOverview(
                                                  'inventory',
                                                  recentInventory,
                                                ),
                                            onTap: () => _openOverviewTarget(
                                              'inventory',
                                              3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(height: 14),
                                        _adminAnalyticsPanel(
                                          members: memberSnapshot.data!.docs,
                                          tasks: taskSnapshot.data?.docs ?? [],
                                          inventory:
                                              inventorySnapshot.data?.docs ??
                                              [],
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _houseService.activityStream(widget.houseId),
                  builder: (context, activitySnapshot) {
                    final items = _overviewActivityItems(
                      activities: activitySnapshot.data,
                    );

                    if (items.isEmpty) {
                      return const Center(child: Text("Nothing to show"));
                    }

                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final target = item.target;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(item.icon)),
                            title: Text(item.title),
                            subtitle: Text(
                              "${item.message}\n${item.formattedDate}",
                            ),
                            isThreeLine: true,
                            trailing: target == null
                                ? null
                                : const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: target == null
                                ? null
                                : () =>
                                      _openOverviewTarget(target.$1, target.$2),
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
    bool highlighted = false,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? colors.primaryContainer.withValues(alpha: 0.82)
                  : colors.surfaceContainerHighest,
              border: Border.all(
                color: highlighted
                    ? colors.primary.withValues(alpha: 0.42)
                    : colors.outlineVariant.withValues(alpha: 0.4),
              ),
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
                        if (highlighted)
                          Text(
                            "New activity",
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                    const AppEmptyState(
                      icon: Icons.lock_outline,
                      title: "Invite required",
                      message:
                          "Use a valid invite link or code from the Home screen to join this house.",
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: const Text("Show Invite QR"),
            onPressed: _showInviteQr,
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _houseService.houseStream(widget.houseId),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            return Text(
              data?['name'] ?? "House",
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          const ThemePickerButton(),
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
                'assets/brand/icons/inventory.svg',
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

  List<_OverviewActivityItem> _overviewActivityItems({
    QuerySnapshot<Map<String, dynamic>>? activities,
  }) {
    final items = <_OverviewActivityItem>[];

    for (final doc in activities?.docs ?? const []) {
      final data = doc.data();
      final type = data['type']?.toString();
      final createdAt =
          _timestampDate(data['timestamp']) ??
          _timestampDate(data['createdAt']);
      final message = data['message']?.toString() ?? 'House update';

      items.add(
        _OverviewActivityItem(
          title: data['title']?.toString() ?? 'House activity',
          message: message,
          date: createdAt,
          formattedDate: _activityDateText(createdAt),
          icon: type == null ? Icons.bolt : _notificationIcon(type),
          target: _notificationTarget(type) ?? _legacyActivityTarget(data),
        ),
      );
    }

    items.sort((a, b) => b.sortValue.compareTo(a.sortValue));

    return items.take(10).toList();
  }

  DateTime? _timestampDate(Object? value) {
    if (value is Timestamp) return value.toDate();

    return null;
  }

  String _activityDateText(DateTime? date) {
    if (date == null) return 'Just now';

    return DateFormat('dd MMM, h:mm a').format(date);
  }

  IconData _notificationIcon(String? type) {
    return switch (type) {
      'task_completed' => Icons.task_alt,
      'task_assigned' => Icons.assignment_ind,
      'chat_message' => Icons.chat_bubble_outline,
      'inventory_added' ||
      'inventory_low_stock' ||
      'purchase_added' => Icons.inventory_2_outlined,
      'member_joined' => Icons.person_add_alt_1,
      _ => Icons.notifications_outlined,
    };
  }

  (String, int)? _notificationTarget(String? type) {
    return switch (type) {
      'chat_message' => ('chat', 1),
      'task_assigned' || 'task_completed' => ('tasks', 2),
      'inventory_added' ||
      'inventory_low_stock' ||
      'purchase_added' => ('inventory', 3),
      'member_joined' => ('people', 4),
      _ => null,
    };
  }

  (String, int)? _legacyActivityTarget(Map<String, dynamic> data) {
    final text =
        '${data['type'] ?? ''} ${data['action'] ?? ''} '
                '${data['message'] ?? ''}'
            .toLowerCase();

    if (text.contains('chat') || text.contains('message')) {
      return ('chat', 1);
    }

    if (text.contains('task')) {
      return ('tasks', 2);
    }

    if (text.contains('inventory') ||
        text.contains('stock') ||
        text.contains('purchase')) {
      return ('inventory', 3);
    }

    if (text.contains('member') || text.contains('join')) {
      return ('people', 4);
    }

    return null;
  }
}

class _OverviewActivityItem {
  final String title;
  final String message;
  final DateTime? date;
  final String formattedDate;
  final IconData icon;
  final (String, int)? target;

  const _OverviewActivityItem({
    required this.title,
    required this.message,
    required this.date,
    required this.formattedDate,
    required this.icon,
    required this.target,
  });

  int get sortValue => date?.millisecondsSinceEpoch ?? 0;
}

class ChatTab extends StatefulWidget {
  final String houseId;

  const ChatTab({super.key, required this.houseId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  static const int _messageLimit = 50;

  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final HouseService houseService = HouseService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;
  List<DocumentSnapshot<Map<String, dynamic>>> _messages = [];
  Object? _messagesError;
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.houseId != widget.houseId) {
      _subscribeToMessages();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToMessages() {
    _messagesSubscription?.cancel();
    _messages = [];
    _messagesError = null;
    _isLoadingMessages = true;

    _messagesSubscription = houseService
        .messagesStream(widget.houseId, limit: _messageLimit)
        .listen(
          (snapshot) {
            final shouldScroll = snapshot.docChanges.any(
              (change) => change.type == DocumentChangeType.added,
            );

            if (!mounted) return;

            setState(() {
              for (final change in snapshot.docChanges) {
                _messages.removeWhere((doc) => doc.id == change.doc.id);

                if (change.type != DocumentChangeType.removed) {
                  _messages.add(change.doc);
                }
              }

              _messages.sort(_compareMessagesNewestFirst);

              if (_messages.length > _messageLimit) {
                _messages = _messages.take(_messageLimit).toList();
              }

              _messagesError = null;
              _isLoadingMessages = false;
            });

            if (shouldScroll) _scrollToLatest();
          },
          onError: (Object error) {
            if (!mounted) return;

            setState(() {
              _messagesError = error;
              _isLoadingMessages = false;
            });
          },
        );
  }

  int _compareMessagesNewestFirst(
    DocumentSnapshot<Map<String, dynamic>> a,
    DocumentSnapshot<Map<String, dynamic>> b,
  ) {
    return _messageSortValue(b).compareTo(_messageSortValue(a));
  }

  int _messageSortValue(DocumentSnapshot<Map<String, dynamic>> doc) {
    final timestamp = doc.data()?['timestamp'];

    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }

    if (doc.metadata.hasPendingWrites) {
      return DateTime.now().millisecondsSinceEpoch;
    }

    return 0;
  }

  Future<void> _sendMessage() async {
    final message = controller.text.trim();

    if (message.isEmpty) return;

    try {
      await houseService.sendMessage(widget.houseId, message);

      controller.clear();
      _scrollToLatest();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Message Error: $e")));
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
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

  String _initial(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? "?" : trimmed[0].toUpperCase();
  }

  String _displayNameForMessage(
    Map<String, dynamic> data,
    Map<String, dynamic>? member,
  ) {
    return member?['displayName']?.toString() ??
        data['displayName']?.toString() ??
        member?['email']?.toString() ??
        data['email']?.toString() ??
        "House member";
  }

  Widget _messageAvatar(
    Map<String, dynamic> data,
    Map<String, dynamic>? member,
  ) {
    final photoUrl =
        member?['photoUrl']?.toString() ?? data['photoUrl']?.toString();
    final label = _displayNameForMessage(data, member);

    return CircleAvatar(
      radius: 14,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(_initial(label), style: const TextStyle(fontSize: 11))
          : null,
    );
  }

  String _messageTime(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];

    if (timestamp is Timestamp) {
      return DateFormat('h:mm a').format(timestamp.toDate());
    }

    return "Sending...";
  }

  Widget _messageBubble({
    required Map<String, dynamic> data,
    required Map<String, dynamic>? member,
    required bool isMine,
    required bool showAvatar,
  }) {
    final colors = Theme.of(context).colorScheme;
    final senderName = _displayNameForMessage(data, member);
    final text = data['text']?.toString() ?? "";
    final bubbleColor = isMine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final textColor = isMine ? colors.onPrimaryContainer : colors.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine && showAvatar) ...[
                _messageAvatar(data, member),
                const SizedBox(width: 8),
              ] else if (!isMine) ...[
                const SizedBox(width: 36),
              ],
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMine && showAvatar)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              senderName,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(text, style: TextStyle(color: textColor)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _messageTime(data),
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMine && showAvatar) ...[
                const SizedBox(width: 8),
                _messageAvatar(data, member),
              ] else if (isMine) ...[
                const SizedBox(width: 36),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _responsiveChat(
      child: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_messagesError != null) {
                  return AppErrorState(
                    title: "Could not load messages",
                    error: _messagesError,
                    onRetry: _subscribeToMessages,
                  );
                }

                if (_isLoadingMessages) {
                  return const AppLoadingState(message: "Loading chat...");
                }

                if (_messages.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: "No messages yet",
                    message: "Start the first house conversation.",
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: houseService.membersStream(widget.houseId),
                  builder: (context, memberSnapshot) {
                    final memberMap = {
                      for (final member in memberSnapshot.data?.docs ?? [])
                        member.id: member.data(),
                    };

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final data = _messages[index].data() ?? {};
                        final currentUser = FirebaseAuth.instance.currentUser;
                        final senderId = data['uid']?.toString();
                        final isMine = senderId == currentUser?.uid;
                        final nextData = index + 1 < _messages.length
                            ? _messages[index + 1].data()
                            : null;
                        final showAvatar = nextData?['uid'] != data['uid'];

                        return _messageBubble(
                          data: data,
                          member: senderId == null ? null : memberMap[senderId],
                          isMine: isMine,
                          showAvatar: showAvatar,
                        );
                      },
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
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
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
  static const List<String> _choreSuggestions = [
    'Vacuum',
    'Take out trash',
    'Clean kitchen',
    'Clean bathroom',
    'Laundry',
    'Wash dishes',
    'Mop floor',
    'Dust shelves',
    'Lawn cleaning',
    'Water plants',
    'Grocery run',
    'Change bedsheets',
  ];
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

  List<String> _filteredChoreSuggestions(TextEditingController controller) {
    final query = controller.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? _choreSuggestions
        : _choreSuggestions
              .where((item) => item.toLowerCase().contains(query))
              .toList();

    return matches.take(12).toList();
  }

  Widget _choreSuggestionChips({
    required TextEditingController controller,
    required StateSetter setDialogState,
  }) {
    final suggestions = _filteredChoreSuggestions(controller);

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: suggestions.map((suggestion) {
          return ActionChip(
            label: Text(suggestion),
            onPressed: () {
              setDialogState(() {
                controller.text = suggestion;
                controller.selection = TextSelection.collapsed(
                  offset: suggestion.length,
                );
              });
            },
          );
        }).toList(),
      ),
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
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: "Task title",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _choreSuggestionChips(
                      controller: titleController,
                      setDialogState: setDialogState,
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
          backgroundColor: Colors.transparent,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addTask(
    String houseId,
    String title, {
    String? assignedTo,
    String? assignedEmail,
    String? assignedName,
    DateTime? dueDate,
    String status = 'pending',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final taskTitle = title.trim();

    if (taskTitle.isEmpty) return;

    final doc = await _tasksRef(houseId).add({
      'title': taskTitle,
      'assignedTo': assignedTo,
      'assignedEmail': assignedEmail,
      'assignedName': assignedName,
      'createdBy': user.uid,
      'status': status,
      'isDone': status == 'done',
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (assignedTo != null && assignedTo.isNotEmpty) {
      await _addNotification(
        houseId: houseId,
        type: 'task_assigned',
        title: 'Task assigned',
        message:
            '${assignedName ?? assignedEmail ?? 'Someone'} was assigned "$taskTitle".',
        taskId: doc.id,
        userId: assignedTo,
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasks(String houseId) {
    return _tasksRef(
      houseId,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> updateTask(
    String houseId,
    String taskId, {
    required String title,
    String? assignedTo,
    String? assignedEmail,
    String? assignedName,
    DateTime? dueDate,
    required String status,
  }) async {
    final taskTitle = title.trim();

    if (taskTitle.isEmpty) return;

    final taskRef = _tasksRef(houseId).doc(taskId);
    final previous = await taskRef.get();
    final previousAssignedTo = previous.data()?['assignedTo']?.toString();
    final previousStatus = _statusFromTask(previous.data() ?? {});

    await taskRef.update({
      'title': taskTitle,
      'assignedTo': assignedTo,
      'assignedEmail': assignedEmail,
      'assignedName': assignedName,
      'status': status,
      'isDone': status == 'done',
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (assignedTo != null &&
        assignedTo.isNotEmpty &&
        assignedTo != previousAssignedTo) {
      await _addNotification(
        houseId: houseId,
        type: 'task_assigned',
        title: 'Task assigned',
        message:
            '${assignedName ?? assignedEmail ?? 'Someone'} was assigned "$taskTitle".',
        taskId: taskId,
        userId: assignedTo,
      );
    }

    if (status == 'done' && previousStatus != 'done') {
      await _addNotification(
        houseId: houseId,
        type: 'task_completed',
        title: 'Task completed',
        message: '"$taskTitle" was marked done.',
        taskId: taskId,
        userId: assignedTo,
      );
    }
  }

  Future<void> toggleTask(
    String houseId,
    String taskId,
    bool currentValue,
  ) async {
    final taskRef = _tasksRef(houseId).doc(taskId);
    final task = await taskRef.get();
    final data = task.data() ?? {};
    final nextDone = !currentValue;
    final title = data['title']?.toString() ?? 'Task';
    final assignedTo = data['assignedTo']?.toString();

    await taskRef.update({
      'isDone': nextDone,
      'status': nextDone ? 'done' : 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (nextDone) {
      await _addNotification(
        houseId: houseId,
        type: 'task_completed',
        title: 'Task completed',
        message: '"$title" was marked done.',
        taskId: taskId,
        userId: assignedTo,
      );
    }
  }

  Future<void> deleteTask(String houseId, String taskId) {
    return _tasksRef(houseId).doc(taskId).delete();
  }

  CollectionReference<Map<String, dynamic>> _tasksRef(String houseId) {
    return _db.collection('houses').doc(houseId).collection('tasks');
  }

  String _statusFromTask(Map<String, dynamic> task) {
    final status = task['status']?.toString();

    if (status != null && status.isNotEmpty) return status;

    return task['isDone'] == true ? 'done' : 'pending';
  }

  Future<void> _addNotification({
    required String houseId,
    required String type,
    required String title,
    required String message,
    required String taskId,
    String? userId,
  }) async {
    await NotificationService().createHouseNotification(
      houseId: houseId,
      type: type,
      title: title,
      message: message,
      targetUserId: userId,
      data: {'taskId': taskId},
    );
  }
}

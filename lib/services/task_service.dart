import 'package:cloud_firestore/cloud_firestore.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addTask(
    String houseId,
    String title,
  ) async {
    await _db
        .collection('houses')
        .doc(houseId)
        .collection('tasks')
        .add({
      'title': title,
      'completed': false,
      'createdAt': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getTasks(String houseId) {
    return _db
        .collection('houses')
        .doc(houseId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleTask(
    String houseId,
    String taskId,
    bool value,
  ) async {
    await _db
        .collection('houses')
        .doc(houseId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'completed': value,
    });
  }
}
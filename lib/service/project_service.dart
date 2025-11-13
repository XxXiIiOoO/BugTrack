import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/UserData.dart';
import '../models/project.dart';
import '../models/role.dart';

class ProjectService {
  ProjectService._();

  static final ProjectService instance = ProjectService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Project> createProject({
    required UserData owner,
    required String name,
    String description = '',
  }) async {
    final ref = _firestore.collection('projects').doc();
    final memberIds = <String>{owner.id};
    final memberRoles = <String, Role>{owner.id: Role.admin};
    final now = DateTime.now();

    final data = {
      'name': name.trim(),
      'description': description.trim(),
      'ownerId': owner.id,
      'memberIds': memberIds.toList(),
      'memberRoles': memberRoles.map((key, value) => MapEntry(key, value.name)),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await ref.set(data);
    return Project(
      id: ref.id,
      name: name.trim(),
      description: description.trim(),
      ownerId: owner.id,
      memberIds: memberIds.toList(),
      memberRoles: memberRoles,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> renameProject({
    required String projectId,
    required String name,
    String? description,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (description != null) data['description'] = description.trim();
    await _firestore.collection('projects').doc(projectId).update(data);
  }

  Future<void> updateMemberRole({
    required Project project,
    required String userId,
    required Role role,
  }) async {
    final ref = _firestore.collection('projects').doc(project.id);
    final memberIds = Set<String>.from(project.memberIds)..add(userId);
    final roles = Map<String, String>.from(
      project.memberRoles.map((key, value) => MapEntry(key, value.name)),
    )..[userId] = role.name;

    await ref.update({
      'memberIds': memberIds.toList(),
      'memberRoles': roles,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> removeMember({
    required Project project,
    required String userId,
  }) async {
    if (project.ownerId == userId) {
      throw StateError('Owner cannot be removed from the project');
    }
    final ref = _firestore.collection('projects').doc(project.id);
    final memberIds = List<String>.from(project.memberIds)..remove(userId);
    final roles = Map<String, String>.from(
      project.memberRoles.map((key, value) => MapEntry(key, value.name)),
    )..remove(userId);

    await ref.update({
      'memberIds': memberIds,
      'memberRoles': roles,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<UserData?> findUserByEmail(String email) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return UserData.fromMap(doc.id, doc.data());
  }
}

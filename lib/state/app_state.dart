import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/UserData.dart';
import '../models/project.dart';
import '../models/role.dart';

/// Глобальное состояние приложения: текущий пользователь и слушатель Firebase Auth.
class AppState extends ChangeNotifier {
  UserData? currentUser;
  List<Project> projects = const [];
  String? _activeProjectId;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _projectsSub;

  Project? get activeProject {
    if (projects.isEmpty) return null;
    if (_activeProjectId != null) {
      final match = projects.where((p) => p.id == _activeProjectId).toList();
      if (match.isNotEmpty) return match.first;
    }
    return projects.first;
  }

  Role? get activeProjectRole {
    final project = activeProject;
    final uid = currentUser?.id;
    if (project == null || uid == null) return null;
    return project.memberRoles[uid];
  }

  void setActiveProject(String? projectId) {
    if (projectId == _activeProjectId) return;
    if (projectId != null && projects.every((p) => p.id != projectId)) return;
    _activeProjectId = projectId;
    notifyListeners();
  }

  void attachAuth() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        currentUser = null;
         _clearProjects();
        notifyListeners();
        return;
      }

      final uid = user.uid;
      final usersCol = FirebaseFirestore.instance.collection('users');
      final snap = await usersCol.doc(uid).get();

      if (!snap.exists) {
        final data = UserData(
          id: uid,
          email: user.email ?? '',
          displayName: user.displayName ?? (user.email ?? 'User'),
          firstName: '',
          lastName: '',
          photoUrl: user.photoURL ?? '',
          role: Role.tester,
          projects: const [],
          createdAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        );
        await usersCol.doc(uid).set(data.toMap());
        currentUser = data;
      } else {
        final u = UserData.fromMap(uid, snap.data()!);
        currentUser = u.copyWith(
          lastSeenAt: DateTime.now(),
          photoUrl: user.photoURL ?? u.photoUrl,
        );
        unawaited(usersCol.doc(uid).update({
          'lastSeenAt': FieldValue.serverTimestamp(),
          if ((user.photoURL ?? '').isNotEmpty) 'photoUrl': user.photoURL,
        }));
      }

      _subscribeProjects(uid);
      notifyListeners();
    });
  }

  void _subscribeProjects(String uid) {
    _projectsSub?.cancel();
    _projectsSub = FirebaseFirestore.instance
        .collection('projects')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      projects = snap.docs.map(Project.fromDoc).toList();
      if (projects.isEmpty) {
        _activeProjectId = null;
      } else if (_activeProjectId == null || projects.every((p) => p.id != _activeProjectId)) {
        _activeProjectId = projects.first.id;
      }
      notifyListeners();
    });
  }

  Role? roleForProject(String projectId, [String? uid]) {
    final userId = uid ?? currentUser?.id;
    if (userId == null) return null;
    for (final project in projects) {
      if (project.id == projectId) {
        return project.memberRoles[userId];
      }
    }
    return null;
  }

  String? get activeProjectId => activeProject?.id;

  void _clearProjects() {
    _projectsSub?.cancel();
    _projectsSub = null;
    projects = const [];
    _activeProjectId = null;
  }

  void setCurrentUser(UserData data) {
    currentUser = data;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _projectsSub?.cancel();
    super.dispose();
  }
}

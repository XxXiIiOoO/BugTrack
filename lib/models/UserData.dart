// lib/models/user_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role.dart';

class UserData {
  final String id;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String photoUrl;
  final Role role;
  final List<String> projects;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  const UserData({
    required this.id,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.photoUrl,
    required this.role,
    required this.projects,
    this.createdAt,
    this.lastSeenAt,
  });

  UserData copyWith({
    String? id,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoUrl,
    Role? role,
    List<String>? projects,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) {
    return UserData(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      projects: projects ?? this.projects,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory UserData.fromMap(String id, Map<String, dynamic> map) {
    final roleStr = (map['role'] as String?) ?? 'viewer';
    return UserData(
      id: id,
      email: (map['email'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      firstName: (map['firstName'] as String?) ?? '',
      lastName: (map['lastName'] as String?) ?? '',
      photoUrl: (map['photoUrl'] as String?) ?? '',
      role: Role.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => Role.tester,
      ),
      projects: List<String>.from((map['projects'] as List?) ?? const []),
      createdAt: _toDate(map['createdAt']),
      lastSeenAt: _toDate(map['lastSeenAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'role': role.name,
      'projects': projects,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
    }..removeWhere((_, v) => v == null);
  }

  static DateTime? _parseTs(Timestamp? ts) => ts?.toDate();
  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return _parseTs(v);
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

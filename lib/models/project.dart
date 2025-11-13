import 'package:cloud_firestore/cloud_firestore.dart';

import 'role.dart';

/// Проект, объединяющий задачи, участников и их роли.
class Project {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, Role> memberRoles;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.memberRoles,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasMembers => memberIds.isNotEmpty;

  Role? roleFor(String uid) => memberRoles[uid];

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    List<String>? memberIds,
    Map<String, Role>? memberRoles,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      memberRoles: memberRoles ?? this.memberRoles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rolesRaw = (data['memberRoles'] as Map?) ?? const <String, dynamic>{};

    return Project(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      memberIds: List<String>.from((data['memberIds'] as List?) ?? const []),
      memberRoles: rolesRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          Role.values.firstWhere(
            (role) => role.name == value,
            orElse: () => Role.tester,
          ),
        ),
      ),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _tryParseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'memberRoles': memberRoles.map((key, value) => MapEntry(key, value.name)),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    }..removeWhere((_, value) => value == null);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

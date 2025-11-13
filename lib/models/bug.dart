import 'package:cloud_firestore/cloud_firestore.dart';

class Bug {
  final String id;
  final String title;
  final String description;
  final String priority; // Low | Medium | High
  final String status;   // Open | In Progress | Done
  final List<String> labels;
  final DateTime creationDate;
  final DateTime? estimatedCompletion;
  final String assignedTo; // uid of user
  final String createdBy; // uid of creator

  Bug({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.labels,
    required this.creationDate,
    required this.estimatedCompletion,
    required this.assignedTo,
    required this.createdBy,
  });

  Bug copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    String? status,
    List<String>? labels,
    DateTime? creationDate,
    DateTime? estimatedCompletion,
    String? assignedTo,
    String? createdBy,
  }) {
    return Bug(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      labels: labels ?? this.labels,
      creationDate: creationDate ?? this.creationDate,
      estimatedCompletion: estimatedCompletion ?? this.estimatedCompletion,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory Bug.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Bug(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      priority: data['priority'] ?? 'Medium',
      status: data['status'] ?? 'Open',
      labels: (data['labels'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      creationDate: (data['creationDate'] is Timestamp)
          ? (data['creationDate'] as Timestamp).toDate()
          : DateTime.tryParse('${data['creationDate']}') ?? DateTime.now(),
      estimatedCompletion: (data['estimatedCompletion'] is Timestamp)
          ? (data['estimatedCompletion'] as Timestamp).toDate()
          : (data['estimatedCompletion'] != null
          ? DateTime.tryParse('${data['estimatedCompletion']}')
          : null),
      assignedTo: data['assignedTo'] ?? '',
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'labels': labels,
      'creationDate': Timestamp.fromDate(creationDate),
      'estimatedCompletion': estimatedCompletion != null ? Timestamp.fromDate(estimatedCompletion!) : null,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
    };
  }
}

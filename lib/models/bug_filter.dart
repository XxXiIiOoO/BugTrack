class BugFilter {
  BugFilter({
    Set<String>? statuses,
    Set<String>? priorities,
    this.assignedToMe = false,
    this.createdByMe = false,
    this.unassignedOnly = false,
    this.overdueOnly = false,
    this.recentOnly = false,
  })  : statuses = statuses != null ? Set<String>.from(statuses) : const <String>{},
        priorities = priorities != null ? Set<String>.from(priorities) : const <String>{};

  final Set<String> statuses;
  final Set<String> priorities;
  final bool assignedToMe;
  final bool createdByMe;
  final bool unassignedOnly;
  final bool overdueOnly;
  final bool recentOnly;

  static final BugFilter empty = BugFilter();

  bool get isEmpty =>
      statuses.isEmpty &&
      priorities.isEmpty &&
      !assignedToMe &&
      !createdByMe &&
      !unassignedOnly &&
      !overdueOnly &&
      !recentOnly;

  BugFilter copyWith({
    Set<String>? statuses,
    Set<String>? priorities,
    bool? assignedToMe,
    bool? createdByMe,
    bool? unassignedOnly,
    bool? overdueOnly,
    bool? recentOnly,
  }) {
    return BugFilter(
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      assignedToMe: assignedToMe ?? this.assignedToMe,
      createdByMe: createdByMe ?? this.createdByMe,
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      recentOnly: recentOnly ?? this.recentOnly,
    );
  }

  BugFilter toggleStatus(String status) {
    final next = Set<String>.from(statuses);
    if (!next.remove(status)) {
      next.add(status);
    }
    return copyWith(statuses: next);
  }

  BugFilter togglePriority(String priority) {
    final next = Set<String>.from(priorities);
    if (!next.remove(priority)) {
      next.add(priority);
    }
    return copyWith(priorities: next);
  }

  BugFilter setAssignedToMe(bool value) {
    return copyWith(
      assignedToMe: value,
      unassignedOnly: value ? false : unassignedOnly,
    );
  }

  BugFilter setUnassignedOnly(bool value) {
    return copyWith(
      unassignedOnly: value,
      assignedToMe: value ? false : assignedToMe,
    );
  }

  BugFilter setCreatedByMe(bool value) {
    return copyWith(createdByMe: value);
  }

  BugFilter setOverdueOnly(bool value) {
    return copyWith(overdueOnly: value);
  }

  BugFilter setRecentOnly(bool value) {
    return copyWith(recentOnly: value);
  }

  BugFilter clear() => BugFilter();

  BugFilter merge(BugFilter other) {
    return BugFilter(
      statuses: other.statuses.isNotEmpty ? other.statuses : statuses,
      priorities: other.priorities.isNotEmpty ? other.priorities : priorities,
      assignedToMe: other.assignedToMe,
      createdByMe: other.createdByMe,
      unassignedOnly: other.unassignedOnly,
      overdueOnly: other.overdueOnly,
      recentOnly: other.recentOnly,
    );
  }
}

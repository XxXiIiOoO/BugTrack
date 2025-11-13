// lib/models/role.dart
enum Role { admin, tester, developer }

extension RoleX on Role {
  String get label {
    switch (this) {
      case Role.admin:
        return 'Administrator';
      case Role.tester:
        return 'Tester';
      case Role.developer:
        return 'Developer';
    }
  }
}

enum Permission {
  manageUsers,
  viewAllBugs,
  createBug,
  editAnyBug,
  editAssignedBug,
  changeStatusAny,
  changeStatusAssigned,
  comment,
  viewStats,
}

final Map<Role, Set<Permission>> kRolePerms = {
  Role.admin: Permission.values.toSet(),
  Role.tester: {
    Permission.viewAllBugs,
    Permission.createBug,
    Permission.comment,
    Permission.viewStats,
  },
  Role.developer: {
    Permission.viewAllBugs,
    Permission.createBug,
    Permission.editAssignedBug,
    Permission.changeStatusAssigned,
    Permission.comment,
    Permission.viewStats,
  },
};

bool can(Role role, Permission perm) => kRolePerms[role]?.contains(perm) ?? false;

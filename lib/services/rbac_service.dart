class RbacService {
  static String getRole(Map member) {
    return member['role'] ?? 'member';
  }

  static bool isAdmin(Map member) {
    final role = getRole(member);
    return role == 'admin' || role == 'owner';
  }

  static bool canManageMembers(Map member) {
    final role = getRole(member);
    return role == 'admin' || role == 'owner';
  }

  static bool canDeleteHouse(Map member) {
    final role = getRole(member);
    return role == 'admin' || role == 'owner';
  }
}

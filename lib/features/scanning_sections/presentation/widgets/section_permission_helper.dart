class SectionPermissionHelper {
  SectionPermissionHelper._();

  /// Checks if a scanning section is accessible given the user's role names list.
  /// 
  /// - Admin users have unrestricted access.
  /// - All users are granted view access to dashboard and scanning sections.
  static bool isSectionAllowed(String sectionTitle, List<String> userRoles) {
    if (userRoles.isEmpty) return true;

    // 1. Admin / SuperAdmin has access to all sections
    final bool isAdmin = userRoles.any((r) {
      final normalized = _normalize(r);
      return normalized.contains('admin') || normalized.contains('superadmin') || normalized == 'root';
    });
    if (isAdmin) return true;

    final normalizedTitle = _normalize(sectionTitle);

    // 2. Exact or normalized matching against the title
    for (final role in userRoles) {
      final normalizedRole = _normalize(role);
      if (normalizedRole == normalizedTitle) return true;
    }

    // 3. Section specific mapped role names
    final allowedKeywords = _getSectionRoleKeywords(normalizedTitle);
    for (final role in userRoles) {
      final normalizedRole = _normalize(role);
      for (final keyword in allowedKeywords) {
        if (normalizedRole == keyword || normalizedRole.contains(keyword) || keyword.contains(normalizedRole)) {
          return true;
        }
      }
    }

    return false;
  }

  static List<String> _getSectionRoleKeywords(String normalizedTitle) {
    if (normalizedTitle.contains('knittingproduction') || normalizedTitle.contains('knitting')) {
      return ['knittingproduction', 'knitting', 'knit'];
    }
    if (normalizedTitle.contains('gbsreceiving') || normalizedTitle.contains('gbs')) {
      return ['gbsreceiving', 'gbs'];
    }
    if (normalizedTitle.contains('lotmaking') || normalizedTitle.contains('lot')) {
      return ['lotmaking', 'pdmerchandizer', 'pdmerchandiser', 'lot', 'pd'];
    }
    if (normalizedTitle.contains('processing') || normalizedTitle.contains('pbs')) {
      return ['processing', 'pbs', 'process'];
    }
    if (normalizedTitle.contains('inductionstore') || normalizedTitle.contains('induction')) {
      return ['inductionstore', 'induction', 'store'];
    }
    if (normalizedTitle.contains('stitchinglineschedule') || normalizedTitle.contains('stitching')) {
      return ['stitchinglineschedule', 'stitching', 'stitch'];
    }
    if (normalizedTitle.contains('traytracking') || normalizedTitle.contains('tracking')) {
      return ['traytracking', 'tracking', 'tray'];
    }
    if (normalizedTitle.contains('wipmonitoring') || normalizedTitle.contains('wip')) {
      return ['wipmonitoring', 'wip'];
    }
    if (normalizedTitle.contains('cartonpacking') || normalizedTitle.contains('packing')) {
      return ['cartonpacking', 'packing', 'carton', 'cartonization'];
    }
    if (normalizedTitle.contains('mdreceiving') || normalizedTitle.contains('md')) {
      return ['mdreceiving', 'md'];
    }
    if (normalizedTitle.contains('processingwastereceiving') || normalizedTitle.contains('wastereceiving') || normalizedTitle.contains('waste')) {
      return ['processingwastereceiving', 'wastereceiving', 'processingwaste', 'waste'];
    }
    if (normalizedTitle.contains('unholdtrays') || normalizedTitle.contains('unhold')) {
      return ['unholdtrays', 'unhold', 'knittingproduction', 'knitting', 'processing', 'pbs'];
    }
    return [normalizedTitle];
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[\s_\-\/\\]'), '');
  }
}

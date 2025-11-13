import '../models/role.dart';
import 'app_localizations.dart';

String roleLabel(AppLocalizations l10n, Role role) {
  switch (role) {
    case Role.admin:
      return l10n.t('role.admin');
    case Role.tester:
      return l10n.t('role.tester');
    case Role.developer:
      return l10n.t('role.developer');
  }
}

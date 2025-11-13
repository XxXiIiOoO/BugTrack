import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EmailNotificationService {
  EmailNotificationService._();

  static final EmailNotificationService instance = EmailNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNewTaskEmail({
    required String recipientUserId,
    required String projectId,
    required String bugId,
    required String bugTitle,
    required String projectName,
    required String creatorName,
  }) async {
    try {
      final userSnap = await _firestore.collection('users').doc(recipientUserId).get();
      final email = (userSnap.data()?['email'] as String?)?.trim();
      if (email == null || email.isEmpty) return;

      final sanitizedProject = projectName.isEmpty ? 'BugTreck' : projectName;
      final subject = 'Новая задача в $sanitizedProject';
      final textBody =
          'Вам назначена задача "$bugTitle" в проекте "$sanitizedProject". Автор: $creatorName.';
      final htmlBody = '''
<p>Здравствуйте!</p>
<p>Вам назначена новая задача <strong>$bugTitle</strong> в проекте <strong>$sanitizedProject</strong>.</p>
<p>Автор: $creatorName.</p>
<p>Откройте приложение BugTreck, чтобы посмотреть детали.</p>
''';

      await _firestore.collection('mail').add({
        'to': email,
        'message': {
          'subject': subject,
          'text': textBody,
          'html': htmlBody,
        },
        'metadata': {
          'type': 'new_bug_assignment',
          'bugId': bugId,
          'projectId': projectId,
        },
      });
    } catch (e, st) {
      debugPrint('Failed to queue email notification: $e\n$st');
    }
  }
}

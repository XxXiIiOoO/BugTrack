import 'package:cloud_firestore/cloud_firestore.dart';

/// Простой кеш отображаемых имён пользователей.
/// Ожидается коллекция: /users/{uid} с полем displayName (или email).
class UserCache {
  UserCache._();
  static final UserCache instance = UserCache._();

  final _db = FirebaseFirestore.instance;
  final Map<String, String> _names = {}; // uid -> displayName/email

  /// Синхронный доступ к уже известному имени (или null).
  String? peek(String uid) => _names[uid];

  /// Асинхронно получает имя; кеширует.
  Future<String> getName(String uid) async {
    if (uid.isEmpty) return 'Unassigned';
    final cached = _names[uid];
    if (cached != null && cached.isNotEmpty) return cached;

    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? const {};
    final name = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();

    final resolved = (name?.isNotEmpty == true)
        ? name!
        : (email?.isNotEmpty == true ? email! : 'User');

    _names[uid] = resolved;
    return resolved;
  }

  /// Подписка на изменения имени; также поддерживает кеш.
  Stream<String> watchName(String uid) {
    if (uid.isEmpty) {
      return Stream.value('Unassigned');
    }
    final ref = _db.collection('users').doc(uid);
    return ref.snapshots().map((doc) {
      final data = doc.data() ?? const {};
      final name = (data['displayName'] as String?)?.trim();
      final email = (data['email'] as String?)?.trim();
      final resolved = (name?.isNotEmpty == true)
          ? name!
          : (email?.isNotEmpty == true ? email! : 'User');
      _names[uid] = resolved;
      return resolved;
    });
  }

  /// Опционально: массовая подзагрузка имён по uid (например, участников проекта).
  Future<void> preload(Iterable<String> uids) async {
    final toLoad = uids.where((u) => u.isNotEmpty && !_names.containsKey(u)).toList();
    if (toLoad.isEmpty) return;
    // Firestore не поддерживает in-запрос >10 в стандартном тарифе — грузим поштучно тут.
    for (final uid in toLoad) {
      await getName(uid);
    }
  }
}

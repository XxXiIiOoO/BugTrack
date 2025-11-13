// lib/services/storage_service.dart
import 'dart:io' show File; // для мобильных/десктоп
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required String projectId,
    required String bugId,
    required String filePath,
    required String fileName,
  }) async {
    final ref = _storage.ref('projects/$projectId/bugs/$bugId/$fileName');
    if (kIsWeb) {
      // На вебе File из dart:io недоступен — используй uploadBytes вместо этого
      throw UnsupportedError('Use uploadBytes on Web');
    }
    final task = await ref.putFile(File(filePath));
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadBytes({
    required String projectId,
    required String bugId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final ref = _storage.ref('projects/$projectId/bugs/$bugId/$fileName');
    final metadata = SettableMetadata(contentType: contentType);
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String url) async {
    await _storage.refFromURL(url).delete();
  }

  Future<String> uploadUserAvatarFile({
    required String uid,
    required String filePath,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Use uploadUserAvatarBytes on Web');
    }
    final ext = _guessExtension(filePath);
    final ref = _userAvatarRef(uid, ext);
    final metadata = SettableMetadata(contentType: _contentTypeFromExt(ext));
    final task = await ref.putFile(File(filePath), metadata);
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadUserAvatarBytes({
    required String uid,
    required Uint8List bytes,
    String? fileName,
  }) async {
    final ext = _guessExtension(fileName);
    final ref = _userAvatarRef(uid, ext);
    final metadata = SettableMetadata(contentType: _contentTypeFromExt(ext));
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  Reference _userAvatarRef(String uid, String extension) {
    final safeExt = extension.toLowerCase();
    return _storage.ref('users/$uid/avatar.$safeExt');
  }

  String _guessExtension(String? source) {
    if (source == null || source.isEmpty) return 'jpg';
    final dot = source.lastIndexOf('.');
    if (dot == -1 || dot == source.length - 1) return 'jpg';
    final ext = source.substring(dot + 1).toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

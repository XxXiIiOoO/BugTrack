import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final DateTime timestamp;
  final List<ChatAttachment> attachments;

  ChatMessage({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    this.attachments = const [],
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawAttachments = (data['attachments'] as List?) ?? const [];
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse('${data['timestamp']}') ?? DateTime.now(),
      attachments: rawAttachments
          .map((raw) => ChatAttachment.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'timestamp': Timestamp.fromDate(timestamp),
        'attachments': attachments.map((att) => att.toMap()).toList(),
      };
}

class ChatAttachment {
  final String name;
  final String url;
  final String contentType;

  const ChatAttachment({
    required this.name,
    required this.url,
    required this.contentType,
  });

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      contentType: map['contentType'] ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'contentType': contentType,
      };

  bool get isImage => contentType.startsWith('image/');
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Resource {
  const Resource({
    required this.resourceId,
    required this.lessonId,
    required this.title,
    required this.type,
    required this.url,
    required this.storagePath,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  final String resourceId;
  final String lessonId;
  final String title;

  /// Kept as an opaque persisted value until supported resource types are
  /// formally approved.
  final String type;

  /// Persisted exactly as documented. URL and Storage semantics are deferred.
  final String url;
  final String storagePath;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  factory Resource.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final resourceId = data['resourceId'];
    final lessonId = data['lessonId'];
    final title = data['title'];
    final type = data['type'];
    final url = data['url'];
    final storagePath = data['storagePath'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (resourceId is! String ||
        resourceId.isEmpty ||
        resourceId != documentId ||
        lessonId is! String ||
        lessonId.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        type is! String ||
        type.trim().isEmpty ||
        url is! String ||
        storagePath is! String ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid resource document.');
    }

    return Resource(
      resourceId: resourceId,
      lessonId: lessonId,
      title: title,
      type: type,
      url: url,
      storagePath: storagePath,
      order: order,
      isActive: isActive,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static DateTime _parseTimestamp(Object? value) {
    if (value is! Timestamp) {
      throw const FormatException('Invalid resource timestamp.');
    }
    return value.toDate();
  }
}

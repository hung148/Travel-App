import 'package:cloud_firestore/cloud_firestore.dart';

class DestinationTip {
  final String id;
  final String ownerId;
  final String destinationName;
  final String destinationKey;
  final String? destinationPlaceId;
  final String displayName;
  final bool isAnonymous;
  final String category;
  final String text;
  final String status;
  final int likesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DestinationTip({
    required this.id,
    required this.ownerId,
    required this.destinationName,
    required this.destinationKey,
    this.destinationPlaceId,
    required this.displayName,
    required this.isAnonymous,
    required this.category,
    required this.text,
    this.status = 'published',
    this.likesCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  String get visibleName => isAnonymous ? 'Traveler' : displayName;

  factory DestinationTip.fromMap(Map<String, dynamic> data, String id) {
    return DestinationTip(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      destinationName: data['destinationName'] as String? ?? '',
      destinationKey: data['destinationKey'] as String? ?? '',
      destinationPlaceId: data['destinationPlaceId'] as String?,
      displayName: data['displayName'] as String? ?? 'Traveler',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      category: data['category'] as String? ?? 'general',
      text: data['text'] as String? ?? '',
      status: data['status'] as String? ?? 'published',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'destinationName': destinationName,
      'destinationKey': destinationKey,
      'destinationPlaceId': destinationPlaceId,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
      'category': category,
      'text': text,
      'status': status,
      'likesCount': likesCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String normalizeDestinationKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

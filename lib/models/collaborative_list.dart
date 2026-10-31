import 'package:cloud_firestore/cloud_firestore.dart';

/// A short form of a list or account ID, for telling apart equal names.
String shortId(String id) => id.length < 8 ? id : id.substring(0, 8);

class CollaborativeList {
  const CollaborativeList({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.memberIds,
  });

  final String id;
  final String ownerId;
  final String name;
  final List<String> memberIds;

  factory CollaborativeList.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return CollaborativeList(
      id: document.id,
      ownerId: data['ownerId'] as String,
      name: data['name'] as String,
      memberIds: List<String>.unmodifiable(data['memberIds'] as List),
    );
  }
}

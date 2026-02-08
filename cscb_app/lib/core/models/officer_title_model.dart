/// Model representing an officer title within an organization
class OfficerTitleModel {
  final String id;
  final String orgId;
  final String title;
  final int memberCount;

  OfficerTitleModel({
    required this.id,
    required this.orgId,
    required this.title,
    required this.memberCount,
  });

  /// Create a copy with updated fields
  OfficerTitleModel copyWith({
    String? id,
    String? orgId,
    String? title,
    int? memberCount,
  }) {
    return OfficerTitleModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfficerTitleModel &&
        other.id == id &&
        other.orgId == orgId &&
        other.title == title &&
        other.memberCount == memberCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orgId.hashCode ^
        title.hashCode ^
        memberCount.hashCode;
  }

  @override
  String toString() {
    return 'OfficerTitleModel(id: $id, orgId: $orgId, title: $title, memberCount: $memberCount)';
  }
}

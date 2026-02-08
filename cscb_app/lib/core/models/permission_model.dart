/// Model representing a permission with its state
class PermissionModel {
  final String key;
  final String label;
  final String description;
  final bool isGranted;

  PermissionModel({
    required this.key,
    required this.label,
    required this.description,
    required this.isGranted,
  });

  /// Create a copy with updated fields
  PermissionModel copyWith({
    String? key,
    String? label,
    String? description,
    bool? isGranted,
  }) {
    return PermissionModel(
      key: key ?? this.key,
      label: label ?? this.label,
      description: description ?? this.description,
      isGranted: isGranted ?? this.isGranted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionModel &&
        other.key == key &&
        other.label == label &&
        other.description == description &&
        other.isGranted == isGranted;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        label.hashCode ^
        description.hashCode ^
        isGranted.hashCode;
  }

  @override
  String toString() {
    return 'PermissionModel(key: $key, label: $label, description: $description, isGranted: $isGranted)';
  }
}

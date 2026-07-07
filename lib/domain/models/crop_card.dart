/// Represents a small crop card shown in the horizontal list at the top.
class CropCard {
  final String id;
  final String name;
  final String imageUrl;
  final double progress;     // 0.0 to 1.0, shown as progress bar
  final bool hasAlert;       // Shows alert icon if true

  const CropCard({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.progress,
    this.hasAlert = false,
  });

  CropCard copyWith({
    String? id,
    String? name,
    String? imageUrl,
    double? progress,
    bool? hasAlert,
  }) {
    return CropCard(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      progress: progress ?? this.progress,
      hasAlert: hasAlert ?? this.hasAlert,
    );
  }
}

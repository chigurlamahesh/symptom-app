class Symptom {
  final String id;
  final String displayName;
  bool isSelected;

  Symptom({
    required this.id,
    required this.displayName,
    this.isSelected = false,
  });

  factory Symptom.fromRaw(String raw) {
    return Symptom(
      id: raw,
      displayName: raw
          .split('_')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' '),
    );
  }

  Symptom copyWith({bool? isSelected}) {
    return Symptom(
      id: id,
      displayName: displayName,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

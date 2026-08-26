class DhikrOption {
  final String id, label;
  const DhikrOption(this.id, this.label);
}

const defaultDhikr = [
  DhikrOption('subhanallah', 'Sübhanallah'),
  DhikrOption('alhamdulillah', 'Elhamdülillah'),
  DhikrOption('allahu-akbar', 'Allahu Ekber'),
  DhikrOption('salawat', 'Salavat'),
];

class TasbihSession {
  final String dhikrId;
  final int count, target;
  final DateTime startedAt;
  final bool hapticEnabled;
  const TasbihSession({
    required this.dhikrId,
    this.count = 0,
    this.target = 33,
    required this.startedAt,
    this.hapticEnabled = true,
  });
  TasbihSession copyWith({
    String? dhikrId,
    int? count,
    int? target,
    DateTime? startedAt,
    bool? hapticEnabled,
  }) => TasbihSession(
    dhikrId: dhikrId ?? this.dhikrId,
    count: count ?? this.count,
    target: target ?? this.target,
    startedAt: startedAt ?? this.startedAt,
    hapticEnabled: hapticEnabled ?? this.hapticEnabled,
  );
  TasbihSession increment() => copyWith(count: count + 1);
  TasbihSession decrement() => copyWith(count: count > 0 ? count - 1 : 0);
  TasbihSession reset() => copyWith(count: 0);
}

class TasbihHistoryEntry {
  final String dhikrId;
  final int count, target;
  final DateTime completedAt;
  const TasbihHistoryEntry({
    required this.dhikrId,
    required this.count,
    required this.target,
    required this.completedAt,
  });
}

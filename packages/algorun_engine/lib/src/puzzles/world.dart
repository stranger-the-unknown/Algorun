final class WorldDef {
  const WorldDef({
    required this.id,
    required this.title,
    required this.index,
    required this.puzzleIds,
    this.concepts = const [],
    this.prerequisites = const [],
  });

  final String id;
  final String title;
  final int index;
  final List<String> puzzleIds;
  final List<String> concepts;
  final List<String> prerequisites;
}

final class WorldsManifest {
  const WorldsManifest(this.worlds);
  final List<WorldDef> worlds;

  WorldDef? byId(String id) {
    for (final w in worlds) {
      if (w.id == id) return w;
    }
    return null;
  }
}

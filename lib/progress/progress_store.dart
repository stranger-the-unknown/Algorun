import 'save_codec.dart';
import 'save_data.dart';

/// What loading produced: the save to play with, and anything that could not
/// be read (for developer output and tests; the player is never blocked).
final class StoreLoad {
  const StoreLoad(this.save, [this.issues = const []]);

  final PlayerSave save;
  final List<SaveIssue> issues;
}

/// Where the save lives. Widgets never touch storage or JSON: they go through
/// the progress notifier, which goes through this.
abstract interface class ProgressStore {
  /// Never throws. No save yet is a fresh save. An unreadable save is kept
  /// aside by the store (never deleted) and play starts from a fresh one.
  Future<StoreLoad> load();

  /// Replaces the stored save. May throw on a storage failure; the caller
  /// reports it and keeps playing from memory.
  Future<void> save(PlayerSave save);

  /// Deletes the save (the player's "reset progress").
  Future<void> clear();
}

/// Holds the encoded save in memory, exactly as a file would. For tests and
/// for platforms without a file system; a new notifier over the same store
/// behaves like an app restart.
final class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([this.text]);

  /// The stored save text, or null for a fresh install.
  String? text;

  /// Texts that could not be read, kept aside in order.
  final List<String> keptAside = [];

  int writes = 0;

  @override
  Future<StoreLoad> load() async {
    final stored = text;
    if (stored == null) return const StoreLoad(PlayerSave.fresh);
    final read = decodeSave(stored);
    if (!read.usable) keptAside.add(stored);
    return StoreLoad(read.save, read.issues);
  }

  @override
  Future<void> save(PlayerSave save) async {
    text = encodeSave(save);
    writes++;
  }

  @override
  Future<void> clear() async => text = null;
}

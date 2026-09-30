import 'file_progress_store.dart';
import 'progress_store.dart';

/// A JSON file in the app's support directory.
ProgressStore platformProgressStore() => FileProgressStore.appSupport();

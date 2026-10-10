import '../error/failure.dart';

/// UI state of a screen or section (architecture/flutter.md §3).
sealed class ViewState<T> {
  const ViewState();
}

class Loading<T> extends ViewState<T> {
  const Loading();
}

class Content<T> extends ViewState<T> {
  const Content(this.data, {this.isStale = false});
  final T data;

  /// Cached data shown while a refresh is pending or failed.
  final bool isStale;
}

class Empty<T> extends ViewState<T> {
  const Empty();
}

class Failed<T> extends ViewState<T> {
  const Failed(this.failure);
  final Failure failure;
}

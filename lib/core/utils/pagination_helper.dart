class PaginationHelper<T> {
  final int pageSize;

  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  final List<T> _items = [];

  PaginationHelper({this.pageSize = 20});

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  int get page => _page;

  void reset() {
    _page = 1;
    _hasMore = true;
    _items.clear();
    _loading = false;
  }

  Future<void> load({
    required Future<List<T>> Function(int page, int limit) fetch,
  }) async {
    if (_loading || !_hasMore) return;

    _loading = true;

    final result = await fetch(_page, pageSize);

    if (result.length < pageSize) {
      _hasMore = false;
    }

    _items.addAll(result);
    _page++;
    _loading = false;
  }
}

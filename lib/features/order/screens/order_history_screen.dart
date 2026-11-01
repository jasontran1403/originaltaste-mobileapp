// lib/features/order/screens/order_history_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/order/order_models.dart';
import '../../../data/storage/session_storage.dart';
import '../../../services/order_service.dart';
import '../../../shared/widgets/order_shared_widgets.dart';

// ════════════════════════════════════════════════════════════════
// ROOT
// ════════════════════════════════════════════════════════════════

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() =>
      _OrderHistoryScreenState();
}

class _OrderHistoryScreenState
    extends ConsumerState<OrderHistoryScreen> {
  UserRole? _role;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final roleStr = await SessionStorage.getRole();
    if (mounted) {
      setState(() {
        _role       = UserRole.fromString(roleStr);
        _roleLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    // So sánh không phân biệt hoa thường để tránh lỗi enum
    final roleStr  = (_role?.name ?? '').toLowerCase();
    final isSuperAdmin  = roleStr.contains('super');
    final isAdmin       = roleStr == 'admin' || roleStr == 'superadmin' || isSuperAdmin;
    final isSeller      = roleStr == 'seller';

    // SELLER   → chỉ Sale history
    // ADMIN    → chỉ POS history
    // SUPERADMIN → cả Sale + POS history (toggle)
    return _HistoryShell(
      isSuperAdmin: isSuperAdmin,
      isAdmin:      isAdmin && !isSuperAdmin,
      isSeller:     isSeller,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHELL
// ════════════════════════════════════════════════════════════════

enum _HistoryMode { sale, pos }

class _HistoryShell extends StatefulWidget {
  final bool isSuperAdmin;
  final bool isAdmin;
  final bool isSeller;

  const _HistoryShell({
    required this.isSuperAdmin,
    required this.isAdmin,
    required this.isSeller,
  });

  @override
  State<_HistoryShell> createState() => _HistoryShellState();
}

class _HistoryShellState extends State<_HistoryShell> {
  late _HistoryMode _mode;

  late DateTime _fromDate;
  late DateTime _toDate;

  final _searchCtrl   = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // ADMIN mặc định xem POS, còn lại xem Sale
    _mode = (widget.isAdmin || widget.isSuperAdmin)
        ? _HistoryMode.pos
        : _HistoryMode.sale;

    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _toDate   = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _searchQuery = v.trim());
    });
  }

  Future<void> _pickDateRange() async {
    final now    = DateTime.now();
    final picked = await showDateRangePicker(
      context:          context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate:        DateTime(2020),
      lastDate:         now,
      currentDate:      now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) {
        final isDark  = Theme.of(ctx).brightness == Brightness.dark;
        final primary = isDark ? AppColors.primary : AppColors.primaryDark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor:  primary,
              brightness: Theme.of(ctx).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _fromDate = DateTime(picked.start.year, picked.start.month,
            picked.start.day, 0, 0, 0);
        _toDate   = DateTime(picked.end.year, picked.end.month,
            picked.end.day, 23, 59, 59, 999);
      });
    }
  }

  String _fmtDateRange() {
    String _d(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}';
    final f       = _fromDate;
    final t       = _toDate;
    final sameDay = f.year == t.year &&
        f.month == t.month &&
        f.day == t.day;
    if (sameDay) return '${_d(f)}/${f.year}';
    return '${_d(f)} – ${_d(t)}/${t.year}';
  }

  // Title khi không có toggle
  String get _screenTitle {
    if (widget.isSeller) return 'Lịch sử đơn hàng';
    if (widget.isAdmin)  return 'Lịch sử POS';
    return 'Lịch sử';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final onBg      = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final bg        = isDark ? AppColors.darkBg : AppColors.lightBg;

    final listKey = ValueKey(
      '${_mode.name}-$_searchQuery-'
          '${_fromDate.millisecondsSinceEpoch}-'
          '${_toDate.millisecondsSinceEpoch}',
    );

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [

        // ── HEADER ────────────────────────────────────────────────
        Container(
          color: cardBg,
          child: SafeArea(bottom: false, child: Column(children: [

            // Row 1: title / toggle + date picker
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [

                // SuperAdmin thấy toggle, còn lại thấy title cố định
                if (widget.isSuperAdmin)
                  _ModeToggle(
                    mode:      _mode,
                    primary:   primary,
                    secondary: secondary,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _searchCtrl.clear();
                      _searchQuery = '';
                    }),
                  )
                else
                  Text(_screenTitle,
                      style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w800,
                          color:      onBg)),

                const Spacer(),

                // Date range button
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: primary.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14, color: primary),
                          const SizedBox(width: 6),
                          Text(_fmtDateRange(),
                              style: TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                  color:      primary)),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_drop_down,
                              size: 16, color: primary),
                        ]),
                  ),
                ),
              ]),
            ),

            // Row 2: Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  _onSearch,
                style:      TextStyle(fontSize: 14, color: onBg),
                decoration: InputDecoration(
                  hintText: 'Tìm mã đơn, tên khách, số điện thoại...',
                  hintStyle: TextStyle(fontSize: 13, color: secondary),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: secondary),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 16, color: secondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                      : null,
                  filled:    true,
                  fillColor: isDark
                      ? AppColors.darkBg.withOpacity(0.5)
                      : const Color(0xFFF1F5F9),
                  isDense:   true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: primary, width: 1.5)),
                ),
              ),
            ),

            Divider(height: 1, color: border),
          ])),
        ),

        // ── BODY ──────────────────────────────────────────────────
        Expanded(
          child: _mode == _HistoryMode.sale
              ? _SaleHistoryList(
            key:          listKey,
            fromTs:       _fromDate.millisecondsSinceEpoch,
            toTs:         _toDate.millisecondsSinceEpoch,
            query:        _searchQuery,
            isSuperAdmin: widget.isSuperAdmin,
            isDark:       isDark,
            primary:      primary,
            secondary:    secondary,
            cardBg:       cardBg,
            border:       border,
          )
              : _PosHistoryList(
            key:          listKey,
            fromTs:       _fromDate.millisecondsSinceEpoch,
            toTs:         _toDate.millisecondsSinceEpoch,
            query:        _searchQuery,
            isSuperAdmin: widget.isSuperAdmin,
            isDark:       isDark,
            primary:      primary,
            secondary:    secondary,
            cardBg:       cardBg,
            border:       border,
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MODE TOGGLE — chỉ SuperAdmin dùng
// ════════════════════════════════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  final _HistoryMode mode;
  final Color primary, secondary;
  final ValueChanged<_HistoryMode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.primary,
    required this.secondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:        secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: secondary.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tab(_HistoryMode.pos,  'POS',
            Icons.point_of_sale_outlined),
        _tab(_HistoryMode.sale, 'Sale',
            Icons.receipt_long_outlined),
      ]),
    );
  }

  Widget _tab(_HistoryMode m, String label, IconData icon) {
    final sel = mode == m;
    return GestureDetector(
      onTap: () => onChanged(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color:        sel ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: sel
              ? [BoxShadow(
              color:      primary.withOpacity(0.3),
              blurRadius: 4)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: sel ? Colors.white : secondary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color:      sel ? Colors.white : secondary)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SALE HISTORY LIST — chỉ SELLER và SUPERADMIN
// ════════════════════════════════════════════════════════════════

class _SaleHistoryList extends StatefulWidget {
  final int fromTs, toTs;
  final String query;
  final bool isDark;
  final bool isSuperAdmin;
  final Color primary, secondary, cardBg, border;

  const _SaleHistoryList({
    super.key,
    required this.fromTs,
    required this.toTs,
    required this.query,
    required this.isSuperAdmin,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.cardBg,
    required this.border,
  });

  @override
  State<_SaleHistoryList> createState() => _SaleHistoryListState();
}

class _SaleHistoryListState extends State<_SaleHistoryList> {
  static const _pageSize = 20;

  List<OrderModel> _items  = [];
  bool    _loading         = false;
  bool    _loadingMore     = false;
  bool    _hasMore         = true;
  int     _loadedCount     = _pageSize;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final size   = reset ? _pageSize : _loadedCount;
      final result = await OrderService.instance.getSaleOrderHistory(
        fromTs:       widget.fromTs,
        toTs:         widget.toTs,
        query:        widget.query,
        page:         0,
        size:         size,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      setState(() {
        _items       = result.items;
        _hasMore     = result.hasNext;
        _loadedCount = reset ? _pageSize : size;
        _loading     = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _items.length ~/ _pageSize;
      final result   = await OrderService.instance.getSaleOrderHistory(
        fromTs:       widget.fromTs,
        toTs:         widget.toTs,
        query:        widget.query,
        page:         nextPage,
        size:         _pageSize,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore     = result.hasNext;
        _loadedCount = _items.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(widget.primary)));
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorView(
          msg: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return _EmptyView(secondary: widget.secondary);
    }

    return RefreshIndicator(
      onRefresh:       () => _load(reset: false),
      color:           widget.primary,
      backgroundColor: widget.cardBg,
      child: ListView.separated(
        controller:      _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount:       _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          if (i == _items.length) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation(widget.primary)),
            ));
          }
          return _SaleOrderCard(
            order:        _items[i],
            isDark:       widget.isDark,
            primary:      widget.primary,
            secondary:    widget.secondary,
            cardBg:       widget.cardBg,
            border:       widget.border,
            isSuperAdmin: widget.isSuperAdmin,
            onCancelled:  () => _load(reset: false),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// POS HISTORY LIST — ADMIN và SUPERADMIN
// ════════════════════════════════════════════════════════════════

class _PosHistoryList extends StatefulWidget {
  final int fromTs, toTs;
  final String query;
  final bool isDark;
  final bool isSuperAdmin;
  final Color primary, secondary, cardBg, border;

  const _PosHistoryList({
    super.key,
    required this.fromTs,
    required this.toTs,
    required this.query,
    required this.isSuperAdmin,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.cardBg,
    required this.border,
  });

  @override
  State<_PosHistoryList> createState() => _PosHistoryListState();
}

class _PosHistoryListState extends State<_PosHistoryList> {
  static const _pageSize = 20;

  List<Map<String, dynamic>> _items = [];
  bool    _loading     = false;
  bool    _loadingMore = false;
  bool    _hasMore     = true;
  int     _loadedCount = _pageSize;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final size   = reset ? _pageSize : _loadedCount;
      final result = await OrderService.instance.getPosOrderHistory(
        fromTs:       widget.fromTs,
        toTs:         widget.toTs,
        query:        widget.query,
        page:         0,
        size:         size,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      final content = (result['content'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _items       = content;
        _hasMore     = result['hasNext'] == true;
        _loadedCount = reset ? _pageSize : size;
        _loading     = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _items.length ~/ _pageSize;
      final result   = await OrderService.instance.getPosOrderHistory(
        fromTs:       widget.fromTs,
        toTs:         widget.toTs,
        query:        widget.query,
        page:         nextPage,
        size:         _pageSize,
        isSuperAdmin: widget.isSuperAdmin,
      );
      if (!mounted) return;
      final content = (result['content'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _items.addAll(content);
        _hasMore     = result['hasNext'] == true;
        _loadedCount = _items.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(widget.primary)));
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorView(
          msg: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return _EmptyView(secondary: widget.secondary);
    }

    return RefreshIndicator(
      onRefresh:       () => _load(reset: false),
      color:           widget.primary,
      backgroundColor: widget.cardBg,
      child: ListView.separated(
        controller:      _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount:       _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == _items.length) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation(widget.primary)),
            ));
          }
          return _PosOrderCard(
            order:     _items[i],
            isDark:    widget.isDark,
            primary:   widget.primary,
            secondary: widget.secondary,
            cardBg:    widget.cardBg,
            border:    widget.border,
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SALE ORDER CARD
// ════════════════════════════════════════════════════════════════

class _SaleOrderCard extends StatefulWidget {
  final OrderModel order;
  final bool isDark;
  final bool isSuperAdmin;
  final Color primary, secondary, cardBg, border;
  final VoidCallback? onCancelled;

  const _SaleOrderCard({
    required this.order,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.cardBg,
    required this.border,
    this.isSuperAdmin = false,
    this.onCancelled,
  });

  @override
  State<_SaleOrderCard> createState() => _SaleOrderCardState();
}

class _SaleOrderCardState extends State<_SaleOrderCard> {
  bool _isExporting  = false;
  bool _isCancelling = false;
  OrderModel get o => widget.order;

  bool get _isCancelled => '${o.status}'.toUpperCase().contains('CANCEL');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/order-detail/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color:        widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: widget.border),
          boxShadow: [BoxShadow(
            color: Colors.black
                .withOpacity(widget.isDark ? 0.25 : 0.08),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          )],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildInfo(),
              _buildActions(context),
            ]),
      ),
    );
  }

  Widget _buildHeader() {
    final divider = widget.isDark
        ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: divider))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        widget.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_outlined,
              size: 20, color: widget.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.orderCode,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                      color: widget.isDark
                          ? Colors.white : Colors.black87)),
              const SizedBox(height: 3),
              Text(fmtOrderDate(o.createdAt),
                  style: TextStyle(
                      fontSize: 12, color: widget.secondary)),
            ])),
        OrderStatusBadge(status: o.status),
      ]),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (o.customerName != null || o.customerPhone != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 15, color: widget.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    [o.customerName, o.customerPhone]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                        fontSize: 13, color: widget.secondary),
                  )),
                ]),
              ),
            Row(children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 15, color: widget.secondary),
              const SizedBox(width: 8),
              Text('${o.items.length} sản phẩm',
                  style: TextStyle(
                      fontSize: 13, color: widget.secondary)),
              const Spacer(),
              PaymentStatusBadge(status: o.paymentStatus),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng cộng:',
                      style: TextStyle(
                          fontSize: 14, color: widget.secondary)),
                  Row(children: [
                    Text(fmtMoney(o.finalAmount),
                        style: const TextStyle(
                            fontSize:   17,
                            fontWeight: FontWeight.w700,
                            color:      Colors.green)),
                    if (o.discountAmount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('-${fmtMoney(o.discountAmount)}',
                            style: TextStyle(
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.error)),
                      ),
                    ],
                  ]),
                ]),
          ]),
    );
  }

  Widget _buildActions(BuildContext context) {
    // Nút Hủy chỉ dành cho super_admin và đơn CHƯA hủy
    final canCancel = widget.isSuperAdmin && !_isCancelled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        if (canCancel) ...[
          Expanded(child: _ActionBtn(
            icon: _isCancelling
                ? Icons.hourglass_empty_rounded
                : Icons.cancel_outlined,
            label:   _isCancelling ? 'Đang hủy...' : 'Hủy',
            onTap:   _isCancelling ? null : () => _confirmCancel(context),
            loading: _isCancelling,
            outlined: true,
            color:   AppColors.error,
          )),
          const SizedBox(width: 10),
        ],
        Expanded(child: _ActionBtn(
          icon:     Icons.visibility_outlined,
          label:    'Chi tiết',
          onTap:    () => context.push('/order-detail/${o.id}'),
          outlined: true,
          color:    widget.secondary,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(
          icon: _isExporting
              ? Icons.hourglass_empty_rounded
              : Icons.picture_as_pdf_outlined,
          // 3 nút → rút gọn nhãn cho vừa; 2 nút → giữ "Tạo Invoice"
          label:   _isExporting
              ? 'Đang tạo...'
              : (canCancel ? 'Invoice' : 'Tạo Invoice'),
          onTap:   _isExporting ? null : () => _exportInvoice(context),
          loading: _isExporting,
          color:   widget.primary,
        )),
      ]),
    );
  }

  // ── Popup xác nhận hủy ──────────────────────────────────────────
  Future<void> _confirmCancel(BuildContext context) async {
    final isDark = widget.isDark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Hủy đơn hàng',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        content: Text(
          'Bạn có chắc muốn hủy đơn ${o.orderCode}?\n\n'
              'Hệ thống sẽ cộng lại tồn kho và hoàn số lượng về đúng '
              'lô giá vốn (FIFO). Thao tác này không thể hoàn tác.',
          style: TextStyle(
              fontSize: 13.5,
              height:   1.4,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
        actionsPadding:
        const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Không',
                style: TextStyle(color: widget.secondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _doCancel(context);
  }

  Future<void> _doCancel(BuildContext context) async {
    setState(() => _isCancelling = true);
    try {
      final res = await OrderService.instance.cancelSaleOrder(o.id);
      if (!context.mounted) return;

      // Backend trả HTTP 200 cho cả success/error → phân biệt bằng data
      if (res.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Đã hủy đơn ${o.orderCode} và hoàn kho.'),
          backgroundColor: Colors.green.shade700,
          behavior:        SnackBarBehavior.floating,
        ));
        widget.onCancelled?.call(); // reload danh sách
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message : 'Hủy đơn thất bại'),
          backgroundColor: Colors.red.shade700,
          behavior:        SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Lỗi: $e'),
          backgroundColor: Colors.red.shade700,
          behavior:        SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _exportInvoice(BuildContext ctx) async {
    setState(() => _isExporting = true);
    try {
      await OrderService.instance.generateInvoice(o.id, ctx);
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content:         Text('Lỗi: $e'),
        backgroundColor: Colors.red.shade700,
        behavior:        SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ════════════════════════════════════════════════════════════════
// POS ORDER CARD — tap để xem chi tiết, badge nhân viên ca
// ════════════════════════════════════════════════════════════════

class _PosOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isDark;
  final Color primary, secondary, cardBg, border;

  const _PosOrderCard({
    required this.order,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.cardBg,
    required this.border,
  });

  static const _srcColors = {
    'TAKE_AWAY':   Color(0xFF0EA5E9),
    'DINE_IN':     Color(0xFF0D9488),
    'SHOPEE_FOOD': Color(0xFFEE4D2D),
    'GRAB_FOOD':   Color(0xFF00B14F),
  };
  static const _srcLabels = {
    'TAKE_AWAY':   'Take Away',
    'DINE_IN':     'Dine In',
    'SHOPEE_FOOD': 'Shopee',
    'GRAB_FOOD':   'Grab',
  };

  String _fmtMoney(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');

  String _fmtDT(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}  '
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  void _showDetail(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor  = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _PosOrderDetailSheet(
        order:       order,
        isDark:      isDark,
        primary:     primary,
        secondary:   secondary,
        surfaceColor: surfaceColor,
        borderColor:  borderColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final src       = order['orderSource'] as String? ?? 'OFFLINE';
    final color     = _srcColors[src] ?? const Color(0xFF94A3B8);
    final label     = _srcLabels[src] ?? 'Offline';
    final isCash    = order['paymentMethod'] == 'CASH';
    final amount    = (order['finalAmount']    as num?)?.toDouble() ?? 0;
    final discount  = (order['discountAmount'] as num?)?.toDouble() ?? 0;
    final ts        = (order['createdAt'] as int?) ?? 0;
    final custName  = order['customerName']  as String? ?? '';
    final custPhone = order['customerPhone'] as String? ?? '';
    final staffName = order['staffName']     as String? ?? '';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: border))),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(label[0],
                        style: TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            color:      color))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['orderCode'] ?? '--',
                            style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : Colors.black87)),
                        const SizedBox(height: 4),
                        Row(children: [
                          _Badge(label: label, color: color),
                          const SizedBox(width: 6),
                          _Badge(
                            label: isCash ? 'Tiền mặt' : 'CK',
                            color: isCash
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                          ),
                        ]),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_fmtMoney(amount)}đ',
                            style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.w800,
                                color:      primary)),
                        if (discount > 0)
                          Text('-${_fmtMoney(discount)}đ',
                              style: TextStyle(
                                  fontSize:   11,
                                  color:      Colors.red.shade400,
                                  fontWeight: FontWeight.w600)),
                      ]),
                ]),
              ),

              // Body — compact, không có items preview
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Customer (nếu có)
                      if (custName.isNotEmpty || custPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Icon(Icons.person_outline_rounded,
                                size: 13, color: secondary),
                            const SizedBox(width: 5),
                            Text(
                              [custName, custPhone]
                                  .where((e) => e.isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                  fontSize: 12, color: secondary),
                            ),
                          ]),
                        ),

                      // Time + staff
                      Row(children: [
                        Icon(Icons.schedule_outlined,
                            size: 13, color: secondary),
                        const SizedBox(width: 5),
                        Text(ts > 0 ? _fmtDT(ts) : '--',
                            style: TextStyle(
                                fontSize: 12, color: secondary)),
                      ]),

                      // Tap hint
                      const SizedBox(height: 6),

                      Row(children: [
                        if (staffName.isNotEmpty) ...[
                          Icon(Icons.badge_outlined,
                              size: 13, color: secondary),
                          const SizedBox(width: 4),
                          Text(staffName,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: secondary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ]),
                    ]),
              ),
            ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// POS ORDER DETAIL SHEET
// ════════════════════════════════════════════════════════════════

class _PosOrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isDark;
  final Color primary, secondary, surfaceColor, borderColor;

  const _PosOrderDetailSheet({
    required this.order,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.surfaceColor,
    required this.borderColor,
  });

  static const _srcColors = {
    'TAKE_AWAY':   Color(0xFF0EA5E9),
    'DINE_IN':     Color(0xFF0D9488),
    'SHOPEE_FOOD': Color(0xFFEE4D2D),
    'GRAB_FOOD':   Color(0xFF00B14F),
  };
  static const _srcLabels = {
    'TAKE_AWAY':   'Take Away',
    'DINE_IN':     'Dine In',
    'SHOPEE_FOOD': 'Shopee',
    'GRAB_FOOD':   'Grab',
  };

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');

  String _fmtDT(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}'
        '  ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final src        = order['orderSource'] as String? ?? 'OFFLINE';
    final color      = _srcColors[src] ?? const Color(0xFF94A3B8);
    final label      = _srcLabels[src] ?? 'Offline';
    final isCash     = order['paymentMethod'] == 'CASH';
    final ts         = (order['createdAt'] as int?) ?? 0;
    final custName   = order['customerName']  as String? ?? '';
    final custPhone  = order['customerPhone'] as String? ?? '';
    final staffName  = order['staffName']     as String? ?? '';
    final items      = (order['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    // Tổng tiền các món (basePrice * qty) — tạm tính thực
    final isAppOrder = items.any(
          (i) => (i['discountPercent'] as num?)?.toInt() == -1,
    );

    double subtotalSum = 0;
    for (final i in items) {
      subtotalSum += (i['subtotal'] as num?)?.toDouble() ?? 0;
    }

    // Tạm tính hiển thị:
    // - Đơn app (Shopee/Grab): dùng totalAmount từ backend (đã include phí sàn raw)
    // - Đơn thường: dùng subtotalSum tính từ các items

    final discountAmount     = (order['discountAmount']     as num?)?.toDouble() ?? 0;
    final platformFeeAmount  = (order['platformFeeAmount']  as num?)?.toDouble() ?? 0;
    final platformFeePercent = (order['platformFeePercent'] as num?)?.toDouble() ?? 0;
    final vatAmount          = (order['vatAmount']          as num?)?.toDouble() ?? 0;
    final finalAmount        = (order['finalAmount']        as num?)?.toDouble() ?? 0;
    final discountNote       = order['discountNote']        as String? ?? '';
    final totalAmount        = (order['totalAmount'] as num?)?.toDouble() ?? 0;

    final displaySubtotal = isAppOrder ? subtotalSum : totalAmount;

    final txtPri     = isDark ? Colors.white     : const Color(0xFF0F172A);
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color:        surfaceColor,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      child: Column(children: [

        // ── Drag handle ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color:        secondary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // ── Header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Order code + close
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: Center(child: Text(label[0],
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['orderCode'] ?? '--',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: txtPri)),
                      Row(children: [
                        _Badge(label: label, color: color),
                        const SizedBox(width: 6),
                        _Badge(
                          label: isCash ? 'Tiền mặt' : 'Chuyển khoản',
                          color: isCash
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                        ),
                      ]),
                    ])),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: secondary),
                  style: IconButton.styleFrom(
                    backgroundColor: secondary.withOpacity(0.08),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ]),

              const SizedBox(height: 8),

              // Shift badge (nếu có)
              if (staffName.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: primary.withOpacity(0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 12, color: primary),
                        const SizedBox(width: 4),
                        Text(staffName,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: primary)),
                      ]),
                ),

              // Time + customer
              Row(children: [
                Icon(Icons.schedule_outlined,
                    size: 12, color: secondary),
                const SizedBox(width: 4),
                Text(ts > 0 ? _fmtDT(ts) : '--',
                    style: TextStyle(
                        fontSize: 12, color: secondary)),
              ]),

              if (custName.isNotEmpty || custPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 12, color: secondary),
                  const SizedBox(width: 4),
                  Text(
                    [custName, custPhone]
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                        fontSize: 12, color: secondary),
                  ),
                ]),
              ],

              const SizedBox(height: 14),
              Divider(height: 1, color: borderColor),
            ],
          ),
        ),

        // ── Items list ────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: borderColor),
            itemBuilder: (_, idx) {
              final item        = items[idx];
              final name        = item['productName']   as String? ?? '';
              final qty         = (item['quantity']     as num?)?.toInt() ?? 0;
              // basePrice = giá gốc chưa trừ phí sàn
              final basePrice  = (item['basePrice']       as num?)?.toDouble() ?? 0;
              final finalPrice = (item['finalUnitPrice']   as num?)?.toDouble() ?? 0;
              final discPct    = (item['discountPercent']  as num?)?.toInt()    ?? 0;
              final isByWeight = item['isByWeight']        as bool?             ?? false;
              final subtotal    = (item['subtotal']     as num?)?.toDouble() ?? 0;
              final addonAmt    = (item['addonAmount']  as num?)?.toDouble() ?? 0;
              final note        = item['note']          as String? ?? '';
              final ingredients = (item['ingredients']  as List? ?? [])
                  .cast<Map<String, dynamic>>();

              // Group ingredients by variantGroupName
              final Map<String, List<Map<String, dynamic>>> groups = {};
              for (final ing in ingredients) {
                final grp = ing['variantGroupName'] as String? ?? 'Khác';
                groups.putIfAbsent(grp, () => []).add(ing);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Product row
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tên sản phẩm
                          Expanded(
                            child: Text(name,
                                style: TextStyle(
                                    fontSize:   13,
                                    fontWeight: FontWeight.w700,
                                    color:      txtPri)),
                          ),
                          const SizedBox(width: 8),
                          // Số lượng
                          Text('× $qty',
                              style: TextStyle(
                                  fontSize: 13, color: secondary)),
                          const SizedBox(width: 14),
                          // Thành tiền (basePrice * qty)
                          Text('${_fmt(basePrice * qty)}đ',
                              style: TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700,
                                  color:      primary)),
                        ]),

                    // Đơn giá gốc
                    const SizedBox(height: 2),
                    Row(children: [
                      if (discPct > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Giảm $discPct%',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange)),
                        ),
                      ],
                      if (addonAmt > 0) ...[
                        const SizedBox(width: 6),
                        Text('+${_fmt(addonAmt)}đ addon',
                            style: TextStyle(
                                fontSize: 10,
                                color: secondary.withOpacity(0.7))),
                      ],
                    ]),

                    // Ingredients / variants
                    if (groups.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...groups.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: entry.value.map((ing) {
                              final ingName = ing['ingredientName']
                              as String? ?? '';
                              final ingQty  = (ing['quantity']
                              as num?)?.toDouble() ?? 0;
                              final unit    = ing['unit']
                              as String? ?? '';
                              // Format qty: bỏ .0 nếu là số nguyên
                              final qtyStr  = ingQty % 1 == 0
                                  ? ingQty.toInt().toString()
                                  : ingQty.toStringAsFixed(2);
                              return Padding(
                                padding: const EdgeInsets.only(
                                    left: 10, top: 2),
                                child: Row(children: [
                                  Text(
                                    unit.isNotEmpty
                                        ? '×$qtyStr ($unit) $ingName'
                                        : '×$qtyStr $ingName',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: secondary, fontWeight: FontWeight.w400),
                                  ),
                                ]),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],

                    // Note
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.notes_outlined,
                            size: 11,
                            color: Colors.orange.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(note,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ]),
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        // ── Summary footer ────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, bottomPad + 20),
          decoration: BoxDecoration(
            color:  surfaceColor,
            border: Border(
                top: BorderSide(color: borderColor)),
            boxShadow: [BoxShadow(
              color:  Colors.black
                  .withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            )],
          ),
          child: Column(children: [

            // Tạm tính (subtotalSum = tổng basePrice * qty)
            _SummaryRow(
              label:     'Tạm tính',
              value:     '${_fmt(displaySubtotal)}đ',
              secondary: secondary,
              isDark:    isDark,
            ),

            // Giảm giá
            if (discountAmount > 0) ...[
              const SizedBox(height: 4),
              _SummaryRow(
                label:      discountNote.isNotEmpty
                    ? discountNote : 'Giảm giá',
                value:      '-${_fmt(discountAmount)}đ',
                secondary:  secondary,
                isDark:     isDark,
                labelColor: Colors.green.shade600,
                valueColor: Colors.green.shade600,
                labelIcon:  Icons.local_offer_outlined,
              ),
            ],

            // Phí sàn
            if (platformFeeAmount > 0) ...[
              const SizedBox(height: 4),
              _SummaryRow(
                label:      'Phí sàn${platformFeePercent > 0 ? '  ${platformFeePercent.toStringAsFixed(0)}%' : ''}',
                value:      '-${_fmt(platformFeeAmount)}đ',
                secondary:  secondary,
                isDark:     isDark,
                labelColor: Colors.red.shade400,
                valueColor: Colors.red.shade400,
              ),
            ],

            // VAT
            if (vatAmount > 0) ...[
              const SizedBox(height: 4),
              _SummaryRow(
                label:     'VAT',
                value:     '+${_fmt(vatAmount)}đ',
                secondary: secondary,
                isDark:    isDark,
                valueColor: Colors.orange,
              ),
            ],

            const SizedBox(height: 10),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),

            // Tổng cộng
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng cộng',
                      style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      primary)),
                  Text('${_fmt(finalAmount)}đ',
                      style: TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.w800,
                          color:      primary)),
                ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Summary row helper ──────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label, value;
  final Color secondary;
  final bool isDark;
  final Color? labelColor, valueColor;
  final IconData? labelIcon;

  const _SummaryRow({
    required this.label, required this.value,
    required this.secondary, required this.isDark,
    this.labelColor, this.valueColor, this.labelIcon,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          if (labelIcon != null) ...[
            Icon(labelIcon, size: 13,
                color: labelColor ?? secondary),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color:    labelColor ?? secondary)),
        ]),
        Text(value,
            style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      valueColor ?? onBg)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize:   10,
            fontWeight: FontWeight.w700,
            color:      color)),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined, loading;
  final Color color;

  const _ActionBtn({
    required this.icon, required this.label, this.onTap,
    this.outlined = false, this.loading = false, required this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: outlined ? null
            : (loading ? color.withOpacity(0.6) : color),
        border: outlined
            ? Border.all(color: color, width: 1.5) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: loading
            ? SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: outlined ? color : Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: outlined ? color : Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}


// ════════════════════════════════════════════════════════════════
// EMPTY / ERROR
// ════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final Color secondary;
  const _EmptyView({required this.secondary});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80, color: secondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Không có đơn hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: secondary)),
          const SizedBox(height: 8),
          Text(
            'Thử thay đổi khoảng thời gian\nhoặc từ khóa tìm kiếm',
            style: TextStyle(fontSize: 13, color: secondary.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 60, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử lại'),
            ),
          ]),
    ),
  );
}
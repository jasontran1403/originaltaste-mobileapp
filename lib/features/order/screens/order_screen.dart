// lib/features/order/screens/order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../shared/widgets/network_image_viewer.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_cart_controller.dart';
import '../widgets/customer_picker_modal.dart';
import '../widgets/price_picker_sheet.dart';

// ══════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ══════════════════════════════════════════════════════════════════

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  final _searchCtrl = TextEditingController();
  bool _productsCollapsed = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load lại sản phẩm mỗi khi vào screen
    Future.microtask(() {
      ref.read(orderCartProvider.notifier).refreshProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    if (isWide) {
      return _WideLayout(searchCtrl: _searchCtrl, isDark: isDark);
    }

    return _NarrowLayout(
      searchCtrl: _searchCtrl,
      isDark: isDark,
      productsCollapsed: _productsCollapsed,
      onToggleProducts: () =>
          setState(() => _productsCollapsed = !_productsCollapsed),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// WIDE LAYOUT  (≥900px) — Cart kiri, Products kanan, side by side
// ══════════════════════════════════════════════════════════════════

class _WideLayout extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final bool isDark;

  const _WideLayout({required this.searchCtrl, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 30, 16, 16 + bottomInset),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Cart panel (kiri) ────────────────────────────────────
            SizedBox(
              width: 360,
              child: _CartPanel(
                  isDark: isDark,
                  primary: primary,
                  cardBg: cardBg,
                  border: border),
            ),
            const SizedBox(width: 16),

            // ── Product panel (kanan, chiếm phần còn lại) ───────────
            Expanded(
              child: _ProductPanel(
                searchCtrl: searchCtrl,
                isDark: isDark,
                primary: primary,
                cardBg: cardBg,
                border: border,
                collapsible: false,
                collapsed: false,
                onToggle: () {},
              ),
            ),
          ]),
        ));
  }
}

// ══════════════════════════════════════════════════════════════════
// NARROW LAYOUT  (<900px) — Cart atas, Products bawah
// ══════════════════════════════════════════════════════════════════

class _NarrowLayout extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final bool isDark, productsCollapsed;
  final VoidCallback onToggleProducts;

  const _NarrowLayout({
    required this.searchCtrl,
    required this.isDark,
    required this.productsCollapsed,
    required this.onToggleProducts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final h = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Mỗi panel chiếm 80% chiều cao màn hình — đủ lớn, có thể scroll để xem panel kia
    final panelHeight = h * 0.7;

    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, 30, 12, 16 + bottomInset),
          child: Column(
            children: [
              // ── Cart ───────────────────────────────────────────────
              SizedBox(
                height: panelHeight,
                child: _CartPanel(
                  isDark: isDark,
                  primary: primary,
                  cardBg: cardBg,
                  border: border,
                ),
              ),

              const SizedBox(height: 12),

              // ── Products ───────────────────────────────────────────
              SizedBox(
                height: panelHeight,
                child: _ProductPanel(
                  searchCtrl: searchCtrl,
                  isDark: isDark,
                  primary: primary,
                  cardBg: cardBg,
                  border: border,
                  collapsible: false, // bỏ collapsible vì đã có scroll
                  collapsed: false,
                  onToggle: () {},
                ),
              ),
            ],
          ),
        ));
  }
}

// ══════════════════════════════════════════════════════════════════
// CART PANEL
// ══════════════════════════════════════════════════════════════════

class _CartPanel extends ConsumerWidget {
  final bool isDark;
  final Color primary, cardBg, border;

  const _CartPanel({
    required this.isDark,
    required this.primary,
    required this.cardBg,
    required this.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderCartProvider);
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        _CartTopBar(
            state: state,
            primary: primary,
            secondary: secondary,
            isDark: isDark),
        Divider(height: 1, color: border),
        Expanded(
          child: Column(children: [
            Expanded(
              child: _CartItemList(
                  state: state,
                  primary: primary,
                  secondary: secondary,
                  isDark: isDark,
                  border: border),
            ),
            Divider(height: 1, color: border),
            _CartTotals(
                state: state,
                primary: primary,
                secondary: secondary,
                isDark: isDark),
            Divider(height: 1, color: border),
            _CartBottomBar(
                state: state,
                primary: primary,
                secondary: secondary,
                isDark: isDark),
          ]),
        ),
      ]),
    );
  }
}

// ── Top bar: title + mode toggle + history + clear ───────────────

class _CartTopBar extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary;
  final bool isDark;

  const _CartTopBar(
      {required this.state,
      required this.primary,
      required this.secondary,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        // Icon + title
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shopping_bag_outlined, size: 16, color: primary),
        ),
        const SizedBox(width: 8),
        Text(
          'Giỏ hàng',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary),
        ),
        if (state.cartItems.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.cartItems.length}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
        const SizedBox(width: 8),

        // Mode toggle
        _ModeToggle(state: state, primary: primary, secondary: secondary),

        const Spacer(),

        // Clear
        if (state.cartItems.isNotEmpty)
          _IconBtn(
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            tooltip: 'Xóa tất cả',
            onTap: () => _confirmClear(context, ref),
          ),
      ]),
    );
  }

  Future<void> _confirmClear(BuildContext ctx, WidgetRef ref) async {
    ref.read(orderCartProvider.notifier).clearCart();
  }
}

// ── Cart item list ───────────────────────────────────────────────

class _CartItemList extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary, border;
  final bool isDark;

  const _CartItemList(
      {required this.state,
      required this.primary,
      required this.secondary,
      required this.isDark,
      required this.border});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingProducts) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation(primary)),
      );
    }
    if (state.cartItems.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Giỏ hàng trống',
        subtitle: 'Chọn sản phẩm từ danh sách bên cạnh',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: state.cartItems.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: secondary.withOpacity(0.08)),
      itemBuilder: (_, i) => _CartRow(
        item: state.cartItems[i],
        index: i,
        state: state,
        primary: primary,
        secondary: secondary,
        isDark: isDark,
      ),
    );
  }
}

// ── Cart row ─────────────────────────────────────────────────────

class _CartRow extends ConsumerWidget {
  final CartItem item;
  final int index;
  final OrderCartState state;
  final Color primary, secondary;
  final bool isDark;

  const _CartRow({
    required this.item,
    required this.index,
    required this.state,
    required this.primary,
    required this.isDark,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(orderCartProvider.notifier);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        // Thumbnail
        _ProductThumb(imageUrl: item.product.imageUrl, size: 38),
        const SizedBox(width: 10),

        // Name + price badge
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => PricePickerSheet.show(context, item),
                  child: _PriceBadge(
                      item: item, primary: primary, secondary: secondary),
                ),
              ]),
        ),

        const SizedBox(width: 8),

        // Qty control
        _QtyControl(
            item: item,
            primary: primary,
            secondary: secondary,
            ctrl: ctrl,
            borderColor: borderColor),

        const SizedBox(width: 8),

        // Subtotal
        SizedBox(
          width: 72,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmtMoneyRaw(state.effectiveSubtotal(item)),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary),
                    textAlign: TextAlign.right),
                if (item.product.vatRate > 0)
                  Text('VAT ${item.product.vatRate}%',
                      style: TextStyle(
                          fontSize: 9, color: Colors.orange.withOpacity(0.85)),
                      textAlign: TextAlign.right),
              ]),
        ),

        const SizedBox(width: 6),

        // Remove
        GestureDetector(
          onTap: () => ctrl.removeFromCart(index),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close_rounded,
                size: 16, color: secondary.withOpacity(0.6)),
          ),
        ),
      ]),
    );
  }
}

// ── Qty control ──────────────────────────────────────────────────

class _QtyControl extends StatelessWidget {
  final CartItem item;
  final Color primary, secondary, borderColor;
  final OrderCartNotifier ctrl;

  const _QtyControl({
    required this.item,
    required this.primary,
    required this.secondary,
    required this.ctrl,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(
          icon: Icons.remove,
          color: secondary,
          onTap: () => ctrl.decrementQty(item)),
      const SizedBox(width: 4),
      NumericField(
        controller: item.qtyController,
        width: 48,
        hint: '1',
        textAlign: TextAlign.center,
        decimal: true,
        inputFormatters: [QtyInputFormatter.instance],
        focusColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: primary, width: 1.5)),
        ),
        onTap: () => ctrl.onQtyTap(item),
        onChanged: (v) => ctrl.onQtyChanged(item, v),
        onSubmitted: () => ctrl.onQtySubmitted(item),
      ),
      const SizedBox(width: 4),
      _Btn(
          icon: Icons.add,
          color: primary,
          onTap: () => ctrl.incrementQty(item)),
    ]);
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Icon(icon, size: 14, color: color)),
        ),
      );
}

// ── Cart totals ──────────────────────────────────────────────────

class _CartTotals extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary;
  final bool isDark;

  const _CartTotals(
      {required this.state,
      required this.primary,
      required this.secondary,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onBg =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final discountRate = state.selectedCustomer?.discountRate ?? 0;
    final hasVat = state.vatAmount > 0;
    final vatBreakdown = state.vatBreakdown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(children: [
        _TotalRow(
          label: 'Tạm tính',
          value: fmtMoney(state.animSubtotal),
          onBg: onBg,
          secondary: secondary,
        ),
        const SizedBox(height: 3),
        _TotalRow(
          label:
              discountRate > 0 ? 'Chiết khấu ($discountRate%)' : 'Chiết khấu',
          value: discountRate > 0 ? '- ${fmtMoney(state.animDiscount)}' : '--',
          color: discountRate > 0 ? Colors.red.shade400 : null,
          muted: discountRate == 0,
          onBg: onBg,
          secondary: secondary,
        ),
        const SizedBox(height: 3),
        _TotalRow(
          label: 'VAT',
          value: hasVat ? '+ ${fmtMoney(state.animVat)}' : '--',
          color: hasVat ? Colors.orange : null,
          muted: !hasVat,
          onBg: onBg,
          secondary: secondary,
        ),
        if (hasVat && vatBreakdown.length > 1)
          ...vatBreakdown.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: _TotalRow(
                  label: '↳ VAT ${e.key}%',
                  value: '+ ${fmtMoney(e.value)}',
                  color: Colors.orange.withOpacity(0.7),
                  small: true,
                  onBg: onBg,
                  secondary: secondary,
                ),
              )),
        const SizedBox(height: 8),
        // Grand total — highlighted row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
              Text(fmtMoney(state.animGrand),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primary)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final Color onBg, secondary;
  final bool muted, small;

  const _TotalRow({
    required this.label,
    required this.value,
    required this.onBg,
    required this.secondary,
    this.color,
    this.muted = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final fs = small ? 10.5 : 12.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: fs,
                color: muted ? secondary : onBg.withOpacity(0.75))),
        Text(value,
            style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w600,
                color: color ?? (muted ? secondary : onBg))),
      ],
    );
  }
}

// ── Cart bottom bar: customer + submit ───────────────────────────

class _CartBottomBar extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary;
  final bool isDark;

  const _CartBottomBar(
      {required this.state,
      required this.primary,
      required this.secondary,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCustomer = state.selectedCustomer != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(children: [
        // Customer chip
        Expanded(
          child: GestureDetector(
            onTap: () => CustomerPickerModal.show(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: hasCustomer
                    ? Colors.green.withOpacity(0.08)
                    : secondary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasCustomer
                      ? Colors.green.withOpacity(0.5)
                      : secondary.withOpacity(0.25),
                ),
              ),
              child: Row(children: [
                Icon(
                  hasCustomer
                      ? Icons.person_outline_rounded
                      : Icons.person_add_alt_outlined,
                  size: 15,
                  color: hasCustomer ? Colors.green : secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.selectedCustomer?.name ?? 'Thêm khách hàng',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasCustomer ? Colors.green : secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCustomer)
                  GestureDetector(
                    onTap: () =>
                        ref.read(orderCartProvider.notifier).clearCustomer(),
                    child: Icon(Icons.close_rounded,
                        size: 13, color: Colors.green.withOpacity(0.7)),
                  ),
              ]),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Submit button
        GestureDetector(
          onTap: state.canCreateOrder
              ? () => _submit(context, ref)
              : () => _warnMissingCustomer(context, state),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color:
                  state.canCreateOrder ? primary : secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              boxShadow: state.canCreateOrder
                  ? [
                      BoxShadow(
                          color: primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (state.isSubmitting)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: state.canCreateOrder ? Colors.white : secondary),
                )
              else
                Icon(Icons.check_rounded,
                    size: 16,
                    color: state.canCreateOrder ? Colors.white : secondary),
              const SizedBox(width: 6),
              Text(
                state.isSubmitting ? 'Đang tạo...' : 'Tạo đơn',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: state.canCreateOrder ? Colors.white : secondary,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit(BuildContext ctx, WidgetRef ref) async {
    final (orderId, errorMsg) =
        await ref.read(orderCartProvider.notifier).submitOrder();
    if (!ctx.mounted) return;

    // Phát hiện lỗi giá thay đổi từ backend
    final isPriceError = orderId == null &&
        errorMsg != null &&
        (errorMsg.contains('đã thay đổi') ||
            errorMsg.contains('thêm lại vào giỏ'));

    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            orderId != null
                ? Icons.check_circle_outline
                : (isPriceError
                    ? Icons.price_change_outlined
                    : Icons.error_outline),
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              orderId != null
                  ? 'Đã tạo đơn #$orderId ✓'
                  : errorMsg ?? 'Không thể tạo đơn hàng',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: orderId != null
            ? Colors.green.shade700
            : (isPriceError ? Colors.orange.shade700 : Colors.red.shade700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isPriceError ? 5 : 3),
      ));
  }

  void _warnMissingCustomer(BuildContext ctx, OrderCartState state) {
    if (state.cartItems.isEmpty) return;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.person_search_outlined, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
            state.orderMode == OrderMode.wholesale
                ? 'Thiếu thông tin khách sỉ'
                : 'Thiếu thông tin khách lẻ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          )),
        ]),
        content: Text(
          state.orderMode == OrderMode.wholesale
              ? 'Vui lòng tìm hoặc tạo khách hàng trước khi đặt đơn sỉ.'
              : 'Vui lòng điền SĐT, email và địa chỉ trước khi đặt đơn lẻ.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Để sau')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              CustomerPickerModal.show(ctx);
            },
            icon: const Icon(Icons.person_add_outlined, size: 15),
            label: const Text('Nhập khách hàng'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PRODUCT PANEL
// Fix lỗi parentDataDirty: KHÔNG dùng SizedBox(height: double.infinity)
// bên trong Column. Dùng Expanded thay thế.
// ══════════════════════════════════════════════════════════════════

class _ProductPanel extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final bool isDark, collapsible, collapsed;
  final Color primary, cardBg, border;
  final VoidCallback onToggle;

  const _ProductPanel({
    required this.searchCtrl,
    required this.isDark,
    required this.primary,
    required this.cardBg,
    required this.border,
    required this.collapsible,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderCartProvider);
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Column phải có constraints rõ ràng — bọc trong ConstrainedBox
      // để Expanded bên trong hoạt động đúng
      child: Column(children: [
        // ── Header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.storefront_outlined, size: 16, color: primary),
            ),
            const SizedBox(width: 8),
            Text('Sản phẩm',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${state.filteredProducts.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: secondary)),
            ),
            const Spacer(),
            _IconBtn(
              icon: Icons.refresh_rounded,
              color: secondary,
              tooltip: 'Tải lại',
              onTap: () =>
                  ref.read(orderCartProvider.notifier).refreshProducts(),
            ),
            if (collapsible)
              _IconBtn(
                icon: collapsed ? Icons.expand_more : Icons.expand_less,
                color: secondary,
                tooltip: collapsed ? 'Mở rộng' : 'Thu gọn',
                onTap: onToggle,
              ),
          ]),
        ),

        if (!collapsed) ...[
          Divider(height: 1, color: border),

          // ── Filter bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: _FilterBar(
              searchCtrl: searchCtrl,
              state: state,
              primary: primary,
              secondary: secondary,
              isDark: isDark,
              border: border,
            ),
          ),

          Divider(height: 1, color: border),

          // ── Grid — Expanded để fill phần còn lại, KHÔNG dùng
          // SizedBox(height: double.infinity) vì gây parentDataDirty
          Expanded(
            child: _ProductGrid(
              state: state,
              primary: primary,
              secondary: secondary,
              isDark: isDark,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final OrderCartState state;
  final Color primary, secondary, border;
  final bool isDark;

  const _FilterBar({
    required this.searchCtrl,
    required this.state,
    required this.primary,
    required this.secondary,
    required this.isDark,
    required this.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(orderCartProvider.notifier);

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Search
      Expanded(
        flex: 4,
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => ctrl.onSearch(v),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              hintStyle: TextStyle(fontSize: 13, color: secondary),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: secondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 1.5)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),

      // Category dropdown
      Expanded(
        flex: 3,
        child: SizedBox(
          height: 38,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
              color: isDark ? AppColors.darkCard : Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: state.selectedCategory?.name,
                isExpanded: true,
                icon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child:
                      Icon(Icons.arrow_drop_down, color: secondary, size: 20),
                ),
                menuMaxHeight: 240,
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: primary)),
                  ),
                  ...state.categories.map((c) => DropdownMenuItem<String?>(
                        value: c.name,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) {
                  ctrl.onSelectCategory(v == null
                      ? null
                      : state.categories.firstWhere((c) => c.name == v));
                },
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),

      // Sort buttons
      _SortChip(
        label: 'A–Z',
        active: state.sortMode.contains('name'),
        onTap: () => ctrl.onSortMode(
            state.sortMode == 'name_asc' ? 'name_desc' : 'name_asc'),
      ),
      const SizedBox(width: 4),
      _SortChip(
        label: '₫',
        active: state.sortMode.contains('price'),
        onTap: () => ctrl.onSortMode(
            state.sortMode == 'price_asc' ? 'price_desc' : 'price_asc'),
      ),
    ]);
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:
              active ? primary.withOpacity(0.12) : secondary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? primary.withOpacity(0.5)
                  : secondary.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? primary : secondary)),
        ),
      ),
    );
  }
}

// ── Product grid ─────────────────────────────────────────────────

class _ProductGrid extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary;
  final bool isDark;

  const _ProductGrid(
      {required this.state,
      required this.primary,
      required this.secondary,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isSearching || state.isLoadingProducts) {
      return Center(
          child: CircularProgressIndicator(
              strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(primary)));
    }
    if (state.filteredProducts.isEmpty) {
      return EmptyState(
          icon: Icons.search_off_rounded, title: 'Không tìm thấy sản phẩm');
    }

    final w = MediaQuery.of(context).size.width;
    final cols = w < 500
        ? 2
        : w < 800
            ? 3
            : w < 1100
                ? 3
                : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: state.filteredProducts.length,
      itemBuilder: (_, i) => _ProductCard(
        product: state.filteredProducts[i],
        cartItems: state.cartItems,
        orderMode: state.orderMode,
        primary: primary,
        secondary: secondary,
        isDark: isDark,
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductModel product;
  final List<CartItem> cartItems;
  final OrderMode orderMode;
  final Color primary, secondary;
  final bool isDark;

  const _ProductCard({
    required this.product,
    required this.cartItems,
    required this.orderMode,
    required this.primary,
    required this.secondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = cartItems
        .where((c) => c.product.id == product.id)
        .fold<double>(0, (s, c) => s + c.quantity);
    final displayPrice = orderMode == OrderMode.wholesale
        ? (product.firstTier?.price ?? product.basePrice)
        : product.basePrice;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final inCart = qty > 0;

    return GestureDetector(
      onTap: () => ref.read(orderCartProvider.notifier).addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: inCart ? primary.withOpacity(0.05) : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart ? primary.withOpacity(0.45) : border,
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(inCart ? 0.08 : 0.04),
              blurRadius: inCart ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Expanded(
            flex: 5,
            child: Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: _ProductThumb(
                    imageUrl: product.imageUrl,
                    width: double.infinity,
                    height: double.infinity),
              ),
              // Cart badge
              if (inCart)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: primary.withOpacity(0.4), blurRadius: 4)
                      ],
                    ),
                    child: Text(
                      '×${qty % 1 == 0 ? qty.toInt() : qty.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
              // Add overlay
              if (!inCart)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 13, color: Colors.white),
                  ),
                ),
            ]),
          ),

          // Info
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 2),
                    Text(fmtMoneyRaw(displayPrice),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODE TOGGLE
// ══════════════════════════════════════════════════════════════════

class _ModeToggle extends ConsumerWidget {
  final OrderCartState state;
  final Color primary, secondary;
  const _ModeToggle(
      {required this.state, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: secondary.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tab(context, ref, OrderMode.retail, 'Lẻ'),
        _tab(context, ref, OrderMode.wholesale, 'Sỉ'),
      ]),
    );
  }

  Widget _tab(BuildContext ctx, WidgetRef ref, OrderMode mode, String label) {
    final sel = state.orderMode == mode;
    return GestureDetector(
      onTap: () => _onTap(ctx, ref, mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: sel
              ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 4)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : secondary)),
      ),
    );
  }

  void _onTap(BuildContext ctx, WidgetRef ref, OrderMode mode) {
    if (state.orderMode == mode) return;
    if (state.cartItems.isEmpty) {
      ref.read(orderCartProvider.notifier).setOrderModeConfirmed(mode);
      ref.read(orderCartProvider.notifier).clearCustomer();
      return;
    }
    // Capture notifier trước khi vào dialog để tránh ref deactivated
    final notifier = ref.read(orderCartProvider.notifier);
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Chuyển sang ${mode == OrderMode.retail ? 'Lẻ' : 'Sỉ'}?'),
        content: const Text('Giỏ hàng sẽ bị xóa vì giá Sỉ và Lẻ khác nhau.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifier.setOrderModeConfirmed(mode);
                notifier.clearCustomer();
              });
            },
            child: Text('Chuyển',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED MICRO WIDGETS
// ══════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}

class _PriceBadge extends StatelessWidget {
  final CartItem item;
  final Color primary, secondary;
  const _PriceBadge(
      {required this.item, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (item.priceMode) {
      ItemPriceMode.discountPercent => (
          Colors.green,
          '-${item.discountPercent ?? 0}%',
          Icons.percent_rounded,
        ),
      ItemPriceMode.base => (
          secondary,
          'Giá gốc',
          Icons.sell_outlined,
        ),
      ItemPriceMode.tier => () {
          final tier = item.activeTier;
          return tier != null
              ? (primary, tier.tierName, Icons.layers_outlined)
              : (secondary, 'Giá gốc', Icons.sell_outlined);
        }(),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 90),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 11, color: color),
        ]),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final double? width, height;
  final double size;
  const _ProductThumb({this.imageUrl, this.width, this.height, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: secondary.withOpacity(0.07),
        borderRadius: width == null ? BorderRadius.circular(8) : null,
      ),
      child: Center(
        child: Icon(Icons.fastfood_outlined,
            size: width != null ? 28 : 18, color: secondary.withOpacity(0.3)),
      ),
    );

    return NetworkImageViewer(
      imageUrl: imageUrl,
      width: width ?? size,
      height: height ?? size,
      fit: BoxFit.cover,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }
}

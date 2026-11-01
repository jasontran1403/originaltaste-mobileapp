import 'package:flutter/material.dart';

/// Mode đặt hàng
enum PosOrderSource {
  takeAway('TAKE_AWAY', 'Take Away', Icons.shopping_bag_outlined),
  dineIn('DINE_IN', 'Dine In', Icons.table_restaurant_outlined),
  shopeeFood('SHOPEE_FOOD', 'Shopee', Icons.storefront_outlined),
  grabFood('GRAB_FOOD', 'Grab', Icons.delivery_dining);

  final String apiValue;
  final String label;
  final IconData icon;
  const PosOrderSource(this.apiValue, this.label, this.icon);

  bool get isOffline => this == takeAway || this == dineIn;
  bool get isApp => this == shopeeFood || this == grabFood;
}

/// Toggle Offline ↔ App + sub-mode bên dưới
class PosOrderModeSelector extends StatelessWidget {
  final PosOrderSource current;
  final bool canShopee;
  final bool canGrab;
  final void Function(PosOrderSource) onChanged;

  const PosOrderModeSelector({
    super.key,
    required this.current,
    required this.canShopee,
    required this.canGrab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOfflineMode = current.isOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Toggle chính: Offline / App ──
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _ModeTab(
                label: 'Offline',
                icon: Icons.storefront_outlined,
                selected: isOfflineMode,
                color: Colors.lightBlue,
                onTap: () {
                  if (!isOfflineMode) onChanged(PosOrderSource.takeAway);
                },
              ),
              const SizedBox(width: 3),
              _ModeTab(
                label: 'App',
                icon: Icons.phone_android_outlined,
                selected: !isOfflineMode,
                color: const Color(0xFFEE4D2D),
                onTap: () {
                  if (isOfflineMode) onChanged(PosOrderSource.shopeeFood);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── Sub-mode ──
        Row(
          children: isOfflineMode
              ? [
                  _SubTab(
                    source: PosOrderSource.takeAway,
                    current: current,
                    enabled: true,
                    onTap: () => onChanged(PosOrderSource.takeAway),
                  ),
                  const SizedBox(width: 6),
                  _SubTab(
                    source: PosOrderSource.dineIn,
                    current: current,
                    enabled: true,
                    onTap: () => onChanged(PosOrderSource.dineIn),
                  ),
                ]
              : [
                  _SubTab(
                    source: PosOrderSource.shopeeFood,
                    current: current,
                    enabled: canShopee,
                    onTap: canShopee
                        ? () => onChanged(PosOrderSource.shopeeFood)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _SubTab(
                    source: PosOrderSource.grabFood,
                    current: current,
                    enabled: canGrab,
                    onTap: canGrab
                        ? () => onChanged(PosOrderSource.grabFood)
                        : null,
                  ),
                ],
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final PosOrderSource source;
  final PosOrderSource current;
  final bool enabled;
  final VoidCallback? onTap;

  const _SubTab({
    required this.source,
    required this.current,
    required this.enabled,
    this.onTap,
  });

  Color get _activeColor {
    switch (source) {
      case PosOrderSource.takeAway:  return Colors.lightBlue;
      case PosOrderSource.dineIn:    return Colors.teal;
      case PosOrderSource.shopeeFood: return const Color(0xFFEE4D2D);
      case PosOrderSource.grabFood:   return const Color(0xFF00B14F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSel = current == source;
    final color = enabled ? _activeColor : cs.onSurface.withOpacity(0.3);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? color : cs.onSurface.withOpacity(0.1),
              width: isSel ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(source.icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(source.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: color,
                  )),
              if (!enabled && source.isApp) ...[
                Text('Có món\nkhông bán',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: cs.onSurface.withOpacity(0.35),
                      height: 1.2,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Payment method selector
class PosPaymentSelector extends StatelessWidget {
  final String current; // 'CASH' | 'TRANSFER'
  final void Function(String) onChanged;

  const PosPaymentSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PayBtn('CASH', 'Tiền mặt', Icons.payments_outlined, Colors.green, current, onChanged),
        const SizedBox(width: 6),
        _PayBtn('TRANSFER', 'Chuyển khoản', Icons.account_balance_outlined, Colors.blue, current, onChanged),
      ],
    );
  }
}

class _PayBtn extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final String current;
  final void Function(String) onChanged;

  const _PayBtn(this.value, this.label, this.icon, this.color,
      this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    final cs = Theme.of(context).colorScheme;
    return Flexible(
      fit: FlexFit.tight, // hoặc loose (giải thích dưới)
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.12) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? color : cs.onSurface.withOpacity(0.1),
              width: sel ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: sel ? color : cs.onSurface.withOpacity(0.5)),
              const SizedBox(width: 2),

              Flexible( // 👈 QUAN TRỌNG
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5, // 👈 giảm nhẹ
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? color : cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

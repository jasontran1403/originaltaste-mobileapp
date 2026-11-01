// lib/features/customer/screens/customer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/customer_controller.dart';
import '../widgets/customer_widgets.dart';
import 'b2b_customer_form_sheet.dart';
import 'pos_customer_form_sheet.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  final _b2bSearchCtrl = TextEditingController();
  final _posSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _b2bSearchCtrl.dispose();
    _posSearchCtrl.dispose();
    super.dispose();
  }

  void _openAdd(CustomerMode mode) async {
    bool saved;
    if (mode == CustomerMode.b2b) {
      saved = await showB2bCustomerForm(context);
    } else {
      saved = await showPosCustomerForm(context);
    }
    if (saved && mounted) {
      ref.read(customerControllerProvider.notifier).refresh();
    }
  }

  void _openEdit(dynamic customer) async {
    bool saved;
    if (customer is B2bCustomerModel) {
      saved = await showB2bCustomerForm(context, customer: customer);
    } else {
      saved = await showPosCustomerForm(context,
          customer: customer as PosCustomerModel);
    }
    if (saved && mounted) {
      ref.read(customerControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(customerControllerProvider);
    final ctrl     = ref.read(customerControllerProvider.notifier);
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final canToggle = ctrl.canToggleMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Column(children: [

        // ── Header ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(children: [
                // Title + Add
                Row(children: [
                  Text('Khách hàng',
                      style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _openAdd(state.mode),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: state.mode == CustomerMode.b2b
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ]),

                // Toggle (chỉ superAdmin)
                if (canToggle) ...[
                  const SizedBox(height: 12),
                  CustomerModeToggle(
                    current:   state.mode,
                    onChanged: ctrl.setMode,
                  ),
                ],
              ]),
            ),
          ),
        ),

        // ── Content ─────────────────────────────────────────────
        Expanded(
          child: state.mode == CustomerMode.b2b
              ? _B2bTab(
            state:      state,
            ctrl:       ctrl,
            searchCtrl: _b2bSearchCtrl,
            onEdit:     _openEdit,
          )
              : _PosTab(
            state:      state,
            ctrl:       ctrl,
            searchCtrl: _posSearchCtrl,
            onEdit:     _openEdit,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// B2B TAB
// ══════════════════════════════════════════════════════════════════

class _B2bTab extends StatelessWidget {
  final CustomerState state;
  final CustomerController ctrl;
  final TextEditingController searchCtrl;
  final ValueChanged<B2bCustomerModel> onEdit;

  const _B2bTab({
    required this.state,
    required this.ctrl,
    required this.searchCtrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.b2bLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.b2bError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: cs.error.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(state.b2bError!,
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: ctrl.loadB2b,
              child: const Text('Thử lại')),
        ],
      ));
    }

    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: CustomerSearchBar(
          hint: 'Tìm theo mã, tên, SĐT...',
          controller: searchCtrl,
          onChanged: ctrl.setB2bSearch,
        ),
      ),

      // Type filter chips
      B2bTypeFilterRow(
        selected:  state.b2bTypeFilter,
        onChanged: ctrl.setB2bTypeFilter,
      ),
      const SizedBox(height: 4),

      // Count
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('${state.filteredB2b.length} khách hàng',
              style: TextStyle(fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
        ),
      ),

      // List
      Expanded(
        child: state.filteredB2b.isEmpty
            ? const CustomerEmptyState(
            text: 'Chưa có khách hàng',
            icon: Icons.business_outlined)
            : RefreshIndicator(
          onRefresh: ctrl.loadB2b,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: state.filteredB2b.length,
            itemBuilder: (_, i) => B2bCustomerCard(
              customer: state.filteredB2b[i],
              onTap: () => onEdit(state.filteredB2b[i]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// POS TAB
// ══════════════════════════════════════════════════════════════════

class _PosTab extends StatelessWidget {
  final CustomerState state;
  final CustomerController ctrl;
  final TextEditingController searchCtrl;
  final ValueChanged<PosCustomerModel> onEdit;

  const _PosTab({
    required this.state,
    required this.ctrl,
    required this.searchCtrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (state.posLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.posError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: cs.error.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(state.posError!,
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: ctrl.loadPos,
              child: const Text('Thử lại')),
        ],
      ));
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: CustomerSearchBar(
          hint: 'Tìm theo tên, SĐT...',
          controller: searchCtrl,
          onChanged: ctrl.setPosSearch,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('${state.filteredPos.length} khách hàng',
              style: TextStyle(fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
        ),
      ),
      Expanded(
        child: state.filteredPos.isEmpty
            ? const CustomerEmptyState(
            text: 'Chưa có khách hàng POS',
            icon: Icons.people_outline_rounded)
            : RefreshIndicator(
          onRefresh: ctrl.loadPos,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: state.filteredPos.length,
            itemBuilder: (_, i) => PosCustomerCard(
              customer: state.filteredPos[i],
              onTap: () => onEdit(state.filteredPos[i]),
            ),
          ),
        ),
      ),
    ]);
  }
}
// lib/features/pos/components/printer_settings_dialog.dart
//
// Đã chuyển từ AlertDialog → BottomSheet.
// Chức năng: tìm máy in trong mạng (scan) + nhập IP thủ công + test kết nối.
// Kết nối thủ công KHÔNG lưu lên API, chỉ lưu memory (PrinterConfig._manualIp).

import 'package:flutter/material.dart';
import 'package:originaltaste/services/pos_printer_service.dart';

Future<bool> showPrinterSettingsDialog(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context:          context,
    isScrollControlled: true,
    backgroundColor:  Colors.transparent,
    builder:          (_) => const _PrinterSettingsSheet(),
  );
  return result == true;
}

class _PrinterSettingsSheet extends StatefulWidget {
  const _PrinterSettingsSheet();
  @override
  State<_PrinterSettingsSheet> createState() => _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState extends State<_PrinterSettingsSheet> {
  final _ipCtrl = TextEditingController(text: PrinterConfig.savedIp ?? '');

  bool         _printingTest = false;
  bool         _scanning    = false;
  int          _scanProg    = 0;
  List<String> _foundIps    = [];
  String?      _selectedIp;
  bool         _testing     = false;
  bool?        _testOk;
  bool         _connecting  = false;

  @override
  void initState() {
    super.initState();
    _selectedIp = PrinterConfig.savedIp;
  }

  @override
  void dispose() { _ipCtrl.dispose(); super.dispose(); }

  // ── Scan subnet ───────────────────────────────────────────────
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanProg = 0;
      _foundIps = [];
      _testOk   = null;
    });

    final found = await PosPrinterService.instance.scanForPrinters(
      onProgress: (done, total) {
        if (mounted) setState(() => _scanProg = (done / total * 100).round());
      },
    );

    if (mounted) {
      setState(() {
        _scanning = false;
        _foundIps = found;
        if (found.isNotEmpty && (_selectedIp == null || !found.contains(_selectedIp))) {
          _selectedIp  = found.first;
          _ipCtrl.text = found.first;
        }
      });
    }
  }

  // ── In test page ─────────────────────────────────────────────
  Future<void> _printTestPage() async {
    setState(() => _printingTest = true);
    final result = await PosPrinterService.instance.printTestPage();
    if (!mounted) return;
    setState(() => _printingTest = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.isSuccess
          ? 'In test thành công!'
          : 'Lỗi: ${result.errorMessage}'),
      backgroundColor: result.isSuccess ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Test + kết nối IP đang nhập ───────────────────────────────
  Future<void> _connect() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    final parts = ip.split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) {
      setState(() => _testOk = false);
      return;
    }
    setState(() { _connecting = true; _testOk = null; });
    final ok = await PrinterConfig.connectManualIp(ip);
    if (!mounted) return;
    setState(() { _connecting = false; _testOk = ok; });
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ── Chọn IP từ danh sách scan → điền vào input ───────────────
  void _selectIp(String ip) {
    setState(() {
      _selectedIp  = ip;
      _ipCtrl.text = ip;
      _testOk      = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cs       = Theme.of(context).colorScheme;
    final surface  = isDark ? const Color(0xFF1E293B) : Colors.white;
    final txtPri   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec   = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border   = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg       = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg   = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final connected = PrinterConfig.isConnected;
    final currentIp = PrinterConfig.savedIp;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Handle
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: txtSec.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // ── Title ───────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.print_outlined, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cài đặt máy in',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: txtPri)),
                Text('ESC/POS qua LAN — port 9100',
                    style: TextStyle(fontSize: 12, color: txtSec)),
              ])),
            ]),
            const SizedBox(height: 20),

            // ── Trạng thái hiện tại ─────────────────────────────
            if (currentIp != null && currentIp.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (connected ? Colors.green : Colors.red).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (connected ? Colors.green : Colors.red).withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(
                    connected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: connected ? Colors.green : Colors.red, size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    connected ? 'Đang kết nối: $currentIp'
                        : 'Mất kết nối: $currentIp',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: connected ? Colors.green : Colors.red),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── IP input + nút Kết nối ──────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TextField(
                controller: _ipCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 15, color: txtPri,
                    letterSpacing: 0.5, fontWeight: FontWeight.w600),
                onChanged: (_) => setState(() => _testOk = null),
                onSubmitted: (_) => _connect(),
                decoration: InputDecoration(
                  labelText: 'Địa chỉ IP máy in',
                  hintText:  '192.168.1.100',
                  hintStyle: TextStyle(color: txtSec.withOpacity(0.4),
                      fontWeight: FontWeight.w400, fontSize: 14, letterSpacing: 0),
                  prefixIcon: Icon(Icons.lan_outlined, size: 18,
                      color: _testOk == false ? Colors.red : txtSec),
                  suffixIcon: _testOk == true
                      ? const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20)
                      : _testOk == false
                      ? const Icon(Icons.cancel_rounded,
                      color: Colors.red, size: 20)
                      : null,
                  filled: true, fillColor: bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _testOk == false ? Colors.red : border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _testOk == false ? Colors.red : cs.primary,
                          width: 1.5)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red)),
                  labelStyle: TextStyle(fontSize: 13, color: txtSec),
                  errorText: _testOk == false
                      ? 'Không kết nối được với ${_ipCtrl.text.trim()}:9100'
                      : null,
                ),
              )),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_rounded, size: 18),
                  label: Text(_connecting ? '...' : 'Kết nối'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),

            if (_testOk == false) const SizedBox(height: 4),
            const SizedBox(height: 14),

            // ── Nút scan ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _scanning
                    ? SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary))
                    : const Icon(Icons.search_rounded),
                label: Text(_scanning
                    ? 'Đang quét mạng... $_scanProg%'
                    : 'Tự động tìm máy in trong mạng LAN'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.primary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _scanning ? null : _scan,
              ),
            ),

            // ── Scan progress bar ────────────────────────────────
            if (_scanning) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _scanProg / 100,
                  minHeight: 4,
                  backgroundColor: cs.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
            ],

            // ── Kết quả scan ─────────────────────────────────────
            if (_foundIps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Icon(Icons.print_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Text('Tìm thấy ${_foundIps.length} máy in:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: txtPri)),
              ]),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Column(children: _foundIps.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final ip  = entry.value;
                  final sel = _selectedIp == ip;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    if (i > 0) Divider(height: 1, color: border),
                    InkWell(
                      onTap: () => _selectIp(ip),
                      borderRadius: BorderRadius.vertical(
                        top:    i == 0 ? const Radius.circular(12) : Radius.zero,
                        bottom: i == _foundIps.length - 1
                            ? const Radius.circular(12) : Radius.zero,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? cs.primary.withOpacity(0.06) : null,
                          borderRadius: BorderRadius.vertical(
                            top:    i == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: i == _foundIps.length - 1
                                ? const Radius.circular(12) : Radius.zero,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.print_outlined, size: 16,
                              color: sel ? cs.primary : txtSec),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ip,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? cs.primary : txtPri))),
                          if (sel)
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: cs.primary)
                          else
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 12, color: txtSec.withOpacity(0.5)),
                        ]),
                      ),
                    ),
                  ]);
                }).toList()),
              ),
            ] else if (!_scanning && _scanProg == 100) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text('Không tìm thấy máy in nào trong mạng.',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700)),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // ── Nút đóng ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Đóng', style: TextStyle(color: txtSec)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
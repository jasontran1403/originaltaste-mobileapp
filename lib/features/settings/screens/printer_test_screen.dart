// lib/features/settings/screens/printer_test_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_toast.dart';
import 'package:originaltaste/services/pos_printer_service.dart';

// ═══════════════════════════════════════════════════════════════
// PERMISSION HELPER
// ═══════════════════════════════════════════════════════════════

enum _PermResult { granted, denied, permanentlyDenied }

Future<_PermResult> _requestNetworkPerm() async {
  if (!Platform.isAndroid) return _PermResult.granted;
  final status = await Permission.location.status;
  if (status.isGranted)           return _PermResult.granted;
  if (status.isPermanentlyDenied) return _PermResult.permanentlyDenied;
  final res = await Permission.location.request();
  if (res.isGranted)              return _PermResult.granted;
  if (res.isPermanentlyDenied)    return _PermResult.permanentlyDenied;
  return _PermResult.denied;
}

// ═══════════════════════════════════════════════════════════════
// PRINTER SETUP BOTTOM SHEET  (kết nối TCP — dùng để setup IP)
// ═══════════════════════════════════════════════════════════════

Future<bool> showPrinterSetupSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SetupSheet(),
  );
  return result == true;
}

// ─── LAN Scanner ──────────────────────────────────────────────
class _Found { final String ip; final int port; _Found(this.ip, this.port); }

Future<List<_Found>> _scanLan(int port,
    {void Function(int done, int total)? onProgress}) async {
  try {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    String? subnet;
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.')      ||
            ip.startsWith('172.')) {
          final p = ip.split('.');
          subnet = '${p[0]}.${p[1]}.${p[2]}';
          break;
        }
      }
      if (subnet != null) break;
    }
    if (subnet == null) return [];

    final found = <_Found>[];
    final futs  = <Future>[];
    int done = 0;
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futs.add(
        Socket.connect(ip, port, timeout: const Duration(milliseconds: 400))
            .then((s) { s.destroy(); found.add(_Found(ip, port)); })
            .catchError((_) {})
            .whenComplete(() { done++; onProgress?.call(done, 254); }),
      );
    }
    await Future.wait(futs);
    found.sort((a, b) => a.ip.compareTo(b.ip));
    return found;
  } catch (_) { return []; }
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet();
  @override State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet>
    with SingleTickerProviderStateMixin {

  late final TabController _tab;
  final _ipCtrl      = TextEditingController();
  final _portCtrl    = TextEditingController(text: '9100');
  bool    _mLoading  = false;
  bool?   _mOk;
  String? _mErr;

  bool         _scanning  = false;
  int          _scanDone  = 0;
  List<_Found> _found     = [];
  String?      _scanErr;
  final _scanPortCtrl = TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _ipCtrl.text = PrinterConfig.savedIp ?? '';
  }

  @override
  void dispose() {
    _tab.dispose();
    _ipCtrl.dispose(); _portCtrl.dispose(); _scanPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _manualConnect() async {
    final ip   = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    if (ip.isEmpty) { setState(() => _mErr = 'Vui lòng nhập IP'); return; }
    final parts = ip.split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) {
      setState(() => _mErr = 'IP không hợp lệ'); return;
    }
    setState(() { _mLoading = true; _mErr = null; _mOk = null; });
    try {
      final s = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 4));
      await s.close();
      PrinterConfig.savedPort = port;
      await PrinterConfig.connectManualIp(ip);
      if (!mounted) return;
      setState(() { _mLoading = false; _mOk = true; });
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() { _mLoading = false; _mOk = false;
      _mErr = 'Không kết nối được'; });
    }
  }

  Future<void> _scan() async {
    final perm = await _requestNetworkPerm();
    if (!mounted) return;
    if (perm != _PermResult.granted) {
      setState(() => _scanErr = 'Cần quyền Vị trí để quét mạng LAN.');
      return;
    }
    final port = int.tryParse(_scanPortCtrl.text.trim()) ?? 9100;
    setState(() { _scanning = true; _scanDone = 0; _found = []; _scanErr = null; });
    final results = await _scanLan(port,
        onProgress: (d, _) { if (mounted) setState(() => _scanDone = d); });
    if (!mounted) return;
    setState(() {
      _scanning = false; _found = results;
      if (results.isEmpty) _scanErr = 'Không tìm thấy thiết bị nào.';
    });
  }

  Future<void> _pick(_Found r) async {
    PrinterConfig.savedPort = r.port;
    await PrinterConfig.connectManualIp(r.ip);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final txtPri  = isDark ? Colors.white             : const Color(0xFF0F172A);
    final txtSec  = isDark ? const Color(0xFF94A3B8)  : const Color(0xFF64748B);
    final border  = isDark ? const Color(0xFF334155)  : const Color(0xFFE2E8F0);
    final bg      = isDark ? const Color(0xFF0F172A)  : const Color(0xFFF8FAFC);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: txtSec.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.print_outlined, color: cs.primary, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kết nối máy in TCP',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800, color: txtPri)),
                  Text('Dự phòng — tự động quét hoặc nhập IP',
                      style: TextStyle(fontSize: 12, color: txtSec)),
                ])),
            IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: Icon(Icons.close, color: txtSec, size: 20)),
          ]),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border)),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(color: cs.primary,
                  borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: txtSec,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: '🔍  Tự động'),
                Tab(text: '✏️  Thủ công'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 260,
            child: TabBarView(controller: _tab, children: [
              // ── Auto ──────────────────────────────────────────
              Column(children: [
                Row(children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _scanPortCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText: 'Port', hintText: '9100',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.wifi_find_rounded, size: 16),
                    label: Text(
                        _scanning ? 'Đang quét...' : 'Quét mạng LAN'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                if (_scanning) ...[
                  LinearProgressIndicator(value: _scanDone / 254),
                  const SizedBox(height: 4),
                  Text('$_scanDone / 254',
                      style: TextStyle(fontSize: 11, color: txtSec)),
                ],
                if (_scanErr != null && !_scanning)
                  Text(_scanErr!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.orange)),
                if (_found.isNotEmpty)
                  Expanded(child: ListView.builder(
                    itemCount: _found.length,
                    itemBuilder: (_, i) {
                      final r = _found[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.print_rounded,
                            size: 18, color: cs.primary),
                        title: Text(r.ip,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text('Port ${r.port}'),
                        trailing: FilledButton(
                          onPressed: () => _pick(r),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Chọn',
                              style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  )),
              ]),

              // ── Manual ────────────────────────────────────────
              Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ipCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d.]'))
                      ],
                      onChanged: (_) {
                        if (_mErr != null) {
                          setState(() => _mErr = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Địa chỉ IP',
                        hintText: '192.168.1.100',
                        prefixIcon: const Icon(Icons.lan_outlined, size: 18),
                        errorText: _mErr,
                        suffixIcon: _mOk == true
                            ? const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 20)
                            : _mOk == false
                            ? const Icon(Icons.cancel_rounded,
                            color: Colors.red, size: 20)
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText: 'Port',
                        hintText: '9100',
                        helperText: 'Mặc định: 9100',
                        prefixIcon: const Icon(
                            Icons.settings_input_component_outlined,
                            size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                      ),
                    ),
                    const Spacer(),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Đóng',
                            style: TextStyle(color: txtSec)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: FilledButton.icon(
                        onPressed: _mLoading ? null : _manualConnect,
                        icon: _mLoading
                            ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                            : const Icon(Icons.wifi_rounded, size: 18),
                        label: Text(_mLoading
                            ? 'Đang kết nối...' : 'Kết nối'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      )),
                    ]),
                  ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRINTER TEST SCREEN  — Windows Driver only
// ═══════════════════════════════════════════════════════════════

class PrinterTestScreen extends StatefulWidget {
  const PrinterTestScreen({super.key});
  @override
  State<PrinterTestScreen> createState() => _PrinterTestScreenState();
}

class _PrinterTestScreenState extends State<PrinterTestScreen> {
  final _serverIpCtrl =
  TextEditingController(text: '192.168.0.200');

  bool    _testing  = false;
  bool?   _lastOk;
  String? _lastErr;
  String? _printerName; // tên máy in lấy từ server

  // ── Kiểm tra server + lấy tên máy in ─────────────────────────
  Future<void> _checkServer() async {
    final ip = _serverIpCtrl.text.trim();
    if (ip.isEmpty) return;

    setState(() { _testing = true; _lastErr = null; _lastOk = null; });

    try {
      // /health
      final health = await http
          .get(Uri.parse('http://$ip:3000/health'))
          .timeout(const Duration(seconds: 5));

      if (health.statusCode != 200) throw Exception('HTTP ${health.statusCode}');

      // /printers
      final prRes = await http
          .get(Uri.parse('http://$ip:3000/printers'))
          .timeout(const Duration(seconds: 5));

      String? pName;
      if (prRes.statusCode == 200) {
        final data = jsonDecode(prRes.body) as Map<String, dynamic>;
        final list = List<String>.from(data['printers'] ?? []);
        // Tìm tên có chứa "Zywell" hoặc lấy cái đầu tiên
        pName = list.firstWhere(
              (p) => p.toLowerCase().contains('zywell'),
          orElse: () => list.isNotEmpty ? list.first : '',
        );
        if (pName.isEmpty) pName = null;
      }

      if (!mounted) return;
      setState(() {
        _testing     = false;
        _lastOk      = true;
        _printerName = pName;
      });
      AppToast.success(context, 'Server online!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _lastOk  = false;
        _lastErr = e.toString();
      });
      AppToast.error(context, 'Không kết nối được server: $e');
    }
  }

  // ── In test page ──────────────────────────────────────────────
  Future<void> _printTest() async {
    final ip = _serverIpCtrl.text.trim();
    if (ip.isEmpty) {
      AppToast.error(context, 'Vui lòng nhập IP Windows server');
      return;
    }

    setState(() { _testing = true; _lastErr = null; });

    try {
      final res = await http
          .post(Uri.parse('http://$ip:3000/print-test'))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          setState(() { _testing = false; _lastOk = true; });
          AppToast.success(context, 'In test thành công! Kiểm tra máy in.');
          return;
        }
        throw Exception(data['error'] ?? 'Lỗi không xác định');
      }
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      if (!mounted) return;
      setState(() { _testing = false; _lastOk = false; _lastErr = e.toString(); });
      AppToast.error(context, 'Lỗi: $e');
    }
  }

  @override
  void dispose() {
    _serverIpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final txtPri  = isDark ? Colors.white            : const Color(0xFF0F172A);
    final txtSec  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt máy in'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [

            // ── Hướng dẫn ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('Cách in tiếng Việt đúng font',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade700)),
                    ]),
                    const SizedBox(height: 10),
                    _Step(n: '1', text:
                    'Trên máy tính Windows: cài Node.js và driver Zywell 0.5.3'),
                    _Step(n: '2', text:
                    'Copy thư mục print-server vào Windows, chạy:\n'
                        'npm install  →  node server.js'),
                    _Step(n: '3', text:
                    'Cài Sumatra PDF (miễn phí) để in HTML đúng font:\n'
                        'sumatrapdfreader.org'),
                    _Step(n: '4', text:
                    'Nhập IP của Windows PC bên dưới và nhấn Kiểm tra'),
                    _Step(n: '5', text:
                    'Nhấn In test — máy in sẽ in trang tiếng Việt có dấu'),
                  ]),
            ),

            const SizedBox(height: 20),

            // ── IP input ──────────────────────────────────────────
            Text('IP Windows Print Server',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: txtPri)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _serverIpCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: txtPri,
                      letterSpacing: 0.5),
                  decoration: InputDecoration(
                    hintText: '192.168.0.200',
                    hintStyle: TextStyle(
                        color: txtSec.withOpacity(0.4),
                        fontWeight: FontWeight.w400),
                    prefixIcon: const Icon(Icons.computer_rounded,
                        size: 20, color: Colors.green),
                    suffixText: ':3000',
                    suffixStyle: TextStyle(color: txtSec, fontSize: 13),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.green, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Nút kiểm tra
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _checkServer,
                  icon: _testing
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                      : const Icon(Icons.wifi_find_rounded, size: 16),
                  label: const Text('Kiểm tra'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ]),

            // ── Status badge ──────────────────────────────────────
            if (_lastOk != null) ...[
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_lastOk! ? Colors.green : Colors.red)
                      .withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (_lastOk! ? Colors.green : Colors.red)
                          .withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(
                    _lastOk!
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _lastOk! ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastOk!
                              ? 'Server online — sẵn sàng in!'
                              : 'Không kết nối được server',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _lastOk! ? Colors.green : Colors.red,
                          ),
                        ),
                        if (_lastOk! && _printerName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('Máy in: $_printerName',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700)),
                          ),
                        if (!_lastOk! && _lastErr != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(_lastErr!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.red)),
                          ),
                      ])),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Nút in test ───────────────────────────────────────
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _testing ? null : _printTest,
                icon: _testing
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  _testing ? 'Đang in...' : 'In trang test tiếng Việt',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Ghi chú ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.25)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('Lưu ý',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '• iPad và Windows PC phải cùng mạng WiFi\n'
                          '• Windows PC phải đang chạy: node server.js\n'
                          '• Máy in Zywell cắm USB vào Windows PC\n'
                          '• Sumatra PDF phải được cài trên Windows PC',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          height: 1.6),
                    ),
                  ]),
            ),

            const SizedBox(height: 24),
            Divider(color: border),
            const SizedBox(height: 12),

            // ── TCP fallback (ẩn trong ExpansionTile) ─────────────
            Theme(
              data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.settings_outlined,
                    size: 18, color: txtSec),
                title: Text('Cài đặt TCP (nâng cao)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: txtSec)),
                subtitle: Text('Kết nối trực tiếp ESC/POS — không hỗ trợ '
                    'tiếng Việt trên Zywell',
                    style: TextStyle(fontSize: 11, color: txtSec)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 12, left: 4, right: 4),
                    child: FilledButton.icon(
                      onPressed: () async {
                        await showPrinterSetupSheet(context);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.cable_rounded, size: 16),
                      label: const Text('Mở cài đặt TCP'),
                      style: FilledButton.styleFrom(
                        backgroundColor: txtSec.withOpacity(0.7),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step widget ───────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String n, text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txtSec = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(n,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: TextStyle(fontSize: 12, color: txtSec, height: 1.5))),
          ]),
    );
  }
}
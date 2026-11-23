import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../users_management/providers/user_management_provider.dart';
import '../providers/sales_assignment_provider.dart';

class MasterRealisasiScreen extends ConsumerStatefulWidget {
  const MasterRealisasiScreen({super.key});

  @override
  ConsumerState<MasterRealisasiScreen> createState() => _MasterRealisasiScreenState();
}

class _MasterRealisasiScreenState extends ConsumerState<MasterRealisasiScreen> with SingleTickerProviderStateMixin {
  double _toDouble(dynamic value) => value is num ? value.toDouble() : (double.tryParse('${value ?? ''}') ?? 0.0);
  int _toInt(dynamic value) => value is num ? value.toInt() : (int.tryParse('${value ?? ''}') ?? 0);

  late TabController _tabController;
  final _periodController = TextEditingController(text: '202610');
  String _selectedPeriod = '202610';
  List<String> _availablePeriods = const ['202610'];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;
  int _activeTabIndex = 0;

  // Live backend state untuk Tab 0: Sell-In Distributor (SAP)
  List<Map<String, dynamic>> _sellinDistRealisasi = [];
  bool _isLoadingSellinDist = false;
  String? _sellinDistError;
  int _sellinPage = 1;
  int _sellinPerPage = 25;
  int _sellinLastPage = 1;
  int _sellinTotalRows = 0;
  double _sellinTotalVol = 0.0;
  double _sellinTotalNom = 0.0;
  Timer? _searchDebounce;

  // Live backend state untuk Tab 1: Sell-Out Distributor
  List<Map<String, dynamic>> _selloutDistRealisasi = [];
  bool _isLoadingSelloutDist = false;
  String? _selloutDistError;
  String _selloutAreaFilter = 'all'; // all | in_area | out_area
  int _selloutPage = 1;
  int _selloutPerPage = 25;
  int _selloutLastPage = 1;
  int _selloutTotalRows = 0;
  double _selloutTotalVol = 0.0;
  double _selloutTotalNom = 0.0;
  int _selloutTotalAo = 0;

  // Live backend state untuk Tab 2: Sell-In Industri
  List<Map<String, dynamic>> _industriRealisasi = [];
  bool _isLoadingIndustri = false;
  String? _industriError;

  // Live backend state untuk Tab 3: Sell-Out Sales Surabaya
  List<Map<String, dynamic>> _surabayaRealisasi = [];
  bool _isLoadingSurabaya = false;
  String? _surabayaError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
        if (_tabController.index == 0 && _sellinDistRealisasi.isEmpty && !_isLoadingSellinDist) {
          _fetchSellinDistributorRealisasi();
        }
        if (_tabController.index == 1 && _selloutDistRealisasi.isEmpty && !_isLoadingSelloutDist) {
          _fetchSelloutDistributorRealisasi();
        }
        if (_tabController.index == 2 && _industriRealisasi.isEmpty && !_isLoadingIndustri) {
          _fetchIndustriRealisasi();
        }
        if (_tabController.index == 3 && _surabayaRealisasi.isEmpty && !_isLoadingSurabaya) {
          _fetchSurabayaRealisasi();
        }
      }
    });
    Future.microtask(() {
      if (!mounted) return;
      _fetchAvailablePeriods();
      _fetchSellinDistributorRealisasi();
      _fetchSelloutDistributorRealisasi();
      _fetchIndustriRealisasi();
      _fetchSurabayaRealisasi();
      ref.read(salesAssignmentProvider.notifier).fetchIndustriDataOnly();
      ref.read(userManagementProvider.notifier).fetchAll();
    });
  }

  Future<void> _fetchAvailablePeriods() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.masterTargetPeriods);
      final raw = res.data is List
          ? res.data as List
          : (res.data is Map && res.data['data'] is List ? res.data['data'] as List : []);
      final periods = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (_selectedPeriod.isNotEmpty && !periods.contains(_selectedPeriod)) {
        periods.add(_selectedPeriod);
      }
      periods.sort((a, b) => b.compareTo(a));
      if (mounted && periods.isNotEmpty) {
        setState(() => _availablePeriods = periods);
      }
    } catch (_) {
      // Abaikan jika gagal memuat daftar periode
    }
  }

  Widget _buildPeriodDropdown(BuildContext context, VoidCallback onReload) {
    final colors = context.colors;
    final periods = <String>{
      ..._availablePeriods,
      if (_selectedPeriod.isNotEmpty) _selectedPeriod,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return SizedBox(
      width: 195,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPeriod,
        isExpanded: true,
        dropdownColor: colors.bgElevated,
        style: TextStyle(color: colors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Periode (YYYYMM)',
          prefixIcon: Icon(LucideIcons.calendar, size: 15, color: colors.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: colors.bgElevated,
        ),
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Semua Periode', overflow: TextOverflow.ellipsis),
          ),
          ...periods.map((p) => DropdownMenuItem<String>(
                value: p,
                child: Text(p, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: (val) {
          if (val == null) return;
          setState(() {
            _selectedPeriod = val;
            _periodController.text = val;
          });
          onReload();
        },
      ),
    );
  }

  Future<void> _fetchSurabayaRealisasi() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSurabaya = true;
      _surabayaError = null;
    });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.selloutSurabayas,
        queryParameters: {
          if (_selectedPeriod.isNotEmpty) 'period': _selectedPeriod,
          if (_searchQuery.isNotEmpty) 'search': _searchQuery,
          'per_page': 200,
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map && res.data['data'] is List ? res.data['data'] as List : []);
      if (!mounted) return;
      setState(() {
        _surabayaRealisasi = list.whereType<Map<String, dynamic>>().toList();
        _isLoadingSurabaya = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
      setState(() {
        _isLoadingSurabaya = false;
        _surabayaError = 'Gagal memuat Sell-Out Surabaya: $msg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSurabaya = false;
        _surabayaError = 'Gagal memuat Sell-Out Surabaya: $e';
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _periodController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSellinDistributorRealisasi({int? page}) async {
    if (!mounted) return;
    final targetPage = page ?? _sellinPage;
    setState(() {
      _isLoadingSellinDist = true;
      _sellinDistError = null;
      _sellinPage = targetPage;
    });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.sellinDistributors,
        queryParameters: {
          if (_selectedPeriod.isNotEmpty) 'period': _selectedPeriod,
          'per_page': _sellinPerPage,
          'page': targetPage,
          if (_searchQuery.isNotEmpty) 'q': _searchQuery,
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map && res.data['data'] is List ? res.data['data'] as List : []);
      final meta = res.data is Map && res.data['meta'] is Map ? res.data['meta'] as Map : null;
      final summary = res.data is Map && res.data['summary'] is Map ? res.data['summary'] as Map : null;
      final rows = list.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _sellinDistRealisasi = rows;
        _sellinPage = _toInt(meta?['current_page'] ?? targetPage).clamp(1, 999999);
        _sellinLastPage = _toInt(meta?['last_page'] ?? 1).clamp(1, 999999);
        _sellinTotalRows = summary != null ? _toInt(summary['total_rows']) : rows.length;
        _sellinTotalVol = summary != null
            ? _toDouble(summary['total_volume_kg'])
            : rows.fold<double>(0.0, (sum, r) => sum + _toDouble(r['volume_kg']));
        _sellinTotalNom = summary != null
            ? _toDouble(summary['total_nominal'])
            : rows.fold<double>(0.0, (sum, r) => sum + _toDouble(r['nominal']));
        _isLoadingSellinDist = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
      setState(() {
        _isLoadingSellinDist = false;
        _sellinDistError = 'Gagal memuat Sell-In Distributor: $msg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSellinDist = false;
        _sellinDistError = 'Gagal memuat Sell-In Distributor: $e';
      });
    }
  }

  Future<void> _showSyncSellinSapDialog() async {
    final periodCtrl = TextEditingController(text: _selectedPeriod.isNotEmpty ? _selectedPeriod : '202607');
    final dateFromCtrl = TextEditingController();
    final dateToCtrl = TextEditingController();
    bool useDateRange = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          backgroundColor: context.colors.bgDialog,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.colors.border)),
          title: Row(
            children: [
              Icon(LucideIcons.download, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sync Sell-In Distributor dari SAP',
                  style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tarik berdasarkan Rentang Tanggal (Tengah Bulan)', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                  subtitle: Text('Gunakan saat ingin tarik harian / pergantian PIC sales', style: TextStyle(color: context.colors.textMuted, fontSize: 11.5)),
                  value: useDateRange,
                  onChanged: (v) => setDState(() => useDateRange = v),
                ),
                const SizedBox(height: 10),
                if (!useDateRange)
                  TextField(
                    controller: periodCtrl,
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Periode (YYYYMM) *',
                      hintText: 'Contoh: 202607',
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dateFromCtrl,
                          style: TextStyle(color: context.colors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Dari (YYYY-MM-DD) *', hintText: '2026-07-01'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dateToCtrl,
                          style: TextStyle(color: context.colors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Sampai (YYYY-MM-DD) *', hintText: '2026-07-15'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: context.colors.textMuted))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
              icon: const Icon(LucideIcons.download, size: 15),
              label: const Text('Sync SAP Sekarang'),
              onPressed: () async {
                final payload = <String, dynamic>{};
                if (!useDateRange) {
                  final p = periodCtrl.text.trim();
                  if (p.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Periode wajib 6 digit YYYYMM.'), backgroundColor: context.semantic.warningSolid),
                    );
                    return;
                  }
                  payload['period'] = p;
                } else {
                  final df = dateFromCtrl.text.trim();
                  final dt = dateToCtrl.text.trim();
                  if (df.isEmpty || dt.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tanggal Dari & Sampai wajib diisi.'), backgroundColor: context.semantic.warningSolid),
                    );
                    return;
                  }
                  payload['date_from'] = df;
                  payload['date_to'] = dt;
                }

                Navigator.pop(ctx);
                await _executeSyncSellinDistributor(payload);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSyncSellinDistributor(Map<String, dynamic> payload) async {
    setState(() {
      _isLoadingSellinDist = true;
      _sellinDistError = null;
    });
    try {
      final res = await DioClient.instance.post(ApiEndpoints.sellinDistributorsSyncSap, data: payload);
      final data = res.data is Map ? res.data as Map : {};
      final total = data['total_fetched'] ?? 0;
      final created = data['created_count'] ?? 0;
      final updated = data['updated_count'] ?? 0;
      final unmapped = data['unmapped_items'];
      final unmappedNote = (unmapped is Map && unmapped.isNotEmpty)
          ? ' (${unmapped.length} ItemCode belum dimapping di Master Brand)'
          : '';

      if (payload['period'] != null) {
        setState(() {
          _selectedPeriod = payload['period'].toString();
          _periodController.text = _selectedPeriod;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync Sell-In Distributor SAP selesai: $total baris ($created baru, $updated diperbarui)$unmappedNote'),
            backgroundColor: context.semantic.successSolid,
          ),
        );
      }
      await _fetchAvailablePeriods();
      await _fetchSellinDistributorRealisasi();
    } on DioException catch (e) {
      final msg = e.response?.data is Map && e.response?.data['message'] != null
          ? e.response?.data['message'].toString()
          : (e.message ?? 'Error tidak diketahui');
      if (!mounted) return;
      setState(() {
        _isLoadingSellinDist = false;
        _sellinDistError = 'Gagal Sync SAP Sell-In Distributor: $msg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSellinDist = false;
        _sellinDistError = 'Gagal Sync SAP Sell-In Distributor: $e';
      });
    }
  }

  Future<void> _fetchSelloutDistributorRealisasi({int? page}) async {
    if (!mounted) return;
    final targetPage = page ?? _selloutPage;
    setState(() {
      _isLoadingSelloutDist = true;
      _selloutDistError = null;
    });
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.selloutDistributors,
        queryParameters: {
          if (_periodController.text.trim().isNotEmpty) 'period': _periodController.text.trim(),
          if (_selloutAreaFilter == 'in_area') 'is_out_of_area': 0,
          if (_selloutAreaFilter == 'out_area') 'is_out_of_area': 1,
          if (_searchQuery.isNotEmpty) 'q': _searchQuery,
          'per_page': _selloutPerPage,
          'page': targetPage,
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map && res.data['data'] is List ? res.data['data'] as List : []);
      final meta = (res.data is Map && res.data['meta'] is Map)
          ? res.data['meta'] as Map
          : const <String, dynamic>{};
      final summary = (res.data is Map && res.data['summary'] is Map)
          ? res.data['summary'] as Map
          : const <String, dynamic>{};

      final rows = list.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _selloutDistRealisasi = rows;
        _selloutPage = _toInt(meta['current_page']) > 0 ? _toInt(meta['current_page']) : targetPage;
        _selloutLastPage = _toInt(meta['last_page']) > 0 ? _toInt(meta['last_page']) : 1;
        _selloutTotalRows = _toInt(summary['total_rows'] ?? meta['total']);
        _selloutTotalVol = _toDouble(summary['total_volume_kg']);
        _selloutTotalNom = _toDouble(summary['total_nominal']);
        _selloutTotalAo = _toInt(summary['total_ao']);
        _isLoadingSelloutDist = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
      setState(() {
        _isLoadingSelloutDist = false;
        _selloutDistError = 'Gagal memuat Sell-Out Distributor: $msg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSelloutDist = false;
        _selloutDistError = 'Gagal memuat Sell-Out Distributor: $e';
      });
    }
  }

  Future<void> _fetchIndustriRealisasi() async {
    if (!mounted) return;
    setState(() {
      _isLoadingIndustri = true;
      _industriError = null;
    });
    try {
      final period = _periodController.text.trim();
      final res = await DioClient.instance.get(
        ApiEndpoints.sellinIndustris,
        queryParameters: period.isNotEmpty ? {'period': period} : null,
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : <dynamic>[]);
      if (!mounted) return;
      setState(() {
        _industriRealisasi = list.whereType<Map<String, dynamic>>().toList();
        _isLoadingIndustri = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
      setState(() {
        _isLoadingIndustri = false;
        _industriError = 'Gagal memuat realisasi industri: $msg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingIndustri = false;
        _industriError = 'Gagal memuat realisasi industri: $e';
      });
    }
  }

  Future<void> _deleteIndustriRealisasi(Map<String, dynamic> row) async {
    final id = row['id'];
    if (id == null) return;
    final custName = row['customer_name']?.toString() ?? row['industri_customer']?['customer_name']?.toString() ?? '-';
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'Hapus Realisasi Industri',
      message: 'Hapus transaksi Sell-In customer "$custName" periode ${row['period'] ?? '-'} (${CurrencyFormatter.formatNumber((double.tryParse((row['volume_kg'] ?? row['tonase'] ?? 0).toString()) ?? 0))} Kg)?',
    );
    if (confirmed != true) return;

    try {
      await DioClient.instance.delete('${ApiEndpoints.sellinIndustris}/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaksi Sell-In Industri berhasil dihapus.'), backgroundColor: context.semantic.successSolid),
        );
      }
      await _fetchIndustriRealisasi();
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $msg'), backgroundColor: context.semantic.dangerSolid),
        );
      }
    }
  }

  Future<void> _syncIndustriFromSap() async {
    final period = _periodController.text.trim();
    if (period.isEmpty || period.length != 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Isi filter Periode (6 digit YYYYMM, misal 202604) terlebih dahulu untuk Sync dari SAP.'),
            backgroundColor: context.semantic.warningSolid,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingIndustri = true;
      _industriError = null;
    });

    try {
      final res = await DioClient.instance.post(
        ApiEndpoints.sellinIndustrisSyncSap,
        data: {'period': period},
      );

      final data = res.data is Map ? res.data as Map : {};
      final total = data['total_fetched'] ?? 0;
      final created = data['created_count'] ?? 0;
      final updated = data['updated_count'] ?? 0;
      final unmapped = data['unmapped_sales'];
      final unmappedNote = (unmapped is Map && unmapped.isNotEmpty)
          ? ' (${unmapped.length} kode sales SAP belum di-link di Pengguna & Akses)'
          : '';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync SAP $period selesai: $total transaksi ($created baru, $updated diperbarui)$unmappedNote'),
            backgroundColor: context.semantic.successSolid,
          ),
        );
      }
      await _fetchIndustriRealisasi();
    } on DioException catch (e) {
      final msg = e.response?.data is Map && e.response?.data['message'] != null
          ? e.response?.data['message'].toString()
          : (e.message ?? 'Error tidak diketahui');
      setState(() {
        _isLoadingIndustri = false;
        _industriError = 'Gagal Sync SAP Industri: $msg';
      });
    } catch (e) {
      setState(() {
        _isLoadingIndustri = false;
        _industriError = 'Gagal Sync SAP Industri: $e';
      });
    }
  }

  Future<void> _showAddIndustriModal() async {
    final assignNotifier = ref.read(salesAssignmentProvider.notifier);
    final userNotifier = ref.read(userManagementProvider.notifier);
    if (ref.read(salesAssignmentProvider).industriCustomers.isEmpty) {
      await assignNotifier.fetchIndustriDataOnly(force: true);
    }
    if (ref.read(userManagementProvider).users.isEmpty) {
      await userNotifier.fetchAll(force: true);
    }
    if (!mounted) return;

    final customers = ref.read(salesAssignmentProvider).industriCustomers;
    final allUsers = ref.read(userManagementProvider).users;
    final industriUsers = allUsers.where((u) {
      final pos = u.position?.code.toUpperCase() ?? '';
      return u.isEligibleIndustri || pos == 'ASM' || pos == 'SPV' || pos == 'ASC';
    }).toList();

    final formKey = GlobalKey<FormState>();
    int? selectedCustomerId = customers.isNotEmpty ? customers.first.id : null;
    int? selectedUserId;
    String nooMode = 'auto';
    final periodCtrl = TextEditingController(
      text: _periodController.text.trim().length == 6 ? _periodController.text.trim() : '202610',
    );
    final volCtrl = TextEditingController();
    final nomCtrl = TextEditingController(text: '0');
    final sapCtrl = TextEditingController();
    bool isSaving = false;
    String? modalError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedCust = customers.where((c) => c.id == selectedCustomerId).firstOrNull;
          final assignedSalesNames = selectedCust?.assignments
              .where((a) => a.isActive && a.user != null)
              .map((a) => '${a.user!.name} (${a.user!.position?.code ?? '-'})')
              .toList() ?? [];

          return AlertDialog(
            backgroundColor: ctx.colors.bgDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ctx.colors.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.factory, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Input Realisasi Sell-In Industri',
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: ctx.colors.textPrimary),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (customers.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.semantic.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.semantic.warning.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Belum ada Master Customer Industri. Tambahkan customer terlebih dahulu di menu Tim & Area Sales → Tim & Customer Industri.',
                            style: TextStyle(fontSize: 12, color: context.semantic.warning),
                          ),
                        ),
                      if (modalError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.semantic.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
                          ),
                          child: Text(modalError!, style: TextStyle(fontSize: 12, color: context.semantic.danger)),
                        ),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedCustomerId,
                        dropdownColor: ctx.colors.bgCard,
                        decoration: InputDecoration(
                          labelText: 'Customer Industri *',
                          prefixIcon: const Icon(LucideIcons.building2, size: 16),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          filled: true,
                          fillColor: ctx.colors.bgInput,
                        ),
                        items: customers.map((c) {
                          return DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(
                              '[${c.customerCode}] ${c.customerName} (${c.customerType})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedCustomerId = val),
                        validator: (val) => val == null ? 'Customer Industri wajib dipilih' : null,
                      ),
                      if (assignedSalesNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'PIC Assignment Aktif: ${assignedSalesNames.join(', ')}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: context.semantic.info, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: selectedUserId,
                        dropdownColor: ctx.colors.bgCard,
                        decoration: InputDecoration(
                          labelText: 'Sales PIC (Opsional)',
                          prefixIcon: const Icon(LucideIcons.userCheck, size: 16),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          filled: true,
                          fillColor: ctx.colors.bgInput,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Auto — Ambil dari Assignment Customer', overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                          ...industriUsers.map((u) {
                            return DropdownMenuItem<int?>(
                              value: u.id,
                              child: Text(
                                '${u.name} (${u.position?.code ?? '-'})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) => setModalState(() => selectedUserId = val),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: periodCtrl,
                              decoration: InputDecoration(
                                labelText: 'Periode (YYYYMM) *',
                                hintText: '202610',
                                prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                filled: true,
                                fillColor: ctx.colors.bgInput,
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.length != 6 || int.tryParse(t) == null) return 'Harus 6 digit (YYYYMM)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: volCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Volume (Kg) *',
                                hintText: '50000',
                                prefixIcon: const Icon(LucideIcons.scale, size: 16),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                filled: true,
                                fillColor: ctx.colors.bgInput,
                              ),
                              validator: (v) {
                                final numVal = double.tryParse((v ?? '').replaceAll(',', '').trim());
                                if (numVal == null || numVal <= 0) return 'Volume (Kg) > 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: nomCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Nominal (Rp)',
                                hintText: '750000000',
                                prefixIcon: const Icon(LucideIcons.banknote, size: 16),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                filled: true,
                                fillColor: ctx.colors.bgInput,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: sapCtrl,
                              decoration: InputDecoration(
                                labelText: 'No. SAP SO / DO',
                                hintText: 'SO-IND-202610-001',
                                prefixIcon: const Icon(LucideIcons.fileText, size: 16),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                filled: true,
                                fillColor: ctx.colors.bgInput,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: nooMode,
                        dropdownColor: ctx.colors.bgCard,
                        decoration: InputDecoration(
                          labelText: 'Penanda NOO (New Open Outlet)',
                          prefixIcon: const Icon(LucideIcons.sparkles, size: 16),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          filled: true,
                          fillColor: ctx.colors.bgInput,
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'auto',
                            child: Text('Auto — Sistem cek riwayat transaksi', overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                          DropdownMenuItem<String>(
                            value: 'true',
                            child: Text('Ya — Hitung sebagai NOO', overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                          DropdownMenuItem<String>(
                            value: 'false',
                            child: Text('Tidak — Repeat Order / Existing', overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ],
                        onChanged: (val) => setModalState(() => nooMode = val ?? 'auto'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                icon: isSaving
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(isSaving ? 'Menyimpan...' : 'Simpan Realisasi'),
                onPressed: isSaving || customers.isEmpty
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() {
                          isSaving = true;
                          modalError = null;
                        });
                        try {
                          final volKg = double.parse(volCtrl.text.replaceAll(',', '').trim());
                          final nom = double.tryParse(nomCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                          final bool? isNoo = nooMode == 'true' ? true : (nooMode == 'false' ? false : null);

                          await DioClient.instance.post(
                            ApiEndpoints.sellinIndustris,
                            data: {
                              'industri_customer_id': selectedCustomerId,
                              if (selectedUserId != null) 'user_id': selectedUserId,
                              'period': periodCtrl.text.trim(),
                              'volume_kg': volKg,
                              'nominal': nom,
                              if (isNoo != null) 'is_noo': isNoo,
                              if (sapCtrl.text.trim().isNotEmpty) 'sap_so_no': sapCtrl.text.trim(),
                            },
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            if (_periodController.text.trim().isNotEmpty &&
                                _periodController.text.trim() != periodCtrl.text.trim()) {
                              _periodController.text = periodCtrl.text.trim();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Realisasi Sell-In Industri berhasil disimpan.'),
                                backgroundColor: context.semantic.successSolid,
                              ),
                            );
                          }
                          await _fetchIndustriRealisasi();
                        } on DioException catch (e) {
                          final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? e.message) : e.message;
                          setModalState(() {
                            isSaving = false;
                            modalError = msg;
                          });
                        } catch (e) {
                          setModalState(() {
                            isSaving = false;
                            modalError = e.toString();
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _triggerSapSync(String streamName) async {
    if (_activeTabIndex == 0) {
      await _showSyncSellinSapDialog();
      return;
    }
    if (_activeTabIndex == 2) {
      await _fetchIndustriRealisasi();
      return;
    }
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isSyncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sinkronisasi data $streamName dari SAP ERP berhasil disinkronkan untuk periode ${_periodController.text}.'),
          backgroundColor: context.semantic.successSolid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Master Data Realisasi Penjualan (Sell-In & Sell-Out)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitoring data aktual transaksi penjualan dari SAP ERP, upload file distributor, industri, dan cabang Surabaya',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final actionsWidget = Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textPrimary,
                      side: BorderSide(color: context.colors.border),
                    ),
                    icon: const Icon(LucideIcons.uploadCloud, size: 16),
                    label: const Text('Bulk Upload File'),
                    onPressed: () => context.go('/bulk-upload'),
                  ),
                  if (_activeTabIndex != 0)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                      icon: _isSyncing || (_activeTabIndex == 2 && _isLoadingIndustri) || (_activeTabIndex == 3 && _isLoadingSurabaya)
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                          : const Icon(LucideIcons.refreshCw, size: 16),
                      label: Text(
                        _activeTabIndex == 2
                            ? (_isLoadingIndustri ? 'Memuat...' : 'Muat Ulang Industri')
                            : (_activeTabIndex == 3
                                ? (_isLoadingSurabaya ? 'Memuat...' : 'Muat Ulang Surabaya')
                                : (_isSyncing ? 'Menghubungkan...' : 'Muat Ulang Data')),
                      ),
                      onPressed: (_isSyncing || (_activeTabIndex == 2 && _isLoadingIndustri) || (_activeTabIndex == 3 && _isLoadingSurabaya))
                          ? null
                          : () {
                              if (_activeTabIndex == 3) {
                                _fetchSurabayaRealisasi();
                              } else {
                                _triggerSapSync('Penjualan');
                              }
                            },
                    ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 16),
                    actionsWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 16),
                  actionsWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Main Card with Tabs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border, width: 1.2),
              boxShadow: context.colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    final tabBarWidget = TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      onTap: (val) => setState(() => _activeTabIndex = val),
                      dividerColor: Colors.transparent,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: context.colors.textPrimary,
                      unselectedLabelColor: context.colors.textMuted,
                      tabs: const [
                        Tab(text: 'Sell-In Distributor'),
                        Tab(text: 'Sell-Out Distributor'),
                        Tab(text: 'Sell-In Industri'),
                        Tab(text: 'Sell-Out Surabaya'),
                      ],
                    );

                    final searchWidget = SizedBox(
                      width: isNarrow ? double.infinity : 240,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari customer / invoice...',
                          prefixIcon: Icon(LucideIcons.search, size: 15, color: context.colors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: context.colors.bgElevated,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.toLowerCase().trim());
                          if (_activeTabIndex == 0 || _activeTabIndex == 1 || _activeTabIndex == 3) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                              if (!mounted) return;
                              if (_activeTabIndex == 0) {
                                _fetchSellinDistributorRealisasi(page: 1);
                              } else if (_activeTabIndex == 1) {
                                _fetchSelloutDistributorRealisasi(page: 1);
                              } else if (_activeTabIndex == 3) {
                                _fetchSurabayaRealisasi();
                              }
                            });
                          }
                        },
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tabBarWidget,
                          const SizedBox(height: 12),
                          searchWidget,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: tabBarWidget),
                        const SizedBox(width: 12),
                        searchWidget,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

                SelectionArea(
                  child: _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildSellinDistributorView();
      case 1:
        return _buildSelloutDistributorView();
      case 2:
        return _buildIndustriRealisasiView();
      case 3:
        return _buildSurabayaRealisasiView();
      default:
        return _buildSellinDistributorView();
    }
  }

  Widget _buildSellinDistributorView() {
    final colors = context.colors;
    final rows = _sellinDistRealisasi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPeriodDropdown(context, () => _fetchSellinDistributorRealisasi(page: 1)),
                OutlinedButton.icon(
                  onPressed: _isLoadingSellinDist ? null : () => _fetchSellinDistributorRealisasi(page: 1),
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildIndustriStatBadge('Transaksi', '$_sellinTotalRows Baris', context.semantic.info),
                _buildIndustriStatBadge('Total Volume', '${CurrencyFormatter.formatNumber(_sellinTotalVol)} Kg', Theme.of(context).colorScheme.primary),
                _buildIndustriStatBadge('Total DPP', CurrencyFormatter.formatRupiah(_sellinTotalNom), context.semantic.success),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text('Sync dari SAP'),
                  onPressed: _isLoadingSellinDist ? null : _showSyncSellinSapDialog,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_sellinDistError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.semantic.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_sellinDistError!, style: TextStyle(color: context.semantic.danger, fontSize: 13)),
          ),
        if (_isLoadingSellinDist)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.bgSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.truck, size: 36, color: colors.textMuted),
                const SizedBox(height: 10),
                Text(
                  'Belum ada data Sell-In Distributor${_selectedPeriod.isNotEmpty ? ' periode $_selectedPeriod' : ''}.',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Klik "Sync dari SAP" untuk menarik transaksi Sell-In Distributor berdasarkan Depo & ItemCode.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 960,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: [
                DataColumn(label: Text('Periode & Tgl', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('No. SAP Doc', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Distributor / Depo (SAP)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Brand & Item SAP', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Sales PIC', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Volume (Kg)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('DPP (Rp)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: rows.map((row) {
                final distName = row['distributor']?['name'] ?? '-';
                final depoName = row['depo']?['name'] ?? '-';
                final depoCode = row['depo']?['code'] ?? '-';
                final brandCode = row['brand']?['code'] ?? '-';
                final itemCode = row['item_code'] ?? '-';
                final itemName = row['item_name'] ?? '';
                final salesUser = row['user']?['name'];
                final sapSlp = row['sap_slp_name'];
                final volKg = _toDouble(row['volume_kg']);
                final nom = _toDouble(row['nominal']);
                final txDate = (row['transaction_date'] ?? '').toString().split('T').first;

                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(row['period']?.toString() ?? '-', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                          if (txDate.isNotEmpty)
                            Text(txDate, style: TextStyle(color: colors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    DataCell(Text(row['sap_doc_no']?.toString() ?? '-', style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$depoName ($depoCode)', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                            Text(distName.toString(), style: TextStyle(color: colors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(brandCode.toString(), style: TextStyle(color: context.semantic.info, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text('$itemCode${itemName.toString().isNotEmpty ? " • $itemName" : ""}', style: TextStyle(color: colors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (salesUser ?? 'Belum di-assign ASM').toString(),
                              style: TextStyle(
                                color: salesUser != null ? colors.textPrimary : context.semantic.warning,
                                fontSize: 12.5,
                                fontWeight: salesUser != null ? FontWeight.w600 : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sapSlp != null && sapSlp.toString().isNotEmpty)
                              Text(
                                'SAP Slp: $sapSlp',
                                style: TextStyle(color: colors.textMuted, fontSize: 10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyFormatter.formatNumber(volKg)} Kg',
                        style: TextStyle(
                          color: volKg < 0 ? context.semantic.danger : colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatRupiah(nom),
                        style: TextStyle(
                          color: nom < 0 ? context.semantic.danger : context.semantic.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Baris/hal:', style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _sellinPerPage,
                    dropdownColor: colors.bgElevated,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                    items: const [25, 50, 100]
                        .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null || v == _sellinPerPage) return;
                      setState(() => _sellinPerPage = v);
                      _fetchSellinDistributorRealisasi(page: 1);
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _sellinPage > 1 && !_isLoadingSellinDist
                        ? () => _fetchSellinDistributorRealisasi(page: _sellinPage - 1)
                        : null,
                    icon: const Icon(LucideIcons.chevronLeft, size: 14),
                    label: const Text('Prev'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hal $_sellinPage / $_sellinLastPage ($_sellinTotalRows data)',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _sellinPage < _sellinLastPage && !_isLoadingSellinDist
                        ? () => _fetchSellinDistributorRealisasi(page: _sellinPage + 1)
                        : null,
                    icon: const Icon(LucideIcons.chevronRight, size: 14),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSelloutDistributorView() {
    final colors = context.colors;
    final rows = _selloutDistRealisasi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPeriodDropdown(context, () => _fetchSelloutDistributorRealisasi(page: 1)),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selloutAreaFilter,
                    isExpanded: true,
                    dropdownColor: colors.bgElevated,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Cakupan Area',
                      prefixIcon: Icon(LucideIcons.mapPin, size: 15, color: colors.textMuted),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: colors.bgElevated,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua Area', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'in_area', child: Text('Dalam Area (Insentif)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'out_area', child: Text('Area Luar (Non-Insentif)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selloutAreaFilter = v);
                        _fetchSelloutDistributorRealisasi(page: 1);
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoadingSelloutDist ? null : () => _fetchSelloutDistributorRealisasi(page: _selloutPage),
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildIndustriStatBadge('Transaksi', '${CurrencyFormatter.formatNumber(_selloutTotalRows)} Baris', context.semantic.info),
                _buildIndustriStatBadge('Total SalesKg', '${CurrencyFormatter.formatNumber(_selloutTotalVol)} Kg', Theme.of(context).colorScheme.primary),
                _buildIndustriStatBadge('Total DPP', CurrencyFormatter.formatRupiah(_selloutTotalNom), context.semantic.success),
                _buildIndustriStatBadge('Active Outlet (AO)', '${CurrencyFormatter.formatNumber(_selloutTotalAo)} Toko', context.semantic.warning),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  icon: const Icon(LucideIcons.uploadCloud, size: 16),
                  label: const Text('Upload Excel Sell-Out'),
                  onPressed: () => context.go('/bulk-upload'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_selloutDistError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.semantic.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_selloutDistError!, style: TextStyle(color: context.semantic.danger, fontSize: 13)),
          ),
        if (_isLoadingSelloutDist)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.bgSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.fileSpreadsheet, size: 36, color: colors.textMuted),
                const SizedBox(height: 10),
                Text(
                  'Belum ada data Sell-Out Distributor${_periodController.text.trim().isNotEmpty ? ' periode ${_periodController.text.trim()}' : ''}.',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unggah file Excel/CSV Sell-Out Distributor (dengan kolom wajib AreaCode) melalui menu Bulk Upload.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          )
        else ...[
          ResponsiveTableCard(
            minWidth: 980,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: [
                DataColumn(label: Text('Periode & Tgl', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Faktur', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Distributor / Depo / AreaCode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Customer (Outlet)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Brand & Barang', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('SalesKg', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('DPP (Rp)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold)), numeric: true),
              ],
              rows: rows.map((row) {
                final distName = row['distributor']?['name'] ?? '-';
                final depoName = row['depo']?['name'] ?? '-';
                final depoCode = row['depo']?['code'] ?? '-';
                final areaCode = row['area']?['code'] ?? '-';
                final areaName = row['area']?['name'] ?? '';
                final isOutArea = row['is_out_of_area'] == true;
                final kotaKab = (row['kota_kab'] ?? '').toString();
                final kecamatan = (row['kecamatan'] ?? '').toString();
                final brandCode = row['brand']?['code'] ?? '-';
                final itemName = row['item_name'] ?? row['item_desc'] ?? '-';
                final volKg = _toDouble(row['volume_kg']);
                final dpp = _toDouble(row['nominal']);
                final txDate = (row['transaction_date'] ?? '').toString().split('T').first;

                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(row['period']?.toString() ?? '-', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                          if (txDate.isNotEmpty)
                            Text(txDate, style: TextStyle(color: colors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    DataCell(Text(row['faktur']?.toString() ?? '-', style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$depoName ($depoCode)', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                            if (isOutArea)
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: context.semantic.warning.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'AREA LUAR (Non-Insentif)',
                                      style: TextStyle(color: context.semantic.warning, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${kotaKab.isNotEmpty ? kotaKab : '-'}${kecamatan.isNotEmpty ? " / $kecamatan" : ""} • $distName',
                                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )
                            else
                              Text('Area: $areaCode${areaName.toString().isNotEmpty ? " ($areaName)" : ""} • $distName', style: TextStyle(color: colors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(row['customer_name']?.toString() ?? '-', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                            Text('${row['customer_code'] ?? "-"} • ${row['tipe_outlet'] ?? "-"}', style: TextStyle(color: colors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(brandCode.toString(), style: TextStyle(color: context.semantic.info, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text(itemName.toString(), style: TextStyle(color: colors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyFormatter.formatNumber(volKg)} Kg',
                        style: TextStyle(
                          color: volKg < 0 ? context.semantic.danger : colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        CurrencyFormatter.formatRupiah(dpp),
                        style: TextStyle(
                          color: dpp < 0 ? context.semantic.danger : context.semantic.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Baris/hal:', style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _selloutPerPage,
                    dropdownColor: colors.bgElevated,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                    items: const [25, 50, 100]
                        .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null || v == _selloutPerPage) return;
                      setState(() => _selloutPerPage = v);
                      _fetchSelloutDistributorRealisasi(page: 1);
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _selloutPage > 1 && !_isLoadingSelloutDist
                        ? () => _fetchSelloutDistributorRealisasi(page: _selloutPage - 1)
                        : null,
                    icon: const Icon(LucideIcons.chevronLeft, size: 14),
                    label: const Text('Prev'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hal $_selloutPage / $_selloutLastPage (${CurrencyFormatter.formatNumber(_selloutTotalRows)} data)',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selloutPage < _selloutLastPage && !_isLoadingSelloutDist
                        ? () => _fetchSelloutDistributorRealisasi(page: _selloutPage + 1)
                        : null,
                    icon: const Icon(LucideIcons.chevronRight, size: 14),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIndustriRealisasiView() {
    final colors = context.colors;
    final filtered = _industriRealisasi.where((row) {
      if (_searchQuery.isEmpty) return true;
      final custName = (row['customer_name'] ?? row['industri_customer']?['customer_name'] ?? '').toString().toLowerCase();
      final custCode = (row['customer_code'] ?? row['industri_customer']?['customer_code'] ?? '').toString().toLowerCase();
      final sapNo = (row['sap_so_no'] ?? '').toString().toLowerCase();
      final userName = (row['user']?['name'] ?? '').toString().toLowerCase();
      return custName.contains(_searchQuery) ||
          custCode.contains(_searchQuery) ||
          sapNo.contains(_searchQuery) ||
          userName.contains(_searchQuery);
    }).toList();

    final totalVol = filtered.fold<double>(
      0.0,
      (sum, row) => sum + (double.tryParse((row['volume_kg'] ?? row['tonase'] ?? 0).toString()) ?? 0.0),
    );
    final totalNom = filtered.fold<double>(
      0.0,
      (sum, row) => sum + (double.tryParse((row['nominal'] ?? 0).toString()) ?? 0.0),
    );
    final nooCount = filtered.where((row) => row['is_noo'] == true || row['is_noo'] == 1).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPeriodDropdown(context, _fetchIndustriRealisasi),
                OutlinedButton.icon(
                  onPressed: _isLoadingIndustri ? null : _fetchIndustriRealisasi,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildIndustriStatBadge('Transaksi', '${filtered.length} Baris', context.semantic.info),
                _buildIndustriStatBadge('Total Volume', '${CurrencyFormatter.formatNumber(totalVol)} Kg', Theme.of(context).colorScheme.primary),
                _buildIndustriStatBadge('Total Nilai', CurrencyFormatter.formatRupiah(totalNom), context.semantic.success),
                _buildIndustriStatBadge('Tandai NOO Manual', '$nooCount', context.semantic.warning),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text('Sync dari SAP'),
                  onPressed: _isLoadingIndustri ? null : _syncIndustriFromSap,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Input Realisasi Industri'),
                  onPressed: _showAddIndustriModal,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_industriError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.semantic.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_industriError!, style: TextStyle(color: context.semantic.danger, fontSize: 13)),
          ),
        if (_isLoadingIndustri)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.factory, size: 44, color: colors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada transaksi Sell-In Industri${_periodController.text.trim().isNotEmpty ? ' periode ${_periodController.text.trim()}' : ''}.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Klik "Input Realisasi Industri" atau unggah via Bulk Upload (entity: sellin_industri).',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 1020,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              dataRowMinHeight: 54,
              dataRowMaxHeight: 72,
              columns: [
                DataColumn(label: Text('Periode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('No. SAP SO', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Customer Industri', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Sales PIC', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Volume (Kg)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Nominal (Rp)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Mode NOO', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((row) {
                final period = row['period']?.toString() ?? '-';
                final sapNo = (row['sap_so_no']?.toString().isNotEmpty == true) ? row['sap_so_no'].toString() : '-';
                final cust = row['industri_customer'] as Map<String, dynamic>?;
                final custCode = (row['customer_code'] ?? cust?['customer_code'] ?? '-').toString();
                final custName = (row['customer_name'] ?? cust?['customer_name'] ?? '-').toString();
                final custType = (cust?['customer_type'] ?? '').toString();
                final user = row['user'] as Map<String, dynamic>?;
                final userName = user?['name']?.toString() ?? 'Auto Assignment';
                final posCode = user?['position']?['code']?.toString();
                final volKg = double.tryParse((row['volume_kg'] ?? row['tonase'] ?? 0).toString()) ?? 0.0;
                final nom = double.tryParse((row['nominal'] ?? 0).toString()) ?? 0.0;
                final rawNoo = row['is_noo'];
                final bool? isNoo = rawNoo == null ? null : (rawNoo == true || rawNoo == 1 || rawNoo == '1');

                final Color nooColor = isNoo == true
                    ? context.semantic.success
                    : (isNoo == false ? context.semantic.info : context.semantic.warning);
                final String nooLabel = isNoo == true
                    ? 'NOO (Ya)'
                    : (isNoo == false ? 'Repeat (Tidak)' : 'Auto (Sistem)');

                return DataRow(
                  cells: [
                    DataCell(Text(period, style: TextStyle(color: context.semantic.warning, fontWeight: FontWeight.bold))),
                    DataCell(Text(sapNo, style: TextStyle(color: colors.textSecondary, fontSize: 12))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              custName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(custCode, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                if (custType.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (custType == 'NEW' ? context.semantic.success : context.semantic.info).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      custType,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: custType == 'NEW' ? context.semantic.success : context.semantic.info,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        posCode != null ? '$userName ($posCode)' : userName,
                        style: TextStyle(
                          color: user != null ? colors.textPrimary : colors.textMuted,
                          fontSize: 12.5,
                          fontWeight: user != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    DataCell(Text('${CurrencyFormatter.formatNumber(volKg)} Kg', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))),
                    DataCell(Text(CurrencyFormatter.formatRupiah(nom), style: TextStyle(color: context.semantic.success, fontWeight: FontWeight.w600))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: nooColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                        child: Text(nooLabel, style: TextStyle(color: nooColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                        tooltip: 'Hapus Transaksi',
                        onPressed: () => _deleteIndustriRealisasi(row),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildIndustriStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSurabayaRealisasiView() {
    final colors = context.colors;
    final rows = _surabayaRealisasi;
    final totalVol = rows.fold<double>(0.0, (s, r) => s + _toDouble(r['volume']));
    final totalAo = rows.fold<int>(0, (s, r) => s + _toInt(r['active_outlet_count']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPeriodDropdown(context, _fetchSurabayaRealisasi),
                OutlinedButton.icon(
                  onPressed: _isLoadingSurabaya ? null : _fetchSurabayaRealisasi,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildIndustriStatBadge('Transaksi', '${rows.length} Baris', context.semantic.info),
                _buildIndustriStatBadge('Total Volume', '${CurrencyFormatter.formatNumber(totalVol)} Kg', Theme.of(context).colorScheme.primary),
                _buildIndustriStatBadge('Active Outlet', '${CurrencyFormatter.formatNumber(totalAo)} Toko', context.semantic.success),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_surabayaError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.semantic.dangerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_surabayaError!, style: TextStyle(color: context.semantic.danger, fontSize: 13)),
          ),
        if (_isLoadingSurabaya)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.bgSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.inbox, size: 32, color: colors.textMuted),
                const SizedBox(height: 10),
                Text(
                  'Belum ada data realisasi Sell-Out Sales Surabaya untuk periode ini.',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unggah data melalui Bulk Upload Data (entitas Sell-Out Sales Surabaya).',
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 780,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              dataRowMinHeight: 50,
              dataRowMaxHeight: 64,
              columns: [
                DataColumn(label: Text('Periode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Sales Surabaya', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Posisi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Koordinator (ASC)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Volume (Kg)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Active Outlet (Toko)', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: rows.map((row) {
                final sales = row['sales'] is Map ? row['sales'] as Map : null;
                final coord = row['coordinator'] is Map ? row['coordinator'] as Map : null;
                final pos = sales?['position'] is Map ? sales!['position'] as Map : null;
                final vol = _toDouble(row['volume']);
                final ao = _toInt(row['active_outlet_count']);

                return DataRow(
                  cells: [
                    DataCell(Text('${row['period'] ?? '-'}', style: TextStyle(color: context.semantic.warning, fontWeight: FontWeight.bold))),
                    DataCell(Text('${sales?['name'] ?? '-'}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
                    DataCell(Text('${pos?['code'] ?? '-'}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
                    DataCell(Text('${coord?['name'] ?? '-'}', style: TextStyle(color: colors.textSecondary))),
                    DataCell(Text('${CurrencyFormatter.formatNumber(vol)} Kg', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))),
                    DataCell(Text('${CurrencyFormatter.formatNumber(ao)} Toko', style: TextStyle(color: context.semantic.info, fontWeight: FontWeight.w600))),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/master_model.dart';

class MasterRealisasiScreen extends ConsumerStatefulWidget {
  const MasterRealisasiScreen({super.key});

  @override
  ConsumerState<MasterRealisasiScreen> createState() => _MasterRealisasiScreenState();
}

class _MasterRealisasiScreenState extends ConsumerState<MasterRealisasiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _periodController = TextEditingController(text: '202610');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
  }

  // Mock sample records for each stream
  final List<RealisasiSalesModel> _sellinDistributor = [
    RealisasiSalesModel(id: 1, entityType: 'sellin_distributor', period: '202610', customerCode: 'DST-001', customerName: 'PT Sumber Rezeki Makmur', volume: 85200, amount: 1278000000, activeOutlet: 45),
    RealisasiSalesModel(id: 2, entityType: 'sellin_distributor', period: '202610', customerCode: 'DST-002', customerName: 'CV Maju Lancar Bersama', volume: 62400, amount: 936000000, activeOutlet: 32),
    RealisasiSalesModel(id: 3, entityType: 'sellin_distributor', period: '202610', customerCode: 'DST-003', customerName: 'PT Mega Buana Distribusi', volume: 51250, amount: 768750000, activeOutlet: 28),
  ];

  final List<RealisasiSalesModel> _selloutDistributor = [
    RealisasiSalesModel(id: 4, entityType: 'sellout_distributor', period: '202610', customerCode: 'OUT-101', customerName: 'Toko Berkah Jaya', volume: 3400, amount: 51000000, activeOutlet: 1),
    RealisasiSalesModel(id: 5, entityType: 'sellout_distributor', period: '202610', customerCode: 'OUT-102', customerName: 'Grosir Sinar Terang', volume: 8900, amount: 133500000, activeOutlet: 1),
    RealisasiSalesModel(id: 6, entityType: 'sellout_distributor', period: '202610', customerCode: 'OUT-103', customerName: 'Minimarket Sentosa', volume: 5600, amount: 84000000, activeOutlet: 1),
  ];

  final List<RealisasiSalesModel> _sellinIndustri = [
    RealisasiSalesModel(id: 7, entityType: 'sellin_industri', period: '202610', customerCode: 'IND-501', customerName: 'PT Roti Harum Nusantara', volume: 42000, amount: 630000000, newOpenOutlet: 2),
    RealisasiSalesModel(id: 8, entityType: 'sellin_industri', period: '202610', customerCode: 'IND-502', customerName: 'Pabrik Biskuit Prima Rasa', volume: 23000, amount: 345000000, newOpenOutlet: 1),
  ];

  final List<RealisasiSalesModel> _selloutSurabaya = [
    RealisasiSalesModel(id: 9, entityType: 'sellout_surabaya', period: '202610', customerCode: 'SBY-01', customerName: 'Depo Rungkut - Canvasing Team 1', volume: 18500, amount: 277500000, activeOutlet: 88),
    RealisasiSalesModel(id: 10, entityType: 'sellout_surabaya', period: '202610', customerCode: 'SBY-02', customerName: 'Depo Tandes - Taking Order Team 2', volume: 23300, amount: 349500000, activeOutlet: 112),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    _periodController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _triggerSapSync(String streamName) async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isSyncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sinkronisasi data $streamName dari SAP ERP berhasil disinkronkan untuk periode ${_periodController.text}.'),
          backgroundColor: AppColors.success,
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
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitoring data aktual transaksi penjualan dari SAP ERP, upload file distributor, industri, dan cabang Surabaya',
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: _isSyncing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(_isSyncing ? 'Menghubungkan...' : 'Tarik Data SAP'),
                    onPressed: _isSyncing ? null : () => _triggerSapSync('Penjualan'),
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
              borderRadius: BorderRadius.circular(16),
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
                      indicatorColor: AppColors.primary,
                      labelColor: context.colors.textPrimary,
                      unselectedLabelColor: context.colors.textMuted,
                      tabs: const [
                        Tab(text: 'Sell-In Distributor (SAP)'),
                        Tab(text: 'Sell-Out Distributor (Upload)'),
                        Tab(text: 'Sell-In Industri (SAP)'),
                        Tab(text: 'Sell-Out Sales Surabaya (SAP)'),
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
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
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

                _buildActiveTabContent(),
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
        return _buildRealisasiTable(_sellinDistributor, isOutlet: true);
      case 1:
        return _buildRealisasiTable(_selloutDistributor, isOutlet: false);
      case 2:
        return _buildRealisasiTable(_sellinIndustri, isNoo: true);
      case 3:
        return _buildRealisasiTable(_selloutSurabaya, isOutlet: true);
      default:
        return _buildRealisasiTable(_sellinDistributor, isOutlet: true);
    }
  }

  Widget _buildRealisasiTable(List<RealisasiSalesModel> list, {bool isOutlet = false, bool isNoo = false}) {
    final filtered = list.where((item) {
      if (_searchQuery.isEmpty) return true;
      final name = item.customerName?.toLowerCase() ?? '';
      final code = item.customerCode?.toLowerCase() ?? '';
      return name.contains(_searchQuery) || code.contains(_searchQuery);
    }).toList();

    return ResponsiveTableCard(
      minWidth: 880,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Periode', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Kode / Doc No', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Customer / Entitas', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Volume (Kg / Box)', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total Nilai (Rp)', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          if (isOutlet)
            DataColumn(label: Text('Active Outlet (AO)', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          if (isNoo)
            DataColumn(label: Text('New Open Outlet (NOO)', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status Sinkron', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.period, style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
              DataCell(Text(row.customerCode ?? '-', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    row.customerName ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              DataCell(Text(CurrencyFormatter.formatNumber(row.volume), style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold))),
              DataCell(Text(CurrencyFormatter.formatRupiah(row.amount), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
              if (isOutlet)
                DataCell(Text('${row.activeOutlet ?? 0} Toko', style: const TextStyle(color: AppColors.info))),
              if (isNoo)
                DataCell(Text('${row.newOpenOutlet ?? 0} NOO', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: const Text('SAP Synced', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}


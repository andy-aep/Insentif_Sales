import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/responsive_table.dart';
import '../providers/master_data_provider.dart';

class OrganizationScreen extends ConsumerStatefulWidget {
  const OrganizationScreen({super.key});

  @override
  ConsumerState<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<OrganizationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
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

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(masterDataProvider);
    final notifier = ref.read(masterDataProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Master Organisasi & Wilayah',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manajemen data referensi hierarki Distributor, Depo, Area Operasional, dan Brand Produk',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              );

              final refreshBtn = IconButton(
                icon: Icon(LucideIcons.refreshCw, color: colors.textSecondary),
                tooltip: 'Segarkan Master Data',
                onPressed: () => notifier.fetchAllMasterData(),
              );

              if (isNarrow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    refreshBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleWidget),
                  refreshBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Search & Tab Bar Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
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
                      labelColor: colors.textPrimary,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
                      tabs: [
                        Tab(text: 'Distributor (${state.distributors.length})'),
                        Tab(text: 'Depo (${state.depos.length})'),
                        Tab(text: 'Area (${state.areas.length})'),
                        Tab(text: 'Brand (${state.brands.length})'),
                      ],
                    );

                    final searchWidget = SizedBox(
                      width: isNarrow ? double.infinity : 220,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari kode / nama...',
                          hintStyle: TextStyle(color: colors.textMuted),
                          prefixIcon: Icon(LucideIcons.search, size: 16, color: colors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase().trim();
                          });
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
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 16),

                // Tab Content
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else
                  _buildActiveTabContent(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, MasterDataState state) {
    switch (_activeTabIndex) {
      case 0:
        return _buildDistributorsTable(context, state);
      case 1:
        return _buildDeposTable(context, state);
      case 2:
        return _buildAreasTable(context, state);
      case 3:
        return _buildBrandsTable(context, state);
      default:
        return _buildDistributorsTable(context, state);
    }
  }

  Widget _buildDistributorsTable(BuildContext context, MasterDataState state) {
    final colors = context.colors;
    final filtered = state.distributors.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) || d.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data distributor ditemukan');

    return ResponsiveTableCard(
      minWidth: 700,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Kode', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Distributor', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Alamat Kantor', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((d) {
          return DataRow(
            cells: [
              DataCell(Text(d.code, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
              DataCell(Text(d.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500))),
              DataCell(Text(d.address ?? '-', style: TextStyle(color: colors.textSecondary))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeposTable(BuildContext context, MasterDataState state) {
    final colors = context.colors;
    final filtered = state.depos.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) || d.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data depo ditemukan');

    return ResponsiveTableCard(
      minWidth: 700,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Kode Depo', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Depo', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Induk Distributor', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((d) {
          return DataRow(
            cells: [
              DataCell(Text(d.code, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
              DataCell(Text(d.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500))),
              DataCell(Text(d.distributor?.name ?? 'Distributor #${d.distributorId ?? "-"}', style: TextStyle(color: colors.textSecondary))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAreasTable(BuildContext context, MasterDataState state) {
    final colors = context.colors;
    final filtered = state.areas.where((a) {
      if (_searchQuery.isEmpty) return true;
      return a.name.toLowerCase().contains(_searchQuery) || a.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data area ditemukan');

    return ResponsiveTableCard(
      minWidth: 650,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Kode Area', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Area Operasional', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((a) {
          return DataRow(
            cells: [
              DataCell(Text(a.code, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
              DataCell(Text(a.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandsTable(BuildContext context, MasterDataState state) {
    final colors = context.colors;
    final filtered = state.brands.where((b) {
      if (_searchQuery.isEmpty) return true;
      return b.name.toLowerCase().contains(_searchQuery) || b.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data brand ditemukan');

    return ResponsiveTableCard(
      minWidth: 650,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Kode Brand', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Merek Dagang', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((b) {
          return DataRow(
            cells: [
              DataCell(Text(b.code, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold))),
              DataCell(Text(b.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String msg) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

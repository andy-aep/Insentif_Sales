import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Organisasi & Wilayah', style: tt.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Manajemen data referensi hierarki Distributor, Depo, Area Operasional, dan Brand Produk',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              );

              final refreshBtn = IconButton(
                icon: Icon(LucideIcons.refreshCw, color: cs.onSurfaceVariant, size: 18),
                tooltip: 'Segarkan Master Data',
                onPressed: () => notifier.fetchAllMasterData(force: true),
              );

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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
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
                      indicatorColor: cs.primary,
                      labelColor: cs.primary,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      tabs: [
                        Tab(text: 'Distributor (${state.distributors.length})'),
                        Tab(text: 'Depo (${state.depos.length})'),
                        Tab(text: 'Area (${state.areas.length})'),
                        Tab(text: 'Brand (${state.brands.length})'),
                      ],
                    );

                    final searchWidget = SizedBox(
                      width: isNarrow ? double.infinity : 240,
                      child: TextField(
                        controller: _searchController,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Cari kode / nama...',
                          prefixIcon: Icon(LucideIcons.search, size: 16, color: cs.onSurfaceVariant),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Tab Content
                if (state.isLoading)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: cs.primary)),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = state.distributors.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) || d.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data distributor ditemukan');

    return ResponsiveTableCard(
      minWidth: 700,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('KODE')),
          DataColumn(label: Text('NAMA DISTRIBUTOR')),
          DataColumn(label: Text('ALAMAT KANTOR')),
        ],
        rows: filtered.map((d) {
          return DataRow(
            cells: [
              DataCell(Text(d.code, style: tt.labelLarge?.copyWith(color: cs.primary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(d.name, style: tt.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(d.address ?? '-', style: tt.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeposTable(BuildContext context, MasterDataState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = state.depos.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) || d.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data depo ditemukan');

    return ResponsiveTableCard(
      minWidth: 700,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('KODE DEPO')),
          DataColumn(label: Text('NAMA DEPO')),
          DataColumn(label: Text('INDUK DISTRIBUTOR')),
        ],
        rows: filtered.map((d) {
          return DataRow(
            cells: [
              DataCell(Text(d.code, style: tt.labelLarge?.copyWith(color: cs.primary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(d.name, style: tt.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(d.distributor?.name ?? 'Distributor #${d.distributorId ?? "-"}', style: tt.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAreasTable(BuildContext context, MasterDataState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = state.areas.where((a) {
      if (_searchQuery.isEmpty) return true;
      return a.name.toLowerCase().contains(_searchQuery) || a.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data area ditemukan');

    return ResponsiveTableCard(
      minWidth: 650,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('KODE AREA')),
          DataColumn(label: Text('NAMA AREA OPERASIONAL')),
        ],
        rows: filtered.map((a) {
          return DataRow(
            cells: [
              DataCell(Text(a.code, style: tt.labelLarge?.copyWith(color: cs.primary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(a.name, style: tt.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandsTable(BuildContext context, MasterDataState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = state.brands.where((b) {
      if (_searchQuery.isEmpty) return true;
      return b.name.toLowerCase().contains(_searchQuery) || b.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) return _buildEmptyMessage(context, 'Tidak ada data brand ditemukan');

    return ResponsiveTableCard(
      minWidth: 650,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('KODE BRAND')),
          DataColumn(label: Text('NAMA MEREK DAGANG')),
        ],
        rows: filtered.map((b) {
          return DataRow(
            cells: [
              DataCell(Text(b.code, style: tt.labelLarge?.copyWith(color: cs.primary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(b.name, style: tt.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String msg) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.inbox, size: 36, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(msg, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

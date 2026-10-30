import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/responsive_table.dart';
import '../providers/incentive_calculation_provider.dart';

class IncentiveCalculationScreen extends ConsumerStatefulWidget {
  final String? initialKategori;

  const IncentiveCalculationScreen({super.key, this.initialKategori});

  @override
  ConsumerState<IncentiveCalculationScreen> createState() => _IncentiveCalculationScreenState();
}

class _IncentiveCalculationScreenState extends ConsumerState<IncentiveCalculationScreen> {
  final _periodController = TextEditingController(text: '202610');
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialKategori != null) {
        ref.read(incentiveCalculationProvider.notifier).setKategori(widget.initialKategori!);
      }
    });
  }

  @override
  void dispose() {
    _periodController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getScreenTitle(String kat) {
    switch (kat.toUpperCase()) {
      case 'DISTRIBUTOR':
      case 'KONSUMSI':
        return 'Perhitungan Insentif Distributor (Konsumsi)';
      case 'INDUSTRI':
        return 'Perhitungan Insentif Penjualan Industri';
      case 'SURABAYA':
        return 'Perhitungan Insentif Cabang Sales Surabaya';
      default:
        return 'Engine Kalkulasi Insentif Sales';
    }
  }

  String _getScreenSubtitle(String kat) {
    switch (kat.toUpperCase()) {
      case 'DISTRIBUTOR':
      case 'KONSUMSI':
        return 'Kalkulasi insentif sales distributor berbasis Sell-In, Sell-Out & Active Outlet (Bagi user is_eligible_konsumsi = true)';
      case 'INDUSTRI':
        return 'Kalkulasi insentif tim sales industri berbasis kuota volume dan New Open Outlet (NOO) (Bagi user is_eligible_industri = true)';
      case 'SURABAYA':
        return 'Kalkulasi insentif sales cabang Surabaya (Taking Order & Canvasing) (Bagi user is_eligible_surabaya = true)';
      default:
        return 'Eksekusi kalkulasi multi-tier berjenjang dan laporan insentif';
    }
  }

  Widget _buildAchievementBadge(double percent) {
    Color bg;
    Color textColor;
    String label = CurrencyFormatter.formatPercent(percent);

    if (percent < 90) {
      bg = AppColors.danger.withValues(alpha: 0.15);
      textColor = const Color(0xFFF87171);
    } else if (percent < 100) {
      bg = AppColors.warning.withValues(alpha: 0.15);
      textColor = const Color(0xFFFBBF24);
    } else if (percent < 120) {
      bg = AppColors.success.withValues(alpha: 0.15);
      textColor = const Color(0xFF34D399);
    } else {
      bg = AppColors.primary.withValues(alpha: 0.18);
      textColor = const Color(0xFF818CF8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(incentiveCalculationProvider);
    final notifier = ref.read(incentiveCalculationProvider.notifier);

    final filteredResults = state.results.where((item) {
      if (state.searchQuery.isEmpty) return true;
      final q = state.searchQuery.toLowerCase();
      final name = item.user?.name.toLowerCase() ?? '';
      final username = item.user?.username.toLowerCase() ?? '';
      return name.contains(q) || username.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getScreenTitle(state.selectedKategori),
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScreenSubtitle(state.selectedKategori),
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.refreshCw, color: colors.textSecondary),
                tooltip: 'Muat Ulang Data',
                onPressed: () => notifier.fetchResults(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Messages
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (state.successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.successMessage!, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Filter Controls Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Skema Perhitungan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: colors.bgInput, borderRadius: BorderRadius.circular(10), border: Border.all(color: colors.borderMuted)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: (state.selectedKategori == 'DISTRIBUTOR' || state.selectedKategori == 'KONSUMSI')
                                  ? 'KONSUMSI'
                                  : state.selectedKategori,
                              dropdownColor: colors.bgCard,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              icon: Icon(LucideIcons.chevronDown, size: 16, color: colors.textSecondary),
                              items: const [
                                DropdownMenuItem(value: 'KONSUMSI', child: Text('Insentif Distributor (Konsumsi)')),
                                DropdownMenuItem(value: 'INDUSTRI', child: Text('Insentif Industri')),
                                DropdownMenuItem(value: 'SURABAYA', child: Text('Insentif Sales Surabaya')),
                              ],
                              onChanged: (val) {
                                if (val != null) notifier.setKategori(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Periode (YYYYMM)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _periodController,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              hintText: '202610',
                              hintStyle: TextStyle(color: colors.textMuted),
                              filled: true,
                              fillColor: colors.bgInput,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                              prefixIcon: Icon(LucideIcons.calendar, size: 15, color: colors.textSecondary),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) notifier.setPeriod(val.trim());
                            },
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(LucideIcons.filter, size: 15),
                        label: const Text('Filter'),
                        onPressed: () => notifier.setPeriod(_periodController.text.trim()),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: state.isCalculating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.calculator, size: 16),
                      label: Text(state.isCalculating ? 'Memproses...' : 'Hitung Insentif'),
                      onPressed: state.isCalculating ? null : () => notifier.calculate(),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: state.isExporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.fileSpreadsheet, size: 16),
                      label: Text(state.isExporting ? 'Mengunduh...' : 'Save to Excel'),
                      onPressed: state.isExporting ? null : () => notifier.exportExcel(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI Banner
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 850;
              final crossAxis = isDesktop ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxis,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 2.1 : 2.5,
                children: [
                  _buildSummaryItem(context, title: 'Sales Berhak (Eligible)', value: '${state.summary.totalPersonil} Personil', icon: LucideIcons.users, color: AppColors.info),
                  _buildSummaryItem(context, title: 'Total Kuota Target', value: '${CurrencyFormatter.formatNumber(state.summary.totalQuota)} Unit', icon: LucideIcons.target, color: AppColors.primaryLight),
                  _buildSummaryItem(context, title: 'Total Realisasi', value: '${CurrencyFormatter.formatNumber(state.summary.totalRealization)} Unit', icon: LucideIcons.checkCheck, color: AppColors.success),
                  _buildSummaryItem(context, title: 'Akumulasi Reward Insentif', value: CurrencyFormatter.formatRupiah(state.summary.totalReward), icon: LucideIcons.wallet, color: const Color(0xFF8B5CF6)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Data Table
          Container(
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final titleRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Hasil Perhitungan Insentif Sales', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(12)),
                            child: Text('${filteredResults.length} Baris', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                          ),
                        ],
                      );

                      final searchBox = SizedBox(
                        width: isNarrow ? double.infinity : 250,
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: colors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari nama sales...',
                            hintStyle: TextStyle(color: colors.textMuted),
                            prefixIcon: Icon(LucideIcons.search, size: 16, color: colors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: colors.bgInput,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                          ),
                          onChanged: (val) => notifier.setSearchQuery(val),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 12),
                            searchBox,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          titleRow,
                          const Spacer(),
                          searchBox,
                        ],
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: colors.border),

                if (state.isLoading)
                  const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                else if (filteredResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calculator, size: 48, color: colors.textMuted),
                          const SizedBox(height: 16),
                          Text('Belum Ada Hasil Kalkulasi Periode Ini', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          const SizedBox(height: 6),
                          Text('Klik tombol "Hitung Insentif" di atas untuk memproses kalkulasi otomatis.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ResponsiveTableCard(
                    minWidth: 1050,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
                      columns: [
                        DataColumn(label: Text('Personil Sales', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Jabatan / Posisi', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Target Kuota', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Realisasi Aktual', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Pencapaian', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Capped Realisasi', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Model Rumus', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Bobot Header', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Nominal Reward', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                      ],
                      rows: filteredResults.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text((item.user?.name.isNotEmpty == true ? item.user!.name[0] : 'S').toUpperCase(), style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(item.user?.name ?? 'Sales #${item.userId}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('@${item.user?.username ?? "-"}', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(item.user?.position?.name ?? item.user?.role?.displayName ?? 'Sales Field', style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
                            DataCell(Text(CurrencyFormatter.formatNumber(item.targetQuota), style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500))),
                            DataCell(Text(CurrencyFormatter.formatNumber(item.realization), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
                            DataCell(_buildAchievementBadge(item.achievementPercent)),
                            DataCell(Text(CurrencyFormatter.formatNumber(item.cappedRealization), style: TextStyle(color: colors.textSecondary))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isRateBased ? AppColors.info.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isRateBased ? 'Rate (${CurrencyFormatter.formatRupiah(item.unitRate)}/u)' : 'Lump Sum',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: item.isRateBased ? AppColors.info : AppColors.warning),
                                ),
                              ),
                            ),
                            DataCell(Text(CurrencyFormatter.formatPercent(item.headerBobotPercent), style: TextStyle(color: colors.textSecondary))),
                            DataCell(
                              Text(CurrencyFormatter.formatRupiah(item.finalReward), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13.5)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: colors.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                const SizedBox(height: 3),
                Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

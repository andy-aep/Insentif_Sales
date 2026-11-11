import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/models/calculation_model.dart';
import '../../users_management/providers/user_management_provider.dart';
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
  final Set<int> _expandedCardIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).fetchAll();
      if (widget.initialKategori != null) {
        ref.read(incentiveCalculationProvider.notifier).setKategori(widget.initialKategori!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant IncentiveCalculationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialKategori != oldWidget.initialKategori && widget.initialKategori != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(incentiveCalculationProvider.notifier).setKategori(widget.initialKategori!);
      });
    }
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
      textColor = const Color(0xFFD9534F);
    } else if (percent < 100) {
      bg = AppColors.warning.withValues(alpha: 0.15);
      textColor = const Color(0xFFF47A60);
    } else if (percent < 120) {
      bg = AppColors.success.withValues(alpha: 0.15);
      textColor = const Color(0xFF24968B);
    } else {
      bg = AppColors.primary.withValues(alpha: 0.18);
      textColor = const Color(0xFFF47A60);
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
    final userMgmt = ref.watch(userManagementProvider);

    final activeKategori = (widget.initialKategori ?? state.selectedKategori).toUpperCase();

    // Filter user yang eligible sesuai skema aktif & memiliki posisi sales
    final eligibleUsers = userMgmt.users.where((u) {
      if (u.positionId == null) return false;
      if (activeKategori == 'INDUSTRI') return u.isEligibleIndustri;
      if (activeKategori == 'SURABAYA') return u.isEligibleSurabaya;
      return u.isEligibleKonsumsi;
    }).toList();

    // Posisi yang eligible di skema aktif
    final eligiblePositionIds = eligibleUsers.map((u) => u.positionId!).toSet();
    final List<PositionModel> eligiblePositions = userMgmt.positions.where((p) {
      if (eligiblePositionIds.isNotEmpty) {
        return eligiblePositionIds.contains(p.id);
      }
      final code = p.code.toUpperCase();
      if (activeKategori == 'KONSUMSI' || activeKategori == 'DISTRIBUTOR') {
        return code == 'ASM' || code == 'SPV';
      }
      return true;
    }).toList();

    // Filter nama sales berdasarkan posisi yang dipilih
    final usersForSelectedPosition = state.selectedPositionId == null
        ? eligibleUsers
        : eligibleUsers.where((u) => u.positionId == state.selectedPositionId).toList();

    final selectedPosObj = state.selectedPositionId == null
        ? null
        : eligiblePositions.where((p) => p.id == state.selectedPositionId).firstOrNull;

    final filteredResults = state.results.where((item) {
      if (state.searchQuery.isEmpty) return true;
      final q = state.searchQuery.toLowerCase();
      final name = item.user?.name.toLowerCase() ?? '';
      final username = item.user?.username.toLowerCase() ?? '';
      final metric = item.metricType.toLowerCase();
      return name.contains(q) || username.contains(q) || metric.contains(q);
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
                      _getScreenTitle(activeKategori),
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScreenSubtitle(activeKategori),
                      style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.refreshCw, color: colors.textSecondary),
                tooltip: 'Muat Ulang Data',
                onPressed: () {
                  ref.read(userManagementProvider.notifier).fetchAll(force: true);
                  notifier.fetchResults();
                },
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
                  Expanded(child: Text(state.errorMessage!, style: const TextStyle(color: Color(0xFFD9534F), fontSize: 13))),
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
                  Expanded(child: Text(state.successMessage!, style: const TextStyle(color: Color(0xFF24968B), fontSize: 13))),
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
                    // 1. Pilihan Posisi Eligible
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Posisi Eligible',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.borderMuted),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: eligiblePositions.any((p) => p.id == state.selectedPositionId)
                                  ? state.selectedPositionId
                                  : null,
                              dropdownColor: colors.bgCard,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              icon: Icon(LucideIcons.chevronDown, size: 16, color: colors.textSecondary),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Posisi Eligible', overflow: TextOverflow.ellipsis),
                                ),
                                ...eligiblePositions.map((pos) {
                                  final metricHint = pos.code.toUpperCase() == 'ASM'
                                      ? ' (Sell-In)'
                                      : (pos.code.toUpperCase() == 'SPV' ? ' (Sell-Out & AO)' : '');
                                  return DropdownMenuItem<int?>(
                                    value: pos.id,
                                    child: Text(
                                      '${pos.code} - ${pos.name}$metricHint',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) => notifier.setPosition(val),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 2. Pilihan Nama Sales sesuai Posisi
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPosObj != null
                              ? '2. Nama ${selectedPosObj.code}'
                              : '2. Nama Sales Eligible',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.borderMuted),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: usersForSelectedPosition.any((u) => u.id == state.selectedUserId)
                                  ? state.selectedUserId
                                  : null,
                              dropdownColor: colors.bgCard,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              icon: Icon(LucideIcons.chevronDown, size: 16, color: colors.textSecondary),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    selectedPosObj != null
                                        ? 'Semua ${selectedPosObj.code} (${usersForSelectedPosition.length})'
                                        : 'Semua Sales (${usersForSelectedPosition.length})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...usersForSelectedPosition.map((u) {
                                  final posCode = u.position?.code ?? '';
                                  return DropdownMenuItem<int?>(
                                    value: u.id,
                                    child: Text(
                                      posCode.isNotEmpty ? '${u.name} ($posCode)' : u.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) => notifier.setUser(val),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 3. Periode (YYYYMM)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('3. Periode (YYYYMM)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary)),
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
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                            onChanged: (val) {
                              if (val.trim().length == 6 && val.trim() != state.selectedPeriod) {
                                notifier.setPeriod(val.trim());
                              }
                            },
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
                      onPressed: state.isCalculating
                          ? null
                          : () {
                              if (_periodController.text.trim().isNotEmpty && _periodController.text.trim() != state.selectedPeriod) {
                                notifier.setPeriod(_periodController.text.trim());
                              }
                              notifier.calculate();
                            },
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
                      onPressed: state.isExporting
                          ? null
                          : () {
                              if (_periodController.text.trim().isNotEmpty && _periodController.text.trim() != state.selectedPeriod) {
                                notifier.setPeriod(_periodController.text.trim());
                              }
                              notifier.exportExcel();
                            },
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
                  _buildSummaryItem(context, title: 'Akumulasi Reward Insentif', value: CurrencyFormatter.formatRupiah(state.summary.totalReward), icon: LucideIcons.wallet, color: const Color(0xFF24968B)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // View Selector & Data Header
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
                      final isNarrow = constraints.maxWidth < 750;
                      final isKonsumsi = state.selectedKategori == 'KONSUMSI';

                      final titleRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isKonsumsi && state.isBreakdownView
                                ? 'Rincian Distributor, Depo & Area'
                                : 'Hasil Perhitungan Insentif Sales',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              isKonsumsi && state.isBreakdownView
                                  ? '${state.breakdownCards.length} Depo'
                                  : '${filteredResults.length} Baris',
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      );

                      final viewToggle = isKonsumsi
                          ? Container(
                              decoration: BoxDecoration(
                                color: colors.bgSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.borderMuted),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => notifier.setBreakdownView(true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: state.isBreakdownView ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.layoutGrid, size: 14, color: state.isBreakdownView ? Colors.white : colors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text('Kartu Distributor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: state.isBreakdownView ? Colors.white : colors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => notifier.setBreakdownView(false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !state.isBreakdownView ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.table, size: 14, color: !state.isBreakdownView ? Colors.white : colors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text('Tabel Personil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !state.isBreakdownView ? Colors.white : colors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink();

                      final searchBox = SizedBox(
                        width: isNarrow ? double.infinity : 240,
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: colors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: isKonsumsi && state.isBreakdownView
                                ? 'Cari distributor / depo / area...'
                                : 'Cari nama sales...',
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
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                viewToggle,
                                searchBox,
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          titleRow,
                          const Spacer(),
                          viewToggle,
                          const SizedBox(width: 14),
                          searchBox,
                        ],
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: colors.border),

                if (state.isLoading)
                  const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                else if (state.selectedKategori == 'KONSUMSI' && state.isBreakdownView)
                  _buildDistributorCardsView(context, state)
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
                  _buildSummaryTable(context, filteredResults, colors),
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

  Widget _buildMiniBadge(double pct) {
    Color bg;
    Color text;
    if (pct < 90) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFDC2626);
    } else if (pct < 100) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildDistributorCardsView(BuildContext context, IncentiveCalculationState state) {
    final colors = context.colors;
    final query = state.searchQuery.trim().toLowerCase();

    final filteredCards = state.breakdownCards.where((card) {
      if (query.isEmpty) return true;
      final inDist = card.distributorName.toLowerCase().contains(query);
      final inDepo = card.depoName.toLowerCase().contains(query);
      final inBrand = card.brandName.toLowerCase().contains(query);
      final inAsm = card.asmName.toLowerCase().contains(query);
      final inAreas = card.areas.any((a) =>
          a.areaName.toLowerCase().contains(query) ||
          a.areaCode.toLowerCase().contains(query) ||
          a.spvName.toLowerCase().contains(query));
      return inDist || inDepo || inBrand || inAsm || inAreas;
    }).toList();

    if (filteredCards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.store, size: 48, color: colors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Tidak Ada Data Distributor / Depo',
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih posisi ASM / SPV atau personil sales, lalu klik tombol "Hitung Insentif".',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredCards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final card = filteredCards[index];
          return _buildDepoCard(card, colors);
        },
      ),
    );
  }

  Widget _buildDepoCard(DistributorBreakdownCardModel card, AppThemeColors colors) {
    final isExpanded = _expandedCardIds.contains(card.id);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clickable Card Header
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCardIds.remove(card.id);
                } else {
                  _expandedCardIds.add(card.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Icon + Distributor -> Depo + Brand pill + Periode + Chevron
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.store, size: 16, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Distributor: ${card.distributorName}',
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            Icon(LucideIcons.arrowRight, size: 14, color: colors.textMuted),
                            Text(
                              'Depo: ${card.depoName}',
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Text(
                                'Brand: ${card.brandName}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Periode: ${card.periodFormatted}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Sell In details & Total pill
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Sell In (${card.brandName}): ',
                                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                              ),
                              TextSpan(
                                text: '${CurrencyFormatter.formatNumber(card.sellInReal)} / ${CurrencyFormatter.formatNumber(card.sellInTarget)}',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              ),
                              TextSpan(
                                text: ' (${card.sellInAchPct.toStringAsFixed(1)}%) ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: card.sellInAchPct >= 100 ? const Color(0xFF10B981) : colors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: '➔ ${CurrencyFormatter.formatRupiah(card.sellInReward)}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'Total: ${CurrencyFormatter.formatRupiah(card.totalDepoReward)}',
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 3: Progress Bar
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.bgSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (card.sellInAchPct / 100.0).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Area Table
          if (isExpanded) ...[
            Divider(height: 1, color: colors.border),
            if (card.areas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Text(
                    'Tidak ada data Area di bawah Depo ini.',
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                ),
              )
            else
              Container(
                color: colors.bgSubtle.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 40,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(colors.bgSubtle),
                    headingTextStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.textSecondary),
                    columns: const [
                      DataColumn(label: SizedBox(width: 32, child: Text('No', textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 130, child: Text('Nama Area'))),
                      DataColumn(label: SizedBox(width: 80, child: Text('Brand'))),
                      DataColumn(label: SizedBox(width: 100, child: Text('Kode Cust'))),
                      DataColumn(label: SizedBox(width: 200, child: Text('Sell Out (Real / Target | Reward)'))),
                      DataColumn(label: SizedBox(width: 180, child: Text('AO (Real / Target | Reward)'))),
                      DataColumn(label: SizedBox(width: 130, child: Text('Subtotal Area (Rp)', textAlign: TextAlign.right))),
                    ],
                    rows: card.areas.map((area) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${area.no}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 130,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    area.areaName,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (area.spvName != '-')
                                    Text(
                                      area.spvName,
                                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                area.brandName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              area.areaCode,
                              style: TextStyle(fontSize: 12, color: colors.textSecondary, fontFamily: 'monospace'),
                            ),
                          ),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${CurrencyFormatter.formatNumber(area.sellOutReal)} / ${CurrencyFormatter.formatNumber(area.sellOutTarget)}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMiniBadge(area.sellOutAchPct),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(area.sellOutReward),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${CurrencyFormatter.formatNumber(area.aoReal.toDouble())} / ${CurrencyFormatter.formatNumber(area.aoTarget.toDouble())}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMiniBadge(area.aoAchPct),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(area.aoReward),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              area.subtotalAreaReward > 0
                                  ? CurrencyFormatter.formatRupiah(area.subtotalAreaReward)
                                  : '0',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: area.subtotalAreaReward > 0 ? AppColors.success : colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTable(BuildContext context, List<IncentiveCalculationModel> filteredResults, AppThemeColors colors) {
    return ResponsiveTableCard(
      minWidth: 1000,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgSubtle),
        headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
        columns: const [
          DataColumn(label: Text('Sales Personil')),
          DataColumn(label: Text('Posisi / Role')),
          DataColumn(label: Text('Metrik & Grade')),
          DataColumn(label: Text('Target Kuota')),
          DataColumn(label: Text('Realisasi')),
          DataColumn(label: Text('Pencapaian %')),
          DataColumn(label: Text('Cap Maks')),
          DataColumn(label: Text('Metode Reward')),
          DataColumn(label: Text('Bobot %')),
          DataColumn(label: Text('Reward Bersih (Rp)')),
        ],
        rows: filteredResults.map((item) {
          final isAo = item.metricType.toUpperCase().contains('AO') || item.metricType.toUpperCase().contains('OUTLET');
          final unitLabel = isAo ? 'Toko' : 'Kg';
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        item.user?.name.isNotEmpty == true ? item.user!.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.user?.name ?? '-', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('@${item.user?.username ?? "-"}', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  item.user?.position != null
                      ? '${item.user!.position!.code} - ${item.user!.position!.name}'
                      : (item.user?.role?.displayName ?? 'Sales Field'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAo
                            ? AppColors.warning.withValues(alpha: 0.14)
                            : AppColors.info.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.metricType.isNotEmpty ? item.metricType : 'Target',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAo ? AppColors.warning : AppColors.info,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Grade ${item.gradeName} • ${item.bobotName}',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              DataCell(Text('${CurrencyFormatter.formatNumber(item.targetQuota)} $unitLabel', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500))),
              DataCell(Text('${CurrencyFormatter.formatNumber(item.realization)} $unitLabel', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
              DataCell(_buildAchievementBadge(item.achievementPercent)),
              DataCell(Text('${CurrencyFormatter.formatNumber(item.cappedRealization)} $unitLabel', style: TextStyle(color: colors.textSecondary))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isRateBased ? AppColors.info.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isRateBased ? 'Rate (${CurrencyFormatter.formatRupiah(item.unitRate)}/$unitLabel)' : 'Lump Sum',
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
    );
  }
}

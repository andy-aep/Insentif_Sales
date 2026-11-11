import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  ConsumerState<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final dashState = ref.watch(dashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Period Selector & Actions
          _buildHeader(context, authUser, dashState),
          const SizedBox(height: 24),

          if (dashState.isLoading && dashState.kpi.isEmpty)
            _buildLoadingState(context)
          else if (dashState.errorMessage != null && dashState.kpi.isEmpty)
            _buildErrorState(context, dashState.errorMessage!)
          else if (dashState.mode == 'ADMIN')
            _buildAdminDashboard(context, dashState)
          else
            _buildSalesDashboard(context, dashState),
        ],
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader(BuildContext context, dynamic user, DashboardState state) {
    final isAdmin = state.mode == 'ADMIN';
    final userPos = state.kpi['position'] ?? user?.position?.code ?? '';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 780;

          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isAdmin ? AppColors.primary : AppColors.petrol).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAdmin ? 'PORTAL ADMINISTRATOR' : 'PORTAL SALES $userPos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isAdmin ? AppColors.primary : AppColors.petrol,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin ? 'Sales Incentive Command Center' : 'Dashboard Pencapaian Insentif',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAdmin
                    ? 'Halo ${user?.name ?? "Administrator"}, pantau agregat data kuota distributor, realisasi, dan leaderboard penjualan.'
                    : 'Halo ${user?.name ?? "Sales"}, pantau target kuota penugasan, realisasi toko, dan estimasi insentif Anda.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          );

          final actionsSection = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Period Selector Dropdown
              if (state.availablePeriods.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.bgElevated,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.calendar, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: state.selectedPeriod.isNotEmpty ? state.selectedPeriod : state.availablePeriods.first,
                        underline: const SizedBox(),
                        icon: const Icon(LucideIcons.chevronDown, size: 14),
                        dropdownColor: context.colors.bgCard,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        items: state.availablePeriods.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text('Periode: $p'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(dashboardProvider.notifier).changePeriod(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Refresh Button
              IconButton(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 16),
                tooltip: 'Muat Ulang Data',
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(dashboardProvider.notifier).fetchSummary(),
              ),

              if (isAdmin) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(LucideIcons.uploadCloud, size: 16),
                  label: Text('Upload Data', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () => context.go('/bulk-upload'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    side: BorderSide(color: context.colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(LucideIcons.calculator, size: 15),
                  label: Text('Kalkulasi', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                  onPressed: () => context.go('/incentives/distributor'),
                ),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 16),
                actionsSection,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleSection),
              const SizedBox(width: 16),
              actionsSection,
            ],
          );
        },
      ),
    );
  }

  // ---------------- ADMIN DASHBOARD ----------------

  Widget _buildAdminDashboard(BuildContext context, DashboardState state) {
    final kpi = state.kpi;
    final targetSellIn = (kpi['target_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
    final realSellIn = (kpi['realisasi_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
    final achSellIn = (kpi['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;

    final targetSellOut = (kpi['target_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
    final realSellOut = (kpi['realisasi_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
    final achSellOut = (kpi['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;

    final targetOutlet = (kpi['target_outlet_count'] as num?)?.toInt() ?? 0;
    final realOutlet = (kpi['realisasi_outlet_count'] as num?)?.toInt() ?? 0;
    final achOutlet = (kpi['ach_outlet_pct'] as num?)?.toDouble() ?? 0.0;

    final totalReward = (kpi['total_incentive_pool'] as num?)?.toDouble() ?? 0.0;
    final totalDist = (kpi['total_distributors'] as num?)?.toInt() ?? 0;
    final totalSales = (kpi['total_sales'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final isMid = constraints.maxWidth >= 600 && !isWide;

            final card1 = _buildKpiCard(
              title: 'Target Sell-In (Depo/ASM)',
              value: '${CurrencyFormatter.formatNumber(targetSellIn)} Kg',
              subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realSellIn)} Kg',
              badgeText: '${achSellIn.toStringAsFixed(1)}%',
              badgeColor: achSellIn >= 100 ? AppColors.success : (achSellIn > 0 ? AppColors.primary : AppColors.slate400),
              icon: LucideIcons.truck,
              footerText: '$totalDist Distributor Nasional',
              progress: (achSellIn / 100).clamp(0.0, 1.0),
            );

            final card2 = _buildKpiCard(
              title: 'Target Sell-Out (Area/SPV)',
              value: '${CurrencyFormatter.formatNumber(targetSellOut)} Kg',
              subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realSellOut)} Kg',
              badgeText: '${achSellOut.toStringAsFixed(1)}%',
              badgeColor: achSellOut >= 100 ? AppColors.success : (achSellOut > 0 ? AppColors.primary : AppColors.slate400),
              icon: LucideIcons.shoppingBag,
              footerText: 'Konsumsi Multi-Brand',
              progress: (achSellOut / 100).clamp(0.0, 1.0),
            );

            final card3 = _buildKpiCard(
              title: 'Target Active Outlet (AO)',
              value: '${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
              subValue: 'Aktual: ${CurrencyFormatter.formatNumber(realOutlet)} Toko',
              badgeText: '${achOutlet.toStringAsFixed(1)}%',
              badgeColor: achOutlet >= 100 ? AppColors.success : (achOutlet > 0 ? AppColors.primary : AppColors.slate400),
              icon: LucideIcons.store,
              footerText: 'Cakupan Toko Ritel Area',
              progress: (achOutlet / 100).clamp(0.0, 1.0),
            );

            final card4 = _buildKpiCard(
              title: 'Estimasi Budget Insentif',
              value: CurrencyFormatter.formatRupiah(totalReward),
              subValue: totalReward > 0 ? 'Terkalkulasi Periode Aktif' : 'Belum Dijalankan',
              badgeText: '$totalSales Sales',
              badgeColor: AppColors.petrol,
              icon: LucideIcons.coins,
              footerText: 'Skema Konsumsi & Industri',
              progress: totalReward > 0 ? 1.0 : 0.0,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                  const SizedBox(width: 14),
                  Expanded(child: card3),
                  const SizedBox(width: 14),
                  Expanded(child: card4),
                ],
              );
            }

            if (isMid) {
              return Column(
                children: [
                  Row(children: [Expanded(child: card1), const SizedBox(width: 14), Expanded(child: card2)]),
                  const SizedBox(height: 14),
                  Row(children: [Expanded(child: card3), const SizedBox(width: 14), Expanded(child: card4)]),
                ],
              );
            }

            return Column(
              children: [
                card1,
                const SizedBox(height: 14),
                card2,
                const SizedBox(height: 14),
                card3,
                const SizedBox(height: 14),
                card4,
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Section: Sales Leaderboard & Monthly Trend
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildLeaderboardCard(context, state.leaderboard)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildDistributorCard(context, state.distributors)),
                ],
              );
            }

            return Column(
              children: [
                _buildLeaderboardCard(context, state.leaderboard),
                const SizedBox(height: 20),
                _buildDistributorCard(context, state.distributors),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Section: Monthly Target Bar Chart
        if (state.monthlyTrend.isNotEmpty) _buildMonthlyTrendCard(context, state.monthlyTrend),
      ],
    );
  }

  // ---------------- SALES DASHBOARD ----------------

  Widget _buildSalesDashboard(BuildContext context, DashboardState state) {
    final kpi = state.kpi;
    final posCode = kpi['position'] ?? 'SALES';
    final isAsm = posCode == 'ASM';

    final myTargetSellIn = (kpi['my_target_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
    final realSellIn = (kpi['realisasi_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
    final achSellIn = (kpi['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;

    final myTargetSellOut = (kpi['my_target_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
    final realSellOut = (kpi['realisasi_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
    final achSellOut = (kpi['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;

    final myTargetOutlet = (kpi['my_target_outlet'] as num?)?.toInt() ?? 0;
    final realOutlet = (kpi['realisasi_outlet'] as num?)?.toInt() ?? 0;
    final achOutlet = (kpi['ach_outlet_pct'] as num?)?.toDouble() ?? 0.0;

    final estimatedReward = (kpi['estimated_reward'] as num?)?.toDouble() ?? 0.0;
    final grade = (kpi['grade'] ?? '-').toString();
    final overallAch = (kpi['overall_ach_pct'] as num?)?.toDouble() ?? 0.0;

    final assignedDepos = (kpi['total_assigned_depos'] as num?)?.toInt() ?? 0;
    final assignedAreas = (kpi['total_assigned_areas'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personalized KPI Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;

            final cardMain = isAsm
                ? _buildKpiCard(
                    title: 'Target Sell-In Depo Saya',
                    value: '${CurrencyFormatter.formatNumber(myTargetSellIn)} Kg',
                    subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realSellIn)} Kg',
                    badgeText: '${achSellIn.toStringAsFixed(1)}%',
                    badgeColor: achSellIn >= 100 ? AppColors.success : AppColors.primary,
                    icon: LucideIcons.truck,
                    footerText: '$assignedDepos Depo di Bawah Tanggung Jawab',
                    progress: (achSellIn / 100).clamp(0.0, 1.0),
                  )
                : _buildKpiCard(
                    title: 'Target Sell-Out Area Saya',
                    value: '${CurrencyFormatter.formatNumber(myTargetSellOut)} Kg',
                    subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realSellOut)} Kg',
                    badgeText: '${achSellOut.toStringAsFixed(1)}%',
                    badgeColor: achSellOut >= 100 ? AppColors.success : AppColors.primary,
                    icon: LucideIcons.shoppingBag,
                    footerText: '$assignedAreas Area di Bawah Tanggung Jawab',
                    progress: (achSellOut / 100).clamp(0.0, 1.0),
                  );

            final cardOutlet = isAsm
                ? _buildKpiCard(
                    title: 'Depo Penugasan Aktif',
                    value: '$assignedDepos Depo',
                    subValue: 'Distributor ASM Area Kerja',
                    badgeText: 'ASM',
                    badgeColor: AppColors.petrol,
                    icon: LucideIcons.mapPin,
                    footerText: 'Tingkat Depo Konsumsi',
                    progress: 1.0,
                  )
                : _buildKpiCard(
                    title: 'Target Active Outlet (AO)',
                    value: '${CurrencyFormatter.formatNumber(myTargetOutlet)} Toko',
                    subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realOutlet)} Toko',
                    badgeText: '${achOutlet.toStringAsFixed(1)}%',
                    badgeColor: achOutlet >= 100 ? AppColors.success : AppColors.primary,
                    icon: LucideIcons.store,
                    footerText: 'Target Sebaran Toko Aktif',
                    progress: (achOutlet / 100).clamp(0.0, 1.0),
                  );

            final cardReward = _buildKpiCard(
              title: 'Estimasi Insentif Saya',
              value: CurrencyFormatter.formatRupiah(estimatedReward),
              subValue: grade != '-' ? 'Grade: $grade (${overallAch.toStringAsFixed(1)}%)' : 'Belum Ada Kalkulasi',
              badgeText: grade != '-' ? 'Grade $grade' : 'Menunggu',
              badgeColor: estimatedReward > 0 ? AppColors.success : AppColors.slate400,
              icon: LucideIcons.award,
              footerText: 'Periode ${state.selectedPeriod}',
              progress: estimatedReward > 0 ? (overallAch / 100).clamp(0.0, 1.0) : 0.0,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: cardMain),
                  const SizedBox(width: 16),
                  Expanded(child: cardOutlet),
                  const SizedBox(width: 16),
                  Expanded(child: cardReward),
                ],
              );
            }

            return Column(
              children: [
                cardMain,
                const SizedBox(height: 14),
                cardOutlet,
                const SizedBox(height: 14),
                cardReward,
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Breakdown Rincian Depo / Area Penugasan
        _buildSalesBreakdownCard(context, state.breakdown, isAsm),
      ],
    );
  }

  // ---------------- WIDGET HELPERS ----------------

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subValue,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String footerText,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subValue,
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: context.colors.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(LucideIcons.info, size: 12, color: context.colors.textFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footerText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textFaint,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, List<dynamic> leaderboard) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trophy, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Leaderboard Personil Sales',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                'Top 10 Penugasan',
                style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada data target sales untuk periode ini', style: TextStyle(color: context.colors.textMuted)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 8,
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Nama Personil', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Posisi', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Target Kuota', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Target Outlet', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Wilayah', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: leaderboard.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final pos = (item['position'] ?? '-').toString();
                  final targetKg = (item['target_kg'] as num?)?.toDouble() ?? 0.0;
                  final targetOutlet = (item['target_outlet'] as num?)?.toInt() ?? 0;
                  final depoCount = (item['depo_count'] as num?)?.toInt() ?? 0;
                  final areaCount = (item['area_count'] as num?)?.toInt() ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: idx <= 3 ? AppColors.primary.withValues(alpha: 0.15) : context.colors.bgElevated,
                          child: Text(
                            '$idx',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: idx <= 3 ? AppColors.primary : context.colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['name'] ?? '-',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: context.colors.textPrimary, fontSize: 13),
                            ),
                            Text(
                              '@${item['username'] ?? '-'}',
                              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (pos == 'ASM' ? AppColors.primary : AppColors.petrol).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pos,
                            style: GoogleFonts.plusJakartaSans(
                              color: pos == 'ASM' ? AppColors.primary : AppColors.petrol,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(targetKg > 0 ? '${CurrencyFormatter.formatNumber(targetKg)} Kg' : '-')),
                      DataCell(Text(targetOutlet > 0 ? '${CurrencyFormatter.formatNumber(targetOutlet)} Toko' : '-')),
                      DataCell(Text(pos == 'ASM' ? '$depoCount Depo' : '$areaCount Area')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistributorCard(BuildContext context, List<dynamic> distributors) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Distributor Kuota',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              Icon(LucideIcons.building2, size: 18, color: context.colors.textMuted),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Distributor dengan alokasi target terbesar',
            style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (distributors.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada data distributor untuk periode ini', style: TextStyle(color: context.colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: distributors.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (context, idx) {
                final d = distributors[idx];
                final sellIn = (d['target_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
                final depoCount = (d['depos_count'] as num?)?.toInt() ?? 0;

                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.petrol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: AppColors.petrol,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['name'] ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${d['code'] ?? '-'} • $depoCount Depo',
                            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${CurrencyFormatter.formatNumber(sellIn)} Kg',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendCard(BuildContext context, List<dynamic> trend) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Alokasi Target Kuota (Multi-Periode)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perbandingan Kuota Sell-In Depo vs Sell-Out Area per Bulan',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: context.colors.textMuted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chartLegend('Sell-In (Kg)', AppColors.primary),
                  const SizedBox(width: 14),
                  _chartLegend('Sell-Out (Kg)', AppColors.petrol),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i >= 0 && i < trend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              trend[i]['period'].toString(),
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '${(val / 1000000).toStringAsFixed(1)}M',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textFaint,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: context.colors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: trend.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final sellIn = (item['target_sell_in'] as num?)?.toDouble() ?? 0.0;
                  final sellOut = (item['target_sell_out'] as num?)?.toDouble() ?? 0.0;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sellIn,
                        color: AppColors.primary,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: sellOut,
                        color: AppColors.petrol,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdownCard(BuildContext context, List<dynamic> breakdown, bool isAsm) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isAsm ? LucideIcons.building2 : LucideIcons.mapPin, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    isAsm ? 'Rincian Target Depo Penugasan' : 'Rincian Target Area & Toko Penugasan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${breakdown.length} Lokasi Terdaftar',
                style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada target penugasan yang tercatat untuk akun Anda pada periode ini',
                    style: TextStyle(color: context.colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: breakdown.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, idx) {
                final loc = breakdown[idx];
                final targetKg = (loc['target_quota_kg'] as num?)?.toDouble() ?? 0.0;
                final targetOutlet = (loc['target_outlet'] as num?)?.toInt() ?? 0;
                final brands = (loc['brands'] as List?) ?? [];

                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  collapsedIconColor: context.colors.textMuted,
                  iconColor: AppColors.primary,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isAsm ? AppColors.primary : AppColors.petrol).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAsm ? 'DEPO' : 'AREA',
                          style: GoogleFonts.plusJakartaSans(
                            color: isAsm ? AppColors.primary : AppColors.petrol,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loc['location_name']} (${loc['location_code']})',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              loc['distributor_name'] ?? '-',
                              style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (targetKg > 0)
                            Text(
                              '${CurrencyFormatter.formatNumber(targetKg)} Kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          if (targetOutlet > 0)
                            Text(
                              '${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: AppColors.petrol,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Column(
                        children: brands.map((b) {
                          final bQuota = (b['target_quota'] as num?)?.toDouble() ?? 0.0;
                          final bOutlet = (b['target_outlet'] as num?)?.toInt() ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: context.colors.bgSubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.tag, size: 14, color: AppColors.petrol),
                                const SizedBox(width: 8),
                                Text(
                                  b['brand_name'] ?? '-',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12.5),
                                ),
                                const Spacer(),
                                if (bQuota > 0)
                                  Text(
                                    '${CurrencyFormatter.formatNumber(bQuota)} Kg',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                if (bQuota > 0 && bOutlet > 0) const Text(' • '),
                                if (bOutlet > 0)
                                  Text(
                                    '$bOutlet Toko',
                                    style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Memuat ringkasan dashboard...',
              style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final isAuthError = message.contains('401') ||
        message.toLowerCase().contains('sesi') ||
        message.toLowerCase().contains('unauthorized');

    final isNetworkOrCorsError = message.contains('XMLHttpRequest') ||
        message.contains('cross-origin') ||
        message.toLowerCase().contains('connection errored');

    String displayMsg = message;
    if (isAuthError) {
      displayMsg = 'Sesi login Anda telah berakhir atau belum terotentikasi di server. Silakan masuk kembali.';
    } else if (isNetworkOrCorsError) {
      displayMsg = 'Koneksi ke backend (http://127.0.0.1:8000) sempat terputus saat request dikirim (Server Down / Reconnecting). Silakan klik tombol di bawah untuk memuat ulang data.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(LucideIcons.alertTriangle, size: 36, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            if (isAuthError)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.logIn, size: 16),
                label: const Text('Masuk Kembali (Login)'),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Coba Lagi'),
                onPressed: () => ref.read(dashboardProvider.notifier).fetchSummary(),
              ),
          ],
        ),
      ),
    );
  }
}

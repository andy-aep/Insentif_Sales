import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  ConsumerState<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  bool _showUnderperformingDist = false;
  String _trendMetric = 'SELL_IN'; // 'SELL_IN' | 'SELL_OUT'

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final dashState = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sticky Header & Multi-Period Filter Bar (crisp 1px hairline, zero shadow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            border: Border(bottom: BorderSide(color: context.colors.border)),
          ),
          child: _buildHeader(context, authUser, dashState),
        ),

        // Scrollable Dashboard Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
        ),
      ],
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader(BuildContext context, dynamic user, DashboardState state) {
    final isAdmin = state.mode == 'ADMIN';
    final canManage = state.user?['can_manage'] != false;
    final scopeLabel = (state.user?['scope_label'] ?? 'Nasional').toString();
    final userPos = (state.kpi['position'] ?? state.user?['position'] ?? user?.position?.code ?? '').toString().toUpperCase();
    final scheme = state.salesScheme.toUpperCase();
    final userName = user?.name ?? state.user?['name'] ?? (isAdmin ? 'Administrator' : 'Sales');

    String contextMeta = canManage
        ? 'Administrator • Cakupan $scopeLabel • $userName'
        : 'Eksekutif${userPos.isNotEmpty ? ' $userPos' : ''} • Cakupan $scopeLabel • $userName';
    String pageTitle = isAdmin ? 'Ringkasan Insentif & Distribusi' : 'Pencapaian Insentif Saya';

    if (!isAdmin) {
      if (scheme == 'INDUSTRI') {
        contextMeta = 'Sales Industri ($userPos) • $userName • Kuota Volume (Kg) & NOO';
      } else if (scheme == 'SURABAYA') {
        contextMeta = userPos == 'ASC'
            ? 'Koordinator Surabaya (ASC) • $userName • Evaluasi Tim TO & SM'
            : 'Sales Surabaya ($userPos) • $userName • Kuota Penjualan Langsung';
      } else {
        contextMeta = userPos == 'ASM'
            ? 'Sales Distributor (ASM) • $userName • Sell-In Depo'
            : 'Sales Distributor ($userPos) • $userName • Sell-Out Area & Active Outlet';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 860;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pageTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 18.5,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              contextMeta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              // Multi-Period Selector Button
              if (state.availablePeriods.isNotEmpty)
                Builder(
                  builder: (context) {
                    final selectedList = state.selectedPeriodsList;
                    final labelText = selectedList.length == 1
                        ? 'Periode: ${selectedList.first}'
                        : 'Periode: ${selectedList.length} Bulan (${selectedList.first}–${selectedList.last})';

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showMultiPeriodPickerDialog(context, ref, state),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.colors.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedList.length > 1 ? Theme.of(context).colorScheme.primary : context.colors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.calendar, size: 15, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              labelText,
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.chevronDown, size: 14, color: context.colors.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
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
                if (canManage)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(LucideIcons.uploadCloud, size: 15),
                    label: Text('Upload Data', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    onPressed: () => context.go('/bulk-upload'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    side: BorderSide(color: context.colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.calculator, size: 14),
                  label: Text('Lihat Insentif', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12.5)),
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
              const SizedBox(height: 12),
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
    );
  }

  // ---------------- ADMIN / EXECUTIVE DASHBOARD ----------------

  Widget _buildAdminDashboard(BuildContext context, DashboardState state) {
    final kpi = state.kpi;
    final scopeLabel = (state.user?['scope_label'] ?? 'Nasional').toString();
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
    final incentiveRatioPct = (kpi['incentive_ratio_pct'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Focal Point: Asymmetric Hero Budget Card + 3-Column Hairline Operational Ledger
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final cs = Theme.of(context).colorScheme;
            final sem = context.semantic;
            final colors = context.colors;

            final heroBudgetPanel = Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'ESTIMASI BUDGET INSENTIF',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.8,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        totalReward > 0 ? 'Terkalkulasi' : 'Menunggu',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: totalReward > 0 ? sem.success : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.formatRupiah(totalReward),
                      style: context.tabularNumStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$totalSales Sales • $totalDist Distributor ($scopeLabel)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        incentiveRatioPct > 0
                            ? 'Rasio ${incentiveRatioPct.toStringAsFixed(2)}%'
                            : 'Skema Aktif',
                        style: context.tabularNumStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            Widget buildLedgerMetric({
              required String label,
              required String primaryValue,
              required String secondaryLine,
              required double pct,
              required String footnote,
            }) {
              final Color statusColor = pct >= 100
                  ? sem.success
                  : (pct >= 80 ? cs.primary : (pct > 0 ? sem.warning : colors.textMuted));

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: context.tabularNumStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        primaryValue,
                        style: context.tabularNumStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      secondaryLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tabularNumStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.textFaint,
                      ),
                    ),
                  ],
                ),
              );
            }

            final sellInMetric = buildLedgerMetric(
              label: 'Sell-In (Depo / ASM)',
              primaryValue: '${CurrencyFormatter.formatNumber(realSellIn)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetSellIn)} Kg',
              pct: achSellIn,
              footnote: '$totalDist Distributor ($scopeLabel)',
            );

            final sellOutMetric = buildLedgerMetric(
              label: 'Sell-Out (Area / SPV)',
              primaryValue: '${CurrencyFormatter.formatNumber(realSellOut)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetSellOut)} Kg',
              pct: achSellOut,
              footnote: 'Konsumsi Multi-Brand',
            );

            final aoMetric = buildLedgerMetric(
              label: 'Active Outlet (AO)',
              primaryValue: '${CurrencyFormatter.formatNumber(realOutlet)} Toko',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
              pct: achOutlet,
              footnote: 'Cakupan Toko Ritel Area',
            );

            final operationalLedger = Container(
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: constraints.maxWidth >= 680
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: sellInMetric),
                          VerticalDivider(width: 1, thickness: 1, color: colors.border),
                          Expanded(child: sellOutMetric),
                          VerticalDivider(width: 1, thickness: 1, color: colors.border),
                          Expanded(child: aoMetric),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        sellInMetric,
                        Divider(height: 1, color: colors.border),
                        sellOutMetric,
                        Divider(height: 1, color: colors.border),
                        aoMetric,
                      ],
                    ),
            );

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: heroBudgetPanel),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 8, child: operationalLedger),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heroBudgetPanel,
                const SizedBox(height: AppSpacing.md),
                operationalLedger,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // Compact Precision Health Strip: Sell-Through, Omzet DPP, Rasio Insentif
        _buildExecutiveHealthStrip(context, kpi),
        const SizedBox(height: AppSpacing.xl),

        // Section: Sales Leaderboard & Performa Distributor (Sell-In + Watchlist)
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildLeaderboardCard(context, state.leaderboard)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _buildDistributorCard(
                      context,
                      state.distributors,
                      state.underperformingDistributors,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildLeaderboardCard(context, state.leaderboard),
                const SizedBox(height: 20),
                _buildDistributorCard(
                  context,
                  state.distributors,
                  state.underperformingDistributors,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Section: Performa per Region & Kontribusi per Brand (Executive Analytics)
        if (state.regionPerformance.isNotEmpty || state.brandPerformance.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildRegionPerformanceCard(context, state.regionPerformance),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildBrandPerformanceCard(context, state.brandPerformance),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildRegionPerformanceCard(context, state.regionPerformance),
                  const SizedBox(height: 20),
                  _buildBrandPerformanceCard(context, state.brandPerformance),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // Section: Tren Target vs Realisasi 6 Periode (Sell-In / Sell-Out)
        if (state.monthlyTrend.isNotEmpty) _buildMonthlyTrendCard(context, state.monthlyTrend),
      ],
    );
  }

  // ---------------- SALES DASHBOARD ----------------

  Widget _buildSalesDashboard(BuildContext context, DashboardState state) {
    final scheme = state.salesScheme.toUpperCase();
    if (scheme == 'INDUSTRI' && state.industriCard != null) {
      return _buildSalesIndustriDashboard(context, state, state.industriCard!);
    }
    if (scheme == 'SURABAYA' && state.surabayaCard != null) {
      return _buildSalesSurabayaDashboard(context, state, state.surabayaCard!);
    }

    final kpi = state.kpi;
    final posCode = (kpi['position'] ?? 'SALES').toString().toUpperCase();
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
    final gradeBadge = grade == '-'
        ? 'Menunggu'
        : (grade.toLowerCase().startsWith('grade') ? grade : 'Grade $grade');
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
                    badgeColor: achSellIn >= 100 ? context.semantic.success : Theme.of(context).colorScheme.primary,
                    icon: LucideIcons.truck,
                    footerText: '$assignedDepos Depo di Bawah Tanggung Jawab',
                    progress: (achSellIn / 100).clamp(0.0, 1.0),
                  )
                : _buildKpiCard(
                    title: 'Target Sell-Out Area Saya',
                    value: '${CurrencyFormatter.formatNumber(myTargetSellOut)} Kg',
                    subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realSellOut)} Kg',
                    badgeText: '${achSellOut.toStringAsFixed(1)}%',
                    badgeColor: achSellOut >= 100 ? context.semantic.success : Theme.of(context).colorScheme.primary,
                    icon: LucideIcons.shoppingBag,
                    footerText: '$assignedAreas Area di Bawah Tanggung Jawab',
                    progress: (achSellOut / 100).clamp(0.0, 1.0),
                  );

            final cardOutlet = isAsm
                ? _buildKpiCard(
                    title: 'Depo Penugasan Aktif',
                    value: '$assignedDepos Depo',
                    subValue: 'Distributor ASM Area Kerja',
                    badgeText: 'ASM Konsumsi',
                    badgeColor: context.semantic.secondaryAccent,
                    icon: LucideIcons.mapPin,
                    footerText: 'Tingkat Depo Konsumsi',
                    progress: 1.0,
                  )
                : _buildKpiCard(
                    title: 'Target Active Outlet (AO)',
                    value: '${CurrencyFormatter.formatNumber(myTargetOutlet)} Toko',
                    subValue: 'Realisasi: ${CurrencyFormatter.formatNumber(realOutlet)} Toko',
                    badgeText: '${achOutlet.toStringAsFixed(1)}%',
                    badgeColor: achOutlet >= 100 ? context.semantic.success : Theme.of(context).colorScheme.primary,
                    icon: LucideIcons.store,
                    footerText: 'Target Sebaran Toko Aktif',
                    progress: (achOutlet / 100).clamp(0.0, 1.0),
                  );

            final cardReward = _buildKpiCard(
              title: 'Estimasi Insentif Saya',
              value: CurrencyFormatter.formatRupiah(estimatedReward),
              subValue: grade != '-' ? '$gradeBadge (${overallAch.toStringAsFixed(1)}%)' : 'Belum Ada Kalkulasi',
              badgeText: gradeBadge,
              badgeColor: estimatedReward > 0 ? context.semantic.success : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildSalesIndustriDashboard(
    BuildContext context,
    DashboardState state,
    Map<String, dynamic> card,
  ) {
    final posCode = (card['position_code'] ?? state.kpi['position'] ?? 'SPV').toString().toUpperCase();
    final sellIn = (card['sell_in'] as Map<String, dynamic>?) ?? {};
    final noo = (card['noo'] as Map<String, dynamic>?) ?? {};
    final customers = (card['customers'] as List?) ?? [];

    final sellInTarget = (sellIn['target_quota'] as num?)?.toDouble() ?? 0.0;
    final sellInActual = (sellIn['actual_realization'] as num?)?.toDouble() ?? 0.0;
    final sellInAch = (sellIn['achievement_percent'] as num?)?.toDouble() ?? 0.0;
    final sellInMinAch = (sellIn['min_achievement_pct'] as num?)?.toDouble() ?? 80.0;
    final sellInPassed = sellIn['is_passed'] == true || sellIn['is_passed'] == 1;
    final sellInGrade = (sellIn['grade_name'] ?? '-').toString();
    final sellInRate = (sellIn['multiplier_rate'] as num?)?.toDouble() ?? 0.0;
    final sellInWeight = (sellIn['header_weight_pct'] as num?)?.toDouble() ?? 70.0;
    final sellInReward = (sellIn['final_reward'] as num?)?.toDouble() ?? 0.0;

    final nooTarget = (noo['target_quota'] as num?)?.toInt() ?? 0;
    final nooActual = (noo['actual_realization'] as num?)?.toInt() ?? 0;
    final nooVolumeKg = (noo['actual_volume_kg'] as num?)?.toDouble() ?? 0.0;
    final nooAch = (noo['achievement_percent'] as num?)?.toDouble() ?? 0.0;
    final nooMinAch = (noo['min_achievement_pct'] as num?)?.toDouble() ?? 50.0;
    final nooPassed = noo['is_passed'] == true || noo['is_passed'] == 1;
    final nooGrade = (noo['grade_name'] ?? '-').toString();
    final nooRate = (noo['multiplier_rate'] as num?)?.toDouble() ?? 0.0;
    final nooWeight = (noo['header_weight_pct'] as num?)?.toDouble() ?? 30.0;
    final nooReward = (noo['final_reward'] as num?)?.toDouble() ?? 0.0;

    final totalReward = (card['total_reward'] as num?)?.toDouble() ?? (sellInReward + nooReward);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;

            final cardSellIn = _buildKpiCard(
              title: 'Pencapaian Sell-In Industri (Bobot ${sellInWeight.toStringAsFixed(0)}%)',
              value: '${CurrencyFormatter.formatNumber(sellInActual)} / ${CurrencyFormatter.formatNumber(sellInTarget)} Kg',
              subValue:
                  'Min Ach: ${sellInMinAch.toStringAsFixed(0)}% • Tarif: Rp ${CurrencyFormatter.formatNumber(sellInRate)}/Kg',
              badgeText: '${sellInAch.toStringAsFixed(1)}% (${sellInPassed ? "Lolos" : "Tidak Lolos"})',
              badgeColor: sellInPassed ? context.semantic.success : context.semantic.danger,
              icon: LucideIcons.factory,
              footerText: 'Insentif Sell-In: ${CurrencyFormatter.formatRupiah(sellInReward)} • $sellInGrade',
              progress: (sellInAch / 100).clamp(0.0, 1.0),
            );

            final cardNoo = _buildKpiCard(
              title: 'Pencapaian NOO / Customer Baru (Bobot ${nooWeight.toStringAsFixed(0)}%)',
              value: '$nooActual / $nooTarget Customer NOO',
              subValue:
                  'Volume NOO: ${CurrencyFormatter.formatNumber(nooVolumeKg)} Kg • Tarif: Rp ${CurrencyFormatter.formatNumber(nooRate)}/Kg',
              badgeText: '${nooAch.toStringAsFixed(1)}% (${nooPassed ? "Lolos" : "Tidak Lolos"})',
              badgeColor: nooPassed ? context.semantic.success : context.semantic.danger,
              icon: LucideIcons.userPlus,
              footerText: 'Insentif NOO: ${CurrencyFormatter.formatRupiah(nooReward)} • $nooGrade',
              progress: (nooAch / 100).clamp(0.0, 1.0),
            );

            final cardTotal = _buildKpiCard(
              title: 'Total Insentif Sales Industri Saya',
              value: CurrencyFormatter.formatRupiah(totalReward),
              subValue:
                  'Sell-In: ${CurrencyFormatter.formatRupiah(sellInReward)} + NOO: ${CurrencyFormatter.formatRupiah(nooReward)}',
              badgeText: 'Posisi $posCode',
              badgeColor: totalReward > 0 ? context.semantic.success : Theme.of(context).colorScheme.onSurfaceVariant,
              icon: LucideIcons.award,
              footerText: 'Periode ${state.selectedPeriod} • ${customers.length} Customer Industri',
              progress: totalReward > 0 ? 1.0 : 0.0,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: cardSellIn),
                  const SizedBox(width: 16),
                  Expanded(child: cardNoo),
                  const SizedBox(width: 16),
                  Expanded(child: cardTotal),
                ],
              );
            }

            return Column(
              children: [
                cardSellIn,
                const SizedBox(height: 14),
                cardNoo,
                const SizedBox(height: 14),
                cardTotal,
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Rincian Rumus Perhitungan Industri
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
            boxShadow: context.colors.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.calculator, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rincian Perhitungan Insentif Sales Industri ($posCode)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _buildFormulaBox(
                    context,
                    title: '1. Komponen Sell-In (${sellInWeight.toStringAsFixed(0)}%)',
                    formula: sellInPassed
                        ? '${CurrencyFormatter.formatNumber(sellInActual)} Kg × Rp ${CurrencyFormatter.formatNumber(sellInRate)} × ${sellInWeight.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(sellInReward)}'
                        : 'Tidak lolos syarat Min Ach ${sellInMinAch.toStringAsFixed(0)}% (Capai ${sellInAch.toStringAsFixed(1)}%) → Rp 0',
                    passed: sellInPassed,
                    grade: sellInGrade,
                  ),
                  _buildFormulaBox(
                    context,
                    title: '2. Komponen NOO / New Open Outlet (${nooWeight.toStringAsFixed(0)}%)',
                    formula: nooPassed
                        ? '${CurrencyFormatter.formatNumber(nooVolumeKg)} Kg (Vol NOO) × Rp ${CurrencyFormatter.formatNumber(nooRate)} × ${nooWeight.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(nooReward)}'
                        : 'Tidak lolos syarat Min Ach ${nooMinAch.toStringAsFixed(0)}% atau 0 NOO (Capai ${nooAch.toStringAsFixed(1)}%) → Rp 0',
                    passed: nooPassed,
                    grade: nooGrade,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Rincian Customer Industri & Status NOO
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
            boxShadow: context.colors.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(LucideIcons.building2, color: context.semantic.secondaryAccent, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Rincian Customer Industri & Evaluasi Status NOO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${customers.length} Customer',
                    style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (customers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi customer industri pada periode ini',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, idx) {
                    final c = customers[idx] as Map<String, dynamic>;
                    final isNoo = c['is_noo'] == true;
                    final volKg = (c['volume_kg'] as num?)?.toDouble() ?? 0.0;
                    final custType = (c['customer_type'] ?? 'EXISTING').toString().toUpperCase();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isNoo ? context.semantic.success : Theme.of(context).colorScheme.onSurfaceVariant).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isNoo ? 'NOO VALID' : custType,
                            style: GoogleFonts.plusJakartaSans(
                              color: isNoo ? context.semantic.success : context.colors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c['customer_name'] ?? '-'} (${c['customer_code'] ?? '-'})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kota: ${c['city'] ?? '-'} • ${c['noo_reason'] ?? '-'}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.colors.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${CurrencyFormatter.formatNumber(volKg)} Kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isNoo ? context.semantic.success : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              isNoo ? 'Dihitung Sell-In & NOO' : 'Dihitung Sell-In',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesSurabayaDashboard(
    BuildContext context,
    DashboardState state,
    Map<String, dynamic> card,
  ) {
    final posCode = (card['position_code'] ?? state.kpi['position'] ?? 'TO').toString().toUpperCase();
    final isAsc = posCode == 'ASC';
    final targetKg = (card['target_kg'] as num?)?.toDouble() ?? 0.0;
    final actualKg = (card['actual_kg'] as num?)?.toDouble() ?? 0.0;
    final achPct = (card['achievement_percent'] as num?)?.toDouble() ?? 0.0;
    final minAchPct = (card['min_achievement_pct'] as num?)?.toDouble() ?? 80.0;
    final passed = card['is_passed'] == true || card['is_passed'] == 1;
    final gradeName = (card['grade_name'] ?? '-').toString();
    final rate = (card['multiplier_rate'] as num?)?.toDouble() ?? 0.0;
    final headerWeightPct = (card['header_weight_pct'] as num?)?.toDouble() ?? 100.0;
    final totalReward = (card['total_reward'] as num?)?.toDouble() ?? 0.0;
    final ascName = (card['asc_name'] ?? '-').toString();
    final subordinates = (card['subordinates'] as List?) ?? [];

    final achievedSubCount = subordinates
        .where((s) => (s as Map)['is_passed'] == true || s['is_passed'] == 1)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;

            final Widget card1 = isAsc
                ? _buildKpiCard(
                    title: 'Tim Bawahan Surabaya (TO & SM)',
                    value: '${subordinates.length} Sales Bawahan',
                    subValue: '$achievedSubCount dari ${subordinates.length} Bawahan Mencapai Target',
                    badgeText: 'Koordinator ASC',
                    badgeColor: context.semantic.secondaryAccent,
                    icon: LucideIcons.users,
                    footerText: 'Evaluasi Individu Per Bawahan (TO & SM)',
                    progress: subordinates.isEmpty ? 0.0 : (achievedSubCount / subordinates.length).clamp(0.0, 1.0),
                  )
                : _buildKpiCard(
                    title: 'Target Penjualan Surabaya ($posCode)',
                    value: '${CurrencyFormatter.formatNumber(targetKg)} Kg',
                    subValue: 'Syarat Pencapaian Minimum: ${minAchPct.toStringAsFixed(0)}%',
                    badgeText: 'Posisi $posCode',
                    badgeColor: context.semantic.secondaryAccent,
                    icon: LucideIcons.target,
                    footerText: 'Koordinator ASC: $ascName',
                    progress: 1.0,
                  );

            final Widget card2 = _buildKpiCard(
              title: isAsc ? 'Total Realisasi vs Target Tim Bawahan' : 'Realisasi Penjualan Langsung Saya',
              value: '${CurrencyFormatter.formatNumber(actualKg)} Kg',
              subValue: isAsc
                  ? 'Target Tim: ${CurrencyFormatter.formatNumber(targetKg)} Kg'
                  : 'Target Saya: ${CurrencyFormatter.formatNumber(targetKg)} Kg ($gradeName)',
              badgeText: '${achPct.toStringAsFixed(1)}% (${passed ? "Lolos" : "Tidak Lolos"})',
              badgeColor: passed ? context.semantic.success : context.semantic.danger,
              icon: LucideIcons.trendingUp,
              footerText: isAsc
                  ? 'Akumulasi Tonase Bawahan TO & SM'
                  : 'Tarif Grade: Rp ${CurrencyFormatter.formatNumber(rate)}/Kg',
              progress: (achPct / 100).clamp(0.0, 1.0),
            );

            final Widget card3 = _buildKpiCard(
              title: isAsc ? 'Grand Total Insentif ASC' : 'Total Insentif Surabaya Saya',
              value: CurrencyFormatter.formatRupiah(totalReward),
              subValue: isAsc
                  ? 'Akumulasi Kontribusi Bawahan Lolos Target'
                  : 'Rumus: ${CurrencyFormatter.formatNumber(actualKg)} Kg × Rp ${CurrencyFormatter.formatNumber(rate)} × ${headerWeightPct.toStringAsFixed(0)}%',
              badgeText: 'Periode ${state.selectedPeriod}',
              badgeColor: totalReward > 0 ? context.semantic.success : Theme.of(context).colorScheme.onSurfaceVariant,
              icon: LucideIcons.award,
              footerText: isAsc ? 'Skema Koordinator ASC Surabaya' : 'Skema Penjualan Langsung ($posCode)',
              progress: totalReward > 0 ? 1.0 : 0.0,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 16),
                  Expanded(child: card2),
                  const SizedBox(width: 16),
                  Expanded(child: card3),
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
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        if (isAsc)
          _buildSurabayaAscBreakdownCard(context, subordinates, totalReward)
        else
          _buildSurabayaIndividualBreakdownCard(
            context,
            posCode: posCode,
            ascName: ascName,
            targetKg: targetKg,
            actualKg: actualKg,
            achPct: achPct,
            minAchPct: minAchPct,
            passed: passed,
            gradeName: gradeName,
            rate: rate,
            headerWeightPct: headerWeightPct,
            totalReward: totalReward,
          ),
      ],
    );
  }

  Widget _buildFormulaBox(
    BuildContext context, {
    required String title,
    required String formula,
    required bool passed,
    required String grade,
  }) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (passed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                grade,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: passed ? context.semantic.success : context.colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formula,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: passed ? Theme.of(context).colorScheme.primary : context.semantic.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurabayaAscBreakdownCard(
    BuildContext context,
    List<dynamic> subordinates,
    double totalReward,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.table, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Breakdown Evaluasi Bawahan Surabaya (TO & SM) — Koordinator ASC',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (subordinates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada bawahan TO / SM yang terhubung pada periode ini',
                  style: TextStyle(color: context.colors.textMuted),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 58,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Nama Bawahan')),
                  DataColumn(label: Text('Posisi')),
                  DataColumn(label: Text('Target (Kg)')),
                  DataColumn(label: Text('Aktual (Kg)')),
                  DataColumn(label: Text('% Capai')),
                  DataColumn(label: Text('Status Target')),
                  DataColumn(label: Text('Grade ASC')),
                  DataColumn(label: Text('Bobot Header')),
                  DataColumn(label: Text('Kontribusi Insentif ASC')),
                ],
                rows: [
                  ...subordinates.map((raw) {
                    final s = raw as Map<String, dynamic>;
                    final passed = s['is_passed'] == true || s['is_passed'] == 1;
                    final tKg = (s['target_kg'] as num?)?.toDouble() ?? 0.0;
                    final aKg = (s['actual_kg'] as num?)?.toDouble() ?? 0.0;
                    final ach = (s['achievement_percent'] as num?)?.toDouble() ?? 0.0;
                    final rate = (s['multiplier_rate'] as num?)?.toDouble() ?? 0.0;
                    final wHdr = (s['header_weight_pct'] as num?)?.toDouble() ?? 100.0;
                    final contrib = (s['contribution_reward'] as num?)?.toDouble() ?? 0.0;

                    return DataRow(
                      cells: [
                        DataCell(Text(
                          (s['sales_name'] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text((s['position_code'] ?? '-').toString())),
                        DataCell(Text(CurrencyFormatter.formatNumber(tKg))),
                        DataCell(Text(CurrencyFormatter.formatNumber(aKg))),
                        DataCell(Text('${ach.toStringAsFixed(1)}%')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (passed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (s['status_label'] ?? (passed ? 'Mencapai Target' : 'Tidak Mencapai Target')).toString(),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: passed ? context.semantic.success : context.semantic.danger,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                          passed
                              ? '${s['grade_name'] ?? '-'} (Rp ${CurrencyFormatter.formatNumber(rate)}/Kg)'
                              : '-',
                        )),
                        DataCell(Text(passed ? '${wHdr.toStringAsFixed(0)}%' : '-')),
                        DataCell(Text(
                          CurrencyFormatter.formatRupiah(contrib),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: contrib > 0 ? context.semantic.success : context.colors.textMuted,
                          ),
                        )),
                      ],
                    );
                  }),
                  DataRow(
                    cells: [
                      const DataCell(Text(
                        'GRAND TOTAL INSENTIF ASC',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      )),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      DataCell(Text(
                        CurrencyFormatter.formatRupiah(totalReward),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSurabayaIndividualBreakdownCard(
    BuildContext context, {
    required String posCode,
    required String ascName,
    required double targetKg,
    required double actualKg,
    required double achPct,
    required double minAchPct,
    required bool passed,
    required String gradeName,
    required double rate,
    required double headerWeightPct,
    required double totalReward,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calculator, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rincian Perhitungan Insentif Individu Surabaya ($posCode)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFormulaBox(
            context,
            title: 'Rumus Perhitungan Insentif Penjualan Langsung ($posCode • Atasan ASC: $ascName)',
            formula: passed
                ? '${CurrencyFormatter.formatNumber(actualKg)} Kg (Aktual) × Rp ${CurrencyFormatter.formatNumber(rate)}/Kg ($gradeName) × ${headerWeightPct.toStringAsFixed(0)}% (Bobot Header) = ${CurrencyFormatter.formatRupiah(totalReward)}'
                : 'Capai ${achPct.toStringAsFixed(1)}% < Min Ach ${minAchPct.toStringAsFixed(0)}% (Tidak Mencapai Target) → Rp 0',
            passed: passed,
            grade: gradeName,
          ),
        ],
      ),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.textMuted, size: 15),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tabularNumStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.tabularNumStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tabularNumStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: colors.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            footerText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiPeriodPickerDialog(BuildContext context, WidgetRef ref, DashboardState state) {
    final colors = context.colors;
    final selected = Set<String>.from(state.selectedPeriodsList);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.border),
            ),
            title: Row(
              children: [
                Icon(LucideIcons.calendar, size: 19, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih Periode Dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (selected.length == state.availablePeriods.length) {
                        selected
                          ..clear()
                          ..add(state.availablePeriods.first);
                      } else {
                        selected
                          ..clear()
                          ..addAll(state.availablePeriods);
                      }
                    });
                  },
                  child: Text(
                    selected.length == state.availablePeriods.length ? 'Reset 1 Bulan' : 'Pilih Semua',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: state.availablePeriods.map((p) {
                    final isChecked = selected.contains(p);
                    return CheckboxListTile(
                      dense: true,
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: isChecked,
                      title: Text(
                        p,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textPrimary,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selected.add(p);
                          } else if (selected.length > 1) {
                            selected.remove(p);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: colors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final sorted = selected.toList()..sort();
                  Navigator.pop(ctx);
                  ref.read(dashboardProvider.notifier).changePeriod(sorted.join(','));
                },
                child: Text(
                  'Terapkan (${selected.length} Periode)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricAchievementCell(
    BuildContext context, {
    required double realVal,
    required double targetVal,
    required double pct,
    required String unit,
  }) {
    final colors = context.colors;
    if (targetVal <= 0 && realVal <= 0) {
      return Text('-', style: TextStyle(color: colors.textMuted, fontSize: 12));
    }

    final Color badgeColor = pct >= 100
        ? context.semantic.success
        : (pct >= 80 ? context.semantic.warning : context.semantic.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${CurrencyFormatter.formatNumber(realVal)} / ${CurrencyFormatter.formatNumber(targetVal)} $unit',
          style: context.tabularNumStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.tag),
          ),
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            style: context.tabularNumStyle(
              color: badgeColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, List<dynamic> leaderboard) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
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
                  Icon(LucideIcons.trophy, color: Theme.of(context).colorScheme.primary, size: 20),
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
                'Top ${leaderboard.length} Penugasan',
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
                columnSpacing: 12,
                horizontalMargin: 6,
                headingRowHeight: 40,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 62,
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Personil & Wilayah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Sell-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Sell-Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('AO (Toko)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: leaderboard.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final pos = (item['position'] ?? '-').toString();
                  final targetSi = (item['target_sell_in'] as num?)?.toDouble() ?? 0.0;
                  final realSi = (item['real_sell_in'] as num?)?.toDouble() ?? 0.0;
                  final achSi = (item['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;
                  final targetSo = (item['target_sell_out'] as num?)?.toDouble() ?? 0.0;
                  final realSo = (item['real_sell_out'] as num?)?.toDouble() ?? 0.0;
                  final achSo = (item['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                  final targetAo = (item['target_ao'] as num?)?.toDouble() ??
                      (item['target_outlet'] as num?)?.toDouble() ??
                      0.0;
                  final realAo = (item['real_ao'] as num?)?.toDouble() ?? 0.0;
                  final achAo = (item['ach_ao_pct'] as num?)?.toDouble() ?? 0.0;
                  final depoCount = (item['depo_count'] as num?)?.toInt() ?? 0;
                  final areaCount = (item['area_count'] as num?)?.toInt() ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: idx <= 3 ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : context.colors.bgElevated,
                          child: Text(
                            '$idx',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: idx <= 3 ? Theme.of(context).colorScheme.primary : context.colors.textMuted,
                            ),
                          ),
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
                                  item['name'] ?? '-',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: context.colors.textPrimary, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (pos == 'ASM' ? Theme.of(context).colorScheme.primary : context.semantic.secondaryAccent).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pos,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: pos == 'ASM' ? Theme.of(context).colorScheme.primary : context.semantic.secondaryAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${item['username'] ?? '-'} • ${pos == 'ASM' ? '$depoCount Depo' : '$areaCount Area'}',
                              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        _buildMetricAchievementCell(
                          context,
                          realVal: realSi,
                          targetVal: targetSi,
                          pct: achSi,
                          unit: 'Kg',
                        ),
                      ),
                      DataCell(
                        _buildMetricAchievementCell(
                          context,
                          realVal: realSo,
                          targetVal: targetSo,
                          pct: achSo,
                          unit: 'Kg',
                        ),
                      ),
                      DataCell(
                        _buildMetricAchievementCell(
                          context,
                          realVal: realAo,
                          targetVal: targetAo,
                          pct: achAo,
                          unit: 'Toko',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _achColor(double pct) {
    if (pct >= 100) return context.semantic.success;
    if (pct >= 80) return context.semantic.warning;
    return context.semantic.danger;
  }

  String _formatCompactKg(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(2)} Jt Kg';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)} Rb Kg';
    return '${CurrencyFormatter.formatNumber(val)} Kg';
  }

  String _formatCompactAxis(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toStringAsFixed(0);
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final color = activeColor ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : context.colors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : context.colors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveHealthStrip(BuildContext context, Map<String, dynamic> kpi) {
    final realSellIn = (kpi['realisasi_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
    final realSellOut = (kpi['realisasi_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
    final sellThroughPct = (kpi['sell_through_pct'] as num?)?.toDouble() ?? 0.0;
    final totalDppSellIn = (kpi['total_dpp_sell_in'] as num?)?.toDouble() ?? 0.0;
    final totalDppSellOut = (kpi['total_dpp_sell_out'] as num?)?.toDouble() ?? 0.0;
    final totalReward = (kpi['total_incentive_pool'] as num?)?.toDouble() ?? 0.0;
    final incentiveRatioPct = (kpi['incentive_ratio_pct'] as num?)?.toDouble() ?? 0.0;

    final String stBadge;
    final Color stColor;
    if (realSellIn <= 0) {
      stBadge = 'Menunggu Realisasi';
      stColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (sellThroughPct >= 85) {
      stBadge = 'Stok Lancar';
      stColor = context.semantic.success;
    } else if (sellThroughPct >= 65) {
      stBadge = 'Moderat';
      stColor = context.semantic.warning;
    } else {
      stBadge = 'Stok Menumpuk';
      stColor = context.semantic.danger;
    }

    final double displayOmzet = totalDppSellOut > 0 ? totalDppSellOut : totalDppSellIn;
    final String omzetBadge = totalDppSellOut > 0 ? 'DPP Sell-Out' : 'DPP Sell-In';

    final String ratioBadge = incentiveRatioPct <= 0
        ? 'Belum Dihitung'
        : (incentiveRatioPct <= 3.0 ? 'Efisien' : 'Perlu Pantau');
    final Color ratioColor = incentiveRatioPct <= 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (incentiveRatioPct <= 3.0 ? context.semantic.success : context.semantic.warning);

    Widget buildStripCell({
      required Color statusColor,
      required String label,
      required String value,
      required String badge,
      required String caption,
    }) {
      final colors = context.colors;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tabularNumStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final cell1 = buildStripCell(
      statusColor: stColor,
      label: 'Sell-Through (SO ÷ SI)',
      value: '${sellThroughPct.toStringAsFixed(1)}%',
      badge: stBadge,
      caption: 'SO ${_formatCompactKg(realSellOut)} vs SI ${_formatCompactKg(realSellIn)}',
    );

    final cell2 = buildStripCell(
      statusColor: Theme.of(context).colorScheme.primary,
      label: 'Total Omzet Penjualan',
      value: CurrencyFormatter.formatRupiah(displayOmzet),
      badge: omzetBadge,
      caption: totalDppSellOut > 0
          ? 'DPP Sell-In: ${CurrencyFormatter.formatRupiah(totalDppSellIn)}'
          : 'Akumulasi nominal transaksi periode terpilih',
    );

    final cell3 = buildStripCell(
      statusColor: ratioColor,
      label: 'Rasio Insentif / Omzet',
      value: '${incentiveRatioPct.toStringAsFixed(2)}%',
      badge: ratioBadge,
      caption: 'Budget ${CurrencyFormatter.formatRupiah(totalReward)} dari Omzet Sell-Out',
    );

    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cell1),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  Expanded(child: cell2),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  Expanded(child: cell3),
                ],
              ),
            );
          }
          return Column(
            children: [
              cell1,
              Divider(height: 1, color: colors.border),
              cell2,
              Divider(height: 1, color: colors.border),
              cell3,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDistributorCard(
    BuildContext context,
    List<dynamic> topDistributors,
    List<dynamic> underperformingDistributors,
  ) {
    final activeList = _showUnderperformingDist ? underperformingDistributors : topDistributors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showUnderperformingDist ? 'Distributor Perlu Perhatian' : 'Top Distributor (Sell-In)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _showUnderperformingDist
                          ? 'Capaian Sell-In < 80% pada periode terpilih'
                          : 'Pencapaian Sell-In (Real / Target) mengikuti periode terpilih',
                      style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(
                _showUnderperformingDist ? LucideIcons.alertTriangle : LucideIcons.building2,
                size: 18,
                color: _showUnderperformingDist ? context.semantic.danger : context.colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildToggleChip(
                label: 'Top Pencapaian',
                isSelected: !_showUnderperformingDist,
                onTap: () => setState(() => _showUnderperformingDist = false),
              ),
              _buildToggleChip(
                label: 'Perlu Perhatian (<80%)${underperformingDistributors.isNotEmpty ? ' (${underperformingDistributors.length})' : ''}',
                isSelected: _showUnderperformingDist,
                activeColor: context.semantic.danger,
                onTap: () => setState(() => _showUnderperformingDist = true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activeList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      _showUnderperformingDist ? LucideIcons.checkCircle2 : LucideIcons.inbox,
                      size: 28,
                      color: _showUnderperformingDist ? context.semantic.success : context.colors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showUnderperformingDist
                          ? 'Tidak ada distributor di bawah 80% untuk periode ini'
                          : 'Belum ada data distributor untuk periode ini',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final d = activeList[idx];
                final targetSi = (d['target_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
                final realSi = (d['real_sell_in_kg'] as num?)?.toDouble() ?? 0.0;
                final achSiPct = (d['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;
                final achSoPct = (d['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                final targetSo = (d['target_sell_out_kg'] as num?)?.toDouble() ?? 0.0;
                final depoCount = (d['depos_count'] as num?)?.toInt() ?? 0;
                final regionName = (d['region_name'] ?? '').toString();
                final pctColor = targetSi > 0 ? _achColor(achSiPct) : Theme.of(context).colorScheme.onSurfaceVariant;
                final rankColor = _showUnderperformingDist ? context.semantic.danger : context.semantic.secondaryAccent;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: rankColor,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                  fontSize: 12.8,
                                ),
                              ),
                              Text(
                                '${d['code'] ?? '-'}${regionName.isNotEmpty && regionName != 'Lainnya' ? ' • $regionName' : ''} • $depoCount Depo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pctColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${achSiPct.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: pctColor,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (achSiPct / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: context.colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Sell-In: ${CurrencyFormatter.formatNumber(realSi)} / ${CurrencyFormatter.formatNumber(targetSi)} Kg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        if (targetSo > 0)
                          Text(
                            'SO ${achSoPct.toStringAsFixed(0)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRegionPerformanceCard(BuildContext context, List<dynamic> regions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.map, size: 18, color: context.semantic.secondaryAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performa per Region',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Perbandingan Sell-In, Sell-Out, AO (Toko), dan Sell-Through tiap wilayah',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (regions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada data region untuk periode ini', style: TextStyle(color: context.colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: regions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final r = regions[idx];
                final regName = (r['region_name'] ?? '-').toString();
                final distCount = (r['distributor_count'] as num?)?.toInt() ?? 0;
                final targetSi = (r['target_sell_in'] as num?)?.toDouble() ?? 0.0;
                final realSi = (r['real_sell_in'] as num?)?.toDouble() ?? 0.0;
                final achSi = (r['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;
                final targetSo = (r['target_sell_out'] as num?)?.toDouble() ?? 0.0;
                final realSo = (r['real_sell_out'] as num?)?.toDouble() ?? 0.0;
                final achSo = (r['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                final targetAo = (r['target_ao'] as num?)?.toInt() ?? 0;
                final realAo = (r['real_ao'] as num?)?.toInt() ?? 0;
                final achAo = (r['ach_ao_pct'] as num?)?.toDouble() ?? 0.0;
                final stPct = (r['sell_through_pct'] as num?)?.toDouble() ?? 0.0;

                Widget miniMetric(String label, double pct, String detail) {
                  final color = _achColor(pct);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMuted,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: context.colors.bgCard,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: context.colors.bgSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    regName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$distCount Dist',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: context.colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.semantic.secondaryAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sell-Through ${stPct.toStringAsFixed(1)}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.semantic.secondaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: miniMetric(
                              'Sell-In',
                              achSi,
                              '${_formatCompactKg(realSi)} / ${_formatCompactKg(targetSi)}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: miniMetric(
                              'Sell-Out',
                              achSo,
                              '${_formatCompactKg(realSo)} / ${_formatCompactKg(targetSo)}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: miniMetric(
                              'AO (Toko)',
                              achAo,
                              '${CurrencyFormatter.formatNumber(realAo)} / ${CurrencyFormatter.formatNumber(targetAo)} Toko',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBrandPerformanceCard(BuildContext context, List<dynamic> brands) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.tag, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performa & Kontribusi Brand',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Pencapaian Sell-In, Sell-Out & porsi kontribusi (% Share)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (brands.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Belum ada data brand untuk periode ini', style: TextStyle(color: context.colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: brands.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final b = brands[idx];
                final name = (b['brand_name'] ?? '-').toString();
                final targetSi = (b['target_sell_in'] as num?)?.toDouble() ?? 0.0;
                final realSi = (b['real_sell_in'] as num?)?.toDouble() ?? 0.0;
                final achSi = (b['ach_sell_in_pct'] as num?)?.toDouble() ?? 0.0;
                final targetSo = (b['target_sell_out'] as num?)?.toDouble() ?? 0.0;
                final realSo = (b['real_sell_out'] as num?)?.toDouble() ?? 0.0;
                final achSo = (b['ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                final shareSi = (b['share_sell_in_pct'] as num?)?.toDouble() ?? 0.0;
                final color = targetSi > 0 ? _achColor(achSi) : Theme.of(context).colorScheme.onSurfaceVariant;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.semantic.secondaryAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Share ${shareSi.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: context.semantic.secondaryAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${achSi.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (achSi / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: context.colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SI: ${_formatCompactKg(realSi)} / ${_formatCompactKg(targetSi)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                        if (targetSo > 0 || realSo > 0)
                          Text(
                            'SO: ${_formatCompactKg(realSo)} (${achSo.toStringAsFixed(0)}%)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: context.colors.textMuted,
                            ),
                          ),
                      ],
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
    final isSellIn = _trendMetric == 'SELL_IN';
    final realColor = isSellIn ? Theme.of(context).colorScheme.primary : context.semantic.secondaryAccent;
    final targetColor = Theme.of(context).colorScheme.outline;

    double maxVal = 0.0;
    for (final item in trend) {
      final t = (item[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0.0;
      final r = (item[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0.0;
      if (t > maxVal) maxVal = t;
      if (r > maxVal) maxVal = r;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Target vs Realisasi (6 Periode)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSellIn
                        ? 'Perbandingan Target vs Realisasi Sell-In Depo per Bulan (Kg)'
                        : 'Perbandingan Target vs Realisasi Sell-Out Area per Bulan (Kg)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: context.colors.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chartLegend('Target (Kg)', targetColor),
                  _chartLegend('Realisasi (Kg)', realColor),
                  const SizedBox(width: 4),
                  _buildToggleChip(
                    label: 'Sell-In',
                    isSelected: isSellIn,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onTap: () => setState(() => _trendMetric = 'SELL_IN'),
                  ),
                  _buildToggleChip(
                    label: 'Sell-Out',
                    isSelected: !isSellIn,
                    activeColor: context.semantic.secondaryAccent,
                    onTap: () => setState(() => _trendMetric = 'SELL_OUT'),
                  ),
                ],
              ),
            ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.15 : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = trend[groupIndex];
                      final period = item['period'].toString();
                      final tVal = (item[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0.0;
                      final rVal = (item[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0.0;
                      final pct = (item[isSellIn ? 'ach_sell_in_pct' : 'ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                      return BarTooltipItem(
                        '$period (${pct.toStringAsFixed(1)}%)\n',
                        GoogleFonts.plusJakartaSans(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: 'Target: ${CurrencyFormatter.formatNumber(tVal)} Kg\n',
                            style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.78), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: 'Real: ${CurrencyFormatter.formatNumber(rVal)} Kg',
                            style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.secondary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i >= 0 && i < trend.length) {
                          final pct = (trend[i][isSellIn ? 'ach_sell_in_pct' : 'ach_sell_out_pct'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  trend[i]['period'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: context.colors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _achColor(pct),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 34,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          _formatCompactAxis(val),
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
                  final targetVal = (item[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0.0;
                  final realVal = (item[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0.0;

                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: targetVal,
                        color: targetColor,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: realVal,
                        color: realColor,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(12),
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
                  Icon(isAsm ? LucideIcons.building2 : LucideIcons.mapPin, color: Theme.of(context).colorScheme.primary, size: 20),
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
                final realKg = (loc['realisasi_kg'] as num?)?.toDouble() ?? 0.0;
                final achPct = (loc['ach_pct'] as num?)?.toDouble() ?? 0.0;
                final targetOutlet = (loc['target_outlet'] as num?)?.toInt() ?? 0;
                final realOutlet = (loc['realisasi_outlet'] as num?)?.toInt() ?? 0;
                final brands = (loc['brands'] as List?) ?? [];

                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  collapsedIconColor: context.colors.textMuted,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isAsm ? Theme.of(context).colorScheme.primary : context.semantic.secondaryAccent).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAsm ? 'DEPO' : 'AREA',
                          style: GoogleFonts.plusJakartaSans(
                            color: isAsm ? Theme.of(context).colorScheme.primary : context.semantic.secondaryAccent,
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
                              '${CurrencyFormatter.formatNumber(realKg)} / ${CurrencyFormatter.formatNumber(targetKg)} Kg (${achPct.toStringAsFixed(1)}%)',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: achPct >= 100 ? context.semantic.success : Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          if (targetOutlet > 0)
                            Text(
                              'AO: $realOutlet / ${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: context.semantic.secondaryAccent,
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
                                Icon(LucideIcons.tag, size: 14, color: context.semantic.secondaryAccent),
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
                                    style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
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
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
            Icon(LucideIcons.alertTriangle, size: 36, color: context.semantic.danger),
            const SizedBox(height: 12),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: context.semantic.danger, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            if (isAuthError)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  int? _touchedTrendIndex;

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final dashState = ref.watch(dashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sticky Header & Period Control Rule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            border: Border(bottom: BorderSide(color: context.colors.border)),
          ),
          child: _buildHeader(context, authUser, dashState),
        ),

        // Main Workspace Scroll Canvas
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
    final userPos = (state.kpi['position'] ?? state.user?['position'] ?? user?.position?.code ?? '')
        .toString()
        .toUpperCase();
    final scheme = state.salesScheme.toUpperCase();
    final userName = user?.name ?? state.user?['name'] ?? (isAdmin ? 'Administrator' : 'Sales');
    final periodLabel = state.selectedPeriod.isEmpty ? '-' : state.selectedPeriod;

    final String pageTitle = isAdmin ? 'Ringkasan distribusi & insentif' : 'Capaian & insentif';
    String contextMeta = canManage
        ? 'Cakupan $scopeLabel · $userName'
        : 'Eksekutif${userPos.isNotEmpty ? ' $userPos' : ''} · Cakupan $scopeLabel · $userName';

    if (!isAdmin) {
      if (scheme == 'INDUSTRI') {
        contextMeta = 'Sales Industri ($userPos) · $userName · Kuota Volume (Kg) & NOO';
      } else if (scheme == 'SURABAYA') {
        contextMeta = userPos == 'ASC'
            ? 'Koordinator Surabaya (ASC) · $userName · Evaluasi Tim TO & SM'
            : 'Sales Surabaya ($userPos) · $userName · Penjualan Langsung';
      } else {
        contextMeta = userPos == 'ASM'
            ? 'Sales Distributor (ASM) · $userName · Sell-In Depo'
            : 'Sales Distributor ($userPos) · $userName · Sell-Out Area & Active Outlet';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 880;
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final colors = context.colors;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pageTitle,
              style: tt.headlineSmall,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.bgSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.tag),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'PERIODE $periodLabel',
                    style: context.monoStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    contextMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        );

        final actionsSection = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (state.availablePeriods.isNotEmpty)
              Builder(
                builder: (context) {
                  final selectedList = state.selectedPeriodsList;
                  final labelText = selectedList.length == 1
                      ? 'Periode ${selectedList.first}'
                      : '${selectedList.length} periode (${selectedList.first}–${selectedList.last})';

                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    hoverColor: colors.bgHover,
                    onTap: () => _showMultiPeriodPickerDialog(context, ref, state),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.bgSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(
                          color: selectedList.length > 1 ? cs.primary : colors.borderStrong,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendar, size: 15, color: cs.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            labelText,
                            style: tt.labelLarge?.copyWith(fontSize: 12.5),
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Icon(LucideIcons.chevronDown, size: 14, color: colors.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),

            Tooltip(
              message: 'Muat ulang data',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                hoverColor: colors.bgHover,
                onTap: state.isLoading ? null : () => ref.read(dashboardProvider.notifier).fetchSummary(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.bgCard,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: colors.borderStrong),
                  ),
                  alignment: Alignment.center,
                  child: state.isLoading
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                        )
                      : Icon(LucideIcons.refreshCw, size: 16, color: colors.textSecondary),
                ),
              ),
            ),

            if (isAdmin) ...[
              if (canManage)
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.uploadCloud, size: 15),
                  label: const Text('Upload Excel'),
                  onPressed: () => context.go('/bulk-upload'),
                ),
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.calculator, size: 15),
                label: const Text('Hitung insentif'),
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
              const SizedBox(height: AppSpacing.md),
              actionsSection,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleSection),
            const SizedBox(width: AppSpacing.lg),
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

    final sellThroughPct = (kpi['sell_through_pct'] as num?)?.toDouble() ?? 0.0;
    final totalDppSellIn = (kpi['total_dpp_sell_in'] as num?)?.toDouble() ?? 0.0;
    final totalDppSellOut = (kpi['total_dpp_sell_out'] as num?)?.toDouble() ?? 0.0;
    final incentiveRatioPct = (kpi['incentive_ratio_pct'] as num?)?.toDouble() ?? 0.0;
    final double displayOmzet = totalDppSellOut > 0 ? totalDppSellOut : totalDppSellIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Asymmetric Hierarchy: Hero Incentive Spotlight (5) + 3-Column Operational Ledger (7)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1020;
            final cs = Theme.of(context).colorScheme;
            final sem = context.semantic;
            final colors = context.colors;

            final heroStatusText = totalReward > 0
                ? (incentiveRatioPct <= 3.0 ? 'Rasio efisien' : 'Perlu pantau')
                : 'Belum dihitung';

            final heroSpotlightBlock = Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: sem.heroSurface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: sem.heroBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL INSENTIF PERIODE INI',
                          style: context.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: sem.heroMuted,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.tag),
                          border: Border.all(color: sem.heroBorder),
                        ),
                        child: Text(
                          heroStatusText,
                          style: context.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: totalReward > 0 ? sem.heroAccent : sem.heroMuted,
                          ),
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
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.9,
                        color: sem.heroOnSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    incentiveRatioPct > 0
                        ? 'Rasio ${incentiveRatioPct.toStringAsFixed(2)}% dari omzet ${totalDppSellOut > 0 ? 'Sell-Out' : 'Sell-In'} · $totalSales sales ($totalDist distributor)'
                        : '$totalSales sales · $totalDist distributor ($scopeLabel)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: sem.heroMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(height: 1, color: sem.heroBorder),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalDppSellOut > 0 ? 'Omzet DPP Sell-Out' : 'Omzet DPP Sell-In',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: sem.heroMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatRupiah(displayOmzet),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tabularNumStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: sem.heroOnSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (totalDppSellOut > 0 && totalDppSellIn > 0) ...[
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DPP Sell-In',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: sem.heroMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatRupiah(totalDppSellIn),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tabularNumStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: sem.heroMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    const SizedBox(height: AppSpacing.md),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        primaryValue,
                        style: context.tabularNumStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondaryLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tag),
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

            final String sellThroughNote = realSellIn > 0
                ? 'Sell-through ${sellThroughPct.toStringAsFixed(1)}% (${sellThroughPct >= 85 ? 'stok lancar' : (sellThroughPct >= 65 ? 'moderat' : 'stok menumpuk')})'
                : 'Konsumsi multi-brand';

            final sellInMetric = buildLedgerMetric(
              label: 'Sell-In Depo (ASM)',
              primaryValue: '${CurrencyFormatter.formatNumber(realSellIn)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetSellIn)} Kg',
              pct: achSellIn,
              footnote: '$totalDist distributor · $scopeLabel',
            );

            final sellOutMetric = buildLedgerMetric(
              label: 'Sell-Out Area (SPV)',
              primaryValue: '${CurrencyFormatter.formatNumber(realSellOut)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetSellOut)} Kg',
              pct: achSellOut,
              footnote: sellThroughNote,
            );

            final aoMetric = buildLedgerMetric(
              label: 'Active Outlet (Toko)',
              primaryValue: '${CurrencyFormatter.formatNumber(realOutlet)} Toko',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
              pct: achOutlet,
              footnote: 'Cakupan toko ritel area',
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
                    Expanded(flex: 5, child: heroSpotlightBlock),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 7, child: operationalLedger),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heroSpotlightBlock,
                const SizedBox(height: AppSpacing.md),
                operationalLedger,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),

        // Section: Capaian sales tertinggi & Capaian distributor
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildLeaderboardCard(context, state.leaderboard)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    flex: 5,
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
                const SizedBox(height: AppSpacing.lg),
                _buildDistributorCard(
                  context,
                  state.distributors,
                  state.underperformingDistributors,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Section: Sebaran per wilayah & Kontribusi per brand
        if (state.regionPerformance.isNotEmpty || state.brandPerformance.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildRegionPerformanceCard(context, state.regionPerformance),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 5,
                      child: _buildBrandPerformanceCard(context, state.brandPerformance),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildRegionPerformanceCard(context, state.regionPerformance),
                  const SizedBox(height: AppSpacing.lg),
                  _buildBrandPerformanceCard(context, state.brandPerformance),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],

        // Section: Tren 6 periode terakhir (direct labels, minimal gridlines)
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
        ? 'Belum ada grade'
        : (grade.toLowerCase().startsWith('grade') ? grade : 'Grade $grade');
    final overallAch = (kpi['overall_ach_pct'] as num?)?.toDouble() ?? 0.0;

    final assignedDepos = (kpi['total_assigned_depos'] as num?)?.toInt() ?? 0;
    final assignedAreas = (kpi['total_assigned_areas'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSalesHeroSection(
          context,
          heroTitle: 'ESTIMASI INSENTIF PERIODE INI',
          heroAmount: CurrencyFormatter.formatRupiah(estimatedReward),
          heroStatus: gradeBadge,
          heroStatusPositive: estimatedReward > 0,
          heroFootnote: grade != '-'
              ? 'Pencapaian gabungan ${overallAch.toStringAsFixed(1)}% · Periode ${state.selectedPeriod}'
              : 'Belum ada kalkulasi untuk periode ${state.selectedPeriod}',
          metrics: [
            if (isAsm)
              _SalesLedgerMetricData(
                label: 'Sell-In Depo',
                primaryValue: '${CurrencyFormatter.formatNumber(realSellIn)} Kg',
                secondaryLine: 'Target ${CurrencyFormatter.formatNumber(myTargetSellIn)} Kg',
                pct: achSellIn,
                footnote: '$assignedDepos depo penugasan',
              )
            else ...[
              _SalesLedgerMetricData(
                label: 'Sell-Out Area',
                primaryValue: '${CurrencyFormatter.formatNumber(realSellOut)} Kg',
                secondaryLine: 'Target ${CurrencyFormatter.formatNumber(myTargetSellOut)} Kg',
                pct: achSellOut,
                footnote: '$assignedAreas area penugasan',
              ),
              _SalesLedgerMetricData(
                label: 'Active Outlet (AO)',
                primaryValue: '${CurrencyFormatter.formatNumber(realOutlet)} Toko',
                secondaryLine: 'Target ${CurrencyFormatter.formatNumber(myTargetOutlet)} Toko',
                pct: achOutlet,
                footnote: 'Sebaran toko ritel area',
              ),
            ],
            if (isAsm)
              _SalesLedgerMetricData(
                label: 'Depo aktif',
                primaryValue: '$assignedDepos Depo',
                secondaryLine: 'Penugasan skema Konsumsi ($posCode)',
                pct: assignedDepos > 0 ? 100 : 0,
                footnote: 'Tingkat distributor',
                hidePercentage: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

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
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSalesHeroSection(
          context,
          heroTitle: 'TOTAL INSENTIF INDUSTRI ($posCode)',
          heroAmount: CurrencyFormatter.formatRupiah(totalReward),
          heroStatus: totalReward > 0 ? 'Terkalkulasi' : 'Rp 0',
          heroStatusPositive: totalReward > 0,
          heroFootnote:
              'Sell-In ${CurrencyFormatter.formatRupiah(sellInReward)} + NOO ${CurrencyFormatter.formatRupiah(nooReward)} · ${customers.length} customer',
          metrics: [
            _SalesLedgerMetricData(
              label: 'Sell-In Industri (${sellInWeight.toStringAsFixed(0)}%)',
              primaryValue: '${CurrencyFormatter.formatNumber(sellInActual)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(sellInTarget)} Kg',
              pct: sellInAch,
              footnote: 'Min ${sellInMinAch.toStringAsFixed(0)}% · ${CurrencyFormatter.formatRate(sellInRate)}/Kg · $sellInGrade',
              forcePassedColor: sellInPassed,
            ),
            _SalesLedgerMetricData(
              label: 'New Open Outlet (${nooWeight.toStringAsFixed(0)}%)',
              primaryValue: '$nooActual Toko',
              secondaryLine: 'Target $nooTarget Toko · Vol ${CurrencyFormatter.formatNumber(nooVolumeKg)} Kg',
              pct: nooAch,
              footnote: 'Min ${nooMinAch.toStringAsFixed(0)}% · ${CurrencyFormatter.formatRate(nooRate)}/Kg · $nooGrade',
              forcePassedColor: nooPassed,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Formula Details
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
                  Icon(LucideIcons.calculator, color: Theme.of(context).colorScheme.primary, size: 17),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ringkasan perhitungan insentif Industri ($posCode)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  _buildFormulaBox(
                    context,
                    title: 'Komponen Sell-In (${sellInWeight.toStringAsFixed(0)}%)',
                    formula: sellInPassed
                        ? '${CurrencyFormatter.formatNumber(sellInActual)} Kg × ${CurrencyFormatter.formatRate(sellInRate)} × ${sellInWeight.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(sellInReward)}'
                        : 'Capaian ${sellInAch.toStringAsFixed(1)}% di bawah batas ${sellInMinAch.toStringAsFixed(0)}% → Rp 0',
                    passed: sellInPassed,
                    grade: sellInGrade,
                  ),
                  _buildFormulaBox(
                    context,
                    title: 'Komponen NOO (${nooWeight.toStringAsFixed(0)}%)',
                    formula: nooPassed
                        ? '${CurrencyFormatter.formatNumber(nooVolumeKg)} Kg (NOO) × ${CurrencyFormatter.formatRate(nooRate)} × ${nooWeight.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(nooReward)}'
                        : 'Belum memenuhi batas ${nooMinAch.toStringAsFixed(0)}% atau 0 NOO → Rp 0',
                    passed: nooPassed,
                    grade: nooGrade,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Customer List & NOO Evaluation
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
                  Expanded(
                    child: Text(
                      'Customer industri & status NOO',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${customers.length} customer',
                    style: context.monoStyle(fontSize: 11.5, color: colors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (customers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi customer industri di periode ini.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => Divider(height: AppSpacing.lg, color: colors.border),
                  itemBuilder: (context, idx) {
                    final c = customers[idx] as Map<String, dynamic>;
                    final isNoo = c['is_noo'] == true;
                    final volKg = (c['volume_kg'] as num?)?.toDouble() ?? 0.0;
                    final custType = (c['customer_type'] ?? 'EXISTING').toString().toUpperCase();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isNoo ? context.semantic.successBg : colors.bgSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.tag),
                            border: Border.all(
                              color: isNoo
                                  ? context.semantic.success.withValues(alpha: 0.35)
                                  : colors.border,
                            ),
                          ),
                          child: Text(
                            isNoo ? 'NOO VALID' : custType,
                            style: context.monoStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isNoo ? context.semantic.success : colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c['customer_name'] ?? '-'} (${c['customer_code'] ?? '-'})',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c['city'] ?? '-'} · ${c['noo_reason'] ?? '-'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${CurrencyFormatter.formatNumber(volKg)} Kg',
                              style: context.tabularNumStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isNoo ? context.semantic.success : colors.textPrimary,
                              ),
                            ),
                            Text(
                              isNoo ? 'Masuk Sell-In & NOO' : 'Masuk Sell-In',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colors.textMuted,
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
        _buildSalesHeroSection(
          context,
          heroTitle: isAsc ? 'TOTAL INSENTIF KOORDINATOR ASC' : 'INSENTIF SURABAYA ($posCode)',
          heroAmount: CurrencyFormatter.formatRupiah(totalReward),
          heroStatus: totalReward > 0 ? 'Lolos' : 'Rp 0',
          heroStatusPositive: totalReward > 0,
          heroFootnote: isAsc
              ? 'Akumulasi dari $achievedSubCount/${subordinates.length} tim mencapai target'
              : '${CurrencyFormatter.formatNumber(actualKg)} Kg × ${CurrencyFormatter.formatRate(rate)} × ${headerWeightPct.toStringAsFixed(0)}%',
          metrics: [
            if (isAsc)
              _SalesLedgerMetricData(
                label: 'Tim bawahan TO & SM',
                primaryValue: '$achievedSubCount / ${subordinates.length} Lolos',
                secondaryLine: 'Evaluasi per individu bawahan',
                pct: subordinates.isEmpty ? 0 : (achievedSubCount / subordinates.length) * 100,
                footnote: 'Periode ${state.selectedPeriod}',
              ),
            _SalesLedgerMetricData(
              label: isAsc ? 'Total tonase tim' : 'Penjualan langsung ($posCode)',
              primaryValue: '${CurrencyFormatter.formatNumber(actualKg)} Kg',
              secondaryLine: 'Target ${CurrencyFormatter.formatNumber(targetKg)} Kg',
              pct: achPct,
              footnote: isAsc
                  ? 'Batas minimum individu ${minAchPct.toStringAsFixed(0)}%'
                  : 'Tarif ${CurrencyFormatter.formatRate(rate)}/Kg · $gradeName · ASC $ascName',
              forcePassedColor: passed,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

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

  Widget _buildSalesHeroSection(
    BuildContext context, {
    required String heroTitle,
    required String heroAmount,
    required String heroStatus,
    required bool heroStatusPositive,
    required String heroFootnote,
    required List<_SalesLedgerMetricData> metrics,
  }) {
    final sem = context.semantic;
    final colors = context.colors;
    final cs = Theme.of(context).colorScheme;

    final heroPanel = Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: sem.heroSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: sem.heroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  heroTitle,
                  style: context.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: sem.heroMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.tag),
                  border: Border.all(color: sem.heroBorder),
                ),
                child: Text(
                  heroStatus,
                  style: context.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: heroStatusPositive ? sem.heroAccent : sem.heroMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              heroAmount,
              style: context.tabularNumStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: sem.heroOnSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: sem.heroBorder),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            heroFootnote,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sem.heroMuted),
          ),
        ],
      ),
    );

    Widget buildCol(_SalesLedgerMetricData m) {
      final Color barColor = m.forcePassedColor != null
          ? (m.forcePassedColor! ? sem.success : sem.danger)
          : (m.pct >= 100 ? sem.success : (m.pct >= 80 ? cs.primary : (m.pct > 0 ? sem.warning : colors.textMuted)));

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
                    m.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.textMuted),
                  ),
                ),
                if (!m.hidePercentage) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${m.pct.toStringAsFixed(1)}%',
                    style: context.tabularNumStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                m.primaryValue,
                style: context.tabularNumStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              m.secondaryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tag),
              child: LinearProgressIndicator(
                value: (m.pct / 100).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: colors.bgElevated,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              m.footnote,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final ledger = Container(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: constraints.maxWidth >= 600
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < metrics.length; i++) ...[
                        if (i > 0) VerticalDivider(width: 1, thickness: 1, color: colors.border),
                        Expanded(child: buildCol(metrics[i])),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < metrics.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.border),
                      buildCol(metrics[i]),
                    ],
                  ],
                ),
        );

        if (constraints.maxWidth >= 960) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: heroPanel),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 7, child: ledger),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heroPanel,
            const SizedBox(height: AppSpacing.md),
            ledger,
          ],
        );
      },
    );
  }

  Widget _buildFormulaBox(
    BuildContext context, {
    required String title,
    required String formula,
    required bool passed,
    required String grade,
  }) {
    final colors = context.colors;
    return Container(
      width: 440,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: (passed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                grade,
                style: context.monoStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: passed ? context.semantic.success : colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formula,
            style: context.tabularNumStyle(
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Icon(LucideIcons.table, color: Theme.of(context).colorScheme.primary, size: 17),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Evaluasi bawahan Surabaya (TO & SM)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (subordinates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Belum ada sales bawahan pada periode ini.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 58,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Posisi')),
                  DataColumn(label: Text('Target (Kg)')),
                  DataColumn(label: Text('Aktual (Kg)')),
                  DataColumn(label: Text('% Capai')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Grade ASC')),
                  DataColumn(label: Text('Bobot')),
                  DataColumn(label: Text('Kontribusi ASC')),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: passed ? context.semantic.successBg : context.semantic.dangerBg,
                              borderRadius: BorderRadius.circular(AppRadius.tag),
                            ),
                            child: Text(
                              (s['status_label'] ?? (passed ? 'Lolos' : 'Di bawah batas')).toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: passed ? context.semantic.success : context.semantic.danger,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                          passed
                              ? '${s['grade_name'] ?? '-'} (${CurrencyFormatter.formatRate(rate)}/Kg)'
                              : '-',
                        )),
                        DataCell(Text(passed ? '${wHdr.toStringAsFixed(0)}%' : '-')),
                        DataCell(Text(
                          CurrencyFormatter.formatRupiah(contrib),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: contrib > 0 ? context.semantic.success : colors.textMuted,
                          ),
                        )),
                      ],
                    );
                  }),
                  DataRow(
                    cells: [
                      const DataCell(Text(
                        'TOTAL INSENTIF ASC',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
                        style: context.tabularNumStyle(
                          fontWeight: FontWeight.w700,
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Icon(LucideIcons.calculator, color: Theme.of(context).colorScheme.primary, size: 17),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ringkasan perhitungan ($posCode)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFormulaBox(
            context,
            title: 'Penjualan langsung ($posCode · Koordinator ASC: $ascName)',
            formula: passed
                ? '${CurrencyFormatter.formatNumber(actualKg)} Kg × ${CurrencyFormatter.formatRate(rate)}/Kg ($gradeName) × ${headerWeightPct.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(totalReward)}'
                : 'Capaian ${achPct.toStringAsFixed(1)}% di bawah batas ${minAchPct.toStringAsFixed(0)}% → Rp 0',
            passed: passed,
            grade: gradeName,
          ),
        ],
      ),
    );
  }

  // ---------------- WIDGET HELPERS ----------------

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
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: colors.border),
            ),
            title: Row(
              children: [
                Icon(LucideIcons.calendar, size: 17, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    'Pilih periode',
                    style: Theme.of(context).textTheme.titleLarge,
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
                    selected.length == state.availablePeriods.length ? 'Reset 1 bulan' : 'Pilih semua',
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
                        style: context.monoStyle(
                          color: colors.textPrimary,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
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
                onPressed: () {
                  final sorted = selected.toList()..sort();
                  Navigator.pop(ctx);
                  ref.read(dashboardProvider.notifier).changePeriod(sorted.join(','));
                },
                child: Text('Terapkan (${selected.length})'),
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
      return Text('—', style: TextStyle(color: colors.textMuted, fontSize: 12));
    }

    final Color badgeColor = _achColor(pct);

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
        const SizedBox(height: 2),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: context.tabularNumStyle(
            color: badgeColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, List<dynamic> leaderboard) {
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Capaian sales tertinggi', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Urut berdasarkan persentase target Sell-In & Sell-Out',
                      style: tt.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${leaderboard.length} teratas',
                style: context.monoStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (leaderboard.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Text(
                    'Belum ada target sales di periode ini.',
                    style: tt.bodyMedium?.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.target, size: 15),
                    label: const Text('Buka target kuota'),
                    onPressed: () => context.go('/master/target'),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 6,
                headingRowHeight: 38,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 62,
                columns: const [
                  DataColumn(label: Text('No')),
                  DataColumn(label: Text('Personil & wilayah')),
                  DataColumn(label: Text('Sell-In')),
                  DataColumn(label: Text('Sell-Out')),
                  DataColumn(label: Text('AO (Toko)')),
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
                        SizedBox(
                          width: 24,
                          child: Text(
                            idx.toString().padLeft(2, '0'),
                            style: context.monoStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: idx <= 3 ? Theme.of(context).colorScheme.primary : colors.textMuted,
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
                                  style: tt.titleSmall,
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.bgSubtle,
                                    borderRadius: BorderRadius.circular(AppRadius.tag),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: Text(
                                    pos,
                                    style: context.monoStyle(
                                      color: pos == 'ASM'
                                          ? Theme.of(context).colorScheme.primary
                                          : colors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${item['username'] ?? '-'} · ${pos == 'ASM' ? '$depoCount depo' : '$areaCount area'}',
                              style: tt.bodySmall?.copyWith(fontSize: 11, color: colors.textMuted),
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
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      hoverColor: colors.bgHover,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? color : colors.bgSubtle,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: isSelected ? color : colors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDistributorCard(
    BuildContext context,
    List<dynamic> topDistributors,
    List<dynamic> underperformingDistributors,
  ) {
    final activeList = _showUnderperformingDist ? underperformingDistributors : topDistributors;
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Capaian distributor', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      _showUnderperformingDist
                          ? 'Distributor dengan capaian Sell-In di bawah 80%'
                          : 'Capaian Sell-In terhadap kuota periode ini',
                      style: tt.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                _showUnderperformingDist ? LucideIcons.alertTriangle : LucideIcons.building2,
                size: 16,
                color: _showUnderperformingDist ? context.semantic.danger : colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            children: [
              _buildToggleChip(
                label: 'Teratas',
                isSelected: !_showUnderperformingDist,
                onTap: () => setState(() => _showUnderperformingDist = false),
              ),
              _buildToggleChip(
                label: 'Di bawah 80%${underperformingDistributors.isNotEmpty ? ' (${underperformingDistributors.length})' : ''}',
                isSelected: _showUnderperformingDist,
                activeColor: context.semantic.danger,
                onTap: () => setState(() => _showUnderperformingDist = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (activeList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                _showUnderperformingDist
                    ? 'Semua distributor sudah di atas 80% pada periode ini.'
                    : 'Belum ada data distributor di periode ini.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: colors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeList.length,
              separatorBuilder: (_, __) => Divider(height: AppSpacing.lg, color: colors.border),
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            (idx + 1).toString().padLeft(2, '0'),
                            style: context.monoStyle(
                              fontWeight: FontWeight.w600,
                              color: _showUnderperformingDist ? context.semantic.danger : colors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['name'] ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleSmall,
                              ),
                              Text(
                                '${d['code'] ?? '-'}${regionName.isNotEmpty && regionName != 'Lainnya' ? ' · $regionName' : ''} · $depoCount depo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.monoStyle(color: colors.textMuted, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${achSiPct.toStringAsFixed(1)}%',
                          style: context.tabularNumStyle(
                            fontWeight: FontWeight.w700,
                            color: pctColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tag),
                      child: LinearProgressIndicator(
                        value: (achSiPct / 100).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Sell-In: ${CurrencyFormatter.formatNumber(realSi)} / ${CurrencyFormatter.formatNumber(targetSi)} Kg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tabularNumStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (targetSo > 0)
                          Text(
                            'SO ${achSoPct.toStringAsFixed(0)}%',
                            style: context.tabularNumStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
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
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sebaran per wilayah', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Perbandingan Sell-In, Sell-Out, dan toko aktif tiap region',
                      style: tt.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.map, size: 16, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (regions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text('Belum ada data wilayah di periode ini.', style: TextStyle(color: colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: regions.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
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
                            style: tt.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: context.tabularNumStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: colors.bgCard,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tabularNumStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md + 2),
                  decoration: BoxDecoration(
                    color: colors.bgSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: colors.border),
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
                                    style: tt.titleSmall,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '$distCount dist',
                                  style: context.monoStyle(fontSize: 10.5, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Sell-through ${stPct.toStringAsFixed(1)}%',
                            style: context.tabularNumStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: miniMetric(
                              'Sell-In',
                              achSi,
                              '${_formatCompactKg(realSi)} / ${_formatCompactKg(targetSi)}',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: miniMetric(
                              'Sell-Out',
                              achSo,
                              '${_formatCompactKg(realSo)} / ${_formatCompactKg(targetSo)}',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
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
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kontribusi per brand', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Porsi volume Sell-In dan serapan Sell-Out tiap merek',
                      style: tt.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.tag, size: 16, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (brands.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text('Belum ada data brand di periode ini.', style: TextStyle(color: colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: brands.length,
              separatorBuilder: (_, __) => Divider(height: AppSpacing.lg, color: colors.border),
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
                            style: tt.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Porsi ${shareSi.toStringAsFixed(1)}%',
                          style: context.monoStyle(fontSize: 10.5, color: colors.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          '${achSi.toStringAsFixed(1)}%',
                          style: context.tabularNumStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tag),
                      child: LinearProgressIndicator(
                        value: (achSi / 100).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SI: ${_formatCompactKg(realSi)} / ${_formatCompactKg(targetSi)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tabularNumStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (targetSo > 0 || realSo > 0)
                          Text(
                            'SO: ${_formatCompactKg(realSo)} (${achSo.toStringAsFixed(0)}%)',
                            style: context.tabularNumStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: colors.textMuted,
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
    final cs = Theme.of(context).colorScheme;
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;
    final realColor = isSellIn ? cs.primary : context.semantic.info;
    final targetColor = colors.borderStrong;

    double maxVal = 0.0;
    for (final item in trend) {
      final t = (item[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0.0;
      final r = (item[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0.0;
      if (t > maxVal) maxVal = t;
      if (r > maxVal) maxVal = r;
    }
    final double gridInterval = maxVal > 0 ? (maxVal / 3) : 25.0;

    final int? activeIdx = (_touchedTrendIndex != null && _touchedTrendIndex! >= 0 && _touchedTrendIndex! < trend.length)
        ? _touchedTrendIndex
        : null;
    final hoveredItem = activeIdx != null ? trend[activeIdx] : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSellIn
                          ? 'Tren 6 periode terakhir — Target vs Realisasi Sell-In (Kg)'
                          : 'Tren 6 periode terakhir — Target vs Realisasi Sell-Out (Kg)',
                      style: tt.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 3, color: targetColor),
                        const SizedBox(width: 5),
                        Text(
                          'Batang abu: Target',
                          style: tt.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(width: 10, height: 3, color: realColor),
                        const SizedBox(width: 5),
                        Text(
                          isSellIn ? 'Batang viridian: Realisasi Sell-In' : 'Batang biru: Realisasi Sell-Out',
                          style: tt.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildToggleChip(
                      label: 'Sell-In',
                      isSelected: isSellIn,
                      activeColor: cs.primary,
                      onTap: () => setState(() {
                        _trendMetric = 'SELL_IN';
                        _touchedTrendIndex = null;
                      }),
                    ),
                    _buildToggleChip(
                      label: 'Sell-Out',
                      isSelected: !isSellIn,
                      activeColor: context.semantic.info,
                      onTap: () => setState(() {
                        _trendMetric = 'SELL_OUT';
                        _touchedTrendIndex = null;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: hoveredItem != null
                ? Container(
                    key: ValueKey('trend_focus_$activeIdx'),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.bgSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'Periode ${hoveredItem['period']}  ·  Target: ${CurrencyFormatter.formatNumber((hoveredItem[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0)} Kg  ·  Realisasi: ${CurrencyFormatter.formatNumber((hoveredItem[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0)} Kg (${((hoveredItem[isSellIn ? 'ach_sell_in_pct' : 'ach_sell_out_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%)',
                      style: context.monoStyle(fontSize: 11, color: colors.textPrimary),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('trend_idle'),
                    height: 16,
                    child: Text(
                      'Sentuh atau arahkan kursor ke batang untuk rincian angka penuh.',
                      style: tt.bodySmall?.copyWith(fontSize: 11, color: colors.textFaint),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.24 : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions || response == null || response.spot == null) {
                      if (_touchedTrendIndex != null) {
                        setState(() => _touchedTrendIndex = null);
                      }
                      return;
                    }
                    final idx = response.spot!.touchedBarGroupIndex;
                    if (_touchedTrendIndex != idx) {
                      setState(() => _touchedTrendIndex = idx);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    tooltipMargin: 4,
                    fitInsideHorizontally: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _formatCompactAxis(rod.toY),
                        context.monoStyle(
                          color: realColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
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
                                  style: context.monoStyle(
                                    color: colors.textPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: context.tabularNumStyle(
                                    color: _achColor(pct),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
                      interval: gridInterval,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          _formatCompactAxis(val),
                          style: context.monoStyle(
                            color: colors.textFaint,
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
                  horizontalInterval: gridInterval,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: colors.border,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(bottom: BorderSide(color: colors.borderStrong)),
                ),
                barGroups: trend.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final targetVal = (item[isSellIn ? 'target_sell_in' : 'target_sell_out'] as num?)?.toDouble() ?? 0.0;
                  final realVal = (item[isSellIn ? 'real_sell_in' : 'real_sell_out'] as num?)?.toDouble() ?? 0.0;

                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    showingTooltipIndicators: realVal > 0 ? const [1] : const [],
                    barRods: [
                      BarChartRodData(
                        toY: targetVal,
                        color: targetColor,
                        width: 15,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.tag)),
                      ),
                      BarChartRodData(
                        toY: realVal,
                        color: realColor,
                        width: 15,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.tag)),
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
    final colors = context.colors;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
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
              Icon(isAsm ? LucideIcons.building2 : LucideIcons.mapPin,
                  color: Theme.of(context).colorScheme.primary, size: 17),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isAsm ? 'Target depo penugasan' : 'Target area & toko penugasan',
                  style: tt.titleLarge,
                ),
              ),
              Text(
                '${breakdown.length} lokasi',
                style: context.monoStyle(color: colors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (breakdown.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'Belum ada target penugasan di periode ini.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: breakdown.length,
              separatorBuilder: (_, __) => Divider(height: AppSpacing.md, color: colors.border),
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
                  collapsedIconColor: colors.textMuted,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.bgSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.tag),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          isAsm ? 'DEPO' : 'AREA',
                          style: context.monoStyle(
                            color: isAsm ? Theme.of(context).colorScheme.primary : colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loc['location_name']} (${loc['location_code']})',
                              style: tt.titleSmall,
                            ),
                            Text(
                              loc['distributor_name'] ?? '-',
                              style: tt.bodySmall?.copyWith(color: colors.textMuted, fontSize: 11.5),
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
                              style: context.tabularNumStyle(
                                fontWeight: FontWeight.w700,
                                color: achPct >= 100
                                    ? context.semantic.success
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 12.5,
                              ),
                            ),
                          if (targetOutlet > 0)
                            Text(
                              'AO: $realOutlet / ${CurrencyFormatter.formatNumber(targetOutlet)} Toko',
                              style: context.tabularNumStyle(
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                      child: Column(
                        children: brands.map((b) {
                          final bQuota = (b['target_quota'] as num?)?.toDouble() ?? 0.0;
                          final bOutlet = (b['target_outlet'] as num?)?.toInt() ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.bgSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.control),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.tag, size: 13, color: colors.textMuted),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  b['brand_name'] ?? '-',
                                  style: tt.titleSmall?.copyWith(fontSize: 12.5),
                                ),
                                const Spacer(),
                                if (bQuota > 0)
                                  Text(
                                    '${CurrencyFormatter.formatNumber(bQuota)} Kg',
                                    style: context.tabularNumStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                if (bQuota > 0 && bOutlet > 0) const Text(' · '),
                                if (bOutlet > 0)
                                  Text(
                                    '$bOutlet Toko',
                                    style: context.tabularNumStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
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

  // ---------------- STRUCTURED LEDGER LOADING & ERROR STATES ----------------

  Widget _buildLoadingState(BuildContext context) {
    final colors = context.colors;
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantic;

    Widget skeletonBar({double? width, double height = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.tag),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tag),
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Menyiapkan buku ringkasan...',
          style: context.monoStyle(fontSize: 11, color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final heroSkeleton = Container(
              height: 170,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: sem.heroSurface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: sem.heroBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 140, height: 10, color: sem.heroBorder),
                  Container(width: 220, height: 28, color: sem.heroBorder),
                  Container(width: 180, height: 10, color: sem.heroBorder),
                ],
              ),
            );

            final ledgerSkeleton = Container(
              height: 170,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [skeletonBar(width: 90), skeletonBar(width: 130, height: 22), skeletonBar()],
                    ),
                  ),
                  VerticalDivider(width: AppSpacing.xl, color: colors.border),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [skeletonBar(width: 90), skeletonBar(width: 130, height: 22), skeletonBar()],
                    ),
                  ),
                  VerticalDivider(width: AppSpacing.xl, color: colors.border),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [skeletonBar(width: 90), skeletonBar(width: 110, height: 22), skeletonBar()],
                    ),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(flex: 5, child: heroSkeleton),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 7, child: ledgerSkeleton),
                ],
              );
            }
            return Column(
              children: [
                heroSkeleton,
                const SizedBox(height: AppSpacing.md),
                ledgerSkeleton,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          height: 240,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              skeletonBar(width: 210, height: 16),
              const SizedBox(height: AppSpacing.xl),
              skeletonBar(height: 14),
              Divider(height: AppSpacing.xl, color: colors.border),
              skeletonBar(height: 14),
              Divider(height: AppSpacing.xl, color: colors.border),
              skeletonBar(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final colors = context.colors;
    final sem = context.semantic;
    final tt = Theme.of(context).textTheme;

    final isAuthError = message.contains('401') ||
        message.toLowerCase().contains('sesi') ||
        message.toLowerCase().contains('unauthorized');

    final String title = isAuthError ? 'Sesi kerja berakhir' : 'Data ringkasan belum bisa dimuat';
    final String body = isAuthError
        ? 'Masuk ulang dengan akun kerja untuk membuka data terbaru.'
        : 'Koneksi ke server terputus atau respons terlambat. Coba muat ulang halaman.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: sem.danger),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.alertTriangle, size: 18, color: sem.danger),
                        const SizedBox(width: AppSpacing.sm),
                        Text(title, style: tt.titleLarge),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      body,
                      style: tt.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (isAuthError)
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.logIn, size: 15),
                        label: const Text('Masuk ulang'),
                        onPressed: () {
                          ref.read(authProvider.notifier).logout();
                          context.go('/login');
                        },
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.refreshCw, size: 15),
                        label: const Text('Muat ulang'),
                        onPressed: () => ref.read(dashboardProvider.notifier).fetchSummary(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesLedgerMetricData {
  final String label;
  final String primaryValue;
  final String secondaryLine;
  final double pct;
  final String footnote;
  final bool? forcePassedColor;
  final bool hidePercentage;

  const _SalesLedgerMetricData({
    required this.label,
    required this.primaryValue,
    required this.secondaryLine,
    required this.pct,
    required this.footnote,
    this.forcePassedColor,
    this.hidePercentage = false,
  });
}

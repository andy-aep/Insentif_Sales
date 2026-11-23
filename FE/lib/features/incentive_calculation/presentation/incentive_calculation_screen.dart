import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
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
  int _cardsPage = 1;
  int _cardsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(userManagementProvider).users.isEmpty) {
        ref.read(userManagementProvider.notifier).fetchAll();
      }
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
        return 'Kalkulasi insentif sales distributor berbasis Sell-In, Sell-Out & Active Outlet (AO)';
      case 'INDUSTRI':
        return 'Kalkulasi insentif tim sales industri berbasis kuota volume (Kg) dan New Open Outlet (NOO)';
      case 'SURABAYA':
        return 'Kalkulasi insentif tim sales cabang Surabaya (SM, TO, dan ASC berbasis evaluasi tim)';
      default:
        return 'Eksekusi kalkulasi multi-tier berjenjang dan laporan insentif';
    }
  }

  Widget _buildAchievementBadge(double percent) {
    Color bg;
    Color textColor;
    String label = CurrencyFormatter.formatPercent(percent);

    if (percent < 90) {
      bg = context.semantic.danger.withValues(alpha: 0.15);
      textColor = context.semantic.danger;
    } else if (percent < 100) {
      bg = context.semantic.warning.withValues(alpha: 0.15);
      textColor = Theme.of(context).colorScheme.primary;
    } else if (percent < 120) {
      bg = context.semantic.success.withValues(alpha: 0.15);
      textColor = context.semantic.success;
    } else {
      bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.18);
      textColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
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
      final code = p.code.toUpperCase();
      if (activeKategori == 'INDUSTRI') {
        return eligiblePositionIds.contains(p.id) || code == 'ASM' || code == 'SPV' || code == 'ASC';
      }
      if (activeKategori == 'SURABAYA') {
        return eligiblePositionIds.contains(p.id) || code == 'ASC' || code == 'TO' || code == 'SM';
      }
      if (eligiblePositionIds.isNotEmpty) {
        return eligiblePositionIds.contains(p.id);
      }
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScreenSubtitle(activeKategori),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Messages
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.semantic.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, color: context.semantic.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.errorMessage!, style: TextStyle(color: context.semantic.danger, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (state.successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.semantic.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.checkCircle2, color: context.semantic.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.successMessage!, style: TextStyle(color: context.semantic.success, fontSize: 13))),
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
              borderRadius: BorderRadius.circular(12),
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
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.bgInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.borderMuted),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: eligiblePositions.any((p) => p.id == state.selectedPositionId)
                                  ? state.selectedPositionId
                                  : null,
                              dropdownColor: colors.bgCard,
                              style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              icon: Icon(LucideIcons.chevronDown, size: 16, color: colors.textSecondary),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Posisi Eligible', overflow: TextOverflow.ellipsis),
                                ),
                                ...eligiblePositions.map((pos) {
                                  final metricHint = activeKategori == 'INDUSTRI'
                                      ? ' (Sell-In & NOO)'
                                      : (activeKategori == 'SURABAYA'
                                          ? (pos.code.toUpperCase() == 'ASC'
                                              ? ' (Evaluasi Bawahan)'
                                              : ' (Penjualan Langsung)')
                                          : (pos.code.toUpperCase() == 'ASM'
                                              ? ' (Sell-In)'
                                              : (pos.code.toUpperCase() == 'SPV' ? ' (Sell-Out & AO)' : '')));
                                  return DropdownMenuItem<int?>(
                                    value: pos.id,
                                    child: Text(
                                      '${pos.code} - ${pos.name}$metricHint',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _cardsPage = 1);
                                notifier.setPosition(val);
                              },
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
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.bgInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.borderMuted),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: usersForSelectedPosition.any((u) => u.id == state.selectedUserId)
                                  ? state.selectedUserId
                                  : null,
                              dropdownColor: colors.bgCard,
                              style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
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
                              onChanged: (val) {
                                setState(() => _cardsPage = 1);
                                notifier.setUser(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 3. Periode (YYYYMM) — Mendukung pilih 1 atau beberapa periode sekaligus
                    Builder(
                      builder: (context) {
                        final selectedList = state.selectedPeriods;
                        final periods = <String>{
                          ...state.availablePeriods,
                          ...selectedList.where((p) => p.length == 6),
                        }.toList()
                          ..sort((a, b) => b.compareTo(a));
                        final displayLabel = selectedList.isEmpty
                            ? (periods.isNotEmpty ? periods.first : 'Pilih Periode')
                            : (selectedList.length == 1
                                ? selectedList.first
                                : (selectedList.length == periods.length && periods.length > 1
                                    ? 'Semua (${periods.length} Periode)'
                                    : '${selectedList.length} Periode (${selectedList.take(2).join(', ')}${selectedList.length > 2 ? '..' : ''})'));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('3. Periode (YYYYMM)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 215,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final picked = Set<String>.from(
                                    selectedList.isNotEmpty
                                        ? selectedList
                                        : (periods.isNotEmpty ? [periods.first] : <String>[]),
                                  );
                                  final res = await showDialog<List<String>>(
                                    context: context,
                                    builder: (ctx) => StatefulBuilder(
                                      builder: (ctx, setDialogState) => AlertDialog(
                                        backgroundColor: colors.bgElevated,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        title: Text(
                                          'Pilih Periode (Bisa > 1 Bulan)',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                        ),
                                        content: SizedBox(
                                          width: 320,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  TextButton(
                                                    onPressed: () => setDialogState(() => picked
                                                      ..clear()
                                                      ..addAll(periods)),
                                                    child: const Text('Pilih Semua'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => setDialogState(() {
                                                      picked.clear();
                                                      if (periods.isNotEmpty) picked.add(periods.first);
                                                    }),
                                                    child: const Text('Reset (Terbaru)'),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 8),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxHeight: 280),
                                                child: ListView(
                                                  shrinkWrap: true,
                                                  children: periods.map((p) {
                                                    final isChecked = picked.contains(p);
                                                    return CheckboxListTile(
                                                      dense: true,
                                                      value: isChecked,
                                                      activeColor: Theme.of(context).colorScheme.primary,
                                                      title: Text(p, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                                                      onChanged: (v) {
                                                        setDialogState(() {
                                                          if (v == true) {
                                                            picked.add(p);
                                                          } else if (picked.length > 1) {
                                                            picked.remove(p);
                                                          }
                                                        });
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text('Batal', style: TextStyle(color: colors.textMuted)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                                            onPressed: () => Navigator.pop(ctx, picked.toList()),
                                            child: const Text('Terapkan'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (res != null && res.isNotEmpty) {
                                    _periodController.text = res.join(',');
                                    notifier.setPeriods(res);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: colors.bgInput,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.borderMuted)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.borderMuted)),
                                    prefixIcon: Icon(LucideIcons.calendar, size: 15, color: colors.textSecondary),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    suffixIcon: Icon(LucideIcons.chevronDown, size: 16, color: colors.textSecondary),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                                  ),
                                  child: Text(
                                    displayLabel,
                                    style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        backgroundColor: context.semantic.successSolid,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: state.isExporting
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
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
              final isIndustri = activeKategori == 'INDUSTRI';
              final isSurabaya = activeKategori == 'SURABAYA';
              final indMeta = state.industriSummary;
              final sbyMeta = state.surabayaSummary;

              final List<Widget> kpiCards = isIndustri
                  ? [
                      _buildSummaryItem(
                        context,
                        title: 'Tim Sales Industri',
                        value: '${indMeta?.totalPersonil ?? state.industriCards.length} Personil',
                        icon: LucideIcons.users,
                        color: context.semantic.info,
                      ),
                      _buildSummaryItem(
                        context,
                        title: 'Total Sell-In (Kg)',
                        value: '${CurrencyFormatter.formatNumber(indMeta?.totalActualSellInKg ?? 0)} / ${CurrencyFormatter.formatNumber(indMeta?.totalTargetSellInKg ?? 0)}',
                        icon: LucideIcons.packageCheck,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      _buildSummaryItem(
                        context,
                        title: 'Realisasi NOO',
                        value: '${CurrencyFormatter.formatNumber(indMeta?.totalActualNoo ?? 0)} NOO (${CurrencyFormatter.formatNumber(indMeta?.totalActualNooKg ?? 0)} Kg)',
                        icon: LucideIcons.store,
                        color: context.semantic.success,
                      ),
                      _buildSummaryItem(
                        context,
                        title: 'Total Payout Industri',
                        value: CurrencyFormatter.formatRupiah(indMeta?.totalPayout ?? state.summary.totalReward),
                        icon: LucideIcons.wallet,
                        color: context.semantic.success,
                      ),
                    ]
                  : (isSurabaya
                      ? [
                          _buildSummaryItem(
                            context,
                            title: 'Tim Sales Surabaya',
                            value: '${sbyMeta?.totalPersonil ?? state.surabayaCards.length} Personil',
                            icon: LucideIcons.users,
                            color: context.semantic.info,
                          ),
                          _buildSummaryItem(
                            context,
                            title: 'Total Target (Kg)',
                            value: '${CurrencyFormatter.formatNumber(sbyMeta?.totalTargetKg ?? 0)} Kg',
                            icon: LucideIcons.target,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          _buildSummaryItem(
                            context,
                            title: 'Total Penjualan (Kg)',
                            value: '${CurrencyFormatter.formatNumber(sbyMeta?.totalActualKg ?? 0)} Kg',
                            icon: LucideIcons.packageCheck,
                            color: context.semantic.success,
                          ),
                          _buildSummaryItem(
                            context,
                            title: 'Total Payout Surabaya',
                            value: CurrencyFormatter.formatRupiah(sbyMeta?.totalPayout ?? state.summary.totalReward),
                            icon: LucideIcons.wallet,
                            color: context.semantic.success,
                          ),
                        ]
                      : [
                          _buildSummaryItem(context, title: 'Sales Berhak (Eligible)', value: '${state.summary.totalPersonil} Personil', icon: LucideIcons.users, color: context.semantic.info),
                          _buildSummaryItem(context, title: 'Total Kuota Target', value: '${CurrencyFormatter.formatNumber(state.summary.totalQuota)} Kg', icon: LucideIcons.target, color: Theme.of(context).colorScheme.primary),
                          _buildSummaryItem(context, title: 'Total Realisasi', value: '${CurrencyFormatter.formatNumber(state.summary.totalRealization)} Kg', icon: LucideIcons.checkCheck, color: context.semantic.success),
                          _buildSummaryItem(context, title: 'Akumulasi Reward Insentif', value: CurrencyFormatter.formatRupiah(state.summary.totalReward), icon: LucideIcons.wallet, color: context.semantic.success),
                        ]);

              return LayoutBuilder(
                builder: (context, kpiConstraints) {
                  final maxW = kpiConstraints.maxWidth;
                  final cols = maxW >= 980 ? 4 : (maxW >= 540 ? 2 : 1);
                  const spacing = 16.0;
                  final itemWidth = ((maxW - spacing * (cols - 1)) / cols).floorToDouble();
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: kpiCards
                        .map((card) => SizedBox(width: itemWidth, child: card))
                        .toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // View Selector & Data Header
          Container(
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(12),
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
                      final isNarrow = constraints.maxWidth < 960;
                      final isKonsumsi = activeKategori == 'KONSUMSI' || activeKategori == 'DISTRIBUTOR';
                      final isIndustri = activeKategori == 'INDUSTRI';
                      final isSurabaya = activeKategori == 'SURABAYA';
                      final hasBreakdown = isKonsumsi || isIndustri || isSurabaya;

                      final titleRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isKonsumsi && state.isBreakdownView
                                  ? 'Rincian Distributor, Depo & Area'
                                  : (isIndustri && state.isBreakdownView
                                      ? 'Audit Insentif Sales Industri'
                                      : (isSurabaya && state.isBreakdownView
                                          ? 'Audit Insentif Sales Surabaya'
                                          : 'Hasil Perhitungan Insentif Sales')),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              isKonsumsi && state.isBreakdownView
                                  ? '${state.breakdownCards.length} Depo'
                                  : (isIndustri && state.isBreakdownView
                                      ? '${state.industriCards.length} Personil'
                                      : (isSurabaya && state.isBreakdownView
                                          ? '${state.surabayaCards.length} Personil'
                                          : '${filteredResults.length} Baris')),
                              style: TextStyle(fontSize: 11, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      );

                      final viewToggle = hasBreakdown
                          ? Container(
                              decoration: BoxDecoration(
                                color: colors.bgSubtle,
                                borderRadius: BorderRadius.circular(8),
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
                                        color: state.isBreakdownView ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.layoutGrid, size: 14, color: state.isBreakdownView ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            isIndustri
                                                ? 'Kartu Audit Industri'
                                                : (isSurabaya ? 'Kartu Audit Surabaya' : 'Kartu Distributor'),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: state.isBreakdownView ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary),
                                          ),
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
                                        color: !state.isBreakdownView ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.table, size: 14, color: !state.isBreakdownView ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text('Tabel Personil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !state.isBreakdownView ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary)),
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
                                : (isIndustri && state.isBreakdownView
                                    ? 'Cari sales / posisi / customer...'
                                    : 'Cari nama sales...'),
                            hintStyle: TextStyle(color: colors.textMuted),
                            prefixIcon: Icon(LucideIcons.search, size: 16, color: colors.textSecondary),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: colors.bgInput,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.borderMuted)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.borderMuted)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                          ),
                          onChanged: (val) {
                            setState(() => _cardsPage = 1);
                            notifier.setSearchQuery(val);
                          },
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
                          Expanded(child: titleRow),
                          const SizedBox(width: 12),
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
                  Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)))
                else if ((activeKategori == 'KONSUMSI' || activeKategori == 'DISTRIBUTOR') && state.isBreakdownView)
                  _buildDistributorCardsView(context, state)
                else if (activeKategori == 'INDUSTRI' && state.isBreakdownView)
                  _buildIndustriBreakdownList(context, state)
                else if (activeKategori == 'SURABAYA' && state.isBreakdownView)
                  _buildSurabayaBreakdownList(context, state)
                else if (filteredResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calculator, size: 48, color: colors.textMuted),
                          const SizedBox(height: 16),
                          Text('Belum Ada Data Insentif pada Periode Ini', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                          const SizedBox(height: 6),
                          Text('Pilih periode lain atau pastikan Master Target & Realisasi sudah tersedia.', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
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
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: colors.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, maxLines: 1, style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                ),
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
      bg = context.semantic.dangerBg;
      text = context.semantic.danger;
    } else if (pct < 100) {
      bg = context.semantic.warningBg;
      text = context.semantic.warning;
    } else {
      bg = context.semantic.successBg;
      text = context.semantic.success;
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
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih periode, posisi ASM / SPV, atau personil sales di atas.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final totalCards = filteredCards.length;
    final totalPages = _cardsPerPage > 0 ? (totalCards / _cardsPerPage).ceil().clamp(1, 999999) : 1;
    final currentPage = _cardsPage.clamp(1, totalPages);
    final startIndex = _cardsPerPage > 0 ? (currentPage - 1) * _cardsPerPage : 0;
    final displayedCards = _cardsPerPage > 0
        ? filteredCards.skip(startIndex).take(_cardsPerPage).toList()
        : filteredCards;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedCards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final card = displayedCards[index];
              return _buildDepoCard(card, colors);
            },
          ),
          const SizedBox(height: 16),
          _buildPaginationBar(
            totalCards: totalCards,
            currentPage: currentPage,
            totalPages: totalPages,
            startIndex: startIndex,
            displayedCount: displayedCards.length,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalCards,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int displayedCount,
    required AppThemeColors colors,
    String unitLabel = 'Depo',
  }) {
    if (totalCards == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bgSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderMuted),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            'Menampilkan ${totalCards > 0 ? startIndex + 1 : 0} - ${startIndex + displayedCount} dari $totalCards $unitLabel',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Baris: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              DropdownButton<int>(
                value: _cardsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: colors.bgCard,
                style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: -1, child: Text('Semua')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _cardsPerPage = val;
                      _cardsPage = 1;
                    });
                  }
                },
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(LucideIcons.chevronsLeft, size: 15),
                tooltip: 'Halaman Pertama',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: currentPage > 1 ? () => setState(() => _cardsPage = 1) : null,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 15),
                tooltip: 'Halaman Sebelumnya',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: currentPage > 1 ? () => setState(() => _cardsPage = currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 15),
                tooltip: 'Halaman Selanjutnya',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: currentPage < totalPages ? () => setState(() => _cardsPage = currentPage + 1) : null,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(LucideIcons.chevronsRight, size: 15),
                tooltip: 'Halaman Terakhir',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: currentPage < totalPages ? () => setState(() => _cardsPage = totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepoCard(DistributorBreakdownCardModel card, AppThemeColors colors) {
    final isExpanded = _expandedCardIds.contains(card.id);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clickable Card Header
          InkWell(
            borderRadius: BorderRadius.circular(12),
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
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(LucideIcons.store, size: 16, color: Theme.of(context).colorScheme.primary),
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            Icon(LucideIcons.arrowRight, size: 14, color: colors.textMuted),
                            Text(
                              'Depo: ${card.depoName}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Brand: ${card.brandName}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
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
                                  color: card.sellInAchPct >= 100 ? context.semantic.success : colors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: '➔ ${CurrencyFormatter.formatRupiah(card.sellInReward)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.semantic.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.semantic.success.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Total: ${CurrencyFormatter.formatRupiah(card.totalDepoReward)}',
                          style: TextStyle(
                            color: context.semantic.success,
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
                          color: context.semantic.success,
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
                    headingTextStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.textSecondary),
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
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
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
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                area.brandName,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
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
                                      '${CurrencyFormatter.formatNumber(area.sellOutReal)} / ${CurrencyFormatter.formatNumber(area.sellOutTarget)} Kg',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMiniBadge(area.sellOutAchPct),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(area.sellOutReward),
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.semantic.warning),
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
                                      '${CurrencyFormatter.formatNumber(area.aoReal.toDouble())} / ${CurrencyFormatter.formatNumber(area.aoTarget.toDouble())} Toko',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMiniBadge(area.aoAchPct),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatRupiah(area.aoReward),
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.semantic.warning),
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
                                color: area.subtotalAreaReward > 0 ? context.semantic.success : colors.textSecondary,
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
      minWidth: 900,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgSubtle),
        columnSpacing: 12,
        horizontalMargin: 10,
        headingTextStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textSecondary),
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
          final isNoo = item.metricType.toUpperCase() == 'NOO';
          final isAo = item.metricType.toUpperCase().contains('AO') || item.metricType.toUpperCase().contains('OUTLET');
          final unitLabel = isNoo ? 'NOO' : (isAo ? 'Toko' : 'Kg');
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        item.user?.name.isNotEmpty == true ? item.user!.name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
                            ? context.semantic.warning.withValues(alpha: 0.14)
                            : context.semantic.info.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.metricType.isNotEmpty ? item.metricType : 'Target',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAo ? context.semantic.warning : context.semantic.info,
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
                    color: item.isRateBased ? context.semantic.info.withValues(alpha: 0.12) : context.semantic.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isRateBased ? 'Rate (${CurrencyFormatter.formatRate(item.unitRate)}/$unitLabel)' : 'Lump Sum',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: item.isRateBased ? context.semantic.info : context.semantic.warning),
                  ),
                ),
              ),
              DataCell(Text(CurrencyFormatter.formatPercent(item.headerBobotPercent), style: TextStyle(color: colors.textSecondary))),
              DataCell(
                Text(CurrencyFormatter.formatRupiah(item.finalReward), style: TextStyle(color: context.semantic.success, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIndustriBreakdownList(BuildContext context, IncentiveCalculationState state) {
    final colors = context.colors;
    final query = state.searchQuery.trim().toLowerCase();

    final filteredCards = state.industriCards.where((card) {
      if (query.isEmpty) return true;
      final inName = card.userName.toLowerCase().contains(query);
      final inUser = card.username.toLowerCase().contains(query);
      final inPos = card.positionCode.toLowerCase().contains(query) || card.positionName.toLowerCase().contains(query);
      final inCustomers = card.customers.any((c) =>
          c.customerName.toLowerCase().contains(query) ||
          c.customerCode.toLowerCase().contains(query) ||
          (c.city ?? '').toLowerCase().contains(query));
      return inName || inUser || inPos || inCustomers;
    }).toList();

    if (filteredCards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.factory, size: 48, color: colors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Rincian Audit Insentif Industri',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih periode, posisi (ASM / SPV / ASC), atau personil sales di atas.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final totalCards = filteredCards.length;
    final totalPages = _cardsPerPage > 0 ? (totalCards / _cardsPerPage).ceil().clamp(1, 999999) : 1;
    final currentPage = _cardsPage.clamp(1, totalPages);
    final startIndex = _cardsPerPage > 0 ? (currentPage - 1) * _cardsPerPage : 0;
    final displayedCards = _cardsPerPage > 0
        ? filteredCards.skip(startIndex).take(_cardsPerPage).toList()
        : filteredCards;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedCards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildIndustriCard(displayedCards[index], colors),
          ),
          const SizedBox(height: 16),
          _buildPaginationBar(
            totalCards: totalCards,
            currentPage: currentPage,
            totalPages: totalPages,
            startIndex: startIndex,
            displayedCount: displayedCards.length,
            colors: colors,
            unitLabel: 'Personil',
          ),
        ],
      ),
    );
  }

  Widget _buildIndustriCard(IndustriBreakdownCardModel card, AppThemeColors colors) {
    final expandKey = -card.userId;
    final isExpanded = _expandedCardIds.contains(expandKey);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.isEligibleIndustri ? colors.border : context.semantic.danger.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCardIds.remove(expandKey);
                } else {
                  _expandedCardIds.add(expandKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isCompactHeader = headerConstraints.maxWidth < 620;
                      final totalBadge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.semantic.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.semantic.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: isCompactHeader ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Grand Total Insentif', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                            Text(
                              CurrencyFormatter.formatRupiah(card.totalReward),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.semantic.success),
                            ),
                          ],
                        ),
                      );

                      final identityRow = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                            child: Text(
                              card.userName.isNotEmpty ? card.userName[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  card.userName,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                ),
                                Text(
                                  '@${card.username}',
                                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.semantic.info.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${card.positionCode} - ${card.positionName}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.semantic.info),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (card.isEligibleIndustri ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    card.isEligibleIndustri
                                        ? 'Eligible Industri'
                                        : (card.ineligibilityReason ?? 'Tidak Eligible Industri'),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: card.isEligibleIndustri ? context.semantic.success : context.semantic.danger,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.bgSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.borderMuted),
                                  ),
                                  child: Text(
                                    '${card.assignedCustomersCount} Customer Assigned',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isCompactHeader) ...[
                            const SizedBox(width: 12),
                            totalBadge,
                          ],
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      );

                      if (isCompactHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            identityRow,
                            const SizedBox(height: 10),
                            totalBadge,
                          ],
                        );
                      }
                      return identityRow;
                    },
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 780;
                      final sellInPanel = _buildIndustriMethodPanel(
                        methodData: card.sellIn,
                        title: 'SELL-IN (Volume Kg)',
                        icon: LucideIcons.packageCheck,
                        accent: context.semantic.info,
                        isNooMethod: false,
                        period: card.period,
                        colors: colors,
                      );
                      final nooPanel = _buildIndustriMethodPanel(
                        methodData: card.noo,
                        title: 'NOO (New Open Outlet)',
                        icon: LucideIcons.sparkles,
                        accent: Theme.of(context).colorScheme.primary,
                        isNooMethod: true,
                        period: card.period,
                        colors: colors,
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sellInPanel),
                            const SizedBox(width: 14),
                            Expanded(child: nooPanel),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          sellInPanel,
                          const SizedBox(height: 12),
                          nooPanel,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isExpanded
                        ? 'Klik untuk sembunyikan rincian ${card.customers.length} transaksi customer'
                        : 'Klik kartu untuk audit ${card.customers.length} customer & riwayat status NOO',
                    style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: colors.border),
            if (card.customers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Belum ada transaksi customer industri ter-assign untuk sales ini pada periode ${card.period}.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(colors.bgSubtle),
                    headingTextStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.textSecondary),
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: double.infinity,
                    columns: const [
                      DataColumn(label: Text('Kode Customer')),
                      DataColumn(label: Text('Nama Customer')),
                      DataColumn(label: Text('Kota')),
                      DataColumn(label: Text('Tipe Master')),
                      DataColumn(label: Text('Jml TX')),
                      DataColumn(label: Text('Volume (Kg)')),
                      DataColumn(label: Text('Nominal (Rp)')),
                      DataColumn(label: Text('Status NOO & Audit')),
                    ],
                    rows: card.customers.map((c) {
                      return DataRow(
                        cells: [
                          DataCell(Text(c.customerCode, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(c.customerName, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                            ),
                          ),
                          DataCell(Text(c.city ?? '-', style: TextStyle(color: colors.textSecondary, fontSize: 12))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (c.customerType == 'NEW' ? context.semantic.success : context.semantic.info).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                c.customerType,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: c.customerType == 'NEW' ? context.semantic.success : context.semantic.info,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('${c.txCount}x', style: TextStyle(color: colors.textSecondary, fontSize: 12))),
                          DataCell(Text('${CurrencyFormatter.formatNumber(c.volumeKg)} Kg', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5))),
                          DataCell(Text(CurrencyFormatter.formatRupiah(c.nominal), style: TextStyle(color: context.semantic.success, fontSize: 12))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (c.isNoo ? context.semantic.success : colors.bgSubtle).withValues(alpha: c.isNoo ? 0.15 : 1),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: c.isNoo ? context.semantic.success.withValues(alpha: 0.4) : colors.borderMuted),
                                  ),
                                  child: Text(
                                    c.isNoo ? 'NOO' : 'Repeat Order',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: c.isNoo ? context.semantic.success : colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  child: Text(
                                    c.nooReason,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                                  ),
                                ),
                              ],
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

  Widget _buildIndustriMethodPanel({
    required IndustriMethodBreakdownModel? methodData,
    required String title,
    required IconData icon,
    required Color accent,
    required bool isNooMethod,
    required String period,
    required AppThemeColors colors,
  }) {
    final unit = isNooMethod ? 'NOO' : 'Kg';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSubtle.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderMuted),
      ),
      child: methodData == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Skema atau target $title belum dikonfigurasi untuk periode $period.',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: accent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (methodData.isPassed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        methodData.isPassed
                            ? 'LOLOS >= ${methodData.minAchievementPct.toStringAsFixed(0)}%'
                            : (methodData.minAchievementPct > 0
                                ? 'TIDAK LOLOS (< ${methodData.minAchievementPct.toStringAsFixed(0)}%)'
                                : 'BELUM TERCAPAI'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: methodData.isPassed ? context.semantic.success : context.semantic.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Target: ${CurrencyFormatter.formatNumber(methodData.targetQuota)} $unit',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      isNooMethod
                          ? 'Real: ${CurrencyFormatter.formatNumber(methodData.actualRealization)} NOO (${CurrencyFormatter.formatNumber(methodData.actualVolumeKg)} Kg)'
                          : 'Real: ${CurrencyFormatter.formatNumber(methodData.actualRealization)} Kg',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ach: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        _buildMiniBadge(methodData.achievementPercent),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade ${methodData.gradeName ?? '-'} • Rate ${CurrencyFormatter.formatRate(methodData.multiplierRate)}/Kg • Bobot ${methodData.headerWeightPct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        methodData.isPassed
                            ? 'Tanpa Cap: ${CurrencyFormatter.formatNumber(methodData.actualVolumeKg)} Kg × ${CurrencyFormatter.formatRate(methodData.multiplierRate)} × ${methodData.headerWeightPct.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(methodData.finalReward)}'
                            : (methodData.minAchievementPct > 0
                                ? 'Reward: Rp 0 (Achievement belum memenuhi batas minimal ${methodData.minAchievementPct.toStringAsFixed(0)}%)'
                                : 'Reward: Rp 0 (Target belum tercapai atau skema belum dikonfigurasi)'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: methodData.isPassed ? context.semantic.success : context.semantic.danger,
                        ),
                      ),
                      if (methodData.auditNotes != null && methodData.auditNotes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          methodData.auditNotes!,
                          style: TextStyle(fontSize: 11, color: colors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatRateRupiah(double rate) {
    if (rate % 1 == 0) {
      return CurrencyFormatter.formatRupiah(rate);
    }
    return 'Rp ${rate.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Widget _buildSurabayaBreakdownList(BuildContext context, IncentiveCalculationState state) {
    final colors = context.colors;
    final query = state.searchQuery.trim().toLowerCase();

    final filteredCards = state.surabayaCards.where((card) {
      if (query.isEmpty) return true;
      final inName = card.userName.toLowerCase().contains(query) || card.username.toLowerCase().contains(query);
      final inPos = card.positionCode.toLowerCase().contains(query) || card.positionName.toLowerCase().contains(query);
      final inAsc = (card.ascName ?? '').toLowerCase().contains(query);
      final inSubs = card.subordinates.any((s) =>
          s.salesName.toLowerCase().contains(query) ||
          s.username.toLowerCase().contains(query) ||
          s.positionCode.toLowerCase().contains(query));
      return inName || inPos || inAsc || inSubs;
    }).toList();

    if (filteredCards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.truck, size: 48, color: colors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Rincian Audit Insentif Surabaya',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih periode, posisi (ASC / TO / SM), atau personil sales di atas.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                textAlign: TextAlign.center,
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
        itemBuilder: (context, index) => _buildSurabayaCard(filteredCards[index], colors),
      ),
    );
  }

  Widget _buildSurabayaCard(SurabayaBreakdownCardModel card, AppThemeColors colors) {
    final isAsc = card.positionCode.toUpperCase() == 'ASC';

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.isEligibleSurabaya ? colors.border : context.semantic.danger.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: colors.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isCompactHeader = headerConstraints.maxWidth < 620;
                final totalBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.semantic.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.semantic.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: isCompactHeader ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isAsc ? 'Grand Total Insentif ASC' : 'Total Insentif',
                        style: TextStyle(fontSize: 10, color: colors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.formatRupiah(card.totalReward),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.semantic.success),
                      ),
                    ],
                  ),
                );

                final identityRow = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: (isAsc ? context.semantic.warning : Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
                      child: Text(
                        card.userName.isNotEmpty ? card.userName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isAsc ? context.semantic.warning : Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            card.userName,
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          Text('@${card.username}', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isAsc ? context.semantic.warning : context.semantic.info).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${card.positionCode} - ${card.positionName}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isAsc ? context.semantic.warning : context.semantic.info),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (card.isEligibleSurabaya ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              card.isEligibleSurabaya ? 'Eligible Surabaya' : (card.ineligibilityReason ?? 'Tidak Eligible Surabaya'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: card.isEligibleSurabaya ? context.semantic.success : context.semantic.danger,
                              ),
                            ),
                          ),
                          if (!isAsc && card.ascName != null && card.ascName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.bgSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.borderMuted),
                              ),
                              child: Text(
                                'Atasan ASC: ${card.ascName}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                              ),
                            ),
                          if (isAsc)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.bgSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.borderMuted),
                              ),
                              child: Text(
                                '${card.subordinatesCount} Bawahan (TO/SM)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isCompactHeader) ...[
                      const SizedBox(width: 12),
                      totalBadge,
                    ],
                  ],
                );

                if (isCompactHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identityRow,
                      const SizedBox(height: 10),
                      totalBadge,
                    ],
                  );
                }
                return identityRow;
              },
            ),
            const SizedBox(height: 14),
            if (isAsc) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bgSubtle.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderMuted),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Breakdown Evaluasi Bawahan (${card.headerName ?? 'Setting ASC'})',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        Text(
                          'Min. Achievement ASC: ${card.minAchievementPct.toStringAsFixed(0)}% • Bobot Header: ${card.headerWeightPct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (card.subordinates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Belum ada bawahan TO / SM yang di-assign ke ASC ini pada periode ${card.period}.',
                          style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(colors.bgCard),
                          headingTextStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.textSecondary),
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: double.infinity,
                          columns: const [
                            DataColumn(label: Text('Nama Bawahan')),
                            DataColumn(label: Text('Posisi')),
                            DataColumn(label: Text('Target (Kg)')),
                            DataColumn(label: Text('Aktual (Kg)')),
                            DataColumn(label: Text('% Capai')),
                            DataColumn(label: Text('Status Target')),
                            DataColumn(label: Text('Grade ASC')),
                            DataColumn(label: Text('Bobot ASC')),
                            DataColumn(label: Text('Bobot Header')),
                            DataColumn(label: Text('Kontribusi Insentif ASC')),
                          ],
                          rows: [
                            ...card.subordinates.map((sub) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(sub.salesName, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary, fontSize: 12.5))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: context.semantic.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                                      child: Text(sub.positionCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.semantic.info)),
                                    ),
                                  ),
                                  DataCell(Text(CurrencyFormatter.formatNumber(sub.targetKg), style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
                                  DataCell(Text(CurrencyFormatter.formatNumber(sub.actualKg), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                                  DataCell(_buildMiniBadge(sub.achievementPercent)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (sub.isPassed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        sub.statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: sub.isPassed ? context.semantic.success : context.semantic.danger,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(sub.gradeName ?? '-', style: TextStyle(color: colors.textSecondary, fontSize: 12))),
                                  DataCell(Text(_formatRateRupiah(sub.multiplierRate), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                                  DataCell(Text('${sub.headerWeightPct.toStringAsFixed(0)}%', style: TextStyle(color: colors.textSecondary, fontSize: 12))),
                                  DataCell(
                                    Text(
                                      CurrencyFormatter.formatRupiah(sub.contributionReward),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: sub.contributionReward > 0 ? context.semantic.success : colors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            DataRow(
                              color: WidgetStateProperty.all(context.semantic.success.withValues(alpha: 0.08)),
                              cells: [
                                DataCell(Text('GRAND TOTAL INSENTIF ASC (${card.userName})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: context.semantic.success))),
                                const DataCell(Text('')),
                                DataCell(Text(CurrencyFormatter.formatNumber(card.targetKg), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
                                DataCell(Text(CurrencyFormatter.formatNumber(card.actualKg), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary))),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                                DataCell(Text(CurrencyFormatter.formatRupiah(card.totalReward), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.semantic.success))),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.bgSubtle.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderMuted),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Penjualan Langsung (${card.positionCode})',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (card.isPassed ? context.semantic.success : context.semantic.danger).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card.isPassed
                                ? 'LOLOS >= ${card.minAchievementPct.toStringAsFixed(0)}%'
                                : (card.minAchievementPct > 0
                                    ? 'TIDAK LOLOS (< ${card.minAchievementPct.toStringAsFixed(0)}%)'
                                    : 'BELUM TERCAPAI'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: card.isPassed ? context.semantic.success : context.semantic.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        Text('Target: ${CurrencyFormatter.formatNumber(card.targetKg)} Kg', style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                        Text('Aktual: ${CurrencyFormatter.formatNumber(card.actualKg)} Kg', style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w700)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ach: ', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                            _buildMiniBadge(card.achievementPercent),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grade ${card.gradeName ?? '-'} • Tarif ${_formatRateRupiah(card.multiplierRate)}/Kg • Bobot Header ${card.headerWeightPct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11.5, color: colors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.isPassed
                                ? '${CurrencyFormatter.formatNumber(card.actualKg)} Kg × ${_formatRateRupiah(card.multiplierRate)} × ${card.headerWeightPct.toStringAsFixed(0)}% = ${CurrencyFormatter.formatRupiah(card.totalReward)}'
                                : (card.minAchievementPct > 0
                                    ? 'Reward: Rp 0 (Achievement belum memenuhi batas minimal ${card.minAchievementPct.toStringAsFixed(0)}%)'
                                    : 'Reward: Rp 0 (Target belum tercapai atau skema belum dikonfigurasi)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: card.isPassed ? context.semantic.success : context.semantic.danger,
                            ),
                          ),
                          if (card.auditNotes != null && card.auditNotes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              card.auditNotes!,
                              style: TextStyle(fontSize: 11, color: colors.textMuted, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

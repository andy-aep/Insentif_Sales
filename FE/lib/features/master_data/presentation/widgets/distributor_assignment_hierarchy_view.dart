import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/auth_user_model.dart';
import '../../../../data/models/master_model.dart';
import '../../../users_management/providers/user_management_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/sales_assignment_provider.dart';

class DistributorAssignmentHierarchyView extends ConsumerStatefulWidget {
  final Widget Function() legacyTableBuilder;

  const DistributorAssignmentHierarchyView({
    super.key,
    required this.legacyTableBuilder,
  });

  @override
  ConsumerState<DistributorAssignmentHierarchyView> createState() =>
      _DistributorAssignmentHierarchyViewState();
}

class _DistributorAssignmentHierarchyViewState
    extends ConsumerState<DistributorAssignmentHierarchyView> {
  String _viewMode = 'BY_DISTRIBUTOR'; // BY_DISTRIBUTOR | BY_SALES | FLAT_TABLE
  String _selectedPeriod = '';
  int? _filterDistributorId;
  String _statusFilter = 'ALL'; // ALL | INCOMPLETE | COMPLETE
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _page = 1;
  int _perPage = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _extractPeriods(List<SalesDistributorAssignmentModel> list) {
    final set = <String>{};
    for (final a in list) {
      final p = a.period.trim();
      if (p.length == 6) set.add(p);
    }
    final sorted = set.toList()..sort((a, b) => b.compareTo(a));
    if (sorted.isEmpty) sorted.add('202610');
    return sorted;
  }

  void _showBulkMapDialog({
    required DistributorModel distributor,
    required List<DepoModel> depos,
    required Map<int, List<AreaModel>> areasByDepo,
    required int? initialAsmUserId,
    required Map<int, int?> initialSpvByArea,
    required String defaultPeriod,
  }) {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);

    final allUsers = List<UserModel>.from(userState.users)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final asmCandidates = allUsers.where((u) {
      final pos = (u.position?.code ?? '').toUpperCase();
      return pos == 'ASM' || (u.isEligibleKonsumsi && pos.isEmpty);
    }).toList();
    final asmList = asmCandidates.isNotEmpty ? asmCandidates : allUsers;

    final spvCandidates = allUsers.where((u) {
      final pos = (u.position?.code ?? '').toUpperCase();
      return pos == 'SPV' || pos == 'ASC' || (u.isEligibleKonsumsi && pos.isEmpty);
    }).toList();
    final spvList = spvCandidates.isNotEmpty ? spvCandidates : allUsers;

    int? selectedAsmId = asmList.any((u) => u.id == initialAsmUserId) ? initialAsmUserId : null;
    final Map<int, int?> selectedSpvByArea = {};
    for (final depo in depos) {
      for (final area in (areasByDepo[depo.id] ?? const <AreaModel>[])) {
        final initSpv = initialSpvByArea[area.id];
        selectedSpvByArea[area.id] = spvList.any((u) => u.id == initSpv) ? initSpv : null;
      }
    }

    final cleanPeriod = (defaultPeriod.isNotEmpty && defaultPeriod != 'ALL') ? defaultPeriod : '202610';
    final periodCtrl = TextEditingController(text: cleanPeriod);
    final yearCtrl = TextEditingController(
      text: cleanPeriod.length >= 4 ? cleanPeriod.substring(0, 4) : '2026',
    );
    bool isFullYear = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final totalAreas = depos.fold<int>(0, (sum, dp) => sum + (areasByDepo[dp.id]?.length ?? 0));

          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.users, size: 20, color: AppColors.primaryLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atur PIC: ${distributor.name}',
                        style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${distributor.code} • ${depos.length} Depo • $totalAreas Area',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Periode berlaku (1 Bulan vs Setahun 12 Bulan)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDialogState(() => isFullYear = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: !isFullYear ? AppColors.primary.withValues(alpha: 0.14) : colors.bgElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: !isFullYear ? AppColors.primary : colors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.calendar, size: 14, color: !isFullYear ? AppColors.primary : colors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    '1 Bulan (YYYYMM)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !isFullYear ? FontWeight.bold : FontWeight.normal,
                                      color: !isFullYear ? colors.textPrimary : colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDialogState(() => isFullYear = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: isFullYear ? AppColors.primary.withValues(alpha: 0.14) : colors.bgElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isFullYear ? AppColors.primary : colors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.calendarRange, size: 14, color: isFullYear ? AppColors.primary : colors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Setahun Penuh (12 Bulan)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isFullYear ? FontWeight.bold : FontWeight.normal,
                                      color: isFullYear ? colors.textPrimary : colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: isFullYear ? yearCtrl : periodCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: isFullYear ? 4 : 6,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: '',
                              labelText: isFullYear ? 'Tahun' : 'Periode',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              filled: true,
                              fillColor: colors.bgElevated,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. ASM Penanggung Jawab Distributor
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.crown, size: 16, color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              Text(
                                '1. ASM Penanggung Jawab Distributor',
                                style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            initialValue: selectedAsmId,
                            isExpanded: true,
                            dropdownColor: colors.bgCard,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(LucideIcons.userCheck, size: 16),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              filled: true,
                              fillColor: colors.bgCard,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('— Kosongkan / Belum Ada ASM —', overflow: TextOverflow.ellipsis),
                              ),
                              ...asmList.map(
                                (u) => DropdownMenuItem<int?>(
                                  value: u.id,
                                  child: Text(
                                    '${u.name} (@${u.username})${u.position != null ? ' • ${u.position!.code}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) => setDialogState(() => selectedAsmId = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. SPV / ASC per Depo & Area
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 16, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '2. SPV / ASC Penanggung Jawab Area ($totalAreas Area)',
                                  style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (depos.isEmpty)
                            Text(
                              'Belum ada Depo & Area terdaftar untuk Distributor ini.',
                              style: TextStyle(color: colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                            )
                          else
                            ...depos.map((dp) {
                              final dpAreas = areasByDepo[dp.id] ?? const <AreaModel>[];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.bgCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(LucideIcons.home, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Depo: ${dp.name} (${dp.code})',
                                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (dpAreas.isEmpty)
                                      Text('Belum ada Area di Depo ini.', style: TextStyle(color: colors.textMuted, fontSize: 11.5))
                                    else
                                      ...dpAreas.map((area) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      area.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                                                    ),
                                                    Text(area.code, style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 6,
                                                child: DropdownButtonFormField<int?>(
                                                  initialValue: selectedSpvByArea[area.id],
                                                  isExpanded: true,
                                                  dropdownColor: colors.bgCard,
                                                  style: TextStyle(color: colors.textPrimary, fontSize: 12),
                                                  decoration: InputDecoration(
                                                    prefixIcon: const Icon(LucideIcons.user, size: 14),
                                                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                    filled: true,
                                                    fillColor: colors.bgInput,
                                                    isDense: true,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  items: [
                                                    const DropdownMenuItem<int?>(
                                                      value: null,
                                                      child: Text('— Vacant (Belum Ada SPV) —', overflow: TextOverflow.ellipsis),
                                                    ),
                                                    ...spvList.map(
                                                      (u) => DropdownMenuItem<int?>(
                                                        value: u.id,
                                                        child: Text(
                                                          '${u.name} (${u.position?.code ?? 'SPV'})',
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (val) => setDialogState(() => selectedSpvByArea[area.id] = val),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: colors.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSaving
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(
                  isSaving ? 'Menyimpan...' : (isFullYear ? 'Simpan Pemetaan (12 Bulan)' : 'Simpan Pemetaan'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final areasPayload = <Map<String, dynamic>>[];
                        for (final dp in depos) {
                          for (final area in (areasByDepo[dp.id] ?? const <AreaModel>[])) {
                            areasPayload.add({
                              'depo_id': dp.id,
                              'area_id': area.id,
                              'spv_user_id': selectedSpvByArea[area.id],
                            });
                          }
                        }

                        final ok = await ref.read(salesAssignmentProvider.notifier).saveDistributorMappingBundle(
                              distributorId: distributor.id,
                              period: periodCtrl.text.trim().isEmpty ? '202610' : periodCtrl.text.trim(),
                              isFullYear: isFullYear,
                              year: yearCtrl.text.trim(),
                              asmUserId: selectedAsmId,
                              areas: areasPayload,
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          final st = ref.read(salesAssignmentProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? (st.successMessage ?? 'Pemetaan PIC berhasil disimpan')
                                  : (st.errorMessage ?? 'Gagal menyimpan pemetaan')),
                              backgroundColor: ok ? AppColors.success : AppColors.danger,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final assignState = ref.watch(salesAssignmentProvider);
    final masterState = ref.watch(masterDataProvider);
    final assignments = assignState.distributorAssignments;

    final availablePeriods = _extractPeriods(assignments);
    final activePeriod = _selectedPeriod.isEmpty ? availablePeriods.first : _selectedPeriod;

    // Filter assignments by active period
    final scopedAssignments = activePeriod == 'ALL'
        ? assignments
        : assignments.where((a) => a.period == activePeriod).toList();

    // Build lookup maps for current period:
    // ASM by distributor_id & SPV by area_id
    final Map<int, SalesDistributorAssignmentModel> asmByDist = {};
    final Map<int, SalesDistributorAssignmentModel> spvByArea = {};
    for (final a in scopedAssignments) {
      if (!a.isActive) continue;
      final pos = (a.user?.position?.code ?? '').toUpperCase();
      if (a.areaId != null) {
        spvByArea.putIfAbsent(a.areaId!, () => a);
      } else if (a.distributorId != null && (pos == 'ASM' || pos.isEmpty)) {
        asmByDist.putIfAbsent(a.distributorId!, () => a);
      }
    }

    // Build sorted Distributors + Depos + Areas from masterDataProvider
    final allDistributors = List<DistributorModel>.from(masterState.distributors)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final Map<int, List<DepoModel>> deposByDist = {};
    for (final dp in masterState.depos) {
      if (dp.distributorId != null) {
        deposByDist.putIfAbsent(dp.distributorId!, () => []).add(dp);
      }
    }
    for (final dist in allDistributors) {
      if ((deposByDist[dist.id] ?? []).isEmpty && dist.depos.isNotEmpty) {
        deposByDist[dist.id] = List<DepoModel>.from(dist.depos);
      }
      deposByDist[dist.id]?.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final Map<int, List<AreaModel>> areasByDepo = {};
    for (final ar in masterState.areas) {
      if (ar.depoId != null) {
        areasByDepo.putIfAbsent(ar.depoId!, () => []).add(ar);
      }
    }
    for (final dpList in deposByDist.values) {
      for (final dp in dpList) {
        if ((areasByDepo[dp.id] ?? []).isEmpty && dp.areas.isNotEmpty) {
          areasByDepo[dp.id] = List<AreaModel>.from(dp.areas);
        }
        areasByDepo[dp.id]?.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    }

    // KPI counts
    int totalDistWithAsm = 0;
    int totalAreasCount = 0;
    int totalAreasMapped = 0;
    for (final d in allDistributors) {
      if (asmByDist.containsKey(d.id)) totalDistWithAsm++;
      for (final dp in (deposByDist[d.id] ?? const <DepoModel>[])) {
        for (final ar in (areasByDepo[dp.id] ?? const <AreaModel>[])) {
          totalAreasCount++;
          if (spvByArea.containsKey(ar.id)) totalAreasMapped++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Row
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiTile(context, 'Total Distributor', '${allDistributors.length} Distributor', LucideIcons.building2, AppColors.primary),
            _kpiTile(context, 'ASM Terpetakan', '$totalDistWithAsm / ${allDistributors.length} Dist', LucideIcons.crown, AppColors.success),
            _kpiTile(context, 'Area Terpetakan', '$totalAreasMapped / $totalAreasCount Area', LucideIcons.mapPin, AppColors.warning),
            _kpiTile(context, 'Belum Ada PIC', '${(allDistributors.length - totalDistWithAsm) + (totalAreasCount - totalAreasMapped)} Slot', LucideIcons.alertCircle, AppColors.danger),
          ],
        ),
        const SizedBox(height: 16),

        // View Mode Toggle + Filters Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Mode Toggle Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _modeChip('BY_DISTRIBUTOR', 'Per Distributor', LucideIcons.building2),
                  _modeChip('BY_SALES', 'Per Sales', LucideIcons.users),
                  _modeChip('FLAT_TABLE', 'Tabel Datar', LucideIcons.table),
                ],
              ),

              if (_viewMode != 'FLAT_TABLE')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Period Dropdown
                    SizedBox(
                      width: 155,
                      child: DropdownButtonFormField<String>(
                        initialValue: availablePeriods.contains(activePeriod) || activePeriod == 'ALL' ? activePeriod : availablePeriods.first,
                        isExpanded: true,
                        dropdownColor: colors.bgCard,
                        style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.calendar, size: 14, color: AppColors.primary),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          filled: true,
                          fillColor: colors.bgCard,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('Semua Periode', overflow: TextOverflow.ellipsis)),
                          ...availablePeriods.map(
                            (p) => DropdownMenuItem(value: p, child: Text('Periode $p', overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedPeriod = v;
                              _page = 1;
                            });
                          }
                        },
                      ),
                    ),
                    if (_viewMode == 'BY_DISTRIBUTOR') ...[
                      // Filter Distributor
                      SizedBox(
                        width: 215,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _filterDistributorId,
                          isExpanded: true,
                          dropdownColor: colors.bgCard,
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                          decoration: InputDecoration(
                            prefixIcon: Icon(LucideIcons.building, size: 14, color: colors.textMuted),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            filled: true,
                            fillColor: colors.bgCard,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Semua Distributor', overflow: TextOverflow.ellipsis)),
                            ...allDistributors.map(
                              (d) => DropdownMenuItem<int?>(value: d.id, child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis)),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _filterDistributorId = v;
                            _page = 1;
                          }),
                        ),
                      ),
                      // Status PIC Filter
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String>(
                          initialValue: _statusFilter,
                          isExpanded: true,
                          dropdownColor: colors.bgCard,
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                          decoration: InputDecoration(
                            prefixIcon: Icon(LucideIcons.filter, size: 14, color: colors.textMuted),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            filled: true,
                            fillColor: colors.bgCard,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Status PIC', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'INCOMPLETE', child: Text('Belum Lengkap / Vacant', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'COMPLETE', child: Text('Sudah Lengkap', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _statusFilter = v;
                                _page = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                    // Live Search
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() {
                          _searchQuery = v.trim().toLowerCase();
                          _page = 1;
                        }),
                        style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Cari distributor / area / sales...',
                          prefixIcon: Icon(LucideIcons.search, size: 14, color: colors.textMuted),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          filled: true,
                          fillColor: colors.bgCard,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content according to View Mode
        if (_viewMode == 'FLAT_TABLE')
          widget.legacyTableBuilder()
        else if (_viewMode == 'BY_SALES')
          _buildBySalesView(context, scopedAssignments, activePeriod)
        else
          _buildByDistributorView(
            context,
            allDistributors: allDistributors,
            deposByDist: deposByDist,
            areasByDepo: areasByDepo,
            asmByDist: asmByDist,
            spvByArea: spvByArea,
            activePeriod: activePeriod,
          ),
      ],
    );
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final selected = _viewMode == mode;
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _viewMode = mode;
        _page = 1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : colors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiTile(BuildContext context, String label, String value, IconData icon, Color color) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11)),
              Text(value, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildByDistributorView(
    BuildContext context, {
    required List<DistributorModel> allDistributors,
    required Map<int, List<DepoModel>> deposByDist,
    required Map<int, List<AreaModel>> areasByDepo,
    required Map<int, SalesDistributorAssignmentModel> asmByDist,
    required Map<int, SalesDistributorAssignmentModel> spvByArea,
    required String activePeriod,
  }) {
    final colors = context.colors;

    final filtered = allDistributors.where((d) {
      if (_filterDistributorId != null && d.id != _filterDistributorId) return false;
      final depos = deposByDist[d.id] ?? const <DepoModel>[];
      final areas = depos.expand((dp) => areasByDepo[dp.id] ?? const <AreaModel>[]).toList();
      final hasAsm = asmByDist.containsKey(d.id);
      final mappedAreas = areas.where((a) => spvByArea.containsKey(a.id)).length;
      final isComplete = hasAsm && mappedAreas == areas.length;

      if (_statusFilter == 'INCOMPLETE' && isComplete) return false;
      if (_statusFilter == 'COMPLETE' && !isComplete) return false;

      if (_searchQuery.isNotEmpty) {
        final asmName = (asmByDist[d.id]?.user?.name ?? '').toLowerCase();
        final matchDist = d.name.toLowerCase().contains(_searchQuery) ||
            d.code.toLowerCase().contains(_searchQuery) ||
            asmName.contains(_searchQuery);
        final matchDepo = depos.any((dp) => dp.name.toLowerCase().contains(_searchQuery) || dp.code.toLowerCase().contains(_searchQuery));
        final matchArea = areas.any((ar) =>
            ar.name.toLowerCase().contains(_searchQuery) ||
            ar.code.toLowerCase().contains(_searchQuery) ||
            (spvByArea[ar.id]?.user?.name ?? '').toLowerCase().contains(_searchQuery));
        if (!matchDist && !matchDepo && !matchArea) return false;
      }
      return true;
    }).toList();

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total - 1) ~/ _perPage) + 1;
    final safePage = _page.clamp(1, totalPages);
    final startIdx = total == 0 ? 0 : (safePage - 1) * _perPage;
    final endIdx = (startIdx + _perPage).clamp(0, total);
    final paged = total == 0 ? <DistributorModel>[] : filtered.sublist(startIdx, endIdx);

    if (paged.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Tidak ada Distributor sesuai filter.', style: TextStyle(color: colors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...paged.map((dist) {
          final depos = deposByDist[dist.id] ?? const <DepoModel>[];
          final areas = depos.expand((dp) => areasByDepo[dp.id] ?? const <AreaModel>[]).toList();
          final asmAssign = asmByDist[dist.id];
          final mappedAreas = areas.where((a) => spvByArea.containsKey(a.id)).length;
          final allMapped = asmAssign != null && mappedAreas == areas.length;

          final initialSpvMap = <int, int?>{
            for (final a in areas) a.id: spvByArea[a.id]?.userId,
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: allMapped ? colors.border : AppColors.warning.withValues(alpha: 0.45),
              ),
              boxShadow: colors.cardShadows,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: paged.length <= 2,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.building2, size: 18, color: AppColors.primary),
                ),
                title: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dist.name,
                      style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(6)),
                      child: Text(dist.code, style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    // ASM Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: asmAssign != null
                            ? AppColors.success.withValues(alpha: 0.14)
                            : AppColors.danger.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        asmAssign != null ? 'ASM: ${asmAssign.user?.name ?? '-'}' : 'Belum Ada ASM',
                        style: TextStyle(
                          color: asmAssign != null ? AppColors.success : AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Area coverage badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: mappedAreas == areas.length
                            ? AppColors.info.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$mappedAreas / ${areas.length} Area Terpetakan',
                        style: TextStyle(
                          color: mappedAreas == areas.length ? AppColors.info : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(LucideIcons.sliders, size: 13),
                      label: const Text('Atur PIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showBulkMapDialog(
                        distributor: dist,
                        depos: depos,
                        areasByDepo: areasByDepo,
                        initialAsmUserId: asmAssign?.userId,
                        initialSpvByArea: initialSpvMap,
                        defaultPeriod: activePeriod,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.chevronDown, size: 16, color: colors.textMuted),
                  ],
                ),
                children: [
                  if (depos.isEmpty)
                    Text('Belum ada Depo di Distributor ini.', style: TextStyle(color: colors.textMuted, fontSize: 12))
                  else
                    ...depos.map((dp) {
                      final dpAreas = areasByDepo[dp.id] ?? const <AreaModel>[];
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.bgSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.home, size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Depo: ${dp.name} (${dp.code})',
                                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (dpAreas.isEmpty)
                              Text('Belum ada Area di Depo ini.', style: TextStyle(color: colors.textMuted, fontSize: 11.5))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: dpAreas.map((ar) {
                                  final spvAssign = spvByArea[ar.id];
                                  final hasSpv = spvAssign != null;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colors.bgCard,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: hasSpv ? colors.border : AppColors.warning.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.mapPin,
                                          size: 13,
                                          color: hasSpv ? AppColors.success : AppColors.warning,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${ar.name} (${ar.code})',
                                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('→', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                        const SizedBox(width: 6),
                                        Text(
                                          hasSpv ? (spvAssign.user?.name ?? '-') : 'Vacant',
                                          style: TextStyle(
                                            color: hasSpv ? AppColors.primaryLight : AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        // Pagination Footer
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Menampilkan ${startIdx + 1}–$endIdx dari $total Distributor',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Per hal:', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: _perPage,
                  dropdownColor: colors.bgCard,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  items: const [10, 25, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _perPage = v;
                        _page = 1;
                      });
                    }
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  onPressed: safePage > 1 ? () => setState(() => _page = safePage - 1) : null,
                ),
                Text('Hal $safePage / $totalPages', style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  onPressed: safePage < totalPages ? () => setState(() => _page = safePage + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBySalesView(
    BuildContext context,
    List<SalesDistributorAssignmentModel> scopedAssignments,
    String activePeriod,
  ) {
    final colors = context.colors;
    final Map<int, List<SalesDistributorAssignmentModel>> byUser = {};
    for (final a in scopedAssignments) {
      if (!a.isActive) continue;
      byUser.putIfAbsent(a.userId, () => []).add(a);
    }

    final entries = byUser.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      final first = e.value.first;
      final name = (first.user?.name ?? '').toLowerCase();
      final uname = (first.user?.username ?? '').toLowerCase();
      final pos = (first.user?.position?.code ?? '').toLowerCase();
      final inAssigns = e.value.any((a) =>
          (a.distributor?.name ?? '').toLowerCase().contains(_searchQuery) ||
          (a.area?.name ?? '').toLowerCase().contains(_searchQuery));
      return name.contains(_searchQuery) || uname.contains(_searchQuery) || pos.contains(_searchQuery) || inAssigns;
    }).toList()
      ..sort((a, b) => (a.value.first.user?.name ?? '').toLowerCase().compareTo((b.value.first.user?.name ?? '').toLowerCase()));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Tidak ada penugasan sales pada periode $activePeriod.', style: TextStyle(color: colors.textMuted))),
      );
    }

    return Column(
      children: entries.map((entry) {
        final list = entry.value;
        final user = list.first.user;
        final posCode = (user?.position?.code ?? '-').toUpperCase();
        final distNames = list.map((a) => a.distributor?.name).whereType<String>().toSet();
        final areaChips = list.where((a) => a.area != null).toList();
        final distChips = list.where((a) => a.area == null && a.distributor != null).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(user?.name ?? '-', style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text('@${user?.username ?? '-'}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (posCode == 'ASM' ? AppColors.primary : AppColors.info).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            posCode,
                            style: TextStyle(
                              color: posCode == 'ASM' ? AppColors.primary : AppColors.info,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    posCode == 'ASM' ? '${distNames.length} Distributor' : '${areaChips.length} Area',
                    style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...distChips.map(
                    (a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.bgSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        '${a.distributor?.name ?? '-'} (${a.distributor?.code ?? '-'})',
                        style: TextStyle(color: colors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  ...areaChips.map(
                    (a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.bgSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        '${a.area?.name ?? '-'} (${a.area?.code ?? '-'}) • ${a.distributor?.name ?? '-'}',
                        style: TextStyle(color: colors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

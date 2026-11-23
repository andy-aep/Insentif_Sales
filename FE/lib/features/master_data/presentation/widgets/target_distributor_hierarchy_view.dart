import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/master_model.dart';
import '../../../../data/models/master_target_model.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/master_target_provider.dart';

/// Tampilan Target Distributor hirarkis:
/// Distributor -> Depo (target per brand) -> Area (target per brand).
class TargetDistributorHierarchyView extends ConsumerStatefulWidget {
  final String period;
  final void Function(MasterTargetModel target) onEdit;
  final Future<void> Function(MasterTargetModel target) onDelete;
  final void Function({
    required int distributorId,
    required int depoId,
    int? brandId,
    String? period,
    double? initialDepoSellIn,
    Map<int, double>? initialAreaSellOut,
    Map<int, int>? initialAreaAo,
  })? onEditDepoBundle;

  const TargetDistributorHierarchyView({
    super.key,
    required this.period,
    required this.onEdit,
    required this.onDelete,
    this.onEditDepoBundle,
  });

  @override
  ConsumerState<TargetDistributorHierarchyView> createState() => TargetDistributorHierarchyViewState();
}

class _AreaNode {
  final int id;
  final String code;
  final String name;
  final List<MasterTargetModel> targets;
  _AreaNode(this.id, this.code, this.name, this.targets);
}

class _DepoNode {
  final int id;
  final String code;
  final String name;
  final List<MasterTargetModel> targets;
  final List<_AreaNode> areas;
  _DepoNode(this.id, this.code, this.name, this.targets, this.areas);
}

class _DistNode {
  final int id;
  final String code;
  final String name;
  final int depoTargetCount;
  final int areaTargetCount;
  final List<_DepoNode> depos;
  _DistNode(this.id, this.code, this.name, this.depoTargetCount, this.areaTargetCount, this.depos);
}

class TargetDistributorHierarchyViewState extends ConsumerState<TargetDistributorHierarchyView> {
  bool _loading = false;
  String? _error;
  List<_DistNode> _items = [];
  Map<String, dynamic> _summary = {};
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 10;

  int? _distId;
  int? _depoId;
  int? _brandId;
  String _metric = 'ALL';
  String _search = '';
  final _searchCtrl = TextEditingController();

  int? get activeDistributorId => _distId;
  int? get activeDepoId => _depoId;
  int? get activeBrandId => _brandId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void didUpdateWidget(covariant TargetDistributorHierarchyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) reload(page: 1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MasterTargetModel> _parseTargets(dynamic raw) =>
      raw is List ? raw.map((e) => MasterTargetModel.fromJson(Map<String, dynamic>.from(e))).toList() : <MasterTargetModel>[];

  int _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> reload({int? page}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{'page': page ?? _page, 'per_page': _perPage};
      if (widget.period.isNotEmpty && widget.period != 'ALL') params['period'] = widget.period;
      if (_distId != null) params['distributor_id'] = _distId;
      if (_depoId != null) params['depo_id'] = _depoId;
      if (_brandId != null) params['brand_id'] = _brandId;
      if (_metric != 'ALL') params['metrik_target'] = _metric;
      if (_search.isNotEmpty) params['search'] = _search;

      final res = await DioClient.instance.get(ApiEndpoints.masterTargetHierarchy, queryParameters: params);
      final map = Map<String, dynamic>.from(res.data as Map);
      final list = (map['data'] as List? ?? []).map((d) {
        final depos = (d['depos'] as List? ?? []).map((dp) {
          final areas = (dp['areas'] as List? ?? [])
              .map((a) => _AreaNode(_toInt(a['id']), a['code']?.toString() ?? '-', a['name']?.toString() ?? '-', _parseTargets(a['targets'])))
              .toList();
          return _DepoNode(_toInt(dp['id']), dp['code']?.toString() ?? '-', dp['name']?.toString() ?? '-', _parseTargets(dp['targets']), areas);
        }).toList();
        return _DistNode(_toInt(d['id']), d['code']?.toString() ?? '-', d['name']?.toString() ?? '-', _toInt(d['depo_target_count']),
            _toInt(d['area_target_count']), depos);
      }).toList();

      if (!mounted) return;
      setState(() {
        _items = list;
        _summary = Map<String, dynamic>.from(map['summary'] ?? {});
        _page = _toInt(map['current_page']);
        _lastPage = _toInt(map['last_page']).clamp(1, 1 << 30);
        _total = _toInt(map['total']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat Target Distributor: $e';
      });
    }
  }

  double _sumQuota(List<MasterTargetModel> list, String metric) =>
      list.where((t) => t.targetType == metric).fold(0.0, (s, t) => s + t.targetQuota);

  void _showMultiPeriodFilterDialog(BuildContext context, List<String> availablePeriods) {
    final colors = context.colors;
    final raw = widget.period.trim();
    final isAllInitial = raw.isEmpty || raw.toUpperCase() == 'ALL';
    final selected = <String>{
      if (!isAllInitial)
        ...raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
    };
    bool selectAllPeriods = isAllInitial;
    final customPeriodCtrl = TextEditingController();

    final periodsToShow = List<String>.from(availablePeriods);
    for (final s in selected) {
      if (!periodsToShow.contains(s)) periodsToShow.add(s);
    }
    if (periodsToShow.isEmpty) {
      periodsToShow.addAll(['202612', '202611', '202610', '202609', '202608', '202607']);
    }

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
                    'Filter Periode Target',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectAllPeriods = !selectAllPeriods;
                      if (selectAllPeriods) {
                        selected
                          ..clear()
                          ..addAll(periodsToShow);
                      } else {
                        selected
                          ..clear()
                          ..add(periodsToShow.first);
                      }
                    });
                  },
                  child: Text(
                    selectAllPeriods ? 'Pilih 1 Bulan' : 'Semua Periode',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    dense: true,
                    activeColor: Theme.of(context).colorScheme.primary,
                    value: selectAllPeriods,
                    title: Text(
                      'Tampilkan Semua Periode (ALL)',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        selectAllPeriods = val == true;
                        if (selectAllPeriods) {
                          selected
                            ..clear()
                            ..addAll(periodsToShow);
                        } else if (selected.length == periodsToShow.length) {
                          selected
                            ..clear()
                            ..add(periodsToShow.first);
                        }
                      });
                    },
                  ),
                  Divider(height: 12, color: colors.border),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView(
                      shrinkWrap: true,
                      children: periodsToShow.map((p) {
                        final isChecked = selectAllPeriods || selected.contains(p);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: Theme.of(context).colorScheme.primary,
                          value: isChecked,
                          title: Text(
                            'Periode $p',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (selectAllPeriods) {
                                selectAllPeriods = false;
                                selected
                                  ..clear()
                                  ..addAll(periodsToShow);
                              }
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customPeriodCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Tambah YYYYMM (mis: 202611)',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          final txt = customPeriodCtrl.text.trim();
                          if (txt.length == 6) {
                            setDialogState(() {
                              if (!periodsToShow.contains(txt)) periodsToShow.insert(0, txt);
                              selectAllPeriods = false;
                              selected.add(txt);
                              customPeriodCtrl.clear();
                            });
                          }
                        },
                        child: const Text('+ Tambah', style: TextStyle(fontSize: 12)),
                      ),
                    ],
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (selectAllPeriods) {
                    ref.read(masterTargetProvider.notifier).setPeriod('ALL');
                  } else {
                    final sorted = selected.toList()..sort();
                    ref.read(masterTargetProvider.notifier).setPeriod(
                      sorted.isEmpty ? 'ALL' : sorted.join(','),
                    );
                  }
                },
                child: Text(
                  selectAllPeriods ? 'Terapkan (Semua Periode)' : 'Terapkan (${selected.length} Periode)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
    final master = ref.watch(masterDataProvider);
    final targetState = ref.watch(masterTargetProvider);
    final sortedDists = List<DistributorModel>.from(master.distributors)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final filteredDepos = master.depos
        .where((dp) => _distId == null || dp.distributorId == _distId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final effectiveDepoId = filteredDepos.any((dp) => dp.id == _depoId) ? _depoId : null;
    num s(String k) => (_summary[k] as num?) ?? 0;

    final rawPeriod = widget.period.trim();
    final periodItems = (rawPeriod.isEmpty || rawPeriod.toUpperCase() == 'ALL')
        ? <String>[]
        : rawPeriod.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final periodLabel = periodItems.isEmpty
        ? 'Semua Periode'
        : (periodItems.length == 1
            ? 'Periode: ${periodItems.first}'
            : '${periodItems.length} Periode (${periodItems.first}–${periodItems.last})');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi(context, 'Distributor', '${s('distributor_count')} Distributor', LucideIcons.building, Theme.of(context).colorScheme.primary),
            _kpi(context, 'Baris Target', '${s('depo_count')} Depo · ${s('area_count')} Area', LucideIcons.layers, context.semantic.warning),
            _kpi(context, 'Target Sell-In (Depo)',
                '${CurrencyFormatter.formatNumber(s('depo_sell_in').toDouble())} Kg',
                LucideIcons.truck, context.semantic.info),
            _kpi(context, 'Target Sell-Out & AO (Area)',
                '${CurrencyFormatter.formatNumber(s('area_sell_out').toDouble())} Kg · ${CurrencyFormatter.formatNumber(s('total_ao').toDouble())} Toko',
                LucideIcons.trendingUp, context.semantic.success),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadows,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Filter Multi-Periode
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showMultiPeriodFilterDialog(context, targetState.availablePeriods),
                child: Container(
                  width: 225,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.calendar, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Filter Periode', style: TextStyle(color: colors.textMuted, fontSize: 10)),
                            Text(
                              periodLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronDown, size: 15, color: colors.textMuted),
                    ],
                  ),
                ),
              ),
              // 2. Filter Distributor (Urut Abjad)
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  initialValue: _distId,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Filter Distributor', LucideIcons.building2),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Distributor')),
                    ...sortedDists.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _distId = v;
                      _depoId = null;
                    });
                    reload(page: 1);
                  },
                ),
              ),
              // 3. Filter Depo (mengikuti Distributor terpilih)
              SizedBox(
                width: 225,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('filter_depo_${_distId}_${effectiveDepoId}_${filteredDepos.length}'),
                  initialValue: effectiveDepoId,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Filter Depo', LucideIcons.home),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Depo')),
                    ...filteredDepos.map((dp) => DropdownMenuItem<int?>(value: dp.id, child: Text('${dp.name} (${dp.code})', overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() => _depoId = v);
                    reload(page: 1);
                  },
                ),
              ),
              // 3. Filter Brand
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<int?>(
                  initialValue: _brandId,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Filter Brand', LucideIcons.tag),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Brand')),
                    ...master.brands.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    _brandId = v;
                    reload(page: 1);
                  },
                ),
              ),
              // 4. Filter Metrik
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _metric,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Metrik', LucideIcons.activity),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Semua Metrik', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SELL_IN', child: Text('Sell-In (Depo)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SELL_OUT', child: Text('Sell-Out & AO (Area)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    _metric = v ?? 'ALL';
                    reload(page: 1);
                  },
                ),
              ),
              // 5. Cari
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: _dec('Cari Distributor / Depo / Area (Enter)', LucideIcons.search),
                  onSubmitted: (v) {
                    _search = v.trim();
                    reload(page: 1);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: () => reload(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: context.semantic.danger)),
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text('Belum ada target distributor pada periode ${widget.period}.', style: TextStyle(color: colors.textMuted))),
          )
        else
          ..._items.map((d) => _distTile(context, d)),
        if (_total > 0) _pagination(context),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _kpi(BuildContext context, String title, String value, IconData icon, Color color) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: colors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  void _triggerEditDepoBundle(_DistNode d, _DepoNode dp, {int? preferredBrandId, String? preferredPeriod}) {
    if (widget.onEditDepoBundle == null) return;
    final allTargets = [...dp.targets, ...dp.areas.expand((a) => a.targets)];
    final sample = allTargets.isNotEmpty ? allTargets.first : null;
    final resolvedPeriod = preferredPeriod ?? sample?.period;
    final resolvedBrandId = preferredBrandId ?? sample?.brandId;

    MasterTargetModel? matchedDepoTarget;
    for (final t in dp.targets) {
      if ((resolvedPeriod == null || t.period == resolvedPeriod) &&
          (resolvedBrandId == null || t.brandId == resolvedBrandId)) {
        matchedDepoTarget = t;
        break;
      }
    }
    matchedDepoTarget ??= dp.targets.firstOrNull;

    final areaSoMap = <int, double>{};
    final areaAoMap = <int, int>{};
    for (final a in dp.areas) {
      MasterTargetModel? matchedAreaTarget;
      for (final t in a.targets) {
        if ((resolvedPeriod == null || t.period == resolvedPeriod) &&
            (resolvedBrandId == null || t.brandId == resolvedBrandId)) {
          matchedAreaTarget = t;
          break;
        }
      }
      matchedAreaTarget ??= a.targets.firstOrNull;
      if (matchedAreaTarget != null) {
        areaSoMap[a.id] = matchedAreaTarget.targetQuota;
        areaAoMap[a.id] = matchedAreaTarget.targetOutlet ?? 0;
      }
    }

    widget.onEditDepoBundle!(
      distributorId: d.id,
      depoId: dp.id,
      brandId: resolvedBrandId,
      period: resolvedPeriod,
      initialDepoSellIn: matchedDepoTarget?.targetQuota,
      initialAreaSellOut: areaSoMap,
      initialAreaAo: areaAoMap,
    );
  }

  Widget _distTile(BuildContext context, _DistNode d) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadows,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _items.length == 1,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.building, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(d.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text('${d.code} · ${d.depos.length} Depo · ${d.depoTargetCount} target depo · ${d.areaTargetCount} target area',
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: d.depos.map((dp) => _depoTile(context, d, dp)).toList(),
        ),
      ),
    );
  }

  Widget _depoTile(BuildContext context, _DistNode d, _DepoNode dp) {
    final colors = context.colors;
    final allTargets = [...dp.targets, ...dp.areas.expand((a) => a.targets)];
    final periodsInDepo = allTargets.map((t) => t.period).where((p) => p.isNotEmpty).toSet().toList()..sort();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(LucideIcons.building2, size: 18, color: Theme.of(context).colorScheme.primary),
          title: Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Depo: ${dp.name}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (periodsInDepo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        periodsInDepo.length == 1
                            ? 'Periode ${periodsInDepo.first}'
                            : '${periodsInDepo.length} Periode (${periodsInDepo.first}–${periodsInDepo.last})',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.onEditDepoBundle != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(LucideIcons.sliders, size: 13),
                  label: const Text('Edit Depo & Area Sekaligus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _triggerEditDepoBundle(d, dp),
                ),
            ],
          ),
          subtitle: Text(
            '${dp.code} · ${dp.targets.length} target brand · ${dp.areas.length} Area · Sell-In Depo ${CurrencyFormatter.formatNumber(_sumQuota(dp.targets, 'SELL_IN'))} Kg',
            style: TextStyle(color: colors.textMuted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            if (allTargets.isEmpty) Text('Tidak ada target.', style: TextStyle(color: colors.textMuted)),
            if (dp.targets.isNotEmpty) ...[
              _sectionLabel(context, 'Target Depo (ASM — Sell-In)', Theme.of(context).colorScheme.primary),
              _targetTable(context, dp.targets, isDepo: true),
            ],
            ...dp.areas.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: context.semantic.warning.withValues(alpha: 0.6), width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(LucideIcons.mapPin, size: 15, color: context.semantic.warning),
                          const SizedBox(width: 6),
                          Text('Area: ${a.name}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text('${a.code} · ${a.targets.length} target brand', style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
                        ]),
                        const SizedBox(height: 6),
                        _targetTable(context, a.targets, isDepo: false),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _targetTable(BuildContext context, List<MasterTargetModel> targets, {bool isDepo = false}) {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columns: [
          const DataColumn(label: Text('Periode')),
          const DataColumn(label: Text('Brand')),
          const DataColumn(label: Text('Metrik')),
          DataColumn(label: Text(isDepo ? 'Target Sell-In' : 'Target Sell-Out')),
          if (!isDepo) const DataColumn(label: Text('Target AO (Toko)')),
          const DataColumn(label: Text('PIC')),
          const DataColumn(label: Text('Aksi')),
        ],
        rows: targets.map((t) {
          final isAo = t.targetType == 'AO';
          return DataRow(cells: [
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.period,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            DataCell(Text(t.brand?.name ?? '-', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(isDepo ? 'SELL_IN' : 'SELL_OUT & AO', style: TextStyle(color: context.semantic.info, fontSize: 11.5, fontWeight: FontWeight.bold))),
            DataCell(Text(
              isAo ? '${t.targetOutlet ?? t.targetQuota.toInt()} Toko' : '${CurrencyFormatter.formatNumber(t.targetQuota)} Kg',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            )),
            if (!isDepo) DataCell(Text(t.targetOutlet != null ? '${t.targetOutlet} Toko' : '-', style: TextStyle(color: context.semantic.warning, fontWeight: FontWeight.bold))),
            DataCell(Text(t.user?.name ?? '-', style: TextStyle(color: colors.textSecondary))),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(LucideIcons.pencil, size: 15, color: Theme.of(context).colorScheme.primary),
                tooltip: 'Edit Baris Ini',
                onPressed: () => widget.onEdit(t),
              ),
              IconButton(
                icon: Icon(LucideIcons.trash2, size: 15, color: context.semantic.danger),
                tooltip: 'Hapus Baris Ini',
                onPressed: () => widget.onDelete(t),
              ),
            ])),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _pagination(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('$_total distributor', style: TextStyle(color: colors.textMuted, fontSize: 13)),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _perPage,
            dropdownColor: colors.bgElevated,
            items: const [5, 10, 20, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v / hal'))).toList(),
            onChanged: (v) {
              if (v == null) return;
              _perPage = v;
              reload(page: 1);
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            onPressed: _page > 1 ? () => reload(page: _page - 1) : null,
          ),
          Text('Hal $_page dari $_lastPage', style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            onPressed: _page < _lastPage ? () => reload(page: _page + 1) : null,
          ),
        ],
      ),
    );
  }
}


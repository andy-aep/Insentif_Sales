import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/master_target_model.dart';
import '../../providers/master_data_provider.dart';

/// Tampilan Target Distributor hirarkis:
/// Distributor -> Depo (target per brand) -> Area (target per brand).
class TargetDistributorHierarchyView extends ConsumerStatefulWidget {
  final String period;
  final void Function(MasterTargetModel target) onEdit;
  final Future<void> Function(MasterTargetModel target) onDelete;

  const TargetDistributorHierarchyView({
    super.key,
    required this.period,
    required this.onEdit,
    required this.onDelete,
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
  int? _brandId;
  String _metric = 'ALL';
  String _search = '';
  final _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final master = ref.watch(masterDataProvider);
    num s(String k) => (_summary[k] as num?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi(context, 'Distributor', '${s('distributor_count')} Distributor', LucideIcons.building, AppColors.primary),
            _kpi(context, 'Baris Target', '${s('depo_count')} Depo · ${s('area_count')} Area', LucideIcons.layers, AppColors.warning),
            _kpi(context, 'Sell-Out Depo / Area',
                '${CurrencyFormatter.formatNumber(s('depo_sell_out').toDouble())} / ${CurrencyFormatter.formatNumber(s('area_sell_out').toDouble())} Kg',
                LucideIcons.trendingUp, AppColors.success),
            _kpi(context, 'Sell-In Depo / Area',
                '${CurrencyFormatter.formatNumber(s('depo_sell_in').toDouble())} / ${CurrencyFormatter.formatNumber(s('area_sell_in').toDouble())} Kg',
                LucideIcons.truck, AppColors.info),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadows,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  initialValue: _distId,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Filter Distributor', LucideIcons.building2),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Distributor')),
                    ...master.distributors.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    _distId = v;
                    reload(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  initialValue: _brandId,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Filter Brand', LucideIcons.tag),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Brand')),
                    ...master.brands.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (v) {
                    _brandId = v;
                    reload(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _metric,
                  isExpanded: true,
                  dropdownColor: colors.bgElevated,
                  decoration: _dec('Metrik', LucideIcons.activity),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Semua Metrik', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SELL_OUT', child: Text('SELL_OUT', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SELL_IN', child: Text('SELL_IN', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'AO', child: Text('AO', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    _metric = v ?? 'ALL';
                    reload(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: 320,
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
            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
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
        borderRadius: BorderRadius.circular(18),
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

  Widget _distTile(BuildContext context, _DistNode d) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(18),
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
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.building, size: 18, color: AppColors.primary),
          ),
          title: Text(d.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text('${d.code} · ${d.depos.length} Depo · ${d.depoTargetCount} target depo · ${d.areaTargetCount} target area',
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: d.depos.map((dp) => _depoTile(context, dp)).toList(),
        ),
      ),
    );
  }

  Widget _depoTile(BuildContext context, _DepoNode dp) {
    final colors = context.colors;
    final allTargets = [...dp.targets, ...dp.areas.expand((a) => a.targets)];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(LucideIcons.building2, size: 18, color: AppColors.primary),
          title: Text('Depo: ${dp.name}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
            '${dp.code} · ${dp.targets.length} target brand · ${dp.areas.length} Area · Sell-In Depo ${CurrencyFormatter.formatNumber(_sumQuota(dp.targets, 'SELL_IN'))} Kg',
            style: TextStyle(color: colors.textMuted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            if (allTargets.isEmpty) Text('Tidak ada target.', style: TextStyle(color: colors.textMuted)),
            if (dp.targets.isNotEmpty) ...[
              _sectionLabel(context, 'Target Depo (ASM) per Brand', AppColors.primary),
              _targetTable(context, dp.targets, isDepo: true),
            ],
            ...dp.areas.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: AppColors.warning.withValues(alpha: 0.6), width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(LucideIcons.mapPin, size: 15, color: AppColors.warning),
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
          const DataColumn(label: Text('Brand')),
          const DataColumn(label: Text('Metrik')),
          const DataColumn(label: Text('Target Kuota')),
          if (!isDepo) const DataColumn(label: Text('Target Outlet')),
          const DataColumn(label: Text('PIC')),
          const DataColumn(label: Text('Aksi')),
        ],
        rows: targets.map((t) {
          final isAo = t.targetType == 'AO';
          return DataRow(cells: [
            DataCell(Text(t.brand?.name ?? '-', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(t.targetType, style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.bold))),
            DataCell(Text(
              isAo ? '${t.targetOutlet ?? t.targetQuota.toInt()} Toko' : '${CurrencyFormatter.formatNumber(t.targetQuota)} Kg',
              style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
            )),
            if (!isDepo) DataCell(Text(t.targetOutlet != null ? '${t.targetOutlet} Toko' : '-', style: TextStyle(color: colors.textSecondary))),
            DataCell(Text(t.user?.name ?? '-', style: TextStyle(color: colors.textSecondary))),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 15, color: AppColors.primaryLight),
                tooltip: 'Edit',
                onPressed: () => widget.onEdit(t),
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                tooltip: 'Hapus',
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


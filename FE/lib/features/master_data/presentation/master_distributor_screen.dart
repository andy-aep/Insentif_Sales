import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/master_model.dart';
import '../../bulk_upload/providers/bulk_upload_provider.dart';
import '../providers/master_data_provider.dart';

class MasterDistributorScreen extends ConsumerStatefulWidget {
  const MasterDistributorScreen({super.key});

  @override
  ConsumerState<MasterDistributorScreen> createState() => _MasterDistributorScreenState();
}

class _MasterDistributorScreenState extends ConsumerState<MasterDistributorScreen> with SingleTickerProviderStateMixin {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(masterDataProvider).distributors.isEmpty) {
        ref.read(masterDataProvider.notifier).fetchAllMasterData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerTabAdd() {
    switch (_activeTabIndex) {
      case 0:
        _showComprehensiveDistributorDialog();
        break;
      case 1:
        _showDepoDialog();
        break;
      case 2:
        _showAreaDialog();
        break;
      case 3:
      default:
        _showBrandDialog();
        break;
    }
  }

  // ---------------- 1. Comprehensive Distributor + Depo + Area Builder ----------------
  String _nextDistributorCode() {
    final dists = ref.read(masterDataProvider).distributors;
    int maxNum = 0;
    final regex = RegExp(r'^DST(\d+)$', caseSensitive: false);
    for (final d in dists) {
      final m = regex.firstMatch(d.code.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'DST${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  String _nextAreaCode({int offset = 0}) {
    final state = ref.read(masterDataProvider);
    int maxNum = 0;
    final regex = RegExp(r'^AR(\d+)$', caseSensitive: false);
    for (final a in state.areas) {
      final m = regex.firstMatch(a.code.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    for (final d in state.distributors) {
      for (final dp in d.depos) {
        for (final a in dp.areas) {
          final m = regex.firstMatch(a.code.trim());
          if (m != null) {
            final n = int.tryParse(m.group(1)!) ?? 0;
            if (n > maxNum) maxNum = n;
          }
        }
      }
    }
    return 'AR${(maxNum + 1 + offset).toString().padLeft(5, '0')}';
  }

  void _showComprehensiveDistributorDialog({DistributorModel? dist}) {
    final colors = context.colors;
    final isEdit = dist != null;

    final codeCtrl = TextEditingController(text: dist?.code ?? _nextDistributorCode());
    final nameCtrl = TextEditingController(text: dist?.name ?? '');
    int? selectedRegionId = dist?.regionId;

    // Draft depos and nested areas
    List<_DepoDraft> draftDepos = [];
    int draftAreaCount = 0;
    if (dist != null && dist.depos.isNotEmpty) {
      final allAreas = ref.read(masterDataProvider).areas;
      draftDepos = dist.depos.map((d) {
        final effectiveAreas = d.areas.isNotEmpty
            ? d.areas
            : allAreas.where((a) => a.depoId == d.id).toList();
        return _DepoDraft(
          id: d.id,
          code: d.code,
          name: d.name,
          areas: effectiveAreas.map((a) => _AreaDraft(id: a.id, code: a.code, name: a.name)).toList(),
        );
      }).toList();
    } else {
      // Starter with 1 depo & 1 area for intuitive onboarding
      draftDepos = [
        _DepoDraft(
          code: '',
          name: '',
          areas: [
            _AreaDraft(code: _nextAreaCode(offset: draftAreaCount++), name: ''),
          ],
        ),
      ];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860, maxHeight: 860),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.building2, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Master Distributor & Jaringan' : 'Tambah Master Distributor, Depo & Area Terintegrasi',
                            style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.onPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.x, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Distributor Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                    Icon(LucideIcons.building, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Identitas Distributor Utama',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 150,
                                      child: TextField(
                                        controller: codeCtrl,
                                        style: TextStyle(color: colors.textPrimary),
                                        decoration: const InputDecoration(labelText: 'Kode Distributor', hintText: 'Otomatis (DSTxxxx) jika kosong'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: nameCtrl,
                                        style: TextStyle(color: colors.textPrimary),
                                        decoration: const InputDecoration(labelText: 'Nama Perusahaan Distributor *', hintText: 'Contoh: PT Sumber Rejeki Utama'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final mState = ref.watch(masterDataProvider);
                                          return DropdownButtonFormField<int?>(
                                            initialValue: selectedRegionId,
                                            isExpanded: true,
                                            dropdownColor: colors.bgElevated,
                                            style: TextStyle(color: colors.textPrimary),
                                            decoration: const InputDecoration(
                                              labelText: 'Wilayah / Region',
                                              prefixIcon: Icon(LucideIcons.globe, size: 16),
                                              prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                            ),
                                            items: [
                                              const DropdownMenuItem<int?>(
                                                value: null,
                                                child: Text('Tanpa Region (Nasional)', overflow: TextOverflow.ellipsis),
                                              ),
                                              ...mState.regions.map((reg) => DropdownMenuItem<int?>(
                                                value: reg.id,
                                                child: Text(
                                                  reg.code == reg.name ? reg.name : '${reg.code} - ${reg.name}',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              )),
                                            ],
                                            onChanged: (val) {
                                              setDialogState(() => selectedRegionId = val);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 2. Depos and Areas Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jaringan Depo Logistik & Area Penjualan',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                  ),
                                  Text(
                                    'Setiap distributor dapat memiliki beberapa depo, dan setiap depo mencakup beberapa area.',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('Tambah Depo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  setDialogState(() {
                                    final dNum = draftDepos.length + 1;
                                    draftDepos.add(
                                      _DepoDraft(
                                        code: codeCtrl.text.trim().isNotEmpty ? '${codeCtrl.text.trim()}-DP$dNum' : 'DP$dNum',
                                        name: 'Depo Baru $dNum',
                                        areas: [
                                          _AreaDraft(code: _nextAreaCode(offset: draftAreaCount++), name: 'Area 1'),
                                        ],
                                      ),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (draftDepos.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.bgElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text('Belum ada Depo yang ditambahkan. Klik "+ Tambah Depo" di atas.', style: TextStyle(color: colors.textMuted)),
                            )
                          else
                            ...draftDepos.asMap().entries.map((dEntry) {
                              final dIdx = dEntry.key;
                              final depo = dEntry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Depo Header Row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.semantic.infoBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(LucideIcons.warehouse, size: 13, color: context.semantic.info),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Depo #${dIdx + 1}',
                                                style: TextStyle(color: context.semantic.info, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                                          tooltip: 'Hapus Depo Ini',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setDialogState(() {
                                              draftDepos.removeAt(dIdx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Depo Code & Name Inputs
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 160,
                                          child: TextField(
                                            controller: depo.codeCtrl,
                                            style: TextStyle(color: colors.textPrimary),
                                            decoration: const InputDecoration(labelText: 'Kode Depo *', hintText: 'Contoh: DP01'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: depo.nameCtrl,
                                            style: TextStyle(color: colors.textPrimary),
                                            decoration: const InputDecoration(labelText: 'Nama Depo *', hintText: 'Contoh: Depo Surabaya Utama'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Nested Areas Container
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colors.bgElevated,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(LucideIcons.mapPin, size: 13, color: context.semantic.success),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Area Tercover (${depo.areas.length} Area)',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.textPrimary),
                                                  ),
                                                ],
                                              ),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: context.semantic.success,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                ),
                                                icon: const Icon(LucideIcons.plus, size: 13),
                                                label: const Text('Tambah Area', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    depo.areas.add(_AreaDraft(code: _nextAreaCode(offset: draftAreaCount++), name: ''));
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          if (depo.areas.isEmpty)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              child: Text('Belum ada area untuk depo ini.', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                            )
                                          else
                                            ...depo.areas.asMap().entries.map((aEntry) {
                                              final aIdx = aEntry.key;
                                              final area = aEntry.value;

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 140,
                                                      child: TextField(
                                                        controller: area.codeCtrl,
                                                        style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                                        decoration: InputDecoration(
                                                          labelText: 'Kode Area',
                                                          hintText: 'Auto (ARxxxxx)',
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: area.nameCtrl,
                                                        style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                                        decoration: InputDecoration(
                                                          labelText: 'Nama Area Operasional *',
                                                          hintText: 'Contoh: Area Rungkut & Timur',
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    IconButton(
                                                      icon: Icon(LucideIcons.x, size: 14, color: context.semantic.danger),
                                                      tooltip: 'Hapus Area',
                                                      padding: const EdgeInsets.all(6),
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          depo.areas.removeAt(aIdx);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Batal', style: TextStyle(color: colors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: Text(
                            isEdit ? 'Simpan Perubahan' : 'Simpan Distributor & Jaringan',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final code = codeCtrl.text.trim();
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nama Distributor wajib diisi!')),
                              );
                              return;
                            }

                            // Format depos payload
                            final deposPayload = draftDepos
                                .where((d) => d.nameCtrl.text.trim().isNotEmpty)
                                .map((d) {
                              return {
                                if (d.id != null) 'id': d.id,
                                'code': d.codeCtrl.text.trim(),
                                'name': d.nameCtrl.text.trim(),
                                'areas': d.areas
                                    .where((a) => a.nameCtrl.text.trim().isNotEmpty)
                                    .map((a) {
                                  return {
                                    if (a.id != null) 'id': a.id,
                                    'code': a.codeCtrl.text.trim(),
                                    'name': a.nameCtrl.text.trim(),
                                  };
                                }).toList(),
                              };
                            }).toList();

                            Navigator.pop(ctx);
                            final success = await ref.read(masterDataProvider.notifier).saveDistributor(
                                  id: dist?.id,
                                  code: code,
                                  name: name,
                                  regionId: selectedRegionId,
                                  depos: deposPayload,
                                );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? (isEdit ? 'Distributor berhasil diperbarui' : 'Distributor, Depo & Area berhasil disimpan!')
                                      : 'Gagal menyimpan distributor.'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- 2. Detail Dialog for Distributor Hierarchy ----------------
  Future<void> _showDistributorDetailDialog(DistributorModel dist) async {
    final colors = context.colors;
    DistributorModel currentDist = dist;

    if (dist.depos.isNotEmpty && dist.depos.first.areas.isEmpty) {
      try {
        final res = await DioClient.instance.get('${ApiEndpoints.distributors}/${dist.id}');
        final rawData = res.data;
        final data = rawData is Map ? (rawData['data'] ?? rawData) : rawData;
        if (data is Map<String, dynamic>) {
          currentDist = DistributorModel.fromJson(data);
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.building2, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Struktur Hirarki: ${currentDist.name}',
                        style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.onPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(currentDist.code, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(currentDist.name, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Region: ${currentDist.region != null ? "${currentDist.region!.code} - ${currentDist.region!.name}" : "Nasional / Tanpa Region"} • Total: ${currentDist.depos.length} Depo Logistik Terdaftar',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text('Daftar Jaringan Depo & Area:', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      const SizedBox(height: 10),

                      if (currentDist.depos.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: colors.bgElevated, borderRadius: BorderRadius.circular(8)),
                          child: Text('Belum ada depo di distributor ini.', style: TextStyle(color: colors.textMuted)),
                        )
                      else
                        ...currentDist.depos.map((depo) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.bgCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.warehouse, size: 15, color: context.semantic.secondaryAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${depo.name} (${depo.code})',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 13.5),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: context.semantic.successBg, borderRadius: BorderRadius.circular(6)),
                                      child: Text('${depo.areas.length} Area', style: TextStyle(color: context.semantic.success, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (depo.areas.isEmpty)
                                  Text('Belum ada area operasional di depo ini.', style: TextStyle(color: colors.textMuted, fontSize: 11.5))
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: depo.areas.map((a) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: colors.bgElevated,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: colors.border),
                                        ),
                                        child: Text('${a.name} (${a.code})', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: colors.bgElevated, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  child: const Text('Tutup'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 3. Standalone Depo Dialog (With Area builder) ----------------
  void _showDepoDialog({DepoModel? depo, int? preselectedDistributorId}) {
    final colors = context.colors;
    final state = ref.read(masterDataProvider);
    final isEdit = depo != null;

    int? selectedDistId = depo?.distributorId ?? preselectedDistributorId ?? (state.distributors.isNotEmpty ? state.distributors.first.id : null);
    final codeCtrl = TextEditingController(text: depo?.code ?? '');
    final nameCtrl = TextEditingController(text: depo?.name ?? '');

    List<_AreaDraft> draftAreas = [];
    if (depo != null) {
      final effectiveAreas = depo.areas.isNotEmpty
          ? depo.areas
          : state.areas.where((a) => a.depoId == depo.id).toList();
      draftAreas = effectiveAreas.map((a) => _AreaDraft(id: a.id, code: a.code, name: a.name)).toList();
    } else {
      draftAreas = [_AreaDraft(code: _nextAreaCode(), name: '')];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                Icon(LucideIcons.warehouse, color: context.semantic.secondaryAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Depo: ${depo.name}' : 'Tambah Depo Logistik Baru',
                    style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Induk Distributor Selector
                    DropdownButtonFormField<int>(
                      initialValue: state.distributors.any((d) => d.id == selectedDistId) ? selectedDistId : null,
                      isExpanded: true,
                      dropdownColor: colors.bgElevated,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Induk Distributor *',
                        prefixIcon: Icon(LucideIcons.building2, size: 16),
                        prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      items: state.distributors.map((dist) {
                        return DropdownMenuItem<int>(
                          value: dist.id,
                          child: Text('${dist.name} (${dist.code})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDistId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: codeCtrl,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Kode Depo *', hintText: 'Contoh: DP-01'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Nama Depo *', hintText: 'Contoh: Depo Surabaya'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Area under Depo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Area Tercover:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
                        TextButton.icon(
                          icon: const Icon(LucideIcons.plus, size: 13),
                          label: const Text('Tambah Area', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setDialogState(() {
                              draftAreas.add(_AreaDraft(code: _nextAreaCode(offset: draftAreas.length), name: ''));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...draftAreas.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final a = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 130,
                              child: TextField(
                                controller: a.codeCtrl,
                                style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                decoration: InputDecoration(
                                  labelText: 'Kode Area',
                                  hintText: 'Auto / AR${idx + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: a.nameCtrl,
                                style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                decoration: const InputDecoration(
                                  labelText: 'Nama Area Operasional',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: Icon(LucideIcons.x, size: 14, color: context.semantic.danger),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setDialogState(() {
                                  draftAreas.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.semantic.infoSolid, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                onPressed: () async {
                  if (selectedDistId == null || codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pilih Distributor dan isi Kode & Nama Depo!')),
                    );
                    return;
                  }

                  final areasPayload = draftAreas
                      .where((a) => a.nameCtrl.text.trim().isNotEmpty)
                      .map((a) => {
                            if (a.id != null) 'id': a.id,
                            'code': a.codeCtrl.text.trim(),
                            'name': a.nameCtrl.text.trim(),
                          })
                      .toList();

                  Navigator.pop(ctx);
                  final ok = await ref.read(masterDataProvider.notifier).saveDepo(
                        id: depo?.id,
                        distributorId: selectedDistId!,
                        code: codeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        areas: areasPayload,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Depo berhasil disimpan' : 'Gagal menyimpan depo')),
                    );
                  }
                },
                child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Depo'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- 4. Standalone Area Dialog ----------------
  void _showAreaDialog({AreaModel? area, int? preselectedDepoId}) {
    final colors = context.colors;
    final state = ref.read(masterDataProvider);
    final isEdit = area != null;

    int? selectedDepoId = area?.depoId ?? preselectedDepoId ?? (state.depos.isNotEmpty ? state.depos.first.id : null);
    final codeCtrl = TextEditingController(text: area?.code ?? _nextAreaCode());
    final nameCtrl = TextEditingController(text: area?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                Icon(LucideIcons.mapPin, color: context.semantic.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Area Operasional: ${area.name}' : 'Tambah Area Operasional Baru',
                    style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: state.depos.any((d) => d.id == selectedDepoId) ? selectedDepoId : null,
                    isExpanded: true,
                    dropdownColor: colors.bgElevated,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Pilih Induk Depo *',
                      prefixIcon: Icon(LucideIcons.warehouse, size: 16),
                      prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    items: state.depos.map((depo) {
                      final distName = depo.distributor?.name ?? 'Distributor';
                      return DropdownMenuItem<int>(
                        value: depo.id,
                        child: Text('${depo.name} ($distName)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedDepoId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Kode Area', hintText: 'Otomatis (ARxxxxx) jika kosong'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Nama Area Operasional *', hintText: 'Contoh: Area Rungkut & Sekitarnya'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: context.semantic.successSolid, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                onPressed: () async {
                  if (selectedDepoId == null || nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pilih Depo dan isi Nama Area!')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final ok = await ref.read(masterDataProvider.notifier).saveArea(
                        id: area?.id,
                        depoId: selectedDepoId!,
                        code: codeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Area berhasil disimpan' : 'Gagal menyimpan area')),
                    );
                  }
                },
                child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Area'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- 5. Brand Dialog ----------------
  void _showBrandDialog({BrandModel? brand}) {
    final colors = context.colors;
    final allBrands = ref.read(masterDataProvider).brands;
    final singleBrands = allBrands.where((b) => !b.isComposite && b.id != brand?.id).toList();
    final isEdit = brand != null;

    bool isCompositeMode = brand != null ? brand.isComposite : false;
    bool isAllBrands = brand?.isAllBrands ?? false;
    final Set<int> selectedComponentIds = (brand?.componentBrandIds ?? []).toSet();
    if (selectedComponentIds.isEmpty && brand != null && !isAllBrands && brand.code.contains('+')) {
      final tokens = brand.code.split('+').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet();
      for (final sb in singleBrands) {
        if (tokens.contains(sb.code.trim().toUpperCase()) || tokens.contains(sb.name.trim().toUpperCase())) {
          selectedComponentIds.add(sb.id);
        }
      }
    }

    final codeCtrl = TextEditingController(text: brand?.code ?? '');
    final nameCtrl = TextEditingController(text: brand?.name ?? '');
    final itemsCtrl = TextEditingController(text: brand?.itemCodes.join(', ') ?? '');
    bool customCodeEdited = isEdit;
    bool customNameEdited = isEdit;

    void syncCompositeLabels() {
      if (!isCompositeMode) return;
      if (isAllBrands) {
        if (!customCodeEdited || codeCtrl.text.trim().isEmpty || codeCtrl.text.contains('+')) {
          codeCtrl.text = 'ALL_BRAND';
        }
        if (!customNameEdited || nameCtrl.text.trim().isEmpty || nameCtrl.text.contains('+')) {
          nameCtrl.text = 'ALL BRAND (Semua Merek)';
        }
        return;
      }
      final picked = singleBrands.where((b) => selectedComponentIds.contains(b.id)).toList();
      if (picked.isNotEmpty) {
        if (!customCodeEdited || codeCtrl.text.trim().isEmpty || codeCtrl.text.contains('+') || codeCtrl.text == 'ALL_BRAND') {
          codeCtrl.text = picked.map((b) => b.code.trim().toUpperCase()).join('+');
        }
        if (!customNameEdited || nameCtrl.text.trim().isEmpty || nameCtrl.text.contains('+') || nameCtrl.text.startsWith('ALL BRAND')) {
          nameCtrl.text = picked.map((b) => b.name.trim()).join(' + ');
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.bgDialog,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
          title: Row(
            children: [
              Icon(LucideIcons.tag, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEdit ? 'Edit Brand: ${brand.name}' : 'Tambah Brand Baru',
                  style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(LucideIcons.tag, size: 14),
                        label: Text('Brand Tunggal'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(LucideIcons.layers, size: 14),
                        label: Text('Brand Gabungan (Mix / All)'),
                      ),
                    ],
                    selected: {isCompositeMode},
                    onSelectionChanged: (sel) {
                      setDialogState(() {
                        isCompositeMode = sel.first;
                        customCodeEdited = false;
                        customNameEdited = false;
                        if (isCompositeMode) {
                          syncCompositeLabels();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (isCompositeMode) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'Semua Brand (All Brand)',
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text(
                              'Otomatis menggabungkan seluruh brand pada Depo & Area',
                              style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                            ),
                            value: isAllBrands,
                            onChanged: (v) {
                              setDialogState(() {
                                isAllBrands = v;
                                customCodeEdited = false;
                                customNameEdited = false;
                                syncCompositeLabels();
                              });
                            },
                          ),
                          if (!isAllBrands) ...[
                            const Divider(height: 16),
                            Text(
                              'Pilih brand yang digabungkan (minimal 2):',
                              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                            const SizedBox(height: 8),
                            if (singleBrands.isEmpty)
                              Text(
                                'Belum ada brand tunggal terdaftar.',
                                style: TextStyle(color: colors.textMuted, fontSize: 12),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: singleBrands.map((sb) {
                                  final selected = selectedComponentIds.contains(sb.id);
                                  return FilterChip(
                                    label: Text('${sb.name} (${sb.code})'),
                                    selected: selected,
                                    onSelected: (checked) {
                                      setDialogState(() {
                                        if (checked) {
                                          selectedComponentIds.add(sb.id);
                                        } else {
                                          selectedComponentIds.remove(sb.id);
                                        }
                                        customCodeEdited = false;
                                        customNameEdited = false;
                                        syncCompositeLabels();
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    onChanged: (_) => customCodeEdited = true,
                    decoration: InputDecoration(
                      labelText: 'Kode Brand *',
                      hintText: isCompositeMode ? 'Contoh: KAPAL+JEMPOL+GARAMI atau ALL_BRAND' : 'Contoh: KAPAL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    onChanged: (_) => customNameEdited = true,
                    decoration: InputDecoration(
                      labelText: 'Nama Merek Dagang *',
                      hintText: isCompositeMode ? 'Contoh: KAPAL + JEMPOL + GARAMI' : 'Contoh: KAPAL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isCompositeMode)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info, size: 15, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ItemCode SAP dan faktur Sell-Out tetap mengikuti brand tunggal masing-masing, lalu otomatis dijumlahkan saat perhitungan insentif.',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: itemsCtrl,
                      maxLines: 4,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Mapping ItemCode SAP (Opsional)',
                        hintText: 'Contoh: B13, B15, B26, C56 (pisahkan dengan koma atau baris baru)',
                        helperText: 'Dipakai untuk otomatis mendeteksi Brand dari ItemCode SAP',
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
              onPressed: () async {
                if (isCompositeMode && !isAllBrands && selectedComponentIds.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih minimal 2 brand untuk digabungkan, atau aktifkan Semua Brand.')),
                  );
                  return;
                }
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode dan Nama Brand wajib diisi!')),
                  );
                  return;
                }

                final parsedCodes = isCompositeMode
                    ? <String>[]
                    : itemsCtrl.text
                        .split(RegExp(r'[\s,;]+'))
                        .map((e) => e.trim().toUpperCase())
                        .where((e) => e.isNotEmpty)
                        .toSet()
                        .toList();

                Navigator.pop(ctx);
                final ok = await ref.read(masterDataProvider.notifier).saveBrand(
                      id: brand?.id,
                      code: codeCtrl.text.trim().toUpperCase(),
                      name: nameCtrl.text.trim(),
                      itemCodes: parsedCodes,
                      isAllBrands: isCompositeMode && isAllBrands,
                      componentBrandIds: (isCompositeMode && !isAllBrands) ? selectedComponentIds.toList() : <int>[],
                    );

                if (mounted) {
                  final err = ref.read(masterDataProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Brand & konfigurasi berhasil disimpan' : (err ?? 'Gagal menyimpan brand')),
                      backgroundColor: ok ? context.semantic.success : context.semantic.danger,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Brand'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masterDataProvider);

    String addBtnLabel = 'Tambah Distributor';
    IconData addBtnIcon = LucideIcons.building2;
    Color addBtnColor = Theme.of(context).colorScheme.primary;

    switch (_activeTabIndex) {
      case 1:
        addBtnLabel = 'Tambah Depo';
        addBtnIcon = LucideIcons.warehouse;
        addBtnColor = context.semantic.secondaryAccent;
        break;
      case 2:
        addBtnLabel = 'Tambah Area';
        addBtnIcon = LucideIcons.mapPin;
        addBtnColor = context.semantic.success;
        break;
      case 3:
        addBtnLabel = 'Tambah Brand';
        addBtnIcon = LucideIcons.tag;
        addBtnColor = Theme.of(context).colorScheme.primary;
        break;
      case 0:
      default:
        addBtnLabel = 'Tambah Distributor';
        addBtnIcon = LucideIcons.building2;
        addBtnColor = Theme.of(context).colorScheme.primary;
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 680;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Master Distributor, Depo & Area',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola relasi berjenjang Distributor ➔ Depo Logistik ➔ Area Sales Operasional & Brand',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final refreshButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textPrimary,
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: state.isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 14),
                label: Text(state.isLoading ? 'Memuat...' : 'Segarkan', style: const TextStyle(fontWeight: FontWeight.w600)),
                onPressed: state.isLoading ? null : () => ref.read(masterDataProvider.notifier).fetchAllMasterData(force: true),
              );

              final exportButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textPrimary,
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(LucideIcons.download, size: 14),
                label: const Text('Tarik Excel Template', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  ref.read(bulkUploadProvider.notifier).downloadTemplate(
                    entity: 'distributor',
                    withData: true,
                  );
                },
              );

              final addButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: addBtnColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(addBtnIcon, size: 16),
                label: Text(addBtnLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _triggerTabAdd,
              );

              final actionButtons = Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  refreshButton,
                  exportButton,
                  addButton,
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Card with Tabs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border, width: 1.2),
              boxShadow: context.colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isLoading)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Colors.transparent,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 750;

                    final tabBar = TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorColor: addBtnColor,
                      labelColor: context.colors.textPrimary,
                      unselectedLabelColor: context.colors.textMuted,
                      onTap: (val) => setState(() => _activeTabIndex = val),
                      tabs: [
                        Tab(text: 'Distributor (${state.distributors.length})'),
                        Tab(text: 'Depo (${state.depos.length})'),
                        Tab(text: 'Area (${state.areas.length})'),
                        Tab(text: 'Brand (${state.brands.length})'),
                      ],
                    );

                    final searchBox = SizedBox(
                      width: isCompact ? double.infinity : 260,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari data master...',
                          hintStyle: TextStyle(color: context.colors.textMuted),
                          prefixIcon: Icon(LucideIcons.search, size: 15, color: context.colors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: context.colors.bgElevated,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.borderMuted)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.borderMuted)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: addBtnColor)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tabBar,
                          const SizedBox(height: 12),
                          searchBox,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: tabBar),
                        const SizedBox(width: 14),
                        searchBox,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

                // Dynamic Active Tab
                _buildActiveTabContent(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, MasterDataState state) {
    if (state.isLoading && state.distributors.isEmpty && state.depos.isEmpty && state.areas.isEmpty && state.brands.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'Memuat Data Master...',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Sedang menyinkronkan data distributor, depo, area, dan brand dari server',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    switch (_activeTabIndex) {
      case 0:
        return _buildDistributorsList(state);
      case 1:
        return _buildDeposList(state);
      case 2:
        return _buildAreasList(state);
      case 3:
      default:
        return _buildBrandsList(state);
    }
  }

  // ---------------- TAB 1: Distributor List ----------------
  Widget _buildDistributorsList(MasterDataState state) {
    final filtered = state.distributors.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) ||
          d.code.toLowerCase().contains(_searchQuery) ||
          d.depos.any((dp) => dp.name.toLowerCase().contains(_searchQuery) || dp.areas.any((a) => a.name.toLowerCase().contains(_searchQuery)));
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Tidak ada data distributor ditemukan', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filtered.length > 50)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Menampilkan 50 dari total ${filtered.length} distributor. Gunakan kotak cari untuk memfilter data spesifik.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ResponsiveTableCard(
          minWidth: 840,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 80,
            columns: [
              DataColumn(label: Text('Kode', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nama Distributor', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Wilayah Region', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Jaringan Depo & Area', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((d) {
              final totalAreas = d.totalAreasCount;
              final totalDepos = d.totalDeposCount;

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d.code, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: d.name,
                            child: Text(
                              d.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$totalDepos Depo • $totalAreas Area Terhubung',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: d.region != null ? context.semantic.success.withValues(alpha: 0.12) : context.colors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: d.region != null ? context.semantic.success.withValues(alpha: 0.3) : context.colors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.globe, size: 12, color: d.region != null ? context.semantic.success : context.colors.textMuted),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              d.region != null
                                  ? (d.region!.code == d.region!.name ? d.region!.name : '${d.region!.code} - ${d.region!.name}')
                                  : 'Belum Diatur',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: d.region != null ? context.semantic.success : context.colors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _showDistributorDetailDialog(d),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.semantic.infoBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.warehouse, size: 12, color: context.semantic.secondaryAccent),
                                    const SizedBox(width: 5),
                                    Text('$totalDepos Depo', style: TextStyle(color: context.semantic.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.semantic.successBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.mapPin, size: 12, color: context.semantic.success),
                                    const SizedBox(width: 5),
                                    Text('$totalAreas Area', style: TextStyle(color: context.semantic.success, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.eye, size: 16, color: Theme.of(context).colorScheme.primary),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Lihat Hirarki Depo & Area',
                          onPressed: () => _showDistributorDetailDialog(d),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.pencil, size: 16, color: context.semantic.secondaryAccent),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Distributor & Jaringan',
                          onPressed: () => _showComprehensiveDistributorDialog(dist: d),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus Distributor',
                          onPressed: () async {
                            final confirmed = await showConfirmDeleteDialog(
                              context: context,
                              title: 'Hapus Distributor',
                              message: 'Apakah Anda yakin ingin menghapus data distributor "${d.name}" (${d.code}) beserta seluruh jaringan Depo dan Area di dalamnya?',
                            );
                            if (confirmed == true) {
                              if (!mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await ref.read(masterDataProvider.notifier).deleteDistributor(d.id);
                              if (!mounted) return;
                              final st = ref.read(masterDataProvider);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? (st.successMessage ?? 'Distributor berhasil dihapus')
                                      : (st.errorMessage ?? 'Gagal menghapus distributor')),
                                  backgroundColor: ok ? context.semantic.success : context.semantic.danger,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------- TAB 2: Depo List ----------------
  Widget _buildDeposList(MasterDataState state) {
    final filtered = state.depos.where((dp) {
      if (_searchQuery.isEmpty) return true;
      return dp.name.toLowerCase().contains(_searchQuery) ||
          dp.code.toLowerCase().contains(_searchQuery) ||
          (dp.distributor?.name.toLowerCase().contains(_searchQuery) ?? false) ||
          dp.areas.any((a) => a.name.toLowerCase().contains(_searchQuery));
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Tidak ada data depo ditemukan', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filtered.length > 50)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Menampilkan 50 dari total ${filtered.length} depo. Gunakan kotak cari untuk memfilter data spesifik.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ResponsiveTableCard(
          minWidth: 800,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 74,
            columns: [
              DataColumn(label: Text('Kode Depo', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nama Depo', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Induk Distributor', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Area Tercover', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((depo) {
              final distName = depo.distributor?.name ?? '—';

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.semantic.secondaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(depo.code, style: TextStyle(color: context.semantic.secondaryAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Tooltip(
                        message: depo.name,
                        child: Text(
                          depo.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.building2, size: 12, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              distName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    depo.areas.isEmpty
                        ? Text('0 Area', style: TextStyle(color: context.colors.textMuted, fontSize: 12))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: depo.areas.take(3).map((a) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.semantic.successBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(a.name, style: TextStyle(color: context.semantic.success, fontSize: 11, fontWeight: FontWeight.w500)),
                                );
                              }).toList()
                                ..addAll(depo.areas.length > 3
                                    ? [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: context.colors.bgElevated,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('+${depo.areas.length - 3}', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                                        )
                                      ]
                                    : []),
                            ),
                          ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.pencil, size: 16, color: context.semantic.secondaryAccent),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Depo & Area',
                          onPressed: () => _showDepoDialog(depo: depo),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus Depo',
                          onPressed: () async {
                            final confirmed = await showConfirmDeleteDialog(
                              context: context,
                              title: 'Hapus Depo Logistik',
                              message: 'Apakah Anda yakin ingin menghapus depo "${depo.name}" beserta area di dalamnya?',
                            );
                            if (confirmed == true) {
                              await ref.read(masterDataProvider.notifier).deleteDepo(depo.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------- TAB 3: Area List ----------------
  Widget _buildAreasList(MasterDataState state) {
    final filtered = state.areas.where((ar) {
      if (_searchQuery.isEmpty) return true;
      return ar.name.toLowerCase().contains(_searchQuery) ||
          ar.code.toLowerCase().contains(_searchQuery) ||
          (ar.depo?.name.toLowerCase().contains(_searchQuery) ?? false) ||
          (ar.depo?.distributor?.name.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Tidak ada data area ditemukan', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filtered.length > 50)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Menampilkan 50 dari total ${filtered.length} area. Gunakan kotak cari untuk memfilter data spesifik.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ResponsiveTableCard(
          minWidth: 800,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 74,
            columns: [
              DataColumn(label: Text('Kode Area', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nama Area Operasional', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Induk Depo', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Distributor Rekanan', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((area) {
              final depoName = area.depo?.name ?? '—';
              final distName = area.depo?.distributor?.name ?? '—';

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.semantic.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(area.code, style: TextStyle(color: context.semantic.success, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Tooltip(
                        message: area.name,
                        child: Text(
                          area.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.semantic.secondaryAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.warehouse, size: 12, color: context.semantic.secondaryAccent),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              depoName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.semantic.secondaryAccent, fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.building2, size: 12, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              distName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.pencil, size: 16, color: context.semantic.success),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Area',
                          onPressed: () => _showAreaDialog(area: area),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus Area',
                          onPressed: () async {
                            final confirmed = await showConfirmDeleteDialog(
                              context: context,
                              title: 'Hapus Area Operasional',
                              message: 'Apakah Anda yakin ingin menghapus area "${area.name}"?',
                            );
                            if (confirmed == true) {
                              await ref.read(masterDataProvider.notifier).deleteArea(area.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------- TAB 4: Brand List ----------------
  Widget _buildBrandsList(MasterDataState state) {
    final filtered = state.brands.where((br) {
      if (_searchQuery.isEmpty) return true;
      final itemMatch = br.itemCodes.any((ic) => ic.toLowerCase().contains(_searchQuery));
      return br.name.toLowerCase().contains(_searchQuery) ||
          br.code.toLowerCase().contains(_searchQuery) ||
          itemMatch;
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Tidak ada data brand ditemukan', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filtered.length > 100)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Menampilkan 100 dari total ${filtered.length} brand. Gunakan kotak cari untuk memfilter data spesifik.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ResponsiveTableCard(
          minWidth: 600,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 70,
            columns: [
              DataColumn(label: Text('Kode Brand', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Nama Merek Dagang', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Mapping ItemCode SAP', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((brand) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(brand.code, style: TextStyle(color: context.semantic.warning, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Tooltip(
                        message: brand.name,
                        child: Text(
                          brand.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Builder(
                        builder: (_) {
                          if (brand.isAllBrands) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Gabungan: Semua Brand (All Brand)',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          if (brand.isComposite) {
                            final brandById = {for (final b in state.brands) b.id: b};
                            final compNames = brand.componentBrandIds
                                .map((id) => brandById[id]?.name ?? brandById[id]?.code)
                                .whereType<String>()
                                .toList();
                            final label = compNames.isNotEmpty
                                ? 'Gabungan ${compNames.length} Brand: ${compNames.join(' + ')}'
                                : 'Gabungan: ${brand.code}';
                            return Tooltip(
                              message: label,
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          return brand.itemCodes.isEmpty
                              ? Text('Belum ada item SAP', style: TextStyle(color: context.colors.textMuted, fontSize: 12))
                              : Tooltip(
                                  message: brand.itemCodes.join(', '),
                                  child: Text(
                                    '${brand.itemCodes.length} Item: ${brand.itemCodes.take(5).join(', ')}${brand.itemCodes.length > 5 ? ', ...' : ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.semantic.secondaryAccent, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                );
                        },
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.pencil, size: 16, color: Theme.of(context).colorScheme.primary),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Brand',
                          onPressed: () => _showBrandDialog(brand: brand),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 16, color: context.semantic.danger),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus Brand',
                          onPressed: () async {
                            final confirmed = await showConfirmDeleteDialog(
                              context: context,
                              title: 'Hapus Brand',
                              message: 'Apakah Anda yakin ingin menghapus brand "${brand.name}"?',
                            );
                            if (confirmed == true) {
                              await ref.read(masterDataProvider.notifier).deleteBrand(brand.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------- Helper Draft Models for Nested Builder ----------------
class _DepoDraft {
  int? id;
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final List<_AreaDraft> areas;

  _DepoDraft({
    this.id,
    required String code,
    required String name,
    List<_AreaDraft>? areas,
  })  : codeCtrl = TextEditingController(text: code),
        nameCtrl = TextEditingController(text: name),
        areas = areas ?? [];
}

class _AreaDraft {
  int? id;
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;

  _AreaDraft({
    this.id,
    required String code,
    required String name,
  })  : codeCtrl = TextEditingController(text: code),
        nameCtrl = TextEditingController(text: name);
}

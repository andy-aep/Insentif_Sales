import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/master_model.dart';
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
  void _showComprehensiveDistributorDialog({DistributorModel? dist}) {
    final colors = context.colors;
    final isEdit = dist != null;

    final codeCtrl = TextEditingController(text: dist?.code ?? '');
    final nameCtrl = TextEditingController(text: dist?.name ?? '');
    int? selectedRegionId = dist?.regionId;

    // Draft depos and nested areas
    List<_DepoDraft> draftDepos = [];
    if (dist != null && dist.depos.isNotEmpty) {
      draftDepos = dist.depos.map((d) {
        return _DepoDraft(
          id: d.id,
          code: d.code,
          name: d.name,
          areas: d.areas.map((a) => _AreaDraft(id: a.id, code: a.code, name: a.name)).toList(),
        );
      }).toList();
    } else {
      // Starter with 1 depo & 1 area for intuitive onboarding
      draftDepos = [
        _DepoDraft(
          code: '',
          name: '',
          areas: [
            _AreaDraft(code: '', name: ''),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.building2, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Master Distributor & Jaringan' : 'Tambah Master Distributor, Depo & Area Terintegrasi',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
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
                                    const Icon(LucideIcons.building, size: 16, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Identitas Distributor Utama',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
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
                                        decoration: const InputDecoration(labelText: 'Kode Distributor *', hintText: 'Contoh: DST01'),
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
                                            dropdownColor: colors.bgElevated,
                                            style: TextStyle(color: colors.textPrimary),
                                            decoration: const InputDecoration(
                                              labelText: 'Wilayah / Region',
                                              prefixIcon: Icon(LucideIcons.globe, size: 16),
                                            ),
                                            items: [
                                              const DropdownMenuItem<int?>(
                                                value: null,
                                                child: Text('Tanpa Region (Nasional)'),
                                              ),
                                              ...mState.regions.map((reg) => DropdownMenuItem<int?>(
                                                value: reg.id,
                                                child: Text('${reg.code} - ${reg.name}'),
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
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                  ),
                                  Text(
                                    'Setiap distributor dapat memiliki beberapa depo, dan setiap depo mencakup beberapa area.',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
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
                                          _AreaDraft(code: '', name: 'Area 1'),
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
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
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
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(LucideIcons.warehouse, size: 13, color: Color(0xFF0369A1)),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Depo #${dIdx + 1}',
                                                style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
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
                                        borderRadius: BorderRadius.circular(10),
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
                                                  const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF10B981)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Area Tercover (${depo.areas.length} Area)',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.textPrimary),
                                                  ),
                                                ],
                                              ),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: const Color(0xFF10B981),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: Size.zero,
                                                ),
                                                icon: const Icon(LucideIcons.plus, size: 13),
                                                label: const Text('Tambah Area', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    depo.areas.add(_AreaDraft(code: '', name: ''));
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
                                                          hintText: 'Auto / AR${aIdx + 1}',
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
                                                      icon: const Icon(LucideIcons.x, size: 14, color: AppColors.danger),
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
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            if (code.isEmpty || name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kode dan Nama Distributor wajib diisi!')),
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
  void _showDistributorDetailDialog(DistributorModel dist) {
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.building2, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Struktur Hirarki: ${dist.name}',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(dist.code, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dist.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Region: ${dist.region != null ? "${dist.region!.code} - ${dist.region!.name}" : "Nasional / Tanpa Region"} • Total: ${dist.depos.length} Depo Logistik Terdaftar',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text('Daftar Jaringan Depo & Area:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      const SizedBox(height: 10),

                      if (dist.depos.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: colors.bgElevated, borderRadius: BorderRadius.circular(10)),
                          child: Text('Belum ada depo di distributor ini.', style: TextStyle(color: colors.textMuted)),
                        )
                      else
                        ...dist.depos.map((depo) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
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
                                    const Icon(LucideIcons.warehouse, size: 15, color: Color(0xFF0288D1)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${depo.name} (${depo.code})',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 13.5),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                                      child: Text('${depo.areas.length} Area', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11)),
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
                decoration: BoxDecoration(color: colors.bgElevated, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
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
    if (depo != null && depo.areas.isNotEmpty) {
      draftAreas = depo.areas.map((a) => _AreaDraft(id: a.id, code: a.code, name: a.name)).toList();
    } else {
      draftAreas = [_AreaDraft(code: '', name: '')];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                const Icon(LucideIcons.warehouse, color: Color(0xFF0288D1), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Depo: ${depo.name}' : 'Tambah Depo Logistik Baru',
                    style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
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
                      initialValue: selectedDistId,
                      dropdownColor: colors.bgElevated,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Induk Distributor *'),
                      items: state.distributors.map((dist) {
                        return DropdownMenuItem<int>(
                          value: dist.id,
                          child: Text('${dist.name} (${dist.code})'),
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
                              draftAreas.add(_AreaDraft(code: '', name: ''));
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
                              icon: const Icon(LucideIcons.x, size: 14, color: AppColors.danger),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
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
    final codeCtrl = TextEditingController(text: area?.code ?? '');
    final nameCtrl = TextEditingController(text: area?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                const Icon(LucideIcons.mapPin, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Area Operasional: ${area.name}' : 'Tambah Area Operasional Baru',
                    style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
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
                    initialValue: selectedDepoId,
                    dropdownColor: colors.bgElevated,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Pilih Induk Depo *'),
                    items: state.depos.map((depo) {
                      final distName = depo.distributor?.name ?? 'Distributor';
                      return DropdownMenuItem<int>(
                        value: depo.id,
                        child: Text('${depo.name} ($distName)'),
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
                    decoration: const InputDecoration(labelText: 'Kode Area *', hintText: 'Contoh: AR-SBY-01'),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedDepoId == null || codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pilih Depo dan isi Kode & Nama Area!')),
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
    final isEdit = brand != null;
    final codeCtrl = TextEditingController(text: brand?.code ?? '');
    final nameCtrl = TextEditingController(text: brand?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Row(
          children: [
            const Icon(LucideIcons.tag, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEdit ? 'Edit Brand: ${brand.name}' : 'Tambah Brand Baru',
                style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(labelText: 'Kode Brand *', hintText: 'Contoh: BRD01'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nama Merek Dagang *', hintText: 'Contoh: Minyak Goreng Kita'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kode dan Nama Brand wajib diisi!')),
                );
                return;
              }

              Navigator.pop(ctx);
              final ok = await ref.read(masterDataProvider.notifier).saveBrand(
                    id: brand?.id,
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Brand berhasil disimpan' : 'Gagal menyimpan brand')),
                );
              }
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Brand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masterDataProvider);

    String addBtnLabel = 'Tambah Distributor';
    IconData addBtnIcon = LucideIcons.building2;
    Color addBtnColor = const Color(0xFF4F46E5);

    switch (_activeTabIndex) {
      case 1:
        addBtnLabel = 'Tambah Depo';
        addBtnIcon = LucideIcons.warehouse;
        addBtnColor = const Color(0xFF0288D1);
        break;
      case 2:
        addBtnLabel = 'Tambah Area';
        addBtnIcon = LucideIcons.mapPin;
        addBtnColor = const Color(0xFF10B981);
        break;
      case 3:
        addBtnLabel = 'Tambah Brand';
        addBtnIcon = LucideIcons.tag;
        addBtnColor = const Color(0xFFF59E0B);
        break;
      case 0:
      default:
        addBtnLabel = 'Tambah Distributor';
        addBtnIcon = LucideIcons.building2;
        addBtnColor = const Color(0xFF4F46E5);
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
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola relasi berjenjang Distributor ➔ Depo Logistik ➔ Area Sales Operasional & Brand',
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final addButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: addBtnColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(addBtnIcon, size: 16),
                label: Text(addBtnLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _triggerTabAdd,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  addButton,
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border, width: 1.2),
              boxShadow: context.colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.borderMuted)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.borderMuted)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: addBtnColor)),
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

    return ResponsiveTableCard(
      minWidth: 800,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columnSpacing: 16,
        horizontalMargin: 12,
        columns: [
          DataColumn(label: Text('Kode', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Distributor', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Wilayah Region', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Jaringan Depo & Area', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((d) {
          final totalAreas = d.depos.fold<int>(0, (sum, dp) => sum + dp.areas.length);

          return DataRow(
            cells: [
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(d.code, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.name, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${d.depos.length} Depo • $totalAreas Area Terhubung', style: TextStyle(color: context.colors.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: d.region != null ? const Color(0xFF8B5CF6).withValues(alpha: 0.12) : context.colors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: d.region != null ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : context.colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.globe, size: 12, color: d.region != null ? const Color(0xFF8B5CF6) : context.colors.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        d.region != null ? '${d.region!.code} - ${d.region!.name}' : 'Belum Diatur',
                        style: TextStyle(
                          color: d.region != null ? const Color(0xFF8B5CF6) : context.colors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.warehouse, size: 12, color: Color(0xFF0288D1)),
                              const SizedBox(width: 5),
                              Text('${d.depos.length} Depo', style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.mapPin, size: 12, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 5),
                              Text('$totalAreas Area', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.slate400),
                      ],
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.eye, size: 16, color: Color(0xFF4F46E5)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Lihat Hirarki Depo & Area',
                      onPressed: () => _showDistributorDetailDialog(d),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF0288D1)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Distributor & Jaringan',
                      onPressed: () => _showComprehensiveDistributorDialog(dist: d),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
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
                          await ref.read(masterDataProvider.notifier).deleteDistributor(d.id);
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

    return ResponsiveTableCard(
      minWidth: 800,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columnSpacing: 16,
        horizontalMargin: 12,
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
                    color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(depo.code, style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text(depo.name, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.building2, size: 12, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 5),
                      Text(distName, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w500, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              DataCell(
                depo.areas.isEmpty
                    ? Text('0 Area', style: TextStyle(color: context.colors.textMuted, fontSize: 12))
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: depo.areas.take(3).map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(a.name, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w500)),
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
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF0288D1)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Depo & Area',
                      onPressed: () => _showDepoDialog(depo: depo),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
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

    return ResponsiveTableCard(
      minWidth: 800,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columnSpacing: 16,
        horizontalMargin: 12,
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(area.code, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text(area.name, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.warehouse, size: 12, color: Color(0xFF0288D1)),
                      const SizedBox(width: 5),
                      Text(depoName, style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.w500, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.building2, size: 12, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 5),
                      Text(distName, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w500, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF10B981)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Area',
                      onPressed: () => _showAreaDialog(area: area),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
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
    );
  }

  // ---------------- TAB 4: Brand List ----------------
  Widget _buildBrandsList(MasterDataState state) {
    final filtered = state.brands.where((br) {
      if (_searchQuery.isEmpty) return true;
      return br.name.toLowerCase().contains(_searchQuery) || br.code.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('Tidak ada data brand ditemukan', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return ResponsiveTableCard(
      minWidth: 600,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columnSpacing: 16,
        horizontalMargin: 12,
        columns: [
          DataColumn(label: Text('Kode Brand', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nama Merek Dagang', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((brand) {
          return DataRow(
            cells: [
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(brand.code, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text(brand.name, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600))),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Brand',
                      onPressed: () => _showBrandDialog(brand: brand),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
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

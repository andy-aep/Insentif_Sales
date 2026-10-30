import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/models/master_model.dart';
import '../../../data/models/master_target_model.dart';
import '../../users_management/providers/user_management_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/master_target_provider.dart';
import '../providers/sales_assignment_provider.dart';

class MasterTargetScreen extends ConsumerStatefulWidget {
  const MasterTargetScreen({super.key});

  @override
  ConsumerState<MasterTargetScreen> createState() => _MasterTargetScreenState();
}

class _MasterTargetScreenState extends ConsumerState<MasterTargetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeTabIndex = 0;

  // Filter state for Tab 0: Target Distributor
  int? _filterDistributorId;
  String _filterLevel = 'ALL'; // 'ALL', 'DEPO', 'AREA'
  String _filterMetric = 'ALL'; // 'ALL', 'SELL_IN', 'SELL_OUT', 'AO'
  int? _filterBrandId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(masterTargetProvider.notifier).fetchTargets();
      ref.read(masterDataProvider.notifier).fetchAllMasterData();
      ref.read(userManagementProvider.notifier).fetchAll();
      ref.read(salesAssignmentProvider.notifier).fetchAllAssignments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // DIALOG: Tambah & Edit Master Target Kuota
  // =========================================================================
  void _showCustomPeriodDialog() {
    final colors = context.colors;
    final currentPeriod = ref.read(masterTargetProvider).selectedPeriod;
    final ctrl = TextEditingController(text: currentPeriod != 'ALL' ? currentPeriod : '202610');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: colors.border)),
        title: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 20, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            Text('Ganti Filter Periode', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan format periode target YYYYMM (contoh: 202610, 202611)', style: TextStyle(color: colors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Periode (YYYYMM)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: colors.bgElevated,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                ref.read(masterTargetProvider.notifier).setPeriod(text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTargetDialog() => _showTargetFormDialog();

  void _showTargetFormDialog({MasterTargetModel? targetToEdit}) {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);
    final masterState = ref.read(masterDataProvider);
    final assignState = ref.read(salesAssignmentProvider);
    final isEdit = targetToEdit != null;

    String selectedKategori = 'DISTRIBUTOR';
    int? selectedDistributorId;
    String selectedLevel = 'DEPO';
    int? selectedDepoId;
    int? selectedAreaId;
    int? selectedBrandId;
    int? selectedUserId;
    String selectedTargetType = 'SELL_OUT';
    String defaultQuota = '3000';
    String defaultOutlet = '50';
    final activeFilterPeriod = ref.read(masterTargetProvider).selectedPeriod;
    String defaultPeriod = activeFilterPeriod != 'ALL' && activeFilterPeriod.isNotEmpty ? activeFilterPeriod : '202610';

    if (targetToEdit != null) {
      selectedKategori = targetToEdit.kategoriSkema == 'KONSUMSI' ? 'DISTRIBUTOR' : targetToEdit.kategoriSkema;
      selectedDistributorId = targetToEdit.distributorId;
      selectedLevel = targetToEdit.level;
      selectedBrandId = targetToEdit.brandId;
      selectedUserId = targetToEdit.userId;
      selectedTargetType = targetToEdit.targetType;
      defaultQuota = targetToEdit.targetQuota % 1 == 0 ? targetToEdit.targetQuota.toInt().toString() : targetToEdit.targetQuota.toString();
      defaultOutlet = targetToEdit.targetOutlet?.toString() ?? targetToEdit.targetQuota.toInt().toString();
      defaultPeriod = targetToEdit.period;
    } else {
      selectedKategori = _activeTabIndex == 0
          ? 'DISTRIBUTOR'
          : (_activeTabIndex == 1 ? 'INDUSTRI' : 'SURABAYA');
      selectedDistributorId = masterState.distributors.isNotEmpty ? masterState.distributors.first.id : null;
      selectedLevel = 'DEPO';
      selectedBrandId = masterState.brands.isNotEmpty ? masterState.brands.first.id : null;
      selectedUserId = userState.users.isNotEmpty ? userState.users.first.id : null;
      selectedTargetType = selectedKategori == 'DISTRIBUTOR' ? 'SELL_OUT' : (selectedKategori == 'INDUSTRI' ? 'SELL_IN' : 'SELL_OUT');
    }

    DistributorModel? currentDist = selectedDistributorId != null
        ? masterState.distributors.where((d) => d.id == selectedDistributorId).firstOrNull
        : (masterState.distributors.isNotEmpty ? masterState.distributors.first : null);

    if (targetToEdit != null && targetToEdit.depoId != null) {
      selectedDepoId = targetToEdit.depoId;
    } else {
      selectedDepoId = (currentDist != null && currentDist.depos.isNotEmpty) ? currentDist.depos.first.id : null;
    }

    DepoModel? currentDepo = (currentDist != null && selectedDepoId != null)
        ? currentDist.depos.where((dp) => dp.id == selectedDepoId).firstOrNull
        : ((currentDist != null && currentDist.depos.isNotEmpty) ? currentDist.depos.first : null);

    if (targetToEdit != null && targetToEdit.areaId != null) {
      selectedAreaId = targetToEdit.areaId;
    } else {
      selectedAreaId = (currentDepo != null && currentDepo.areas.isNotEmpty) ? currentDepo.areas.first.id : null;
    }

    if (targetToEdit != null && targetToEdit.brandId != null) {
      selectedBrandId = targetToEdit.brandId;
    } else if (selectedBrandId == null && masterState.brands.isNotEmpty) {
      selectedBrandId = masterState.brands.first.id;
    }

    final quotaCtrl = TextEditingController(text: defaultQuota);
    final outletCtrl = TextEditingController(text: defaultOutlet);
    final periodCtrl = TextEditingController(text: defaultPeriod);
    final yearCtrl = TextEditingController(
      text: defaultPeriod.length >= 4 ? defaultPeriod.substring(0, 4) : DateTime.now().year.toString(),
    );
    bool isFullYearMode = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDistributor = selectedKategori == 'DISTRIBUTOR';
          final isOutletMetric = selectedTargetType == 'AO' || selectedTargetType == 'NOO';

          // Auto-detect sales personil for Distributor based on assignment
          UserModel? detectedSales;
          String detectedRoleText = '';
          if (isDistributor) {
            if (selectedLevel == 'AREA' && selectedAreaId != null) {
              final spvAssign = assignState.distributorAssignments.where((a) => a.areaId == selectedAreaId && a.isActive).firstOrNull;
              if (spvAssign != null) {
                detectedSales = spvAssign.user;
                detectedRoleText = 'SPV Area Penanggung Jawab';
              }
            } else if (selectedDistributorId != null) {
              final asmAssign = assignState.distributorAssignments.where((a) => a.distributorId == selectedDistributorId && (a.user?.position?.code.toUpperCase() == 'ASM') && a.isActive).firstOrNull;
              if (asmAssign != null) {
                detectedSales = asmAssign.user;
                detectedRoleText = 'ASM Distributor Penanggung Jawab';
              }
            }
          }

          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isEdit ? LucideIcons.edit3 : LucideIcons.target, color: AppColors.primaryLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Ubah Target Kuota Penjualan' : 'Tetapkan Target Kuota Penjualan',
                        style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        isEdit
                            ? 'Perbarui besaran kuota atau alokasi target untuk periode ${targetToEdit.period}'
                            : (isDistributor ? 'Set target per Distributor, Depo, atau Area per Brand' : 'Tetapkan kuota penjualan per personil sales'),
                        style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Skema Kategori
                    Text('Skema Target *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedKategori,
                      dropdownColor: colors.bgElevated,
                      isExpanded: true,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: colors.bgElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('Target Distributor (Konsumsi: Depo / Area / Brand)')),
                        DropdownMenuItem(value: 'INDUSTRI', child: Text('Target Industri (B2B)')),
                        DropdownMenuItem(value: 'SURABAYA', child: Text('Target Sales Surabaya (TO / Canvasing)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedKategori = val;
                            if (val == 'DISTRIBUTOR') selectedTargetType = 'SELL_OUT';
                            if (val == 'INDUSTRI') selectedTargetType = 'SELL_IN';
                            if (val == 'SURABAYA') selectedTargetType = 'SELL_OUT';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // ========================================================
                    // HIERARKI DISTRIBUTOR: DEPO / AREA PER BRAND
                    // ========================================================
                    if (isDistributor) ...[
                      // Pilih Distributor
                      Text('Pilih Distributor *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDistributorId,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.building2, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: masterState.distributors.map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDistributorId = val;
                              currentDist = masterState.distributors.where((d) => d.id == val).firstOrNull;
                              selectedDepoId = (currentDist != null && currentDist!.depos.isNotEmpty) ? currentDist!.depos.first.id : null;
                              currentDepo = (currentDist != null && currentDist!.depos.isNotEmpty) ? currentDist!.depos.first : null;
                              selectedAreaId = (currentDepo != null && currentDepo!.areas.isNotEmpty) ? currentDepo!.areas.first.id : null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Tingkat Target: Depo (ASM) vs Area (SPV)
                      Text('Tingkat Target Kuota *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedLevel = 'DEPO'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedLevel == 'DEPO' ? AppColors.primary.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedLevel == 'DEPO' ? AppColors.primary : colors.border,
                                    width: selectedLevel == 'DEPO' ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedLevel == 'DEPO' ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                      size: 16,
                                      color: selectedLevel == 'DEPO' ? AppColors.primary : colors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Target per Depo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.textPrimary)),
                                          Text('Penanggung Jawab: ASM', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedLevel = 'AREA'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedLevel == 'AREA' ? AppColors.warning.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedLevel == 'AREA' ? AppColors.warning : colors.border,
                                    width: selectedLevel == 'AREA' ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedLevel == 'AREA' ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                      size: 16,
                                      color: selectedLevel == 'AREA' ? AppColors.warning : colors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Target per Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: colors.textPrimary)),
                                          Text('Penanggung Jawab: SPV', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pilih Depo
                      Text('Pilih Depo Distributor *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        key: ValueKey('dialog_depo_${selectedDistributorId}_$selectedDepoId'),
                        initialValue: selectedDepoId,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.home, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: (currentDist?.depos ?? []).map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDepoId = val;
                              currentDepo = currentDist?.depos.where((d) => d.id == val).firstOrNull;
                              selectedAreaId = (currentDepo != null && currentDepo!.areas.isNotEmpty) ? currentDepo!.areas.first.id : null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Jika Level Area: Pilih Area
                      if (selectedLevel == 'AREA') ...[
                        Text('Pilih Area Operasional (SPV) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('dialog_area_${selectedDepoId}_$selectedAreaId'),
                          initialValue: selectedAreaId,
                          dropdownColor: colors.bgElevated,
                          isExpanded: true,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.warning),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: (currentDepo?.areas ?? []).map((a) {
                            return DropdownMenuItem<int>(
                              value: a.id,
                              child: Text('${a.name} (${a.code})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedAreaId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Pilih Brand
                      Text('Pilih Brand Produk *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedBrandId,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.tag, size: 18, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: masterState.brands.map((b) {
                          return DropdownMenuItem<int>(
                            value: b.id,
                            child: Text('${b.name} (${b.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedBrandId = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Banner info sales penanggung jawab otomatis
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedLevel == 'DEPO' ? LucideIcons.crown : LucideIcons.userCheck,
                              size: 20,
                              color: selectedLevel == 'DEPO' ? AppColors.primaryLight : AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detectedRoleText.isNotEmpty ? detectedRoleText : (selectedLevel == 'DEPO' ? 'Posisi ASM (Area Sales Manager)' : 'Posisi SPV (Sales Supervisor)'),
                                    style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    detectedSales != null
                                        ? '${detectedSales.name} (@${detectedSales.username})'
                                        : '(Belum ada personil di-assign ke unit ini)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: detectedSales != null ? colors.textPrimary : colors.textMuted,
                                      fontStyle: detectedSales != null ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      // Non-distributor: pilih sales langsung
                      Text('Pilih Sales Personil *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedUserId,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.user, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: userState.users.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text('${u.name} (@${u.username})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedUserId = val);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Metrik Target
                    Text('Pilih Metrik Target *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTargetType,
                      dropdownColor: colors.bgElevated,
                      isExpanded: true,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: colors.bgElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: isDistributor
                          ? const [
                              DropdownMenuItem(value: 'SELL_OUT', child: Text('Sell-Out (Kg / Box)')),
                              DropdownMenuItem(value: 'SELL_IN', child: Text('Sell-In (Kg / Box)')),
                              DropdownMenuItem(value: 'AO', child: Text('Active Outlet (AO Toko)')),
                            ]
                          : (selectedKategori == 'INDUSTRI'
                              ? const [
                                  DropdownMenuItem(value: 'SELL_IN', child: Text('Sell-In (Kg / Tonase)')),
                                  DropdownMenuItem(value: 'NOO', child: Text('New Open Outlet (NOO)')),
                                ]
                              : const [
                                  DropdownMenuItem(value: 'SELL_OUT', child: Text('Sell-Out (Kg / Box)')),
                                  DropdownMenuItem(value: 'AO', child: Text('Active Outlet (AO Toko)')),
                                ]),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedTargetType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Besaran Angka Target
                    if (!isOutletMetric)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Besaran Kuota Volume (Kg / Box) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: quotaCtrl,
                            style: TextStyle(color: colors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(LucideIcons.scale, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: colors.bgElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Jumlah Toko / Outlet ($selectedTargetType) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: outletCtrl,
                            style: TextStyle(color: colors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(LucideIcons.store, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: colors.bgElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Periode Pilihan: Bulanan (1 Bulan) vs 1 Tahun Penuh (12 Bulan)
                    if (!isEdit) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setDialogState(() => isFullYearMode = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: !isFullYearMode ? AppColors.primary.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isFullYearMode ? AppColors.primary : colors.border,
                                    width: !isFullYearMode ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.calendar, size: 14, color: !isFullYearMode ? AppColors.primaryLight : colors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Target 1 Bulan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !isFullYearMode ? FontWeight.bold : FontWeight.normal,
                                        color: !isFullYearMode ? colors.textPrimary : colors.textMuted,
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
                              onTap: () => setDialogState(() => isFullYearMode = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isFullYearMode ? AppColors.primary.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFullYearMode ? AppColors.primary : colors.border,
                                    width: isFullYearMode ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.calendarRange, size: 14, color: isFullYearMode ? AppColors.primaryLight : colors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Setahun (12 Bulan)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isFullYearMode ? FontWeight.bold : FontWeight.normal,
                                        color: isFullYearMode ? colors.textPrimary : colors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (isFullYearMode && !isEdit) ...[
                      Row(
                        children: [
                          Text('Tahun Target (YYYY) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Otomatis 12 Bulan (Jan - Des)', style: TextStyle(color: AppColors.info, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: yearCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 2026',
                          prefixIcon: const Icon(LucideIcons.calendarRange, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      Text('Periode (YYYYMM) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: periodCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 202610',
                          prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: colors.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(isEdit ? LucideIcons.check : LucideIcons.save, size: 16, color: Colors.white),
                label: Text(
                  isEdit
                      ? 'Simpan Perubahan'
                      : (isFullYearMode ? 'Simpan Target 1 Tahun (12 Bulan)' : 'Simpan Target'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final period = periodCtrl.text.trim().isEmpty ? '202610' : periodCtrl.text.trim();
                  final year = yearCtrl.text.trim().isEmpty ? '2026' : yearCtrl.text.trim();
                  final quotaVal = double.tryParse(quotaCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  final outletVal = int.tryParse(outletCtrl.text);

                  if (isDistributor && selectedDistributorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wajib memilih Distributor!'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (isDistributor && selectedDepoId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wajib memilih Depo!'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (isDistributor && selectedLevel == 'AREA' && selectedAreaId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Untuk target tingkat Area, wajib memilih Area!'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  final success = isEdit
                      ? await ref.read(masterTargetProvider.notifier).updateTarget(
                          id: targetToEdit.id,
                          userId: isDistributor ? (detectedSales?.id ?? targetToEdit.userId) : selectedUserId,
                          distributorId: isDistributor ? selectedDistributorId : null,
                          depoId: isDistributor ? selectedDepoId : null,
                          areaId: (isDistributor && selectedLevel == 'AREA') ? selectedAreaId : null,
                          brandId: isDistributor ? selectedBrandId : null,
                          level: isDistributor ? selectedLevel : 'SALES',
                          kategoriSkema: isDistributor ? 'KONSUMSI' : selectedKategori,
                          targetType: selectedTargetType,
                          period: period,
                          targetQuota: isOutletMetric ? (outletVal?.toDouble() ?? 0.0) : quotaVal,
                          targetOutlet: isOutletMetric ? outletVal : null,
                        )
                      : await ref.read(masterTargetProvider.notifier).saveTarget(
                          userId: isDistributor ? (detectedSales?.id) : selectedUserId,
                          distributorId: isDistributor ? selectedDistributorId : null,
                          depoId: isDistributor ? selectedDepoId : null,
                          areaId: (isDistributor && selectedLevel == 'AREA') ? selectedAreaId : null,
                          brandId: isDistributor ? selectedBrandId : null,
                          level: isDistributor ? selectedLevel : 'SALES',
                          kategoriSkema: isDistributor ? 'KONSUMSI' : selectedKategori,
                          targetType: selectedTargetType,
                          period: period,
                          isFullYear: isFullYearMode,
                          year: year,
                          targetQuota: isOutletMetric ? (outletVal?.toDouble() ?? 0.0) : quotaVal,
                          targetOutlet: isOutletMetric ? outletVal : null,
                        );

                  if (ctx.mounted) Navigator.pop(ctx);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? (isEdit ? 'Target kuota berhasil diperbarui!' : 'Target kuota berhasil disimpan!')
                            : 'Gagal memproses target kuota'),
                        backgroundColor: success ? AppColors.success : AppColors.danger,
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
    final targetState = ref.watch(masterTargetProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Master Target Kuota Penjualan',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Distributor & Sales',
                          style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manajemen kuota target per Distributor (Depo & Area per Brand untuk ASM & SPV), Industri, dan Sales Surabaya',
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final actionButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                label: const Text('Input Target Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _showAddTargetDialog,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 16),
                    actionButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    tooltip: 'Muat Ulang Target',
                    color: context.colors.textMuted,
                    onPressed: () {
                      ref.read(masterTargetProvider.notifier).fetchTargets();
                      ref.read(masterDataProvider.notifier).fetchAllMasterData();
                      ref.read(salesAssignmentProvider.notifier).fetchAllAssignments();
                    },
                  ),
                  const SizedBox(width: 8),
                  actionButton,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Tab Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border, width: 1.2),
              boxShadow: context.colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  onTap: (val) => setState(() => _activeTabIndex = val),
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primaryLight,
                  labelColor: context.colors.textPrimary,
                  unselectedLabelColor: context.colors.textMuted,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.building2, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Distributor: Depo & Area (${targetState.targets.where((t) => t.kategoriSkema == 'KONSUMSI' || t.kategoriSkema == 'DISTRIBUTOR').length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.factory, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Industri (${targetState.targets.where((t) => t.kategoriSkema == 'INDUSTRI').length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Sales Surabaya (${targetState.targets.where((t) => t.kategoriSkema == 'SURABAYA').length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

                if (targetState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildActiveTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildDistributorTargetTab();
      case 1:
        return _buildGenericTargetTable('INDUSTRI');
      case 2:
      default:
        return _buildGenericTargetTable('SURABAYA');
    }
  }

  // =========================================================================
  // TAB 0: TARGET DISTRIBUTOR (DEPO & AREA PER BRAND UNTUK ASM & SPV)
  // =========================================================================
  Widget _buildDistributorTargetTab() {
    final colors = context.colors;
    final targetState = ref.watch(masterTargetProvider);
    final masterState = ref.watch(masterDataProvider);
    final assignState = ref.watch(salesAssignmentProvider);

    // Filter distributor targets
    final allDistTargets = targetState.targets.where((t) => t.kategoriSkema == 'KONSUMSI' || t.kategoriSkema == 'DISTRIBUTOR').toList();

    final filteredList = allDistTargets.where((t) {
      if (_filterDistributorId != null && t.distributorId != _filterDistributorId) return false;
      if (_filterLevel == 'DEPO' && t.level != 'DEPO') return false;
      if (_filterLevel == 'AREA' && t.level != 'AREA') return false;
      if (_filterMetric != 'ALL' && t.targetType != _filterMetric) return false;
      if (_filterBrandId != null && t.brandId != _filterBrandId) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final distName = (t.distributor?.name ?? '').toLowerCase();
        final depoName = (t.depo?.name ?? '').toLowerCase();
        final areaName = (t.area?.name ?? '').toLowerCase();
        final brandName = (t.brand?.name ?? '').toLowerCase();
        final userName = (t.user?.name ?? '').toLowerCase();
        return distName.contains(q) || depoName.contains(q) || areaName.contains(q) || brandName.contains(q) || userName.contains(q);
      }
      return true;
    }).toList();

    // Summary calculation (gunakan agregasi backend jika tanpa filter lokal, atau filter lokal jika spesifik)
    final summary = targetState.summary;
    final bool hasLocalFilters = _filterDistributorId != null || _filterLevel != 'ALL' || _filterMetric != 'ALL' || _filterBrandId != null || _searchQuery.isNotEmpty;

    final double totalSellIn = !hasLocalFilters && summary != null
        ? ((summary['total_sell_in'] as num?)?.toDouble() ?? 0.0)
        : filteredList.where((t) => t.targetType == 'SELL_IN').fold<double>(0.0, (sum, t) => sum + t.targetQuota);

    final double totalSellOut = !hasLocalFilters && summary != null
        ? ((summary['total_sell_out'] as num?)?.toDouble() ?? 0.0)
        : filteredList.where((t) => t.targetType == 'SELL_OUT').fold<double>(0.0, (sum, t) => sum + t.targetQuota);

    final int totalAo = !hasLocalFilters && summary != null
        ? ((summary['total_ao'] as num?)?.toInt() ?? 0)
        : filteredList.where((t) => t.targetType == 'AO').fold<int>(0, (sum, t) => sum + (t.targetOutlet ?? t.targetQuota.toInt()));

    final int depoCount = !hasLocalFilters && summary != null
        ? ((summary['depo_count'] as num?)?.toInt() ?? 0)
        : filteredList.where((t) => t.level == 'DEPO').length;

    final int areaCount = !hasLocalFilters && summary != null
        ? ((summary['area_count'] as num?)?.toInt() ?? 0)
        : filteredList.where((t) => t.level == 'AREA').length;

    final selectedDistObj = masterState.distributors.where((d) => d.id == _filterDistributorId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Banner
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMiniKpiCard(
              title: selectedDistObj != null ? 'Distributor Aktif' : 'Total Target Distributor',
              value: selectedDistObj != null ? selectedDistObj.name : '${masterState.distributors.length} Distributor',
              icon: LucideIcons.building2,
              color: AppColors.primary,
            ),
            _buildMiniKpiCard(
              title: 'Total Kuota Sell-Out',
              value: '${CurrencyFormatter.formatNumber(totalSellOut)} Kg',
              icon: LucideIcons.trendingUp,
              color: const Color(0xFF8B5CF6),
            ),
            _buildMiniKpiCard(
              title: 'Total Kuota Sell-In',
              value: '${CurrencyFormatter.formatNumber(totalSellIn)} Kg',
              icon: LucideIcons.truck,
              color: AppColors.info,
            ),
            _buildMiniKpiCard(
              title: 'Total Active Outlet (AO)',
              value: '$totalAo Toko',
              icon: LucideIcons.store,
              color: AppColors.success,
            ),
            _buildMiniKpiCard(
              title: 'Rincian Kuota',
              value: '$depoCount Depo • $areaCount Area',
              icon: LucideIcons.layers,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Toolbar (Pilih Periode, Distributor, Tingkat, Brand, Metrik, & Search)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1180;

              final periodWidget = DropdownButtonFormField<String>(
                key: ValueKey('period_dist_${targetState.selectedPeriod}'),
                initialValue: targetState.availablePeriods.contains(targetState.selectedPeriod) || targetState.selectedPeriod == 'ALL'
                    ? targetState.selectedPeriod
                    : (targetState.availablePeriods.isNotEmpty ? targetState.availablePeriods.first : '202610'),
                dropdownColor: colors.bgElevated,
                isExpanded: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Filter Periode',
                  labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                  suffixIcon: Tooltip(
                    message: 'Input Periode Kustom',
                    child: IconButton(
                      icon: const Icon(LucideIcons.calendarPlus, size: 15, color: AppColors.primaryLight),
                      splashRadius: 18,
                      onPressed: _showCustomPeriodDialog,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Semua Periode', overflow: TextOverflow.ellipsis)),
                  ...targetState.availablePeriods.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(masterTargetProvider.notifier).setPeriod(val);
                  }
                },
              );

              final distWidget = DropdownButtonFormField<int?>(
                initialValue: _filterDistributorId,
                dropdownColor: colors.bgElevated,
                isExpanded: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Filter Distributor',
                  labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  prefixIcon: const Icon(LucideIcons.building2, size: 16),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua Distributor', overflow: TextOverflow.ellipsis)),
                  ...masterState.distributors.map((d) => DropdownMenuItem<int?>(
                    value: d.id,
                    child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) => setState(() => _filterDistributorId = val),
              );

              final levelWidget = DropdownButtonFormField<String>(
                initialValue: _filterLevel,
                dropdownColor: colors.bgElevated,
                isExpanded: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Tingkat Target',
                  labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Semua Tingkat', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'DEPO', child: Text('Depo (ASM)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'AREA', child: Text('Area (SPV)', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filterLevel = val);
                },
              );

              final metricWidget = DropdownButtonFormField<String>(
                initialValue: _filterMetric,
                dropdownColor: colors.bgElevated,
                isExpanded: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Metrik Target',
                  labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Semua Metrik', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'SELL_OUT', child: Text('Sell-Out', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'SELL_IN', child: Text('Sell-In', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'AO', child: Text('Active Outlet (AO)', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filterMetric = val);
                },
              );

              final brandWidget = DropdownButtonFormField<int?>(
                initialValue: _filterBrandId,
                dropdownColor: colors.bgElevated,
                isExpanded: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Filter Brand',
                  labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua Brand', overflow: TextOverflow.ellipsis)),
                  ...masterState.brands.map((b) => DropdownMenuItem<int?>(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) => setState(() => _filterBrandId = val),
              );

              final searchWidget = TextField(
                controller: _searchController,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari Nama Distributor, Depo, Area, Brand, atau Sales Personil (Tekan Enter untuk cari)...',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: colors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                onSubmitted: (val) => ref.read(masterTargetProvider.notifier).fetchTargets(search: val.trim(), page: 1),
              );

              if (isCompact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 2, child: periodWidget),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: distWidget),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: levelWidget),
                        const SizedBox(width: 10),
                        Expanded(child: metricWidget),
                        const SizedBox(width: 10),
                        Expanded(child: brandWidget),
                      ],
                    ),
                    const SizedBox(height: 10),
                    searchWidget,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 2, child: periodWidget),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: distWidget),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: levelWidget),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: metricWidget),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: brandWidget),
                    ],
                  ),
                  const SizedBox(height: 10),
                  searchWidget,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Table
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(LucideIcons.inbox, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('Belum ada data target kuota distributor yang sesuai filter.', style: TextStyle(color: colors.textMuted)),
              ],
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 1080,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              columns: [
                DataColumn(label: Text('Tingkat', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Distributor', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Depo & Area Operasional', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Brand Produk', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Metrik Target', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Besaran Kuota Target', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Posisi & Sales Penanggung Jawab', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Periode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: filteredList.map((item) {
                final isArea = item.level == 'AREA';
                final isOutlet = item.targetType == 'AO' || item.targetType == 'NOO';

                // Resolve sales personil (from target or assignment)
                UserModel? assignedSales = item.user;
                String assignedPosition = '';
                if (assignedSales != null) {
                  assignedPosition = assignedSales.position?.code ?? (isArea ? 'SPV' : 'ASM');
                } else {
                  if (isArea && item.areaId != null) {
                    final assign = assignState.distributorAssignments.where((a) => a.areaId == item.areaId && a.isActive).firstOrNull;
                    assignedSales = assign?.user;
                    assignedPosition = 'SPV';
                  } else if (item.distributorId != null) {
                    final assign = assignState.distributorAssignments.where((a) => a.distributorId == item.distributorId && (a.user?.position?.code.toUpperCase() == 'ASM') && a.isActive).firstOrNull;
                    assignedSales = assign?.user;
                    assignedPosition = 'ASM';
                  }
                }

                return DataRow(
                  cells: [
                    // Tingkat Badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isArea
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isArea ? AppColors.warning.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isArea ? LucideIcons.mapPin : LucideIcons.building2, size: 12, color: isArea ? AppColors.warning : AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(
                              isArea ? 'AREA (SPV)' : 'DEPO (ASM)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isArea ? AppColors.warning : AppColors.primaryLight),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Distributor
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.distributor?.name ?? 'Distributor #${item.distributorId ?? '-'}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                          Text(item.distributor?.code ?? '-', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),

                    // Depo & Area
                    DataCell(
                      isArea
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.area?.name ?? 'Area #${item.areaId}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                                Text('Depo: ${item.depo?.name ?? '-'}', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item.depo?.name ?? 'Depo #${item.depoId}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                                Text('Seluruh Area Depo', style: TextStyle(color: colors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ),
                    ),

                    // Brand Produk
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.brand?.name ?? (item.brandId != null ? 'Brand #${item.brandId}' : 'Semua Brand'),
                          style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Metrik Target
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.targetType == 'SELL_OUT'
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                              : (item.targetType == 'SELL_IN' ? AppColors.info.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.targetType,
                          style: TextStyle(
                            color: item.targetType == 'SELL_OUT'
                                ? const Color(0xFF8B5CF6)
                                : (item.targetType == 'SELL_IN' ? AppColors.info : AppColors.success),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                    // Besaran Target Kuota
                    DataCell(
                      Text(
                        isOutlet
                            ? '${item.targetOutlet ?? item.targetQuota.toInt()} Toko'
                            : '${CurrencyFormatter.formatNumber(item.targetQuota)} Kg',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),

                    // Posisi & Sales Penanggung Jawab
                    DataCell(
                      assignedSales != null
                          ? Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isArea ? AppColors.warning.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    assignedSales.name.isNotEmpty ? assignedSales.name[0].toUpperCase() : 'S',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isArea ? AppColors.warning : AppColors.primaryLight),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(assignedSales.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                                    Text('[$assignedPosition] • @${assignedSales.username}', style: TextStyle(color: colors.textMuted, fontSize: 10.5)),
                                  ],
                                ),
                              ],
                            )
                          : Text('Belum di-assign', style: TextStyle(color: colors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                    ),

                    // Periode
                    DataCell(Text(item.period, style: TextStyle(color: colors.textMuted))),

                    // Aksi
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 15, color: AppColors.primaryLight),
                            tooltip: 'Edit Target',
                            onPressed: () => _showTargetFormDialog(targetToEdit: item),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                            tooltip: 'Hapus Target',
                            onPressed: () async {
                              final confirmed = await showConfirmDeleteDialog(
                                context: context,
                                title: 'Hapus Target Kuota',
                                message: 'Yakin ingin menghapus target ${item.targetType} untuk ${item.level == 'AREA' ? item.area?.name : item.depo?.name} (${item.brand?.name})?',
                              );
                              if (confirmed == true) {
                                await ref.read(masterTargetProvider.notifier).deleteTarget(item.id);
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
          if (targetState.totalItems > 0)
            _buildPaginationBar(targetState),
      ],
    );
  }

  // =========================================================================
  // TAB 1 & 2: TARGET INDUSTRI & SURABAYA
  // =========================================================================
  Widget _buildGenericTargetTable(String kategori) {
    final colors = context.colors;
    final targetState = ref.watch(masterTargetProvider);

    final list = targetState.targets.where((t) {
      if (t.kategoriSkema != kategori) return false;
      if (_searchQuery.isEmpty) return true;
      final name = t.user?.name.toLowerCase() ?? '';
      return name.contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Toolbar for Generic Tab (Periode & Search)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('period_gen_${targetState.selectedPeriod}'),
                  initialValue: targetState.availablePeriods.contains(targetState.selectedPeriod) || targetState.selectedPeriod == 'ALL'
                      ? targetState.selectedPeriod
                      : (targetState.availablePeriods.isNotEmpty ? targetState.availablePeriods.first : '202610'),
                  dropdownColor: colors.bgElevated,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Filter Periode',
                    labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                    prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('Semua Periode')),
                    ...targetState.availablePeriods.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    )),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(masterTargetProvider.notifier).setPeriod(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.calendarPlus, size: 18),
                tooltip: 'Input / Ganti Periode Kustom',
                color: AppColors.primaryLight,
                onPressed: _showCustomPeriodDialog,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari Nama Sales Personil atau Periode (Tekan Enter)...',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    isDense: true,
                    filled: true,
                    fillColor: colors.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  onSubmitted: (val) => ref.read(masterTargetProvider.notifier).fetchTargets(search: val.trim(), page: 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(LucideIcons.inbox, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('Belum ada data target untuk skema $kategori pada periode ${targetState.selectedPeriod}.', style: TextStyle(color: colors.textMuted)),
              ],
            ),
          )
        else ...[
          ResponsiveTableCard(
            minWidth: 850,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              columns: [
                DataColumn(label: Text('Sales Personil', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Periode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Metrik Target', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Besaran Target Kuota', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status Validasi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: list.map((item) {
                final isOutlet = item.targetType == 'AO' || item.targetType == 'NOO';

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            child: Text((item.user?.name.isNotEmpty == true ? item.user!.name[0] : 'S').toUpperCase(), style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              item.user?.name ?? 'Sales #${item.userId ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(item.period, style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text(item.targetType, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    DataCell(
                      Text(
                        isOutlet ? '${item.targetOutlet ?? item.targetQuota.toInt()} Toko' : '${CurrencyFormatter.formatNumber(item.targetQuota)} Kg',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Approved', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 15, color: AppColors.primaryLight),
                            tooltip: 'Edit Target',
                            onPressed: () => _showTargetFormDialog(targetToEdit: item),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                            tooltip: 'Hapus Target',
                            onPressed: () async {
                              final confirmed = await showConfirmDeleteDialog(
                                context: context,
                                title: 'Hapus Target Kuota',
                                message: 'Apakah Anda yakin ingin menghapus target ${item.targetType} untuk sales "${item.user?.name ?? '-'}" periode ${item.period}?',
                              );
                              if (confirmed == true) {
                                await ref.read(masterTargetProvider.notifier).deleteTarget(item.id);
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
          if (targetState.totalItems > 0)
            _buildPaginationBar(targetState),
        ],
      ],
    );
  }

  Widget _buildPaginationBar(MasterTargetState targetState) {
    final colors = context.colors;
    final notifier = ref.read(masterTargetProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Menampilkan ${targetState.fromItem} - ${targetState.toItem} dari ${targetState.totalItems} target',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(width: 14),
              Text('Baris/hal:', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: targetState.perPage,
                dropdownColor: colors.bgElevated,
                underline: const SizedBox(),
                isDense: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (val) {
                  if (val != null) notifier.setPerPage(val);
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                tooltip: 'Halaman Sebelumnya',
                onPressed: targetState.currentPage > 1
                    ? () => notifier.goToPage(targetState.currentPage - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Hal ${targetState.currentPage} dari ${targetState.lastPage > 0 ? targetState.lastPage : 1}',
                  style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                tooltip: 'Halaman Selanjutnya',
                onPressed: targetState.currentPage < targetState.lastPage
                    ? () => notifier.goToPage(targetState.currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
              Text(value, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

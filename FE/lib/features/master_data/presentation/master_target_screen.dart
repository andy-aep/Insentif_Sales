import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/models/master_model.dart';
import '../../../data/models/master_target_model.dart';
import '../../bulk_upload/providers/bulk_upload_provider.dart';
import '../../users_management/providers/user_management_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/master_target_provider.dart';
import '../providers/sales_assignment_provider.dart';
import 'widgets/target_distributor_hierarchy_view.dart';

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
  final GlobalKey<TargetDistributorHierarchyViewState> _hierarchyKey = GlobalKey<TargetDistributorHierarchyViewState>();

  // Filter state
  int? _filterDistributorId;
  String _filterMetric = 'ALL'; // 'ALL', 'SELL_IN', 'SELL_OUT', 'AO'
  int? _filterBrandId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      final mapped = _tabToInternal(_tabController.index);
      if (!_tabController.indexIsChanging && mapped != _activeTabIndex) {
        setState(() => _activeTabIndex = mapped);
        _fetchActiveTabTargets(force: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchActiveTabTargets(force: true);
      if (ref.read(masterDataProvider).distributors.isEmpty) {
        ref.read(masterDataProvider.notifier).fetchAllMasterData();
      }
      if (ref.read(userManagementProvider).users.isEmpty) {
        ref.read(userManagementProvider.notifier).fetchAll();
      }
      if (ref.read(salesAssignmentProvider).distributorAssignments.isEmpty) {
        ref.read(salesAssignmentProvider.notifier).fetchAllAssignments();
      }
    });
  }

  void _fetchActiveTabTargets({bool force = false, int page = 1}) {
    String? level;
    String? kategori;

    switch (_activeTabIndex) {
      case 0:
        level = 'DEPO';
        kategori = 'DISTRIBUTOR';
        break;
      case 1:
        level = 'AREA';
        kategori = 'DISTRIBUTOR';
        break;
      case 2:
        kategori = 'INDUSTRI';
        break;
      case 3:
        kategori = 'SURABAYA';
        break;
    }

    ref.read(masterTargetProvider.notifier).fetchTargets(
      force: force,
      page: page,
      level: level,
      clearLevel: level == null,
      kategori: kategori,
      clearKategori: kategori == null,
      distributorId: _filterDistributorId,
      clearDistributor: _filterDistributorId == null,
      brandId: _filterBrandId,
      clearBrand: _filterBrandId == null,
      metrikTarget: _filterMetric != 'ALL' ? _filterMetric : null,
      clearMetric: _filterMetric == 'ALL',
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      clearSearch: _searchQuery.isEmpty,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // DIALOG: Ganti Periode Kustom
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

  // =========================================================================
  // DIALOG: Tambah & Edit Master Target (Terpisah: Target Depo / Target Area / Industri / Surabaya)
  // =========================================================================
  void _showTargetFormDialog({MasterTargetModel? targetToEdit}) {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);
    final masterState = ref.read(masterDataProvider);
    final assignState = ref.read(salesAssignmentProvider);
    final targetState = ref.read(masterTargetProvider);
    final isEdit = targetToEdit != null;

    // Skema terpisah: 'TARGET_DEPO', 'TARGET_AREA', 'INDUSTRI', 'SURABAYA'
    String selectedScheme = 'TARGET_DEPO';
    int? selectedDistributorId;
    int? selectedDepoId;
    int? selectedAreaId;
    int? selectedBrandId;
    int? selectedUserId;
    String selectedTargetType = 'SELL_OUT';
    String defaultQuota = '5000';
    String defaultOutlet = '50';
    final activeFilterPeriod = targetState.selectedPeriod;
    String defaultPeriod = activeFilterPeriod != 'ALL' && activeFilterPeriod.isNotEmpty ? activeFilterPeriod : '202610';

    if (targetToEdit != null) {
      if (targetToEdit.kategoriSkema == 'KONSUMSI' || targetToEdit.kategoriSkema == 'DISTRIBUTOR') {
        selectedScheme = targetToEdit.level == 'AREA' ? 'TARGET_AREA' : 'TARGET_DEPO';
      } else {
        selectedScheme = targetToEdit.kategoriSkema;
      }
      selectedDistributorId = targetToEdit.distributorId;
      selectedBrandId = targetToEdit.brandId;
      selectedUserId = targetToEdit.userId;
      selectedTargetType = targetToEdit.targetType;
      defaultQuota = targetToEdit.targetQuota % 1 == 0 ? targetToEdit.targetQuota.toInt().toString() : targetToEdit.targetQuota.toString();
      defaultOutlet = targetToEdit.targetOutlet?.toString() ?? targetToEdit.targetQuota.toInt().toString();
      defaultPeriod = targetToEdit.period;
    } else {
      selectedScheme = switch (_activeTabIndex) {
        0 => 'TARGET_DEPO',
        1 => 'TARGET_AREA',
        2 => 'INDUSTRI',
        _ => 'SURABAYA',
      };
      selectedDistributorId = masterState.distributors.isNotEmpty ? masterState.distributors.first.id : null;
      selectedBrandId = masterState.brands.isNotEmpty ? masterState.brands.first.id : null;
      selectedUserId = userState.users.isNotEmpty ? userState.users.first.id : null;
      selectedTargetType = selectedScheme == 'INDUSTRI' ? 'SELL_IN' : 'SELL_OUT';
      defaultQuota = selectedScheme == 'TARGET_AREA' ? '1500' : '5000';
      defaultOutlet = selectedScheme == 'TARGET_AREA' ? '25' : '50';
    }

    DistributorModel? currentDist = selectedDistributorId != null
        ? masterState.distributors.where((d) => d.id == selectedDistributorId).firstOrNull
        : (masterState.distributors.isNotEmpty ? masterState.distributors.first : null);

    List<DepoModel> dialogDepos = masterState.depos.where((dp) => dp.distributorId == selectedDistributorId).toList();
    if (dialogDepos.isEmpty && currentDist != null && currentDist.depos.isNotEmpty) {
      dialogDepos = List<DepoModel>.from(currentDist.depos);
    }
    if (targetToEdit?.depo != null && !dialogDepos.any((d) => d.id == targetToEdit!.depo!.id)) {
      dialogDepos.insert(0, targetToEdit!.depo!);
    }

    if (targetToEdit != null && targetToEdit.depoId != null) {
      selectedDepoId = targetToEdit.depoId;
    } else {
      selectedDepoId = dialogDepos.isNotEmpty ? dialogDepos.first.id : null;
    }

    DepoModel? currentDepo = selectedDepoId != null
        ? dialogDepos.where((dp) => dp.id == selectedDepoId).firstOrNull
        : (dialogDepos.isNotEmpty ? dialogDepos.first : null);

    List<AreaModel> dialogAreas = masterState.areas.where((ar) => ar.depoId == selectedDepoId).toList();
    if (dialogAreas.isEmpty && currentDepo != null && currentDepo.areas.isNotEmpty) {
      dialogAreas = List<AreaModel>.from(currentDepo.areas);
    }
    if (targetToEdit?.area != null && !dialogAreas.any((a) => a.id == targetToEdit!.area!.id)) {
      dialogAreas.insert(0, targetToEdit!.area!);
    }

    if (targetToEdit != null && targetToEdit.areaId != null) {
      selectedAreaId = targetToEdit.areaId;
    } else {
      selectedAreaId = dialogAreas.isNotEmpty ? dialogAreas.first.id : null;
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
    bool isLoadingDepos = false;
    bool isLoadingAreas = false;
    bool didInitialFetch = false;

    Future<void> loadAreasForDepo(int? depoId, StateSetter setDialogState) async {
      if (depoId == null) {
        setDialogState(() {
          dialogAreas = [];
          selectedAreaId = null;
        });
        return;
      }
      setDialogState(() => isLoadingAreas = true);
      try {
        final res = await DioClient.instance.get(
          ApiEndpoints.areas,
          queryParameters: {'depo_id': depoId, 'limit': 500},
        );
        final List raw = res.data['data'] ?? (res.data is List ? res.data : []);
        final fetched = raw.map((e) => AreaModel.fromJson(e)).toList();
        setDialogState(() {
          dialogAreas = fetched;
          if (selectedAreaId == null || !dialogAreas.any((a) => a.id == selectedAreaId)) {
            selectedAreaId = dialogAreas.isNotEmpty ? dialogAreas.first.id : null;
          }
          isLoadingAreas = false;
        });
      } catch (_) {
        setDialogState(() => isLoadingAreas = false);
      }
    }

    Future<void> loadDeposForDistributor(int? distId, StateSetter setDialogState) async {
      if (distId == null) {
        setDialogState(() {
          dialogDepos = [];
          selectedDepoId = null;
          dialogAreas = [];
          selectedAreaId = null;
        });
        return;
      }
      setDialogState(() => isLoadingDepos = true);
      try {
        final res = await DioClient.instance.get(
          ApiEndpoints.depos,
          queryParameters: {'distributor_id': distId, 'limit': 500},
        );
        final List raw = res.data['data'] ?? (res.data is List ? res.data : []);
        final fetched = raw.map((e) => DepoModel.fromJson(e)).toList();
        int? nextDepoId = selectedDepoId;
        if (nextDepoId == null || !fetched.any((d) => d.id == nextDepoId)) {
          nextDepoId = fetched.isNotEmpty ? fetched.first.id : null;
        }
        setDialogState(() {
          dialogDepos = fetched;
          selectedDepoId = nextDepoId;
          currentDepo = fetched.where((d) => d.id == nextDepoId).firstOrNull;
          isLoadingDepos = false;
        });
        await loadAreasForDepo(nextDepoId, setDialogState);
      } catch (_) {
        setDialogState(() => isLoadingDepos = false);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (!didInitialFetch && selectedDistributorId != null) {
            didInitialFetch = true;
            Future.microtask(() => loadDeposForDistributor(selectedDistributorId, setDialogState));
          }

          final isTargetDepo = selectedScheme == 'TARGET_DEPO';
          final isTargetArea = selectedScheme == 'TARGET_AREA';
          final isDistributor = isTargetDepo || isTargetArea;
          final isOutletMetric = selectedTargetType == 'AO' || selectedTargetType == 'NOO';

          // Auto-detect sales personil
          UserModel? detectedSales;
          String detectedRoleText = '';
          if (isTargetDepo && selectedDistributorId != null) {
            final asmAssign = assignState.distributorAssignments
                .where((a) => a.distributorId == selectedDistributorId && (a.user?.position?.code.toUpperCase() == 'ASM') && a.isActive)
                .firstOrNull;
            detectedSales = asmAssign?.user;
            detectedRoleText = 'ASM Penanggung Jawab Depo';
          } else if (isTargetArea && selectedAreaId != null) {
            final spvAssign = assignState.distributorAssignments
                .where((a) => a.areaId == selectedAreaId && a.isActive)
                .firstOrNull;
            detectedSales = spvAssign?.user;
            detectedRoleText = 'SPV Penanggung Jawab Area';
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
                        isEdit
                            ? 'Ubah ${isTargetArea ? 'Target Area (SPV)' : (isTargetDepo ? 'Target Depo (ASM)' : 'Target Kuota')}'
                            : 'Input ${isTargetArea ? 'Target Area (SPV)' : (isTargetDepo ? 'Target Depo (ASM)' : 'Target Kuota')}',
                        style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        isTargetDepo
                            ? 'Setting kuota mandiri untuk tingkat Depo (ASM)'
                            : (isTargetArea
                                ? 'Setting kuota mandiri untuk tingkat Area (SPV)'
                                : 'Tetapkan kuota penjualan per personil sales'),
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
                    // 1. Pilih Jenis Target (Terpisah: Target Depo sendiri, Target Area sendiri)
                    Text('Jenis Target *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedScheme,
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
                        DropdownMenuItem(value: 'TARGET_DEPO', child: Text('Target Depo (ASM)')),
                        DropdownMenuItem(value: 'TARGET_AREA', child: Text('Target Area (SPV)')),
                        DropdownMenuItem(value: 'INDUSTRI', child: Text('Target Industri (B2B)')),
                        DropdownMenuItem(value: 'SURABAYA', child: Text('Target Sales Surabaya (TO / Canvasing)')),
                      ],
                      onChanged: isEdit
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedScheme = val;
                                  if (val == 'TARGET_DEPO') {
                                    selectedTargetType = 'SELL_OUT';
                                    quotaCtrl.text = '5000';
                                    outletCtrl.text = '50';
                                  } else if (val == 'TARGET_AREA') {
                                    selectedTargetType = 'SELL_OUT';
                                    quotaCtrl.text = '1500';
                                    outletCtrl.text = '25';
                                  } else if (val == 'INDUSTRI') {
                                    selectedTargetType = 'SELL_IN';
                                  } else if (val == 'SURABAYA') {
                                    selectedTargetType = 'SELL_OUT';
                                  }
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),

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
                            });
                            loadDeposForDistributor(val, setDialogState);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pilih Depo
                      Row(
                        children: [
                          Text(
                            isTargetArea ? 'Pilih Depo Induk *' : 'Pilih Depo *',
                            style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (isLoadingDepos) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        key: ValueKey('dialog_depo_${selectedDistributorId}_${selectedDepoId}_${dialogDepos.length}'),
                        initialValue: dialogDepos.any((d) => d.id == selectedDepoId) ? selectedDepoId : null,
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
                        items: dialogDepos.map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDepoId = val;
                              currentDepo = dialogDepos.where((d) => d.id == val).firstOrNull;
                            });
                            loadAreasForDepo(val, setDialogState);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Khusus Target Area: Pilih Area
                      if (isTargetArea) ...[
                        Row(
                          children: [
                            Text('Pilih Area (SPV) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                            if (isLoadingAreas) ...[
                              const SizedBox(width: 8),
                              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('dialog_area_${selectedDepoId}_${selectedAreaId}_${dialogAreas.length}'),
                          initialValue: dialogAreas.any((a) => a.id == selectedAreaId) ? selectedAreaId : null,
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
                          items: dialogAreas.map((a) {
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
                          prefixIcon: const Icon(LucideIcons.tag, size: 18, color: Color(0xFF24968B)),
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

                      // Info Sales Penanggung Jawab sesuai unit (ASM untuk Depo, SPV untuk Area)
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
                              isTargetDepo ? LucideIcons.crown : LucideIcons.userCheck,
                              size: 20,
                              color: isTargetDepo ? AppColors.primaryLight : AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detectedRoleText.isNotEmpty
                                        ? detectedRoleText
                                        : (isTargetDepo ? 'Posisi ASM (Area Sales Manager)' : 'Posisi SPV (Sales Supervisor)'),
                                    style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    detectedSales != null
                                        ? '${detectedSales.name} (@${detectedSales.username})'
                                        : '(Otomatis mengikuti assignment ${isTargetDepo ? 'ASM' : 'SPV'} aktif)',
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
                          : (selectedScheme == 'INDUSTRI'
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

                    // Besaran Angka Target (Murni 1 Field sesuai Jenis Target yang dipilih)
                    if (!isOutletMetric)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTargetDepo
                                ? 'Besaran Target Depo (Kg / Box) *'
                                : (isTargetArea ? 'Besaran Target Area (Kg / Box) *' : 'Besaran Kuota Volume (Kg / Box) *'),
                            style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
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
                          Text(
                            isTargetDepo
                                ? 'Target Jumlah Toko / Outlet Depo ($selectedTargetType) *'
                                : (isTargetArea
                                    ? 'Target Jumlah Toko / Outlet Area ($selectedTargetType) *'
                                    : 'Target Jumlah Toko / Outlet ($selectedTargetType) *'),
                            style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
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
                  if (isTargetArea && selectedAreaId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wajib memilih Area!'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  final targetLevel = isTargetDepo ? 'DEPO' : (isTargetArea ? 'AREA' : 'SALES');

                  final success = isEdit
                      ? await ref.read(masterTargetProvider.notifier).updateTarget(
                          id: targetToEdit.id,
                          userId: isDistributor ? (detectedSales?.id ?? targetToEdit.userId) : selectedUserId,
                          distributorId: isDistributor ? selectedDistributorId : null,
                          depoId: isDistributor ? selectedDepoId : null,
                          areaId: isTargetArea ? selectedAreaId : null,
                          brandId: isDistributor ? selectedBrandId : null,
                          level: targetLevel,
                          kategoriSkema: isDistributor ? 'KONSUMSI' : selectedScheme,
                          targetType: selectedTargetType,
                          period: period,
                          targetQuota: isOutletMetric ? (outletVal?.toDouble() ?? 0.0) : quotaVal,
                          targetOutlet: isOutletMetric ? outletVal : null,
                        )
                      : await ref.read(masterTargetProvider.notifier).saveTarget(
                          userId: isDistributor ? (detectedSales?.id) : selectedUserId,
                          distributorId: isDistributor ? selectedDistributorId : null,
                          depoId: isDistributor ? selectedDepoId : null,
                          areaId: isTargetArea ? selectedAreaId : null,
                          brandId: isDistributor ? selectedBrandId : null,
                          level: targetLevel,
                          kategoriSkema: isDistributor ? 'KONSUMSI' : selectedScheme,
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
    ref.listen<MasterTargetState>(masterTargetProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        _hierarchyKey.currentState?.reload();
      }
    });
    final summary = targetState.summary;
    final depoTargetsCount = summary?['depo_count'] ?? targetState.targets.where((t) => (t.kategoriSkema == 'KONSUMSI' || t.kategoriSkema == 'DISTRIBUTOR') && t.level == 'DEPO').length;
    final areaTargetsCount = summary?['area_count'] ?? targetState.targets.where((t) => (t.kategoriSkema == 'KONSUMSI' || t.kategoriSkema == 'DISTRIBUTOR') && t.level == 'AREA').length;
    final industriCount = summary?['industri_count'] ?? targetState.targets.where((t) => t.kategoriSkema == 'INDUSTRI').length;
    final surabayaCount = summary?['surabaya_count'] ?? targetState.targets.where((t) => t.kategoriSkema == 'SURABAYA').length;

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
                  Text(
                    'Target & Kuota Penjualan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Kelola target kuota hierarki Distributor (Depo & Area), Industri, serta Sales Surabaya.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: context.colors.textMuted),
                  ),
                ],
              );

              final exportButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textPrimary,
                  backgroundColor: context.colors.bgCard,
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(LucideIcons.download, size: 16),
                label: Text(
                  'Tarik Excel Template',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onPressed: () {
                  final activePeriod = ref.read(masterTargetProvider).selectedPeriod;
                  ref.read(bulkUploadProvider.notifier).downloadTemplate(
                    entity: 'master_target_distributor',
                    withData: true,
                    period: activePeriod,
                  );
                },
              );

              final actionButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(LucideIcons.plus, size: 17, color: Colors.white),
                label: Text(
                  switch (_activeTabIndex) {
                    0 => 'Tambah Target Distributor',
                    1 => 'Tambah Target Area',
                    2 => 'Tambah Target Industri',
                    _ => 'Tambah Target Surabaya',
                  },
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onPressed: _showAddTargetDialog,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        exportButton,
                        actionButton,
                      ],
                    ),
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
                      _fetchActiveTabTargets(force: true);
                      ref.read(masterDataProvider.notifier).fetchAllMasterData(force: true);
                      ref.read(salesAssignmentProvider.notifier).fetchAllAssignments(force: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  exportButton,
                  const SizedBox(width: 8),
                  actionButton,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Tab Card (4 Tab Terpisah: Target Depo, Target Area, Target Industri, Target Sales Surabaya)
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
                  onTap: (val) {
                    final mapped = _tabToInternal(val);
                    if (_activeTabIndex != mapped) {
                      setState(() => _activeTabIndex = mapped);
                      _fetchActiveTabTargets(force: true);
                    }
                  },
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primaryLight,
                  labelColor: context.colors.textPrimary,
                  unselectedLabelColor: context.colors.textMuted,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.network, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Distributor ($depoTargetsCount Depo · $areaTargetsCount Area)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.factory, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Industri ($industriCount)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.compass, size: 16),
                          const SizedBox(width: 8),
                          Text('Target Sales Surabaya ($surabayaCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

                if (targetState.isLoading && _activeTabIndex >= 2)
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

  /// Tab UI: 0 = Target Distributor (hirarki Depo+Area), 1 = Industri, 2 = Surabaya.
  /// Index internal: 0 = Distributor, 2 = Industri, 3 = Surabaya.
  int _tabToInternal(int tab) => switch (tab) { 0 => 0, 1 => 2, _ => 3 };

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
      case 1:
        return TargetDistributorHierarchyView(
          key: _hierarchyKey,
          period: ref.read(masterTargetProvider).selectedPeriod,
          onEdit: (t) => _showTargetFormDialog(targetToEdit: t),
          onDelete: (t) async {
            final confirmed = await showConfirmDeleteDialog(
              context: context,
              title: 'Hapus Target Kuota',
              message: 'Yakin hapus target ${t.targetType} ${t.level == 'AREA' ? (t.area?.name ?? '') : (t.depo?.name ?? '')} (${t.brand?.name ?? '-'})?',
            );
            if (confirmed == true) {
              await ref.read(masterTargetProvider.notifier).deleteTarget(t.id);
              _hierarchyKey.currentState?.reload();
            }
          },
        );
      case 2:
        return _buildGenericTargetTable('INDUSTRI');
      case 3:
      default:
        return _buildGenericTargetTable('SURABAYA');
    }
  }

  // =========================================================================
  // TAB 0 (TARGET DEPO) & TAB 1 (TARGET AREA) — MURNI TERPISAH SENDIRI-SENDIRI
  // =========================================================================
  // ignore: unused_element
  Widget _buildSeparateUnitTargetTab({required String level}) {
    final colors = context.colors;
    final targetState = ref.watch(masterTargetProvider);
    final masterState = ref.watch(masterDataProvider);
    final assignState = ref.watch(salesAssignmentProvider);
    final isAreaTab = level == 'AREA';

    final unitTargets = targetState.targets.where((t) => t.level == level).toList();

    final filteredList = unitTargets.where((t) {
      if (_filterDistributorId != null && t.distributorId != _filterDistributorId) return false;
      if (_filterMetric != 'ALL' && t.targetType != _filterMetric) return false;
      if (_filterBrandId != null && t.brandId != _filterBrandId) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final distName = (t.distributor?.name ?? '').toLowerCase();
        final depoName = (t.depo?.name ?? '').toLowerCase();
        final areaName = (t.area?.name ?? '').toLowerCase();
        final brandName = (t.brand?.name ?? '').toLowerCase();
        final userName = (t.user?.name ?? '').toLowerCase();
        return distName.contains(q) || depoName.contains(q) || (isAreaTab && areaName.contains(q)) || brandName.contains(q) || userName.contains(q);
      }
      return true;
    }).toList();

    final summary = targetState.summary;
    final bool hasLocalFilters = _filterDistributorId != null || _filterMetric != 'ALL' || _filterBrandId != null || _searchQuery.isNotEmpty;

    final double totalSellOut = !hasLocalFilters && summary != null && summary[isAreaTab ? 'area_sell_out' : 'depo_sell_out'] != null
        ? ((summary[isAreaTab ? 'area_sell_out' : 'depo_sell_out'] as num?)?.toDouble() ?? 0.0)
        : filteredList.where((t) => t.targetType == 'SELL_OUT').fold<double>(0.0, (sum, t) => sum + t.targetQuota);

    final double totalSellIn = !hasLocalFilters && summary != null && summary[isAreaTab ? 'area_sell_in' : 'depo_sell_in'] != null
        ? ((summary[isAreaTab ? 'area_sell_in' : 'depo_sell_in'] as num?)?.toDouble() ?? 0.0)
        : filteredList.where((t) => t.targetType == 'SELL_IN').fold<double>(0.0, (sum, t) => sum + t.targetQuota);

    final int totalAo = !hasLocalFilters && summary != null && summary[isAreaTab ? 'area_ao' : 'depo_ao'] != null
        ? ((summary[isAreaTab ? 'area_ao' : 'depo_ao'] as num?)?.toInt() ?? 0)
        : filteredList.where((t) => t.targetType == 'AO').fold<int>(0, (sum, t) => sum + (t.targetOutlet ?? t.targetQuota.toInt()));

    final int unitCount = !hasLocalFilters && summary != null && summary[isAreaTab ? 'area_count' : 'depo_count'] != null
        ? ((summary[isAreaTab ? 'area_count' : 'depo_count'] as num?)?.toInt() ?? 0)
        : filteredList.length;

    void applyServerFilter({
      int? distId,
      bool clearDist = false,
      String? metric,
      int? brandId,
      bool clearBrand = false,
    }) {
      final nextDist = clearDist ? null : (distId ?? _filterDistributorId);
      final nextMetric = metric ?? _filterMetric;
      final nextBrand = clearBrand ? null : (brandId ?? _filterBrandId);

      setState(() {
        _filterDistributorId = nextDist;
        _filterMetric = nextMetric;
        _filterBrandId = nextBrand;
      });

      _fetchActiveTabTargets(force: true, page: 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Banner khusus tab ini saja (Target Depo sendiri / Target Area sendiri)
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Target Area (SPV)' : 'Total Target Depo (ASM)',
              value: isAreaTab ? '$unitCount Baris Target Area' : '$unitCount Baris Target Depo',
              icon: isAreaTab ? LucideIcons.mapPin : LucideIcons.building2,
              color: isAreaTab ? AppColors.warning : AppColors.primary,
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Sell-Out Area' : 'Total Sell-Out Depo',
              value: '${CurrencyFormatter.formatNumber(totalSellOut)} Kg',
              icon: LucideIcons.trendingUp,
              color: const Color(0xFF24968B),
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Sell-In Area' : 'Total Sell-In Depo',
              value: '${CurrencyFormatter.formatNumber(totalSellIn)} Kg',
              icon: LucideIcons.truck,
              color: AppColors.info,
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Active Outlet (AO) Area' : 'Total Active Outlet (AO) Depo',
              value: '$totalAo Toko',
              icon: LucideIcons.store,
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1050;

              final periodWidget = DropdownButtonFormField<String>(
                key: ValueKey('period_${level}_${targetState.selectedPeriod}'),
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
                onChanged: (val) => applyServerFilter(distId: val, clearDist: val == null),
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
                  if (val != null) applyServerFilter(metric: val);
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
                onChanged: (val) => applyServerFilter(brandId: val, clearBrand: val == null),
              );

              final searchWidget = TextField(
                controller: _searchController,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: isAreaTab
                      ? 'Cari Nama Area, Depo, Distributor, Brand, atau SPV (Tekan Enter)...'
                      : 'Cari Nama Depo, Distributor, Brand, atau ASM (Tekan Enter)...',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: colors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                onSubmitted: (val) => ref.read(masterTargetProvider.notifier).fetchTargets(
                  distributorId: _filterDistributorId,
                  metrikTarget: _filterMetric,
                  brandId: _filterBrandId,
                  search: val.trim(),
                  page: 1,
                  force: true,
                ),
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

        // Table (Murni menampilkan Target Depo saja pada Tab Depo, atau Target Area saja pada Tab Area)
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(LucideIcons.inbox, size: 48, color: colors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  isAreaTab
                      ? 'Belum ada data Target Area (SPV) yang sesuai filter.'
                      : 'Belum ada data Target Depo (ASM) yang sesuai filter.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ],
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 1020,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              dataRowMinHeight: 58,
              dataRowMaxHeight: 74,
              columns: [
                DataColumn(label: Text('Distributor', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                if (!isAreaTab)
                  DataColumn(label: Text('Depo Cabang', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold)))
                else ...[
                  DataColumn(label: Text('Area Operasional', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Depo Induk', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                ],
                DataColumn(label: Text('Brand Produk', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Metrik Target', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(
                  label: Text(
                    isAreaTab ? 'Besaran Target Area' : 'Besaran Target Depo',
                    style: TextStyle(color: isAreaTab ? AppColors.warning : AppColors.primaryLight, fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    isAreaTab ? 'SPV Penanggung Jawab' : 'ASM Penanggung Jawab',
                    style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(label: Text('Periode', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: filteredList.map((item) {
                final isOutlet = item.targetType == 'AO' || item.targetType == 'NOO';

                // Resolve sales personil (from target or assignment)
                UserModel? assignedSales = item.user;
                String assignedPosition = '';
                if (assignedSales != null) {
                  assignedPosition = assignedSales.position?.code ?? (isAreaTab ? 'SPV' : 'ASM');
                } else {
                  if (isAreaTab && item.areaId != null) {
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

                    // Unit: Depo Cabang (untuk Tab Depo) atau Area Operasional + Depo Induk (untuk Tab Area)
                    if (!isAreaTab)
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.depo?.name ?? 'Depo #${item.depoId}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                            Text(item.depo?.code ?? '-', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                          ],
                        ),
                      )
                    else ...[
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.area?.name ?? 'Area #${item.areaId}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                            Text(item.area?.code ?? '-', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.depo?.name ?? 'Depo #${item.depoId}', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
                            Text(item.depo?.code ?? '-', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],

                    // Brand Produk
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24968B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF24968B).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.brand?.name ?? (item.brandId != null ? 'Brand #${item.brandId}' : 'Semua Brand'),
                          style: const TextStyle(color: Color(0xFF24968B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Metrik Target
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.targetType == 'SELL_OUT'
                              ? const Color(0xFF24968B).withValues(alpha: 0.15)
                              : (item.targetType == 'SELL_IN' ? AppColors.info.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.targetType,
                          style: TextStyle(
                            color: item.targetType == 'SELL_OUT'
                                ? const Color(0xFF24968B)
                                : (item.targetType == 'SELL_IN' ? AppColors.info : AppColors.success),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                    // Besaran Target (Murni Target Depo pada Tab Depo, atau Murni Target Area pada Tab Area)
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isOutlet
                                ? '${item.targetOutlet ?? item.targetQuota.toInt()} Toko'
                                : '${CurrencyFormatter.formatNumber(item.targetQuota)} Kg',
                            style: TextStyle(
                              color: isAreaTab ? AppColors.warning : AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          if (!isOutlet && item.targetOutlet != null && item.targetOutlet! > 0)
                            Text('AO: ${item.targetOutlet} Toko', style: TextStyle(color: colors.textMuted, fontSize: 10.5)),
                        ],
                      ),
                    ),

                    // Penanggung Jawab (ASM / SPV)
                    DataCell(
                      assignedSales != null
                          ? Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isAreaTab ? AppColors.warning.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    assignedSales.name.isNotEmpty ? assignedSales.name[0].toUpperCase() : 'S',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAreaTab ? AppColors.warning : AppColors.primaryLight),
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
                                message: 'Yakin ingin menghapus target ${item.targetType} untuk ${isAreaTab ? item.area?.name : item.depo?.name} (${item.brand?.name})?',
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
  // TAB 2 & 3: TARGET INDUSTRI & SURABAYA
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
              dataRowMinHeight: 54,
              dataRowMaxHeight: 70,
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

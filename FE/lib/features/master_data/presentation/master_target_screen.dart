import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
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
      if (!mounted) return;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
        title: Row(
          children: [
            Icon(LucideIcons.calendar, size: 20, color: Theme.of(context).colorScheme.primary),
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                ref.read(masterTargetProvider.notifier).setPeriod(text);
                Navigator.pop(ctx);
              }
            },
            child: Text('Terapkan', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showAddTargetDialog() => _showTargetFormDialog();

  // =========================================================================
  // DIALOG: Tambah (Terpadu Depo Sell-In + Area Sell-Out & AO) & Edit Master Target
  // =========================================================================
  void _showTargetFormDialog({
    MasterTargetModel? targetToEdit,
    int? initialDistributorId,
    int? initialDepoId,
    int? initialBrandId,
    String? initialPeriod,
    double? initialDepoSellIn,
    Map<int, double>? initialAreaSellOut,
    Map<int, int>? initialAreaAo,
  }) {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);
    final masterState = ref.read(masterDataProvider);
    final assignState = ref.read(salesAssignmentProvider);
    final targetState = ref.read(masterTargetProvider);
    final isEdit = targetToEdit != null;
    final isBundlePreFill = !isEdit && initialDistributorId != null;

    final sortedDistributors = List<DistributorModel>.from(masterState.distributors)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Mode Tambah: 'DISTRIBUTOR_TERPADU', 'INDUSTRI', 'SURABAYA'
    // Mode Edit:   'TARGET_DEPO', 'TARGET_AREA', 'INDUSTRI', 'SURABAYA'
    String selectedScheme = 'DISTRIBUTOR_TERPADU';
    int? selectedDistributorId;
    int? selectedDepoId;
    int? selectedAreaId;
    int? selectedBrandId;
    int? selectedUserId;
    String selectedTargetType = 'SELL_IN';
    String defaultQuota = '';
    String defaultOutlet = '';
    final activeFilterPeriod = targetState.selectedPeriod.trim();
    final firstActivePeriod = (activeFilterPeriod.isNotEmpty && activeFilterPeriod.toUpperCase() != 'ALL')
        ? activeFilterPeriod.split(',').first.trim()
        : '202610';
    String defaultPeriod = initialPeriod ?? (firstActivePeriod.isNotEmpty ? firstActivePeriod : '202610');

    String fmtNum(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

    if (targetToEdit != null) {
      if (targetToEdit.kategoriSkema == 'KONSUMSI' || targetToEdit.kategoriSkema == 'DISTRIBUTOR') {
        selectedScheme = targetToEdit.level == 'AREA' ? 'TARGET_AREA' : 'TARGET_DEPO';
      } else {
        selectedScheme = targetToEdit.kategoriSkema;
      }
      selectedDistributorId = targetToEdit.distributorId;
      selectedBrandId = targetToEdit.brandId;
      selectedUserId = targetToEdit.userId;
      selectedTargetType = selectedScheme == 'TARGET_DEPO'
          ? 'SELL_IN'
          : (selectedScheme == 'TARGET_AREA' ? 'SELL_OUT' : targetToEdit.targetType);
      defaultQuota = fmtNum(targetToEdit.targetQuota);
      defaultOutlet = targetToEdit.targetOutlet?.toString() ?? '';
      defaultPeriod = targetToEdit.period;
    } else {
      selectedScheme = isBundlePreFill
          ? 'DISTRIBUTOR_TERPADU'
          : switch (_activeTabIndex) {
              0 => 'DISTRIBUTOR_TERPADU',
              1 => 'DISTRIBUTOR_TERPADU',
              2 => 'INDUSTRI',
              _ => 'SURABAYA',
            };
      selectedDistributorId = initialDistributorId ?? (sortedDistributors.isNotEmpty ? sortedDistributors.first.id : null);
      selectedBrandId = initialBrandId ?? (masterState.brands.isNotEmpty ? masterState.brands.first.id : null);
      selectedUserId = userState.users.isNotEmpty ? userState.users.first.id : null;
      selectedTargetType = selectedScheme == 'INDUSTRI' ? 'SELL_IN' : 'SELL_OUT';
      defaultQuota = initialDepoSellIn != null
          ? fmtNum(initialDepoSellIn)
          : (selectedScheme == 'DISTRIBUTOR_TERPADU' ? '' : '5000');
      defaultOutlet = selectedScheme == 'DISTRIBUTOR_TERPADU' ? '' : '50';
    }

    DistributorModel? currentDist = selectedDistributorId != null
        ? sortedDistributors.where((d) => d.id == selectedDistributorId).firstOrNull
        : (sortedDistributors.isNotEmpty ? sortedDistributors.first : null);

    List<DepoModel> dialogDepos = masterState.depos.where((dp) => dp.distributorId == selectedDistributorId).toList();
    if (dialogDepos.isEmpty && currentDist != null && currentDist.depos.isNotEmpty) {
      dialogDepos = List<DepoModel>.from(currentDist.depos);
    }
    if (targetToEdit?.depo != null && !dialogDepos.any((d) => d.id == targetToEdit!.depo!.id)) {
      dialogDepos.insert(0, targetToEdit!.depo!);
    }

    if (targetToEdit != null && targetToEdit.depoId != null) {
      selectedDepoId = targetToEdit.depoId;
    } else if (initialDepoId != null) {
      selectedDepoId = initialDepoId;
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

    UserModel? detectAsmForDistributor(int? distId, int? depoId, String period) {
      if (distId == null && depoId == null) return null;
      if (depoId != null) {
        final depoAssigns = assignState.distributorAssignments
            .where((a) =>
                a.isActive &&
                a.user != null &&
                (a.user?.position?.code.toUpperCase() == 'ASM') &&
                a.depoId == depoId)
            .toList();
        if (depoAssigns.isNotEmpty) {
          final exact = depoAssigns.where((a) => a.period == period).firstOrNull;
          return (exact ?? depoAssigns.first).user;
        }
        final depoTargets = targetState.targets
            .where((t) => t.level == 'DEPO' && t.depoId == depoId && t.user != null)
            .toList();
        if (depoTargets.isNotEmpty) {
          final exact = depoTargets.where((t) => t.period == period).firstOrNull;
          return (exact ?? depoTargets.first).user;
        }
      }
      if (distId == null) return null;
      final candidates = assignState.distributorAssignments
          .where((a) =>
              a.distributorId == distId &&
              (a.user?.position?.code.toUpperCase() == 'ASM') &&
              a.isActive &&
              a.user != null)
          .toList();
      final exact = candidates.where((a) => a.period == period).firstOrNull;
      return (exact ?? candidates.firstOrNull)?.user;
    }

    UserModel? detectSpvForArea(int? areaId, String period) {
      if (areaId == null) return null;
      final candidates = assignState.distributorAssignments
          .where((a) => a.areaId == areaId && a.isActive && a.user != null)
          .toList();
      final exact = candidates.where((a) => a.period == period).firstOrNull;
      return (exact ?? candidates.firstOrNull)?.user;
    }

    if (isEdit && selectedUserId == null) {
      if (selectedScheme == 'TARGET_AREA') {
        selectedUserId = detectSpvForArea(selectedAreaId, defaultPeriod)?.id;
      } else if (selectedScheme == 'TARGET_DEPO') {
        selectedUserId = detectAsmForDistributor(selectedDistributorId, selectedDepoId, defaultPeriod)?.id;
      }
    }

    final quotaCtrl = TextEditingController(text: defaultQuota);
    final outletCtrl = TextEditingController(text: defaultOutlet);
    final periodCtrl = TextEditingController(text: defaultPeriod);
    final yearCtrl = TextEditingController(
      text: defaultPeriod.length >= 4 ? defaultPeriod.substring(0, 4) : DateTime.now().year.toString(),
    );
    final Map<int, TextEditingController> areaSellOutCtrls = {};
    final Map<int, TextEditingController> areaAoCtrls = {};

    void syncAreaControllers(List<AreaModel> areas) {
      for (final a in areas) {
        final initSo = initialAreaSellOut?[a.id];
        final initAo = initialAreaAo?[a.id];
        areaSellOutCtrls.putIfAbsent(
          a.id,
          () => TextEditingController(text: initSo != null && initSo > 0 ? fmtNum(initSo) : ''),
        );
        areaAoCtrls.putIfAbsent(
          a.id,
          () => TextEditingController(text: initAo != null && initAo > 0 ? initAo.toString() : ''),
        );
      }
    }

    syncAreaControllers(dialogAreas);

    bool isFullYearMode = false;
    bool isLoadingDepos = false;
    bool isLoadingAreas = false;
    bool isSubmitting = false;
    bool didInitialFetch = false;

    List<dynamic> extractList(dynamic data) {
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return const [];
    }

    Future<void> loadAreasForDepo(
      int? depoId,
      StateSetter setDialogState, {
      bool preserveSelection = false,
    }) async {
      if (depoId == null) {
        setDialogState(() {
          dialogAreas = [];
          selectedAreaId = null;
        });
        return;
      }
      final prevAreaId = preserveSelection ? selectedAreaId : null;
      setDialogState(() {
        isLoadingAreas = true;
        if (!preserveSelection) {
          dialogAreas = [];
          selectedAreaId = null;
        }
      });
      try {
        final res = await DioClient.instance.get(
          ApiEndpoints.areas,
          queryParameters: {'depo_id': depoId, 'limit': 500},
        );
        final List raw = extractList(res.data);
        final fetched = raw.map((e) => AreaModel.fromJson(e)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (preserveSelection &&
            targetToEdit?.area != null &&
            targetToEdit!.area!.depoId == depoId &&
            !fetched.any((a) => a.id == targetToEdit.area!.id)) {
          fetched.insert(0, targetToEdit.area!);
        }
        syncAreaControllers(fetched);
        int? nextAreaId = prevAreaId;
        if (nextAreaId == null || !fetched.any((a) => a.id == nextAreaId)) {
          nextAreaId = fetched.isNotEmpty ? fetched.first.id : null;
        }
        setDialogState(() {
          dialogAreas = fetched;
          selectedAreaId = nextAreaId;
          isLoadingAreas = false;
        });
      } catch (_) {
        setDialogState(() => isLoadingAreas = false);
      }
    }

    Future<void> loadDeposForDistributor(
      int? distId,
      StateSetter setDialogState, {
      bool preserveSelection = false,
    }) async {
      if (distId == null) {
        setDialogState(() {
          dialogDepos = [];
          selectedDepoId = null;
          dialogAreas = [];
          selectedAreaId = null;
        });
        return;
      }
      final prevDepoId = preserveSelection ? selectedDepoId : null;
      setDialogState(() {
        isLoadingDepos = true;
        if (!preserveSelection) {
          dialogDepos = [];
          selectedDepoId = null;
          currentDepo = null;
          dialogAreas = [];
          selectedAreaId = null;
        }
      });
      try {
        final res = await DioClient.instance.get(
          ApiEndpoints.depos,
          queryParameters: {'distributor_id': distId, 'limit': 500},
        );
        final List raw = extractList(res.data);
        final fetched = raw.map((e) => DepoModel.fromJson(e)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        int? nextDepoId = prevDepoId;
        if (nextDepoId == null || !fetched.any((d) => d.id == nextDepoId)) {
          nextDepoId = fetched.isNotEmpty ? fetched.first.id : null;
        }
        setDialogState(() {
          dialogDepos = fetched;
          selectedDepoId = nextDepoId;
          currentDepo = fetched.where((d) => d.id == nextDepoId).firstOrNull;
          isLoadingDepos = false;
        });
        await loadAreasForDepo(
          nextDepoId,
          setDialogState,
          preserveSelection: preserveSelection && nextDepoId == prevDepoId,
        );
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
            Future.microtask(() => loadDeposForDistributor(selectedDistributorId, setDialogState, preserveSelection: true));
          }

          final isDistributorBundle = !isEdit && selectedScheme == 'DISTRIBUTOR_TERPADU';
          final isTargetDepo = selectedScheme == 'TARGET_DEPO';
          final isTargetArea = selectedScheme == 'TARGET_AREA';
          final isDistributor = isDistributorBundle || isTargetDepo || isTargetArea;
          final isOutletMetric = !isDistributor && (selectedTargetType == 'AO' || selectedTargetType == 'NOO');

          final activeDialogPeriod = periodCtrl.text.trim().isNotEmpty ? periodCtrl.text.trim() : defaultPeriod;
          final detectedAsm = isDistributor ? detectAsmForDistributor(selectedDistributorId, selectedDepoId, activeDialogPeriod) : null;
          final detectedSpv = isTargetArea ? detectSpvForArea(selectedAreaId, activeDialogPeriod) : null;

          List<UserModel> buildPicOptions({required bool forDepo}) {
            final Map<int, UserModel> byId = {};
            final filtered = userState.users.where((u) {
              if (forDepo) {
                return u.position?.code.toUpperCase() == 'ASM' || u.isEligibleKonsumsi;
              }
              return u.isEligibleKonsumsi;
            });
            for (final u in (filtered.isNotEmpty ? filtered : userState.users)) {
              byId[u.id] = u;
            }
            if (targetToEdit?.user != null) {
              byId.putIfAbsent(targetToEdit!.user!.id, () => targetToEdit.user!);
            }
            if (forDepo && detectedAsm != null) {
              byId.putIfAbsent(detectedAsm.id, () => detectedAsm);
            }
            if (!forDepo && detectedSpv != null) {
              byId.putIfAbsent(detectedSpv.id, () => detectedSpv);
            }
            final list = byId.values.toList();
            list.sort((a, b) {
              int rank(UserModel u) {
                final pos = u.position?.code.toUpperCase() ?? '';
                if (forDepo) return pos == 'ASM' ? 0 : 1;
                return (pos == 'SPV' || pos == 'ASC') ? 0 : 1;
              }

              final r = rank(a).compareTo(rank(b));
              return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            return list;
          }

          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(isEdit ? LucideIcons.edit3 : LucideIcons.target, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit
                            ? 'Ubah ${isTargetArea ? 'Target Area (Sell-Out & AO)' : (isTargetDepo ? 'Target Depo (Sell-In)' : 'Target Kuota')}'
                            : (isDistributorBundle
                                ? 'Input Target Distributor Terpadu'
                                : 'Input Target ${selectedScheme == 'INDUSTRI' ? 'Industri (B2B)' : 'Sales Surabaya'}'),
                        style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        isDistributorBundle
                            ? 'Isi Target Sell-In Depo (ASM) dan Sell-Out + AO seluruh Area (SPV) sekaligus'
                            : (isTargetDepo
                                ? 'Target Sell-In (Kg) tingkat Depo untuk ASM'
                                : (isTargetArea
                                    ? 'Target Sell-Out (Kg) & Active Outlet (Toko) tingkat Area untuk SPV/ASC'
                                    : 'Tetapkan kuota penjualan per personil sales')),
                        style: GoogleFonts.plusJakartaSans(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isDistributorBundle ? 640 : 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Pilih Jenis Target
                    Text('Jenis Target *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedScheme,
                      dropdownColor: colors.bgElevated,
                      isExpanded: true,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: colors.bgElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: isEdit
                          ? const [
                              DropdownMenuItem(value: 'TARGET_DEPO', child: Text('Target Depo — Sell-In (ASM)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'TARGET_AREA', child: Text('Target Area — Sell-Out & AO (SPV/ASC)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'INDUSTRI', child: Text('Target Industri (B2B)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'SURABAYA', child: Text('Target Sales Surabaya (TO / Canvasing)', overflow: TextOverflow.ellipsis)),
                            ]
                          : const [
                              DropdownMenuItem(
                                value: 'DISTRIBUTOR_TERPADU',
                                child: Text('Target Distributor (Depo Sell-In + Area Sell-Out & AO)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(value: 'INDUSTRI', child: Text('Target Industri (B2B)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'SURABAYA', child: Text('Target Sales Surabaya (TO / Canvasing)', overflow: TextOverflow.ellipsis)),
                            ],
                      onChanged: isEdit
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedScheme = val;
                                  if (val == 'DISTRIBUTOR_TERPADU') {
                                    selectedTargetType = 'SELL_IN';
                                    quotaCtrl.text = '';
                                  } else if (val == 'INDUSTRI') {
                                    selectedTargetType = 'SELL_IN';
                                    quotaCtrl.text = '5000';
                                  } else if (val == 'SURABAYA') {
                                    selectedTargetType = 'SELL_OUT';
                                    quotaCtrl.text = '5000';
                                    outletCtrl.text = '50';
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
                        key: ValueKey('dialog_dist_$selectedDistributorId'),
                        initialValue: sortedDistributors.any((d) => d.id == selectedDistributorId) ? selectedDistributorId : null,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.building2, size: 17),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        ),
                        items: sortedDistributors.map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: isEdit
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedDistributorId = val;
                                    currentDist = sortedDistributors.where((d) => d.id == val).firstOrNull;
                                  });
                                  loadDeposForDistributor(val, setDialogState);
                                }
                              },
                      ),
                      const SizedBox(height: 12),

                      // Depo + Brand berdampingan
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Pilih Depo *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                    if (isLoadingDepos) ...[
                                      const SizedBox(width: 6),
                                      const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  key: ValueKey('dialog_depo_${selectedDistributorId}_${selectedDepoId}_${dialogDepos.length}'),
                                  initialValue: dialogDepos.any((d) => d.id == selectedDepoId) ? selectedDepoId : null,
                                  dropdownColor: colors.bgElevated,
                                  isExpanded: true,
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(LucideIcons.home, size: 16),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: colors.bgElevated,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  ),
                                  items: dialogDepos.map((d) {
                                    return DropdownMenuItem<int>(
                                      value: d.id,
                                      child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: isEdit
                                      ? null
                                      : (val) {
                                          if (val != null) {
                                            setDialogState(() {
                                              selectedDepoId = val;
                                              currentDepo = dialogDepos.where((d) => d.id == val).firstOrNull;
                                            });
                                            loadAreasForDepo(val, setDialogState);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pilih Brand Produk *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  key: ValueKey('dialog_brand_$selectedBrandId'),
                                  initialValue: masterState.brands.any((b) => b.id == selectedBrandId) ? selectedBrandId : null,
                                  dropdownColor: colors.bgElevated,
                                  isExpanded: true,
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(LucideIcons.tag, size: 16, color: context.semantic.success),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: colors.bgElevated,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ========================================================
                      // MODE TAMBAH TERPADU: Depo (Sell-In) + Semua Area (Sell-Out & AO)
                      // ========================================================
                      if (isDistributorBundle) ...[
                        // Bagian 1: Target Depo (Sell-In)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.bgElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.crown, size: 16, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '1. Target Depo — Sell-In (ASM)',
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      detectedAsm != null ? 'ASM: ${detectedAsm.name}' : 'ASM: Otomatis',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: quotaCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                                decoration: InputDecoration(
                                  labelText: 'Target Sell-In Depo (Kg)',
                                  hintText: 'Contoh: 135000 (kosongkan jika hanya input Area)',
                                  prefixIcon: const Icon(LucideIcons.truck, size: 17),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  suffixText: 'Kg',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: colors.bgCard,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bagian 2: Daftar Target Area (Sell-Out & AO sekaligus)
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
                                  Icon(LucideIcons.mapPin, size: 16, color: context.semantic.warning),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '2. Target Area — Sell-Out (Kg) & AO (Toko)',
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  if (isLoadingAreas)
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.semantic.warning.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${dialogAreas.length} Area',
                                        style: TextStyle(color: context.semantic.warning, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (dialogAreas.isEmpty && !isLoadingAreas)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Belum ada Area terdaftar pada Depo ini. Anda tetap dapat menyimpan Target Sell-In Depo di atas.',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                )
                                else
                                  ...dialogAreas.map((area) {
                                    final spv = detectSpvForArea(area.id, activeDialogPeriod);
                                    final soCtrl = areaSellOutCtrls.putIfAbsent(area.id, () => TextEditingController());
                                  final aoCtrl = areaAoCtrls.putIfAbsent(area.id, () => TextEditingController());
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.bgCard,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.border),
                                    ),
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
                                              Text(
                                                '${area.code}${spv != null ? ' • SPV: ${spv.name}' : ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: colors.textMuted, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 4,
                                          child: TextField(
                                            controller: soCtrl,
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                            decoration: InputDecoration(
                                              labelText: 'Sell-Out (Kg)',
                                              hintText: '0',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: colors.bgInput,
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: aoCtrl,
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                                            decoration: InputDecoration(
                                              labelText: 'AO (Toko)',
                                              hintText: '0',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: colors.bgInput,
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (isTargetDepo) ...[
                        // MODE EDIT DEPO: Langsung input Target Sell-In (Kg) tanpa dropdown metrik
                        Text('ASM Penanggung Jawab', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            final picOptions = buildPicOptions(forDepo: true);
                            return DropdownButtonFormField<int?>(
                              key: ValueKey('dialog_depo_pic_${selectedDistributorId}_${selectedUserId}_${picOptions.length}'),
                              initialValue: selectedUserId != null && picOptions.any((u) => u.id == selectedUserId) ? selectedUserId : null,
                              dropdownColor: colors.bgElevated,
                              isExpanded: true,
                              style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                              decoration: InputDecoration(
                                prefixIcon: Icon(LucideIcons.crown, size: 17, color: Theme.of(context).colorScheme.primary),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: colors.bgElevated,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Otomatis mengikuti assignment aktif', overflow: TextOverflow.ellipsis),
                                ),
                                ...picOptions.map((u) => DropdownMenuItem<int?>(
                                      value: u.id,
                                      child: Text(
                                        '${u.name} (@${u.username})${u.position != null ? ' • ${u.position!.code}' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedUserId = val),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('Target Sell-In Depo (Kg) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: quotaCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.truck, size: 18),
                            suffixText: 'Kg',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (isTargetArea) ...[
                        // MODE EDIT AREA: Pilih Area + langsung 2 input Sell-Out (Kg) & AO (Toko)
                        Text('Area (SPV / ASC) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('dialog_area_${selectedDepoId}_${selectedAreaId}_${dialogAreas.length}'),
                          initialValue: dialogAreas.any((a) => a.id == selectedAreaId) ? selectedAreaId : null,
                          dropdownColor: colors.bgElevated,
                          isExpanded: true,
                          style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                          decoration: InputDecoration(
                            prefixIcon: Icon(LucideIcons.mapPin, size: 17, color: context.semantic.warning),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          ),
                          items: dialogAreas.map((a) {
                            return DropdownMenuItem<int>(
                              value: a.id,
                              child: Text('${a.name} (${a.code})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: isEdit ? null : (val) {
                            if (val != null) setDialogState(() => selectedAreaId = val);
                          },
                        ),
                        const SizedBox(height: 10),
                        Text('SPV / ASC Area', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            final areaPicOptions = buildPicOptions(forDepo: false);
                            return DropdownButtonFormField<int?>(
                              key: ValueKey('dialog_area_pic_${selectedAreaId}_${selectedUserId}_${areaPicOptions.length}'),
                              initialValue: selectedUserId != null && areaPicOptions.any((u) => u.id == selectedUserId) ? selectedUserId : null,
                              dropdownColor: colors.bgElevated,
                              isExpanded: true,
                              style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                              decoration: InputDecoration(
                                prefixIcon: Icon(LucideIcons.userCheck, size: 17, color: context.semantic.warning),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: colors.bgElevated,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Otomatis mengikuti assignment aktif', overflow: TextOverflow.ellipsis),
                                ),
                                ...areaPicOptions.map((u) => DropdownMenuItem<int?>(
                                      value: u.id,
                                      child: Text(
                                        '${u.name} (@${u.username})${u.position != null ? ' • ${u.position!.code}' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: (val) => setDialogState(() => selectedUserId = val),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Target Sell-Out Area (Kg) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: quotaCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(LucideIcons.scale, size: 17),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      suffixText: 'Kg',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: colors.bgElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Target AO (Toko) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: outletCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(LucideIcons.store, size: 17),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      suffixText: 'Toko',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: colors.bgElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ] else ...[
                      // Non-distributor (Industri / Surabaya): pilih sales & metrik
                      Text('Pilih Sales Personil *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: userState.users.any((u) => u.id == selectedUserId) ? selectedUserId : null,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.user, size: 18),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

                      Text('Pilih Metrik Target *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTargetType,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: selectedScheme == 'INDUSTRI'
                            ? const [
                                DropdownMenuItem(value: 'SELL_IN', child: Text('Sell-In (Kg / Tonase)')),
                                DropdownMenuItem(value: 'NOO', child: Text('New Open Outlet (NOO)')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'SELL_OUT', child: Text('Sell-Out (Kg / Box)')),
                                DropdownMenuItem(value: 'AO', child: Text('Active Outlet (AO Toko)')),
                              ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedTargetType = val);
                        },
                      ),
                      const SizedBox(height: 14),

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
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: colors.bgElevated,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                    ],

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
                                  color: !isFullYearMode ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isFullYearMode ? Theme.of(context).colorScheme.primary : colors.border,
                                    width: !isFullYearMode ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.calendar, size: 14, color: !isFullYearMode ? Theme.of(context).colorScheme.primary : colors.textMuted),
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
                                  color: isFullYearMode ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFullYearMode ? Theme.of(context).colorScheme.primary : colors.border,
                                    width: isFullYearMode ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.calendarRange, size: 14, color: isFullYearMode ? Theme.of(context).colorScheme.primary : colors.textMuted),
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
                            decoration: BoxDecoration(color: context.semantic.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('Otomatis 12 Bulan (Jan - Des)', style: TextStyle(color: context.semantic.info, fontSize: 10.5, fontWeight: FontWeight.bold)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 202610',
                          prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: colors.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isSubmitting
                    ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : Icon(isEdit ? LucideIcons.check : LucideIcons.save, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                label: Text(
                  isSubmitting
                      ? 'Menyimpan...'
                      : (isEdit
                          ? 'Simpan Perubahan'
                          : (isFullYearMode ? 'Simpan Target 1 Tahun (12 Bulan)' : 'Simpan Target')),
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final period = periodCtrl.text.trim().isEmpty ? '202610' : periodCtrl.text.trim();
                        final year = yearCtrl.text.trim().isEmpty ? '2026' : yearCtrl.text.trim();
                        final quotaVal = double.tryParse(quotaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                        final outletVal = int.tryParse(outletCtrl.text.trim());

                        if (isDistributor && selectedDistributorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Wajib memilih Distributor!'), backgroundColor: context.semantic.dangerSolid),
                          );
                          return;
                        }
                        if (isDistributor && selectedDepoId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Wajib memilih Depo!'), backgroundColor: context.semantic.dangerSolid),
                          );
                          return;
                        }
                        if (isDistributor && selectedBrandId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Wajib memilih Brand!'), backgroundColor: context.semantic.dangerSolid),
                          );
                          return;
                        }
                        if (isTargetArea && selectedAreaId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Wajib memilih Area!'), backgroundColor: context.semantic.dangerSolid),
                          );
                          return;
                        }

                        if (isDistributorBundle) {
                          final areaPayloadList = <Map<String, dynamic>>[];
                          for (final area in dialogAreas) {
                            final so = double.tryParse((areaSellOutCtrls[area.id]?.text ?? '').trim().replaceAll(',', '.')) ?? 0.0;
                            final ao = int.tryParse((areaAoCtrls[area.id]?.text ?? '').trim()) ?? 0;
                            if (so > 0 || ao > 0) {
                              areaPayloadList.add({
                                'area_id': area.id,
                                'user_id': isFullYearMode ? null : detectSpvForArea(area.id, period)?.id,
                                'sell_out': so,
                                'ao': ao,
                              });
                            }
                          }
                          if (quotaVal <= 0 && areaPayloadList.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Isi minimal 1 nilai Target Sell-In Depo atau Target Area (Sell-Out / AO)!'),
                                backgroundColor: context.semantic.dangerSolid,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final success = await ref.read(masterTargetProvider.notifier).saveDistributorBundle(
                                distributorId: selectedDistributorId!,
                                depoId: selectedDepoId!,
                                brandId: selectedBrandId!,
                                period: period,
                                isFullYear: isFullYearMode,
                                year: year,
                                asmUserId: isFullYearMode ? null : detectedAsm?.id,
                                depoSellInQuota: quotaVal > 0 ? quotaVal : null,
                                areaTargets: areaPayloadList,
                              );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            _hierarchyKey.currentState?.reload();
                            final msg = ref.read(masterTargetProvider).successMessage ??
                                ref.read(masterTargetProvider).errorMessage ??
                                (success ? 'Target berhasil disimpan!' : 'Gagal menyimpan target');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: success ? context.semantic.success : context.semantic.danger,
                              ),
                            );
                          }
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        final targetLevel = isTargetDepo ? 'DEPO' : (isTargetArea ? 'AREA' : 'SALES');
                        final effectiveTargetType = isTargetDepo
                            ? 'SELL_IN'
                            : (isTargetArea ? 'SELL_OUT' : selectedTargetType);
                        final effectiveQuota = isOutletMetric ? (outletVal?.toDouble() ?? 0.0) : quotaVal;
                        final effectiveOutlet = isTargetArea
                            ? (outletVal ?? 0)
                            : (isOutletMetric ? outletVal : null);

                        final success = isEdit
                            ? await ref.read(masterTargetProvider.notifier).updateTarget(
                                  id: targetToEdit.id,
                                  userId: isTargetDepo
                                      ? (selectedUserId ?? detectedAsm?.id)
                                      : (isTargetArea ? (selectedUserId ?? detectedSpv?.id) : selectedUserId),
                                  distributorId: isDistributor ? selectedDistributorId : null,
                                  depoId: isDistributor ? selectedDepoId : null,
                                  areaId: isTargetArea ? selectedAreaId : null,
                                  brandId: isDistributor ? selectedBrandId : null,
                                  level: targetLevel,
                                  kategoriSkema: isDistributor ? 'KONSUMSI' : selectedScheme,
                                  targetType: effectiveTargetType,
                                  period: period,
                                  targetQuota: effectiveQuota,
                                  targetOutlet: effectiveOutlet,
                                )
                            : await ref.read(masterTargetProvider.notifier).saveTarget(
                                  userId: selectedUserId,
                                  level: targetLevel,
                                  kategoriSkema: selectedScheme,
                                  targetType: effectiveTargetType,
                                  period: period,
                                  isFullYear: isFullYearMode,
                                  year: year,
                                  targetQuota: effectiveQuota,
                                  targetOutlet: effectiveOutlet,
                                );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (mounted) {
                          _hierarchyKey.currentState?.reload();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? (isEdit ? 'Target kuota berhasil diperbarui!' : 'Target kuota berhasil disimpan!')
                                  : 'Gagal memproses target kuota'),
                              backgroundColor: success ? context.semantic.success : context.semantic.danger,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(LucideIcons.download, size: 16),
                label: Text(
                  'Tarik Excel Template',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onPressed: () {
                  final activePeriod = ref.read(masterTargetProvider).selectedPeriod;
                  final entity = switch (_activeTabIndex) {
                    2 => 'master_target_industri',
                    3 => 'master_target_surabaya',
                    _ => 'master_target_distributor',
                  };
                  final isDistTab = _activeTabIndex <= 1;
                  ref.read(bulkUploadProvider.notifier).downloadTemplate(
                    entity: entity,
                    withData: true,
                    period: activePeriod,
                    distributorId: isDistTab ? _hierarchyKey.currentState?.activeDistributorId : null,
                    depoId: isDistTab ? _hierarchyKey.currentState?.activeDepoId : null,
                    brandId: isDistTab ? _hierarchyKey.currentState?.activeBrandId : null,
                  );
                },
              );

              final actionButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(LucideIcons.plus, size: 17, color: Theme.of(context).colorScheme.onPrimary),
                label: Text(
                  switch (_activeTabIndex) {
                    0 => 'Tambah Target Distributor',
                    1 => 'Tambah Target Area',
                    2 => 'Tambah Target Industri',
                    _ => 'Tambah Target Surabaya',
                  },
                  style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
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
              borderRadius: BorderRadius.circular(12),
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
                  indicatorColor: Theme.of(context).colorScheme.primary,
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
          onEditDepoBundle: ({
            required distributorId,
            required depoId,
            brandId,
            period,
            initialDepoSellIn,
            initialAreaSellOut,
            initialAreaAo,
          }) =>
              _showTargetFormDialog(
                initialDistributorId: distributorId,
                initialDepoId: depoId,
                initialBrandId: brandId,
                initialPeriod: period,
                initialDepoSellIn: initialDepoSellIn,
                initialAreaSellOut: initialAreaSellOut,
                initialAreaAo: initialAreaAo,
              ),
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
              color: isAreaTab ? context.semantic.warning : Theme.of(context).colorScheme.primary,
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Sell-Out Area' : 'Total Sell-Out Depo',
              value: '${CurrencyFormatter.formatNumber(totalSellOut)} Kg',
              icon: LucideIcons.trendingUp,
              color: context.semantic.success,
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Sell-In Area' : 'Total Sell-In Depo',
              value: '${CurrencyFormatter.formatNumber(totalSellIn)} Kg',
              icon: LucideIcons.truck,
              color: context.semantic.info,
            ),
            _buildMiniKpiCard(
              title: isAreaTab ? 'Total Active Outlet (AO) Area' : 'Total Active Outlet (AO) Depo',
              value: '$totalAo Toko',
              icon: LucideIcons.store,
              color: context.semantic.success,
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
                      icon: Icon(LucideIcons.calendarPlus, size: 15, color: Theme.of(context).colorScheme.primary),
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
                    style: TextStyle(color: isAreaTab ? context.semantic.warning : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
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
                          color: context.semantic.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.semantic.success.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.brand?.name ?? (item.brandId != null ? 'Brand #${item.brandId}' : 'Semua Brand'),
                          style: TextStyle(color: context.semantic.success, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Metrik Target
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.targetType == 'SELL_OUT'
                              ? context.semantic.success.withValues(alpha: 0.15)
                              : (item.targetType == 'SELL_IN' ? context.semantic.info.withValues(alpha: 0.15) : context.semantic.success.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.targetType,
                          style: TextStyle(
                            color: item.targetType == 'SELL_OUT'
                                ? context.semantic.success
                                : (item.targetType == 'SELL_IN' ? context.semantic.info : context.semantic.success),
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
                              color: isAreaTab ? context.semantic.warning : Theme.of(context).colorScheme.primary,
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
                                  backgroundColor: isAreaTab ? context.semantic.warning.withValues(alpha: 0.2) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    assignedSales.name.isNotEmpty ? assignedSales.name[0].toUpperCase() : 'S',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAreaTab ? context.semantic.warning : Theme.of(context).colorScheme.primary),
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
                            icon: Icon(LucideIcons.pencil, size: 15, color: Theme.of(context).colorScheme.primary),
                            tooltip: 'Edit Target',
                            onPressed: () => _showTargetFormDialog(targetToEdit: item),
                          ),
                          IconButton(
                            icon: Icon(LucideIcons.trash2, size: 15, color: context.semantic.danger),
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
                width: 240,
                child: Builder(
                  builder: (context) {
                    final sel = targetState.selectedPeriod.trim();
                    final isMultiOrCustom = sel.isNotEmpty && sel != 'ALL' && !targetState.availablePeriods.contains(sel);
                    return DropdownButtonFormField<String>(
                      key: ValueKey('period_gen_$sel'),
                      initialValue: sel.isEmpty ? 'ALL' : sel,
                      isExpanded: true,
                      dropdownColor: colors.bgElevated,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Filter Periode',
                        labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                        prefixIcon: const Icon(LucideIcons.calendar, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('Semua Periode', overflow: TextOverflow.ellipsis)),
                        if (isMultiOrCustom)
                          DropdownMenuItem(value: sel, child: Text('Periode: $sel', overflow: TextOverflow.ellipsis)),
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
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.calendarPlus, size: 18),
                tooltip: 'Input / Ganti Periode Kustom',
                color: Theme.of(context).colorScheme.primary,
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
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            child: Text((item.user?.name.isNotEmpty == true ? item.user!.name[0] : 'S').toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    DataCell(Text(item.period, style: TextStyle(color: context.semantic.warning, fontWeight: FontWeight.bold))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text(item.targetType, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
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
                        decoration: BoxDecoration(color: context.semantic.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text('Approved', style: TextStyle(color: context.semantic.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(LucideIcons.pencil, size: 15, color: Theme.of(context).colorScheme.primary),
                            tooltip: 'Edit Target',
                            onPressed: () => _showTargetFormDialog(targetToEdit: item),
                          ),
                          IconButton(
                            icon: Icon(LucideIcons.trash2, size: 15, color: context.semantic.danger),
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
        borderRadius: BorderRadius.circular(8),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: colors.textFaint, size: 13),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.tabularNumStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

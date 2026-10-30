import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/models/master_model.dart';
import '../../users_management/providers/user_management_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/sales_assignment_provider.dart';

class MasterSurabayaScreen extends ConsumerStatefulWidget {
  const MasterSurabayaScreen({super.key});

  @override
  ConsumerState<MasterSurabayaScreen> createState() => _MasterSurabayaScreenState();
}

class _MasterSurabayaScreenState extends ConsumerState<MasterSurabayaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Filter & Search state for Distributor tab
  final _searchDistributorCtrl = TextEditingController();
  String _searchDistributorQuery = '';
  String _filterPosition = 'ALL'; // 'ALL', 'NSM', 'LSM', 'ASM', 'SPV'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });

    // Make sure data is fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesAssignmentProvider.notifier).fetchAllAssignments();
      ref.read(masterDataProvider.notifier).fetchAllMasterData();
      ref.read(userManagementProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDistributorCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // DIALOG 1: Assign Distributor & Area (Konsumsi: ASM & SPV)
  // =========================================================================
  void _showAssignDistributorDialog() {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);
    final masterState = ref.read(masterDataProvider);

    // Sales yang eligible insentif konsumsi (prioritas isEligibleKonsumsi == true atau berposisi NSM/LSM/ASM/SPV)
    final eligibleSales = userState.users.where((u) {
      final pCode = u.position?.code.toUpperCase() ?? '';
      return u.isEligibleKonsumsi || ['NSM', 'LSM', 'ASM', 'SPV'].contains(pCode);
    }).toList();
    final allSalesList = eligibleSales.isNotEmpty ? eligibleSales : userState.users;

    if (allSalesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada data user sales yang tersedia. Tambahkan user terlebih dahulu di menu Users.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Filter daftar atasan berjenjang
    final nsmUsers = userState.users.where((u) => u.position?.code.toUpperCase() == 'NSM').toList();
    final lsmUsers = userState.users.where((u) => u.position?.code.toUpperCase() == 'LSM').toList();
    final asmUsers = userState.users.where((u) => u.position?.code.toUpperCase() == 'ASM').toList();

    // Default form states
    UserModel selectedUser = allSalesList.first;
    UserModel? selectedNsm = nsmUsers.isNotEmpty ? nsmUsers.first : null;
    UserModel? selectedLsm = lsmUsers.isNotEmpty ? lsmUsers.first : null;
    UserModel? selectedAsm = asmUsers.isNotEmpty ? asmUsers.first : null;

    RegionModel? selectedRegion = masterState.regions.isNotEmpty ? masterState.regions.first : null;
    DistributorModel? selectedDistributor = masterState.distributors.isNotEmpty ? masterState.distributors.first : null;

    // Depo & Area selection
    DepoModel? selectedDepo = (selectedDistributor != null && selectedDistributor.depos.isNotEmpty) ? selectedDistributor.depos.first : null;
    AreaModel? selectedArea = (selectedDepo != null && selectedDepo.areas.isNotEmpty) ? selectedDepo.areas.first : null;

    final periodCtrl = TextEditingController(text: '202610');
    final notesCtrl = TextEditingController();

    final assignmentState = ref.read(salesAssignmentProvider);

    // NSM territory customization state
    String nsmScope = 'SPECIFIC';
    final territoryLabelCtrl = TextEditingController(text: 'Indonesia Timur');
    final Set<int> selectedSubordinateLsmIds = {};

    void syncNsmState(int userId) {
      final existingNsm = assignmentState.distributorAssignments.firstWhereOrNull((a) => a.userId == userId);
      if (existingNsm != null) {
        if (existingNsm.notes != null && existingNsm.notes!.isNotEmpty && existingNsm.notes != 'Nasional Penuh') {
          nsmScope = 'SPECIFIC';
          territoryLabelCtrl.text = existingNsm.notes!;
        } else {
          nsmScope = 'ALL';
        }
        selectedSubordinateLsmIds.clear();
        for (final sub in existingNsm.subordinateLsms) {
          selectedSubordinateLsmIds.add(sub.userId);
        }
      }
    }

    if (selectedUser.position?.code.toUpperCase() == 'NSM') {
      syncNsmState(selectedUser.id);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final posCode = selectedUser.position?.code.toUpperCase() ?? '';
          final isNsm = posCode == 'NSM';
          final isLsm = posCode == 'LSM';
          final isAsm = posCode == 'ASM';
          final isSpv = posCode == 'SPV';

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
                    color: isNsm
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : (isLsm
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                            : (isAsm ? AppColors.primary.withValues(alpha: 0.15) : AppColors.info.withValues(alpha: 0.15))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isNsm
                        ? LucideIcons.globe
                        : (isLsm ? LucideIcons.shieldCheck : (isAsm ? LucideIcons.crown : LucideIcons.target)),
                    color: isNsm
                        ? const Color(0xFFF59E0B)
                        : (isLsm ? const Color(0xFF8B5CF6) : (isAsm ? AppColors.primaryLight : AppColors.info)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Penugasan Insentif Konsumsi',
                        style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Hierarki: NSM (Nasional/Teritorial) ➔ LSM (Region) ➔ ASM (Distributor) ➔ SPV (Area)',
                        style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Pilih Sales Personil
                    Text('Sales Personil Lapangan (Eligible Konsumsi) *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: selectedUser.id,
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
                      items: allSalesList.map((u) {
                        final pName = u.position?.name ?? 'Tanpa Posisi';
                        final pCode = u.position?.code ?? '-';
                        return DropdownMenuItem<int>(
                          value: u.id,
                          child: Text(
                            '${u.name} (@${u.username}) • [$pCode - $pName]',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedUser = allSalesList.firstWhere((u) => u.id == val);
                            if (selectedUser.position?.code.toUpperCase() == 'NSM') {
                              syncNsmState(selectedUser.id);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // ==========================================
                    // Dynamic View based on Posisi
                    // ==========================================
                    if (isNsm) ...[
                      // 1. NSM Banner & Scope
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.globe, color: Color(0xFFF59E0B), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Posisi NSM (National Sales Manager)',
                                    style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'NSM adalah pimpinan sales di atas LSM. Jika terdapat beberapa NSM, masing-masing dapat membawahi LSM / Wilayah khusus (misal: Indonesia Timur, Barat, Utara, Selatan).',
                                    style: GoogleFonts.inter(color: colors.textMuted, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pilihan Cakupan NSM
                      Text('Cakupan Kepemimpinan NSM *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => nsmScope = 'ALL'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: nsmScope == 'ALL' ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: nsmScope == 'ALL' ? const Color(0xFFF59E0B) : colors.border,
                                    width: nsmScope == 'ALL' ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      nsmScope == 'ALL' ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                      size: 16,
                                      color: nsmScope == 'ALL' ? const Color(0xFFF59E0B) : colors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Nasional Penuh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary)),
                                          Text('Seluruh LSM & Region', style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
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
                              onTap: () => setDialogState(() => nsmScope = 'SPECIFIC'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: nsmScope == 'SPECIFIC' ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : colors.bgElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: nsmScope == 'SPECIFIC' ? const Color(0xFFF59E0B) : colors.border,
                                    width: nsmScope == 'SPECIFIC' ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      nsmScope == 'SPECIFIC' ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                      size: 16,
                                      color: nsmScope == 'SPECIFIC' ? const Color(0xFFF59E0B) : colors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Teritorial / LSM Khusus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.textPrimary)),
                                          Text('Membawahi LSM tertentu', style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
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

                      if (nsmScope == 'SPECIFIC') ...[
                        Text('Nama Teritorial / Wilayah NSM *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: territoryLabelCtrl,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.compass, size: 18, color: Color(0xFFF59E0B)),
                            hintText: 'Misal: Indonesia Timur, Indonesia Barat, dll.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            'Indonesia Timur',
                            'Indonesia Barat',
                            'Indonesia Utara',
                            'Indonesia Selatan',
                            'Jawa & Bali',
                            'Luar Jawa',
                          ].map((preset) {
                            final isSelected = territoryLabelCtrl.text.trim().toLowerCase() == preset.toLowerCase();
                            return ActionChip(
                              label: Text(preset, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : colors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              backgroundColor: isSelected ? const Color(0xFFF59E0B) : colors.bgElevated,
                              side: BorderSide(color: isSelected ? const Color(0xFFF59E0B) : colors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () {
                                setDialogState(() {
                                  territoryLabelCtrl.text = preset;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Checklist LSM yang dipimpin
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pilih LSM yang Dipimpin NSM Ini *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              '${selectedSubordinateLsmIds.length} LSM Terpilih',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: colors.bgElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: lsmUsers.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Belum ada user sales berposisi LSM. Silakan tambahkan user LSM di menu User Management.',
                                    style: TextStyle(color: colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: lsmUsers.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
                                  itemBuilder: (ctx, idx) {
                                    final lsm = lsmUsers[idx];
                                    final isChecked = selectedSubordinateLsmIds.contains(lsm.id);

                                    final lsmAssign = assignmentState.distributorAssignments.firstWhereOrNull((a) => a.userId == lsm.id);
                                    final lsmRegionName = lsmAssign?.region?.name ?? 'Belum ada Region';
                                    final currentNsmName = lsmAssign?.nsm?.name;

                                    return CheckboxListTile(
                                      value: isChecked,
                                      activeColor: const Color(0xFFF59E0B),
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      title: Text(
                                        '${lsm.name} (@${lsm.username})',
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        'Region: $lsmRegionName${currentNsmName != null ? ' • Atasan saat ini: $currentNsmName' : ''}',
                                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedSubordinateLsmIds.add(lsm.id);
                                          } else {
                                            selectedSubordinateLsmIds.remove(lsm.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        // Nasional Penuh
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.bgElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text('${lsmUsers.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF8B5CF6))),
                                  Text('Seluruh LSM', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                ],
                              ),
                              Container(height: 24, width: 1, color: colors.border),
                              Column(
                                children: [
                                  Text('${masterState.regions.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF59E0B))),
                                  Text('Seluruh Region', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                ],
                              ),
                              Container(height: 24, width: 1, color: colors.border),
                              Column(
                                children: [
                                  Text('${masterState.distributors.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4F46E5))),
                                  Text('Seluruh Distributor', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ] else if (isLsm) ...[
                      // 2. LSM Banner & Scope
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.shieldCheck, color: Color(0xFF8B5CF6), size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Posisi LSM (Line / Local Sales Manager)',
                                    style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'LSM adalah atasan langsung dari para ASM dan bertanggung jawab atas satu Teritorial Region (mencakup seluruh Distributor di region tersebut).',
                                    style: GoogleFonts.inter(color: colors.textMuted, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Atasan NSM untuk LSM
                      if (nsmUsers.isNotEmpty) ...[
                        Text('Atasan NSM (National Sales Manager)', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedNsm?.id,
                          dropdownColor: colors.bgElevated,
                          isExpanded: true,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.globe, size: 18, color: Color(0xFFF59E0B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Langsung ke Direksi (Tanpa NSM)')),
                            ...nsmUsers.map((n) {
                              final nsmAssign = assignmentState.distributorAssignments.firstWhereOrNull((a) => a.userId == n.id);
                              final territoryNote = (nsmAssign?.notes != null && nsmAssign!.notes!.isNotEmpty)
                                  ? ' [${nsmAssign.notes}]'
                                  : ' [Nasional Penuh]';
                              return DropdownMenuItem<int?>(
                                value: n.id,
                                child: Text('${n.name} (@${n.username})$territoryNote', overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedNsm = val != null ? nsmUsers.firstWhere((u) => u.id == val) : null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Pilih Wilayah / Region yang Dipegang LSM
                      Text('Pilih Wilayah / Region yang Dipegang LSM *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedRegion?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.map, size: 18, color: Color(0xFF8B5CF6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: masterState.regions.map((r) => DropdownMenuItem<int>(
                          value: r.id,
                          child: Text('${r.code} - ${r.name}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRegion = masterState.regions.firstWhere((r) => r.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Daftar distributor yang ada di region ini
                      Builder(
                        builder: (_) {
                          final distInRegion = masterState.distributors.where((d) => d.regionId == selectedRegion?.id).toList();
                          return Container(
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
                                  children: [
                                    const Icon(LucideIcons.building2, size: 16, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Distributor di Wilayah ${selectedRegion?.name ?? ''} (${distInRegion.length} Distributor):',
                                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (distInRegion.isEmpty)
                                  Text('Belum ada distributor yang dialokasikan ke region ini.', style: TextStyle(color: colors.textMuted, fontSize: 11.5, fontStyle: FontStyle.italic))
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: distInRegion.map((d) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                      ),
                                      child: Text('${d.name} (${d.depos.length} Depo)', style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                                    )).toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ] else if (isAsm) ...[
                      // 3. ASM Banner & Scope
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.crown, color: AppColors.primaryLight, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Posisi ASM (Area Sales Manager): Berada di bawah LSM, membawahi SPV. ASM memegang penuh Distributor terpilih beserta seluruh Depo & Areanya.',
                                style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Atasan LSM untuk ASM
                      if (lsmUsers.isNotEmpty) ...[
                        Text('Atasan LSM Penanggung Jawab Region', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedLsm?.id,
                          dropdownColor: colors.bgElevated,
                          isExpanded: true,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18, color: Color(0xFF8B5CF6)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: colors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Atasan LSM (Direct)')),
                            ...lsmUsers.map((l) => DropdownMenuItem<int?>(
                              value: l.id,
                              child: Text('${l.name} (@${l.username})'),
                            )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedLsm = val != null ? lsmUsers.firstWhere((u) => u.id == val) : null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Pilih Distributor
                      Text('Pilih Distributor yang Dipegang ASM *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDistributor?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.truck, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: masterState.distributors.map((d) {
                          final regInfo = d.region != null ? ' [Region: ${d.region!.name}]' : '';
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})$regInfo', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDistributor = masterState.distributors.firstWhere((d) => d.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      if (selectedDistributor != null) ...[
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
                                children: [
                                  const Icon(LucideIcons.layers, size: 16, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Depo & Area Otomatis Tercover (${selectedDistributor!.depos.length} Depo):',
                                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (selectedDistributor!.depos.isEmpty)
                                Text('Belum ada Depo di distributor ini.', style: TextStyle(color: colors.textMuted, fontSize: 12, fontStyle: FontStyle.italic))
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: selectedDistributor!.depos.map((d) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${d.name} (${d.areas.length} Area)',
                                        style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ] else if (isSpv) ...[
                      // 4. SPV Banner & Scope
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.target, color: AppColors.info, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Posisi SPV (Sales Supervisor): Berada di bawah ASM dan mengelola Area operasional spesifik dari Depo distributor tersebut.',
                                style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // SPV: Pilih Atasan ASM
                      Text('Atasan ASM Penanggung Jawab Distributor *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedAsm?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.warning),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: (asmUsers.isNotEmpty ? asmUsers : allSalesList).map((a) {
                          return DropdownMenuItem<int>(
                            value: a.id,
                            child: Text('${a.name} (@${a.username})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedAsm = allSalesList.firstWhere((u) => u.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pilih Distributor
                      Text('Pilih Distributor *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDistributor?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.truck, size: 18),
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
                              selectedDistributor = masterState.distributors.firstWhere((d) => d.id == val);
                              selectedDepo = selectedDistributor!.depos.isNotEmpty ? selectedDistributor!.depos.first : null;
                              selectedArea = (selectedDepo != null && selectedDepo!.areas.isNotEmpty) ? selectedDepo!.areas.first : null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pilih Depo
                      Text('Pilih Depo Distributor *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        key: ValueKey('depo_field_${selectedDistributor?.id}_${selectedDepo?.id}'),
                        initialValue: selectedDepo?.id,
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
                        items: (selectedDistributor?.depos ?? []).map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDepo = selectedDistributor?.depos.firstWhere((d) => d.id == val);
                              selectedArea = (selectedDepo != null && selectedDepo!.areas.isNotEmpty) ? selectedDepo!.areas.first : null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pilih Area
                      Text('Pilih Area yang Di-manage SPV *', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        key: ValueKey('area_field_${selectedDepo?.id}_${selectedArea?.id}'),
                        initialValue: selectedArea?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.info),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: colors.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: (selectedDepo?.areas ?? []).map((a) {
                          return DropdownMenuItem<int>(
                            value: a.id,
                            child: Text('${a.name} (${a.code})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedArea = selectedDepo!.areas.firstWhere((a) => a.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      // Fallback: distributor default
                      Text('Pilih Distributor Penugasan', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDistributor?.id,
                        dropdownColor: colors.bgElevated,
                        isExpanded: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.truck, size: 18),
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
                              selectedDistributor = masterState.distributors.firstWhere((d) => d.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Periode & Catatan
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Periode (YYYYMM)', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: periodCtrl,
                                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: colors.bgElevated,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Catatan Penugasan', style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: notesCtrl,
                                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Opsional',
                                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: colors.bgElevated,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  backgroundColor: isNsm
                      ? const Color(0xFFF59E0B)
                      : (isLsm
                          ? const Color(0xFF8B5CF6)
                          : (isAsm ? AppColors.primary : AppColors.info)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.check, size: 16, color: Colors.white),
                label: const Text('Simpan Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  if (isNsm && nsmScope == 'SPECIFIC' && selectedSubordinateLsmIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih minimal 1 LSM yang dipimpin oleh NSM Teritorial Khusus!'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (isLsm && selectedRegion == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Untuk penugasan LSM, wajib memilih Wilayah/Region!'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (isAsm && selectedDistributor == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Untuk penugasan ASM, wajib memilih Distributor!'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (isSpv && (selectedAsm == null || selectedDepo == null || selectedArea == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Untuk penugasan SPV, wajib memilih Atasan ASM, Depo, dan Area!'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }

                  final finalNotes = isNsm
                      ? (nsmScope == 'SPECIFIC'
                          ? (territoryLabelCtrl.text.trim().isEmpty ? 'Teritorial Khusus' : territoryLabelCtrl.text.trim())
                          : (notesCtrl.text.trim().isEmpty ? 'Nasional Penuh' : notesCtrl.text.trim()))
                      : notesCtrl.text.trim();

                  final success = await ref.read(salesAssignmentProvider.notifier).saveDistributorAssignment(
                    userId: selectedUser.id,
                    regionId: isLsm
                        ? selectedRegion?.id
                        : (isAsm || isSpv ? selectedDistributor?.regionId : null),
                    distributorId: (isNsm || isLsm) ? null : selectedDistributor?.id,
                    nsmId: isLsm ? selectedNsm?.id : null,
                    lsmId: isAsm ? selectedLsm?.id : null,
                    asmId: isSpv ? selectedAsm?.id : null,
                    depoId: isSpv ? selectedDepo?.id : null,
                    areaId: isSpv ? selectedArea?.id : null,
                    lsmIds: (isNsm && nsmScope == 'SPECIFIC') ? selectedSubordinateLsmIds.toList() : null,
                    period: periodCtrl.text.trim().isEmpty ? '202610' : periodCtrl.text.trim(),
                    notes: finalNotes,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  if (mounted) {
                    final msg = ref.read(salesAssignmentProvider).errorMessage ?? 'Penugasan berhasil disimpan';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Penugasan Sales Distributor berhasil disimpan!' : msg),
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

  // =========================================================================
  // DIALOG 2: Assign Koordinator & Sales Surabaya
  // =========================================================================
  void _showAssignSurabayaDialog() {
    final colors = context.colors;
    final userState = ref.read(userManagementProvider);
    final coordinators = userState.users.where((u) => u.isEligibleSurabaya || u.position?.code == 'COORD').toList();
    final allSales = userState.users;

    if (allSales.isEmpty) return;

    int selectedCoordId = coordinators.isNotEmpty ? coordinators.first.id : allSales.first.id;
    int selectedSalesId = allSales.isNotEmpty ? allSales.first.id : 1;
    String selectedType = 'Taking Order';
    final periodCtrl = TextEditingController(text: '202610');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                const Icon(LucideIcons.userCheck, color: AppColors.warning, size: 22),
                const SizedBox(width: 10),
                Text('Penugasan Tim Sales Surabaya', style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedCoordId,
                    dropdownColor: colors.bgElevated,
                    isExpanded: true,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Pilih Koordinator Surabaya'),
                    items: (coordinators.isNotEmpty ? coordinators : allSales).map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (@${c.username})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCoordId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSalesId,
                    dropdownColor: colors.bgElevated,
                    isExpanded: true,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Pilih Sales Personil'),
                    items: allSales.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.name} (@${s.username})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSalesId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: colors.bgElevated,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tipe Penugasan Khusus'),
                    items: const [
                      DropdownMenuItem(value: 'Taking Order', child: Text('Sales Taking Order (TO)')),
                      DropdownMenuItem(value: 'Canvasing', child: Text('Sales Canvasing (Ujung Tombak)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: periodCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Periode Penugasan (YYYYMM)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                onPressed: () async {
                  await ref.read(salesAssignmentProvider.notifier).saveSurabayaAssignment(
                    coordinatorId: selectedCoordId,
                    salesId: selectedSalesId,
                    salesType: selectedType,
                    period: periodCtrl.text.trim().isEmpty ? '202610' : periodCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Simpan Assignment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(salesAssignmentProvider);

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
                        'Master Sales',
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
                          'Konsumsi & Surabaya',
                          style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manajemen penugasan Distributor untuk Sales Konsumsi (NSM, LSM, ASM, SPV) dan Tim Sales Surabaya',
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final actionButton = _activeTabIndex == 0
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.white),
                      label: const Text('Assign Distributor (Konsumsi)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _showAssignDistributorDialog,
                    )
                  : (_activeTabIndex == 1
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.black),
                          label: const Text('Assign Koordinator Surabaya', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          onPressed: _showAssignSurabayaDialog,
                        )
                      : const SizedBox.shrink());

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
                    tooltip: 'Muat Ulang Data',
                    color: context.colors.textMuted,
                    onPressed: () {
                      ref.read(salesAssignmentProvider.notifier).fetchAllAssignments();
                      ref.read(masterDataProvider.notifier).fetchAllMasterData();
                      ref.read(userManagementProvider.notifier).fetchAll();
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
                  indicatorColor: _activeTabIndex == 0 ? AppColors.primaryLight : AppColors.warning,
                  labelColor: context.colors.textPrimary,
                  unselectedLabelColor: context.colors.textMuted,
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.building2, size: 16),
                          const SizedBox(width: 8),
                          Text('Penugasan Konsumsi / Distributor (${assignmentState.distributorAssignments.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 16),
                          const SizedBox(width: 8),
                          Text('Penugasan Sales Surabaya (${assignmentState.surabayaAssignments.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

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
        return _buildDistributorAssignmentTab();
      case 1:
      default:
        return _buildSurabayaAssignmentTab();
    }
  }

  // =========================================================================
  // TAB 0: TABEL PENUGASAN KONSUMSI (DISTRIBUTOR: ASM & SPV)
  // =========================================================================
  Widget _buildDistributorAssignmentTab() {
    final assignmentState = ref.watch(salesAssignmentProvider);
    final rawList = assignmentState.distributorAssignments;

    // Filter by position & query
    final filteredList = rawList.where((item) {
      final posCode = item.user?.position?.code.toUpperCase() ?? '';
      if (_filterPosition == 'NSM' && posCode != 'NSM') return false;
      if (_filterPosition == 'LSM' && posCode != 'LSM') return false;
      if (_filterPosition == 'ASM' && posCode != 'ASM') return false;
      if (_filterPosition == 'SPV' && posCode != 'SPV') return false;

      if (_searchDistributorQuery.isNotEmpty) {
        final q = _searchDistributorQuery.toLowerCase();
        final userName = (item.user?.name ?? '').toLowerCase();
        final distName = (item.distributor?.name ?? '').toLowerCase();
        final regionName = (item.region?.name ?? item.distributor?.region?.name ?? '').toLowerCase();
        final depoName = (item.depo?.name ?? '').toLowerCase();
        final areaName = (item.area?.name ?? '').toLowerCase();
        final asmName = (item.asm?.name ?? '').toLowerCase();
        final lsmName = (item.lsm?.name ?? '').toLowerCase();
        final nsmName = (item.nsm?.name ?? '').toLowerCase();
        return userName.contains(q) ||
            distName.contains(q) ||
            regionName.contains(q) ||
            depoName.contains(q) ||
            areaName.contains(q) ||
            asmName.contains(q) ||
            lsmName.contains(q) ||
            nsmName.contains(q);
      }
      return true;
    }).toList();

    final nsmCount = rawList.where((i) => i.user?.position?.code.toUpperCase() == 'NSM').length;
    final lsmCount = rawList.where((i) => i.user?.position?.code.toUpperCase() == 'LSM').length;
    final asmCount = rawList.where((i) => i.user?.position?.code.toUpperCase() == 'ASM').length;
    final spvCount = rawList.where((i) => i.user?.position?.code.toUpperCase() == 'SPV').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Banner
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMiniKpiCard(
                  title: 'Total Penugasan Konsumsi',
                  value: '${rawList.length}',
                  icon: LucideIcons.fileSpreadsheet,
                  color: AppColors.primary,
                ),
                _buildMiniKpiCard(
                  title: 'NSM (Nasional)',
                  value: '$nsmCount Orang',
                  icon: LucideIcons.globe,
                  color: const Color(0xFFF59E0B),
                ),
                _buildMiniKpiCard(
                  title: 'LSM (Region)',
                  value: '$lsmCount Orang',
                  icon: LucideIcons.shieldCheck,
                  color: const Color(0xFF8B5CF6),
                ),
                _buildMiniKpiCard(
                  title: 'ASM (Distributor)',
                  value: '$asmCount Orang',
                  icon: LucideIcons.crown,
                  color: AppColors.primaryLight,
                ),
                _buildMiniKpiCard(
                  title: 'SPV (Area)',
                  value: '$spvCount Orang',
                  icon: LucideIcons.target,
                  color: AppColors.info,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Filter & Search Toolbar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchDistributorCtrl,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari Sales, Region, Distributor, Depo, atau Area...',
                  hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: context.colors.bgElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchDistributorQuery = val.trim()),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: context.colors.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterPosition,
                  dropdownColor: context.colors.bgElevated,
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Semua Posisi')),
                    DropdownMenuItem(value: 'NSM', child: Text('Hanya NSM (Nasional)')),
                    DropdownMenuItem(value: 'LSM', child: Text('Hanya LSM (Region)')),
                    DropdownMenuItem(value: 'ASM', child: Text('Hanya ASM (Distributor)')),
                    DropdownMenuItem(value: 'SPV', child: Text('Hanya SPV (Area)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterPosition = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(LucideIcons.inbox, size: 48, color: context.colors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('Belum ada data penugasan distributor yang cocok.', style: TextStyle(color: context.colors.textMuted)),
              ],
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 1040,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
              columns: [
                DataColumn(label: Text('Posisi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Sales Personil Lapangan', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Hirarki Atasan', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Wilayah / Region', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Distributor yang Dipegang', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Depo Terkait', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Area yang Di-manage', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Periode', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
              ],
              rows: filteredList.map((item) {
                final pos = item.user?.position?.code.toUpperCase() ?? '';
                final isNsm = pos == 'NSM';
                final isLsm = pos == 'LSM';
                final isAsm = pos == 'ASM';
                final isSpv = pos == 'SPV';

                final Color badgeColor = isNsm
                    ? const Color(0xFFF59E0B)
                    : (isLsm
                        ? const Color(0xFF8B5CF6)
                        : (isAsm ? AppColors.primaryLight : (isSpv ? AppColors.info : AppColors.slate400)));

                return DataRow(
                  cells: [
                    // Posisi Badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          item.user?.position?.code ?? 'SALES',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                    // Sales Name
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: badgeColor.withValues(alpha: 0.2),
                            child: Text(
                              (item.user?.name.isNotEmpty == true) ? item.user!.name[0].toUpperCase() : 'S',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.user?.name ?? 'User #${item.userId}', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
                              Text('@${item.user?.username ?? '-'}', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Atasan Berjenjang
                    DataCell(
                      isNsm
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Direksi / Nasional', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          : (isLsm
                              ? (item.nsm != null
                                  ? Builder(
                                      builder: (_) {
                                        final nsmAssign = rawList.firstWhereOrNull((a) => a.userId == item.nsmId);
                                        final territoryNote = (nsmAssign?.notes != null && nsmAssign!.notes!.isNotEmpty && nsmAssign.notes != 'Nasional Penuh')
                                            ? ' [${nsmAssign.notes}]'
                                            : '';
                                        return Row(
                                          children: [
                                            const Icon(LucideIcons.globe, size: 14, color: Color(0xFFF59E0B)),
                                            const SizedBox(width: 6),
                                            Text('NSM: ${item.nsm!.name}$territoryNote', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                                          ],
                                        );
                                      },
                                    )
                                  : const Text('Direct (Tanpa NSM)', style: TextStyle(color: AppColors.slate400, fontSize: 11, fontStyle: FontStyle.italic)))
                              : (isAsm
                                  ? (item.lsm != null
                                      ? Row(
                                          children: [
                                            const Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF8B5CF6)),
                                            const SizedBox(width: 6),
                                            Text('LSM: ${item.lsm!.name}', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                                          ],
                                        )
                                      : const Text('Direct (Tanpa LSM)', style: TextStyle(color: AppColors.slate400, fontSize: 11, fontStyle: FontStyle.italic)))
                                  : Row(
                                      children: [
                                        const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.warning),
                                        const SizedBox(width: 6),
                                        Text(item.asm?.name ?? 'ASM Penanggung Jawab', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                                      ],
                                    ))),
                    ),

                    // Wilayah / Region
                    DataCell(
                      isNsm
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    (item.notes != null && item.notes!.isNotEmpty && item.notes != 'Nasional Penuh')
                                        ? item.notes!
                                        : 'Seluruh Indonesia (Nasional)',
                                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (item.subordinateLsms.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Membawahi ${item.subordinateLsms.length} LSM: ${item.subordinateLsms.map((s) => s.user?.name ?? 'LSM').join(', ')}',
                                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            )
                          : (isLsm
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    item.region != null ? '${item.region!.code} - ${item.region!.name}' : 'Semua Region',
                                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : Text(
                                  item.region?.name ?? item.distributor?.region?.name ?? 'Tanpa Region',
                                  style: TextStyle(color: context.colors.textPrimary, fontSize: 12),
                                )),
                    ),

                    // Distributor
                    DataCell(
                      isNsm
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                (item.notes != null && item.notes!.isNotEmpty && item.notes != 'Nasional Penuh')
                                    ? 'Distributor Teritorial (${item.subordinateLsms.length} LSM Region)'
                                    : 'Seluruh Distributor Nasional',
                                style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          : (isLsm
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text('Distributor Region ${item.region?.code ?? ""}', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.distributor?.name ?? 'Distributor #${item.distributorId}', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                                    Text(item.distributor?.code ?? '-', style: const TextStyle(color: AppColors.primaryAccent, fontSize: 11)),
                                  ],
                                )),
                    ),

                    // Depo
                    DataCell(
                      (isNsm || isLsm)
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Semua Depo Teritorial', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          : (isAsm
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Semua Depo Tercakup', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : Text(item.depo?.name ?? 'Depo #${item.depoId ?? '-'}', style: TextStyle(color: context.colors.textPrimary))),
                    ),

                    // Area
                    DataCell(
                      (isNsm || isLsm)
                          ? const Text('Seluruh Area Wilayah', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500))
                          : (isAsm
                              ? const Text('Seluruh Area Distributor', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500))
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.area?.name ?? 'Area #${item.areaId ?? '-'}',
                                    style: const TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )),
                    ),

                    // Periode
                    DataCell(Text(item.period, style: TextStyle(color: context.colors.textMuted))),

                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Aktif', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    // Aksi
                    DataCell(
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                        tooltip: 'Hapus Penugasan',
                        onPressed: () async {
                          final confirmed = await showConfirmDeleteDialog(
                            context: context,
                            title: 'Hapus Penugasan Distributor',
                            message: 'Apakah Anda yakin ingin menghapus penugasan "${item.user?.name ?? 'Sales'}"?',
                          );
                          if (confirmed == true) {
                            await ref.read(salesAssignmentProvider.notifier).deleteDistributorAssignment(item.id);
                          }
                        },
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


  // =========================================================================
  // TAB 1: TABEL PENUGASAN KOORDINATOR & SALES SURABAYA
  // =========================================================================
  Widget _buildSurabayaAssignmentTab() {
    final assignmentState = ref.watch(salesAssignmentProvider);
    final list = assignmentState.surabayaAssignments;

    return ResponsiveTableCard(
      minWidth: 800,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(context.colors.bgTableHead),
        columns: [
          DataColumn(label: Text('Koordinator Surabaya', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Sales Personil Lapangan', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Model Penugasan', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Periode', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Aksi', style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.bold))),
        ],
        rows: list.map((item) {
          final isTO = item.salesType == 'Taking Order';

          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    const Icon(LucideIcons.userCheck, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(item.coordinator?.name ?? 'Koordinator #${item.coordinatorId}', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              DataCell(Text(item.sales?.name ?? 'Sales #${item.salesId}', style: TextStyle(color: context.colors.textPrimary))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTO ? AppColors.primary.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.salesType,
                    style: TextStyle(
                      color: isTO ? AppColors.primaryLight : AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text(item.period, style: TextStyle(color: context.colors.textMuted))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Aktif', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                  tooltip: 'Hapus Assignment',
                  onPressed: () async {
                    final confirmed = await showConfirmDeleteDialog(
                      context: context,
                      title: 'Hapus Assignment Sales Surabaya',
                      message: 'Apakah Anda yakin ingin menghapus penugasan "${item.sales?.name ?? 'Sales'}" di bawah koordinator "${item.coordinator?.name ?? 'Koordinator'}"?',
                    );
                    if (confirmed == true) {
                      await ref.read(salesAssignmentProvider.notifier).deleteSurabayaAssignment(item.id);
                    }
                  },
                ),
              ),
            ],
          );
        }).toList(),
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
              Text(value, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

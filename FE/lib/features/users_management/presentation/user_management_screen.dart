import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/models/master_model.dart';
import '../../master_data/providers/master_data_provider.dart';
import '../providers/user_management_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeTabIndex = 0;
  int? _selectedRoleId;
  int? _lastSyncedRoleId;
  final Map<int, Map<String, bool>> _workingPermissions = {};
  bool _isSavingPermissions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    final clean = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
    return clean;
  }

  // ---------------- User Form Dialog ----------------

  void _showUserFormDialog({UserModel? user}) {
    final colors = context.colors;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final passwordCtrl = TextEditingController();

    String sanitizeDate(String? d) {
      if (d == null || d.trim().isEmpty) return '';
      final s = d.trim();
      if (s.contains('T')) return s.split('T').first;
      if (s.length > 10) return s.substring(0, 10);
      return s;
    }

    final initialFrom = sanitizeDate(user?.aktifFrom);
    final aktifFromCtrl = TextEditingController(
      text: initialFrom.isNotEmpty ? initialFrom : DateTime.now().toString().substring(0, 10),
    );
    final aktifToCtrl = TextEditingController(text: sanitizeDate(user?.aktifTo));

    final state = ref.read(userManagementProvider);
    int selectedRoleId = user?.roleId ?? (state.roles.isNotEmpty ? state.roles.first.id : 1);
    int? selectedPosId = user?.positionId ?? (state.positions.isNotEmpty ? state.positions.first.id : null);
    bool isKonsumsi = user?.isEligibleKonsumsi ?? true;
    bool isIndustri = user?.isEligibleIndustri ?? false;
    bool isSurabaya = user?.isEligibleSurabaya ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            title: Row(
              children: [
                Icon(user == null ? LucideIcons.userPlus : LucideIcons.userCheck, color: AppColors.primaryLight, size: 22),
                const SizedBox(width: 10),
                Text(
                  user == null ? 'Tambah User Baru' : 'Edit Pengguna',
                  style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    if (user == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Kata Sandi Default'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedRoleId,
                            dropdownColor: colors.bgCard,
                            isExpanded: true,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Role Akses'),
                            items: state.roles.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                child: Text(r.displayName, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedRoleId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: selectedPosId,
                            dropdownColor: colors.bgCard,
                            isExpanded: true,
                            style: TextStyle(color: colors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Posisi Sales'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tanpa Posisi', overflow: TextOverflow.ellipsis),
                              ),
                              ...state.positions.map((p) {
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name} (${p.code})', overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setDialogState(() => selectedPosId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: aktifFromCtrl,
                            readOnly: true,
                            onTap: () async {
                              final initial = DateTime.tryParse(aktifFromCtrl.text) ?? DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: initial,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final y = picked.year.toString().padLeft(4, '0');
                                final m = picked.month.toString().padLeft(2, '0');
                                final d = picked.day.toString().padLeft(2, '0');
                                setDialogState(() {
                                  aktifFromCtrl.text = '$y-$m-$d';
                                });
                              }
                            },
                            style: TextStyle(color: colors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Aktif Dari (Tanggal)',
                              hintText: 'YYYY-MM-DD',
                              suffixIcon: IconButton(
                                icon: const Icon(LucideIcons.calendar, size: 18),
                                onPressed: () async {
                                  final initial = DateTime.tryParse(aktifFromCtrl.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: initial,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    final y = picked.year.toString().padLeft(4, '0');
                                    final m = picked.month.toString().padLeft(2, '0');
                                    final d = picked.day.toString().padLeft(2, '0');
                                    setDialogState(() {
                                      aktifFromCtrl.text = '$y-$m-$d';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: aktifToCtrl,
                            readOnly: true,
                            onTap: () async {
                              final initial = DateTime.tryParse(aktifToCtrl.text) ?? DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: initial,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final y = picked.year.toString().padLeft(4, '0');
                                final m = picked.month.toString().padLeft(2, '0');
                                final d = picked.day.toString().padLeft(2, '0');
                                setDialogState(() {
                                  aktifToCtrl.text = '$y-$m-$d';
                                });
                              }
                            },
                            style: TextStyle(color: colors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Aktif Hingga (Opsional)',
                              hintText: 'Kosong = Permanen',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (aktifToCtrl.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(LucideIcons.x, size: 16),
                                      onPressed: () {
                                        setDialogState(() {
                                          aktifToCtrl.clear();
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.calendar, size: 18),
                                    onPressed: () async {
                                      final initial = DateTime.tryParse(aktifToCtrl.text) ?? DateTime.now();
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: initial,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        final y = picked.year.toString().padLeft(4, '0');
                                        final m = picked.month.toString().padLeft(2, '0');
                                        final d = picked.day.toString().padLeft(2, '0');
                                        setDialogState(() {
                                          aktifToCtrl.text = '$y-$m-$d';
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Eligibility Perhitungan Skema Insentif (Antrean Kalkulasi):',
                      style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Eligible Insentif Konsumsi (Distributor)', style: TextStyle(color: colors.textPrimary, fontSize: 12.5)),
                      value: isKonsumsi,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setDialogState(() => isKonsumsi = val ?? false),
                    ),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Eligible Insentif Industri', style: TextStyle(color: colors.textPrimary, fontSize: 12.5)),
                      value: isIndustri,
                      activeColor: AppColors.success,
                      onChanged: (val) => setDialogState(() => isIndustri = val ?? false),
                    ),
                    CheckboxListTile(
                      dense: true,
                      title: Text('Eligible Insentif Sales Surabaya', style: TextStyle(color: colors.textPrimary, fontSize: 12.5)),
                      value: isSurabaya,
                      activeColor: AppColors.warning,
                      onChanged: (val) => setDialogState(() => isSurabaya = val ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.inter(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'username': usernameCtrl.text.trim(),
                    if (passwordCtrl.text.isNotEmpty) 'password': passwordCtrl.text,
                    'role_id': selectedRoleId,
                    'position_id': selectedPosId,
                    'aktif_from': aktifFromCtrl.text.trim(),
                    'aktif_to': aktifToCtrl.text.trim().isEmpty ? null : aktifToCtrl.text.trim(),
                    'is_eligible_konsumsi': isKonsumsi,
                    'is_eligible_industri': isIndustri,
                    'is_eligible_surabaya': isSurabaya,
                  };
                  ref.read(userManagementProvider.notifier).saveUser(data, id: user?.id);
                  Navigator.pop(ctx);
                },
                child: Text('Simpan Pengguna', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Change Password Dialog ----------------

  void _showChangePasswordDialog(UserModel user) {
    final colors = context.colors;
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.key, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Text('Ubah Kata Sandi: ${user.name}', style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan kata sandi baru untuk akun @${user.username}:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Kata Sandi Baru'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              if (passCtrl.text.isNotEmpty) {
                ref.read(userManagementProvider.notifier).changePassword(user.id, passCtrl.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Sandi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------- Add Position Dialog ----------------

  void _showAddPositionDialog() {
    final colors = context.colors;
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Text('Tambah Posisi Sales', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Nama Posisi (Contoh: Sales Canvasing)')),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Kode Posisi (Contoh: SALES_CANVAS)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                ref.read(userManagementProvider.notifier).savePosition(nameCtrl.text.trim(), codeCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Posisi'),
          ),
        ],
      ),
    );
  }

  // ---------------- Add Role Dialog ----------------

  void _showAddRoleDialog() {
    final colors = context.colors;
    final nameCtrl = TextEditingController();
    final displayCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Text('Tambah Role Baru', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Nama Role (Contoh: Admin Sales)')),
            const SizedBox(height: 12),
            TextField(controller: displayCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Display Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                ref.read(userManagementProvider.notifier).saveRole(nameCtrl.text.trim(), displayCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Role'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(userManagementProvider);
    final masterState = ref.watch(masterDataProvider);
    _syncWorkingPermissions(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role & Manajemen Hak Akses',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola akun pengguna, penugasan posisi sales lapangan, role sistem, region wilayah, dan hak akses menu aplikasi',
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              );

              final addButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  _activeTabIndex == 1
                      ? LucideIcons.shieldAlert
                      : (_activeTabIndex == 2
                          ? LucideIcons.briefcase
                          : (_activeTabIndex == 3 ? LucideIcons.mapPin : LucideIcons.userPlus)),
                  size: 16,
                ),
                label: Text(
                  _activeTabIndex == 1
                      ? 'Tambah Role'
                      : (_activeTabIndex == 2
                          ? 'Tambah Posisi'
                          : (_activeTabIndex == 3 ? 'Tambah Region' : 'Tambah User')),
                ),
                onPressed: () {
                  if (_activeTabIndex == 1) {
                    _showAddRoleDialog();
                  } else if (_activeTabIndex == 2) {
                    _showAddPositionDialog();
                  } else if (_activeTabIndex == 3) {
                    _showRegionFormDialog();
                  } else {
                    _showUserFormDialog();
                  }
                },
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

          // Search & Tab Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
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
                      indicatorColor: AppColors.primary,
                      labelColor: colors.textPrimary,
                      unselectedLabelColor: colors.textSecondary,
                      onTap: (val) => setState(() => _activeTabIndex = val),
                      tabs: [
                        Tab(text: 'Daftar Pengguna (${state.users.length})'),
                        Tab(text: 'Role Sistem (${state.roles.length})'),
                        Tab(text: 'Posisi Sales (${state.positions.length})'),
                        Tab(text: 'Wilayah Region (${masterState.regions.length})'),
                        Tab(text: 'Hak Akses Menu (${state.menus.length})'),
                      ],
                    );

                    final searchField = SizedBox(
                      width: isCompact ? double.infinity : 240,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari data...',
                          hintStyle: TextStyle(color: colors.textMuted),
                          prefixIcon: Icon(LucideIcons.search, size: 15, color: colors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: colors.bgInput,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderMuted)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
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
                          searchField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: tabBar),
                        const SizedBox(width: 14),
                        searchField,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 16),

                // Dynamic Active Tab (No fixed height clipping)
                _buildActiveTabContent(context, state, masterState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, UserManagementState state, MasterDataState masterState) {
    switch (_activeTabIndex) {
      case 0:
        return _buildUsersTable(context, state);
      case 1:
        return _buildRolesTable(context, state);
      case 2:
        return _buildPositionsTable(context, state);
      case 3:
        return _buildRegionsTable(context, masterState);
      case 4:
      default:
        return _buildMenusTable(context, state);
    }
  }

  Widget _buildUsersTable(BuildContext context, UserManagementState state) {
    final colors = context.colors;
    final filtered = state.users.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.name.toLowerCase().contains(_searchQuery) || u.username.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(LucideIcons.users, size: 40, color: colors.textMuted),
              const SizedBox(height: 12),
              Text('Tidak ada pengguna ditemukan', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ResponsiveTableCard(
      minWidth: 800,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
        columnSpacing: 16,
        horizontalMargin: 12,
        columns: [
          DataColumn(label: Text('Nama & Username', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Role', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Posisi Sales', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Masa Aktif', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Eligibility Skema', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((u) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        (u.name.isNotEmpty ? u.name[0] : 'U').toUpperCase(),
                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(u.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text('@${u.username}', style: TextStyle(color: colors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(6)),
                  child: Text(u.role?.displayName ?? 'User', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(u.position?.name ?? '-', style: TextStyle(color: colors.textSecondary, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                Text(
                  u.aktifTo != null ? '${_formatDate(u.aktifFrom)} s/d ${_formatDate(u.aktifTo)}' : '${_formatDate(u.aktifFrom)} (Aktif)',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (u.isEligibleKonsumsi)
                      _eligibleChip('Konsumsi', AppColors.primary),
                    if (u.isEligibleIndustri)
                      _eligibleChip('Industri', AppColors.success),
                    if (u.isEligibleSurabaya)
                      _eligibleChip('Surabaya', AppColors.warning),
                    if (!u.isEligibleKonsumsi && !u.isEligibleIndustri && !u.isEligibleSurabaya)
                      Text('-', style: TextStyle(color: colors.textMuted)),
                  ],
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.edit2, size: 15, color: AppColors.primaryLight),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Data',
                      onPressed: () => _showUserFormDialog(user: u),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.key, size: 15, color: AppColors.warning),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Ubah Password',
                      onPressed: () => _showChangePasswordDialog(u),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Hapus User',
                      onPressed: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context: context,
                          title: 'Hapus Akun Pengguna',
                          message: 'Apakah Anda yakin ingin menghapus akun "${u.name}" (@${u.username})? Tindakan ini tidak dapat dibatalkan.',
                        );
                        if (confirmed == true) {
                          ref.read(userManagementProvider.notifier).deleteUser(u.id);
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

  Widget _eligibleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRolesTable(BuildContext context, UserManagementState state) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Tambah Role'),
              onPressed: _showAddRoleDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.roles.length,
          itemBuilder: (ctx, i) {
            final r = state.roles[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shield, color: AppColors.primaryLight, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.displayName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Identifier: ${r.name}', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                    tooltip: 'Hapus Role Akses',
                    onPressed: () async {
                      final confirmed = await showConfirmDeleteDialog(
                        context: context,
                        title: 'Hapus Role Akses',
                        message: 'Apakah Anda yakin ingin menghapus role "${r.displayName}"? Pengguna dengan role ini akan terpengaruh.',
                      );
                      if (confirmed == true) {
                        ref.read(userManagementProvider.notifier).deleteRole(r.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPositionsTable(BuildContext context, UserManagementState state) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Tambah Posisi Sales'),
              onPressed: _showAddPositionDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.positions.length,
          itemBuilder: (ctx, i) {
            final p = state.positions[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(p.code, style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                    tooltip: 'Hapus Posisi Sales',
                    onPressed: () async {
                      final confirmed = await showConfirmDeleteDialog(
                        context: context,
                        title: 'Hapus Posisi Sales',
                        message: 'Apakah Anda yakin ingin menghapus posisi "${p.name}" (${p.code})?',
                      );
                      if (confirmed == true) {
                        ref.read(userManagementProvider.notifier).deletePosition(p.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRegionFormDialog({RegionModel? region}) {
    final colors = context.colors;
    final codeCtrl = TextEditingController(text: region?.code ?? '');
    final nameCtrl = TextEditingController(text: region?.name ?? '');
    final descCtrl = TextEditingController(text: region?.description ?? '');
    final isEdit = region != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Row(
          children: [
            Icon(isEdit ? LucideIcons.edit3 : LucideIcons.mapPin, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: 10),
            Text(isEdit ? 'Edit Wilayah Region' : 'Tambah Region Baru', style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: 'Kode Region (Contoh: REG01)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nama Wilayah Region (Contoh: Jawa Timur & Bali)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(labelText: 'Deskripsi Cakupan Area'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (codeCtrl.text.trim().isNotEmpty && nameCtrl.text.trim().isNotEmpty) {
                await ref.read(masterDataProvider.notifier).saveRegion(
                  id: region?.id,
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Buat Region'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsTable(BuildContext context, MasterDataState masterState) {
    final colors = context.colors;
    final regions = masterState.regions.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery) || r.code.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daftar Region Wilayah Distribusi (${regions.length})', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Tambah Region Baru'),
              onPressed: () => _showRegionFormDialog(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (regions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text('Belum ada data region wilayah.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: regions.length,
            itemBuilder: (ctx, i) {
              final r = regions[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(r.code, style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (r.description != null && r.description!.isNotEmpty)
                            Text(r.description!, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text('${r.distributorsCount} Distributor', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.primaryLight),
                      tooltip: 'Edit Region',
                      onPressed: () => _showRegionFormDialog(region: r),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                      tooltip: 'Hapus Region',
                      onPressed: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context: context,
                          title: 'Hapus Region Wilayah',
                          message: 'Apakah Anda yakin ingin menghapus region "${r.name}" (${r.code})?',
                        );
                        if (confirmed == true) {
                          ref.read(masterDataProvider.notifier).deleteRegion(r.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _syncWorkingPermissions(UserManagementState state) {
    if (state.roles.isEmpty) return;

    if (_selectedRoleId == null || !state.roles.any((r) => r.id == _selectedRoleId)) {
      _selectedRoleId = state.roles.first.id;
      _lastSyncedRoleId = null;
    }

    if (_lastSyncedRoleId != _selectedRoleId) {
      _lastSyncedRoleId = _selectedRoleId;
      _workingPermissions.clear();

      final role = state.roles.firstWhere((r) => r.id == _selectedRoleId);
      for (final menu in state.menus) {
        final existing = role.menuPermissions.where((p) => p.menuId == menu.id).firstOrNull;
        if (existing != null) {
          _workingPermissions[menu.id] = {
            'can_view': existing.canView,
            'can_create': existing.canCreate,
            'can_update': existing.canUpdate,
            'can_delete': existing.canDelete,
          };
        } else {
          final isAdmin = role.name.toLowerCase().contains('admin');
          _workingPermissions[menu.id] = {
            'can_view': isAdmin,
            'can_create': isAdmin,
            'can_update': isAdmin,
            'can_delete': isAdmin,
          };
        }
      }
    } else {
      final role = state.roles.firstWhere((r) => r.id == _selectedRoleId);
      for (final menu in state.menus) {
        if (!_workingPermissions.containsKey(menu.id)) {
          final existing = role.menuPermissions.where((p) => p.menuId == menu.id).firstOrNull;
          if (existing != null) {
            _workingPermissions[menu.id] = {
              'can_view': existing.canView,
              'can_create': existing.canCreate,
              'can_update': existing.canUpdate,
              'can_delete': existing.canDelete,
            };
          } else {
            final isAdmin = role.name.toLowerCase().contains('admin');
            _workingPermissions[menu.id] = {
              'can_view': isAdmin,
              'can_create': isAdmin,
              'can_update': isAdmin,
              'can_delete': isAdmin,
            };
          }
        }
      }
    }
  }

  void _togglePermission(int menuId, String key, bool value) {
    setState(() {
      _workingPermissions[menuId] ??= {
        'can_view': false,
        'can_create': false,
        'can_update': false,
        'can_delete': false,
      };
      _workingPermissions[menuId]![key] = value;
      // If giving create, update or delete, automatically grant view
      if (value && key != 'can_view') {
        _workingPermissions[menuId]!['can_view'] = true;
      }
      // If revoking view, revoke create, update and delete
      if (!value && key == 'can_view') {
        _workingPermissions[menuId]!['can_create'] = false;
        _workingPermissions[menuId]!['can_update'] = false;
        _workingPermissions[menuId]!['can_delete'] = false;
      }
    });
  }

  void _toggleRow(int menuId, bool enable) {
    setState(() {
      _workingPermissions[menuId] = {
        'can_view': enable,
        'can_create': enable,
        'can_update': enable,
        'can_delete': enable,
      };
    });
  }

  void _toggleColumn(String key, bool enable, List<MenuModel> menus) {
    setState(() {
      for (final m in menus) {
        _workingPermissions[m.id] ??= {
          'can_view': false,
          'can_create': false,
          'can_update': false,
          'can_delete': false,
        };
        _workingPermissions[m.id]![key] = enable;
        if (enable && key != 'can_view') {
          _workingPermissions[m.id]!['can_view'] = true;
        }
        if (!enable && key == 'can_view') {
          _workingPermissions[m.id]!['can_create'] = false;
          _workingPermissions[m.id]!['can_update'] = false;
          _workingPermissions[m.id]!['can_delete'] = false;
        }
      }
    });
  }

  void _grantAllAccess(List<MenuModel> menus) {
    setState(() {
      for (final m in menus) {
        _workingPermissions[m.id] = {
          'can_view': true,
          'can_create': true,
          'can_update': true,
          'can_delete': true,
        };
      }
    });
  }

  void _revokeAllAccess(List<MenuModel> menus) {
    setState(() {
      for (final m in menus) {
        _workingPermissions[m.id] = {
          'can_view': false,
          'can_create': false,
          'can_update': false,
          'can_delete': false,
        };
      }
    });
  }

  void _resetPermissions(RoleModel role, List<MenuModel> menus) {
    setState(() {
      _workingPermissions.clear();
      for (final menu in menus) {
        final existing = role.menuPermissions.where((p) => p.menuId == menu.id).firstOrNull;
        if (existing != null) {
          _workingPermissions[menu.id] = {
            'can_view': existing.canView,
            'can_create': existing.canCreate,
            'can_update': existing.canUpdate,
            'can_delete': existing.canDelete,
          };
        } else {
          _workingPermissions[menu.id] = {
            'can_view': false,
            'can_create': false,
            'can_update': false,
            'can_delete': false,
          };
        }
      }
    });
  }

  Future<void> _savePermissions(RoleModel role, List<MenuModel> allMenus) async {
    setState(() => _isSavingPermissions = true);
    try {
      final payload = allMenus.map((m) {
        final p = _workingPermissions[m.id] ?? {
          'can_view': false,
          'can_create': false,
          'can_update': false,
          'can_delete': false,
        };
        return {
          'menu_id': m.id,
          'can_view': p['can_view'] == true,
          'can_create': p['can_create'] == true,
          'can_update': p['can_update'] == true,
          'can_delete': p['can_delete'] == true,
        };
      }).toList();

      final success = await ref.read(userManagementProvider.notifier).updateRolePermissions(role.id, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Hak akses role "${role.displayName}" berhasil disimpan!' : 'Gagal menyimpan hak akses',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPermissions = false);
      }
    }
  }

  Widget _buildMenusTable(BuildContext context, UserManagementState state) {
    final colors = context.colors;

    if (state.roles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(LucideIcons.shieldAlert, size: 40, color: colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Belum ada role sistem. Tambahkan role terlebih dahulu pada tab "Role Sistem".',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final selectedRole = state.roles.firstWhere(
      (r) => r.id == _selectedRoleId,
      orElse: () => state.roles.first,
    );

    final filteredMenus = state.menus.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.name.toLowerCase().contains(_searchQuery) || (m.route ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    final allCanView = filteredMenus.isNotEmpty && filteredMenus.every((m) => _workingPermissions[m.id]?['can_view'] == true);
    final allCanCreate = filteredMenus.isNotEmpty && filteredMenus.every((m) => _workingPermissions[m.id]?['can_create'] == true);
    final allCanUpdate = filteredMenus.isNotEmpty && filteredMenus.every((m) => _workingPermissions[m.id]?['can_update'] == true);
    final allCanDelete = filteredMenus.isNotEmpty && filteredMenus.every((m) => _workingPermissions[m.id]?['can_delete'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Selector & Action Toolbar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 750;

              final roleSelector = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pilih Role Konfigurasi:', style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedRole.id,
                          dropdownColor: colors.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          items: state.roles.map((r) {
                            return DropdownMenuItem<int>(
                              value: r.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.displayName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  const SizedBox(width: 6),
                                  Text('(${r.name})', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null && newId != _selectedRoleId) {
                              setState(() {
                                _selectedRoleId = newId;
                                _lastSyncedRoleId = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(LucideIcons.checkCheck, size: 14),
                    label: const Text('Beri Semua', style: TextStyle(fontSize: 12)),
                    onPressed: () => _grantAllAccess(state.menus),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(LucideIcons.xCircle, size: 14),
                    label: const Text('Cabut Semua', style: TextStyle(fontSize: 12)),
                    onPressed: () => _revokeAllAccess(state.menus),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    onPressed: () => _resetPermissions(selectedRole, state.menus),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: _isSavingPermissions
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.save, size: 15),
                    label: const Text('Simpan Hak Akses', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: _isSavingPermissions ? null : () => _savePermissions(selectedRole, state.menus),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    roleSelector,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  roleSelector,
                  actionButtons,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Hint Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mengatur hak akses menu untuk role "${selectedRole.displayName}". Centang izin yang diizinkan untuk setiap menu dan klik "Simpan Hak Akses".',
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // RBAC Interactive Matrix Table
        if (filteredMenus.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('Tidak ada menu yang sesuai pencarian', style: TextStyle(color: colors.textSecondary)),
            ),
          )
        else
          ResponsiveTableCard(
            minWidth: 860,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: [
                DataColumn(
                  label: Text('Menu Sistem & Route', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lihat (View)', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Pilih semua Lihat',
                        child: Checkbox(
                          value: allCanView,
                          activeColor: AppColors.primary,
                          onChanged: (v) => _toggleColumn('can_view', v ?? false, filteredMenus),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tambah (Create)', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Pilih semua Tambah',
                        child: Checkbox(
                          value: allCanCreate,
                          activeColor: AppColors.primary,
                          onChanged: (v) => _toggleColumn('can_create', v ?? false, filteredMenus),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ubah (Update)', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Pilih semua Ubah',
                        child: Checkbox(
                          value: allCanUpdate,
                          activeColor: AppColors.primary,
                          onChanged: (v) => _toggleColumn('can_update', v ?? false, filteredMenus),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Hapus (Delete)', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Pilih semua Hapus',
                        child: Checkbox(
                          value: allCanDelete,
                          activeColor: AppColors.danger,
                          onChanged: (v) => _toggleColumn('can_delete', v ?? false, filteredMenus),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                DataColumn(
                  label: Text('Status & Aksi Baris', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold)),
                ),
              ],
              rows: filteredMenus.map((m) {
                final p = _workingPermissions[m.id] ?? {
                  'can_view': false,
                  'can_create': false,
                  'can_update': false,
                  'can_delete': false,
                };
                final canView = p['can_view'] == true;
                final canCreate = p['can_create'] == true;
                final canUpdate = p['can_update'] == true;
                final canDelete = p['can_delete'] == true;

                final isAllRow = canView && canCreate && canUpdate && canDelete;
                final isNoneRow = !canView && !canCreate && !canUpdate && !canDelete;
                final isReadOnly = canView && !canCreate && !canUpdate && !canDelete;

                Color badgeBg;
                Color badgeFg;
                String badgeText;

                if (isAllRow) {
                  badgeBg = AppColors.success.withValues(alpha: 0.15);
                  badgeFg = AppColors.success;
                  badgeText = 'Akses Penuh';
                } else if (isNoneRow) {
                  badgeBg = colors.bgSubtle;
                  badgeFg = colors.textMuted;
                  badgeText = 'Tidak Aktif';
                } else if (isReadOnly) {
                  badgeBg = AppColors.info.withValues(alpha: 0.15);
                  badgeFg = AppColors.info;
                  badgeText = 'Hanya Lihat';
                } else {
                  badgeBg = AppColors.warning.withValues(alpha: 0.15);
                  badgeFg = AppColors.warning;
                  badgeText = 'Kustom';
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(6)),
                            child: Text('#${m.order}', style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(m.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text(m.route ?? '-', style: const TextStyle(color: AppColors.primaryLight, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Checkbox(
                        value: canView,
                        activeColor: AppColors.primary,
                        onChanged: (v) => _togglePermission(m.id, 'can_view', v ?? false),
                      ),
                    ),
                    DataCell(
                      Checkbox(
                        value: canCreate,
                        activeColor: AppColors.primary,
                        onChanged: (v) => _togglePermission(m.id, 'can_create', v ?? false),
                      ),
                    ),
                    DataCell(
                      Checkbox(
                        value: canUpdate,
                        activeColor: AppColors.primary,
                        onChanged: (v) => _togglePermission(m.id, 'can_update', v ?? false),
                      ),
                    ),
                    DataCell(
                      Checkbox(
                        value: canDelete,
                        activeColor: AppColors.danger,
                        onChanged: (v) => _togglePermission(m.id, 'can_delete', v ?? false),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(badgeText, style: TextStyle(color: badgeFg, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _toggleRow(m.id, !isAllRow),
                            child: Text(
                              isAllRow ? 'Batal Semua' : 'Beri Semua',
                              style: TextStyle(
                                fontSize: 11,
                                color: isAllRow ? AppColors.danger : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
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
        const SizedBox(height: 16),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.bgSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.save, size: 16, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Perubahan hak akses berlaku segera setelah disimpan.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
                icon: _isSavingPermissions
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.check, size: 15),
                label: Text('Simpan (${selectedRole.displayName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _isSavingPermissions ? null : () => _savePermissions(selectedRole, state.menus),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../data/models/target_header_model.dart';
import '../providers/incentive_scheme_provider.dart';

class IncentiveSchemeScreen extends ConsumerStatefulWidget {
  const IncentiveSchemeScreen({super.key});

  @override
  ConsumerState<IncentiveSchemeScreen> createState() => _IncentiveSchemeScreenState();
}

class _IncentiveSchemeScreenState extends ConsumerState<IncentiveSchemeScreen> {
  int _activeCategoryIndex = 0;
  final List<String> _categories = ['KONSUMSI', 'INDUSTRI', 'SURABAYA'];

  // Simulation test state
  double _simTarget = 15000;
  double _simRealization = 16500;

  // ---------------- Level 1 & Full Setting Form Dialog (Add & Edit) ----------------
  void _showTargetHeaderFormDialog({TargetHeaderModel? header, String? kategori}) {
    _showComprehensiveSettingBuilder(header: header, defaultKategori: kategori);
  }

  void _showSettingDetailDialog(TargetHeaderModel header) {
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 850),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner matching screenshot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF5C6BC0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Detail Insentif Setting #${header.id}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card Info
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                Expanded(
                                  child: Text(
                                    header.nama,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${header.bobot.toInt() == header.bobot ? header.bobot.toInt() : header.bobot}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1F5FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    header.type.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF0288D1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    header.displaySalesType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF5E35B1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal Aktif From:', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        header.displayAktifFrom.isNotEmpty ? header.displayAktifFrom : '01/01/2026',
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal Aktif To:', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        header.displayAktifTo.isNotEmpty ? header.displayAktifTo : '31/12/2026',
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status:', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        header.aktif ? 'Aktif' : 'Non-Aktif',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Daftar Grade & Rincian Bobot (N Grade)
                      Text(
                        'Daftar Grade & Rincian Bobot (${header.grades.length} Grade)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (header.grades.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.bgElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            'Belum ada Grade & Rincian Bobot yang dikonfigurasi.',
                            style: TextStyle(color: colors.textMuted),
                          ),
                        )
                      else
                        ...header.grades.map((grade) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.bgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD6D9F5), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Grade: ${grade.gradeName}',
                                      style: const TextStyle(
                                        color: Color(0xFF5C6BC0),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Aktif',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rentang Target: ${CurrencyFormatter.formatNumber(grade.targetFrom)} - ${CurrencyFormatter.formatNumber(grade.targetTo)}',
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                ),
                                const SizedBox(height: 14),

                                // Rincian Bobot Grade Subtable
                                Container(
                                  decoration: BoxDecoration(
                                    color: colors.bgElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.border),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rincian Bobot Grade',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (grade.gradeBobots.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text('Belum ada rincian bobot tier.', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                        )
                                      else
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FlexColumnWidth(1.5),
                                            2: FlexColumnWidth(1.5),
                                            3: FlexColumnWidth(1.5),
                                            4: FlexColumnWidth(1.8),
                                            5: FlexColumnWidth(1.2),
                                          },
                                          children: [
                                            TableRow(
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: colors.border)),
                                              ),
                                              children: [
                                                _buildTh('Nama', colors),
                                                _buildTh('% From', colors),
                                                _buildTh('% To', colors),
                                                _buildTh('Bobot', colors),
                                                _buildTh('Nominal', colors),
                                                _buildTh('Pengali', colors, align: TextAlign.center),
                                              ],
                                            ),
                                            ...grade.gradeBobots.map((b) {
                                              return TableRow(
                                                children: [
                                                  _buildTd(b.bobotName, colors),
                                                  _buildTd(_formatDisplayNum(b.percentFrom), colors),
                                                  _buildTd(_formatDisplayNum(b.percentTo), colors),
                                                  _buildTd(_formatDisplayNum(b.bobot), colors),
                                                  _buildTd(_formatDisplayNum(b.nominal), colors),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    child: Center(
                                                      child: b.pengali
                                                          ? const Icon(LucideIcons.checkCircle2, color: Color(0xFF4CAF50), size: 18)
                                                          : Icon(LucideIcons.minus, color: colors.textMuted, size: 16),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
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

              // Bottom Actions matching screenshot
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0288D1),
                        side: const BorderSide(color: Color(0xFF0288D1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      icon: const Icon(LucideIcons.copy, size: 16, color: Color(0xFF0288D1)),
                      label: const Text('Duplikat Setting', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(incentiveSchemeProvider.notifier).duplicateTargetHeader(header.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Setting insentif berhasil diduplikasi')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5C6BC0),
                        side: const BorderSide(color: Color(0xFF5C6BC0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      icon: const Icon(LucideIcons.pencil, size: 16, color: Color(0xFF5C6BC0)),
                      label: const Text('Edit Setting', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showComprehensiveSettingBuilder(header: header);
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6BC0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                      ),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComprehensiveSettingBuilder({TargetHeaderModel? header, String? defaultKategori}) {
    final colors = context.colors;
    final isEdit = header != null;
    final currentKategori = header?.kategoriSkema ?? (defaultKategori ?? _categories[_activeCategoryIndex]);

    final namaCtrl = TextEditingController(text: header?.nama ?? 'SELL IN - ASM');
    final bobotCtrl = TextEditingController(
      text: header != null
          ? (header.bobot.toInt() == header.bobot ? header.bobot.toInt().toString() : header.bobot.toString())
          : '50',
    );

    final positions = [
      {'id': '1', 'name': 'Area Sales Manager (ASM)'},
      {'id': '2', 'name': 'Sales Supervisor (SPV)'},
      {'id': '3', 'name': 'Sales Coordinator (COORD)'},
      {'id': '4', 'name': 'Sales Taking Order (TO)'},
      {'id': '5', 'name': 'Sales Canvasing (CANVAS)'},
    ];

    String selectedSalesType = '1';
    if (header != null) {
      final match = positions.firstWhere(
        (p) => p['id'] == header.salesType || p['name']!.toUpperCase().contains(header.salesType.toUpperCase()),
        orElse: () => {'id': header.salesType, 'name': header.salesType},
      );
      selectedSalesType = match['id']!;
    } else {
      if (currentKategori == 'INDUSTRI') selectedSalesType = '2';
      if (currentKategori == 'SURABAYA') selectedSalesType = '3';
    }

    String selectedType = header?.type ?? (currentKategori == 'SURABAYA' ? 'Sell-Out' : 'Sell-In');
    String selectedKategori = currentKategori;
    bool isAktif = header?.aktif ?? true;

    final initialFrom = header != null ? header.formattedAktifFrom : '2026-01-01';
    final initialTo = header != null ? header.formattedAktifTo : '2026-12-31';

    final aktifFromCtrl = TextEditingController(text: initialFrom);
    final aktifToCtrl = TextEditingController(text: initialTo);

    // Initialize drafts
    List<_GradeDraft> drafts = [];
    if (header != null && header.grades.isNotEmpty) {
      drafts = header.grades.map((g) {
        return _GradeDraft(
          name: g.gradeName,
          from: g.targetFrom,
          to: g.targetTo,
          bobots: g.gradeBobots.map((b) => _BobotDraft(
            name: b.bobotName,
            pFrom: b.percentFrom,
            pTo: b.percentTo,
            bobot: b.pengali ? b.bobot : 0,
            nominal: !b.pengali ? b.nominal : 0,
            pengali: b.pengali,
          )).toList(),
        );
      }).toList();
    } else {
      // Default starter matching screenshot (Grade 1 with 3 tiers)
      drafts = [
        _GradeDraft(
          name: '1',
          from: 2000,
          to: 15000,
          bobots: [
            _BobotDraft(name: '80%', pFrom: 80, pTo: 89.9, bobot: 1.25, nominal: 0, pengali: true),
            _BobotDraft(name: '90%', pFrom: 90, pTo: 99.9, bobot: 2.0, nominal: 0, pengali: true),
            _BobotDraft(name: '100%', pFrom: 100, pTo: 500, bobot: 3.0, nominal: 0, pengali: true),
          ],
        ),
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate(TextEditingController ctrl) async {
            DateTime initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final y = picked.year.toString().padLeft(4, '0');
              final m = picked.month.toString().padLeft(2, '0');
              final d = picked.day.toString().padLeft(2, '0');
              setDialogState(() {
                ctrl.text = '$y-$m-$d';
              });
            }
          }

          return Dialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920, maxHeight: 850),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C6BC0),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(isEdit ? LucideIcons.fileEdit : LucideIcons.plusCircle, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Setting Insentif #${header.id}' : 'Tambah Setting Insentif Baru',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

                  // Scrollable Form Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Level 1 Section Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('HEADER', style: TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Text('Informasi Skema Insentif', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 1: Nama & Kategori
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: namaCtrl,
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: const InputDecoration(labelText: 'Nama Skema Setting (e.g. SELL IN - ASM) *'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedKategori,
                                  dropdownColor: colors.bgElevated,
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                  decoration: const InputDecoration(labelText: 'Kategori Skema *'),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedKategori = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 2: Sales Type, Type, Bobot
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedSalesType,
                                  isExpanded: true,
                                  dropdownColor: colors.bgElevated,
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                  decoration: const InputDecoration(labelText: 'Target Posisi (Sales Type) *'),
                                  items: positions.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name']!, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedSalesType = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedType,
                                  isExpanded: true,
                                  dropdownColor: colors.bgElevated,
                                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                  decoration: const InputDecoration(labelText: 'Jenis Program *'),
                                  items: const [
                                    DropdownMenuItem(value: 'Sell-In', child: Text('Sell-In')),
                                    DropdownMenuItem(value: 'Sell-Out', child: Text('Sell-Out')),
                                    DropdownMenuItem(value: 'Active Outlet', child: Text('Active Outlet (AO)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedType = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: bobotCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: const InputDecoration(labelText: 'Bobot', suffixText: '%'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 3: Tanggal From, To & Status Aktif
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: aktifFromCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(aktifFromCtrl),
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Tanggal Aktif From',
                                    hintText: 'YYYY-MM-DD',
                                    suffixIcon: IconButton(icon: const Icon(LucideIcons.calendar, size: 18), onPressed: () => pickDate(aktifFromCtrl)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: aktifToCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(aktifToCtrl),
                                  style: TextStyle(color: colors.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Tanggal Aktif To',
                                    hintText: 'YYYY-MM-DD',
                                    suffixIcon: IconButton(icon: const Icon(LucideIcons.calendar, size: 18), onPressed: () => pickDate(aktifToCtrl)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  Switch(
                                    value: isAktif,
                                    activeThumbColor: AppColors.success,
                                    onChanged: (val) => setDialogState(() => isAktif = val),
                                  ),
                                  Text(isAktif ? 'Status Aktif' : 'Non-Aktif', style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Divider(color: colors.border),
                          const SizedBox(height: 12),

                          // Section 2: Daftar Grade & Rincian Bobot (Dynamic)
                          Row(
                            children: [
                              Text(
                                'Daftar Grade & Rincian Bobot (${drafts.length} Grade)',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C6BC0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 15),
                                label: const Text('Tambah Grade'),
                                onPressed: () {
                                  setDialogState(() {
                                    drafts.add(
                                      _GradeDraft(
                                        name: '${drafts.length + 1}',
                                        from: 0,
                                        to: 0,
                                        bobots: [
                                          _BobotDraft(name: '100%', pFrom: 100, pTo: 120, bobot: 2.5, nominal: 0, pengali: true),
                                        ],
                                      ),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (drafts.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.bgElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text('Belum ada Grade. Klik "Tambah Grade" di atas.', style: TextStyle(color: colors.textMuted)),
                            )
                          else
                            ...drafts.asMap().entries.map((entry) {
                              final gIdx = entry.key;
                              final gradeDraft = entry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD6D9F5), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Grade Header inputs
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 140,
                                          child: TextField(
                                            controller: gradeDraft.nameCtrl,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            decoration: const InputDecoration(labelText: 'Nama Grade (e.g. 1)'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: gradeDraft.fromCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'Rentang Target Dari (Kg/Unit)'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: gradeDraft.toCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: 'Rentang Target Sampai (Kg/Unit)'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 18),
                                          tooltip: 'Hapus Grade',
                                          onPressed: () {
                                            setDialogState(() {
                                              drafts.removeAt(gIdx);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Rincian Bobot Table Box
                                    Container(
                                      decoration: BoxDecoration(
                                        color: colors.bgElevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: colors.border),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('Rincian Bobot Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
                                              const Spacer(),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                                icon: const Icon(LucideIcons.plus, size: 14, color: Color(0xFF5C6BC0)),
                                                label: const Text('Tambah Tier Bobot', style: TextStyle(color: Color(0xFF5C6BC0), fontSize: 12, fontWeight: FontWeight.w600)),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    gradeDraft.bobots.add(
                                                      _BobotDraft(name: 'Tier Baru', pFrom: 100, pTo: 120, bobot: 0, nominal: 0, pengali: true),
                                                    );
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          if (gradeDraft.bobots.isEmpty)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              child: Text('Belum ada tier bobot. Klik "+ Tambah Tier Bobot"', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                                            )
                                          else
                                            ...gradeDraft.bobots.asMap().entries.map((bEntry) {
                                              final bIdx = bEntry.key;
                                              final bDraft = bEntry.value;

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextField(
                                                        controller: bDraft.nameCtrl,
                                                        decoration: const InputDecoration(labelText: 'Nama (e.g. 80%)', isDense: true),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextField(
                                                        controller: bDraft.pFromCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(labelText: '% From', isDense: true),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextField(
                                                        controller: bDraft.pToCtrl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(labelText: '% To', isDense: true),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextField(
                                                        controller: bDraft.bobotCtrl,
                                                        enabled: bDraft.pengali,
                                                        keyboardType: TextInputType.number,
                                                        style: TextStyle(
                                                          color: bDraft.pengali ? colors.textPrimary : colors.textMuted.withValues(alpha: 0.5),
                                                        ),
                                                        decoration: InputDecoration(
                                                          labelText: 'Bobot',
                                                          isDense: true,
                                                          fillColor: bDraft.pengali ? null : colors.border.withValues(alpha: 0.15),
                                                          filled: !bDraft.pengali,
                                                          hintText: bDraft.pengali ? null : '-',
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextField(
                                                        controller: bDraft.nominalCtrl,
                                                        enabled: !bDraft.pengali,
                                                        keyboardType: TextInputType.number,
                                                        style: TextStyle(
                                                          color: !bDraft.pengali ? colors.textPrimary : colors.textMuted.withValues(alpha: 0.5),
                                                        ),
                                                        decoration: InputDecoration(
                                                          labelText: 'Nominal',
                                                          isDense: true,
                                                          fillColor: !bDraft.pengali ? null : colors.border.withValues(alpha: 0.15),
                                                          filled: bDraft.pengali,
                                                          hintText: !bDraft.pengali ? null : '-',
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Text('Pengali', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                        Checkbox(
                                                          value: bDraft.pengali,
                                                          activeColor: const Color(0xFF4CAF50),
                                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          onChanged: (val) {
                                                            setDialogState(() {
                                                              bDraft.pengali = val ?? false;
                                                              if (bDraft.pengali) {
                                                                bDraft.nominalCtrl.text = '0';
                                                              } else {
                                                                bDraft.bobotCtrl.text = '0';
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 16),
                                                      tooltip: 'Hapus Tier',
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          gradeDraft.bobots.removeAt(bIdx);
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

                  // Bottom Action bar
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
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C6BC0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: () async {
                            final gradesPayload = drafts.map((g) {
                              return {
                                'grade_name': g.nameCtrl.text.trim().isNotEmpty ? g.nameCtrl.text.trim() : 'Grade',
                                'target_from': double.tryParse(g.fromCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                'target_to': double.tryParse(g.toCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                'bobots': g.bobots.map((b) => {
                                  'bobot_name': b.nameCtrl.text.trim().isNotEmpty ? b.nameCtrl.text.trim() : 'Tier',
                                  'percent_from': double.tryParse(b.pFromCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                  'percent_to': double.tryParse(b.pToCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                  'pengali': b.pengali,
                                  'bobot': b.pengali ? (double.tryParse(b.bobotCtrl.text.replaceAll(',', '.')) ?? 0.0) : 0.0,
                                  'nominal': !b.pengali ? (double.tryParse(b.nominalCtrl.text.replaceAll(',', '.')) ?? 0.0) : 0.0,
                                }).toList(),
                              };
                            }).toList();

                            final data = {
                              'nama': namaCtrl.text.trim(),
                              'kategori_skema': selectedKategori,
                              'sales_type': selectedSalesType,
                              'type': selectedType,
                              'bobot': double.tryParse(bobotCtrl.text) ?? 100.0,
                              'aktif_from': aktifFromCtrl.text.replaceAll('-', '').trim(),
                              'aktif_to': aktifToCtrl.text.replaceAll('-', '').trim(),
                              'aktif': isAktif,
                              'grades': gradesPayload,
                            };

                            Navigator.pop(ctx);
                            await ref.read(incentiveSchemeProvider.notifier).saveTargetHeader(data, id: header?.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isEdit ? 'Setting insentif berhasil diperbarui' : 'Setting insentif berhasil dibuat')),
                              );
                            }
                          },
                          child: Text(isEdit ? 'Simpan Perubahan' : 'Buat Setting Insentif Lengkap', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTh(String text, AppThemeColors colors, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTd(String text, AppThemeColors colors, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDisplayNum(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toString().replaceAll('.', ',');
  }

  Widget _buildMetaTag(IconData icon, String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.colors.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Grade Dialog (Add & Edit) ----------------
  void _showGradeFormDialog({required TargetHeaderModel header, GradeModel? grade}) {
    final colors = context.colors;
    final isEdit = grade != null;
    final gradeNameCtrl = TextEditingController(text: grade?.gradeName ?? 'Grade Platinum');
    final fromCtrl = TextEditingController(text: grade != null ? (grade.targetFrom == grade.targetFrom.roundToDouble() ? grade.targetFrom.toInt().toString() : grade.targetFrom.toString()) : '10000');
    final toCtrl = TextEditingController(text: grade != null ? (grade.targetTo == grade.targetTo.roundToDouble() ? grade.targetTo.toInt().toString() : grade.targetTo.toString()) : '50000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
        title: Row(
          children: [
            Icon(isEdit ? LucideIcons.fileEdit : LucideIcons.plusCircle, color: AppColors.info, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEdit ? 'Edit Grade: ${grade.gradeName}' : 'Tambah Grade ke ${header.nama}',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gradeNameCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Label Grade (Contoh: Grade 1, Grade Platinum)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fromCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Target Kuota Dari (Kg / Unit)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Target Kuota Sampai (Kg / Unit)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.info, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(incentiveSchemeProvider.notifier).saveGrade(
                    header.id,
                    gradeNameCtrl.text.trim(),
                    double.tryParse(fromCtrl.text) ?? 0,
                    double.tryParse(toCtrl.text) ?? 0,
                    id: grade?.id,
                  );
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Grade'),
          ),
        ],
      ),
    );
  }

  // ---------------- Tier Dialog (Add & Edit) ----------------
  void _showTierFormDialog({required GradeModel grade, GradeBobotModel? tier}) {
    final colors = context.colors;
    final isEdit = tier != null;
    final tierNameCtrl = TextEditingController(text: tier?.bobotName ?? 'Tier 100% - 120%');
    final pFromCtrl = TextEditingController(text: tier != null ? tier.percentFrom.toString() : '100.0');
    final pToCtrl = TextEditingController(text: tier != null ? tier.percentTo.toString() : '120.0');
    bool isRateBased = tier?.pengali ?? true;
    final rateCtrl = TextEditingController(text: tier != null ? tier.bobot.toString() : '2.5');
    final lumpSumCtrl = TextEditingController(text: tier != null ? (tier.nominal == tier.nominal.roundToDouble() ? tier.nominal.toInt().toString() : tier.nominal.toString()) : '1500000');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.bgDialog,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border)),
            title: Row(
              children: [
                Icon(isEdit ? LucideIcons.fileEdit : LucideIcons.plusCircle, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Tier Bobot: ${tier.bobotName}' : 'Tambah Tier Bobot ke Grade ${grade.gradeName}',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tierNameCtrl, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Nama Tier (Contoh: Tier 100%)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: pFromCtrl, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: '% Dari'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: pToCtrl, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: '% Sampai'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: isRateBased,
                    dropdownColor: colors.bgElevated,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Model Rumus Pengali'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Tarif per Satuan (Rate-based / Kg)')),
                      DropdownMenuItem(value: false, child: Text('Nominal Tetap (Lump-sum / Flat)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => isRateBased = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isRateBased)
                    TextField(controller: rateCtrl, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Nilai Pengali per Unit Realisasi (Rp / Kg)'))
                  else
                    TextField(controller: lumpSumCtrl, keyboardType: TextInputType.number, style: TextStyle(color: colors.textPrimary), decoration: const InputDecoration(labelText: 'Nominal Flat Bonus (Rp)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: colors.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  ref.read(incentiveSchemeProvider.notifier).saveGradeBobot(
                        grade.idGrade,
                        tierNameCtrl.text.trim(),
                        double.tryParse(pFromCtrl.text) ?? 0,
                        double.tryParse(pToCtrl.text) ?? 0,
                        isRateBased,
                        isRateBased ? (double.tryParse(rateCtrl.text) ?? 0) : 0,
                        !isRateBased ? (double.tryParse(lumpSumCtrl.text) ?? 0) : 0,
                        id: tier?.id,
                      );
                  Navigator.pop(ctx);
                },
                child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Tier Bobot'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incentiveSchemeProvider);
    final selectedCategory = _categories[_activeCategoryIndex];

    final matchingHeaders = state.targetHeaders.where((h) {
      return (h.kategoriSkema?.toUpperCase() == selectedCategory) ||
          (selectedCategory == 'KONSUMSI' && h.kategoriSkema == null);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setting Perhitungan Insentif',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Konfigurasi Skema Target Insentif, Grade Kuota, dan Tier Bobot Komisi',
                    style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
                  ),
                ],
              );

              final actionButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Tambah Setting Insentif', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showComprehensiveSettingBuilder(defaultKategori: selectedCategory),
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
                  actionButton,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Category Selector Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
                boxShadow: context.colors.cardShadows,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_categories.length, (index) {
                  final cat = _categories[index];
                  final isSelected = _activeCategoryIndex == index;
                  return InkWell(
                    onTap: () => setState(() => _activeCategoryIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat == 'KONSUMSI' ? '1. Skema Distributor (Konsumsi)' : (cat == 'INDUSTRI' ? '2. Skema Industri' : '3. Skema Surabaya'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : context.colors.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3-Level Display Cards for the category
          if (matchingHeaders.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
                boxShadow: context.colors.cardShadows,
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.sliders, size: 40, color: context.colors.textMuted),
                  const SizedBox(height: 12),
                  Text('Belum Ada Target Header untuk Skema $selectedCategory', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showTargetHeaderFormDialog(kategori: selectedCategory),
                    child: const Text('Buat Skema Header Pertama'),
                  ),
                ],
              ),
            )
          else
            ...matchingHeaders.map((header) => _build3LevelCard(header)),

          const SizedBox(height: 28),

          // Real-time calculation simulation sandbox
          _buildSimulatorCard(),
        ],
      ),
    );
  }

  Widget _build3LevelCard(TargetHeaderModel header) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.bgElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 920;

                final headerInfo = InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showSettingDetailDialog(header),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.award, size: 18, color: Color(0xFF5C6BC0)),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              header.nama,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: header.aktif
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              header.aktif ? 'Aktif' : 'Non-Aktif',
                              style: TextStyle(
                                color: header.aktif ? AppColors.success : AppColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildMetaTag(LucideIcons.user, header.displaySalesType, context),
                          _buildMetaTag(LucideIcons.tag, header.type, context),
                          _buildMetaTag(LucideIcons.pieChart, 'Bobot: ${_formatDisplayNum(header.bobot)}%', context),
                          _buildMetaTag(LucideIcons.calendar, '${header.formattedAktifFrom} s/d ${header.formattedAktifTo}', context),
                        ],
                      ),
                    ],
                  ),
                );

                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5C6BC0),
                        side: const BorderSide(color: Color(0xFF5C6BC0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      ),
                      icon: const Icon(LucideIcons.info, size: 14, color: Color(0xFF5C6BC0)),
                      label: const Text('Detail', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: () => _showSettingDetailDialog(header),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0288D1),
                        side: const BorderSide(color: Color(0xFF0288D1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      ),
                      icon: const Icon(LucideIcons.copy, size: 14, color: Color(0xFF0288D1)),
                      label: const Text('Duplikat', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        await ref.read(incentiveSchemeProvider.notifier).duplicateTargetHeader(header.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Setting insentif berhasil diduplikasi')),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.textPrimary,
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      ),
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: () => _showComprehensiveSettingBuilder(header: header),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      tooltip: 'Hapus Target Header',
                      onPressed: () async {
                        final confirm = await showConfirmDeleteDialog(
                          context: context,
                          title: 'Hapus Target Header',
                          message: 'Apakah Anda yakin ingin menghapus skema target "${header.nama}" beserta seluruh Grade dan Tier di dalamnya?',
                        );
                        if (confirm == true) {
                          ref.read(incentiveSchemeProvider.notifier).deleteTargetHeader(header.id);
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6BC0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 15),
                      label: const Text('Tambah Grade', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () => _showGradeFormDialog(header: header),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerInfo,
                      const SizedBox(height: 14),
                      actions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerInfo),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
              },
            ),
          ),

          // Grades and Tiers
          Padding(
            padding: const EdgeInsets.all(20),
            child: header.grades.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Text('Belum ada Grade. Klik "Tambah Grade" di atas.', style: TextStyle(color: context.colors.textMuted)),
                  )
                : Column(
                    children: header.grades.map((grade) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colors.bgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Grade Header
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 620;
                                final gradeInfo = Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(LucideIcons.layers, size: 14, color: Color(0xFF5C6BC0)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Grade ${grade.gradeName}',
                                            style: const TextStyle(
                                              color: Color(0xFF5C6BC0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Target: ${CurrencyFormatter.formatNumber(grade.targetFrom)} – ${CurrencyFormatter.formatNumber(grade.targetTo)} Kg',
                                        style: TextStyle(
                                          color: context.colors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                                final gradeActions = Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: context.colors.textPrimary,
                                        side: BorderSide(color: context.colors.border),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(LucideIcons.pencil, size: 12),
                                      label: const Text('Edit Grade', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showGradeFormDialog(header: header, grade: grade),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                                      tooltip: 'Hapus Grade',
                                      onPressed: () async {
                                        final confirm = await showConfirmDeleteDialog(
                                          context: context,
                                          title: 'Hapus Grade',
                                          message: 'Apakah Anda yakin ingin menghapus "${grade.gradeName}"?',
                                        );
                                        if (confirm == true) {
                                          ref.read(incentiveSchemeProvider.notifier).deleteGrade(grade.id);
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF5C6BC0),
                                        side: const BorderSide(color: Color(0xFF5C6BC0)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(LucideIcons.plus, size: 13),
                                      label: const Text('Tambah Tier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      onPressed: () => _showTierFormDialog(grade: grade),
                                    ),
                                  ],
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      gradeInfo,
                                      const SizedBox(height: 10),
                                      gradeActions,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: gradeInfo),
                                    const SizedBox(width: 10),
                                    gradeActions,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Grade Bobots Tier Table
                            if (grade.gradeBobots.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('Belum ada Tier Grade Bobot. Klik "Tambah Tier" di atas.', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: context.colors.bgCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.colors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.6),
                                    1: FlexColumnWidth(1.6),
                                    2: FlexColumnWidth(1.8),
                                    3: FlexColumnWidth(1.8),
                                    4: FlexColumnWidth(1.8),
                                    5: FixedColumnWidth(76),
                                  },
                                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: context.colors.bgTableHead,
                                        border: Border(bottom: BorderSide(color: context.colors.border)),
                                      ),
                                      children: [
                                        _buildTh('Tier', context.colors),
                                        _buildTh('Pencapaian', context.colors),
                                        _buildTh('Model Komisi', context.colors),
                                        _buildTh('Tarif / Satuan', context.colors),
                                        _buildTh('Nominal Tetap', context.colors),
                                        _buildTh('Aksi', context.colors, align: TextAlign.center),
                                      ],
                                    ),
                                    ...grade.gradeBobots.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final b = entry.value;
                                      final isLast = idx == grade.gradeBobots.length - 1;
                                      return TableRow(
                                        decoration: BoxDecoration(
                                          border: isLast ? null : Border(bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5))),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            child: Text(
                                              b.bobotName,
                                              style: TextStyle(
                                                color: context.colors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            child: Text(
                                              '${_formatDisplayNum(b.percentFrom)}% – ${_formatDisplayNum(b.percentTo)}%',
                                              style: const TextStyle(
                                                color: AppColors.warning,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: b.pengali ? const Color(0xFFE1F5FE) : const Color(0xFFE8F5E9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  b.pengali ? 'Rate per Satuan' : 'Nominal Flat',
                                                  style: TextStyle(
                                                    color: b.pengali ? const Color(0xFF0288D1) : const Color(0xFF2E7D32),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            child: Text(
                                              b.pengali ? 'Rp ${_formatDisplayNum(b.bobot)} / kg' : '—',
                                              style: TextStyle(
                                                color: b.pengali ? context.colors.textPrimary : context.colors.textMuted,
                                                fontWeight: b.pengali ? FontWeight.w600 : FontWeight.normal,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            child: Text(
                                              !b.pengali ? CurrencyFormatter.formatRupiah(b.nominal) : '—',
                                              style: TextStyle(
                                                color: !b.pengali ? AppColors.success : context.colors.textMuted,
                                                fontWeight: !b.pengali ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(LucideIcons.pencil, size: 15, color: Color(0xFF5C6BC0)),
                                                  tooltip: 'Edit Tier',
                                                  padding: const EdgeInsets.all(4),
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _showTierFormDialog(grade: grade, tier: b),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                                                  tooltip: 'Hapus Tier',
                                                  padding: const EdgeInsets.all(4),
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () async {
                                                    final confirm = await showConfirmDeleteDialog(
                                                      context: context,
                                                      title: 'Hapus Tier Bobot',
                                                      message: 'Apakah Anda yakin ingin menghapus "${b.bobotName}"?',
                                                    );
                                                    if (confirm == true) {
                                                      ref.read(incentiveSchemeProvider.notifier).deleteGradeBobot(b.id);
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorCard() {
    final achievement = _simTarget > 0 ? (_simRealization / _simTarget) * 100 : 0.0;
    double reward = 0;
    String matchedRule = 'Tidak ada tier yang cocok';

    // Simulation calculation using specification logic:
    // Rate-based with capped realization at 120%
    if (achievement >= 120) {
      double capped = _simTarget * 1.2;
      reward = 3.5 * capped * (100 / 100);
      matchedRule = 'Tier > 120%: Capped Max Realisasi ($capped Kg) x Rp 3.5 / Kg';
    } else if (achievement >= 100) {
      reward = 3.5 * _simRealization * (100 / 100);
      matchedRule = 'Tier 100% - 120%: Realisasi ($_simRealization Kg) x Rp 3.5 / Kg';
    } else if (achievement >= 80) {
      reward = 2.0 * _simRealization * (100 / 100);
      matchedRule = 'Tier 80% - 99.9%: Realisasi ($_simRealization Kg) x Rp 2.0 / Kg';
    } else {
      reward = 0;
      matchedRule = 'Di bawah 80%: Tidak berhak insentif';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.cpu, color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Text('Simulasi Real-time Engine Insentif', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mencocokkan kuota target terhadap Grade, mengevaluasi pencapaian % ke Tier Bobot, dan menghitung reward akhir.',
            style: GoogleFonts.inter(fontSize: 12.5, color: context.colors.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target Kuota (Kg)', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _simTarget.toInt().toString(),
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(filled: true, fillColor: context.colors.bgElevated),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() => _simTarget = double.tryParse(val) ?? 1),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Realisasi Penjualan (Kg)', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _simRealization.toInt().toString(),
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(filled: true, fillColor: context.colors.bgElevated),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() => _simRealization = double.tryParse(val) ?? 0),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: context.colors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pencapaian: ${CurrencyFormatter.formatPercent(achievement)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: achievement >= 100 ? AppColors.success : AppColors.warning)),
                    const SizedBox(height: 3),
                    Text('Aturan: $matchedRule', style: TextStyle(color: context.colors.textMuted, fontSize: 11.5)),
                    const SizedBox(height: 6),
                    Text('Total Reward: ${CurrencyFormatter.formatRupiah(reward)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradeDraft {
  final TextEditingController nameCtrl;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final List<_BobotDraft> bobots;

  _GradeDraft({
    required String name,
    required double from,
    required double to,
    required this.bobots,
  })  : nameCtrl = TextEditingController(text: name),
        fromCtrl = TextEditingController(text: from == from.roundToDouble() ? from.toInt().toString() : from.toString()),
        toCtrl = TextEditingController(text: to == to.roundToDouble() ? to.toInt().toString() : to.toString());
}

class _BobotDraft {
  final TextEditingController nameCtrl;
  final TextEditingController pFromCtrl;
  final TextEditingController pToCtrl;
  final TextEditingController bobotCtrl;
  final TextEditingController nominalCtrl;
  bool pengali;

  _BobotDraft({
    required String name,
    required double pFrom,
    required double pTo,
    required double bobot,
    required double nominal,
    required this.pengali,
  })  : nameCtrl = TextEditingController(text: name),
        pFromCtrl = TextEditingController(text: pFrom == pFrom.roundToDouble() ? pFrom.toInt().toString() : pFrom.toString()),
        pToCtrl = TextEditingController(text: pTo == pTo.roundToDouble() ? pTo.toInt().toString() : pTo.toString()),
        bobotCtrl = TextEditingController(text: bobot == bobot.roundToDouble() ? bobot.toInt().toString() : bobot.toString()),
        nominalCtrl = TextEditingController(text: nominal == nominal.roundToDouble() ? nominal.toInt().toString() : nominal.toString());
}

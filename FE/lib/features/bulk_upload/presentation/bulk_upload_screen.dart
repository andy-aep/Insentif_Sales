import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/upload_batch_model.dart';
import '../providers/bulk_upload_provider.dart';

class BulkUploadScreen extends ConsumerStatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  ConsumerState<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends ConsumerState<BulkUploadScreen> {
  final Map<String, String> _entityOptions = {
    'sellout_distributor': 'Transaksi: Sell-Out Distributor',
    'distributor': 'Master: Distributor, Depo & Area',
    'master_target_distributor': 'Master: Target Distributor',
  };

  final Map<String, List<Map<String, String>>> _entityColumnGuides = {
    'sellout_distributor': [
      {'col': 'depo_code', 'req': 'WAJIB', 'ex': 'DP01', 'desc': 'Kode Depo sesuai Master'},
      {'col': 'brand_code', 'req': 'WAJIB', 'ex': 'BRD01', 'desc': 'Kode Brand sesuai Master'},
      {'col': 'period', 'req': 'WAJIB', 'ex': '202610', 'desc': 'Periode YYYYMM (6 digit)'},
      {'col': 'volume_kg', 'req': 'WAJIB', 'ex': '12000', 'desc': 'Volume Sell-Out (Kg)'},
      {'col': 'active_outlet_count', 'req': 'WAJIB', 'ex': '45', 'desc': 'Jumlah Active Outlet (AO)'},
    ],
    'distributor': [
      {'col': 'region_code', 'req': 'OPSIONAL', 'ex': 'REG01', 'desc': 'Kode Region (REG01, REG02, REG03)'},
      {'col': 'distributor_code', 'req': 'WAJIB', 'ex': 'DST01', 'desc': 'Kode Distributor (ulangi jika banyak Depo)'},
      {'col': 'distributor_name', 'req': 'WAJIB', 'ex': 'PT Sumber Rejeki Utama', 'desc': 'Nama Perusahaan Distributor'},
      {'col': 'depo_code', 'req': 'WAJIB', 'ex': 'DP01', 'desc': 'Kode Depo berelasi ke distributor_code'},
      {'col': 'depo_name', 'req': 'WAJIB', 'ex': 'Depo Surabaya Timur', 'desc': 'Nama Cabang Depo'},
      {'col': 'area_code', 'req': 'WAJIB', 'ex': 'AR01', 'desc': 'Kode Area berelasi ke depo_code'},
      {'col': 'area_name', 'req': 'WAJIB', 'ex': 'Rungkut & Sekitarnya', 'desc': 'Nama Area Operasional'},
    ],
    'master_target_distributor': [
      {'col': 'period', 'req': 'WAJIB', 'ex': '202610 / 2026', 'desc': 'Periode YYYYMM (atau YYYY untuk 12 bulan)'},
      {'col': 'distributor_code', 'req': 'WAJIB', 'ex': 'DST01', 'desc': 'Kode Distributor sesuai Master'},
      {'col': 'depo_code', 'req': 'WAJIB', 'ex': 'DP01', 'desc': 'Kode Depo sesuai Master'},
      {'col': 'area_code', 'req': 'OPSIONAL', 'ex': 'AR01', 'desc': 'Kosong = Level Depo (ASM), Isi = Level Area (SPV)'},
      {'col': 'brand_code', 'req': 'WAJIB', 'ex': 'BRD01', 'desc': 'Kode Brand produk'},
      {'col': 'metrik_target', 'req': 'WAJIB', 'ex': 'SELL_OUT', 'desc': 'SELL_OUT, SELL_IN, atau AO'},
      {'col': 'target_quota', 'req': 'WAJIB', 'ex': '3000', 'desc': 'Besaran kuota target (Kg/Box/Toko)'},
      {'col': 'target_outlet', 'req': 'OPSIONAL', 'ex': '50', 'desc': 'Target jumlah toko Active Outlet (AO)'},
      {'col': 'username', 'req': 'OPSIONAL', 'ex': 'budi_asm', 'desc': 'Username sales (otomatis jika dikosongkan)'},
    ],
  };

  String _formatEntityLabel(String rawEntity) {
    if (_entityOptions.containsKey(rawEntity)) return _entityOptions[rawEntity]!;
    final mapLegacy = {
      'sellin_distributor': 'Transaksi: Sell-In Distributor',
      'sell_in_distributor': 'Transaksi: Sell-In Distributor',
      'sell_out_distributor': 'Transaksi: Sell-Out Distributor',
      'sellin_industri': 'Transaksi: Sell-In Industri',
      'sell_in_industri': 'Transaksi: Sell-In Industri',
      'sellout_sales_surabaya': 'Transaksi: Sell-Out Surabaya',
      'sell_out_surabaya': 'Transaksi: Sell-Out Surabaya',
      'distributors': 'Master: Distributor, Depo & Area',
      'depo': 'Master: Depo',
      'depos': 'Master: Depo',
      'area': 'Master: Area',
      'areas': 'Master: Area',
      'master_targets': 'Master: Target Distributor',
      'target_distributor': 'Master: Target Distributor',
    };
    return mapLegacy[rawEntity] ?? rawEntity;
  }

  bool _isRollbackSupported(String rawEntity) {
    return const {
      'sellin_distributor',
      'sellout_distributor',
      'sellin_industri',
      'sellout_sales_surabaya',
      'sell_in_distributor',
      'sell_out_distributor',
      'sell_in_industri',
      'sell_out_surabaya',
    }.contains(rawEntity);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        ref.read(bulkUploadProvider.notifier).setFile(
              file.name,
              file.size,
              file.bytes!,
            );
      }
    }
  }

  void _showRollbackConfirmation(UploadBatchModel batch) {
    final colors = context.colors;
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
            const Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 22),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Rollback Batch',
              style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan (rollback) seluruh transaksi dari batch ini?',
              style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.bgSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID Batch: ${batch.id}', style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Entitas: ${batch.entity}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  Text('Total Baris: ${batch.totalRows} baris (${batch.successRows} berhasil)', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Perhatian: Seluruh record yang telah tersimpan dari file ini akan dihapus dari database secara permanen.',
              style: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bulkUploadProvider.notifier).rollback(batch.id);
            },
            child: Text('Ya, Rollback', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final colors = context.colors;
    Color bg;
    Color text;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESS':
        bg = AppColors.success.withValues(alpha: 0.15);
        text = const Color(0xFF34D399);
        icon = LucideIcons.checkCircle2;
        break;
      case 'ROLLED_BACK':
        bg = AppColors.danger.withValues(alpha: 0.15);
        text = const Color(0xFFF87171);
        icon = LucideIcons.rotateCcw;
        break;
      case 'PROCESSING':
        bg = AppColors.warning.withValues(alpha: 0.15);
        text = const Color(0xFFFBBF24);
        icon = LucideIcons.clock;
        break;
      default:
        bg = colors.bgSubtle;
        text = colors.textSecondary;
        icon = LucideIcons.helpCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(color: text, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(bulkUploadProvider);
    final notifier = ref.read(bulkUploadProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Upload & Rollback Center',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unggah data transaksi massal spreadsheet dan manajemen pemulihan batch aman',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.refreshCw, color: colors.textSecondary),
                tooltip: 'Segarkan Riwayat Batch',
                onPressed: () => notifier.fetchHistory(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Alert Notifications
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (state.successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.successMessage!,
                      style: GoogleFonts.inter(color: const Color(0xFF6EE7B7), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Upload Card Container
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '1. Pilih Entitas Data yang Akan Diunggah',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: state.isDownloadingTemplate
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.download, size: 15),
                      label: Text(
                        state.isDownloadingTemplate
                            ? 'Mengunduh...'
                            : 'Unduh Template Excel (.xlsx)',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: state.isDownloadingTemplate ? null : () => notifier.downloadTemplate(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderMuted),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _entityOptions.containsKey(state.selectedEntity)
                          ? state.selectedEntity
                          : _entityOptions.keys.first,
                      dropdownColor: colors.bgCard,
                      isExpanded: true,
                      style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14),
                      icon: Icon(LucideIcons.chevronDown, color: colors.textSecondary),
                      items: _entityOptions.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.setEntity(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Panduan Kolom Modul Terpilih
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.bgSubtle.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.bookOpen, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Panduan Kolom Excel — ${_formatEntityLabel(state.selectedEntity)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'Sheet 1: Data Upload • Sheet 2: Kode Referensi Master',
                            style: GoogleFonts.inter(fontSize: 11.5, color: colors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (_entityColumnGuides[state.selectedEntity] ?? []).map((col) {
                          final isReq = col['req'] == 'WAJIB';
                          return Container(
                            width: 230,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.bgCard,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.borderMuted),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        col['col']!,
                                        style: GoogleFonts.sourceCodePro(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isReq ? AppColors.warning : AppColors.info).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        col['req']!,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isReq ? AppColors.warning : AppColors.info,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  col['desc']!,
                                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contoh: ${col['ex']}',
                                  style: GoogleFonts.sourceCodePro(fontSize: 10.5, color: colors.textMuted),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  '2. Dropzone File Spreadsheet',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // File Dropzone Box
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: colors.bgSubtle.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: state.selectedFileName != null ? AppColors.primary : colors.borderMuted,
                        width: 1.8,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.fileSpreadsheet, size: 36, color: AppColors.primaryLight),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          state.selectedFileName ?? 'Klik atau Seret file Excel ke sini',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: state.selectedFileName != null ? colors.textPrimary : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.selectedFileSize != null
                              ? 'Ukuran: ${_formatFileSize(state.selectedFileSize!)} • Format Didukung: .xlsx, .xls, .csv'
                              : 'Format didukung: Microsoft Excel (.xlsx, .xls) atau CSV (Max 25MB)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Bar if File Selected
                if (state.selectedFileName != null) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.border),
                        ),
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: const Text('Batal Pilih'),
                        onPressed: () => notifier.clearSelectedFile(),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: state.isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(LucideIcons.uploadCloud, size: 16),
                        label: Text(state.isUploading ? 'Mengunggah & Validasi...' : 'Upload & Proses Batch'),
                        onPressed: state.isUploading ? null : () => notifier.upload(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Riwayat Batch & Rollback Table
          Container(
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1.2),
              boxShadow: colors.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Riwayat Upload Batch & Audit Log',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${state.batches.length} Batch',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.border),

                if (state.isLoadingHistory)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (state.batches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.history, size: 40, color: colors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Belum Ada Riwayat Batch Upload',
                            style: GoogleFonts.outfit(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'File transaksi yang Anda upload akan dicatat di sini dengan audit log lengkap.',
                            style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ResponsiveTableCard(
                    minWidth: 880,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
                      columns: [
                        DataColumn(label: Text('ID Batch', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Entitas', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('File Asli', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Baris Total / Sukses / Gagal', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Status', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Waktu Upload', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600))),
                      ],
                      rows: state.batches.map((batch) {
                        final isAlreadyRolledBack = batch.status.toUpperCase() == 'ROLLED_BACK';

                        return DataRow(
                          cells: [
                            // ID Batch
                            DataCell(
                              Text(
                                batch.id.length > 8 ? '${batch.id.substring(0, 8)}...' : batch.id,
                                style: GoogleFonts.sourceCodePro(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Entitas
                            DataCell(
                              Text(
                                _formatEntityLabel(batch.entity),
                                style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                              ),
                            ),
                            // File Asli
                            DataCell(
                              Text(
                                batch.originalFilename ?? '-',
                                style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 12.5),
                              ),
                            ),
                            // Row statistics
                            DataCell(
                              Row(
                                children: [
                                  Text('${batch.totalRows} baris ', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                                  Text('(${batch.successRows} sukses, ', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                                  Text('${batch.failedRows} gagal)', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                                ],
                              ),
                            ),
                            // Status Badge
                            DataCell(_buildStatusBadge(context, batch.status)),
                            // Created At
                            DataCell(
                              Text(batch.createdAt, style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12)),
                            ),
                            // Rollback Action
                            DataCell(
                              !_isRollbackSupported(batch.entity)
                                  ? Text('Master Data', style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12))
                                  : isAlreadyRolledBack
                                      ? Text('Di-rollback', style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12))
                                      : OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(LucideIcons.rotateCcw, size: 13),
                                          label: const Text('Rollback', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showRollbackConfirmation(batch),
                                        ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

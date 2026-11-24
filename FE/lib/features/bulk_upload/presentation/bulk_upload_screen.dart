import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../data/models/upload_batch_model.dart';
import '../../master_data/providers/master_data_provider.dart';
import '../providers/bulk_upload_provider.dart';

class BulkUploadScreen extends ConsumerStatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  ConsumerState<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends ConsumerState<BulkUploadScreen> {
  final TextEditingController _selloutPeriodCtrl = TextEditingController();
  final TextEditingController _historyPeriodCtrl = TextEditingController();
  final TextEditingController _historySearchCtrl = TextEditingController();
  String _historyEntityFilter = 'ALL';
  String _historyStatusFilter = 'ALL';
  int _historyPage = 1;
  int _historyPerPage = 10;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final md = ref.read(masterDataProvider);
      if (md.distributors.isEmpty) {
        ref.read(masterDataProvider.notifier).fetchAllMasterData();
      }
    });
  }

  @override
  void dispose() {
    _selloutPeriodCtrl.dispose();
    _historyPeriodCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  final Map<String, String> _entityOptions = {
    'sellout_distributor': 'Transaksi: Sell-Out Distributor',
    'sellin_industri': 'Transaksi: Sell-In Industri (Kg & NOO)',
    'industri_customer': 'Master: Customer & Assignment Sales Industri',
    'distributor': 'Master: Distributor, Depo & Area',
    'master_target_distributor': 'Master: Target Distributor (Depo & Area)',
  };

  final Map<String, List<Map<String, String>>> _entityColumnGuides = {
    'sellout_distributor': [
      {'col': 'Faktur', 'req': 'WAJIB', 'ex': 'INV/07/26/0001', 'desc': 'Nomor faktur penjualan/retur (tidak boleh kosong)'},
      {'col': 'Tanggal', 'req': 'WAJIB', 'ex': '2026-07-01', 'desc': 'Tanggal faktur valid (YYYY-MM-DD / DD/MM/YYYY)'},
      {'col': 'Bulan', 'req': 'WAJIB', 'ex': '7', 'desc': 'Bulan 1-12 (wajib sinkron dengan bulan pada Tanggal)'},
      {'col': 'KodeDistributor', 'req': 'WAJIB', 'ex': 'C110003678', 'desc': 'Kode SAP Depo/Distributor sesuai Master Distributor'},
      {'col': 'NamaDistributor', 'req': 'WAJIB', 'ex': 'INDO PRIMA, CV', 'desc': 'Nama Distributor sesuai Master Distributor'},
      {'col': 'Depo', 'req': 'WAJIB', 'ex': 'PONTIANAK', 'desc': 'Nama atau kode Depo sesuai Master Depo'},
      {'col': 'AreaCode', 'req': 'WAJIB', 'ex': 'AR00100 / LUAR', 'desc': 'Kode Area (ARxxxxx) sesuai Master, atau isi LUAR / OUT_AREA untuk penjualan luar area (non-insentif)'},
      {'col': 'KodeCustomer', 'req': 'WAJIB', 'ex': 'CUST-0001', 'desc': 'Kode toko/outlet pembeli (perhitungan Active Outlet / AO)'},
      {'col': 'NamaCustomer', 'req': 'WAJIB', 'ex': 'MARI MART', 'desc': 'Nama toko/outlet pembeli'},
      {'col': 'Alamat', 'req': 'WAJIB', 'ex': 'JL. DR. WAHIDIN', 'desc': 'Alamat toko/outlet pembeli'},
      {'col': 'JenisBarang', 'req': 'WAJIB', 'ex': 'KAPAL', 'desc': 'Kode/nama Brand sesuai Master Brand'},
      {'col': 'JenisSales', 'req': 'WAJIB', 'ex': 'SELL OUT', 'desc': 'Wajib berisi SELL OUT'},
      {'col': 'ITM', 'req': 'WAJIB', 'ex': 'B13', 'desc': 'Kode item produk'},
      {'col': 'NamaBarang', 'req': 'WAJIB', 'ex': 'KOP 150 @ 3KG / BAL', 'desc': 'Nama kemasan barang'},
      {'col': 'Barang', 'req': 'WAJIB', 'ex': 'GARAM CAP KAPAL 150GR @3KG/BAL', 'desc': 'Deskripsi lengkap barang'},
      {'col': 'SalesKg', 'req': 'WAJIB', 'ex': '3 / -15', 'desc': 'Volume penjualan Kg (angka valid, tidak boleh 0)'},
      {'col': 'DPP', 'req': 'WAJIB', 'ex': '20670', 'desc': 'Nilai penjualan sebelum pajak (Rp)'},
      {'col': 'Kota/Kab', 'req': 'WAJIB', 'ex': 'PONTIANAK', 'desc': 'Kota / Kabupaten lokasi outlet'},
      {'col': 'Kecamatan', 'req': 'OPSIONAL', 'ex': '(boleh kosong)', 'desc': 'Kecamatan lokasi outlet'},
      {'col': 'SalesmanDist', 'req': 'WAJIB', 'ex': 'JACKY CHEDORRY', 'desc': 'Nama salesman distributor'},
      {'col': 'PIC', 'req': 'WAJIB', 'ex': 'DANNY', 'desc': 'Nama PIC'},
      {'col': 'TipeOutlet', 'req': 'WAJIB', 'ex': 'RETAIL', 'desc': 'Tipe outlet (RETAIL, MINI MARKET, GROSIR, dll)'},
    ],
    'sellin_industri': [
      {'col': 'customer_code', 'req': 'WAJIB', 'ex': 'CUST-IND-01', 'desc': 'Kode Customer Industri (atau isi customer_name)'},
      {'col': 'customer_name', 'req': 'OPSIONAL', 'ex': 'PT Roti Nusantara Jaya', 'desc': 'Nama Customer Industri'},
      {'col': 'username', 'req': 'OPSIONAL', 'ex': 'andre_spv', 'desc': 'Username sales PIC (kosong = pakai Assignment aktif)'},
      {'col': 'period', 'req': 'WAJIB', 'ex': '202611', 'desc': 'Periode YYYYMM (6 digit)'},
      {'col': 'volume_kg', 'req': 'WAJIB', 'ex': '50000', 'desc': 'Volume Sell-In Industri (Kg)'},
      {'col': 'nominal', 'req': 'OPSIONAL', 'ex': '750000000', 'desc': 'Nilai penjualan (Rp)'},
      {'col': 'is_noo', 'req': 'OPSIONAL', 'ex': '0 / 1 / kosong', 'desc': '1 = NOO, 0 = Repeat, kosong = Auto sistem'},
      {'col': 'sap_so_no', 'req': 'OPSIONAL', 'ex': 'SO-IND-202611-201', 'desc': 'Nomor Sales Order SAP'},
    ],
    'industri_customer': [
      {'col': 'customer_code', 'req': 'WAJIB', 'ex': 'CUST-IND-01', 'desc': 'Kode unik Customer Industri'},
      {'col': 'customer_name', 'req': 'WAJIB', 'ex': 'PT Roti Nusantara Jaya', 'desc': 'Nama Customer / Pabrik Industri'},
      {'col': 'city', 'req': 'OPSIONAL', 'ex': 'Surabaya', 'desc': 'Kota / area domisili customer'},
      {'col': 'customer_type', 'req': 'OPSIONAL', 'ex': 'NEW / EXISTING', 'desc': 'Default NEW jika kosong'},
      {'col': 'first_transaction_period', 'req': 'OPSIONAL', 'ex': '202504', 'desc': 'Periode transaksi awal (YYYYMM)'},
      {'col': 'sales_username', 'req': 'OPSIONAL', 'ex': 'andre_spv', 'desc': 'Username sales PIC untuk auto-assign customer'},
    ],
    'distributor': [
      {'col': 'region_code', 'req': 'OPSIONAL', 'ex': 'EAST', 'desc': 'Kode Region (EAST / WEST)'},
      {'col': 'distributor_code', 'req': 'WAJIB', 'ex': 'DST01', 'desc': 'Kode Distributor (ulangi jika banyak Depo)'},
      {'col': 'distributor_name', 'req': 'WAJIB', 'ex': 'PT Sumber Rejeki Utama', 'desc': 'Nama Perusahaan Distributor'},
      {'col': 'depo_code', 'req': 'WAJIB', 'ex': 'DP01', 'desc': 'Kode Depo berelasi ke distributor_code'},
      {'col': 'depo_name', 'req': 'WAJIB', 'ex': 'Depo Surabaya Timur', 'desc': 'Nama Cabang Depo'},
      {'col': 'area_code', 'req': 'WAJIB', 'ex': 'AR01', 'desc': 'Kode Area berelasi ke depo_code'},
      {'col': 'area_name', 'req': 'WAJIB', 'desc': 'Nama Area Operasional', 'ex': 'Rungkut & Sekitarnya'},
    ],
    'master_target_distributor': [
      {'col': 'period', 'req': 'WAJIB', 'ex': '202610 / 2026', 'desc': 'Periode YYYYMM (atau YYYY untuk 12 bulan)'},
      {'col': 'distributor_code', 'req': 'WAJIB', 'ex': 'DST01', 'desc': 'Kode Distributor sesuai Master (lihat Sheet 2 Panduan untuk nama & region)'},
      {'col': 'depo_code', 'req': 'WAJIB', 'ex': 'DP01', 'desc': 'Kode Depo sesuai Master (lihat Sheet 2 Panduan untuk nama depo & distributor)'},
      {'col': 'area_code', 'req': 'OPSIONAL', 'ex': 'AR01 / (kosong)', 'desc': 'Kosongkan = Target Depo (ASM); Isi = Target Area (SPV) — lihat Sheet 2 Panduan'},
      {'col': 'brand_code', 'req': 'WAJIB', 'ex': 'KAPAL / KAPAL+JEMPOL', 'desc': 'Kode Brand tunggal atau Brand Gabungan (KAPAL+JEMPOL, ALL_BRAND)'},
      {'col': 'metrik_target', 'req': 'WAJIB', 'ex': 'SELL_IN / SELL_OUT', 'desc': 'SELL_IN untuk baris Depo; SELL_OUT untuk baris Area'},
      {'col': 'target_quota', 'req': 'WAJIB', 'ex': '5000 / 1500', 'desc': 'Besaran kuota Target Depo atau Area (Kg)'},
      {'col': 'target_outlet', 'req': 'OPSIONAL', 'ex': '25', 'desc': 'Target jumlah toko Active Outlet / AO (satuan Toko, khusus baris Area)'},
      {'col': 'username', 'req': 'OPSIONAL', 'ex': 'budi_asm / rian_spv', 'desc': 'Username ASM/SPV (otomatis jika kosong)'},
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
      'distributor': 'Master: Distributor, Depo & Area',
      'master_target_depo': 'Master: Target Depo (ASM)',
      'master_target_area': 'Master: Target Area (SPV)',
      'depo': 'Master: Depo',
      'depos': 'Master: Depo',
      'area': 'Master: Area',
      'areas': 'Master: Area',
      'master_targets': 'Master: Target Distributor',
      'target_distributor': 'Master: Target Distributor',
    };
    return mapLegacy[rawEntity] ?? rawEntity;
  }

  Future<void> _pickFile() async {
    final isSellout = ref.read(bulkUploadProvider).selectedEntity == 'sellout_distributor';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      allowMultiple: !isSellout,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final picked = result.files
          .where((f) => f.bytes != null)
          .map((f) => SelectedUploadFile(name: f.name, size: f.size, bytes: f.bytes!))
          .toList();
      if (picked.isNotEmpty) {
        ref.read(bulkUploadProvider.notifier).setFiles(picked);
      }
    }
  }

  void _showDeleteBatchConfirmation(UploadBatchModel batch) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.trash2, color: context.semantic.danger, size: 22),
            const SizedBox(width: 10),
            Text(
              'Hapus Riwayat & Data Batch',
              style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus permanen batch upload ini beserta seluruh datanya?',
              style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 13.5),
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
                  Text('Entitas: ${_formatEntityLabel(batch.entity)}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  Text('File Asli: ${batch.originalFilename ?? '-'}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  Text('Total Baris: ${batch.totalRows} baris (${batch.successRows} berhasil)', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Perhatian: Menghapus batch ini akan otomatis me-rollback (menghapus) seluruh data transaksi/master yang di-import dari database beserta file Excel dan riwayatnya.',
              style: GoogleFonts.plusJakartaSans(color: context.semantic.danger, fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.semantic.dangerSolid, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bulkUploadProvider.notifier).deleteBatch(batch.id);
            },
            child: Text('Ya, Hapus Data & Riwayat', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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
        bg = context.semantic.success.withValues(alpha: 0.15);
        text = context.semantic.success;
        icon = LucideIcons.checkCircle2;
        break;
      case 'ROLLED_BACK':
        bg = context.semantic.danger.withValues(alpha: 0.15);
        text = context.semantic.danger;
        icon = LucideIcons.rotateCcw;
        break;
      case 'PROCESSING':
        bg = context.semantic.warning.withValues(alpha: 0.15);
        text = Theme.of(context).colorScheme.primary;
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
            style: GoogleFonts.plusJakartaSans(color: text, fontWeight: FontWeight.bold, fontSize: 11),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unggah data transaksi massal spreadsheet dan manajemen pemulihan batch aman',
                      style: GoogleFonts.plusJakartaSans(
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
                color: context.semantic.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, color: context.semantic.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.plusJakartaSans(color: context.semantic.danger, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () => notifier.clearError(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.x, color: context.semantic.danger, size: 16),
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
                color: context.semantic.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.semantic.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.checkCircle2, color: context.semantic.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.successMessage!,
                      style: GoogleFonts.plusJakartaSans(color: context.semantic.success, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () => notifier.clearSuccess(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(LucideIcons.x, color: context.semantic.success, size: 16),
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
              borderRadius: BorderRadius.circular(12),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.borderMuted),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
                          label: Text(
                            'Tarik Template + Data Eksisting',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: state.isDownloadingTemplate
                              ? null
                              : () => notifier.downloadTemplate(withData: true),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.semantic.successSolid,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: state.isDownloadingTemplate
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                                )
                              : const Icon(LucideIcons.download, size: 15),
                          label: Text(
                            state.isDownloadingTemplate
                                ? 'Mengunduh...'
                                : 'Unduh Template Kosong',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onPressed: state.isDownloadingTemplate ? null : () => notifier.downloadTemplate(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderMuted),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _entityOptions.containsKey(state.selectedEntity)
                          ? state.selectedEntity
                          : _entityOptions.keys.first,
                      dropdownColor: colors.bgCard,
                      isExpanded: true,
                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 14),
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
                if (state.selectedEntity == 'sellout_distributor') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.shieldCheck, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aturan Ketat Sell-Out: 1 File Excel = 1 Bulan (Periode) & 1 Distributor',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sistem memverifikasi bahwa seluruh baris memiliki pengkodean valid (AreaCode, KodeDistributor, KodeCustomer, ITM, JenisBarang), DPP & SalesKg non-nol, serta hanya berasal dari 1 bulan dan 1 distributor.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 225,
                              child: TextField(
                                controller: _selloutPeriodCtrl,
                                maxLength: 6,
                                style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  counterText: '',
                                  labelText: 'Periode Bulan (YYYYMM)',
                                  hintText: 'Contoh: 202610',
                                  prefixIcon: Icon(LucideIcons.calendar, size: 15, color: colors.textMuted),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  filled: true,
                                  fillColor: colors.bgInput,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (v) => notifier.setSelloutPeriod(v),
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: DropdownButtonFormField<int?>(
                                initialValue: state.selectedDistributorId,
                                isExpanded: true,
                                dropdownColor: colors.bgCard,
                                style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Distributor (Opsional / Kunci Validasi)',
                                  prefixIcon: Icon(LucideIcons.building2, size: 15, color: colors.textMuted),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  filled: true,
                                  fillColor: colors.bgInput,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Deteksi otomatis dari file (wajib 1 distributor)', overflow: TextOverflow.ellipsis),
                                  ),
                                  ...ref.watch(masterDataProvider).distributors.map(
                                        (d) => DropdownMenuItem<int?>(
                                          value: d.id,
                                          child: Text('${d.code} — ${d.name}', overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                ],
                                onChanged: (v) => notifier.setSelloutDistributorId(v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
                          Icon(LucideIcons.bookOpen, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Panduan Kolom Excel — ${_formatEntityLabel(state.selectedEntity)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            'Sheet 1: Data Upload • Sheet 2: Kode Referensi Master',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: colors.textMuted),
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
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isReq ? context.semantic.warning : context.semantic.info).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        col['req']!,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isReq ? context.semantic.warning : context.semantic.info,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  col['desc']!,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: colors.textSecondary),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // File Dropzone Box
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: colors.bgSubtle.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: state.selectedFileName != null ? Theme.of(context).colorScheme.primary : colors.borderMuted,
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
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.fileSpreadsheet, size: 36, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          state.selectedFileName ?? 'Klik atau Seret file Excel ke sini',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: state.selectedFileName != null ? colors.textPrimary : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.selectedFileSize != null
                              ? 'Total Ukuran: ${_formatFileSize(state.selectedFileSize!)} • Bisa pilih banyak file sekaligus (.xlsx, .xls, .csv)'
                              : 'Mendukung Multi-File Upload sekaligus (.xlsx, .xls, .csv) • Kapasitas ratusan ribu baris (Max 200MB/file)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (state.selectedFiles.length > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.bgSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftar File yang Akan Diunggah (${state.selectedFiles.length} file):',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.selectedFiles.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final f = entry.value;
                            return Chip(
                              avatar: Icon(LucideIcons.fileSpreadsheet, size: 14, color: Theme.of(context).colorScheme.primary),
                              label: Text('${f.name} (${_formatFileSize(f.size)})', style: const TextStyle(fontSize: 11.5)),
                              onDeleted: state.isUploading ? null : () => notifier.removeFileAt(idx),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                if (state.isUploading) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.uploadProgress > 0 && state.uploadProgress < 0.95 ? state.uploadProgress : null,
                      minHeight: 8,
                      backgroundColor: colors.bgSubtle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.uploadStatusText ??
                        (state.uploadProgress < 0.9
                            ? 'Mengunggah file ke server (${(state.uploadProgress * 100).toStringAsFixed(0)}%)...'
                            : 'Memproses & menyimpan ribuan baris ke database secara bulk (Streaming Engine)...'),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                  ),
                ],

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
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: state.isUploading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
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

          // Riwayat Batch & Audit Log Table (Compact 5 Columns + Filter + Pagination)
          Builder(
            builder: (context) {
              final periodFilter = _historyPeriodCtrl.text.trim().toLowerCase();
              final queryFilter = _historySearchCtrl.text.trim().toLowerCase();

              final filteredBatches = state.batches.where((batch) {
                if (_historyEntityFilter != 'ALL' && batch.entity != _historyEntityFilter) {
                  return false;
                }
                if (_historyStatusFilter != 'ALL' && batch.status.toUpperCase() != _historyStatusFilter) {
                  return false;
                }
                if (periodFilter.isNotEmpty && !(batch.period ?? '').toLowerCase().contains(periodFilter)) {
                  return false;
                }
                if (queryFilter.isNotEmpty) {
                  final haystack = [
                    batch.id,
                    batch.originalFilename ?? '',
                    batch.distributorCode ?? '',
                    batch.distributorName ?? '',
                    batch.period ?? '',
                    _formatEntityLabel(batch.entity),
                  ].join(' ').toLowerCase();
                  if (!haystack.contains(queryFilter)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              final totalItems = filteredBatches.length;
              final totalPages = totalItems == 0 ? 1 : ((totalItems - 1) ~/ _historyPerPage) + 1;
              final safePage = _historyPage.clamp(1, totalPages);
              final startIndex = totalItems == 0 ? 0 : (safePage - 1) * _historyPerPage;
              final endIndex = (startIndex + _historyPerPage).clamp(0, totalItems);
              final pagedBatches = totalItems == 0
                  ? <UploadBatchModel>[]
                  : filteredBatches.sublist(startIndex, endIndex);

              return Container(
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border, width: 1.2),
                  boxShadow: colors.cardShadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Riwayat Upload Batch & Audit Log',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: colors.bgSubtle, borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '$totalItems / ${state.batches.length} Batch',
                                      style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Dropdown Entitas
                                  SizedBox(
                                    width: 210,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _historyEntityFilter,
                                      isExpanded: true,
                                      dropdownColor: colors.bgCard,
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(LucideIcons.layers, size: 14, color: colors.textMuted),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        filled: true,
                                        fillColor: colors.bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'ALL',
                                          child: Text('Semua Entitas', overflow: TextOverflow.ellipsis),
                                        ),
                                        ..._entityOptions.entries.map(
                                          (e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _historyEntityFilter = val;
                                            _historyPage = 1;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  // Dropdown Status
                                  SizedBox(
                                    width: 175,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _historyStatusFilter,
                                      isExpanded: true,
                                      dropdownColor: colors.bgCard,
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(LucideIcons.filter, size: 14, color: colors.textMuted),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        filled: true,
                                        fillColor: colors.bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'ALL', child: Text('Semua Status', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'FAILED', child: Text('FAILED', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _historyStatusFilter = val;
                                            _historyPage = 1;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  // Filter Periode
                                  SizedBox(
                                    width: 165,
                                    child: TextField(
                                      controller: _historyPeriodCtrl,
                                      maxLength: 6,
                                      onChanged: (_) => setState(() => _historyPage = 1),
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: 'Periode (202610)',
                                        prefixIcon: Icon(LucideIcons.calendar, size: 14, color: colors.textMuted),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        filled: true,
                                        fillColor: colors.bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                      ),
                                    ),
                                  ),
                                  // Live Search
                                  SizedBox(
                                    width: 250,
                                    child: TextField(
                                      controller: _historySearchCtrl,
                                      onChanged: (_) => setState(() => _historyPage = 1),
                                      style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        hintText: 'Ketik nama file / distributor...',
                                        prefixIcon: Icon(LucideIcons.search, size: 14, color: colors.textMuted),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        suffixIcon: _historySearchCtrl.text.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(LucideIcons.x, size: 13, color: colors.textMuted),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  _historySearchCtrl.clear();
                                                  setState(() => _historyPage = 1);
                                                },
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: colors.bgInput,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: state.isLoadingHistory
                                        ? null
                                        : () => notifier.fetchHistory(
                                              period: _historyPeriodCtrl.text,
                                              query: _historySearchCtrl.text,
                                            ),
                                    icon: const Icon(LucideIcons.refreshCw, size: 13),
                                    label: const Text('Segarkan', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.border),

                    if (state.isLoadingHistory)
                      Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                      )
                    else if (filteredBatches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.history, size: 40, color: colors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                state.batches.isEmpty ? 'Belum Ada Riwayat Batch Upload' : 'Tidak Ada Batch Sesuai Filter',
                                style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                state.batches.isEmpty
                                    ? 'File transaksi yang Anda upload akan dicatat di sini dengan audit log lengkap.'
                                    : 'Coba ubah filter Entitas, Status, Periode, atau kata kunci pencarian.',
                                style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ResponsiveTableCard(
                        minWidth: 740,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(colors.bgTableHead),
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          dataRowMinHeight: 54,
                          dataRowMaxHeight: 72,
                          columns: [
                            DataColumn(label: Text('File & Distributor', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                            DataColumn(label: Text('Entitas & Waktu', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                            DataColumn(label: Text('Hasil Baris', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                            DataColumn(label: Text('Status', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                            DataColumn(label: Text('Aksi', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                          ],
                          rows: pagedBatches.map((batch) {
                            final shortId = batch.id.length > 8 ? batch.id.substring(0, 8) : batch.id;

                            return DataRow(
                              cells: [
                                // 1. File Asli + Distributor & Periode
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 260),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Tooltip(
                                          message: batch.originalFilename ?? '-',
                                          child: Text(
                                            batch.originalFilename ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: colors.textPrimary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if ((batch.period != null && batch.period!.isNotEmpty) ||
                                            (batch.distributorName != null && batch.distributorName!.isNotEmpty))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              [
                                                if (batch.period != null && batch.period!.isNotEmpty) 'Periode: ${batch.period}',
                                                if (batch.distributorName != null && batch.distributorName!.isNotEmpty)
                                                  '${batch.distributorCode ?? ''} ${batch.distributorName}'.trim(),
                                              ].join(' • '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 2. Entitas & Waktu + Short ID
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 210),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _formatEntityLabel(batch.entity),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_formatBatchTimestamp(batch.createdAt)} • #$shortId',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.sourceCodePro(color: colors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 3. Hasil Baris
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${batch.totalRows} baris',
                                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('${batch.successRows} sukses', style: TextStyle(color: context.semantic.success, fontSize: 11)),
                                          if (batch.failedRows > 0) ...[
                                            Text(', ', style: TextStyle(color: colors.textMuted, fontSize: 11)),
                                            Text('${batch.failedRows} gagal', style: TextStyle(color: context.semantic.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 4. Status Badge
                                DataCell(_buildStatusBadge(context, batch.status)),
                                // 5. Aksi: Unduh Excel & Hapus (Rollback + Delete in 1 action)
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(LucideIcons.download, size: 15, color: Theme.of(context).colorScheme.primary),
                                        tooltip: 'Unduh Excel (${batch.originalFilename ?? 'file.xlsx'})',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => ref.read(bulkUploadProvider.notifier).downloadBatchFile(
                                          batch.id,
                                          batch.originalFilename ?? 'batch_${batch.id}.xlsx',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: context.semantic.danger,
                                          side: BorderSide(color: context.semantic.danger.withValues(alpha: 0.45)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(LucideIcons.trash2, size: 13),
                                        label: const Text('Hapus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                        onPressed: () => _showDeleteBatchConfirmation(batch),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      Divider(height: 1, color: colors.border),
                      // Pagination Footer
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Menampilkan ${startIndex + 1}–$endIndex dari $totalItems batch',
                              style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12),
                            ),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('Baris/hal:', style: GoogleFonts.plusJakartaSans(color: colors.textMuted, fontSize: 12)),
                                ...[10, 25, 50].map((size) {
                                  final selected = _historyPerPage == size;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => setState(() {
                                      _historyPerPage = size;
                                      _historyPage = 1;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: selected ? Theme.of(context).colorScheme.primary : colors.bgSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$size',
                                        style: TextStyle(
                                          color: selected ? Theme.of(context).colorScheme.onPrimary : colors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: safePage > 1 ? () => setState(() => _historyPage = safePage - 1) : null,
                                ),
                                Text(
                                  'Hal $safePage / $totalPages',
                                  style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: safePage < totalPages ? () => setState(() => _historyPage = safePage + 1) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatBatchTimestamp(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d $m ${dt.year} $h:$min';
  }
}

<?php

namespace App\Exports;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\Region;
use App\Models\User;
use App\Services\BatchImportService;
use Maatwebsite\Excel\Concerns\Export;
use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMultipleSheets;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;

class BulkUploadTemplateExport implements Export, WithMultipleSheets
{
    protected string $entity;

    public function __construct(string $entity)
    {
        $this->entity = BatchImportService::normalizeEntity($entity);
    }

    public function sheets(): array
    {
        return [
            new BulkUploadDataSheet($this->entity),
            new BulkUploadGuideSheet($this->entity),
        ];
    }
}

class BulkUploadDataSheet implements FromArray, ShouldAutoSize, WithHeadings, WithStyles, WithTitle
{
    public function __construct(protected string $entity) {}

    public function title(): string
    {
        return 'Data Upload';
    }

    public function headings(): array
    {
        return match ($this->entity) {
            'sellin_distributor' => [
                'distributor_code',
                'brand_code',
                'period',
                'volume_kg',
                'nominal',
                'sap_doc_no',
            ],
            'sellout_distributor' => [
                'depo_code',
                'brand_code',
                'period',
                'volume_kg',
                'active_outlet_count',
            ],
            'sellin_industri' => [
                'username',
                'customer_name',
                'period',
                'tonase',
                'sap_so_no',
            ],
            'sellout_sales_surabaya' => [
                'sales_username',
                'coordinator_username',
                'period',
                'volume',
                'active_outlet_count',
            ],
            'distributor' => [
                'region_code',
                'distributor_code',
                'distributor_name',
                'depo_code',
                'depo_name',
                'area_code',
                'area_name',
            ],
            'master_target_distributor' => [
                'period',
                'distributor_code',
                'depo_code',
                'area_code',
                'brand_code',
                'metrik_target',
                'target_quota',
                'target_outlet',
                'username',
            ],
            'depo' => [
                'code',
                'name',
                'distributor_code',
            ],
            'area' => [
                'code',
                'name',
                'depo_code',
            ],
            default => [],
        };
    }

    public function array(): array
    {
        return match ($this->entity) {
            'sellin_distributor' => [
                ['DST01', 'BRD01', '202610', 15000, 375000000, 'SAP-SI-202610-010'],
                ['DST01', 'BRD02', '202610', 8500, 212500000, 'SAP-SI-202610-011'],
            ],
            'sellout_distributor' => [
                ['DP01', 'BRD01', '202610', 12000, 45],
                ['DP02', 'BRD02', '202610', 6500, 30],
            ],
            'sellin_industri' => [
                ['dewi_industri', 'PT Roti Nusantara Jaya', '202610', 25.5, 'SO-IND-202610-201'],
                ['dewi_industri', 'CV Biskuit Makmur Sentosa', '202610', 18.0, 'SO-IND-202610-202'],
            ],
            'sellout_sales_surabaya' => [
                ['eko_surabaya', 'admin', '202610', 3200, 38],
                ['eko_surabaya', 'admin', '202610', 2100, 25],
            ],
            'distributor' => [
                ['REG01', 'DST01', 'PT Sumber Rejeki Utama', 'DP01', 'Depo Surabaya Timur', 'AR01', 'Rungkut & Sekitarnya'],
                ['REG01', 'DST01', 'PT Sumber Rejeki Utama', 'DP01', 'Depo Surabaya Timur', 'AR02', 'Area B2 (Tenggilis)'],
                ['REG01', 'DST01', 'PT Sumber Rejeki Utama', 'DP02', 'Depo A2 - Surabaya Barat', 'AR03', 'Tandes & Margomulyo'],
                ['REG02', 'DST02', 'PT Maju Bersama Distribusi', 'DP03', 'Depo Semarang Pusat', 'AR04', 'Simpang Lima & Sekitarnya'],
            ],
            'master_target_distributor' => [
                ['202610', 'DST01', 'DP01', '', 'BRD01', 'SELL_OUT', 3000, 50, 'budi_asm'],
                ['202610', 'DST01', 'DP01', '', 'BRD01', 'SELL_IN', 3000, '', 'budi_asm'],
                ['202610', 'DST01', 'DP01', 'AR01', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
                ['202610', 'DST01', 'DP01', 'AR02', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
            ],
            'depo' => [
                ['DP01', 'Depo Surabaya Timur', 'DST01'],
                ['DP02', 'Depo A2 - Surabaya Barat', 'DST01'],
            ],
            'area' => [
                ['AR01', 'Rungkut & Sekitarnya', 'DP01'],
                ['AR02', 'Area B2 (Tenggilis)', 'DP01'],
            ],
            default => [],
        };
    }

    public function styles(Worksheet $sheet): array
    {
        return [
            1 => [
                'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => '4F46E5'],
                ],
            ],
        ];
    }
}

class BulkUploadGuideSheet implements FromArray, ShouldAutoSize, WithStyles, WithTitle
{
    public function __construct(protected string $entity) {}

    public function title(): string
    {
        return 'Panduan & Kode Referensi';
    }

    public function array(): array
    {
        $rows = [
            ['PANDUAN PENGISIAN TEMPLATE UPLOAD (' . strtoupper($this->entity) . ')'],
            ['Catatan Penting: Sistem hanya membaca Sheet 1 ("Data Upload"). Jangan mengubah nama kolom di baris 1 Sheet "Data Upload".'],
            [''],
            ['1. DAFTAR KOLOM & ATURAN PENGISIAN'],
            ['Nama Kolom', 'Status', 'Tipe / Format', 'Contoh Nilai', 'Keterangan / Aturan'],
        ];

        foreach ($this->getColumnGuides() as $guide) {
            $rows[] = $guide;
        }

        $rows[] = [''];
        $rows[] = ['2. DAFTAR KODE REFERENSI MASTER DATA AKTIF DI DATABASE'];

        // Brands
        $rows[] = [''];
        $rows[] = ['A. KODE BRAND (brand_code)'];
        $rows[] = ['brand_code', 'Nama Brand', 'brand_id'];
        foreach (Brand::orderBy('code')->get(['id', 'code', 'name']) as $b) {
            $rows[] = [$b->code, $b->name, $b->id];
        }

        // Regions
        $rows[] = [''];
        $rows[] = ['B. KODE REGION (region_code)'];
        $rows[] = ['region_code', 'Nama Region', 'region_id'];
        foreach (Region::orderBy('code')->get(['id', 'code', 'name']) as $r) {
            $rows[] = [$r->code, $r->name, $r->id];
        }

        // Distributors
        $rows[] = [''];
        $rows[] = ['C. KODE DISTRIBUTOR (distributor_code)'];
        $rows[] = ['distributor_code', 'Nama Distributor', 'distributor_id'];
        foreach (Distributor::orderBy('code')->get(['id', 'code', 'name']) as $d) {
            $rows[] = [$d->code, $d->name, $d->id];
        }

        // Depos
        $rows[] = [''];
        $rows[] = ['D. KODE DEPO (depo_code)'];
        $rows[] = ['depo_code', 'Nama Depo', 'Kode Distributor Induk', 'depo_id'];
        foreach (Depo::with('distributor')->orderBy('code')->get() as $dp) {
            $rows[] = [$dp->code, $dp->name, $dp->distributor?->code ?? '-', $dp->id];
        }

        // Areas
        $rows[] = [''];
        $rows[] = ['E. KODE AREA (depo_code -> area_code)'];
        $rows[] = ['area_code', 'Nama Area', 'Kode Depo Induk', 'area_id'];
        foreach (Area::with('depo')->orderBy('code')->get() as $ar) {
            $rows[] = [$ar->code, $ar->name, $ar->depo?->code ?? '-', $ar->id];
        }

        // Users / Sales
        $rows[] = [''];
        $rows[] = ['F. DAFTAR USERNAME & ID USER / SALES'];
        $rows[] = ['username', 'Nama Lengkap', 'Jabatan / Position', 'user_id'];
        foreach (User::with('position')->orderBy('id')->get() as $u) {
            $rows[] = [$u->username, $u->name, $u->position?->name ?? 'Admin / All', $u->id];
        }

        return $rows;
    }

    protected function getColumnGuides(): array
    {
        return match ($this->entity) {
            'sellin_distributor' => [
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode distributor sesuai Master Distributor (atau gunakan kolom distributor_id)'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode brand produk sesuai Master Brand (atau gunakan kolom brand_id)'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202610', 'Periode bulan transaksi (contoh: 202610 untuk Oktober 2026)'],
                ['volume_kg', 'WAJIB', 'Angka / Desimal', '15000', 'Total volume Sell-In dalam satuan Kg (tanpa titik pemisah ribuan)'],
                ['nominal', 'WAJIB', 'Angka / Desimal', '375000000', 'Total nilai rupiah transaksi (tanpa Rp atau titik ribuan)'],
                ['sap_doc_no', 'OPSIONAL', 'Teks', 'SAP-SI-202610-010', 'Nomor dokumen referensi SAP'],
            ],
            'sellout_distributor' => [
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode depo sesuai Master Depo (atau gunakan kolom depo_id)'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode brand produk sesuai Master Brand (atau gunakan kolom brand_id)'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202610', 'Periode bulan transaksi (contoh: 202610)'],
                ['volume_kg', 'WAJIB', 'Angka / Desimal', '12000', 'Total volume Sell-Out dalam satuan Kg'],
                ['active_outlet_count', 'WAJIB', 'Angka Bulat', '45', 'Jumlah toko/outlet aktif (Active Outlet / AO)'],
            ],
            'sellin_industri' => [
                ['username', 'WAJIB', 'Teks (Username)', 'dewi_industri', 'Username sales industri (atau gunakan kolom user_id berisi ID angka user)'],
                ['customer_name', 'WAJIB', 'Teks', 'PT Roti Nusantara Jaya', 'Nama pelanggan / pabrik B2B industri'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202610', 'Periode bulan transaksi (contoh: 202610)'],
                ['tonase', 'WAJIB', 'Angka / Desimal', '25.5', 'Total volume penjualan dalam satuan Ton'],
                ['sap_so_no', 'OPSIONAL', 'Teks', 'SO-IND-202610-201', 'Nomor Sales Order (SO) SAP'],
            ],
            'sellout_sales_surabaya' => [
                ['sales_username', 'WAJIB', 'Teks (Username)', 'eko_surabaya', 'Username sales TO/Canvasing Surabaya (atau gunakan kolom sales_id)'],
                ['coordinator_username', 'OPSIONAL', 'Teks (Username)', 'admin', 'Username koordinator Surabaya (atau gunakan kolom coordinator_id)'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202610', 'Periode bulan transaksi (contoh: 202610)'],
                ['volume', 'WAJIB', 'Angka / Desimal', '3200', 'Total volume penjualan Sell-Out Surabaya (Kg / Box)'],
                ['active_outlet_count', 'WAJIB', 'Angka Bulat', '38', 'Jumlah toko/outlet aktif (Active Outlet / AO)'],
            ],
            'distributor' => [
                ['region_code', 'OPSIONAL', 'Teks (Kode)', 'REG01', 'Kode Region sesuai Master Region (contoh: REG01, REG02, REG03)'],
                ['distributor_code', 'WAJIB', 'Teks Unik', 'DST01', 'Kode unik Distributor. Ulangi kode yang sama di baris berikutnya jika memiliki banyak Depo/Area.'],
                ['distributor_name', 'WAJIB', 'Teks', 'PT Sumber Rejeki Utama', 'Nama lengkap perusahaan Distributor'],
                ['depo_code', 'WAJIB', 'Teks Unik', 'DP01', 'Kode unik Depo yang otomatis berelasi ke distributor_code pada baris yang sama. Ulangi jika Depo memiliki banyak Area.'],
                ['depo_name', 'WAJIB', 'Teks', 'Depo Surabaya Timur', 'Nama cabang / Depo milik Distributor tersebut'],
                ['area_code', 'WAJIB', 'Teks Unik', 'AR01', 'Kode unik Area yang otomatis berelasi ke depo_code pada baris yang sama'],
                ['area_name', 'WAJIB', 'Teks', 'Rungkut & Sekitarnya', 'Nama Area operasional di bawah Depo tersebut'],
            ],
            'master_target_distributor' => [
                ['period', 'WAJIB', 'YYYYMM / YYYY', '202610', 'Periode target 6 digit (contoh: 202610) atau 4 digit tahun (contoh: 2026 untuk otomatis 12 bulan)'],
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode Distributor sesuai Master Distributor'],
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode Depo sesuai Master Depo'],
                ['area_code', 'OPSIONAL', 'Teks (Kode)', 'AR01', 'Kosongkan untuk Target Level DEPO (ASM). Isi kode Area (contoh: AR01) untuk Target Level AREA (SPV).'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode Brand produk sesuai Master Brand (contoh: BRD01, BRD02)'],
                ['metrik_target', 'WAJIB', 'SELL_OUT / SELL_IN / AO', 'SELL_OUT', 'Metrik kuota target: SELL_OUT, SELL_IN, atau AO (Active Outlet)'],
                ['target_quota', 'WAJIB', 'Angka / Desimal', '3000', 'Besaran kuota target volume (Kg/Box) atau jumlah toko jika metrik AO'],
                ['target_outlet', 'OPSIONAL', 'Angka Bulat', '50', 'Target jumlah toko Active Outlet (AO) pendamping'],
                ['username', 'OPSIONAL', 'Teks (Username)', 'budi_asm', 'Username sales penanggung jawab (jika dikosongkan, otomatis mengikuti penugasan ASM/SPV aktif)'],
            ],
            'depo' => [
                ['code', 'WAJIB', 'Teks Unik', 'DP03', 'Kode unik depo (jika sudah ada, data akan diperbarui)'],
                ['name', 'WAJIB', 'Teks', 'Depo Malang Raya', 'Nama cabang / depo distributor'],
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode distributor induk yang membawahi depo ini'],
            ],
            'area' => [
                ['code', 'WAJIB', 'Teks Unik', 'AR03', 'Kode unik area operasional (jika sudah ada, data akan diperbarui)'],
                ['name', 'WAJIB', 'Teks', 'Area Sidoarjo Kota', 'Nama area operasional sales'],
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode depo induk yang membawahi area ini'],
            ],
            default => [],
        };
    }

    public function styles(Worksheet $sheet): array
    {
        return [
            1 => ['font' => ['bold' => true, 'size' => 13]],
            4 => ['font' => ['bold' => true, 'size' => 11]],
            5 => [
                'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => '1E293B'],
                ],
            ],
        ];
    }
}

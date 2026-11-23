<?php

namespace App\Exports;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IndustriCustomer;
use App\Models\MasterTarget;
use App\Models\Region;
use App\Models\SellinDistributor;
use App\Models\SellinIndustri;
use App\Models\SelloutDistributor;
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
    protected bool $withData;
    protected ?string $period;
    protected ?int $distributorId;
    protected ?int $brandId;
    protected ?int $depoId;

    public function __construct(
        string $entity,
        bool $withData = false,
        ?string $period = null,
        ?int $distributorId = null,
        ?int $brandId = null,
        ?int $depoId = null
    ) {
        $this->entity = BatchImportService::normalizeEntity($entity);
        $this->withData = $withData;
        $this->period = $period;
        $this->distributorId = $distributorId;
        $this->brandId = $brandId;
        $this->depoId = $depoId;
    }

    public function sheets(): array
    {
        return [
            new BulkUploadDataSheet($this->entity, $this->withData, $this->period, $this->distributorId, $this->brandId, $this->depoId),
            new BulkUploadGuideSheet($this->entity),
        ];
    }
}

class BulkUploadDataSheet implements FromArray, ShouldAutoSize, WithHeadings, WithStyles, WithTitle
{
    public function __construct(
        protected string $entity,
        protected bool $withData = false,
        protected ?string $period = null,
        protected ?int $distributorId = null,
        protected ?int $brandId = null,
        protected ?int $depoId = null
    ) {}

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
                'Faktur',
                'Tanggal',
                'Bulan',
                'KodeDistributor',
                'NamaDistributor',
                'Depo',
                'AreaCode',
                'KodeCustomer',
                'NamaCustomer',
                'Alamat',
                'JenisBarang',
                'JenisSales',
                'ITM',
                'NamaBarang',
                'Barang',
                'SalesKg',
                'DPP',
                'Kota/Kab',
                'Kecamatan',
                'SalesmanDist',
                'PIC',
                'TipeOutlet',
            ],
            'sellin_industri' => [
                'customer_code',
                'customer_name',
                'username',
                'period',
                'volume_kg',
                'nominal',
                'is_noo',
                'sap_so_no',
            ],
            'industri_customer' => [
                'customer_code',
                'customer_name',
                'city',
                'customer_type',
                'first_transaction_period',
                'sales_username',
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
            'master_target_depo' => [
                'period',
                'distributor_code',
                'depo_code',
                'brand_code',
                'metrik_target',
                'target_quota',
                'target_outlet',
                'username',
            ],
            'master_target_area', 'master_target_distributor' => [
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
        if ($this->withData) {
            $realData = $this->getRealData();
            if (! empty($realData)) {
                return $realData;
            }
        }

        return match ($this->entity) {
            'sellin_distributor' => [
                ['DST01', 'BRD01', '202610', 15000, 375000000, 'SAP-SI-202610-010'],
                ['DST01', 'BRD02', '202610', 8500, 212500000, 'SAP-SI-202610-011'],
            ],
            'sellout_distributor' => [
                [
                    'INV/07/26/0001',
                    '2026-07-01',
                    7,
                    'C110003678',
                    'INDO PRIMA, CV',
                    'PONTIANAK',
                    'AR00100',
                    'CUST-0001',
                    'MARI MART',
                    'JL. DR. WAHIDIN ( UJUNG BANGET )',
                    'KAPAL',
                    'SELL OUT',
                    'B13',
                    'KOP 150 @ 3KG / BAL',
                    'GARAM CAP KAPAL 150GR @3KG/BAL',
                    3,
                    20670,
                    'PONTIANAK',
                    '',
                    'JACKY CHEDORRY',
                    'DANNY',
                    'RETAIL',
                ],
                [
                    '0318/07/26',
                    '2026-07-03',
                    7,
                    'C110003678',
                    'INDO PRIMA, CV',
                    'PONTIANAK',
                    'AR00100',
                    'HKC0001',
                    'HKC PLASTIK',
                    'JL. JURUSAN ANJUNGAN SETELAH KANTOR CAMAT',
                    'KAPAL',
                    'SELL OUT',
                    'B13',
                    'KOP 150 @ 3KG / BAL',
                    'GARAM CAP KAPAL 150GR @3KG/BAL',
                    3,
                    20670,
                    'SEI PINYU',
                    '',
                    'JACKY CHEDORRY',
                    'DANNY',
                    'RETAIL',
                ],
            ],
            'sellin_industri' => [
                ['CUST-IND-01', 'PT Roti Nusantara Jaya', 'andre_spv', '202611', 50000, 750000000, '0', 'SO-IND-202611-201'],
                ['CUST-IND-02', 'CV Biskuit Makmur Sentosa', 'andre_spv', '202611', 10000, 160000000, '1', 'SO-IND-202611-202'],
            ],
            'industri_customer' => [
                ['CUST-IND-01', 'PT Roti Nusantara Jaya', 'Surabaya', 'EXISTING', '202504', 'andre_spv'],
                ['CUST-IND-02', 'CV Biskuit Makmur Sentosa', 'Sidoarjo', 'NEW', '', 'andre_spv'],
            ],
            'sellout_sales_surabaya' => [
                ['eko_surabaya', 'admin', '202610', 3200, 38],
                ['eko_surabaya', 'admin', '202610', 2100, 25],
            ],
            'distributor' => [
                ['EAST', 'DST01', 'PT Sumber Rejeki Utama', 'DP01', 'Depo Surabaya Timur', 'AR01', 'Rungkut & Sekitarnya'],
                ['EAST', 'DST01', 'PT Sumber Rejeki Utama', 'DP01', 'Depo Surabaya Timur', 'AR02', 'Area B2 (Tenggilis)'],
                ['EAST', 'DST01', 'PT Sumber Rejeki Utama', 'DP02', 'Depo A2 - Surabaya Barat', 'AR03', 'Tandes & Margomulyo'],
                ['WEST', 'DST02', 'PT Maju Bersama Distribusi', 'DP03', 'Depo Semarang Pusat', 'AR04', 'Simpang Lima & Sekitarnya'],
            ],
            'master_target_depo' => [
                ['202610', 'DST01', 'DP01', 'BRD01', 'SELL_OUT', 5000, 50, 'budi_asm'],
                ['202610', 'DST01', 'DP01', 'BRD01', 'SELL_IN', 5000, '', 'budi_asm'],
                ['202610', 'DST01', 'DP02', 'BRD02', 'SELL_OUT', 4000, 40, 'budi_asm'],
            ],
            'master_target_area' => [
                ['202610', 'DST01', 'DP01', 'AR01', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
                ['202610', 'DST01', 'DP01', 'AR02', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
                ['202610', 'DST01', 'DP02', 'AR03', 'BRD02', 'SELL_OUT', 1500, 20, 'rian_spv'],
            ],
            'master_target_distributor' => [
                ['202610', 'DST01', 'DP01', '', 'BRD01', 'SELL_IN', 5000, '', 'budi_asm'],
                ['202610', 'DST01', 'DP01', 'AR01', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
                ['202610', 'DST01', 'DP01', 'AR02', 'BRD01', 'SELL_OUT', 1500, 25, 'rian_spv'],
                ['202610', 'DST01', 'DP02', '', 'BRD02', 'SELL_IN', 4000, '', 'budi_asm'],
                ['202610', 'DST01', 'DP02', 'AR03', 'BRD02', 'SELL_OUT', 1500, 20, 'rian_spv'],
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

    private function getRealData(): array
    {
        return match ($this->entity) {
            'master_target_distributor', 'master_target_depo', 'master_target_area' => $this->getMasterTargetData(),
            'distributor' => $this->getDistributorData(),
            'sellin_distributor' => $this->getSellinDistributorData(),
            'sellout_distributor' => $this->getSelloutDistributorData(),
            'sellin_industri' => $this->getSellinIndustriData(),
            'industri_customer' => $this->getIndustriCustomerData(),
            default => [],
        };
    }

    private function parsePeriodList(): array
    {
        $raw = trim((string) $this->period);
        if ($raw === '' || strtoupper($raw) === 'ALL') {
            return [];
        }

        return collect(explode(',', $raw))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->sort()
            ->values()
            ->all();
    }

    private function getMasterTargetData(): array
    {
        $periodList = $this->parsePeriodList();
        $q = MasterTarget::with(['distributor', 'depo', 'area', 'brand', 'user'])
            ->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR']);

        if (! empty($periodList)) {
            $q->whereIn('period', $periodList);
        }
        if ($this->distributorId) {
            $q->where('distributor_id', $this->distributorId);
        }
        if ($this->depoId) {
            $q->where('depo_id', $this->depoId);
        }
        if ($this->brandId) {
            $q->where('brand_id', $this->brandId);
        }

        return $q->orderBy('period')
            ->orderBy('distributor_id')
            ->orderBy('depo_id')
            ->orderByRaw('CASE WHEN level = \'DEPO\' THEN 0 ELSE 1 END')
            ->orderBy('area_id')
            ->get()
            ->map(function ($t) {
                return [
                    (string) $t->period,
                    $t->distributor?->code ?? '',
                    $t->depo?->code ?? '',
                    $t->area?->code ?? '',
                    $t->brand?->code ?? '',
                    $t->metrik_target ?? 'SELL_IN',
                    (float) $t->target_quota,
                    $t->level === 'AREA' ? ($t->target_outlet ?? '') : '',
                    $t->user?->username ?? '',
                ];
            })
            ->toArray();
    }

    private function getDistributorData(): array
    {
        $areas = Area::with(['depo.distributor.region'])->get();
        $rows = [];
        foreach ($areas as $a) {
            $depo = $a->depo;
            $dist = $depo?->distributor;
            $reg = $dist?->region;
            $rows[] = [
                $reg?->code ?? '',
                $dist?->code ?? '',
                $dist?->name ?? '',
                $depo?->code ?? '',
                $depo?->name ?? '',
                $a->code ?? '',
                $a->name ?? '',
            ];
        }

        return $rows;
    }

    private function getSellinDistributorData(): array
    {
        $q = SellinDistributor::with(['distributor', 'brand']);
        $periodList = $this->parsePeriodList();
        if (! empty($periodList)) {
            $q->whereIn('period', $periodList);
        }

        return $q->get()->map(function ($s) {
            return [
                $s->distributor?->code ?? '',
                $s->brand?->code ?? '',
                $s->period,
                (float) $s->volume_kg,
                (float) $s->nominal,
                $s->sap_doc_no ?? '',
            ];
        })->toArray();
    }

    private function getSellinIndustriData(): array
    {
        $q = SellinIndustri::with(['user', 'industriCustomer']);
        $periodList = $this->parsePeriodList();
        if (! empty($periodList)) {
            $q->whereIn('period', $periodList);
        }

        return $q->get()->map(function ($s) {
            $volKg = (float) ($s->volume_kg > 0 ? $s->volume_kg : $s->tonase);
            return [
                $s->industriCustomer?->customer_code ?? ($s->customer_code ?? ''),
                $s->industriCustomer?->customer_name ?? $s->customer_name,
                $s->user?->username ?? '',
                $s->period,
                $volKg,
                (float) ($s->nominal ?? 0),
                $s->is_noo === null ? '' : ($s->is_noo ? '1' : '0'),
                $s->sap_so_no ?? '',
            ];
        })->toArray();
    }

    private function getIndustriCustomerData(): array
    {
        return IndustriCustomer::with(['assignments' => fn ($q) => $q->where('is_active', true)->with('user')])
            ->orderBy('customer_name')
            ->get()
            ->map(function ($c) {
                $firstAssign = $c->assignments->first();
                return [
                    $c->customer_code,
                    $c->customer_name,
                    $c->city ?? '',
                    $c->customer_type,
                    $c->first_transaction_period ?? '',
                    $firstAssign?->user?->username ?? '',
                ];
            })
            ->toArray();
    }

    private function getSelloutDistributorData(): array
    {
        $q = SelloutDistributor::with(['distributor', 'depo', 'area', 'brand']);
        $periodList = $this->parsePeriodList();
        if (! empty($periodList)) {
            $q->whereIn('period', $periodList);
        }

        return $q->get()->map(function ($s) {
            $txDate = $s->transaction_date ? $s->transaction_date->format('Y-m-d') : '';
            $bulan = $s->bulan ?? ($s->period ? (int) substr((string) $s->period, 4, 2) : '');

            return [
                $s->faktur ?? '',
                $txDate,
                $bulan,
                $s->depo?->code ?? ($s->distributor?->code ?? ''),
                $s->distributor?->name ?? '',
                $s->depo?->name ?? '',
                $s->area?->code ?? '',
                $s->customer_code ?? '',
                $s->customer_name ?? '',
                $s->alamat ?? '',
                $s->brand?->code ?? ($s->brand?->name ?? ''),
                $s->jenis_sales ?? 'SELL OUT',
                $s->item_code ?? '',
                $s->item_name ?? '',
                $s->item_desc ?? '',
                (float) $s->volume_kg,
                (float) ($s->nominal ?? 0),
                $s->kota_kab ?? '',
                $s->kecamatan ?? '',
                $s->salesman_dist ?? '',
                $s->pic ?? '',
                $s->tipe_outlet ?? '',
            ];
        })->toArray();
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

        // Distributors (maksimal 200 sampel referensi agar file template tetap ringan)
        $rows[] = [''];
        $rows[] = ['C. KODE DISTRIBUTOR (distributor_code)'];
        $rows[] = ['distributor_code', 'Nama Distributor', 'distributor_id'];
        foreach (Distributor::orderBy('code')->limit(200)->get(['id', 'code', 'name']) as $d) {
            $rows[] = [$d->code, $d->name, $d->id];
        }

        // Depos
        $rows[] = [''];
        $rows[] = ['D. KODE DEPO (depo_code)'];
        $rows[] = ['depo_code', 'Nama Depo', 'Kode Distributor Induk', 'depo_id'];
        foreach (Depo::with('distributor:id,code')->orderBy('code')->limit(200)->get(['id', 'code', 'name', 'distributor_id']) as $dp) {
            $rows[] = [$dp->code, $dp->name, $dp->distributor?->code ?? '-', $dp->id];
        }

        // Areas
        $rows[] = [''];
        $rows[] = ['E. KODE AREA & RELASI DEPO / DISTRIBUTOR (AreaCode)'];
        $rows[] = ['AreaCode', 'Nama Area', 'Depo', 'KodeDistributor (SAP Depo)', 'NamaDistributor', 'area_id'];
        foreach (Area::with('depo.distributor')->orderBy('code')->limit(300)->get() as $ar) {
            $rows[] = [
                $ar->code,
                $ar->name,
                $ar->depo?->name ?? '-',
                $ar->depo?->code ?? '-',
                $ar->depo?->distributor?->name ?? '-',
                $ar->id,
            ];
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
                ['Faktur', 'WAJIB', 'Teks', '1983-07-26', 'Nomor faktur penjualan/retur distributor (tidak boleh kosong)'],
                ['Tanggal', 'WAJIB', 'Tanggal (YYYY-MM-DD)', '2026-07-01', 'Tanggal faktur valid (wajib format YYYY-MM-DD atau DD/MM/YYYY)'],
                ['Bulan', 'WAJIB', 'Angka Bulat (1-12)', '7', 'Bulan transaksi 1 s/d 12 (wajib sinkron dengan bulan pada kolom Tanggal)'],
                ['KodeDistributor', 'WAJIB', 'Teks (Kode)', 'C110003678', 'Kode SAP Depo/Distributor sesuai Master Distributor (wajib sinkron dengan AreaCode)'],
                ['NamaDistributor', 'WAJIB', 'Teks', 'INDO PRIMA, CV', 'Nama perusahaan Distributor sesuai Master Distributor (wajib sinkron dengan AreaCode)'],
                ['Depo', 'WAJIB', 'Teks', 'PONTIANAK', 'Nama atau kode Depo sesuai Master Depo (wajib sinkron dengan AreaCode)'],
                ['AreaCode', 'WAJIB', 'Teks (Kode Area)', 'AR00100', 'Kode Area sesuai Master Distributor & Area (lihat daftar di bawah, wajib sinkron dengan Depo & Distributor)'],
                ['KodeCustomer', 'WAJIB', 'Teks (Kode)', '1932-03-01', 'Kode toko/outlet pembeli (digunakan untuk perhitungan Active Outlet / AO unik)'],
                ['NamaCustomer', 'WAJIB', 'Teks', 'MARI MART', 'Nama toko/outlet pembeli (tidak boleh kosong)'],
                ['Alamat', 'WAJIB', 'Teks', 'JL. DR. WAHIDIN', 'Alamat toko/outlet pembeli (tidak boleh kosong)'],
                ['JenisBarang', 'WAJIB', 'Teks (Kode Brand)', 'KAPAL', 'Kode/nama Brand sesuai Master Brand (contoh: KAPAL, JEMPOL, TANGAN, LAYAR, GARAMI)'],
                ['JenisSales', 'WAJIB', 'SELL OUT', 'SELL OUT', 'Wajib berisi SELL OUT'],
                ['ITM', 'WAJIB', 'Teks (Kode Item)', 'B13', 'Kode item produk (tidak boleh kosong)'],
                ['NamaBarang', 'WAJIB', 'Teks', 'KOP 150 @ 3KG / BAL', 'Nama kemasan barang (tidak boleh kosong)'],
                ['Barang', 'WAJIB', 'Teks', 'GARAM CAP KAPAL 150GR @3KG/BAL', 'Deskripsi lengkap barang (tidak boleh kosong)'],
                ['SalesKg', 'WAJIB', 'Angka / Desimal', '3', 'Volume penjualan dalam Kg (positif untuk penjualan, negatif untuk retur, tidak boleh 0)'],
                ['DPP', 'WAJIB', 'Angka / Desimal', '20670', 'Nilai penjualan sebelum pajak (Rupiah)'],
                ['Kota/Kab', 'WAJIB', 'Teks', 'PONTIANAK', 'Kota / Kabupaten lokasi outlet (tidak boleh kosong)'],
                ['Kecamatan', 'OPSIONAL', 'Teks', '', 'Kecamatan lokasi outlet (boleh dikosongkan jika tidak tersedia)'],
                ['SalesmanDist', 'WAJIB', 'Teks', 'JACKY CHEDORRY', 'Nama salesman distributor (tidak boleh kosong)'],
                ['PIC', 'WAJIB', 'Teks', 'DANNY', 'Nama PIC (tidak boleh kosong)'],
                ['TipeOutlet', 'WAJIB', 'Teks', 'RETAIL', 'Tipe outlet (contoh: RETAIL, MINI MARKET, GROSIR, SEMI GROSIR, END USER)'],
            ],
            'sellin_industri' => [
                ['customer_code', 'OPSIONAL', 'Teks (Kode)', 'CUST-IND-01', 'Kode Customer Industri sesuai Master Customer Industri (utama untuk relasi & deteksi NOO)'],
                ['customer_name', 'WAJIB', 'Teks', 'PT Roti Nusantara Jaya', 'Nama pelanggan / pabrik B2B industri'],
                ['username', 'OPSIONAL', 'Teks (Username)', 'andre_spv', 'Username sales industri (otomatis diambil dari penugasan customer jika dikosongkan)'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202611', 'Periode bulan transaksi (contoh: 202611)'],
                ['volume_kg', 'WAJIB', 'Angka / Desimal', '50000', 'Total volume pembelian dalam satuan Kilogram (Kg) — alias kolom tonase juga didukung'],
                ['nominal', 'OPSIONAL', 'Angka', '750000000', 'Nilai rupiah transaksi (opsional)'],
                ['is_noo', 'OPSIONAL', '1 / 0 / Kosong', '', 'Kosongkan untuk deteksi NOO otomatis (transaksi pertama tahun berjalan). Isi 1 (NOO) atau 0 (Existing) untuk override manual.'],
                ['sap_so_no', 'OPSIONAL', 'Teks', 'SO-IND-202611-201', 'Nomor Sales Order (SO) SAP'],
            ],
            'industri_customer' => [
                ['customer_code', 'WAJIB', 'Teks Unik', 'CUST-IND-01', 'Kode unik Customer Industri'],
                ['customer_name', 'WAJIB', 'Teks', 'PT Roti Nusantara Jaya', 'Nama perusahaan / pabrik Customer Industri'],
                ['city', 'OPSIONAL', 'Teks', 'Surabaya', 'Kota lokasi customer'],
                ['customer_type', 'WAJIB', 'NEW / EXISTING', 'NEW', 'Status customer: NEW (berpotensi NOO saat transaksi pertama) atau EXISTING'],
                ['first_transaction_period', 'OPSIONAL', 'YYYYMM (6 digit)', '202504', 'Periode transaksi pertama historis (kosongkan untuk customer baru)'],
                ['sales_username', 'OPSIONAL', 'Teks (Username)', 'andre_spv', 'Username sales ASM/SPV/ASC untuk auto-assign ke customer ini'],
            ],
            'sellout_sales_surabaya' => [
                ['sales_username', 'WAJIB', 'Teks (Username)', 'eko_surabaya', 'Username sales TO/Canvasing Surabaya (atau gunakan kolom sales_id)'],
                ['coordinator_username', 'OPSIONAL', 'Teks (Username)', 'admin', 'Username koordinator Surabaya (atau gunakan kolom coordinator_id)'],
                ['period', 'WAJIB', 'YYYYMM (6 digit)', '202610', 'Periode bulan transaksi (contoh: 202610)'],
                ['volume', 'WAJIB', 'Angka / Desimal', '3200', 'Total volume penjualan Sell-Out Surabaya (Kg / Box)'],
                ['active_outlet_count', 'WAJIB', 'Angka Bulat', '38', 'Jumlah toko/outlet aktif (Active Outlet / AO)'],
            ],
            'distributor' => [
                ['region_code', 'OPSIONAL', 'Teks (Kode)', 'EAST', 'Kode Region sesuai Master Region (contoh: EAST, WEST)'],
                ['distributor_code', 'WAJIB', 'Teks Unik', 'DST01', 'Kode unik Distributor. Ulangi kode yang sama di baris berikutnya jika memiliki banyak Depo/Area.'],
                ['distributor_name', 'WAJIB', 'Teks', 'PT Sumber Rejeki Utama', 'Nama lengkap perusahaan Distributor'],
                ['depo_code', 'WAJIB', 'Teks Unik', 'DP01', 'Kode unik Depo yang otomatis berelasi ke distributor_code pada baris yang sama. Ulangi jika Depo memiliki banyak Area.'],
                ['depo_name', 'WAJIB', 'Teks', 'Depo Surabaya Timur', 'Nama cabang / Depo milik Distributor tersebut'],
                ['area_code', 'WAJIB', 'Teks Unik', 'AR01', 'Kode unik Area yang otomatis berelasi ke depo_code pada baris yang sama'],
                ['area_name', 'WAJIB', 'Teks', 'Rungkut & Sekitarnya', 'Nama Area operasional di bawah Depo tersebut'],
            ],
            'master_target_depo' => [
                ['period', 'WAJIB', 'YYYYMM / YYYY', '202610', 'Periode target 6 digit (contoh: 202610) atau 4 digit tahun (contoh: 2026 untuk otomatis 12 bulan)'],
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode Distributor sesuai Master Distributor'],
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode Depo sesuai Master Depo'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode Brand produk sesuai Master Brand (contoh: BRD01, BRD02)'],
                ['metrik_target', 'WAJIB', 'SELL_OUT / SELL_IN / AO', 'SELL_OUT', 'Metrik kuota target Depo: SELL_OUT, SELL_IN, atau AO (Active Outlet)'],
                ['target_quota', 'WAJIB', 'Angka / Desimal', '5000', 'Besaran kuota Target Depo (ASM) dalam Kg/Box atau jumlah toko jika metrik AO'],
                ['target_outlet', 'OPSIONAL', 'Angka Bulat', '50', 'Target jumlah toko Active Outlet (AO) Depo'],
                ['username', 'OPSIONAL', 'Teks (Username)', 'budi_asm', 'Username ASM penanggung jawab Depo (otomatis jika dikosongkan)'],
            ],
            'master_target_area' => [
                ['period', 'WAJIB', 'YYYYMM / YYYY', '202610', 'Periode target 6 digit (contoh: 202610) atau 4 digit tahun (contoh: 2026 untuk otomatis 12 bulan)'],
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode Distributor sesuai Master Distributor'],
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode Depo induk dari Area tersebut'],
                ['area_code', 'WAJIB', 'Teks (Kode)', 'AR01', 'Kode Area sesuai Master Area'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode Brand produk sesuai Master Brand (contoh: BRD01, BRD02)'],
                ['metrik_target', 'WAJIB', 'SELL_OUT / SELL_IN / AO', 'SELL_OUT', 'Metrik kuota target Area: SELL_OUT, SELL_IN, atau AO (Active Outlet)'],
                ['target_quota', 'WAJIB', 'Angka / Desimal', '1500', 'Besaran kuota Target Area (SPV) dalam Kg/Box atau jumlah toko jika metrik AO'],
                ['target_outlet', 'OPSIONAL', 'Angka Bulat', '25', 'Target jumlah toko Active Outlet (AO) Area'],
                ['username', 'OPSIONAL', 'Teks (Username)', 'rian_spv', 'Username SPV penanggung jawab Area (otomatis jika dikosongkan)'],
            ],
            'master_target_distributor' => [
                ['period', 'WAJIB', 'YYYYMM / YYYY', '202610', 'Periode target 6 digit (contoh: 202610) atau 4 digit tahun (contoh: 2026 untuk otomatis 12 bulan)'],
                ['distributor_code', 'WAJIB', 'Teks (Kode)', 'DST01', 'Kode Distributor sesuai Master Distributor'],
                ['depo_code', 'WAJIB', 'Teks (Kode)', 'DP01', 'Kode Depo sesuai Master Depo'],
                ['area_code', 'OPSIONAL', 'Teks (Kode)', 'AR01', 'KOSONGKAN jika baris ini Target Depo (ASM); ISI kode Area jika baris ini Target Area (SPV)'],
                ['brand_code', 'WAJIB', 'Teks (Kode)', 'BRD01', 'Kode Brand produk sesuai Master Brand (contoh: BRD01, BRD02)'],
                ['metrik_target', 'WAJIB', 'SELL_OUT / SELL_IN / AO', 'SELL_OUT', 'Metrik kuota target: SELL_OUT, SELL_IN, atau AO (Active Outlet)'],
                ['target_quota', 'WAJIB', 'Angka / Desimal', '5000', 'Besaran kuota Target Depo atau Area dalam Kg/Box (atau jumlah toko jika metrik AO)'],
                ['target_outlet', 'OPSIONAL', 'Angka Bulat', '50', 'Target jumlah toko Active Outlet (AO)'],
                ['username', 'OPSIONAL', 'Teks (Username)', 'budi_asm / rian_spv', 'Username ASM (untuk Depo) atau SPV (untuk Area) — otomatis jika dikosongkan'],
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

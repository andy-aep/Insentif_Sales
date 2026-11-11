<?php

error_reporting(E_ALL & ~E_DEPRECATED);
ini_set('memory_limit', '2048M');
set_time_limit(600);

$totalRows = 50000;
$csvFile = __DIR__ . '/templates/template_distributor_50000.csv';
$xlsxFile = __DIR__ . '/templates/template_distributor_50000.xlsx';

echo "Generating $totalRows rows of dummy data...\n";

$distPrefixes = [
    'PT Sumber Rejeki', 'PT Maju Bersama', 'PT Berkah Sejahtera', 'PT Makmur Sentosa',
    'PT Sinar Abadi', 'PT Mitra Sukses', 'PT Mandiri Jaya', 'PT Sejahtera Abadi',
    'PT Cahaya Distribusi', 'PT Prima Distribusi', 'PT Global Niaga', 'PT Utama Mandiri',
    'PT Artha Buana', 'PT Sukses Bersama', 'PT Bintang Nusantara', 'PT Mega Perkasa'
];
$distSuffixes = ['Utama', 'Distrindo', 'Distribusindo', 'Niaga', 'Express', 'Logistik', 'Trade', 'Traders'];

$cities = [
    ['reg' => 'REG01', 'depo' => 'Surabaya Barat', 'areas' => ['Tandes', 'Margomulyo', 'Benowo', 'Lakarsantri', 'Wiyung', 'Darmo', 'Sambikerep']],
    ['reg' => 'REG01', 'depo' => 'Surabaya Timur', 'areas' => ['Rungkut', 'Tenggilis', 'Mulyorejo', 'Sukolilo', 'Kenjeran', 'Kertajaya', 'Tambaksari']],
    ['reg' => 'REG01', 'depo' => 'Sidoarjo', 'areas' => ['Waru', 'Gedangan', 'Buduran', 'Taman', 'Krian', 'Candi', 'Sukodono']],
    ['reg' => 'REG01', 'depo' => 'Malang', 'areas' => ['Klojen', 'Blimbing', 'Lowokwaru', 'Sukun', 'Kedungkandang', 'Singosari', 'Batu']],
    ['reg' => 'REG01', 'depo' => 'Denpasar', 'areas' => ['Denpasar Barat', 'Denpasar Selatan', 'Denpasar Timur', 'Sanur', 'Kuta', 'Ubud', 'Jimbaran']],
    ['reg' => 'REG01', 'depo' => 'Kediri', 'areas' => ['Mojoroto', 'Kota', 'Pesantren', 'Pare', 'Gampengrejo', 'Ngadiluwih', 'Wates']],
    ['reg' => 'REG01', 'depo' => 'Jember', 'areas' => ['Kaliwates', 'Sumbersari', 'Patrang', 'Ambulu', 'Rambipuji', 'Tangul', 'Balung']],

    ['reg' => 'REG02', 'depo' => 'Semarang Pusat', 'areas' => ['Simpang Lima', 'Gajahmungkur', 'Candisari', 'Pedurungan', 'Banyumanik', 'Tembalang', 'Genuk']],
    ['reg' => 'REG02', 'depo' => 'Solo / Surakarta', 'areas' => ['Laweyan', 'Serengan', 'Pasar Kliwon', 'Jebres', 'Banjarsari', 'Palur', 'Kartasura']],
    ['reg' => 'REG02', 'depo' => 'Yogyakarta', 'areas' => ['Malioboro', 'Kotagede', 'Gondomanan', 'Umbulharjo', 'Depok Sleman', 'Bantul', 'Sleman']],
    ['reg' => 'REG02', 'depo' => 'Purwokerto', 'areas' => ['Purwokerto Barat', 'Purwokerto Timur', 'Purwokerto Selatan', 'Sokaraja', 'Banyumas', 'Baturraden']],
    ['reg' => 'REG02', 'depo' => 'Tegal', 'areas' => ['Tegal Barat', 'Tegal Timur', 'Tegal Selatan', 'Margadana', 'Slawi', 'Brebes', 'Adiwerna']],
    ['reg' => 'REG02', 'depo' => 'Magelang', 'areas' => ['Magelang Utara', 'Magelang Tengah', 'Magelang Selatan', 'Mertoyudan', 'Muntilan', 'Secang']],

    ['reg' => 'REG03', 'depo' => 'Jakarta Pusat', 'areas' => ['Menteng', 'Gambir', 'Kemayoran', 'Tanah Abang', 'Senen', 'Cempaka Putih', 'Johar Baru']],
    ['reg' => 'REG03', 'depo' => 'Jakarta Barat', 'areas' => ['Kebon Jeruk', 'Grogol', 'Cengkareng', 'Kembangan', 'Taman Sari', 'Kalideres', 'Palmerah']],
    ['reg' => 'REG03', 'depo' => 'Jakarta Selatan', 'areas' => ['Kebayoran Baru', 'Tebet', 'Cilandak', 'Pasar Minggu', 'Pancoran', 'Setiabudi', 'Mampang']],
    ['reg' => 'REG03', 'depo' => 'Bandung Pusat', 'areas' => ['Cicendo', 'Coblong', 'Sumur Bandung', 'Batununggal', 'Lengkong', 'Sukajadi', 'Andir']],
    ['reg' => 'REG03', 'depo' => 'Bekasi', 'areas' => ['Bekasi Barat', 'Bekasi Timur', 'Bekasi Selatan', 'Rawalumbu', 'Tambun', 'Cikarang', 'Pondok Gede']],
    ['reg' => 'REG03', 'depo' => 'Tangerang', 'areas' => ['Karawaci', 'Cipondoh', 'Cikokol', 'Serpong', 'BSD City', 'Bintaro', 'Ciledug']],
    ['reg' => 'REG03', 'depo' => 'Bogor', 'areas' => ['Bogor Tengah', 'Bogor Barat', 'Bogor Selatan', 'Cibinong', 'Sentul', 'Baranangsiang', 'Tajur']]
];

$areasPerDepo = 10;
$deposPerDist = 5;
$totalDepos = $totalRows / $areasPerDepo; // 5000
$totalDists = $totalDepos / $deposPerDist; // 1000

echo "Structure: $totalDists Distributors, $totalDepos Depos, $totalRows Areas\n";

$csvHandle = fopen($csvFile, 'w');
fputcsv($csvHandle, ['region_code', 'distributor_code', 'distributor_name', 'depo_code', 'depo_name', 'area_code', 'area_name'], escape: "\\");

$areaCounter = 1;
$depoCounter = 1;
$distCounter = 1;

for ($d = 1; $d <= $totalDists; $d++) {
    $cityInfo = $cities[($d - 1) % count($cities)];
    $regCode = $cityInfo['reg'];
    $distCode = 'DST' . str_pad($d, 4, '0', STR_PAD_LEFT);
    $prefix = $distPrefixes[($d - 1) % count($distPrefixes)];
    $suffix = $distSuffixes[(int)(($d - 1) / count($distPrefixes)) % count($distSuffixes)];
    $distName = "$prefix $suffix $d";

    for ($dp = 1; $dp <= $deposPerDist; $dp++) {
        $depoCode = 'DP' . str_pad($depoCounter, 5, '0', STR_PAD_LEFT);
        $depoCity = $cities[($depoCounter - 1) % count($cities)];
        $depoName = "Depo {$depoCity['depo']} " . (int)(($depoCounter - 1) / count($cities) + 1);

        for ($ar = 1; $ar <= $areasPerDepo; $ar++) {
            $areaCode = 'AR' . str_pad($areaCounter, 5, '0', STR_PAD_LEFT);
            $areaPool = $depoCity['areas'];
            $baseAreaName = $areaPool[($ar - 1) % count($areaPool)];
            $secNum = (int)(($ar - 1) / count($areaPool) + 1);
            $areaName = "$baseAreaName Sektor $secNum";

            fputcsv($csvHandle, [
                $regCode,
                $distCode,
                $distName,
                $depoCode,
                $depoName,
                $areaCode,
                $areaName
            ], escape: "\\");

            $areaCounter++;
        }
        $depoCounter++;
    }
    $distCounter++;
}

fclose($csvHandle);
echo "CSV created successfully: $csvFile (Rows: " . ($areaCounter - 1) . ")\n";

// Generate XLSX
echo "Starting XLSX generation...\n";
$start = microtime(true);

require __DIR__ . '/BE/vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Style\Fill;

$spreadsheet = new Spreadsheet();

// Sheet 1: Data Upload
$sheetData = $spreadsheet->getActiveSheet();
$sheetData->setTitle('Data Upload');

// Set headers
$headers = ['region_code', 'distributor_code', 'distributor_name', 'depo_code', 'depo_name', 'area_code', 'area_name'];
$sheetData->fromArray([$headers], null, 'A1');

$sheetData->getStyle('A1:G1')->applyFromArray([
    'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
    'fill' => [
        'fillType' => Fill::FILL_SOLID,
        'startColor' => ['rgb' => '4F46E5'],
    ],
]);

$csvIn = fopen($csvFile, 'r');
fgetcsv($csvIn, escape: "\\"); // skip header

$chunkSize = 10000;
$chunk = [];
$currentRow = 2;

while (($row = fgetcsv($csvIn, escape: "\\")) !== false) {
    $chunk[] = $row;
    if (count($chunk) >= $chunkSize) {
        $sheetData->fromArray($chunk, null, 'A' . $currentRow);
        $currentRow += count($chunk);
        $chunk = [];
        echo "Loaded $currentRow rows into sheet...\n";
    }
}
if (!empty($chunk)) {
    $sheetData->fromArray($chunk, null, 'A' . $currentRow);
    $currentRow += count($chunk);
    $chunk = [];
}
fclose($csvIn);

// Sheet 2: Panduan & Kode Referensi
$guideSheet = $spreadsheet->createSheet();
$guideSheet->setTitle('Panduan & Kode Referensi');

$guideRows = [
    ['PANDUAN PENGISIAN TEMPLATE UPLOAD (DISTRIBUTOR)'],
    ['Catatan Penting: Sistem hanya membaca Sheet 1 ("Data Upload"). Jangan mengubah nama kolom di baris 1 Sheet "Data Upload".'],
    [''],
    ['1. DAFTAR KOLOM & ATURAN PENGISIAN'],
    ['Nama Kolom', 'Status', 'Tipe / Format', 'Contoh Nilai', 'Keterangan / Aturan'],
    ['region_code', 'OPSIONAL', 'Teks (Kode)', 'REG01', 'Kode Region sesuai Master Region (contoh: REG01, REG02, REG03)'],
    ['distributor_code', 'WAJIB', 'Teks Unik', 'DST01', 'Kode unik Distributor. Ulangi kode yang sama di baris berikutnya jika memiliki banyak Depo/Area.'],
    ['distributor_name', 'WAJIB', 'Teks', 'PT Sumber Rejeki Utama', 'Nama lengkap perusahaan Distributor'],
    ['depo_code', 'WAJIB', 'Teks Unik', 'DP01', 'Kode unik Depo yang otomatis berelasi ke distributor_code pada baris yang sama. Ulangi jika Depo memiliki banyak Area.'],
    ['depo_name', 'WAJIB', 'Teks', 'Depo Surabaya Timur', 'Nama cabang / Depo milik Distributor tersebut'],
    ['area_code', 'WAJIB', 'Teks Unik', 'AR01', 'Kode unik Area yang otomatis berelasi ke depo_code pada baris yang sama'],
    ['area_name', 'WAJIB', 'Teks', 'Rungkut & Sekitarnya', 'Nama Area operasional di bawah Depo tersebut'],
    [''],
    ['2. DAFTAR KODE REFERENSI MASTER DATA AKTIF DI DATABASE'],
    [''],
    ['A. KODE BRAND (brand_code)'],
    ['brand_code', 'Nama Brand', 'brand_id'],
    ['BRD01', 'Indoprima Dairy', 1],
    ['BRD02', 'Indoprima Sweet', 2],
    [''],
    ['B. KODE REGION (region_code)'],
    ['region_code', 'Nama Region', 'region_id'],
    ['REG01', 'Jawa Timur & Bali', 1],
    ['REG02', 'Jawa Tengah & DIY', 2],
    ['REG03', 'Jawa Barat & DKI', 3],
    [''],
    ['C. KODE DISTRIBUTOR (distributor_code)'],
    ['distributor_code', 'Nama Distributor', 'distributor_id'],
    ['DST01', 'PT Sumber Rejeki Utama', 1],
    ['DST02', 'PT Maju Bersama Distribusi', 3],
    [''],
    ['D. KODE DEPO (depo_code)'],
    ['depo_code', 'Nama Depo', 'Kode Distributor Induk', 'depo_id'],
    ['DP01', 'Depo Surabaya Timur', 'DST01', 1],
    ['DP02', 'Depo A2 - Surabaya Barat', 'DST01', 4],
    ['DP03', 'Depo Semarang Pusat', 'DST02', 5],
    [''],
    ['E. KODE AREA (depo_code -> area_code)'],
    ['area_code', 'Nama Area', 'Kode Depo Induk', 'area_id'],
    ['AR01', 'Rungkut & Sekitarnya', 'DP01', 1],
    ['AR02', 'Area B2 (Tenggilis)', 'DP01', 5],
    ['AR03', 'Tandes & Margomulyo', 'DP02', 6],
    ['AR04', 'Simpang Lima & Sekitarnya', 'DP03', 7],
    [''],
    ['F. DAFTAR USERNAME & ID USER / SALES'],
    ['username', 'Nama Lengkap', 'Jabatan / Position', 'user_id'],
    ['admin', 'Administrator', 'Admin / All', 1],
    ['budi_asm', 'Budi Santoso (ASM)', 'Area Sales Manager', 2],
    ['dewi_industri', 'Dewi Lestari (Industri)', 'Sales Supervisor', 3],
    ['eko_surabaya', 'Eko Prasetyo (TO Surabaya)', 'Sales Taking Order', 4],
    ['rian_spv', 'Rian Pratama (SPV Konsumsi)', 'Sales Supervisor', 5],
    ['hendra_nsm', 'Hendra Pratama (NSM Barat)', 'National Sales Manager', 6],
    ['suryadi_lsm', 'Suryadi (LSM Jatim & Bali)', 'Line / Local Sales Manager', 7],
    ['bambang_nsm', 'Bambang Wijaya (NSM Timur)', 'National Sales Manager', 8],
    ['agus_lsm', 'Agus Setiawan (LSM Jabar & DKI)', 'Line / Local Sales Manager', 9]
];

$guideSheet->fromArray($guideRows, null, 'A1');

$spreadsheet->setActiveSheetIndex(0);

echo "Saving XLSX file...\n";
$writer = new Xlsx($spreadsheet);
$writer->setPreCalculateFormulas(false);
$writer->save($xlsxFile);

$duration = round(microtime(true) - $start, 2);
echo "XLSX created successfully: $xlsxFile in {$duration}s\n";

<?php

namespace App\Services;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\MasterTarget;
use App\Models\Region;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SellinIndustri;
use App\Models\SelloutDistributor;
use App\Models\SelloutSalesSurabaya;
use App\Models\UploadBatch;
use App\Models\User;
use Exception;
use Generator;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Concerns\Import;
use Maatwebsite\Excel\Facades\Excel;
use Throwable;
use XMLReader;
use ZipArchive;

class BatchImportService
{
    public static function normalizeEntity(string $entity): string
    {
        return match (strtolower(trim($entity))) {
            'sell_in_distributor', 'sellin_distributor' => 'sellin_distributor',
            'sell_out_distributor', 'sellout_distributor' => 'sellout_distributor',
            'sell_in_industri', 'sellin_industri' => 'sellin_industri',
            'sell_out_surabaya', 'sellout_surabaya', 'sellout_sales_surabaya' => 'sellout_sales_surabaya',
            'distributors', 'distributor' => 'distributor',
            'master_target_depo', 'target_depo' => 'master_target_depo',
            'master_target_area', 'target_area' => 'master_target_area',
            'master_target_distributor', 'master_targets', 'target_distributor' => 'master_target_distributor',
            'depos', 'depo' => 'depo',
            'areas', 'area' => 'area',
            default => strtolower(trim($entity)),
        };
    }

    public function createBatch(string $entityType, string $fileName, int $userId): UploadBatch
    {
        return UploadBatch::create([
            'id' => (string) Str::uuid(),
            'entity_type' => self::normalizeEntity($entityType),
            'file_name' => $fileName,
            'status' => 'PROCESSING',
            'uploaded_by' => $userId,
        ]);
    }

    /**
     * Memproses file upload skala besar (50.000 - 500.000+ baris) menggunakan
     * Streaming XML/CSV Reader (O(1) RAM) dan Bulk Chunked SQL Insert/Upsert.
     */
    public function processFile(UploadBatch $batch, UploadedFile|string $file): UploadBatch
    {
        if (function_exists('set_time_limit')) {
            @set_time_limit(0);
        }
        @ini_set('max_execution_time', '0');
        @ini_set('memory_limit', '2048M');
        DB::disableQueryLog();

        $filePath = $file instanceof UploadedFile ? $file->getRealPath() : (string) $file;
        $ext = strtolower($file instanceof UploadedFile ? $file->getClientOriginalExtension() : pathinfo($filePath, PATHINFO_EXTENSION));

        try {
            $generator = $this->streamRows($filePath, $ext);

            if (! $generator->valid()) {
                $batch->update(['status' => 'COMPLETED', 'total_rows' => 0, 'success_rows' => 0, 'failed_rows' => 0]);

                return $batch;
            }

            // Ambil baris pertama sebagai header
            $rawHeader = $generator->current();
            $generator->next();

            $header = [];
            foreach ($rawHeader as $idx => $col) {
                $clean = strtolower(trim((string) $col));
                // Hapus UTF-8 BOM jika ada di kolom pertama CSV
                if ($idx === 0) {
                    $clean = preg_replace('/^\xEF\xBB\xBF/', '', $clean);
                }
                if ($clean !== '') {
                    $header[$idx] = $clean;
                }
            }

            if (empty($header)) {
                $batch->update(['status' => 'COMPLETED', 'total_rows' => 0, 'success_rows' => 0, 'failed_rows' => 0]);

                return $batch;
            }

            // Deteksi otomatis tipe entitas berdasarkan kolom header jika user salah pilih dropdown
            $entityType = $this->detectEntityFromHeader($header, $batch->entity_type);
            if ($entityType !== $batch->entity_type) {
                $batch->entity_type = $entityType;
                $batch->save();
            }

            [$totalRows, $successCount, $failedCount] = match ($entityType) {
                'distributor' => $this->processDistributorBulk($generator, $header, $batch->id),
                'sellout_distributor' => $this->processSelloutDistributorBulk($generator, $header, $batch->id),
                'master_target_depo' => $this->processMasterTargetDistributorBulk($generator, $header, 'DEPO', $batch->id),
                'master_target_area' => $this->processMasterTargetDistributorBulk($generator, $header, 'AREA', $batch->id),
                'master_target_distributor' => $this->processMasterTargetDistributorBulk($generator, $header, null, $batch->id),
                'sellin_distributor' => $this->processSellinDistributorBulk($generator, $header, $batch->id),
                'sellin_industri' => $this->processSellinIndustriBulk($generator, $header, $batch->id),
                'sellout_sales_surabaya' => $this->processSelloutSurabayaBulk($generator, $header, $batch->id),
                'depo' => $this->processDepoBulk($generator, $header, $batch->id),
                'area' => $this->processAreaBulk($generator, $header, $batch->id),
                default => [0, 0, 0],
            };

            $batch->update([
                'total_rows' => $totalRows,
                'success_rows' => $successCount,
                'failed_rows' => $failedCount,
                'status' => 'COMPLETED',
            ]);

            return $batch;
        } catch (Throwable $e) {
            $batch->update([
                'status' => 'FAILED',
            ]);
            throw new Exception($e->getMessage(), (int) $e->getCode(), $e);
        }
    }

    /**
     * Auto-detect modul apabila header file jelas milik template lain
     */
    protected function detectEntityFromHeader(array $header, string $currentEntity): string
    {
        $cols = array_values($header);

        if (in_array('metrik_target', $cols, true) || in_array('target_quota', $cols, true)) {
            if (in_array($currentEntity, ['master_target_depo', 'master_target_area', 'master_target_distributor'], true)) {
                return $currentEntity;
            }

            return 'master_target_distributor';
        }

        if (in_array('distributor_name', $cols, true) || in_array('depo_name', $cols, true) || in_array('area_name', $cols, true)) {
            return 'distributor';
        }

        if (in_array('depo_code', $cols, true) && in_array('volume_kg', $cols, true) && in_array('active_outlet_count', $cols, true)) {
            return 'sellout_distributor';
        }

        return self::normalizeEntity($currentEntity);
    }

    /**
     * Streaming generator untuk membaca .xlsx (via ZipArchive + XMLReader) atau .csv (via fgetcsv)
     * tanpa memuat seluruh file ke dalam RAM.
     */
    protected function streamRows(string $filePath, string $ext): Generator
    {
        if (in_array($ext, ['csv', 'txt'], true)) {
            yield from $this->streamCsvRows($filePath);

            return;
        }

        if ($ext === 'xlsx' && class_exists(ZipArchive::class) && class_exists(XMLReader::class)) {
            $zip = new ZipArchive;
            if ($zip->open($filePath) === true) {
                $zip->close();
                yield from $this->streamXlsxRows($filePath);

                return;
            }
        }

        // Fallback untuk format .xls lawas
        $sheets = Excel::toArray(new class implements Import {}, $filePath);
        foreach ($sheets[0] ?? [] as $row) {
            yield $row;
        }
    }

    protected function streamCsvRows(string $filePath): Generator
    {
        $handle = fopen($filePath, 'rb');
        if (! $handle) {
            return;
        }

        // Deteksi delimiter (, atau ;) dari baris pertama
        $firstLine = fgets($handle);
        if ($firstLine === false) {
            fclose($handle);

            return;
        }
        $delimiter = substr_count($firstLine, ';') > substr_count($firstLine, ',') ? ';' : ',';
        rewind($handle);

        while (($row = fgetcsv($handle, 0, $delimiter)) !== false) {
            if ($row === [null]) {
                continue;
            }
            yield $row;
        }

        fclose($handle);
    }

    protected function streamXlsxRows(string $filePath): Generator
    {
        $zip = new ZipArchive;
        if ($zip->open($filePath) !== true) {
            return;
        }

        // 1. Baca tabel Shared Strings (xl/sharedStrings.xml) ke array indeks
        $sharedStrings = [];
        if ($zip->locateName('xl/sharedStrings.xml') !== false) {
            $ssReader = new XMLReader;
            $ssUri = 'zip://'.$filePath.'#xl/sharedStrings.xml';
            if (@$ssReader->open($ssUri, null, LIBXML_NONET | LIBXML_COMPACT)) {
                $currentSi = '';
                $inSi = false;
                while ($ssReader->read()) {
                    if ($ssReader->nodeType === XMLReader::ELEMENT) {
                        if ($ssReader->localName === 'si') {
                            $currentSi = '';
                            $inSi = true;
                            if ($ssReader->isEmptyElement) {
                                $sharedStrings[] = '';
                                $inSi = false;
                            }
                        } elseif ($inSi && $ssReader->localName === 't') {
                            $currentSi .= $ssReader->readString();
                        }
                    } elseif ($ssReader->nodeType === XMLReader::END_ELEMENT && $ssReader->localName === 'si') {
                        $sharedStrings[] = $currentSi;
                        $inSi = false;
                    }
                }
                $ssReader->close();
            }
        }

        // 2. Tentukan lokasi worksheet pertama (default xl/worksheets/sheet1.xml)
        $sheetEntry = 'xl/worksheets/sheet1.xml';
        if ($zip->locateName($sheetEntry) === false) {
            for ($i = 0; $i < $zip->numFiles; $i++) {
                $name = $zip->getNameIndex($i);
                if (str_starts_with($name, 'xl/worksheets/sheet') && str_ends_with($name, '.xml')) {
                    $sheetEntry = $name;
                    break;
                }
            }
        }
        $zip->close();

        // 3. Stream baris demi baris (<row>) dari worksheet pertama dengan state machine XMLReader murni
        $sheetReader = new XMLReader;
        $sheetUri = 'zip://'.$filePath.'#'.$sheetEntry;
        if (! @$sheetReader->open($sheetUri, null, LIBXML_NONET | LIBXML_COMPACT)) {
            return;
        }

        $cells = [];
        $maxCol = -1;
        $colIdx = 0;
        $cellType = '';
        $cellVal = '';
        $inCell = false;

        while ($sheetReader->read()) {
            if ($sheetReader->nodeType === XMLReader::ELEMENT) {
                $name = $sheetReader->localName;
                if ($name === 'row') {
                    $cells = [];
                    $maxCol = -1;
                } elseif ($name === 'c') {
                    $ref = $sheetReader->getAttribute('r') ?? '';
                    $colIdx = $ref !== '' ? $this->colRefToIndex($ref) : ($maxCol + 1);
                    $cellType = $sheetReader->getAttribute('t') ?? '';
                    $cellVal = '';
                    if ($sheetReader->isEmptyElement) {
                        $inCell = false;
                    } else {
                        $inCell = true;
                    }
                } elseif ($inCell && ($name === 'v' || $name === 't')) {
                    $text = $sheetReader->readString();
                    if ($cellType === 's') {
                        $cellVal = $sharedStrings[(int) $text] ?? '';
                    } else {
                        $cellVal .= $text;
                    }
                }
            } elseif ($sheetReader->nodeType === XMLReader::END_ELEMENT) {
                $name = $sheetReader->localName;
                if ($name === 'c') {
                    $cells[$colIdx] = $cellVal;
                    if ($colIdx > $maxCol) {
                        $maxCol = $colIdx;
                    }
                    $inCell = false;
                } elseif ($name === 'row') {
                    if ($maxCol >= 0) {
                        $row = [];
                        for ($i = 0; $i <= $maxCol; $i++) {
                            $row[$i] = $cells[$i] ?? null;
                        }
                        yield $row;
                    }
                }
            }
        }

        $sheetReader->close();
    }

    protected function colRefToIndex(string $cellRef): int
    {
        $colIndex = 0;
        $len = strlen($cellRef);
        for ($i = 0; $i < $len; $i++) {
            $ch = ord($cellRef[$i]);
            if ($ch >= 65 && $ch <= 90) {
                $colIndex = $colIndex * 26 + ($ch - 64);
            } elseif ($ch >= 97 && $ch <= 122) {
                $colIndex = $colIndex * 26 + ($ch - 96);
            } else {
                break;
            }
        }

        return max(0, $colIndex - 1);
    }

    protected function mapRow(array $header, array $rawRow): ?array
    {
        $hasValue = false;
        $row = [];
        foreach ($header as $idx => $colName) {
            $val = $rawRow[$idx] ?? null;
            if ($val !== null && trim((string) $val) !== '') {
                $hasValue = true;
            }
            $row[$colName] = $val;
        }

        return $hasValue ? $row : null;
    }

    /**
     * 1. BULK IMPORT: Master Distributor, Depo & Area (Sekaligus & Berelasi)
     */
    protected function processDistributorBulk(Generator $generator, array $header, ?string $batchId = null): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $regionMap = array_change_key_case(Region::pluck('id', 'code')->all(), CASE_UPPER);
        $existingDistMap = array_change_key_case(Distributor::pluck('name', 'code')->all(), CASE_UPPER);
        $existingDepoMap = array_change_key_case(Depo::pluck('name', 'code')->all(), CASE_UPPER);
        $existingAreaMap = array_change_key_case(Area::pluck('name', 'code')->all(), CASE_UPPER);

        $uniqueDistributors = [];
        $uniqueDepos = [];
        $uniqueAreas = [];
        $now = now()->format('Y-m-d H:i:s');

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $distCode = trim((string) ($row['distributor_code'] ?? $row['code'] ?? ''));
            $distName = trim((string) ($row['distributor_name'] ?? $row['name'] ?? ''));
            $regCode = strtoupper(trim((string) ($row['region_code'] ?? '')));

            if ($distCode === '') {
                $failedCount++;
                continue;
            }

            $distKey = strtoupper($distCode);
            if ($distName === '') {
                $distName = $uniqueDistributors[$distKey]['name'] ?? $existingDistMap[$distKey] ?? '';
            }
            if ($distName === '') {
                $failedCount++;
                continue;
            }

            $regionId = $row['region_id'] ?? ($regCode !== '' ? ($regionMap[$regCode] ?? null) : null);

            $uniqueDistributors[$distKey] = [
                'batch_id' => $batchId,
                'code' => $distCode,
                'name' => $distName,
                'region_id' => $regionId ?? ($uniqueDistributors[$distKey]['region_id'] ?? null),
                'created_at' => $now,
                'updated_at' => $now,
            ];

            $depoCode = trim((string) ($row['depo_code'] ?? ''));
            $depoName = trim((string) ($row['depo_name'] ?? ''));
            if ($depoCode !== '') {
                $depoKey = strtoupper($depoCode);
                if ($depoName === '') {
                    $depoName = $uniqueDepos[$depoKey]['name'] ?? $existingDepoMap[$depoKey] ?? $depoCode;
                }
                $uniqueDepos[$depoKey] = [
                    'batch_id' => $batchId,
                    'code' => $depoCode,
                    'name' => $depoName,
                    'dist_key' => $distKey,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];

                $areaCode = trim((string) ($row['area_code'] ?? ''));
                $areaName = trim((string) ($row['area_name'] ?? ''));
                if ($areaCode !== '') {
                    $areaKey = strtoupper($areaCode);
                    if ($areaName === '') {
                        $areaName = $uniqueAreas[$areaKey]['name'] ?? $existingAreaMap[$areaKey] ?? $areaCode;
                    }
                    $uniqueAreas[$areaKey] = [
                        'batch_id' => $batchId,
                        'code' => $areaCode,
                        'name' => $areaName,
                        'depo_key' => $depoKey,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }

            $successCount++;
        }

        // Eksekusi Bulk Upsert Hierarki dalam Chunk 1.000
        DB::transaction(function () use ($uniqueDistributors, $uniqueDepos, $uniqueAreas, $batchId) {
            if (! empty($uniqueDistributors)) {
                foreach (array_chunk(array_values($uniqueDistributors), 1000) as $chunk) {
                    DB::table('distributors')->upsert($chunk, ['code'], ['name', 'region_id', 'batch_id', 'updated_at']);
                }
            }

            $distIdMap = array_change_key_case(DB::table('distributors')->pluck('id', 'code')->all(), CASE_UPPER);

            if (! empty($uniqueDepos)) {
                $depoRows = [];
                foreach ($uniqueDepos as $d) {
                    $distId = $distIdMap[$d['dist_key']] ?? null;
                    if ($distId) {
                        $depoRows[] = [
                            'batch_id' => $batchId,
                            'code' => $d['code'],
                            'name' => $d['name'],
                            'distributor_id' => $distId,
                            'created_at' => $d['created_at'],
                            'updated_at' => $d['updated_at'],
                        ];
                    }
                }
                foreach (array_chunk($depoRows, 1000) as $chunk) {
                    DB::table('depos')->upsert($chunk, ['code'], ['name', 'distributor_id', 'batch_id', 'updated_at']);
                }
            }

            $depoIdMap = array_change_key_case(DB::table('depos')->pluck('id', 'code')->all(), CASE_UPPER);

            if (! empty($uniqueAreas)) {
                $areaRows = [];
                foreach ($uniqueAreas as $a) {
                    $depoId = $depoIdMap[$a['depo_key']] ?? null;
                    if ($depoId) {
                        $areaRows[] = [
                            'batch_id' => $batchId,
                            'code' => $a['code'],
                            'name' => $a['name'],
                            'depo_id' => $depoId,
                            'created_at' => $a['created_at'],
                            'updated_at' => $a['updated_at'],
                        ];
                    }
                }
                foreach (array_chunk($areaRows, 1000) as $chunk) {
                    DB::table('areas')->upsert($chunk, ['code'], ['name', 'depo_id', 'batch_id', 'updated_at']);
                }
            }
        });

        return [$totalRows, $successCount, $failedCount];
    }

    /**
     * 2. BULK IMPORT: Transaksi Sell-Out Distributor (100k - 500k+ baris)
     */
    protected function processSelloutDistributorBulk(Generator $generator, array $header, string $batchId): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $depoMap = array_change_key_case(DB::table('depos')->pluck('id', 'code')->all(), CASE_UPPER);
        $brandMap = array_change_key_case(DB::table('brands')->pluck('id', 'code')->all(), CASE_UPPER);
        $defaultPeriod = date('Ym');
        $now = now()->format('Y-m-d H:i:s');

        $chunk = [];
        $chunkSize = 2500;

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $depoId = $row['depo_id'] ?? null;
            if (! $depoId && ! empty($row['depo_code'])) {
                $depoId = $depoMap[strtoupper(trim((string) $row['depo_code']))] ?? null;
            }

            $brandId = $row['brand_id'] ?? null;
            if (! $brandId && ! empty($row['brand_code'])) {
                $brandId = $brandMap[strtoupper(trim((string) $row['brand_code']))] ?? null;
            }

            if (! $depoId || ! $brandId) {
                $failedCount++;
                continue;
            }

            $chunk[] = [
                'batch_id' => $batchId,
                'depo_id' => (int) $depoId,
                'brand_id' => (int) $brandId,
                'period' => substr(trim((string) ($row['period'] ?? $defaultPeriod)), 0, 6),
                'volume_kg' => (float) ($row['volume_kg'] ?? 0),
                'active_outlet_count' => (int) ($row['active_outlet_count'] ?? 0),
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;

            if (count($chunk) >= $chunkSize) {
                DB::table('sellout_distributors')->insert($chunk);
                $chunk = [];
            }
        }

        if (! empty($chunk)) {
            DB::table('sellout_distributors')->insert($chunk);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    /**
     * 3. BULK IMPORT: Master Target Depo / Area (100k - 500k+ baris)
     */
    protected function processMasterTargetDistributorBulk(Generator $generator, array $header, ?string $forcedLevel = null, ?string $batchId = null): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $distMap = array_change_key_case(DB::table('distributors')->pluck('id', 'code')->all(), CASE_UPPER);

        $depoMap = [];
        foreach (DB::table('depos')->get(['id', 'code', 'distributor_id']) as $d) {
            $depoMap[strtoupper($d->code)] = ['id' => $d->id, 'distributor_id' => $d->distributor_id];
        }

        $areaMap = [];
        foreach (DB::table('areas')->get(['id', 'code', 'depo_id']) as $a) {
            $areaMap[strtoupper($a->code)] = ['id' => $a->id, 'depo_id' => $a->depo_id];
        }

        $brandMap = array_change_key_case(DB::table('brands')->pluck('id', 'code')->all(), CASE_UPPER);
        $userMap = array_change_key_case(DB::table('users')->pluck('id', 'username')->all(), CASE_LOWER);

        // Preload ASM per distributor dan SPV per area
        $asmByDist = [];
        $spvByArea = [];
        $assignments = SalesDistributorAssignment::with('user.position')->where('is_active', true)->get();
        foreach ($assignments as $assign) {
            if ($assign->area_id) {
                $spvByArea[$assign->area_id] = $assign->user_id;
            }
            if ($assign->distributor_id && strtoupper($assign->user?->position?->code ?? '') === 'ASM') {
                $asmByDist[$assign->distributor_id] = $assign->user_id;
            }
        }

        $defaultPeriod = date('Ym');
        $now = now()->format('Y-m-d H:i:s');
        $dedupTargets = [];
        $affectedPeriods = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $distributorId = $row['distributor_id'] ?? null;
            if (! $distributorId && ! empty($row['distributor_code'])) {
                $distributorId = $distMap[strtoupper(trim((string) $row['distributor_code']))] ?? null;
            }

            $depoId = $row['depo_id'] ?? null;
            if (! $depoId && ! empty($row['depo_code'])) {
                $depoInfo = $depoMap[strtoupper(trim((string) $row['depo_code']))] ?? null;
                if ($depoInfo) {
                    $depoId = $depoInfo['id'];
                    if (! $distributorId) {
                        $distributorId = $depoInfo['distributor_id'];
                    }
                }
            }

            $areaId = null;
            if ($forcedLevel !== 'DEPO') {
                $areaId = $row['area_id'] ?? null;
                if (! $areaId && ! empty($row['area_code'])) {
                    $areaInfo = $areaMap[strtoupper(trim((string) $row['area_code']))] ?? null;
                    if ($areaInfo) {
                        $areaId = $areaInfo['id'];
                        if (! $depoId) {
                            $depoId = $areaInfo['depo_id'];
                        }
                    }
                }
            }

            $brandId = $row['brand_id'] ?? null;
            if (! $brandId && ! empty($row['brand_code'])) {
                $brandId = $brandMap[strtoupper(trim((string) $row['brand_code']))] ?? null;
            }

            if (! $distributorId || ! $depoId || ! $brandId) {
                $failedCount++;
                continue;
            }

            if ($forcedLevel === 'AREA' && ! $areaId) {
                $failedCount++;
                continue;
            }

            $rawMetrik = strtoupper(trim((string) ($row['metrik_target'] ?? $row['target_type'] ?? 'SELL_OUT')));
            $metrik = match ($rawMetrik) {
                'SELL-OUT', 'SELL_OUT', 'SELLOUT' => 'SELL_OUT',
                'SELL-IN', 'SELL_IN', 'SELLIN' => 'SELL_IN',
                'AO', 'ACTIVE_OUTLET', 'OUTLET' => 'AO',
                default => $rawMetrik,
            };

            $level = $forcedLevel ?? ($areaId ? 'AREA' : 'DEPO');
            if ($level === 'DEPO') {
                $areaId = null;
            }

            $rawPeriod = trim((string) ($row['period'] ?? $defaultPeriod));
            $periods = [];
            if (strlen($rawPeriod) === 4 && ctype_digit($rawPeriod)) {
                for ($m = 1; $m <= 12; $m++) {
                    $periods[] = sprintf('%04d%02d', (int) $rawPeriod, $m);
                }
            } else {
                $periods[] = substr($rawPeriod, 0, 6);
            }

            $userId = $row['user_id'] ?? null;
            $username = $row['username'] ?? $row['sales_username'] ?? null;
            if (! $userId && ! empty($username)) {
                $cleanUname = strtolower(trim((string) $username));
                if ($cleanUname === 'sulistyo') {
                    $cleanUname = 'sulis';
                }
                if ($cleanUname !== 'vacant') {
                    $userId = $userMap[$cleanUname] ?? null;
                    if (! $userId) {
                        $posId = $level === 'AREA' ? 2 : 1; // 1: ASM, 2: SPV
                        $newUserId = DB::table('users')->insertGetId([
                            'name' => ucwords(str_replace(['.', '_', '-'], ' ', $cleanUname)),
                            'username' => $cleanUname,
                            'email' => $cleanUname . '@company.com',
                            'password' => bcrypt('password123'),
                            'role_id' => 3, // Sales
                            'position_id' => $posId,
                            'aktif_from' => '2024-01-01',
                            'is_eligible_konsumsi' => 1,
                            'is_eligible_industri' => 0,
                            'is_eligible_surabaya' => 0,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                        $userMap[$cleanUname] = $newUserId;
                        $userId = $newUserId;
                    }
                }
            }
            if (! $userId) {
                $userId = $level === 'AREA'
                    ? ($areaId ? ($spvByArea[$areaId] ?? null) : null)
                    : ($asmByDist[$distributorId] ?? null);
            }

            $targetQuota = (float) ($row['target_quota'] ?? ($level === 'AREA' ? ($row['target_area'] ?? 0) : ($row['target_depo'] ?? 0)));
            $targetOutlet = isset($row['target_outlet']) && $row['target_outlet'] !== ''
                ? (int) $row['target_outlet']
                : ($metrik === 'AO' ? (int) $targetQuota : null);

            foreach ($periods as $p) {
                $affectedPeriods[$p] = true;
                $compKey = "{$p}|{$metrik}|{$distributorId}|{$depoId}|".($areaId ?? 0)."|{$brandId}";
                $dedupTargets[$compKey] = [
                    'batch_id' => $batchId,
                    'period' => $p,
                    'kategori_skema' => 'KONSUMSI',
                    'metrik_target' => $metrik,
                    'distributor_id' => (int) $distributorId,
                    'depo_id' => (int) $depoId,
                    'area_id' => $areaId ? (int) $areaId : null,
                    'brand_id' => (int) $brandId,
                    'level' => $level,
                    'target_quota' => $targetQuota,
                    'target_outlet' => $targetOutlet,
                    'user_id' => $userId ? (int) $userId : null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }

            $successCount++;
        }

        if (! empty($dedupTargets)) {
            $existingMap = [];
            foreach (array_chunk(array_keys($affectedPeriods), 50) as $pChunk) {
                $existingRows = DB::table('master_targets')
                    ->where('kategori_skema', 'KONSUMSI')
                    ->whereIn('period', $pChunk)
                    ->get(['id', 'period', 'metrik_target', 'distributor_id', 'depo_id', 'area_id', 'brand_id']);

                foreach ($existingRows as $er) {
                    $k = "{$er->period}|{$er->metrik_target}|{$er->distributor_id}|{$er->depo_id}|".($er->area_id ?? 0)."|{$er->brand_id}";
                    $existingMap[$k] = $er->id;
                }
            }

            $toInsert = [];
            $toUpdate = [];
            foreach ($dedupTargets as $k => $item) {
                if (isset($existingMap[$k])) {
                    $item['id'] = $existingMap[$k];
                    $toUpdate[] = $item;
                } else {
                    $toInsert[] = $item;
                }
            }

            DB::transaction(function () use ($toInsert, $toUpdate) {
                foreach (array_chunk($toInsert, 1500) as $chunk) {
                    DB::table('master_targets')->insert($chunk);
                }
                foreach (array_chunk($toUpdate, 1500) as $chunk) {
                    DB::table('master_targets')->upsert(
                        $chunk,
                        ['id'],
                        ['batch_id', 'level', 'target_quota', 'target_outlet', 'user_id', 'updated_at']
                    );
                }
            });

            // Auto-sinkronisasi penugasan sales distributor ke tabel sales_distributor_assignments
            foreach ($dedupTargets as $targetData) {
                if (empty($targetData['user_id'])) continue;
                $uId = (int) $targetData['user_id'];
                $distId = (int) $targetData['distributor_id'];
                $p = $targetData['period'];
                $lvl = $targetData['level'];
                $aId = $targetData['area_id'];
                $dpId = $targetData['depo_id'];

                if ($lvl === 'DEPO') {
                    SalesDistributorAssignment::updateOrCreate(
                        [
                            'user_id' => $uId,
                            'distributor_id' => $distId,
                            'period' => $p,
                        ],
                        [
                            'is_active' => true,
                            'notes' => 'Imported via Master Target',
                        ]
                    );
                } elseif ($lvl === 'AREA' && $aId) {
                    SalesDistributorAssignment::updateOrCreate(
                        [
                            'user_id' => $uId,
                            'area_id' => (int) $aId,
                            'period' => $p,
                        ],
                        [
                            'distributor_id' => $distId,
                            'depo_id' => (int) $dpId,
                            'is_active' => true,
                            'notes' => 'Imported via Master Target',
                        ]
                    );
                }
            }
        }

        return [$totalRows, $successCount, $failedCount];
    }

    protected function processSellinDistributorBulk(Generator $generator, array $header, string $batchId): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $distMap = array_change_key_case(DB::table('distributors')->pluck('id', 'code')->all(), CASE_UPPER);
        $brandMap = array_change_key_case(DB::table('brands')->pluck('id', 'code')->all(), CASE_UPPER);
        $defaultPeriod = date('Ym');
        $now = now()->format('Y-m-d H:i:s');
        $chunk = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $distId = $row['distributor_id'] ?? ($distMap[strtoupper(trim((string) ($row['distributor_code'] ?? '')))] ?? null);
            $brandId = $row['brand_id'] ?? ($brandMap[strtoupper(trim((string) ($row['brand_code'] ?? '')))] ?? null);

            if (! $distId || ! $brandId) {
                $failedCount++;
                continue;
            }

            $chunk[] = [
                'batch_id' => $batchId,
                'distributor_id' => (int) $distId,
                'brand_id' => (int) $brandId,
                'period' => substr(trim((string) ($row['period'] ?? $defaultPeriod)), 0, 6),
                'volume_kg' => (float) ($row['volume_kg'] ?? 0),
                'nominal' => (float) ($row['nominal'] ?? 0),
                'sap_doc_no' => isset($row['sap_doc_no']) ? trim((string) $row['sap_doc_no']) : null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;

            if (count($chunk) >= 2500) {
                DB::table('sellin_distributors')->insert($chunk);
                $chunk = [];
            }
        }

        if (! empty($chunk)) {
            DB::table('sellin_distributors')->insert($chunk);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    protected function processSellinIndustriBulk(Generator $generator, array $header, string $batchId): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $userMap = array_change_key_case(DB::table('users')->pluck('id', 'username')->all(), CASE_LOWER);
        $defaultPeriod = date('Ym');
        $now = now()->format('Y-m-d H:i:s');
        $chunk = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $username = strtolower(trim((string) ($row['username'] ?? $row['sales_username'] ?? '')));
            $userId = $row['user_id'] ?? ($userMap[$username] ?? null);
            if (! $userId) {
                $failedCount++;
                continue;
            }

            $chunk[] = [
                'batch_id' => $batchId,
                'user_id' => (int) $userId,
                'customer_name' => trim((string) ($row['customer_name'] ?? 'General Customer')),
                'period' => substr(trim((string) ($row['period'] ?? $defaultPeriod)), 0, 6),
                'tonase' => (float) ($row['tonase'] ?? 0),
                'sap_so_no' => isset($row['sap_so_no']) ? trim((string) $row['sap_so_no']) : null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;

            if (count($chunk) >= 2500) {
                DB::table('sellin_industris')->insert($chunk);
                $chunk = [];
            }
        }

        if (! empty($chunk)) {
            DB::table('sellin_industris')->insert($chunk);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    protected function processSelloutSurabayaBulk(Generator $generator, array $header, string $batchId): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;

        $userMap = array_change_key_case(DB::table('users')->pluck('id', 'username')->all(), CASE_LOWER);
        $defaultPeriod = date('Ym');
        $now = now()->format('Y-m-d H:i:s');
        $chunk = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $salesUname = strtolower(trim((string) ($row['sales_username'] ?? $row['username'] ?? '')));
            $salesId = $row['sales_id'] ?? ($userMap[$salesUname] ?? null);
            if (! $salesId) {
                $failedCount++;
                continue;
            }

            $coordUname = strtolower(trim((string) ($row['coordinator_username'] ?? '')));
            $coordId = $row['coordinator_id'] ?? ($coordUname !== '' ? ($userMap[$coordUname] ?? null) : null);

            $chunk[] = [
                'batch_id' => $batchId,
                'coordinator_id' => $coordId ? (int) $coordId : null,
                'sales_id' => (int) $salesId,
                'period' => substr(trim((string) ($row['period'] ?? $defaultPeriod)), 0, 6),
                'volume' => (float) ($row['volume'] ?? 0),
                'active_outlet_count' => (int) ($row['active_outlet_count'] ?? 0),
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;

            if (count($chunk) >= 2500) {
                DB::table('sellout_sales_surabayas')->insert($chunk);
                $chunk = [];
            }
        }

        if (! empty($chunk)) {
            DB::table('sellout_sales_surabayas')->insert($chunk);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    protected function processDepoBulk(Generator $generator, array $header, ?string $batchId = null): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;
        $distMap = array_change_key_case(DB::table('distributors')->pluck('id', 'code')->all(), CASE_UPPER);
        $now = now()->format('Y-m-d H:i:s');
        $uniqueDepos = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $code = trim((string) ($row['code'] ?? ''));
            $name = trim((string) ($row['name'] ?? ''));
            $distId = $row['distributor_id'] ?? ($distMap[strtoupper(trim((string) ($row['distributor_code'] ?? '')))] ?? null);

            if ($code === '' || $name === '' || ! $distId) {
                $failedCount++;
                continue;
            }

            $uniqueDepos[strtoupper($code)] = [
                'batch_id' => $batchId,
                'code' => $code,
                'name' => $name,
                'distributor_id' => (int) $distId,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;
        }

        foreach (array_chunk(array_values($uniqueDepos), 1000) as $chunk) {
            DB::table('depos')->upsert($chunk, ['code'], ['name', 'distributor_id', 'batch_id', 'updated_at']);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    protected function processAreaBulk(Generator $generator, array $header, ?string $batchId = null): array
    {
        $totalRows = 0;
        $successCount = 0;
        $failedCount = 0;
        $depoMap = array_change_key_case(DB::table('depos')->pluck('id', 'code')->all(), CASE_UPPER);
        $now = now()->format('Y-m-d H:i:s');
        $uniqueAreas = [];

        while ($generator->valid()) {
            $rawRow = $generator->current();
            $generator->next();
            $row = $this->mapRow($header, $rawRow);
            if ($row === null) {
                continue;
            }
            $totalRows++;

            $code = trim((string) ($row['code'] ?? ''));
            $name = trim((string) ($row['name'] ?? ''));
            $depoId = $row['depo_id'] ?? ($depoMap[strtoupper(trim((string) ($row['depo_code'] ?? '')))] ?? null);

            if ($code === '' || $name === '' || ! $depoId) {
                $failedCount++;
                continue;
            }

            $uniqueAreas[strtoupper($code)] = [
                'batch_id' => $batchId,
                'code' => $code,
                'name' => $name,
                'depo_id' => (int) $depoId,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $successCount++;
        }

        foreach (array_chunk(array_values($uniqueAreas), 1000) as $chunk) {
            DB::table('areas')->upsert($chunk, ['code'], ['name', 'depo_id', 'batch_id', 'updated_at']);
        }

        return [$totalRows, $successCount, $failedCount];
    }

    public function rollback(string $batchId): bool
    {
        return DB::transaction(function () use ($batchId) {
            $batch = UploadBatch::findOrFail($batchId);

            if ($batch->status === 'ROLLED_BACK') {
                throw new Exception('Batch ini sudah pernah di-rollback.');
            }

            match ($batch->entity_type) {
                'sellin_distributor' => SellinDistributor::where('batch_id', $batchId)->delete(),
                'sellout_distributor' => SelloutDistributor::where('batch_id', $batchId)->delete(),
                'sellin_industri' => SellinIndustri::where('batch_id', $batchId)->delete(),
                'sellout_sales_surabaya' => SelloutSalesSurabaya::where('batch_id', $batchId)->delete(),
                'master_target_depo', 'master_target_area', 'master_target_distributor' => MasterTarget::where('batch_id', $batchId)->delete(),
                'distributor' => $this->rollbackDistributorBatch($batchId),
                'depo' => Depo::where('batch_id', $batchId)->delete(),
                'area' => Area::where('batch_id', $batchId)->delete(),
                default => throw new Exception('Tipe entitas tidak mendukung rollback.'),
            };

            $batch->update([
                'status' => 'ROLLED_BACK',
                'rolled_back_at' => now(),
            ]);

            return true;
        });
    }

    protected function rollbackDistributorBatch(string $batchId): void
    {
        // 1. Hapus target yang berelasi dengan batch ini jika ada
        MasterTarget::where('batch_id', $batchId)->delete();

        // 2. Hapus area, depo, dan distributor dari batch ini
        Area::where('batch_id', $batchId)->delete();
        Depo::where('batch_id', $batchId)->delete();
        Distributor::where('batch_id', $batchId)->delete();
    }
}

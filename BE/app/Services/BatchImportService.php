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
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Concerns\Import;
use Maatwebsite\Excel\Facades\Excel;

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
     * Memproses file upload (Excel atau CSV) sesuai tipe entitas
     */
    public function processFile(UploadBatch $batch, UploadedFile $file): UploadBatch
    {
        $rows = Excel::toArray(new class implements Import {}, $file);
        $data = $rows[0] ?? [];

        if (empty($data)) {
            $batch->update(['status' => 'COMPLETED', 'total_rows' => 0, 'success_rows' => 0]);

            return $batch;
        }

        // Header berada di baris pertama
        $header = array_map(fn ($col) => strtolower(trim((string) $col)), array_shift($data));
        $nonEmptyRows = array_values(array_filter(
            $data,
            fn ($rawRow) => ! empty(array_filter($rawRow, fn ($v) => ! is_null($v) && trim((string) $v) !== ''))
        ));
        $totalRows = count($nonEmptyRows);
        $successCount = 0;
        $failedCount = 0;

        DB::beginTransaction();
        try {
            foreach ($nonEmptyRows as $rawRow) {
                $row = [];
                foreach ($header as $index => $colName) {
                    if ($colName !== '') {
                        $row[$colName] = $rawRow[$index] ?? null;
                    }
                }

                $inserted = $this->insertRow($batch->entity_type, $batch->id, $row);
                if ($inserted) {
                    $successCount++;
                } else {
                    $failedCount++;
                }
            }

            $batch->update([
                'total_rows' => $totalRows,
                'success_rows' => $successCount,
                'failed_rows' => $failedCount,
                'status' => 'COMPLETED',
            ]);

            DB::commit();
        } catch (Exception $e) {
            DB::rollBack();
            $batch->update([
                'status' => 'FAILED',
            ]);
            throw $e;
        }

        return $batch;
    }

    protected function insertRow(string $entityType, string $batchId, array $row): bool
    {
        return match (self::normalizeEntity($entityType)) {
            'sellin_distributor' => $this->insertSellinDistributor($batchId, $row),
            'sellout_distributor' => $this->insertSelloutDistributor($batchId, $row),
            'sellin_industri' => $this->insertSellinIndustri($batchId, $row),
            'sellout_sales_surabaya' => $this->insertSelloutSalesSurabaya($batchId, $row),
            'distributor' => $this->insertDistributor($row),
            'master_target_distributor' => $this->insertMasterTargetDistributor($row),
            'depo' => $this->insertDepo($row),
            'area' => $this->insertArea($row),
            default => false,
        };
    }

    protected function insertSellinDistributor(string $batchId, array $row): bool
    {
        $distributorId = $row['distributor_id'] ?? null;
        if (! $distributorId && ! empty($row['distributor_code'])) {
            $distributorId = Distributor::where('code', trim((string) $row['distributor_code']))->value('id');
        }

        $brandId = $row['brand_id'] ?? null;
        if (! $brandId && ! empty($row['brand_code'])) {
            $brandId = Brand::where('code', trim((string) $row['brand_code']))->value('id');
        }

        if (! $distributorId || ! $brandId) {
            return false;
        }

        SellinDistributor::create([
            'batch_id' => $batchId,
            'distributor_id' => $distributorId,
            'brand_id' => $brandId,
            'period' => trim((string) ($row['period'] ?? date('Ym'))),
            'volume_kg' => (float) ($row['volume_kg'] ?? 0),
            'nominal' => (float) ($row['nominal'] ?? 0),
            'sap_doc_no' => isset($row['sap_doc_no']) ? trim((string) $row['sap_doc_no']) : null,
        ]);

        return true;
    }

    protected function insertSelloutDistributor(string $batchId, array $row): bool
    {
        $depoId = $row['depo_id'] ?? null;
        if (! $depoId && ! empty($row['depo_code'])) {
            $depoId = Depo::where('code', trim((string) $row['depo_code']))->value('id');
        }

        $brandId = $row['brand_id'] ?? null;
        if (! $brandId && ! empty($row['brand_code'])) {
            $brandId = Brand::where('code', trim((string) $row['brand_code']))->value('id');
        }

        if (! $depoId || ! $brandId) {
            return false;
        }

        SelloutDistributor::create([
            'batch_id' => $batchId,
            'depo_id' => $depoId,
            'brand_id' => $brandId,
            'period' => trim((string) ($row['period'] ?? date('Ym'))),
            'volume_kg' => (float) ($row['volume_kg'] ?? 0),
            'active_outlet_count' => (int) ($row['active_outlet_count'] ?? 0),
        ]);

        return true;
    }

    protected function insertSellinIndustri(string $batchId, array $row): bool
    {
        $userId = $row['user_id'] ?? null;
        $username = $row['username'] ?? $row['sales_username'] ?? null;

        if (! $userId && ! empty($username)) {
            $userId = User::where('username', trim((string) $username))->value('id');
        }

        if (! $userId) {
            return false;
        }

        SellinIndustri::create([
            'batch_id' => $batchId,
            'user_id' => $userId,
            'customer_name' => trim((string) ($row['customer_name'] ?? 'General Customer')),
            'period' => trim((string) ($row['period'] ?? date('Ym'))),
            'tonase' => (float) ($row['tonase'] ?? 0),
            'sap_so_no' => isset($row['sap_so_no']) ? trim((string) $row['sap_so_no']) : null,
        ]);

        return true;
    }

    protected function insertSelloutSalesSurabaya(string $batchId, array $row): bool
    {
        $salesId = $row['sales_id'] ?? null;
        $salesUsername = $row['sales_username'] ?? $row['username'] ?? null;

        if (! $salesId && ! empty($salesUsername)) {
            $salesId = User::where('username', trim((string) $salesUsername))->value('id');
        }

        if (! $salesId) {
            return false;
        }

        $coordinatorId = $row['coordinator_id'] ?? null;
        $coordinatorUsername = $row['coordinator_username'] ?? null;
        if (! $coordinatorId && ! empty($coordinatorUsername)) {
            $coordinatorId = User::where('username', trim((string) $coordinatorUsername))->value('id');
        }

        SelloutSalesSurabaya::create([
            'batch_id' => $batchId,
            'coordinator_id' => $coordinatorId ?: null,
            'sales_id' => $salesId,
            'period' => trim((string) ($row['period'] ?? date('Ym'))),
            'volume' => (float) ($row['volume'] ?? 0),
            'active_outlet_count' => (int) ($row['active_outlet_count'] ?? 0),
        ]);

        return true;
    }

    protected function insertDistributor(array $row): bool
    {
        $distCode = trim((string) ($row['distributor_code'] ?? $row['code'] ?? ''));
        $distName = trim((string) ($row['distributor_name'] ?? $row['name'] ?? ''));

        if ($distCode === '') {
            return false;
        }

        $regionId = $row['region_id'] ?? null;
        if (! $regionId && ! empty($row['region_code'])) {
            $regionId = Region::where('code', trim((string) $row['region_code']))->value('id');
        }

        $existingDist = Distributor::where('code', $distCode)->first();
        if (! $existingDist && $distName === '') {
            return false;
        }

        $distPayload = [];
        if ($distName !== '') {
            $distPayload['name'] = $distName;
        }
        if ($regionId) {
            $distPayload['region_id'] = $regionId;
        }

        $distributor = Distributor::updateOrCreate(
            ['code' => $distCode],
            $distPayload
        );

        // Relasi Depo (jika kolom depo_code diisi pada baris yang sama)
        $depoCode = trim((string) ($row['depo_code'] ?? ''));
        $depoName = trim((string) ($row['depo_name'] ?? ''));
        $depo = null;

        if ($depoCode !== '') {
            $existingDepo = Depo::where('code', $depoCode)->first();
            if ($existingDepo || $depoName !== '') {
                $depoPayload = ['distributor_id' => $distributor->id];
                if ($depoName !== '') {
                    $depoPayload['name'] = $depoName;
                }
                $depo = Depo::updateOrCreate(
                    ['code' => $depoCode],
                    $depoPayload
                );
            }
        }

        // Relasi Area (jika kolom area_code diisi pada baris yang sama)
        $areaCode = trim((string) ($row['area_code'] ?? ''));
        $areaName = trim((string) ($row['area_name'] ?? ''));

        if ($areaCode !== '' && $depo) {
            $existingArea = Area::where('code', $areaCode)->first();
            if ($existingArea || $areaName !== '') {
                $areaPayload = ['depo_id' => $depo->id];
                if ($areaName !== '') {
                    $areaPayload['name'] = $areaName;
                }
                Area::updateOrCreate(
                    ['code' => $areaCode],
                    $areaPayload
                );
            }
        }

        return true;
    }

    protected function insertMasterTargetDistributor(array $row): bool
    {
        $distributorId = $row['distributor_id'] ?? null;
        if (! $distributorId && ! empty($row['distributor_code'])) {
            $distributorId = Distributor::where('code', trim((string) $row['distributor_code']))->value('id');
        }

        $depoId = $row['depo_id'] ?? null;
        if (! $depoId && ! empty($row['depo_code'])) {
            $depo = Depo::where('code', trim((string) $row['depo_code']))->first();
            if ($depo) {
                $depoId = $depo->id;
                if (! $distributorId) {
                    $distributorId = $depo->distributor_id;
                }
            }
        }

        $areaId = $row['area_id'] ?? null;
        if (! $areaId && ! empty($row['area_code'])) {
            $area = Area::where('code', trim((string) $row['area_code']))->first();
            if ($area) {
                $areaId = $area->id;
                if (! $depoId) {
                    $depoId = $area->depo_id;
                }
            }
        }

        $brandId = $row['brand_id'] ?? null;
        if (! $brandId && ! empty($row['brand_code'])) {
            $brandId = Brand::where('code', trim((string) $row['brand_code']))->value('id');
        }

        if (! $distributorId || ! $depoId || ! $brandId) {
            return false;
        }

        $rawMetrik = strtoupper(trim((string) ($row['metrik_target'] ?? $row['target_type'] ?? 'SELL_OUT')));
        $metrik = match ($rawMetrik) {
            'SELL-OUT', 'SELL_OUT', 'SELLOUT' => 'SELL_OUT',
            'SELL-IN', 'SELL_IN', 'SELLIN' => 'SELL_IN',
            'AO', 'ACTIVE_OUTLET', 'OUTLET' => 'AO',
            default => $rawMetrik,
        };

        $level = $areaId ? 'AREA' : 'DEPO';
        $rawPeriod = trim((string) ($row['period'] ?? date('Ym')));
        $periods = [];

        if (strlen($rawPeriod) === 4 && ctype_digit($rawPeriod)) {
            for ($m = 1; $m <= 12; $m++) {
                $periods[] = sprintf('%04d%02d', (int) $rawPeriod, $m);
            }
        } else {
            $periods[] = $rawPeriod;
        }

        $userId = $row['user_id'] ?? null;
        $username = $row['username'] ?? $row['sales_username'] ?? null;
        if (! $userId && ! empty($username)) {
            $userId = User::where('username', trim((string) $username))->value('id');
        }

        $targetQuota = (float) ($row['target_quota'] ?? 0);
        $targetOutlet = isset($row['target_outlet']) && $row['target_outlet'] !== ''
            ? (int) $row['target_outlet']
            : ($metrik === 'AO' ? (int) $targetQuota : null);

        foreach ($periods as $p) {
            $resolvedUserId = $userId;
            if (! $resolvedUserId) {
                if ($areaId) {
                    $spvAssign = SalesDistributorAssignment::where('area_id', $areaId)
                        ->where('is_active', true)
                        ->latest()
                        ->first();
                    $resolvedUserId = $spvAssign?->user_id;
                } else {
                    $asmAssign = SalesDistributorAssignment::where('distributor_id', $distributorId)
                        ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                        ->where('is_active', true)
                        ->latest()
                        ->first();
                    $resolvedUserId = $asmAssign?->user_id;
                }
            }

            MasterTarget::updateOrCreate(
                [
                    'period' => $p,
                    'kategori_skema' => 'KONSUMSI',
                    'metrik_target' => $metrik,
                    'distributor_id' => $distributorId,
                    'depo_id' => $depoId,
                    'area_id' => $areaId,
                    'brand_id' => $brandId,
                ],
                [
                    'level' => $level,
                    'target_quota' => $targetQuota,
                    'target_outlet' => $targetOutlet,
                    'user_id' => $resolvedUserId,
                ]
            );
        }

        return true;
    }

    protected function insertDepo(array $row): bool
    {
        $code = trim((string) ($row['code'] ?? ''));
        $name = trim((string) ($row['name'] ?? ''));
        $distributorId = $row['distributor_id'] ?? null;

        if (! $distributorId && ! empty($row['distributor_code'])) {
            $distributorId = Distributor::where('code', trim((string) $row['distributor_code']))->value('id');
        }

        if ($code === '' || $name === '' || ! $distributorId) {
            return false;
        }

        Depo::updateOrCreate(
            ['code' => $code],
            ['name' => $name, 'distributor_id' => $distributorId]
        );

        return true;
    }

    protected function insertArea(array $row): bool
    {
        $code = trim((string) ($row['code'] ?? ''));
        $name = trim((string) ($row['name'] ?? ''));
        $depoId = $row['depo_id'] ?? null;

        if (! $depoId && ! empty($row['depo_code'])) {
            $depoId = Depo::where('code', trim((string) $row['depo_code']))->value('id');
        }

        if ($code === '' || $name === '' || ! $depoId) {
            return false;
        }

        Area::updateOrCreate(
            ['code' => $code],
            ['name' => $name, 'depo_id' => $depoId]
        );

        return true;
    }

    public function rollback(string $batchId): bool
    {
        return DB::transaction(function () use ($batchId) {
            $batch = UploadBatch::findOrFail($batchId);

            if ($batch->status === 'ROLLED_BACK') {
                throw new Exception('Batch ini sudah pernah di-rollback.');
            }

            // Hapus rekaman data transaksi yang terikat dengan batch_id ini
            match ($batch->entity_type) {
                'sellin_distributor' => SellinDistributor::where('batch_id', $batchId)->delete(),
                'sellout_distributor' => SelloutDistributor::where('batch_id', $batchId)->delete(),
                'sellin_industri' => SellinIndustri::where('batch_id', $batchId)->delete(),
                'sellout_sales_surabaya' => SelloutSalesSurabaya::where('batch_id', $batchId)->delete(),
                default => throw new Exception('Tipe entitas tidak mendukung rollback.'),
            };

            $batch->update([
                'status' => 'ROLLED_BACK',
                'rolled_back_at' => now(),
            ]);

            return true;
        });
    }
}

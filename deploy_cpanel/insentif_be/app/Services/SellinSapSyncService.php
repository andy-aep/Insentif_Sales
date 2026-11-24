<?php

namespace App\Services;

use App\Models\BrandItem;
use App\Models\Depo;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class SellinSapSyncService
{
    public function __construct(
        protected SapService $sapService
    ) {}

    /**
     * Auto-sync Sell-In Distributor dari SAP jika data periode sudah melewati TTL (default 15 menit).
     * Aman terhadap SAP downtime (try/catch + backoff 2 menit + lock anti-bentrok).
     */
    public function syncIfStale(string $period, int $ttlMinutes = 15): void
    {
        $cleanPeriod = preg_replace('/[^0-9]/', '', trim($period));
        if (strlen($cleanPeriod) !== 6) {
            return;
        }

        $currentYm = date('Ym');
        $prevYm = date('Ym', strtotime('-1 month'));

        // Hanya auto-sync untuk bulan berjalan, bulan lalu, atau bulan <= berjalan yang masih 0 baris
        if ($cleanPeriod > $currentYm) {
            return;
        }
        $isRecentMonth = ($cleanPeriod === $currentYm || $cleanPeriod === $prevYm);
        if (! $isRecentMonth) {
            $hasRows = SellinDistributor::where('period', $cleanPeriod)->exists();
            if ($hasRows) {
                return;
            }
        }

        $cacheKey = "sap_sellin_synced:{$cleanPeriod}";
        if (Cache::has($cacheKey)) {
            return;
        }

        $lock = Cache::lock("sap_sellin_syncing:{$cleanPeriod}", 45);
        if (! $lock->get()) {
            return;
        }

        try {
            if (Cache::has($cacheKey)) {
                return;
            }

            $result = $this->syncPeriod($cleanPeriod);
            Cache::put($cacheKey, now()->toIso8601String(), now()->addMinutes($ttlMinutes));

            if (($result['created_count'] ?? 0) > 0 || ($result['updated_count'] ?? 0) > 0) {
                Cache::forget("incentive_calc_fresh:KONSUMSI:{$cleanPeriod}");
            }
        } catch (Throwable $e) {
            Log::warning("Auto-sync SAP Sell-In periode {$cleanPeriod} dilewati: {$e->getMessage()}");
            // Backoff singkat 2 menit agar request berikutnya tidak ikut menunggu timeout SAP
            Cache::put($cacheKey, 'backoff', now()->addMinutes(2));
        } finally {
            $lock->release();
        }
    }

    /**
     * Auto-sync beberapa periode sekaligus (maksimal 2 periode per request agar tetap responsif).
     *
     * @param  array<int, string>  $periods
     */
    public function syncPeriodsIfStale(array $periods, int $ttlMinutes = 15): void
    {
        $checked = 0;
        foreach ($periods as $p) {
            if ($checked >= 2) {
                break;
            }
            $clean = preg_replace('/[^0-9]/', '', (string) $p);
            if (strlen($clean) !== 6) {
                continue;
            }
            $this->syncIfStale($clean, $ttlMinutes);
            $checked++;
        }
    }

    /**
     * Eksekusi sinkronisasi penuh Sell-In Distributor dari SAP ke tabel sellin_distributors.
     *
     * @return array<string, mixed>
     */
    public function syncPeriod(
        ?string $period,
        ?string $dateFrom = null,
        ?string $dateTo = null,
        ?string $cardCode = null
    ): array {
        $depos = Depo::all();
        $depoByCode = [];
        foreach ($depos as $d) {
            $depoByCode[strtoupper(trim((string) $d->code))] = $d;
        }

        $cleanCardCode = ! empty($cardCode) ? strtoupper(trim($cardCode)) : null;
        $cardCodes = $cleanCardCode ? null : array_keys($depoByCode);

        $rows = $this->sapService->listSellinDistributor($period, $dateFrom, $dateTo, $cleanCardCode, $cardCodes);

        $brandByItemCode = BrandItem::pluck('brand_id', 'item_code')
            ->mapWithKeys(fn ($brandId, $itemCode) => [strtoupper(trim((string) $itemCode)) => (int) $brandId])
            ->all();

        $activeAssignments = SalesDistributorAssignment::where('is_active', true)
            ->with(['user.position'])
            ->get();
        $depoAssignments = $activeAssignments->whereNotNull('depo_id')->groupBy('depo_id');
        $distAsmAssignments = $activeAssignments
            ->filter(fn ($a) => $a->distributor_id !== null && strtoupper($a->user?->position?->code ?? '') === 'ASM')
            ->groupBy('distributor_id');
        $depoTargets = MasterTarget::where('kategori_skema', 'KONSUMSI')
            ->where('level', 'DEPO')
            ->whereNotNull('user_id')
            ->with('user')
            ->get()
            ->groupBy(fn ($t) => $t->period . '_' . $t->depo_id);

        $createdCount = 0;
        $updatedCount = 0;
        $skippedNoDepo = 0;
        $unmappedItems = [];

        DB::transaction(function () use (
            $rows,
            $depoByCode,
            $brandByItemCode,
            $depoAssignments,
            $distAsmAssignments,
            $depoTargets,
            &$createdCount,
            &$updatedCount,
            &$skippedNoDepo,
            &$unmappedItems
        ) {
            foreach ($rows as $row) {
                $depo = $depoByCode[$row['card_code']] ?? null;
                if (! $depo) {
                    $skippedNoDepo++;
                    continue;
                }

                $itemCode = $row['item_code'];
                $brandId = $itemCode !== '' ? ($brandByItemCode[$itemCode] ?? null) : null;
                if ($itemCode !== '' && ! $brandId) {
                    $unmappedItems[$itemCode] = $row['item_name'] ?: $itemCode;
                }

                $txDate = $row['doc_date'];
                $txPeriod = $row['period'];

                $resolvedUserId = $this->resolveSalesOwnerForDate(
                    (int) $depo->id,
                    (int) $depo->distributor_id,
                    $txPeriod,
                    $txDate,
                    $depoAssignments,
                    $distAsmAssignments,
                    $depoTargets
                );

                $sapDocNo = $row['sap_doc_no'] !== '' ? $row['sap_doc_no'] : null;

                $existing = SellinDistributor::where('period', $txPeriod)
                    ->where('depo_id', $depo->id)
                    ->where('sap_doc_no', $sapDocNo)
                    ->where('item_code', $itemCode !== '' ? $itemCode : null)
                    ->first();

                $payload = [
                    'distributor_id' => (int) $depo->distributor_id,
                    'depo_id' => (int) $depo->id,
                    'user_id' => $resolvedUserId,
                    'sap_slp_code' => $row['slp_code'],
                    'sap_slp_name' => $row['slp_name'] !== '' ? $row['slp_name'] : null,
                    'brand_id' => $brandId,
                    'item_code' => $itemCode !== '' ? $itemCode : null,
                    'item_name' => $row['item_name'] !== '' ? $row['item_name'] : null,
                    'period' => $txPeriod,
                    'transaction_date' => $txDate,
                    'volume_kg' => $row['volume_kg'],
                    'nominal' => $row['nominal'],
                    'sap_doc_no' => $sapDocNo,
                ];

                if ($existing) {
                    $existing->update($payload);
                    $updatedCount++;
                } else {
                    SellinDistributor::create($payload);
                    $createdCount++;
                }
            }
        });

        if ($period && ! $cleanCardCode) {
            Cache::put("sap_sellin_synced:{$period}", now()->toIso8601String(), now()->addMinutes(15));
            Cache::forget("incentive_calc_fresh:KONSUMSI:{$period}");
        }

        return [
            'message' => 'Sinkronisasi Realisasi Sell-In Distributor dari SAP selesai.',
            'total_fetched' => count($rows),
            'created_count' => $createdCount,
            'updated_count' => $updatedCount,
            'skipped_no_depo' => $skippedNoDepo,
            'unmapped_items' => $unmappedItems,
        ];
    }

    private function resolveSalesOwnerForDate(
        int $depoId,
        int $distributorId,
        string $period,
        ?string $txDate,
        $depoAssignments,
        $distAsmAssignments,
        $depoTargets
    ): ?int {
        $isActiveOnDate = function (?User $u) use ($txDate): bool {
            if (! $u) {
                return false;
            }
            if (! $txDate) {
                return true;
            }
            $from = $u->aktif_from ? $u->aktif_from->format('Y-m-d') : null;
            $to = $u->aktif_to ? $u->aktif_to->format('Y-m-d') : null;
            if ($from && $txDate < $from) {
                return false;
            }
            if ($to && $txDate > $to) {
                return false;
            }

            return true;
        };

        $targets = $depoTargets->get($period . '_' . $depoId) ?? collect();
        foreach ($targets as $t) {
            if ($isActiveOnDate($t->user)) {
                return (int) $t->user_id;
            }
        }

        $assigns = $depoAssignments->get($depoId) ?? collect();
        foreach ($assigns as $a) {
            if ((! $a->period || $a->period === $period) && $isActiveOnDate($a->user)) {
                return (int) $a->user_id;
            }
        }

        $distAssigns = $distAsmAssignments->get($distributorId) ?? collect();
        foreach ($distAssigns as $a) {
            if ((! $a->period || $a->period === $period) && $isActiveOnDate($a->user)) {
                return (int) $a->user_id;
            }
        }

        return null;
    }
}

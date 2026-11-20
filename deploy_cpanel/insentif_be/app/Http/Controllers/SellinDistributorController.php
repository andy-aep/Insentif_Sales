<?php

namespace App\Http\Controllers;

use App\Models\BrandItem;
use App\Models\Depo;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\User;
use App\Services\SapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

class SellinDistributorController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $baseQuery = SellinDistributor::query()
            ->when($request->filled('period'), fn ($q) => $q->where('period', trim($request->period)))
            ->when($request->filled('distributor_id'), fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->when($request->filled('depo_id'), fn ($q) => $q->where('depo_id', $request->depo_id))
            ->when($request->filled('brand_id'), fn ($q) => $q->where('brand_id', $request->brand_id))
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = '%' . strtolower(trim((string) $request->q)) . '%';
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(COALESCE(sap_doc_no, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(item_code, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(item_name, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(sap_slp_name, \'\')) LIKE ?', [$term])
                        ->orWhereHas('depo', fn ($d) => $d->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('distributor', fn ($d) => $d->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('brand', fn ($b) => $b->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('user', fn ($u) => $u->whereRaw('LOWER(name) LIKE ?', [$term]));
                });
            });

        $relations = [
            'distributor:id,code,name',
            'depo:id,code,name',
            'brand:id,code,name',
            'user:id,name,username',
        ];

        if ($request->filled('per_page') || $request->boolean('paginate')) {
            $perPage = min(max($request->integer('per_page', 25), 1), 200);
            $summary = (clone $baseQuery)
                ->selectRaw('COUNT(*) as total_rows, COALESCE(SUM(volume_kg), 0) as total_volume_kg, COALESCE(SUM(nominal), 0) as total_nominal')
                ->first();

            $paginated = (clone $baseQuery)
                ->with($relations)
                ->orderByDesc('transaction_date')
                ->latest('id')
                ->paginate($perPage);

            return response()->json([
                'data' => $paginated->items(),
                'meta' => [
                    'current_page' => $paginated->currentPage(),
                    'last_page' => $paginated->lastPage(),
                    'per_page' => $paginated->perPage(),
                    'total' => $paginated->total(),
                ],
                'summary' => [
                    'total_rows' => (int) ($summary->total_rows ?? 0),
                    'total_volume_kg' => (float) ($summary->total_volume_kg ?? 0),
                    'total_nominal' => (float) ($summary->total_nominal ?? 0),
                ],
            ]);
        }

        $limit = min(max($request->integer('limit', 500), 1), 2000);

        return response()->json(
            (clone $baseQuery)
                ->with($relations)
                ->orderByDesc('transaction_date')
                ->latest('id')
                ->limit($limit)
                ->get()
        );
    }

    public function destroy(SellinDistributor $sellinDistributor): JsonResponse
    {
        $sellinDistributor->delete();

        return response()->json([
            'message' => 'Data Sell-In Distributor berhasil dihapus',
        ]);
    }

    public function syncFromSap(Request $request, SapService $sapService): JsonResponse
    {
        $validated = $request->validate([
            'period' => 'nullable|string|size:6',
            'date_from' => 'nullable|date',
            'date_to' => 'nullable|date|after_or_equal:date_from',
            'card_code' => 'nullable|string|max:64',
        ]);

        $period = ! empty($validated['period']) ? trim($validated['period']) : null;
        $dateFrom = ! empty($validated['date_from']) ? trim($validated['date_from']) : null;
        $dateTo = ! empty($validated['date_to']) ? trim($validated['date_to']) : null;

        if (! $period && (! $dateFrom || ! $dateTo)) {
            return response()->json([
                'message' => 'Pilih Periode (YYYYMM) atau rentang Tanggal Dari & Sampai.',
            ], 422);
        }

        $depos = Depo::all();
        $depoByCode = [];
        foreach ($depos as $d) {
            $depoByCode[strtoupper(trim((string) $d->code))] = $d;
        }

        $cardCode = ! empty($validated['card_code']) ? strtoupper(trim($validated['card_code'])) : null;
        $cardCodes = $cardCode ? null : array_keys($depoByCode);

        try {
            $rows = $sapService->listSellinDistributor($period, $dateFrom, $dateTo, $cardCode, $cardCodes);
        } catch (Throwable $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 502);
        }

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

                // Resolusi kepemilikan omset sales berdasarkan Master Target / Assignment ASM Depo & DocDate vs aktif_from..aktif_to
                // (SlpCode/SlpName SAP tidak dipakai sebagai patokan PIC karena bisa berisi SPV/ASC)
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

        return response()->json([
            'message' => 'Sinkronisasi Realisasi Sell-In Distributor dari SAP selesai.',
            'total_fetched' => count($rows),
            'created_count' => $createdCount,
            'updated_count' => $updatedCount,
            'skipped_no_depo' => $skippedNoDepo,
            'unmapped_items' => $unmappedItems,
        ]);
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

        // 1. Cek MasterTarget DEPO untuk periode & depo ini yang aktif pada tanggal transaksi
        $targets = $depoTargets->get($period . '_' . $depoId) ?? collect();
        foreach ($targets as $t) {
            if ($isActiveOnDate($t->user)) {
                return (int) $t->user_id;
            }
        }

        // 2. Cek SalesDistributorAssignment pada depo ini yang aktif pada tanggal transaksi
        $assigns = $depoAssignments->get($depoId) ?? collect();
        foreach ($assigns as $a) {
            if ((! $a->period || $a->period === $period) && $isActiveOnDate($a->user)) {
                return (int) $a->user_id;
            }
        }

        // 3. Cek SalesDistributorAssignment ASM pada distributor induk yang aktif pada tanggal transaksi
        $distAssigns = $distAsmAssignments->get($distributorId) ?? collect();
        foreach ($distAssigns as $a) {
            if ((! $a->period || $a->period === $period) && $isActiveOnDate($a->user)) {
                return (int) $a->user_id;
            }
        }

        return null;
    }
}

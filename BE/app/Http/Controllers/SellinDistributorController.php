<?php

namespace App\Http\Controllers;

use App\Models\SellinDistributor;
use App\Services\SellinSapSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class SellinDistributorController extends Controller
{
    public function index(Request $request, SellinSapSyncService $autoSync): JsonResponse
    {
        if (! $request->boolean('skip_auto_sync')) {
            $syncPeriod = $request->filled('period') ? trim((string) $request->period) : date('Ym');
            $autoSync->syncIfStale($syncPeriod);
        }

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

    public function syncFromSap(Request $request, SellinSapSyncService $syncService): JsonResponse
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
        $cardCode = ! empty($validated['card_code']) ? strtoupper(trim($validated['card_code'])) : null;

        if (! $period && (! $dateFrom || ! $dateTo)) {
            return response()->json([
                'message' => 'Pilih Periode (YYYYMM) atau rentang Tanggal Dari & Sampai.',
            ], 422);
        }

        try {
            $result = $syncService->syncPeriod($period, $dateFrom, $dateTo, $cardCode);
        } catch (Throwable $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 502);
        }

        return response()->json($result);
    }
}

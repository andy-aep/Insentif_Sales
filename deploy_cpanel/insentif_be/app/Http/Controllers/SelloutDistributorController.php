<?php

namespace App\Http\Controllers;

use App\Models\SelloutDistributor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SelloutDistributorController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $baseQuery = SelloutDistributor::query()
            ->when($request->filled('period'), fn ($q) => $q->where('period', trim($request->period)))
            ->when($request->filled('depo_id'), fn ($q) => $q->where('depo_id', $request->depo_id))
            ->when($request->filled('area_id'), fn ($q) => $q->where('area_id', $request->area_id))
            ->when($request->filled('is_out_of_area'), fn ($q) => $q->where('is_out_of_area', $request->boolean('is_out_of_area')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = '%' . strtolower(trim((string) $request->q)) . '%';
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(COALESCE(faktur, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(customer_code, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(customer_name, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(item_code, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(item_name, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(item_desc, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(kota_kab, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(kecamatan, \'\')) LIKE ?', [$term])
                        ->orWhereHas('distributor', fn ($d) => $d->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('depo', fn ($d) => $d->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('area', fn ($a) => $a->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]))
                        ->orWhereHas('brand', fn ($b) => $b->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]));
                });
            });

        $relations = [
            'distributor:id,code,name',
            'depo:id,code,name',
            'area:id,code,name',
            'brand:id,code,name',
        ];

        if ($request->filled('per_page') || $request->boolean('paginate')) {
            $perPage = min(max($request->integer('per_page', 25), 1), 200);
            $summary = (clone $baseQuery)
                ->selectRaw('COUNT(*) as total_rows, COALESCE(SUM(volume_kg), 0) as total_volume_kg, COALESCE(SUM(nominal), 0) as total_nominal, COALESCE(SUM(active_outlet_count), 0) as total_ao')
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
                    'total_ao' => (int) ($summary->total_ao ?? 0),
                ],
            ]);
        }

        $limit = min(max($request->integer('limit', 300), 1), 1000);

        return response()->json(
            (clone $baseQuery)
                ->with($relations)
                ->orderByDesc('transaction_date')
                ->latest('id')
                ->limit($limit)
                ->get()
        );
    }

    public function destroy(SelloutDistributor $selloutDistributor): JsonResponse
    {
        $selloutDistributor->delete();

        return response()->json([
            'message' => 'Data Sell-Out Distributor berhasil dihapus',
        ]);
    }
}

<?php

namespace App\Http\Controllers;

use App\Models\SalesSurabayaAssignment;
use App\Models\SelloutSalesSurabaya;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SelloutSalesSurabayaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = SelloutSalesSurabaya::with(['sales.position', 'coordinator.position'])
            ->when($request->filled('period') && $request->period !== 'ALL', fn ($q) => $q->where('period', $request->period))
            ->when($request->filled('sales_id'), fn ($q) => $q->where('sales_id', $request->sales_id))
            ->when($request->filled('coordinator_id'), fn ($q) => $q->where('coordinator_id', $request->coordinator_id));

        if ($request->filled('search')) {
            $term = '%' . strtolower(trim((string) $request->search)) . '%';
            $query->where(function ($sub) use ($term) {
                $sub->whereHas('sales', fn ($u) => $u->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(username) LIKE ?', [$term]))
                    ->orWhereHas('coordinator', fn ($u) => $u->whereRaw('LOWER(name) LIKE ?', [$term]));
            });
        }

        $perPage = min(max($request->integer('per_page', 100), 1), 500);
        return response()->json($query->latest('id')->paginate($perPage));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'sales_id' => 'required|exists:users,id',
            'coordinator_id' => 'nullable|exists:users,id',
            'period' => 'required|string|size:6',
            'volume' => 'required|numeric|min:0',
            'active_outlet_count' => 'nullable|integer|min:0',
        ]);

        $coordinatorId = $validated['coordinator_id'] ?? SalesSurabayaAssignment::where('sales_id', $validated['sales_id'])
            ->where('is_active', true)
            ->where(function ($q) use ($validated) {
                $q->where('period', $validated['period'])
                    ->orWhereNull('period')
                    ->orWhere('period', '');
            })
            ->value('coordinator_id');

        $record = SelloutSalesSurabaya::create([
            'sales_id' => $validated['sales_id'],
            'coordinator_id' => $coordinatorId,
            'period' => $validated['period'],
            'volume' => (float) $validated['volume'],
            'active_outlet_count' => (int) ($validated['active_outlet_count'] ?? 0),
        ]);

        return response()->json([
            'message' => 'Realisasi Sales Surabaya berhasil disimpan',
            'data' => $record->load(['sales.position', 'coordinator.position']),
        ], 201);
    }

    public function update(Request $request, SelloutSalesSurabaya $selloutSurabaya): JsonResponse
    {
        $validated = $request->validate([
            'sales_id' => 'sometimes|required|exists:users,id',
            'coordinator_id' => 'nullable|exists:users,id',
            'period' => 'sometimes|required|string|size:6',
            'volume' => 'sometimes|required|numeric|min:0',
            'active_outlet_count' => 'nullable|integer|min:0',
        ]);

        $selloutSurabaya->update($validated);

        return response()->json([
            'message' => 'Realisasi Sales Surabaya berhasil diperbarui',
            'data' => $selloutSurabaya->load(['sales.position', 'coordinator.position']),
        ]);
    }

    public function destroy(SelloutSalesSurabaya $selloutSurabaya): JsonResponse
    {
        $selloutSurabaya->delete();

        return response()->json(['message' => 'Realisasi Sales Surabaya berhasil dihapus']);
    }
}

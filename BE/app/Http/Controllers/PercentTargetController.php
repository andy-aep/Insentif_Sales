<?php

namespace App\Http\Controllers;

use App\Models\PercentTarget;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PercentTargetController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $records = PercentTarget::when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->get();

        return response()->json($records);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'metrik_target' => 'required|string|max:100',
            'percent_min' => 'required|numeric|min:0',
            'percent_max' => 'required|numeric|gte:percent_min',
            'performance_status' => 'required|string|max:100',
            'badge_color' => 'required|string|max:50',
            'is_eligible_payout' => 'boolean',
        ]);

        $record = PercentTarget::create($validated);

        return response()->json(['message' => 'Percent Target berhasil dibuat', 'data' => $record], 201);
    }

    public function show(PercentTarget $percentTarget): JsonResponse
    {
        return response()->json(['data' => $percentTarget]);
    }

    public function update(Request $request, PercentTarget $percentTarget): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'sometimes|required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'metrik_target' => 'sometimes|required|string|max:100',
            'percent_min' => 'sometimes|required|numeric|min:0',
            'percent_max' => 'sometimes|required|numeric|gte:percent_min',
            'performance_status' => 'sometimes|required|string|max:100',
            'badge_color' => 'sometimes|required|string|max:50',
            'is_eligible_payout' => 'boolean',
        ]);

        $percentTarget->update($validated);

        return response()->json(['message' => 'Percent Target berhasil diperbarui', 'data' => $percentTarget]);
    }

    public function destroy(PercentTarget $percentTarget): JsonResponse
    {
        $percentTarget->delete();

        return response()->json(['message' => 'Percent Target berhasil dihapus']);
    }
}

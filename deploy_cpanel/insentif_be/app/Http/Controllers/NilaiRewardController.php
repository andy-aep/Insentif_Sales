<?php

namespace App\Http\Controllers;

use App\Models\NilaiReward;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NilaiRewardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $rewards = NilaiReward::when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->get();

        return response()->json($rewards);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'metrik_target' => 'required|string|max:100',
            'kategori_grade' => 'required|string|max:100',
            'standard_rate' => 'numeric|min:0',
            'standard_nominal' => 'numeric|min:0',
        ]);

        $reward = NilaiReward::create($validated);

        return response()->json(['message' => 'Nilai Reward berhasil dibuat', 'data' => $reward], 201);
    }

    public function show(NilaiReward $nilaiReward): JsonResponse
    {
        return response()->json(['data' => $nilaiReward]);
    }

    public function update(Request $request, NilaiReward $nilaiReward): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'sometimes|required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'metrik_target' => 'sometimes|required|string|max:100',
            'kategori_grade' => 'sometimes|required|string|max:100',
            'standard_rate' => 'numeric|min:0',
            'standard_nominal' => 'numeric|min:0',
        ]);

        $nilaiReward->update($validated);

        return response()->json(['message' => 'Nilai Reward berhasil diperbarui', 'data' => $nilaiReward]);
    }

    public function destroy(NilaiReward $nilaiReward): JsonResponse
    {
        $nilaiReward->delete();

        return response()->json(['message' => 'Nilai Reward berhasil dihapus']);
    }
}

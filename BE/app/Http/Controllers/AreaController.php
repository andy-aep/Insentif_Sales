<?php

namespace App\Http\Controllers;

use App\Models\Area;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AreaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $areas = Area::with('depo.distributor')
            ->when($request->depo_id, fn ($q) => $q->where('depo_id', $request->depo_id))
            ->latest()
            ->get();

        return response()->json($areas);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'depo_id' => 'required|exists:depos,id',
            'code' => 'required|string|max:50|unique:areas,code',
            'name' => 'required|string|max:150',
        ]);

        $area = Area::create($validated);

        return response()->json(['message' => 'Area berhasil dibuat', 'data' => $area->load('depo.distributor')], 201);
    }

    public function show(Area $area): JsonResponse
    {
        return response()->json(['data' => $area->load('depo.distributor')]);
    }

    public function update(Request $request, Area $area): JsonResponse
    {
        $validated = $request->validate([
            'depo_id' => 'sometimes|required|exists:depos,id',
            'code' => 'sometimes|required|string|max:50|unique:areas,code,'.$area->id,
            'name' => 'sometimes|required|string|max:150',
        ]);

        $area->update($validated);

        return response()->json(['message' => 'Area berhasil diperbarui', 'data' => $area->load('depo.distributor')]);
    }

    public function destroy(Area $area): JsonResponse
    {
        $area->delete();

        return response()->json(['message' => 'Area berhasil dihapus']);
    }
}

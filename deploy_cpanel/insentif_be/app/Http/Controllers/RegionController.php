<?php

namespace App\Http\Controllers;

use App\Models\Region;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RegionController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Region::withCount('distributors')->latest()->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:regions,code',
            'name' => 'required|string|max:150',
            'description' => 'nullable|string',
        ]);

        $region = Region::create($validated);

        return response()->json([
            'message' => 'Region berhasil dibuat',
            'data' => $region->loadCount('distributors'),
        ], 201);
    }

    public function show(Region $region): JsonResponse
    {
        return response()->json([
            'data' => $region->load(['distributors.depos.areas']),
        ]);
    }

    public function update(Request $request, Region $region): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'sometimes|required|string|max:50|unique:regions,code,'.$region->id,
            'name' => 'sometimes|required|string|max:150',
            'description' => 'nullable|string',
        ]);

        $region->update($validated);

        return response()->json([
            'message' => 'Region berhasil diperbarui',
            'data' => $region->loadCount('distributors'),
        ]);
    }

    public function destroy(Region $region): JsonResponse
    {
        $region->delete();

        return response()->json([
            'message' => 'Region berhasil dihapus',
        ]);
    }
}

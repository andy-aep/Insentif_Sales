<?php

namespace App\Http\Controllers;

use App\Models\Area;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AreaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $limit = $request->integer('limit', 150);
        $search = $request->string('search')->trim();

        $query = Area::with('depo:id,distributor_id,code,name', 'depo.distributor:id,code,name')
            ->when($request->depo_id, fn ($q) => $q->where('depo_id', $request->depo_id));

        if ($search->isNotEmpty()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('code', 'like', "%{$search}%");
            });
        }

        $areas = $query->latest('id')->limit($limit)->get();

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

<?php

namespace App\Http\Controllers;

use App\Models\Area;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AreaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $limit = min(max($request->integer('limit', 1000), 1), 5000);
        $search = $request->string('search')->trim();

        $query = Area::with('depo:id,distributor_id,code,name', 'depo.distributor:id,code,name')
            ->when($request->depo_id, fn ($q) => $q->where('depo_id', $request->depo_id));

        if ($search->isNotEmpty()) {
            $term = '%' . strtolower((string) $search) . '%';
            $query->where(function ($q) use ($term) {
                $q->whereRaw('LOWER(name) LIKE ?', [$term])
                  ->orWhereRaw('LOWER(code) LIKE ?', [$term]);
            });
        }

        $areas = $query->orderBy('name')->limit($limit)->get();

        return response()->json($areas);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'depo_id' => 'required|exists:depos,id',
            'code' => 'nullable|string|max:50|unique:areas,code',
            'name' => 'required|string|max:150',
        ]);

        if (empty($validated['code'])) {
            $validated['code'] = DistributorController::nextSequentialCode(Area::class, 'AR', 5);
        } else {
            $validated['code'] = DistributorController::normalizeCodeFormat($validated['code'], 'AR', 5);
            if (Area::where('code', $validated['code'])->exists()) {
                $validated['code'] = DistributorController::nextSequentialCode(Area::class, 'AR', 5);
            }
        }

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

        if (isset($validated['code'])) {
            $validated['code'] = DistributorController::normalizeCodeFormat($validated['code'], 'AR', 5);
        }

        $area->update($validated);

        return response()->json(['message' => 'Area berhasil diperbarui', 'data' => $area->load('depo.distributor')]);
    }

    public function destroy(Area $area): JsonResponse
    {
        if ($reason = DistributorController::findAreaUsageReason($area)) {
            return response()->json(['message' => $reason], 422);
        }

        $area->delete();

        return response()->json(['message' => 'Area berhasil dihapus']);
    }
}

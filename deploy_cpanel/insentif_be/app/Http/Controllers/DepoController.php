<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class DepoController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $limit = min(max($request->integer('limit', 1000), 1), 5000);
        $search = $request->string('search')->trim();

        $query = Depo::with([
            'distributor:id,code,name',
            'areas:id,depo_id,code,name',
        ])
            ->when($request->distributor_id, fn ($q) => $q->where('distributor_id', $request->distributor_id));

        if ($search->isNotEmpty()) {
            $term = '%' . strtolower((string) $search) . '%';
            $query->where(function ($q) use ($term) {
                $q->whereRaw('LOWER(name) LIKE ?', [$term])
                  ->orWhereRaw('LOWER(code) LIKE ?', [$term]);
            });
        }

        $depos = $query->orderBy('name')->limit($limit)->get();

        return response()->json($depos);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'distributor_id' => 'required|exists:distributors,id',
            'code' => 'required|string|max:50|unique:depos,code',
            'name' => 'required|string|max:150',
            'areas' => 'nullable|array',
            'areas.*.code' => 'nullable|string|max:50',
            'areas.*.name' => 'required_with:areas|string|max:150',
        ]);

        return DB::transaction(function () use ($validated) {
            $depo = Depo::create([
                'distributor_id' => $validated['distributor_id'],
                'code' => $validated['code'],
                'name' => $validated['name'],
            ]);

            if (!empty($validated['areas'])) {
                foreach ($validated['areas'] as $aIdx => $areaData) {
                    $areaCode = !empty($areaData['code'])
                        ? DistributorController::normalizeCodeFormat($areaData['code'], 'AR', 5)
                        : DistributorController::nextSequentialCode(Area::class, 'AR', 5);
                    if (Area::where('code', $areaCode)->exists()) {
                        $areaCode = DistributorController::nextSequentialCode(Area::class, 'AR', 5);
                    }
                    $depo->areas()->create([
                        'code' => $areaCode,
                        'name' => $areaData['name'],
                    ]);
                }
            }

            return response()->json([
                'message' => 'Depo berhasil dibuat',
                'data' => $depo->load(['distributor', 'areas']),
            ], 201);
        });
    }

    public function show(Depo $depo): JsonResponse
    {
        return response()->json(['data' => $depo->load(['distributor', 'areas'])]);
    }

    public function update(Request $request, Depo $depo): JsonResponse
    {
        $validated = $request->validate([
            'distributor_id' => 'sometimes|required|exists:distributors,id',
            'code' => 'sometimes|required|string|max:50|unique:depos,code,'.$depo->id,
            'name' => 'sometimes|required|string|max:150',
            'areas' => 'nullable|array',
            'areas.*.id' => 'nullable|integer',
            'areas.*.code' => 'nullable|string|max:50',
            'areas.*.name' => 'required_with:areas|string|max:150',
        ]);

        return DB::transaction(function () use ($validated, $depo, $request) {
            $depo->update([
                'distributor_id' => $validated['distributor_id'] ?? $depo->distributor_id,
                'code' => $validated['code'] ?? $depo->code,
                'name' => $validated['name'] ?? $depo->name,
            ]);

            if ($request->has('areas')) {
                $keptAreaIds = [];
                foreach ($request->input('areas', []) as $aIdx => $areaData) {
                    $areaId = $areaData['id'] ?? null;
                    $areaName = $areaData['name'] ?? '';
                    $areaCode = !empty($areaData['code'])
                        ? DistributorController::normalizeCodeFormat($areaData['code'], 'AR', 5)
                        : DistributorController::nextSequentialCode(Area::class, 'AR', 5);

                    if ($areaId) {
                        $area = Area::where('id', $areaId)->where('depo_id', $depo->id)->first();
                        if ($area) {
                            if ($areaCode !== $area->code && Area::where('code', $areaCode)->where('id', '!=', $area->id)->exists()) {
                                $areaCode = DistributorController::nextSequentialCode(Area::class, 'AR', 5);
                            }
                            $area->update([
                                'code' => $areaCode,
                                'name' => $areaName,
                            ]);
                            $keptAreaIds[] = $area->id;
                        }
                    } else {
                        if (Area::where('code', $areaCode)->exists()) {
                            $areaCode = DistributorController::nextSequentialCode(Area::class, 'AR', 5);
                        }
                        $area = $depo->areas()->create([
                            'code' => $areaCode,
                            'name' => $areaName,
                        ]);
                        $keptAreaIds[] = $area->id;
                    }
                }
                $areasToDelete = $depo->areas()->whereNotIn('id', $keptAreaIds)->get();
                foreach ($areasToDelete as $oldArea) {
                    if ($reason = DistributorController::findAreaUsageReason($oldArea)) {
                        throw ValidationException::withMessages(['areas' => [$reason]]);
                    }
                    $oldArea->delete();
                }
            }

            return response()->json([
                'message' => 'Depo berhasil diperbarui',
                'data' => $depo->load(['distributor', 'areas']),
            ]);
        });
    }

    public function destroy(Depo $depo): JsonResponse
    {
        if ($reason = DistributorController::findDepoUsageReason($depo)) {
            return response()->json(['message' => $reason], 422);
        }

        DB::transaction(function () use ($depo) {
            $depo->areas()->delete();
            $depo->delete();
        });

        return response()->json(['message' => 'Depo berhasil dihapus']);
    }
}


<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DepoController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $depos = Depo::with(['distributor', 'areas'])
            ->when($request->distributor_id, fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->latest()
            ->get();

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
                    $areaCode = !empty($areaData['code']) ? trim($areaData['code']) : $depo->code . '-AR' . ($aIdx + 1);
                    $baseCode = $areaCode;
                    $counter = 1;
                    while (Area::where('code', $areaCode)->exists()) {
                        $areaCode = $baseCode . '-' . $counter++;
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
                    $areaCode = !empty($areaData['code']) ? trim($areaData['code']) : $depo->code . '-AR' . ($aIdx + 1);

                    if ($areaId) {
                        $area = Area::where('id', $areaId)->where('depo_id', $depo->id)->first();
                        if ($area) {
                            $area->update([
                                'code' => $areaCode,
                                'name' => $areaName,
                            ]);
                            $keptAreaIds[] = $area->id;
                        }
                    } else {
                        $baseCode = $areaCode;
                        $counter = 1;
                        while (Area::where('code', $areaCode)->exists()) {
                            $areaCode = $baseCode . '-' . $counter++;
                        }
                        $area = $depo->areas()->create([
                            'code' => $areaCode,
                            'name' => $areaName,
                        ]);
                        $keptAreaIds[] = $area->id;
                    }
                }
                $depo->areas()->whereNotIn('id', $keptAreaIds)->delete();
            }

            return response()->json([
                'message' => 'Depo berhasil diperbarui',
                'data' => $depo->load(['distributor', 'areas']),
            ]);
        });
    }

    public function destroy(Depo $depo): JsonResponse
    {
        $depo->delete();

        return response()->json(['message' => 'Depo berhasil dihapus']);
    }
}


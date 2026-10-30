<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DistributorController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Distributor::with(['region', 'depos.areas'])->latest()->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:distributors,code',
            'name' => 'required|string|max:150',
            'region_id' => 'nullable|exists:regions,id',
            'depos' => 'nullable|array',
            'depos.*.code' => 'nullable|string|max:50',
            'depos.*.name' => 'required_with:depos|string|max:150',
            'depos.*.areas' => 'nullable|array',
            'depos.*.areas.*.code' => 'nullable|string|max:50',
            'depos.*.areas.*.name' => 'required_with:depos.*.areas|string|max:150',
        ]);

        return DB::transaction(function () use ($validated) {
            $distributor = Distributor::create([
                'code' => $validated['code'],
                'name' => $validated['name'],
                'region_id' => $validated['region_id'] ?? null,
            ]);

            if (!empty($validated['depos'])) {
                foreach ($validated['depos'] as $dIdx => $depoData) {
                    $depoCode = !empty($depoData['code'])
                        ? trim($depoData['code'])
                        : $distributor->code . '-DP' . ($dIdx + 1);

                    $baseCode = $depoCode;
                    $counter = 1;
                    while (Depo::where('code', $depoCode)->exists()) {
                        $depoCode = $baseCode . '-' . $counter++;
                    }

                    $depo = $distributor->depos()->create([
                        'code' => $depoCode,
                        'name' => $depoData['name'],
                    ]);

                    if (!empty($depoData['areas'])) {
                        foreach ($depoData['areas'] as $aIdx => $areaData) {
                            $areaCode = !empty($areaData['code'])
                                ? trim($areaData['code'])
                                : $depo->code . '-AR' . ($aIdx + 1);

                            $baseAreaCode = $areaCode;
                            $aCounter = 1;
                            while (Area::where('code', $areaCode)->exists()) {
                                $areaCode = $baseAreaCode . '-' . $aCounter++;
                            }

                            $depo->areas()->create([
                                'code' => $areaCode,
                                'name' => $areaData['name'],
                            ]);
                        }
                    }
                }
            }

            return response()->json([
                'message' => 'Distributor beserta Depo dan Area berhasil dibuat',
                'data' => $distributor->load(['region', 'depos.areas']),
            ], 201);
        });
    }

    public function show(Distributor $distributor): JsonResponse
    {
        return response()->json(['data' => $distributor->load(['region', 'depos.areas'])]);
    }

    public function update(Request $request, Distributor $distributor): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'sometimes|required|string|max:50|unique:distributors,code,'.$distributor->id,
            'name' => 'sometimes|required|string|max:150',
            'region_id' => 'nullable|exists:regions,id',
            'depos' => 'nullable|array',
            'depos.*.id' => 'nullable|integer',
            'depos.*.code' => 'nullable|string|max:50',
            'depos.*.name' => 'required_with:depos|string|max:150',
            'depos.*.areas' => 'nullable|array',
            'depos.*.areas.*.id' => 'nullable|integer',
            'depos.*.areas.*.code' => 'nullable|string|max:50',
            'depos.*.areas.*.name' => 'required_with:depos.*.areas|string|max:150',
        ]);

        return DB::transaction(function () use ($validated, $distributor, $request) {
            $updateData = [
                'code' => $validated['code'] ?? $distributor->code,
                'name' => $validated['name'] ?? $distributor->name,
            ];
            if ($request->has('region_id')) {
                $updateData['region_id'] = $validated['region_id'];
            }
            $distributor->update($updateData);

            if ($request->has('depos')) {
                $keptDepoIds = [];
                foreach ($request->input('depos', []) as $dIdx => $depoData) {
                    $depoId = $depoData['id'] ?? null;
                    $depoName = $depoData['name'] ?? '';
                    $depoCode = !empty($depoData['code']) ? trim($depoData['code']) : $distributor->code . '-DP' . ($dIdx + 1);

                    if ($depoId) {
                        $depo = Depo::where('id', $depoId)->where('distributor_id', $distributor->id)->first();
                        if ($depo) {
                            $depo->update([
                                'code' => $depoCode,
                                'name' => $depoName,
                            ]);
                        }
                    } else {
                        $baseCode = $depoCode;
                        $counter = 1;
                        while (Depo::where('code', $depoCode)->exists()) {
                            $depoCode = $baseCode . '-' . $counter++;
                        }
                        $depo = $distributor->depos()->create([
                            'code' => $depoCode,
                            'name' => $depoName,
                        ]);
                    }

                    if ($depo) {
                        $keptDepoIds[] = $depo->id;

                        if (isset($depoData['areas'])) {
                            $keptAreaIds = [];
                            foreach ($depoData['areas'] as $aIdx => $areaData) {
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
                                    }
                                } else {
                                    $baseAreaCode = $areaCode;
                                    $aCounter = 1;
                                    while (Area::where('code', $areaCode)->exists()) {
                                        $areaCode = $baseAreaCode . '-' . $aCounter++;
                                    }
                                    $area = $depo->areas()->create([
                                        'code' => $areaCode,
                                        'name' => $areaName,
                                    ]);
                                }

                                if ($area) {
                                    $keptAreaIds[] = $area->id;
                                }
                            }
                            $depo->areas()->whereNotIn('id', $keptAreaIds)->delete();
                        }
                    }
                }
                $distributor->depos()->whereNotIn('id', $keptDepoIds)->delete();
            }

            return response()->json([
                'message' => 'Distributor berhasil diperbarui',
                'data' => $distributor->load(['region', 'depos.areas']),
            ]);
        });
    }

    public function destroy(Distributor $distributor): JsonResponse
    {
        $distributor->delete();

        return response()->json(['message' => 'Distributor berhasil dihapus']);
    }
}


<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DistributorController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $limit = min(max($request->integer('limit', 1000), 1), 5000);
        $search = $request->string('search')->trim();

        $query = Distributor::withCount(['depos', 'areas'])
            ->with([
                'region:id,code,name',
                'depos:id,distributor_id,code,name',
            ]);

        if ($search->isNotEmpty()) {
            $term = '%' . strtolower((string) $search) . '%';
            $query->where(function ($q) use ($term) {
                $q->whereRaw('LOWER(name) LIKE ?', [$term])
                  ->orWhereRaw('LOWER(code) LIKE ?', [$term]);
            });
        }

        return response()->json($query->orderBy('name')->limit($limit)->get());
    }

    /**
     * Generate sequential code with prefix (e.g. DST0001, AR00001) safely without colliding with existing records.
     */
    public static function nextSequentialCode(string $modelClass, string $prefix, int $padLength): string
    {
        $codes = $modelClass::query()
            ->whereRaw('LOWER(code) LIKE ?', [strtolower($prefix) . '%'])
            ->pluck('code');

        $maxNum = 0;
        $pattern = '/^' . preg_quote($prefix, '/') . '(\d+)$/i';
        foreach ($codes as $c) {
            if (preg_match($pattern, trim((string) $c), $m)) {
                $num = (int) $m[1];
                if ($num > $maxNum) {
                    $maxNum = $num;
                }
            }
        }

        $next = $maxNum + 1;
        do {
            $candidate = $prefix . str_pad((string) $next, $padLength, '0', STR_PAD_LEFT);
            $next++;
        } while ($modelClass::where('code', $candidate)->exists());

        return $candidate;
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'nullable|string|max:50|unique:distributors,code',
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
            $distCode = !empty($validated['code'])
                ? strtoupper(trim($validated['code']))
                : self::nextSequentialCode(Distributor::class, 'DST', 4);

            $distributor = Distributor::create([
                'code' => $distCode,
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
                                ? strtoupper(trim($areaData['code']))
                                : self::nextSequentialCode(Area::class, 'AR', 5);

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
                                $areaCode = !empty($areaData['code'])
                                    ? strtoupper(trim($areaData['code']))
                                    : ($areaId ? '' : self::nextSequentialCode(Area::class, 'AR', 5));

                                if ($areaId) {
                                    $area = Area::where('id', $areaId)->where('depo_id', $depo->id)->first();
                                    if ($area) {
                                        $area->update([
                                            'code' => $areaCode !== '' ? $areaCode : $area->code,
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
        $sellinCount = SellinDistributor::where('distributor_id', $distributor->id)->count();
        $selloutCount = SelloutDistributor::where('distributor_id', $distributor->id)->count();

        if ($sellinCount > 0 || $selloutCount > 0) {
            return response()->json([
                'message' => "Distributor \"{$distributor->name}\" tidak dapat dihapus karena masih memiliki {$sellinCount} transaksi Sell-In dan {$selloutCount} transaksi Sell-Out. Hapus atau rollback data transaksi terkait terlebih dahulu.",
            ], 422);
        }

        DB::transaction(fn () => $distributor->delete());

        return response()->json(['message' => 'Distributor berhasil dihapus']);
    }
}


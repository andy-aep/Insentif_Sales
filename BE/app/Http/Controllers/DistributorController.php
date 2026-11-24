<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

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
                'depos.areas:id,depo_id,code,name',
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
     * Normalisasi kode berawalan prefix menjadi zero-padded N digit (mis. DST053 -> DST0053, AR0192 -> AR00192).
     */
    public static function normalizeCodeFormat(string $rawCode, string $prefix, int $padLength): string
    {
        $clean = strtoupper(trim($rawCode));
        if ($clean === '') {
            return '';
        }

        $pattern = '/^' . preg_quote($prefix, '/') . '0*(\d+)(?:-\d+)?$/i';
        if (preg_match($pattern, $clean, $m)) {
            return strtoupper($prefix) . str_pad($m[1], $padLength, '0', STR_PAD_LEFT);
        }

        return $clean;
    }

    /**
     * Generate sequential code with prefix (e.g. DST0001, AR00001) safely without colliding with existing records.
     */
    public static function nextSequentialCode(string $modelClass, string $prefix, int $padLength): string
    {
        $query = method_exists($modelClass, 'withTrashed') ? $modelClass::withTrashed() : $modelClass::query();
        $codes = $query
            ->whereRaw('LOWER(code) LIKE ?', [strtolower($prefix) . '%'])
            ->pluck('code');

        $maxNum = 0;
        $pattern = '/^' . preg_quote($prefix, '/') . '0*(\d+)$/i';
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
            $existsQuery = method_exists($modelClass, 'withTrashed') ? $modelClass::withTrashed() : $modelClass::query();
        } while ($existsQuery->where('code', $candidate)->exists());

        return $candidate;
    }

    /**
     * Cek apakah Area masih dipakai di transaksi/target/assignment sehingga tidak boleh dihapus.
     */
    public static function findAreaUsageReason(Area $area): ?string
    {
        $selloutCount = SelloutDistributor::where('area_id', $area->id)->count();
        $targetCount = MasterTarget::where('area_id', $area->id)->count();
        $assignCount = SalesDistributorAssignment::where('area_id', $area->id)->count();

        if ($selloutCount === 0 && $targetCount === 0 && $assignCount === 0) {
            return null;
        }

        $parts = [];
        if ($selloutCount > 0) {
            $parts[] = "{$selloutCount} transaksi Sell-Out";
        }
        if ($targetCount > 0) {
            $parts[] = "{$targetCount} Master Target";
        }
        if ($assignCount > 0) {
            $parts[] = "{$assignCount} Penugasan Sales";
        }

        return "Area \"{$area->name}\" ({$area->code}) tidak dapat dihapus karena masih terpakai pada " . implode(', ', $parts) . '.';
    }

    /**
     * Cek apakah Depo (atau Area di bawahnya) masih dipakai di transaksi/target/assignment sehingga tidak boleh dihapus.
     */
    public static function findDepoUsageReason(Depo $depo): ?string
    {
        $areaIds = $depo->areas()->pluck('id');
        $sellinCount = SellinDistributor::where('depo_id', $depo->id)->count();
        $selloutCount = SelloutDistributor::where(function ($q) use ($depo, $areaIds) {
            $q->where('depo_id', $depo->id);
            if ($areaIds->isNotEmpty()) {
                $q->orWhereIn('area_id', $areaIds);
            }
        })->count();
        $targetCount = MasterTarget::where(function ($q) use ($depo, $areaIds) {
            $q->where('depo_id', $depo->id);
            if ($areaIds->isNotEmpty()) {
                $q->orWhereIn('area_id', $areaIds);
            }
        })->count();
        $assignCount = SalesDistributorAssignment::where(function ($q) use ($depo, $areaIds) {
            $q->where('depo_id', $depo->id);
            if ($areaIds->isNotEmpty()) {
                $q->orWhereIn('area_id', $areaIds);
            }
        })->count();

        if ($sellinCount === 0 && $selloutCount === 0 && $targetCount === 0 && $assignCount === 0) {
            return null;
        }

        $parts = [];
        if ($sellinCount > 0) {
            $parts[] = "{$sellinCount} transaksi Sell-In";
        }
        if ($selloutCount > 0) {
            $parts[] = "{$selloutCount} transaksi Sell-Out";
        }
        if ($targetCount > 0) {
            $parts[] = "{$targetCount} Master Target";
        }
        if ($assignCount > 0) {
            $parts[] = "{$assignCount} Penugasan Sales";
        }

        return "Depo \"{$depo->name}\" ({$depo->code}) tidak dapat dihapus karena masih terpakai pada " . implode(', ', $parts) . '.';
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
                ? self::normalizeCodeFormat($validated['code'], 'DST', 4)
                : self::nextSequentialCode(Distributor::class, 'DST', 4);
            if (Distributor::where('code', $distCode)->exists()) {
                $distCode = self::nextSequentialCode(Distributor::class, 'DST', 4);
            }

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
                                ? self::normalizeCodeFormat($areaData['code'], 'AR', 5)
                                : self::nextSequentialCode(Area::class, 'AR', 5);

                            if (Area::where('code', $areaCode)->exists()) {
                                $areaCode = self::nextSequentialCode(Area::class, 'AR', 5);
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
            $normalizedDistCode = isset($validated['code'])
                ? self::normalizeCodeFormat($validated['code'], 'DST', 4)
                : $distributor->code;
            $updateData = [
                'code' => $normalizedDistCode,
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
                                    ? self::normalizeCodeFormat($areaData['code'], 'AR', 5)
                                    : ($areaId ? '' : self::nextSequentialCode(Area::class, 'AR', 5));

                                if ($areaId) {
                                    $area = Area::where('id', $areaId)->where('depo_id', $depo->id)->first();
                                    if ($area) {
                                        $nextAreaCode = $areaCode !== '' ? $areaCode : $area->code;
                                        if ($nextAreaCode !== $area->code && Area::where('code', $nextAreaCode)->where('id', '!=', $area->id)->exists()) {
                                            $nextAreaCode = self::nextSequentialCode(Area::class, 'AR', 5);
                                        }
                                        $area->update([
                                            'code' => $nextAreaCode,
                                            'name' => $areaName,
                                        ]);
                                    }
                                } else {
                                    if (Area::where('code', $areaCode)->exists()) {
                                        $areaCode = self::nextSequentialCode(Area::class, 'AR', 5);
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
                            $areasToDelete = $depo->areas()->whereNotIn('id', $keptAreaIds)->get();
                            foreach ($areasToDelete as $oldArea) {
                                if ($reason = self::findAreaUsageReason($oldArea)) {
                                    throw ValidationException::withMessages(['depos' => [$reason]]);
                                }
                                $oldArea->delete();
                            }
                        }
                    }
                }
                $deposToDelete = $distributor->depos()->whereNotIn('id', $keptDepoIds)->get();
                foreach ($deposToDelete as $oldDepo) {
                    if ($reason = self::findDepoUsageReason($oldDepo)) {
                        throw ValidationException::withMessages(['depos' => [$reason]]);
                    }
                    $oldDepo->areas()->delete();
                    $oldDepo->delete();
                }
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
        $targetCount = MasterTarget::where('distributor_id', $distributor->id)->count();
        $assignCount = SalesDistributorAssignment::where('distributor_id', $distributor->id)->count();

        if ($sellinCount > 0 || $selloutCount > 0 || $targetCount > 0 || $assignCount > 0) {
            $parts = [];
            if ($sellinCount > 0) $parts[] = "{$sellinCount} transaksi Sell-In";
            if ($selloutCount > 0) $parts[] = "{$selloutCount} transaksi Sell-Out";
            if ($targetCount > 0) $parts[] = "{$targetCount} Master Target";
            if ($assignCount > 0) $parts[] = "{$assignCount} Penugasan Sales";

            return response()->json([
                'message' => "Distributor \"{$distributor->name}\" tidak dapat dihapus karena masih memiliki " . implode(', ', $parts) . '. Hapus atau rollback data terkait terlebih dahulu.',
            ], 422);
        }

        DB::transaction(function () use ($distributor) {
            foreach ($distributor->depos as $dp) {
                $dp->areas()->delete();
                $dp->delete();
            }
            $distributor->delete();
        });

        return response()->json(['message' => 'Distributor berhasil dihapus']);
    }
}


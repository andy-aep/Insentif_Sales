<?php

namespace App\Http\Controllers;

use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MasterTargetController extends Controller
{
    /**
     * Dapatkan daftar periode yang tersedia pada Master Target.
     */
    public function periods(): JsonResponse
    {
        $periods = MasterTarget::distinct()
            ->orderByDesc('period')
            ->pluck('period');

        return response()->json([
            'data' => $periods,
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        // Cegah execution timeout saat data mencapai puluhan ribu baris
        if (function_exists('set_time_limit')) {
            @set_time_limit(120);
        }

        $perPage = min(max($request->integer('per_page', 50), 10), 500);

        $query = MasterTarget::with([
            'user:id,name,username,position_id',
            'user.position:id,name,code',
            'distributor:id,name,code',
            'depo:id,name,code,distributor_id',
            'area:id,name,code,depo_id',
            'brand:id,name,code',
        ])
            ->when($request->user_id, fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->distributor_id, fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->when($request->depo_id, fn ($q) => $q->where('depo_id', $request->depo_id))
            ->when($request->area_id, fn ($q) => $q->where('area_id', $request->area_id))
            ->when($request->brand_id, fn ($q) => $q->where('brand_id', $request->brand_id))
            ->when($request->level, fn ($q) => $q->where('level', $request->level))
            ->when($request->kategori_skema, function ($q, $k) {
                if (in_array(strtoupper($k), ['KONSUMSI', 'DISTRIBUTOR'])) {
                    $q->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR']);
                } else {
                    $q->where('kategori_skema', $k);
                }
            })
            ->when($request->period, fn ($q) => $q->where('period', $request->period))
            ->when($request->metrik_target, fn ($q) => $q->where('metrik_target', $request->metrik_target));

        if ($request->filled('search')) {
            $search = '%' . trim($request->search) . '%';
            $query->where(function ($sub) use ($search) {
                $sub->whereHas('distributor', fn ($d) => $d->where('name', 'like', $search)->orWhere('code', 'like', $search))
                    ->orWhereHas('depo', fn ($d) => $d->where('name', 'like', $search))
                    ->orWhereHas('area', fn ($a) => $a->where('name', 'like', $search))
                    ->orWhereHas('brand', fn ($b) => $b->where('name', 'like', $search))
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', $search));
            });
        }

        // Summary cepat via agregasi SQL index-aware tanpa load ribuan model ke memory
        $summaryBase = (clone $query)->getQuery();
        $summary = [
            'total_sell_in' => (float) (clone $summaryBase)->where('metrik_target', 'SELL_IN')->sum('target_quota'),
            'total_sell_out' => (float) (clone $summaryBase)->where('metrik_target', 'SELL_OUT')->sum('target_quota'),
            'total_ao' => (int) (clone $summaryBase)->where('metrik_target', 'AO')->sum(DB::raw('COALESCE(target_outlet, target_quota)')),
            'depo_count' => (int) (clone $summaryBase)->where('level', 'DEPO')->count(),
            'area_count' => (int) (clone $summaryBase)->where('level', 'AREA')->count(),
            'total_count' => (int) (clone $summaryBase)->count(),
        ];

        $paginated = $query->latest('id')->paginate($perPage);

        return response()->json([
            'data' => $paginated->items(),
            'current_page' => $paginated->currentPage(),
            'last_page' => $paginated->lastPage(),
            'per_page' => $paginated->perPage(),
            'total' => $paginated->total(),
            'from' => $paginated->firstItem(),
            'to' => $paginated->lastItem(),
            'summary' => $summary,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'nullable|exists:users,id',
            'distributor_id' => 'nullable|exists:distributors,id',
            'depo_id' => 'nullable|exists:depos,id',
            'area_id' => 'nullable|exists:areas,id',
            'brand_id' => 'nullable|exists:brands,id',
            'level' => 'nullable|string|in:DISTRIBUTOR,DEPO,AREA,SALES',
            'kategori_skema' => 'required|string',
            'metrik_target' => 'required|string|max:100',
            'period' => 'nullable|string',
            'year' => 'nullable|string|size:4',
            'is_full_year' => 'nullable|boolean',
            'target_quota' => 'required|numeric|min:0',
            'target_outlet' => 'nullable|integer|min:0',
        ]);

        $kategori = strtoupper($validated['kategori_skema']);
        if ($kategori === 'DISTRIBUTOR') {
            $kategori = 'KONSUMSI';
        }

        // Determine hierarchy level
        $level = $validated['level'] ?? null;
        if (! $level) {
            if (! empty($validated['area_id'])) {
                $level = 'AREA';
            } elseif (! empty($validated['depo_id'])) {
                $level = 'DEPO';
            } elseif (! empty($validated['distributor_id'])) {
                $level = 'DISTRIBUTOR';
            } else {
                $level = 'SALES';
            }
        }

        $isFullYear = $request->boolean('is_full_year') || ! empty($validated['year']) || (isset($validated['period']) && strlen($validated['period']) === 4);

        $periods = [];
        $targetYear = $validated['year'] ?? (isset($validated['period']) ? substr($validated['period'], 0, 4) : date('Y'));

        if ($isFullYear) {
            if (empty($targetYear) || strlen($targetYear) !== 4) {
                return response()->json(['message' => 'Format tahun tidak valid (harus 4 digit YYYY).'], 422);
            }
            for ($m = 1; $m <= 12; $m++) {
                $periods[] = sprintf('%04d%02d', (int) $targetYear, $m);
            }
        } else {
            if (empty($validated['period']) || strlen($validated['period']) !== 6) {
                return response()->json(['message' => 'Format periode tidak valid (harus 6 digit YYYYMM).'], 422);
            }
            $periods[] = $validated['period'];
        }

        $createdTargets = [];
        DB::transaction(function () use ($periods, $kategori, $level, $validated, &$createdTargets) {
            foreach ($periods as $p) {
                // Auto-resolve user_id from active assignment if not supplied
                $userId = $validated['user_id'] ?? null;
                if (! $userId && $kategori === 'KONSUMSI') {
                    if (! empty($validated['area_id'])) {
                        $spvAssign = SalesDistributorAssignment::where('area_id', $validated['area_id'])
                            ->where('is_active', true)
                            ->where(function ($q) use ($p) {
                                $q->where('period', $p)->orWhereNull('period');
                            })
                            ->first();
                        if (! $spvAssign) {
                            $spvAssign = SalesDistributorAssignment::where('area_id', $validated['area_id'])
                                ->where('is_active', true)
                                ->latest()
                                ->first();
                        }
                        if ($spvAssign) {
                            $userId = $spvAssign->user_id;
                        }
                    } elseif (! empty($validated['distributor_id'])) {
                        $asmAssign = SalesDistributorAssignment::where('distributor_id', $validated['distributor_id'])
                            ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                            ->where('is_active', true)
                            ->where(function ($q) use ($p) {
                                $q->where('period', $p)->orWhereNull('period');
                            })
                            ->first();
                        if (! $asmAssign) {
                            $asmAssign = SalesDistributorAssignment::where('distributor_id', $validated['distributor_id'])
                                ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                                ->where('is_active', true)
                                ->latest()
                                ->first();
                        }
                        if ($asmAssign) {
                            $userId = $asmAssign->user_id;
                        }
                    }
                }

                $target = MasterTarget::updateOrCreate(
                    [
                        'period' => $p,
                        'kategori_skema' => $kategori,
                        'metrik_target' => $validated['metrik_target'],
                        'distributor_id' => $validated['distributor_id'] ?? null,
                        'depo_id' => $validated['depo_id'] ?? null,
                        'area_id' => $validated['area_id'] ?? null,
                        'brand_id' => $validated['brand_id'] ?? null,
                        'user_id' => $userId,
                    ],
                    [
                        'level' => $level,
                        'target_quota' => $validated['target_quota'],
                        'target_outlet' => $validated['target_outlet'] ?? null,
                    ]
                );
                $createdTargets[] = $target;
            }
        });

        $message = $isFullYear
            ? "Master Target berhasil disimpan untuk 12 bulan penuh tahun {$targetYear}"
            : "Master Target berhasil disimpan";

        return response()->json([
            'message' => $message,
            'count' => count($createdTargets),
            'data' => $createdTargets[0]->load(['user.position', 'distributor', 'depo', 'area', 'brand']),
        ], 201);
    }

    public function show(MasterTarget $masterTarget): JsonResponse
    {
        return response()->json([
            'data' => $masterTarget->load(['user.position', 'distributor', 'depo', 'area', 'brand']),
        ]);
    }

    public function update(Request $request, MasterTarget $masterTarget): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'nullable|exists:users,id',
            'distributor_id' => 'nullable|exists:distributors,id',
            'depo_id' => 'nullable|exists:depos,id',
            'area_id' => 'nullable|exists:areas,id',
            'brand_id' => 'nullable|exists:brands,id',
            'level' => 'nullable|string|in:DISTRIBUTOR,DEPO,AREA,SALES',
            'kategori_skema' => 'nullable|string',
            'metrik_target' => 'sometimes|required|string|max:100',
            'period' => 'sometimes|required|string|size:6',
            'target_quota' => 'sometimes|required|numeric|min:0',
            'target_outlet' => 'nullable|integer|min:0',
        ]);

        if (isset($validated['kategori_skema'])) {
            $kategori = strtoupper($validated['kategori_skema']);
            if ($kategori === 'DISTRIBUTOR') {
                $validated['kategori_skema'] = 'KONSUMSI';
            }
        }

        $masterTarget->update($validated);

        return response()->json([
            'message' => 'Master Target berhasil diperbarui',
            'data' => $masterTarget->load(['user.position', 'distributor', 'depo', 'area', 'brand']),
        ]);
    }

    public function destroy(MasterTarget $masterTarget): JsonResponse
    {
        $masterTarget->delete();

        return response()->json(['message' => 'Master Target berhasil dihapus']);
    }
}

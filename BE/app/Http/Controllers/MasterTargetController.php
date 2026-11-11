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

    /**
     * Target Distributor hierarkis: Distributor -> Depo (brand targets) -> Area (brand targets).
     * Paginasi per distributor.
     */
    public function hierarchy(Request $request): JsonResponse
    {
        if (function_exists('set_time_limit')) {
            @set_time_limit(120);
        }

        $perPage = min(max($request->integer('per_page', 10), 1), 100);

        $base = MasterTarget::query()
            ->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR'])
            ->whereNotNull('distributor_id')
            ->when($request->period && $request->period !== 'ALL', fn ($q) => $q->where('period', $request->period))
            ->when($request->distributor_id, fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->when($request->brand_id, fn ($q) => $q->where('brand_id', $request->brand_id))
            ->when($request->metrik_target, fn ($q) => $q->where('metrik_target', $request->metrik_target));

        if ($request->filled('search')) {
            $search = '%' . trim($request->search) . '%';
            $base->where(function ($sub) use ($search) {
                $sub->whereHas('distributor', fn ($d) => $d->where('name', 'like', $search)->orWhere('code', 'like', $search))
                    ->orWhereHas('depo', fn ($d) => $d->where('name', 'like', $search)->orWhere('code', 'like', $search))
                    ->orWhereHas('area', fn ($a) => $a->where('name', 'like', $search)->orWhere('code', 'like', $search));
            });
        }

        $summary = [
            'distributor_count' => (int) (clone $base)->distinct()->count('distributor_id'),
            'depo_count' => (int) (clone $base)->where('level', 'DEPO')->count(),
            'area_count' => (int) (clone $base)->where('level', 'AREA')->count(),
            'depo_sell_out' => (float) (clone $base)->where('level', 'DEPO')->where('metrik_target', 'SELL_OUT')->sum('target_quota'),
            'depo_sell_in' => (float) (clone $base)->where('level', 'DEPO')->where('metrik_target', 'SELL_IN')->sum('target_quota'),
            'area_sell_out' => (float) (clone $base)->where('level', 'AREA')->where('metrik_target', 'SELL_OUT')->sum('target_quota'),
            'area_sell_in' => (float) (clone $base)->where('level', 'AREA')->where('metrik_target', 'SELL_IN')->sum('target_quota'),
            'total_ao' => (int) (clone $base)->where('metrik_target', 'AO')->sum(DB::raw('COALESCE(target_outlet, target_quota)')),
        ];

        $distPage = (clone $base)
            ->select('distributor_id')
            ->groupBy('distributor_id')
            ->orderBy('distributor_id')
            ->paginate($perPage);

        $distIds = collect($distPage->items())->pluck('distributor_id')->all();

        $rows = (clone $base)
            ->whereIn('distributor_id', $distIds)
            ->with([
                'user:id,name,username',
                'distributor:id,name,code',
                'depo:id,name,code,distributor_id',
                'area:id,name,code,depo_id',
                'brand:id,name,code',
            ])
            ->orderBy('depo_id')->orderBy('area_id')->orderBy('brand_id')
            ->get();

        // Resolusi PIC dari Penugasan Sales Distributor (Gambar 2) jika user belum terisi di target
        $periodFilter = $request->period && $request->period !== 'ALL' ? $request->period : null;

        $asmAssignments = SalesDistributorAssignment::whereIn('distributor_id', $distIds)
            ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
            ->where('is_active', true)
            ->when($periodFilter, fn ($q) => $q->where(fn ($sub) => $sub->where('period', $periodFilter)->orWhereNull('period')))
            ->with('user:id,name,username')
            ->get()
            ->keyBy('distributor_id');

        $areaIds = $rows->where('level', 'AREA')->pluck('area_id')->filter()->unique()->all();
        $spvAssignments = SalesDistributorAssignment::whereIn('area_id', $areaIds)
            ->whereHas('user.position', fn ($q) => $q->where('code', 'SPV'))
            ->where('is_active', true)
            ->when($periodFilter, fn ($q) => $q->where(fn ($sub) => $sub->where('period', $periodFilter)->orWhereNull('period')))
            ->with('user:id,name,username')
            ->get()
            ->keyBy('area_id');

        foreach ($rows as $row) {
            if (! $row->user) {
                if ($row->level === 'DEPO' && isset($asmAssignments[$row->distributor_id])) {
                    $row->setRelation('user', $asmAssignments[$row->distributor_id]->user);
                } elseif ($row->level === 'AREA' && isset($spvAssignments[$row->area_id])) {
                    $row->setRelation('user', $spvAssignments[$row->area_id]->user);
                }
            }
        }

        $data = [];
        foreach ($distIds as $distId) {
            $distRows = $rows->where('distributor_id', $distId);
            $first = $distRows->first();
            $depos = [];
            foreach ($distRows->groupBy(fn ($r) => $r->depo_id ?? 0) as $depoId => $depoRows) {
                $depoModel = $depoRows->first()->depo;
                $depoTargets = $depoRows->where('level', 'DEPO')->values();
                $areas = [];
                foreach ($depoRows->where('level', 'AREA')->groupBy(fn ($r) => $r->area_id ?? 0) as $areaId => $areaRows) {
                    $areaModel = $areaRows->first()->area;
                    $areas[] = [
                        'id' => $areaId,
                        'code' => $areaModel?->code,
                        'name' => $areaModel?->name,
                        'targets' => $areaRows->values(),
                    ];
                }
                $depos[] = [
                    'id' => $depoId,
                    'code' => $depoModel?->code,
                    'name' => $depoModel?->name,
                    'targets' => $depoTargets,
                    'areas' => $areas,
                ];
            }
            $data[] = [
                'id' => $distId,
                'code' => $first?->distributor?->code,
                'name' => $first?->distributor?->name,
                'depo_target_count' => $distRows->where('level', 'DEPO')->count(),
                'area_target_count' => $distRows->where('level', 'AREA')->count(),
                'depos' => $depos,
            ];
        }

        return response()->json([
            'data' => $data,
            'current_page' => $distPage->currentPage(),
            'last_page' => $distPage->lastPage(),
            'per_page' => $distPage->perPage(),
            'total' => $distPage->total(),
            'summary' => $summary,
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

        // Summary cepat via agregasi SQL index-aware (dipisahkan murni antara Target Depo, Target Area, Industri & Surabaya)
        $summaryBase = (clone $query)->getQuery();
        $depoBase = (clone $summaryBase)->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR'])->where('level', 'DEPO');
        $areaBase = (clone $summaryBase)->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR'])->where('level', 'AREA');

        $depoSellIn = (float) (clone $depoBase)->whereIn('metrik_target', ['SELL_IN', 'Sell-In'])->sum('target_quota');
        $depoSellOut = (float) (clone $depoBase)->whereIn('metrik_target', ['SELL_OUT', 'Sell-Out'])->sum('target_quota');
        $depoAo = (int) (clone $depoBase)->where('metrik_target', 'AO')->sum(DB::raw('COALESCE(target_outlet, target_quota)'));
        $depoCount = (int) (clone $depoBase)->count();

        $areaSellIn = (float) (clone $areaBase)->whereIn('metrik_target', ['SELL_IN', 'Sell-In'])->sum('target_quota');
        $areaSellOut = (float) (clone $areaBase)->whereIn('metrik_target', ['SELL_OUT', 'Sell-Out'])->sum('target_quota');
        $areaAo = (int) (clone $areaBase)->where('metrik_target', 'AO')->sum(DB::raw('COALESCE(target_outlet, target_quota)'));
        $areaCount = (int) (clone $areaBase)->count();

        $industriCount = (int) (clone $summaryBase)->where('kategori_skema', 'INDUSTRI')->count();
        $surabayaCount = (int) (clone $summaryBase)->where('kategori_skema', 'SURABAYA')->count();

        $summary = [
            'depo_sell_in' => $depoSellIn,
            'depo_sell_out' => $depoSellOut,
            'depo_ao' => $depoAo,
            'depo_count' => $depoCount,
            'area_sell_in' => $areaSellIn,
            'area_sell_out' => $areaSellOut,
            'area_ao' => $areaAo,
            'area_count' => $areaCount,
            'industri_count' => $industriCount,
            'surabaya_count' => $surabayaCount,
            'total_sell_in' => $request->level === 'AREA' ? $areaSellIn : $depoSellIn,
            'total_sell_out' => $request->level === 'AREA' ? $areaSellOut : $depoSellOut,
            'total_ao' => $request->level === 'AREA' ? $areaAo : $depoAo,
            'total_count' => (int) (clone $summaryBase)->count(),
        ];

        $query->when($request->kategori_skema, function ($q, $k) {
            if (in_array(strtoupper($k), ['KONSUMSI', 'DISTRIBUTOR'])) {
                $q->whereIn('kategori_skema', ['KONSUMSI', 'DISTRIBUTOR']);
            } else {
                $q->where('kategori_skema', $k);
            }
        });
        $query->when($request->level, fn ($q) => $q->where('level', $request->level));

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
            'level' => 'nullable|string|in:DISTRIBUTOR,DEPO,AREA,BOTH,SALES',
            'kategori_skema' => 'required|string',
            'metrik_target' => 'required|string|max:100',
            'period' => 'nullable|string',
            'year' => 'nullable|string|size:4',
            'is_full_year' => 'nullable|boolean',
            'target_quota' => 'nullable|numeric|min:0',
            'target_outlet' => 'nullable|integer|min:0',
            'target_quota_depo' => 'nullable|numeric|min:0',
            'target_outlet_depo' => 'nullable|integer|min:0',
            'target_quota_area' => 'nullable|numeric|min:0',
            'target_outlet_area' => 'nullable|integer|min:0',
        ]);

        $kategori = strtoupper($validated['kategori_skema']);
        if ($kategori === 'DISTRIBUTOR') {
            $kategori = 'KONSUMSI';
        }

        // Determine hierarchy level
        $level = $validated['level'] ?? null;
        if (! $level) {
            if (isset($validated['target_quota_depo']) && isset($validated['target_quota_area']) && ! empty($validated['area_id'])) {
                $level = 'BOTH';
            } elseif (! empty($validated['area_id'])) {
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
                // Helper resolve ASM dan SPV
                $resolveAsm = function () use ($validated, $p) {
                    if (empty($validated['distributor_id'])) {
                        return null;
                    }
                    $asmAssign = SalesDistributorAssignment::where('distributor_id', $validated['distributor_id'])
                        ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                        ->where('is_active', true)
                        ->where(fn ($q) => $q->where('period', $p)->orWhereNull('period'))
                        ->first();
                    if (! $asmAssign) {
                        $asmAssign = SalesDistributorAssignment::where('distributor_id', $validated['distributor_id'])
                            ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                            ->where('is_active', true)
                            ->latest()
                            ->first();
                    }

                    return $asmAssign?->user_id;
                };

                $resolveSpv = function () use ($validated, $p) {
                    if (empty($validated['area_id'])) {
                        return null;
                    }
                    $spvAssign = SalesDistributorAssignment::where('area_id', $validated['area_id'])
                        ->where('is_active', true)
                        ->where(fn ($q) => $q->where('period', $p)->orWhereNull('period'))
                        ->first();
                    if (! $spvAssign) {
                        $spvAssign = SalesDistributorAssignment::where('area_id', $validated['area_id'])
                            ->where('is_active', true)
                            ->latest()
                            ->first();
                    }

                    return $spvAssign?->user_id;
                };

                // 1. Jika level DEPO atau BOTH: simpan Target Depo (ASM)
                if ($level === 'DEPO' || $level === 'BOTH') {
                    $depoQuota = (float) ($validated['target_quota_depo'] ?? $validated['target_quota'] ?? 0);
                    $depoOutlet = $validated['target_outlet_depo'] ?? ($level === 'DEPO' ? ($validated['target_outlet'] ?? null) : null);
                    $asmUserId = ($level === 'DEPO' && ! empty($validated['user_id'])) ? $validated['user_id'] : $resolveAsm();

                    $depoTarget = MasterTarget::updateOrCreate(
                        [
                            'period' => $p,
                            'kategori_skema' => $kategori,
                            'metrik_target' => $validated['metrik_target'],
                            'distributor_id' => $validated['distributor_id'] ?? null,
                            'depo_id' => $validated['depo_id'] ?? null,
                            'area_id' => null,
                            'brand_id' => $validated['brand_id'] ?? null,
                            'level' => 'DEPO',
                        ],
                        [
                            'user_id' => $asmUserId,
                            'target_quota' => $depoQuota,
                            'target_outlet' => $depoOutlet,
                        ]
                    );
                    $createdTargets[] = $depoTarget;
                }

                // 2. Jika level AREA atau BOTH: simpan Target Area (SPV)
                if (($level === 'AREA' || $level === 'BOTH') && ! empty($validated['area_id'])) {
                    $areaQuota = (float) ($validated['target_quota_area'] ?? $validated['target_quota'] ?? 0);
                    $areaOutlet = $validated['target_outlet_area'] ?? ($validated['target_outlet'] ?? null);
                    $spvUserId = ($level === 'AREA' && ! empty($validated['user_id'])) ? $validated['user_id'] : $resolveSpv();

                    $areaTarget = MasterTarget::updateOrCreate(
                        [
                            'period' => $p,
                            'kategori_skema' => $kategori,
                            'metrik_target' => $validated['metrik_target'],
                            'distributor_id' => $validated['distributor_id'] ?? null,
                            'depo_id' => $validated['depo_id'] ?? null,
                            'area_id' => $validated['area_id'],
                            'brand_id' => $validated['brand_id'] ?? null,
                            'level' => 'AREA',
                        ],
                        [
                            'user_id' => $spvUserId,
                            'target_quota' => $areaQuota,
                            'target_outlet' => $areaOutlet,
                        ]
                    );
                    $createdTargets[] = $areaTarget;
                }

                // 3. Jika non-Depo/Area (misal INDUSTRI / SURABAYA / SALES)
                if (! in_array($level, ['DEPO', 'AREA', 'BOTH'])) {
                    $salesTarget = MasterTarget::updateOrCreate(
                        [
                            'period' => $p,
                            'kategori_skema' => $kategori,
                            'metrik_target' => $validated['metrik_target'],
                            'distributor_id' => $validated['distributor_id'] ?? null,
                            'depo_id' => $validated['depo_id'] ?? null,
                            'area_id' => $validated['area_id'] ?? null,
                            'brand_id' => $validated['brand_id'] ?? null,
                            'user_id' => $validated['user_id'] ?? null,
                        ],
                        [
                            'level' => $level,
                            'target_quota' => (float) ($validated['target_quota'] ?? 0),
                            'target_outlet' => $validated['target_outlet'] ?? null,
                        ]
                    );
                    $createdTargets[] = $salesTarget;
                }
            }
        });

        $message = $isFullYear
            ? "Master Target berhasil disimpan untuk 12 bulan penuh tahun {$targetYear}"
            : ($level === 'BOTH' ? 'Target Depo & Target Area berhasil disimpan sekaligus' : 'Master Target berhasil disimpan');

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

<?php

namespace App\Http\Controllers;

use App\Exports\DistributorBreakdownExport;
use App\Exports\IncentiveCalculationExport;
use App\Models\Area;
use App\Models\Brand;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class IncentiveCalculationController extends Controller
{
    public function __construct(
        protected IncentiveCalculationService $calculationService
    ) {}

    public function calculate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'period' => 'required|string|max:300',
            'position_id' => 'nullable|integer|exists:positions,id',
            'user_id' => 'nullable|integer|exists:users,id',
        ]);

        $authUserId = $request->user()->id;
        $periods = collect(explode(',', (string) $validated['period']))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->values();
        if ($periods->isEmpty()) {
            $periods = collect([preg_replace('/[^0-9]/', '', (string) $validated['period'])]);
        }

        $results = collect();
        foreach ($periods as $p) {
            $res = $this->calculationService->execute(
                $validated['kategori_skema'],
                $p,
                $authUserId,
                isset($validated['position_id']) ? (int) $validated['position_id'] : null,
                isset($validated['user_id']) ? (int) $validated['user_id'] : null
            );
            if (! isset($validated['position_id']) && ! isset($validated['user_id'])) {
                Cache::put("incentive_calc_fresh:{$validated['kategori_skema']}:{$p}", now()->timestamp, 30);
            }
            $results = $results->merge($res);
        }

        $totalPayout = $results->sum('final_reward');
        $totalPersonil = $results->pluck('user_id')->unique()->count();

        return response()->json([
            'message' => 'Kalkulasi insentif berhasil dijalankan',
            'meta' => [
                'kategori_skema' => $validated['kategori_skema'],
                'period' => $validated['period'],
                'total_personil' => $totalPersonil,
                'total_records' => $results->count(),
                'total_payout' => $totalPayout,
            ],
            'data' => $results,
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $authUser = $request->user()?->load('role');
        $isSalesOnly = strtolower($authUser?->role?->name ?? '') === 'sales';
        $scopedUserId = $isSalesOnly ? $authUser->id : $request->user_id;

        $periods = collect(explode(',', (string) $request->period))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->values();

        // Otomatis jalankan kalkulasi saat periode belum dihitung atau cache kesegaran 30 detik habis (hindari kalkulasi ulang setiap ganti filter/paging)
        if ($request->filled('kategori_skema') && $periods->isNotEmpty()) {
            $kategori = strtoupper((string) $request->kategori_skema);
            if ($kategori === 'DISTRIBUTOR') {
                $kategori = 'KONSUMSI';
            }
            if (in_array($kategori, ['KONSUMSI', 'INDUSTRI', 'SURABAYA'], true)) {
                $forceRecalc = $request->boolean('recalculate');
                foreach ($periods as $p) {
                    $cacheKey = "incentive_calc_fresh:{$kategori}:{$p}";
                    if (! $forceRecalc && Cache::has($cacheKey)) {
                        continue;
                    }
                    try {
                        $this->calculationService->execute(
                            $kategori,
                            $p,
                            (int) ($authUser?->id ?? 1),
                            null,
                            null
                        );
                        Cache::put($cacheKey, now()->timestamp, 30);
                    } catch (\Throwable) {
                    }
                }
            }
        }

        $calculations = IncentiveCalculation::with(['user.position', 'targetHeader', 'grade', 'gradeBobot', 'calculatedBy'])
            ->when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->when($request->period, function ($q) use ($request, $periods) {
                if ($periods->count() > 1) {
                    $q->whereIn('period', $periods->all());
                } elseif ($periods->count() === 1) {
                    $q->where('period', $periods->first());
                } else {
                    $q->where('period', $request->period);
                }
            })
            ->when($request->position_id, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('position_id', $request->position_id)))
            ->when($scopedUserId, fn ($q) => $q->where('user_id', $scopedUserId))
            ->orderBy('user_id')
            ->orderBy('target_header_id')
            ->paginate($request->integer('per_page', 100));

        return response()->json($calculations);
    }

    public function exportExcel(Request $request): BinaryFileResponse
    {
        $request->validate([
            'kategori_skema' => 'nullable|in:KONSUMSI,INDUSTRI,SURABAYA',
            'period' => 'nullable|string|max:300',
            'position_id' => 'nullable|integer',
            'user_id' => 'nullable|integer',
            'search' => 'nullable|string',
        ]);

        $kategoriSkema = strtoupper((string) ($request->query('kategori_skema') ?: 'KONSUMSI'));
        $rawPeriod = (string) ($request->query('period') ?? '');
        $firstPeriod = collect(explode(',', $rawPeriod))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->first();
        $period = $firstPeriod ?: ($rawPeriod !== '' ? $rawPeriod : date('Ym'));
        $positionId = $request->query('position_id') ? (int) $request->query('position_id') : null;
        $userId = $request->query('user_id') ? (int) $request->query('user_id') : null;

        $fileName = 'incentive_report_'.($kategoriSkema ?: 'KONSUMSI').'_'.str_replace(',', '_', $rawPeriod !== '' ? $rawPeriod : $period).'.xlsx';

        if ($kategoriSkema === 'KONSUMSI') {
            if (! $request->filled('period')) {
                $request->merge(['period' => $period]);
            }
            $payload = $this->buildDistributorBreakdownPayload($request);

            return Excel::download(
                new DistributorBreakdownExport($payload['data']),
                $fileName
            );
        }

        return Excel::download(
            new IncentiveCalculationExport($kategoriSkema, $rawPeriod !== '' ? $rawPeriod : $period, $positionId, $userId),
            $fileName
        );
    }

    public function distributorBreakdown(Request $request): JsonResponse
    {
        return response()->json($this->buildDistributorBreakdownPayload($request));
    }

    /**
     * @return array{meta: array<string, mixed>, data: array<int, array<string, mixed>>}
     */
    protected function buildDistributorBreakdownPayload(Request $request): array
    {
        $request->validate([
            'period' => 'required|string|max:300',
            'position_id' => 'nullable|integer',
            'user_id' => 'nullable|integer',
            'search' => 'nullable|string',
        ]);

        $periods = collect(explode(',', (string) $request->period))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->sort()
            ->values();
        if ($periods->isEmpty()) {
            $fallback = preg_replace('/[^0-9]/', '', (string) $request->period);
            $periods = collect([$fallback !== '' ? $fallback : date('Ym')]);
        }
        $cleanPeriod = (string) $periods->first();
        $periodList = $periods->all();
        $formatPeriod = static function (string $p): string {
            if (strlen($p) !== 6) {
                return $p;
            }
            $yr = substr($p, 0, 4);
            $mo = (int) substr($p, 4, 2);

            return "{$mo}/{$yr}";
        };
        $periodFormatted = $periods->map($formatPeriod)->implode(', ');

        $positionId = $request->filled('position_id') ? (int) $request->position_id : null;
        $userId = $request->filled('user_id') ? (int) $request->user_id : null;
        $search = $request->filled('search') ? trim(strtolower($request->search)) : null;

        // TargetHeaders for KONSUMSI (3 header per posisi: SELL_IN, SELL_OUT, AO)
        $konsumsiHeaders = TargetHeader::where('kategori_skema', 'KONSUMSI')
            ->where('aktif', true)
            ->with('grades.bobots')
            ->get();

        $resolveHeadersForSalesType = function (int $salesType) use ($konsumsiHeaders): array {
            $forType = $konsumsiHeaders->where('sales_type', $salesType);
            $findMetric = function (string $metric) use ($forType): ?TargetHeader {
                return $forType->first(function ($h) use ($metric) {
                    $t = strtoupper(str_replace(['-', ' '], '_', trim((string) $h->type)));
                    $isAo = in_array($t, ['AO', 'ACTIVE_OUTLET', 'OUTLET'], true) || str_contains($t, 'AO') || str_contains($t, 'OUTLET');
                    $isSo = str_contains($t, 'OUT') && ! $isAo;
                    $isSi = ! $isAo && ! $isSo;
                    return match ($metric) {
                        'SI' => $isSi,
                        'SO' => $isSo,
                        'AO' => $isAo,
                        default => false,
                    };
                });
            };
            return [
                'si' => $findMetric('SI'),
                'so' => $findMetric('SO'),
                'ao' => $findMetric('AO'),
            ];
        };

        $selectedUser = $userId ? User::with('position')->find($userId) : null;
        $selectedPos = $positionId ? Position::find($positionId) : null;
        $userPosCode = strtoupper($selectedUser?->position?->code ?? $selectedPos?->code ?? '');
        $filterPosCode = strtoupper($selectedPos?->code ?? '');
        $isSpv = $selectedUser && in_array(strtoupper($selectedUser->position?->code ?? ''), ['SPV', 'ASC'], true);
        $isAsm = $selectedUser && strtoupper($selectedUser->position?->code ?? '') === 'ASM';

        $activeSalesType = (int) ($selectedUser?->position_id
            ?? $positionId
            ?? (Position::where('code', 'ASM')->value('id') ?? 1));
        $activeHeaders = $resolveHeadersForSalesType($activeSalesType);
        if (! $activeHeaders['si'] && ! $activeHeaders['so'] && ! $activeHeaders['ao'] && in_array($userPosCode, ['ASC', 'SPV'], true)) {
            $spvPosId = (int) (Position::where('code', 'SPV')->value('id') ?? 0);
            if ($spvPosId > 0) {
                $activeHeaders = $resolveHeadersForSalesType($spvPosId);
            }
        }
        $posSiHeader = $activeHeaders['si'];
        $posSoHeader = $activeHeaders['so'];
        $posAoHeader = $activeHeaders['ao'];

        // Preload active assignments for ASM and SPV
        $asmAssignments = SalesDistributorAssignment::whereNotNull('distributor_id')
            ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
            ->where('is_active', true)
            ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
            ->with('user:id,name')
            ->get()
            ->keyBy('distributor_id');

        $spvAssignments = SalesDistributorAssignment::whereNotNull('area_id')
            ->whereHas('user.position', fn ($q) => $q->whereIn('code', ['SPV', 'ASC']))
            ->where('is_active', true)
            ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
            ->with('user:id,name')
            ->get()
            ->keyBy('area_id');

        // 1. Get relevant DEPO target rows (khusus SELL_IN agar tidak terduplikasi bila ada metrik lain di level DEPO)
        $depoQuery = MasterTarget::with(['distributor', 'depo', 'brand', 'user.position'])
            ->whereIn('period', $periodList)
            ->where('kategori_skema', 'KONSUMSI')
            ->where('level', 'DEPO')
            ->where('metrik_target', 'SELL_IN');

        $assignedAreaIds = collect();

        if ($isAsm) {
            $assignedDistIds = SalesDistributorAssignment::where('user_id', $userId)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
                ->pluck('distributor_id')
                ->filter()
                ->unique();

            $depoQuery->where(function ($q) use ($userId, $assignedDistIds) {
                $q->where('user_id', $userId);
                if ($assignedDistIds->isNotEmpty()) {
                    $q->orWhereIn('distributor_id', $assignedDistIds);
                }
            });
        } elseif ($isSpv) {
            $assignedAreaIds = SalesDistributorAssignment::where('user_id', $userId)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
                ->pluck('area_id')
                ->filter()
                ->unique();

            $assignedDepoIds = Area::whereIn('id', $assignedAreaIds)->pluck('depo_id')->filter()->unique();

            $spvDepoIds = MasterTarget::whereIn('period', $periodList)
                ->where('kategori_skema', 'KONSUMSI')
                ->where('level', 'AREA')
                ->where(function ($q) use ($userId, $assignedAreaIds) {
                    $q->where('user_id', $userId);
                    if ($assignedAreaIds->isNotEmpty()) {
                        $q->orWhereIn('area_id', $assignedAreaIds);
                    }
                })
                ->pluck('depo_id')
                ->merge($assignedDepoIds)
                ->unique();

            $depoQuery->whereIn('depo_id', $spvDepoIds);
        } elseif ($filterPosCode === 'ASM') {
            $asmUserIds = User::whereHas('position', fn ($q) => $q->where('code', 'ASM'))->pluck('id');
            $assignedDistIds = SalesDistributorAssignment::whereIn('user_id', $asmUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
                ->pluck('distributor_id')
                ->filter()
                ->unique();

            $depoQuery->where(function ($q) use ($asmUserIds, $assignedDistIds) {
                $q->whereIn('user_id', $asmUserIds);
                if ($assignedDistIds->isNotEmpty()) {
                    $q->orWhereIn('distributor_id', $assignedDistIds);
                }
            });
        } elseif (in_array($filterPosCode, ['SPV', 'ASC'], true)) {
            $spvUserIds = User::whereHas('position', fn ($q) => $q->where('code', $filterPosCode))->pluck('id');
            $spvAreaIds = SalesDistributorAssignment::whereIn('user_id', $spvUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
                ->pluck('area_id')
                ->filter()
                ->unique();

            $spvDepoIds = MasterTarget::whereIn('period', $periodList)
                ->where('kategori_skema', 'KONSUMSI')
                ->where('level', 'AREA')
                ->where(function ($q) use ($spvUserIds, $spvAreaIds) {
                    $q->whereIn('user_id', $spvUserIds);
                    if ($spvAreaIds->isNotEmpty()) {
                        $q->orWhereIn('area_id', $spvAreaIds);
                    }
                })
                ->pluck('depo_id')
                ->merge(Area::whereIn('id', $spvAreaIds)->pluck('depo_id'))
                ->unique();

            $depoQuery->whereIn('depo_id', $spvDepoIds);
        }

        $depoTargets = $depoQuery->get();

        // Realization records cache with SQL aggregation (hemat memori untuk multi-periode)
        $allSellin = SellinDistributor::whereIn('period', $periodList)
            ->select(['period', 'distributor_id', 'depo_id', 'brand_id', 'user_id', 'transaction_date', 'volume_kg'])
            ->get();
        $allSellout = SelloutDistributor::whereIn('period', $periodList)
            ->where('is_out_of_area', false)
            ->selectRaw('period, depo_id, area_id, brand_id, COALESCE(SUM(volume_kg), 0) as volume_kg, COALESCE(SUM(active_outlet_count), 0) as active_outlet_count')
            ->groupBy('period', 'depo_id', 'area_id', 'brand_id')
            ->get();

        $sellinByDistBrand = $allSellin->groupBy(fn ($s) => $s->period . '_' . $s->distributor_id . '_' . ($s->brand_id ?? 0));
        $sellinByDist = $allSellin->groupBy(fn ($s) => $s->period . '_' . $s->distributor_id);
        $hasDepoLevelSellin = $allSellin->whereNotNull('depo_id')->isNotEmpty();
        $sellinByDepoBrand = $allSellin->whereNotNull('depo_id')->groupBy(fn ($s) => $s->period . '_' . $s->depo_id . '_' . ($s->brand_id ?? 0));
        $sellinByDepo = $allSellin->whereNotNull('depo_id')->groupBy(fn ($s) => $s->period . '_' . $s->depo_id);

        $selloutByDepoBrand = $allSellout->groupBy(fn ($s) => $s->period . '_' . $s->depo_id . '_' . ($s->brand_id ?? 0));
        $selloutByDepo = $allSellout->groupBy(fn ($s) => $s->period . '_' . $s->depo_id);
        $hasAreaLevelSellout = $allSellout->whereNotNull('area_id')->isNotEmpty();
        $selloutByAreaBrand = $allSellout->whereNotNull('area_id')->groupBy(fn ($s) => $s->period . '_' . $s->area_id . '_' . ($s->brand_id ?? 0));
        $selloutByArea = $allSellout->whereNotNull('area_id')->groupBy(fn ($s) => $s->period . '_' . $s->area_id);

        // 2. Get relevant AREA target rows
        $areaQuery = MasterTarget::with(['area', 'brand', 'user.position'])
            ->whereIn('period', $periodList)
            ->where('kategori_skema', 'KONSUMSI')
            ->where('level', 'AREA');

        if ($isSpv) {
            $areaQuery->where(function ($q) use ($userId, $assignedAreaIds) {
                $q->where('user_id', $userId);
                if ($assignedAreaIds->isNotEmpty()) {
                    $q->orWhereIn('area_id', $assignedAreaIds);
                }
            });
        } elseif (in_array($filterPosCode, ['SPV', 'ASC'], true)) {
            $spvUserIds = User::whereHas('position', fn ($q) => $q->where('code', $filterPosCode))->pluck('id');
            $spvAreaIds = SalesDistributorAssignment::whereIn('user_id', $spvUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereIn('period', $periodList)->orWhereNull('period'))
                ->pluck('area_id')
                ->filter()
                ->unique();

            $areaQuery->where(function ($q) use ($spvUserIds, $spvAreaIds) {
                $q->whereIn('user_id', $spvUserIds);
                if ($spvAreaIds->isNotEmpty()) {
                    $q->orWhereIn('area_id', $spvAreaIds);
                }
            });
        }

        $allAreaTargets = $areaQuery->get()->groupBy(fn ($a) => $a->period . '_' . $a->depo_id . '_' . ($a->brand_id ?? 0));

        $allBrands = Brand::all(['id', 'code', 'name', 'is_all_brands', 'component_brand_ids']);
        $effectiveBrandIdsMap = Brand::buildEffectiveBrandIdsMap($allBrands);

        $collectMatchedRecords = static function (?int $targetBrandId, string $prefix, $byBrandMap, $byAllMap) use ($effectiveBrandIdsMap) {
            if (! $targetBrandId || ! array_key_exists($targetBrandId, $effectiveBrandIdsMap) || $effectiveBrandIdsMap[$targetBrandId] === null) {
                return $byAllMap->get($prefix) ?? collect();
            }

            $effIds = $effectiveBrandIdsMap[$targetBrandId];
            if (count($effIds) === 1) {
                return $byBrandMap->get($prefix . '_' . $effIds[0]) ?? collect();
            }

            $merged = collect();
            foreach ($effIds as $bId) {
                $rows = $byBrandMap->get($prefix . '_' . $bId);
                if ($rows && $rows->isNotEmpty()) {
                    $merged = $merged->concat($rows);
                }
            }

            return $merged;
        };

        $cardItems = [];
        $uniquePersonil = [];
        $totalGrandReward = 0;
        $totalGrandTargetSi = 0;
        $totalGrandRealSi = 0;
        $totalGrandTargetSo = 0;
        $totalGrandRealSo = 0;
        $totalGrandTargetAo = 0;
        $totalGrandRealAo = 0;

        foreach ($depoTargets as $dt) {
            $dtPeriod = (string) $dt->period;
            $dtPeriodFormatted = $formatPeriod($dtPeriod);
            $distName = $dt->distributor?->name ?? '-';
            $depoName = $dt->depo?->name ?? '-';
            $brandName = $dt->brand?->name ?? '-';
            $asmName = $dt->user?->name ?? $asmAssignments->get($dt->distributor_id)?->user?->name ?? '-';

            if ($search) {
                $match = str_contains(strtolower($distName), $search)
                    || str_contains(strtolower($depoName), $search)
                    || str_contains(strtolower($brandName), $search)
                    || str_contains(strtolower($asmName), $search);
                if (!$match) continue;
            }

            if ($asmName !== '-' && ! $isSpv && ! in_array($filterPosCode, ['SPV', 'ASC'], true)) {
                $uniquePersonil[strtolower($asmName)] = true;
            }

            // Sell-In (utamakan depo_id + filter masa aktif ASM jika transaction_date tersedia)
            $targetSi = (float) $dt->target_quota;
            $targetSiBrandId = $dt->brand_id ? (int) $dt->brand_id : null;
            if ($hasDepoLevelSellin && $dt->depo_id) {
                $matchedSiRecords = $collectMatchedRecords(
                    $targetSiBrandId,
                    $dtPeriod . '_' . $dt->depo_id,
                    $sellinByDepoBrand,
                    $sellinByDepo
                );
            } else {
                $matchedSiRecords = $collectMatchedRecords(
                    $targetSiBrandId,
                    $dtPeriod . '_' . $dt->distributor_id,
                    $sellinByDistBrand,
                    $sellinByDist
                );
            }

            $asmUser = $dt->user ?? $asmAssignments->get($dt->distributor_id)?->user;
            if ($asmUser) {
                $from = $asmUser->aktif_from ? $asmUser->aktif_from->format('Y-m-d') : null;
                $to = $asmUser->aktif_to ? $asmUser->aktif_to->format('Y-m-d') : null;
                $matchedSiRecords = $matchedSiRecords->filter(function ($s) use ($from, $to, $asmUser) {
                    if ($s->user_id && (int) $s->user_id === (int) $asmUser->id) {
                        return true;
                    }
                    if (! $s->transaction_date) {
                        return true;
                    }
                    $d = $s->transaction_date->format('Y-m-d');
                    if ($from && $d < $from) {
                        return false;
                    }
                    if ($to && $d > $to) {
                        return false;
                    }

                    return true;
                });
            }

            $realSi = (float) $matchedSiRecords->sum('volume_kg');
            $achSiPct = $targetSi > 0 ? round(($realSi / $targetSi) * 100, 1) : 0.0;

            $siEval = $this->evaluateMetricReward($posSiHeader, $targetSi, $realSi);
            $rewardSi = $siEval['reward'];
            $siPassed = $siEval['passed'];

            // Areas
            $areaGroupKey = $dtPeriod . '_' . $dt->depo_id . '_' . ($dt->brand_id ?? 0);
            $areaTargets = $allAreaTargets->get($areaGroupKey) ?? collect();

            if ($areaTargets->isEmpty()) {
                $areaTargets = $allAreaTargets->get($dtPeriod . '_' . $dt->depo_id . '_0') ?? collect();
            }

            $areaList = [];
            $depoTotalAreaReward = 0;

            foreach ($areaTargets as $at) {
                $areaName = $at->area?->name ?? '-';
                $areaCode = $at->area?->code ?? '-';
                $spvName = $at->user?->name ?? $spvAssignments->get($at->area_id)?->user?->name ?? '-';
                $areaBrandName = $at->brand?->name ?? $brandName;

                if ($spvName !== '-' && ($isSpv || in_array($filterPosCode, ['SPV', 'ASC'], true))) {
                    $uniquePersonil[strtolower($spvName)] = true;
                }

                $targetSo = (float) $at->target_quota;
                $targetAo = (int) $at->target_outlet;

                // Sell-Out & AO (O(1) hash map lookup: utamakan area_id jika tersedia, fallback ke depo_id)
                $targetSoBrandId = $at->brand_id ? (int) $at->brand_id : null;
                if ($hasAreaLevelSellout && $at->area_id) {
                    $matchedSoRecords = $collectMatchedRecords(
                        $targetSoBrandId,
                        $dtPeriod . '_' . $at->area_id,
                        $selloutByAreaBrand,
                        $selloutByArea
                    );
                } else {
                    $matchedSoRecords = $collectMatchedRecords(
                        $targetSoBrandId,
                        $dtPeriod . '_' . $dt->depo_id,
                        $selloutByDepoBrand,
                        $selloutByDepo
                    );
                }

                $realSo = (float) $matchedSoRecords->sum('volume_kg');
                $realAo = (int) $matchedSoRecords->sum('active_outlet_count');

                $achSoPct = $targetSo > 0 ? round(($realSo / $targetSo) * 100, 1) : 0.0;
                $achAoPct = $targetAo > 0 ? round(($realAo / $targetAo) * 100, 1) : 0.0;

                $soEval = $this->evaluateMetricReward($posSoHeader, $targetSo, $realSo);
                $rewardSo = $soEval['reward'];
                $soPassed = $soEval['passed'];

                $aoEval = $this->evaluateMetricReward($posAoHeader, (float) $targetAo, (float) $realAo);
                // Aturan 3: AO minimal wajib >= min% DAN salah satu/keduanya SI atau SO tercapai
                $rewardAo = ($siPassed || $soPassed) ? $aoEval['reward'] : 0.0;
                $subtotalAreaReward = $rewardSo + $rewardAo;

                $depoTotalAreaReward += $subtotalAreaReward;

                $areaList[] = [
                    'no' => 0,
                    'area_name' => $areaName,
                    'area_code' => $areaCode,
                    'brand_name' => $areaBrandName,
                    'spv_name' => $spvName,
                    'sell_out_target' => $targetSo,
                    'sell_out_real' => $realSo,
                    'sell_out_ach_pct' => $achSoPct,
                    'sell_out_reward' => $rewardSo,
                    'ao_target' => $targetAo,
                    'ao_real' => $realAo,
                    'ao_ach_pct' => $achAoPct,
                    'ao_reward' => $rewardAo,
                    'sell_in_spv_reward' => $isSpv ? $rewardSi : 0.0,
                    'subtotal_area_reward' => $subtotalAreaReward,
                ];

                $totalGrandTargetSo += $targetSo;
                $totalGrandRealSo += $realSo;
                $totalGrandTargetAo += $targetAo;
                $totalGrandRealAo += $realAo;
            }

            usort($areaList, static fn ($a, $b) => strcasecmp((string) $a['area_name'], (string) $b['area_name']));
            foreach ($areaList as $idx => &$arItem) {
                $arItem['no'] = $idx + 1;
            }
            unset($arItem);

            $cardTotalReward = $rewardSi + $depoTotalAreaReward;

            $totalGrandReward += $cardTotalReward;
            $totalGrandTargetSi += $targetSi;
            $totalGrandRealSi += $realSi;

            $cardItems[] = [
                'id' => $dt->id,
                'distributor_name' => $distName,
                'depo_name' => $depoName,
                'brand_name' => $brandName,
                'asm_name' => $asmName,
                'period' => $dtPeriod,
                'period_formatted' => $dtPeriodFormatted,
                'sell_in_target' => $targetSi,
                'sell_in_real' => $realSi,
                'sell_in_ach_pct' => $achSiPct,
                'sell_in_reward' => $rewardSi,
                'total_depo_reward' => $cardTotalReward,
                'areas_count' => count($areaList),
                'areas' => $areaList,
            ];
        }

        usort($cardItems, static function ($a, $b) {
            return strcmp((string) $a['period'], (string) $b['period'])
                ?: strcasecmp((string) $a['distributor_name'], (string) $b['distributor_name'])
                ?: strcasecmp((string) $a['depo_name'], (string) $b['depo_name'])
                ?: strcasecmp((string) $a['brand_name'], (string) $b['brand_name']);
        });

        $totalPersonilCount = $selectedUser ? 1 : count($uniquePersonil);

        return [
            'meta' => [
                'period' => $periods->implode(','),
                'period_formatted' => $periodFormatted,
                'position_id' => $positionId,
                'user_id' => $userId,
                'user_name' => $selectedUser?->name,
                'user_role' => $userPosCode,
                'total_personil' => $totalPersonilCount,
                'total_depos' => count($cardItems),
                'total_areas' => collect($cardItems)->sum('areas_count'),
                'total_target_sell_in' => $totalGrandTargetSi,
                'total_real_sell_in' => $totalGrandRealSi,
                'total_target_sell_out' => $totalGrandTargetSo,
                'total_real_sell_out' => $totalGrandRealSo,
                'total_target_ao' => $totalGrandTargetAo,
                'total_real_ao' => $totalGrandRealAo,
                'total_reward' => $totalGrandReward,
            ],
            'data' => $cardItems,
        ];
    }

    /**
     * Evaluasi reward per metrik tanpa cap realisasi:
     * - Cek min_achievement_pct pada TargetHeader.
     * - Model pengali=true: Realisasi * Bobot Tier * (Bobot Header / 100).
     * - Model pengali=false (AO Nominal Tetap): Nominal Tier * (Bobot Header / 100).
     *
     * @return array{reward: float, passed: bool}
     */
    protected function evaluateMetricReward(?TargetHeader $header, float $target, float $real): array
    {
        if (! $header || $target <= 0) {
            return ['reward' => 0.0, 'passed' => false];
        }

        $matchedGrade = $header->grades->first(function ($grade) use ($target) {
            return $target >= (float) $grade->target_from && $target <= (float) $grade->target_to;
        });

        if (! $matchedGrade && $header->grades->isNotEmpty()) {
            $maxGrade = $header->grades->sortByDesc(fn ($g) => (float) $g->target_to)->first();
            $minGrade = $header->grades->sortBy(fn ($g) => (float) $g->target_from)->first();
            $matchedGrade = $target > (float) $maxGrade->target_to ? $maxGrade : $minGrade;
        }

        if (! $matchedGrade) {
            return ['reward' => 0.0, 'passed' => false];
        }

        $achPct = ($real / $target) * 100.0;
        $minAchPct = (float) ($header->min_achievement_pct ?? 0);
        if ($achPct < $minAchPct) {
            return ['reward' => 0.0, 'passed' => false];
        }

        $matchedBobot = $matchedGrade->bobots->first(function ($tier) use ($achPct) {
            return $achPct >= (float) $tier->percent_from && $achPct <= (float) $tier->percent_to;
        });

        if (! $matchedBobot && $matchedGrade->bobots->isNotEmpty()) {
            $minPercent = (float) $matchedGrade->bobots->min(fn ($t) => (float) $t->percent_from);
            if ($achPct >= $minPercent) {
                $matchedBobot = $matchedGrade->bobots
                    ->filter(fn ($t) => $achPct >= (float) $t->percent_from)
                    ->sortByDesc(fn ($t) => (float) $t->percent_from)
                    ->first();
            }
        }

        if (! $matchedBobot) {
            return ['reward' => 0.0, 'passed' => false];
        }

        $headerBobotFactor = (float) $header->bobot / 100.0;
        $reward = $matchedBobot->pengali
            ? (float) $matchedBobot->bobot * $real * $headerBobotFactor
            : (float) $matchedBobot->nominal * $headerBobotFactor;

        return ['reward' => $reward, 'passed' => true];
    }

    protected function calculateRewardForMetric(?TargetHeader $header, float $target, float $real): float
    {
        return $this->evaluateMetricReward($header, $target, $real)['reward'];
    }

    /**
     * Breakdown audit lengkap per Sales Industri (ASM / SPV / ASC): Sell-In, NOO, Customer, dan Rumus Transparan.
     */
    public function industriBreakdown(Request $request): JsonResponse
    {
        $request->validate([
            'period' => 'required|string|max:300',
            'position_id' => 'nullable|integer|exists:positions,id',
            'user_id' => 'nullable|integer|exists:users,id',
            'search' => 'nullable|string',
        ]);

        $periods = collect(explode(',', (string) $request->period))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->sort()
            ->values();
        if ($periods->isEmpty()) {
            $periods = collect([date('Ym')]);
        }

        $positionId = $request->filled('position_id') ? (int) $request->position_id : null;
        $userId = $request->filled('user_id') ? (int) $request->user_id : null;
        $search = $request->filled('search') ? trim((string) $request->search) : null;

        $allCards = collect();
        $totalTargetSi = 0.0;
        $totalActualSi = 0.0;
        $totalTargetNoo = 0.0;
        $totalActualNoo = 0.0;
        $totalActualNooKg = 0.0;
        $totalPayout = 0.0;
        $personilIds = [];

        foreach ($periods as $p) {
            $evaluated = $this->calculationService->evaluateIndustriForPeriod($p, $positionId, $userId, $search, true);
            $meta = $evaluated['meta'] ?? [];
            $totalTargetSi += (float) ($meta['total_target_sell_in_kg'] ?? 0);
            $totalActualSi += (float) ($meta['total_actual_sell_in_kg'] ?? 0);
            $totalTargetNoo += (float) ($meta['total_target_noo'] ?? 0);
            $totalActualNoo += (float) ($meta['total_actual_noo'] ?? 0);
            $totalActualNooKg += (float) ($meta['total_actual_noo_kg'] ?? 0);
            $totalPayout += (float) ($meta['total_payout'] ?? 0);

            foreach ($evaluated['cards'] as $card) {
                unset($card['header_records']);
                $card['period'] = $p;
                if (! empty($card['user_id'])) {
                    $personilIds[$card['user_id']] = true;
                }
                $allCards->push($card);
            }
        }

        return response()->json([
            'meta' => [
                'period' => $periods->implode(','),
                'total_personil' => count($personilIds),
                'total_target_sell_in_kg' => $totalTargetSi,
                'total_actual_sell_in_kg' => $totalActualSi,
                'total_target_noo' => $totalTargetNoo,
                'total_actual_noo' => $totalActualNoo,
                'total_actual_noo_kg' => $totalActualNooKg,
                'total_payout' => $totalPayout,
            ],
            'data' => $allCards->values(),
        ]);
    }

    /**
     * Breakdown audit lengkap Sales Surabaya (TO, SM, dan ASC beserta tabel rincian bawahan).
     */
    public function surabayaBreakdown(Request $request): JsonResponse
    {
        $request->validate([
            'period' => 'required|string|max:300',
            'position_id' => 'nullable|integer|exists:positions,id',
            'user_id' => 'nullable|integer|exists:users,id',
            'search' => 'nullable|string',
        ]);

        $periods = collect(explode(',', (string) $request->period))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->sort()
            ->values();
        if ($periods->isEmpty()) {
            $periods = collect([date('Ym')]);
        }

        $positionId = $request->filled('position_id') ? (int) $request->position_id : null;
        $userId = $request->filled('user_id') ? (int) $request->user_id : null;
        $search = $request->filled('search') ? trim((string) $request->search) : null;

        $allCards = collect();
        $totalTargetKg = 0.0;
        $totalActualKg = 0.0;
        $totalPayout = 0.0;
        $personilIds = [];

        foreach ($periods as $p) {
            $evaluated = $this->calculationService->evaluateSurabayaForPeriod($p, $positionId, $userId, $search, true);
            $meta = $evaluated['meta'] ?? [];
            $totalTargetKg += (float) ($meta['total_target_kg'] ?? 0);
            $totalActualKg += (float) ($meta['total_actual_kg'] ?? 0);
            $totalPayout += (float) ($meta['total_payout'] ?? 0);

            foreach ($evaluated['cards'] as $card) {
                unset($card['header_records']);
                $card['period'] = $p;
                if (! empty($card['user_id'])) {
                    $personilIds[$card['user_id']] = true;
                }
                $allCards->push($card);
            }
        }

        return response()->json([
            'meta' => [
                'period' => $periods->implode(','),
                'total_personil' => count($personilIds),
                'total_target_kg' => $totalTargetKg,
                'total_actual_kg' => $totalActualKg,
                'total_payout' => $totalPayout,
            ],
            'data' => $allCards->values(),
        ]);
    }
}

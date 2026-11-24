<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\Region;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SellinIndustri;
use App\Models\SelloutDistributor;
use App\Models\SelloutSalesSurabaya;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user()->load(['role', 'position']);
        $roleName = strtolower($user->role?->name ?? '');
        $posCode = strtoupper((string) ($user->position?->code ?? ''));

        $isAdminRole = in_array($roleName, ['admin', 'superadmin', 'administrator', 'admin sales'], true);
        $isManagementRole = str_contains($roleName, 'direksi')
            || str_contains($roleName, 'director')
            || str_contains($roleName, 'manager')
            || str_contains($roleName, 'management');
        $isNsm = $posCode === 'NSM';
        $isLsm = $posCode === 'LSM';
        $isExecutive = $isAdminRole || $isManagementRole || $isNsm || $isLsm;

        // Ambil periode dari query (mendukung multi-periode dipisah koma: 202607,202608,202609), atau default ke periode terbaru di master_targets
        $latestPeriod = MasterTarget::max('period') ?? date('Ym');
        $rawPeriod = (string) $request->query('period', $latestPeriod);
        $periodList = collect(explode(',', $rawPeriod))
            ->map(fn ($p) => preg_replace('/[^0-9]/', '', $p))
            ->filter(fn ($p) => strlen($p) === 6)
            ->unique()
            ->sort()
            ->values()
            ->all();

        if (empty($periodList)) {
            $periodList = [$latestPeriod];
        }
        $period = implode(',', $periodList);

        $availablePeriods = MasterTarget::distinct()
            ->orderByDesc('period')
            ->pluck('period')
            ->take(24)
            ->values();

        if ($availablePeriods->isEmpty()) {
            $availablePeriods = collect($periodList);
        }

        if ($isExecutive) {
            $scopedDistIds = null;
            $scopeLabel = 'Nasional';
            if ($isLsm && ! $isAdminRole && ! $isManagementRole && ! $isNsm) {
                $regionIds = SalesDistributorAssignment::where('user_id', $user->id)
                    ->where('is_active', true)
                    ->pluck('region_id')
                    ->filter()
                    ->unique()
                    ->all();
                if (! empty($regionIds)) {
                    $scopedDistIds = Distributor::whereIn('region_id', $regionIds)->pluck('id')->all();
                    $regionNames = Region::whereIn('id', $regionIds)->pluck('name')->implode(', ');
                    $scopeLabel = $regionNames !== '' ? "Region {$regionNames}" : 'Region Penugasan';
                }
            }

            return response()->json($this->getAdminDashboard(
                $user,
                $period,
                $periodList,
                $availablePeriods,
                $isAdminRole,
                $scopedDistIds,
                $scopeLabel
            ));
        }

        return response()->json($this->getSalesDashboard($user, $period, $periodList, $availablePeriods));
    }

    private function getAdminDashboard(
        User $user,
        string $period,
        array $periodList,
        $availablePeriods,
        bool $canManage = true,
        ?array $scopedDistIds = null,
        string $scopeLabel = 'Nasional'
    ): array {
        $scopeDist = fn ($q) => $scopedDistIds !== null ? $q->whereIn('distributor_id', $scopedDistIds) : $q;

        $targetSellInKg = (float) $scopeDist(MasterTarget::whereIn('period', $periodList)
            ->where('metrik_target', 'SELL_IN'))
            ->sum('target_quota');

        $targetSellOutKg = (float) $scopeDist(MasterTarget::whereIn('period', $periodList)
            ->where('metrik_target', 'SELL_OUT'))
            ->sum('target_quota');

        $targetOutletCount = (int) $scopeDist(MasterTarget::whereIn('period', $periodList)
            ->where('level', 'AREA'))
            ->sum('target_outlet');

        $sellinTotals = $scopeDist(SellinDistributor::whereIn('period', $periodList))
            ->selectRaw('COALESCE(SUM(volume_kg), 0) as vol, COALESCE(SUM(nominal), 0) as nom')
            ->first();
        $realisasiSellInKg = (float) ($sellinTotals->vol ?? 0);
        $totalDppSellIn = (float) ($sellinTotals->nom ?? 0);

        $selloutTotals = $scopeDist(SelloutDistributor::whereIn('period', $periodList)
            ->where('is_out_of_area', false))
            ->selectRaw('COALESCE(SUM(volume_kg), 0) as vol, COALESCE(SUM(nominal), 0) as nom, COALESCE(SUM(active_outlet_count), 0) as ao')
            ->first();
        $realisasiSellOutKg = (float) ($selloutTotals->vol ?? 0);
        $totalDppSellOut = (float) ($selloutTotals->nom ?? 0);
        $realisasiOutletCount = (int) ($selloutTotals->ao ?? 0);

        $achSellInPct = $targetSellInKg > 0 ? round(($realisasiSellInKg / $targetSellInKg) * 100, 1) : 0.0;
        $achSellOutPct = $targetSellOutKg > 0 ? round(($realisasiSellOutKg / $targetSellOutKg) * 100, 1) : 0.0;
        $achOutletPct = $targetOutletCount > 0 ? round(($realisasiOutletCount / $targetOutletCount) * 100, 1) : 0.0;
        $sellThroughPct = $realisasiSellInKg > 0 ? round(($realisasiSellOutKg / $realisasiSellInKg) * 100, 1) : 0.0;

        $totalIncentivePool = (float) IncentiveCalculation::whereIn('period', $periodList)->sum('final_reward');
        $incentiveRatioPct = $totalDppSellOut > 0 ? round(($totalIncentivePool / $totalDppSellOut) * 100, 2) : 0.0;

        $totalDistributors = $scopedDistIds !== null
            ? count($scopedDistIds)
            : (int) Distributor::count();
        $totalDepos = $scopedDistIds !== null
            ? (int) Depo::whereIn('distributor_id', $scopedDistIds)->count()
            : (int) Depo::count();
        $totalAreas = $scopedDistIds !== null
            ? (int) Area::whereHas('depo', fn ($q) => $q->whereIn('distributor_id', $scopedDistIds))->count()
            : (int) Area::count();
        $totalSalesPersonil = (int) User::whereHas('role', fn ($q) => $q->where('name', 'Sales'))->count();

        // Preload target & realisasi periode terpilih untuk Leaderboard (O(1) lookup, tanpa N+1)
        $allTargets = $scopeDist(MasterTarget::whereIn('period', $periodList))
            ->get(['user_id', 'level', 'metrik_target', 'distributor_id', 'depo_id', 'area_id', 'brand_id', 'target_quota', 'target_outlet']);

        $allAssignments = SalesDistributorAssignment::where('is_active', true)
            ->when($scopedDistIds !== null, fn ($q) => $q->whereIn('distributor_id', $scopedDistIds))
            ->get(['user_id', 'distributor_id', 'depo_id', 'area_id']);

        $sellinByDepo = $scopeDist(SellinDistributor::whereIn('period', $periodList))
            ->whereNotNull('depo_id')
            ->selectRaw('depo_id, SUM(volume_kg) as vol')
            ->groupBy('depo_id')
            ->pluck('vol', 'depo_id');

        $sellinByDist = $scopeDist(SellinDistributor::whereIn('period', $periodList))
            ->selectRaw('distributor_id, SUM(volume_kg) as vol')
            ->groupBy('distributor_id')
            ->pluck('vol', 'distributor_id');

        $hasDepoSellin = $sellinByDepo->isNotEmpty();

        $selloutByDepo = $scopeDist(SelloutDistributor::whereIn('period', $periodList))
            ->where('is_out_of_area', false)
            ->whereNotNull('depo_id')
            ->selectRaw('depo_id, SUM(volume_kg) as vol, SUM(active_outlet_count) as ao')
            ->groupBy('depo_id')
            ->get()
            ->keyBy('depo_id');

        $selloutByDist = $scopeDist(SelloutDistributor::whereIn('period', $periodList))
            ->where('is_out_of_area', false)
            ->whereNotNull('distributor_id')
            ->selectRaw('distributor_id, SUM(volume_kg) as vol, SUM(active_outlet_count) as ao')
            ->groupBy('distributor_id')
            ->get()
            ->keyBy('distributor_id');

        $selloutByArea = $scopeDist(SelloutDistributor::whereIn('period', $periodList))
            ->where('is_out_of_area', false)
            ->whereNotNull('area_id')
            ->selectRaw('area_id, SUM(volume_kg) as vol, SUM(active_outlet_count) as ao')
            ->groupBy('area_id')
            ->get()
            ->keyBy('area_id');

        $areaToDepoMap = Area::pluck('depo_id', 'id');

        // Pre-index target Depo (SELL_IN) per depo_id dan target Area (SELL_OUT & AO) per depo_id & area_id
        $depoSellInTargetsByDepo = [];
        $areaSellOutTargetsByDepo = [];
        $areaAoTargetsByDepo = [];
        $areaSellOutTargetsByArea = [];
        $areaAoTargetsByArea = [];
        $targetsByUser = [];

        foreach ($allTargets as $t) {
            if ($t->user_id) {
                $targetsByUser[$t->user_id][] = $t;
            }
            $metrik = strtoupper((string) $t->metrik_target);
            if ($t->level === 'DEPO' && $metrik === 'SELL_IN' && $t->depo_id) {
                $depoSellInTargetsByDepo[$t->depo_id] = ($depoSellInTargetsByDepo[$t->depo_id] ?? 0.0) + (float) $t->target_quota;
            }
            if ($t->level === 'AREA') {
                if ($metrik === 'SELL_OUT') {
                    if ($t->depo_id) {
                        $areaSellOutTargetsByDepo[$t->depo_id] = ($areaSellOutTargetsByDepo[$t->depo_id] ?? 0.0) + (float) $t->target_quota;
                    }
                    if ($t->area_id) {
                        $areaSellOutTargetsByArea[$t->area_id] = ($areaSellOutTargetsByArea[$t->area_id] ?? 0.0) + (float) $t->target_quota;
                    }
                }
                if ($t->target_outlet) {
                    if ($t->depo_id) {
                        $areaAoTargetsByDepo[$t->depo_id] = ($areaAoTargetsByDepo[$t->depo_id] ?? 0) + (int) $t->target_outlet;
                    }
                    if ($t->area_id) {
                        $areaAoTargetsByArea[$t->area_id] = ($areaAoTargetsByArea[$t->area_id] ?? 0) + (int) $t->target_outlet;
                    }
                }
            }
        }

        $assignmentsByUser = $allAssignments->groupBy('user_id');

        // Agregasi kalkulasi insentif periode ini (1 query)
        $userCalcs = IncentiveCalculation::whereIn('period', $periodList)
            ->get()
            ->groupBy('user_id');

        // Top Sales Leaderboard dengan rincian Sell-In, Sell-Out, AO + Realisasi & Persentase
        $salesLeaderboard = User::whereHas('role', fn ($q) => $q->where('name', 'Sales'))
            ->with(['position'])
            ->get()
            ->map(function ($s) use (
                $targetsByUser,
                $assignmentsByUser,
                $depoSellInTargetsByDepo,
                $areaSellOutTargetsByDepo,
                $areaAoTargetsByDepo,
                $areaSellOutTargetsByArea,
                $areaAoTargetsByArea,
                $sellinByDepo,
                $sellinByDist,
                $hasDepoSellin,
                $selloutByDepo,
                $selloutByArea,
                $areaToDepoMap,
                $userCalcs
            ) {
                $posCode = strtoupper((string) ($s->position?->code ?? ''));
                $uTargets = $targetsByUser[$s->id] ?? [];
                $uAssigns = $assignmentsByUser->get($s->id) ?? collect();

                $depoIds = [];
                $distIds = [];
                $areaIds = [];

                foreach ($uTargets as $t) {
                    if ($t->depo_id) $depoIds[$t->depo_id] = true;
                    if ($t->distributor_id) $distIds[$t->distributor_id] = true;
                    if ($t->area_id) $areaIds[$t->area_id] = true;
                }
                foreach ($uAssigns as $a) {
                    if ($a->depo_id) $depoIds[$a->depo_id] = true;
                    if ($a->distributor_id) $distIds[$a->distributor_id] = true;
                    if ($a->area_id) {
                        $areaIds[$a->area_id] = true;
                        $parentDepo = $areaToDepoMap->get($a->area_id);
                        if ($parentDepo) $depoIds[$parentDepo] = true;
                    }
                }

                $targetSellIn = 0.0;
                $realSellIn = 0.0;
                $targetSellOut = 0.0;
                $realSellOut = 0.0;
                $targetAo = 0;
                $realAo = 0;

                if ($posCode === 'ASM') {
                    // ASM: Sell-In, Sell-Out, dan AO dihitung dari seluruh Depo yang di-handle
                    $managedDepoIds = array_keys($depoIds);
                    foreach ($managedDepoIds as $dId) {
                        $targetSellIn += $depoSellInTargetsByDepo[$dId] ?? 0.0;
                        $targetSellOut += $areaSellOutTargetsByDepo[$dId] ?? 0.0;
                        $targetAo += $areaAoTargetsByDepo[$dId] ?? 0;

                        if ($hasDepoSellin) {
                            $realSellIn += (float) ($sellinByDepo->get($dId) ?? 0.0);
                        }
                        $soRow = $selloutByDepo->get($dId);
                        if ($soRow) {
                            $realSellOut += (float) $soRow->vol;
                            $realAo += (int) $soRow->ao;
                        }
                    }
                    if (! $hasDepoSellin) {
                        foreach (array_keys($distIds) as $distId) {
                            $realSellIn += (float) ($sellinByDist->get($distId) ?? 0.0);
                        }
                    }
                } else {
                    // SPV / ASC: Sell-Out & AO dari Area yang dipegang, Sell-In dari Depo induk Area
                    foreach (array_keys($areaIds) as $aId) {
                        $targetSellOut += $areaSellOutTargetsByArea[$aId] ?? 0.0;
                        $targetAo += $areaAoTargetsByArea[$aId] ?? 0;
                        $soRow = $selloutByArea->get($aId);
                        if ($soRow) {
                            $realSellOut += (float) $soRow->vol;
                            $realAo += (int) $soRow->ao;
                        }
                    }
                    foreach (array_keys($depoIds) as $dId) {
                        $targetSellIn += $depoSellInTargetsByDepo[$dId] ?? 0.0;
                        if ($hasDepoSellin) {
                            $realSellIn += (float) ($sellinByDepo->get($dId) ?? 0.0);
                        }
                    }
                    if (! $hasDepoSellin) {
                        foreach (array_keys($distIds) as $distId) {
                            $realSellIn += (float) ($sellinByDist->get($distId) ?? 0.0);
                        }
                    }
                }

                $achSellInPct = $targetSellIn > 0 ? round(($realSellIn / $targetSellIn) * 100, 1) : 0.0;
                $achSellOutPct = $targetSellOut > 0 ? round(($realSellOut / $targetSellOut) * 100, 1) : 0.0;
                $achAoPct = $targetAo > 0 ? round(($realAo / $targetAo) * 100, 1) : 0.0;

                $calcs = $userCalcs->get($s->id);
                $totalReward = $calcs ? (float) $calcs->sum('final_reward') : 0.0;

                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'username' => $s->username,
                    'position' => $s->position?->code ?? '-',
                    'target_sell_in' => $targetSellIn,
                    'real_sell_in' => $realSellIn,
                    'ach_sell_in_pct' => $achSellInPct,
                    'target_sell_out' => $targetSellOut,
                    'real_sell_out' => $realSellOut,
                    'ach_sell_out_pct' => $achSellOutPct,
                    'target_ao' => $targetAo,
                    'real_ao' => $realAo,
                    'ach_ao_pct' => $achAoPct,
                    'target_kg' => $targetSellIn + $targetSellOut,
                    'target_outlet' => $targetAo,
                    'depo_count' => count($depoIds),
                    'area_count' => count($areaIds),
                    'achievement_pct' => $posCode === 'ASM' ? $achSellInPct : $achSellOutPct,
                    'estimated_reward' => $totalReward,
                ];
            })
            ->filter(fn ($s) => $s['target_sell_in'] > 0 || $s['target_sell_out'] > 0 || $s['target_ao'] > 0)
            ->sortByDesc(fn ($s) => $s['target_sell_in'] + $s['target_sell_out'])
            ->values()
            ->take(15);

        // Agregasi target distributor periode terpilih (1 query efisien dengan GROUP BY)
        $distTargetsAgg = $scopeDist(MasterTarget::whereIn('period', $periodList))
            ->whereNotNull('distributor_id')
            ->selectRaw("distributor_id, 
                SUM(CASE WHEN metrik_target = 'SELL_IN' THEN target_quota ELSE 0 END) as sell_in,
                SUM(CASE WHEN metrik_target = 'SELL_OUT' THEN target_quota ELSE 0 END) as sell_out,
                SUM(CASE WHEN level = 'AREA' THEN COALESCE(target_outlet, 0) ELSE 0 END) as target_ao")
            ->groupBy('distributor_id')
            ->get()
            ->keyBy('distributor_id');

        // Top Distributor & Underperforming Distributor Breakdown (dengan Realisasi & % Pencapaian)
        $allDistModels = Distributor::with(['region:id,code,name'])
            ->withCount('depos')
            ->when($scopedDistIds !== null, fn ($q) => $q->whereIn('id', $scopedDistIds))
            ->get();

        $allDistMetrics = $allDistModels
            ->map(function ($d) use ($distTargetsAgg, $sellinByDist, $selloutByDist) {
                $agg = $distTargetsAgg->get($d->id);
                $targetSi = $agg ? (float) $agg->sell_in : 0.0;
                $targetSo = $agg ? (float) $agg->sell_out : 0.0;
                $targetAo = $agg ? (int) $agg->target_ao : 0;

                $realSi = (float) ($sellinByDist->get($d->id) ?? 0.0);
                $soRow = $selloutByDist->get($d->id);
                $realSo = $soRow ? (float) $soRow->vol : 0.0;
                $realAo = $soRow ? (int) $soRow->ao : 0;

                $achSiPct = $targetSi > 0 ? round(($realSi / $targetSi) * 100, 1) : 0.0;
                $achSoPct = $targetSo > 0 ? round(($realSo / $targetSo) * 100, 1) : 0.0;
                $sellThrough = $realSi > 0 ? round(($realSo / $realSi) * 100, 1) : 0.0;

                return [
                    'id' => $d->id,
                    'code' => $d->code,
                    'name' => $d->name,
                    'region_id' => $d->region_id,
                    'region_code' => $d->region?->code ?? '-',
                    'region_name' => $d->region?->name ?? 'Lainnya',
                    'depos_count' => $d->depos_count,
                    'target_sell_in_kg' => $targetSi,
                    'real_sell_in_kg' => $realSi,
                    'ach_sell_in_pct' => $achSiPct,
                    'target_sell_out_kg' => $targetSo,
                    'real_sell_out_kg' => $realSo,
                    'ach_sell_out_pct' => $achSoPct,
                    'target_ao' => $targetAo,
                    'real_ao' => $realAo,
                    'sell_through_pct' => $sellThrough,
                ];
            })
            ->filter(fn ($d) => $d['target_sell_in_kg'] > 0 || $d['target_sell_out_kg'] > 0 || $d['real_sell_in_kg'] > 0);

        $distributorBreakdown = $allDistMetrics
            ->sortBy([
                fn ($a, $b) => ($b['target_sell_in_kg'] > 0 ? 1 : 0) <=> ($a['target_sell_in_kg'] > 0 ? 1 : 0),
                fn ($a, $b) => $b['ach_sell_in_pct'] <=> $a['ach_sell_in_pct'],
                fn ($a, $b) => $b['real_sell_in_kg'] <=> $a['real_sell_in_kg'],
                fn ($a, $b) => $b['target_sell_in_kg'] <=> $a['target_sell_in_kg'],
            ])
            ->values()
            ->take(10);

        $underperformingDistributors = $allDistMetrics
            ->filter(fn ($d) => $d['target_sell_in_kg'] > 0 && $d['ach_sell_in_pct'] < 80)
            ->sortBy([
                ['ach_sell_in_pct', 'asc'],
                ['target_sell_in_kg', 'desc'],
            ])
            ->values()
            ->take(10);

        // Performa per Region (untuk Manager Sales & Direksi)
        $regionPerformance = $allDistMetrics
            ->groupBy('region_name')
            ->map(function ($group, $regName) {
                $tSi = (float) $group->sum('target_sell_in_kg');
                $rSi = (float) $group->sum('real_sell_in_kg');
                $tSo = (float) $group->sum('target_sell_out_kg');
                $rSo = (float) $group->sum('real_sell_out_kg');
                $tAo = (int) $group->sum('target_ao');
                $rAo = (int) $group->sum('real_ao');

                return [
                    'region_code' => $group->first()['region_code'] ?? '-',
                    'region_name' => $regName,
                    'distributor_count' => $group->count(),
                    'target_sell_in' => $tSi,
                    'real_sell_in' => $rSi,
                    'ach_sell_in_pct' => $tSi > 0 ? round(($rSi / $tSi) * 100, 1) : 0.0,
                    'target_sell_out' => $tSo,
                    'real_sell_out' => $rSo,
                    'ach_sell_out_pct' => $tSo > 0 ? round(($rSo / $tSo) * 100, 1) : 0.0,
                    'target_ao' => $tAo,
                    'real_ao' => $rAo,
                    'ach_ao_pct' => $tAo > 0 ? round(($rAo / $tAo) * 100, 1) : 0.0,
                    'sell_through_pct' => $rSi > 0 ? round(($rSo / $rSi) * 100, 1) : 0.0,
                ];
            })
            ->sortByDesc('target_sell_in')
            ->values();

        // Performa & Kontribusi per Brand
        $brandTargetsAgg = $scopeDist(MasterTarget::whereIn('period', $periodList))
            ->whereNotNull('brand_id')
            ->selectRaw("brand_id,
                SUM(CASE WHEN metrik_target = 'SELL_IN' THEN target_quota ELSE 0 END) as target_si,
                SUM(CASE WHEN metrik_target = 'SELL_OUT' THEN target_quota ELSE 0 END) as target_so")
            ->groupBy('brand_id')
            ->get()
            ->keyBy('brand_id');

        $brandSellinAgg = $scopeDist(SellinDistributor::whereIn('period', $periodList))
            ->whereNotNull('brand_id')
            ->selectRaw('brand_id, COALESCE(SUM(volume_kg), 0) as vol')
            ->groupBy('brand_id')
            ->pluck('vol', 'brand_id');

        $brandSelloutAgg = $scopeDist(SelloutDistributor::whereIn('period', $periodList))
            ->where('is_out_of_area', false)
            ->whereNotNull('brand_id')
            ->selectRaw('brand_id, COALESCE(SUM(volume_kg), 0) as vol')
            ->groupBy('brand_id')
            ->pluck('vol', 'brand_id');

        $allBrandsList = Brand::orderBy('id')->get(['id', 'code', 'name', 'is_all_brands', 'component_brand_ids']);
        $effectiveBrandIdsMap = Brand::buildEffectiveBrandIdsMap($allBrandsList);

        $brandPerformance = $allBrandsList
            ->map(function ($b) use ($brandTargetsAgg, $brandSellinAgg, $brandSelloutAgg, $effectiveBrandIdsMap, $realisasiSellInKg, $targetSellInKg, $realisasiSellOutKg, $targetSellOutKg) {
                $tRow = $brandTargetsAgg->get($b->id);
                $tSi = $tRow ? (float) $tRow->target_si : 0.0;
                $tSo = $tRow ? (float) $tRow->target_so : 0.0;
                $effIds = $effectiveBrandIdsMap[$b->id] ?? [(int) $b->id];
                $isComposite = $effIds === null || count($effIds) > 1;

                if ($isComposite && ($tSi > 0 || $tSo > 0)) {
                    if ($effIds === null) {
                        $rSi = (float) $brandSellinAgg->sum();
                        $rSo = (float) $brandSelloutAgg->sum();
                    } else {
                        $rSi = 0.0;
                        $rSo = 0.0;
                        foreach ($effIds as $compId) {
                            $rSi += (float) ($brandSellinAgg->get($compId) ?? 0.0);
                            $rSo += (float) ($brandSelloutAgg->get($compId) ?? 0.0);
                        }
                    }
                } else {
                    $rSi = (float) ($brandSellinAgg->get($b->id) ?? 0.0);
                    $rSo = (float) ($brandSelloutAgg->get($b->id) ?? 0.0);
                }

                $shareSiDenom = $realisasiSellInKg > 0 ? $realisasiSellInKg : $targetSellInKg;
                $shareSiNum = $realisasiSellInKg > 0 ? $rSi : $tSi;
                $shareSoDenom = $realisasiSellOutKg > 0 ? $realisasiSellOutKg : $targetSellOutKg;
                $shareSoNum = $realisasiSellOutKg > 0 ? $rSo : $tSo;

                return [
                    'brand_code' => $b->code,
                    'brand_name' => $b->name,
                    'target_sell_in' => $tSi,
                    'real_sell_in' => $rSi,
                    'ach_sell_in_pct' => $tSi > 0 ? round(($rSi / $tSi) * 100, 1) : 0.0,
                    'target_sell_out' => $tSo,
                    'real_sell_out' => $rSo,
                    'ach_sell_out_pct' => $tSo > 0 ? round(($rSo / $tSo) * 100, 1) : 0.0,
                    'share_sell_in_pct' => $shareSiDenom > 0 ? round(($shareSiNum / $shareSiDenom) * 100, 1) : 0.0,
                    'share_sell_out_pct' => $shareSoDenom > 0 ? round(($shareSoNum / $shareSoDenom) * 100, 1) : 0.0,
                ];
            })
            ->filter(fn ($b) => $b['target_sell_in'] > 0 || $b['target_sell_out'] > 0 || $b['real_sell_in'] > 0 || $b['real_sell_out'] > 0)
            ->sortByDesc(fn ($b) => $b['real_sell_in'] + $b['target_sell_in'])
            ->values();

        // Tren Bulanan 6 Periode Terakhir (Target vs Realisasi Sell-In & Sell-Out)
        $trendPeriods = $availablePeriods->take(6);
        $trendAgg = $scopeDist(MasterTarget::whereIn('period', $trendPeriods))
            ->selectRaw("period,
                SUM(CASE WHEN metrik_target = 'SELL_IN' THEN target_quota ELSE 0 END) as sell_in,
                SUM(CASE WHEN metrik_target = 'SELL_OUT' THEN target_quota ELSE 0 END) as sell_out")
            ->groupBy('period')
            ->get()
            ->keyBy('period');

        $trendRealSi = $scopeDist(SellinDistributor::whereIn('period', $trendPeriods))
            ->selectRaw('period, COALESCE(SUM(volume_kg), 0) as vol')
            ->groupBy('period')
            ->pluck('vol', 'period');

        $trendRealSo = $scopeDist(SelloutDistributor::whereIn('period', $trendPeriods))
            ->where('is_out_of_area', false)
            ->selectRaw('period, COALESCE(SUM(volume_kg), 0) as vol')
            ->groupBy('period')
            ->pluck('vol', 'period');

        $monthlyTrend = $trendPeriods->reverse()->map(function ($p) use ($trendAgg, $trendRealSi, $trendRealSo) {
            $agg = $trendAgg->get($p);
            $tSi = $agg ? (float) $agg->sell_in : 0.0;
            $tSo = $agg ? (float) $agg->sell_out : 0.0;
            $rSi = (float) ($trendRealSi->get($p) ?? 0.0);
            $rSo = (float) ($trendRealSo->get($p) ?? 0.0);
            return [
                'period' => $p,
                'target_sell_in' => $tSi,
                'real_sell_in' => $rSi,
                'ach_sell_in_pct' => $tSi > 0 ? round(($rSi / $tSi) * 100, 1) : 0.0,
                'target_sell_out' => $tSo,
                'real_sell_out' => $rSo,
                'ach_sell_out_pct' => $tSo > 0 ? round(($rSo / $tSo) * 100, 1) : 0.0,
            ];
        })->values();

        return [
            'mode' => 'ADMIN',
            'period' => $period,
            'available_periods' => $availablePeriods,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'role' => $user->role?->display_name ?? $user->role?->name ?? 'Administrator',
                'position' => $user->position?->code ?? '',
                'can_manage' => $canManage,
                'scope_label' => $scopeLabel,
            ],
            'kpi' => [
                'total_distributors' => $totalDistributors,
                'total_depos' => $totalDepos,
                'total_areas' => $totalAreas,
                'total_sales' => $totalSalesPersonil,
                'target_sell_in_kg' => $targetSellInKg,
                'target_sell_out_kg' => $targetSellOutKg,
                'target_outlet_count' => $targetOutletCount,
                'realisasi_sell_in_kg' => $realisasiSellInKg,
                'realisasi_sell_out_kg' => $realisasiSellOutKg,
                'realisasi_outlet_count' => $realisasiOutletCount,
                'ach_sell_in_pct' => $achSellInPct,
                'ach_sell_out_pct' => $achSellOutPct,
                'ach_outlet_pct' => $achOutletPct,
                'sell_through_pct' => $sellThroughPct,
                'total_dpp_sell_in' => $totalDppSellIn,
                'total_dpp_sell_out' => $totalDppSellOut,
                'incentive_ratio_pct' => $incentiveRatioPct,
                'total_incentive_pool' => $totalIncentivePool,
            ],
            'leaderboard' => $salesLeaderboard,
            'distributors' => $distributorBreakdown,
            'underperforming_distributors' => $underperformingDistributors,
            'region_performance' => $regionPerformance,
            'brand_performance' => $brandPerformance,
            'monthly_trend' => $monthlyTrend,
        ];
    }

    private function getSalesDashboard(User $user, string $period, array $periodList, $availablePeriods): array
    {
        $primaryPeriod = $periodList[0] ?? $period;
        $posCode = strtoupper($user->position?->code ?? 'SALES');
        $salesScheme = 'KONSUMSI';
        if ($user->is_eligible_industri) {
            $salesScheme = 'INDUSTRI';
        } elseif ($user->is_eligible_surabaya) {
            $salesScheme = 'SURABAYA';
        }

        $industriCard = null;
        $surabayaCard = null;

        // Ambil penugasan wilayah dari SalesDistributorAssignment jika ada
        $assignments = SalesDistributorAssignment::where('is_active', true)
            ->where(function ($q) use ($user) {
                $q->where('user_id', $user->id)
                    ->orWhere('asm_id', $user->id)
                    ->orWhere('lsm_id', $user->id)
                    ->orWhere('nsm_id', $user->id);
            })
            ->get();

        $assignedDepoIdsFromMap = $assignments->whereNotNull('depo_id')->pluck('depo_id')->unique();
        $assignedAreaIdsFromMap = $assignments->whereNotNull('area_id')->pluck('area_id')->unique();

        $myTargetsQuery = MasterTarget::whereIn('period', $periodList)
            ->with(['distributor', 'depo', 'area', 'brand']);

        if ($salesScheme === 'KONSUMSI') {
            $myTargetsQuery->whereIn('level', ['DEPO', 'AREA'])
                ->where(function ($q) use ($user, $posCode, $assignedDepoIdsFromMap, $assignedAreaIdsFromMap) {
                    $q->where('user_id', $user->id);
                    if ($posCode === 'ASM' && $assignedDepoIdsFromMap->isNotEmpty()) {
                        $q->orWhere(function ($sq) use ($assignedDepoIdsFromMap) {
                            $sq->where('level', 'DEPO')->whereIn('depo_id', $assignedDepoIdsFromMap);
                        });
                    } elseif ($posCode === 'SPV' && $assignedAreaIdsFromMap->isNotEmpty()) {
                        $q->orWhere(function ($sq) use ($assignedAreaIdsFromMap) {
                            $sq->where('level', 'AREA')->whereIn('area_id', $assignedAreaIdsFromMap);
                        });
                    }
                });
        } else {
            $myTargetsQuery->where('user_id', $user->id);
        }

        $myTargets = $myTargetsQuery->get();

        $myTargetSellInKg = (float) $myTargets->where('metrik_target', 'SELL_IN')->sum('target_quota');
        $myTargetSellOutKg = (float) $myTargets->where('metrik_target', 'SELL_OUT')->sum('target_quota');
        $myTargetOutlet = (int) $myTargets->where('level', 'AREA')->sum('target_outlet');

        // Depo atau Area ID yang ditugaskan ke sales ini
        $assignedDepoIds = $myTargets->whereNotNull('depo_id')->pluck('depo_id')->merge($assignedDepoIdsFromMap)->unique();
        $assignedAreaIds = $myTargets->whereNotNull('area_id')->pluck('area_id')->merge($assignedAreaIdsFromMap)->unique();

        $realisasiSellInKg = 0.0;
        $realisasiSellOutKg = 0.0;
        $realisasiOutlet = 0;

        $assignedDistributorIds = $myTargets->whereNotNull('distributor_id')->pluck('distributor_id')
            ->merge($assignments->whereNotNull('distributor_id')->pluck('distributor_id'))
            ->unique();

        if ($assignedDepoIds->isNotEmpty() && SellinDistributor::whereIn('period', $periodList)->whereIn('depo_id', $assignedDepoIds)->exists()) {
            $siQuery = SellinDistributor::whereIn('period', $periodList)->whereIn('depo_id', $assignedDepoIds);
            $from = $user->aktif_from ? $user->aktif_from->format('Y-m-d') : null;
            $to = $user->aktif_to ? $user->aktif_to->format('Y-m-d') : null;
            if ($from || $to) {
                $siQuery->where(function ($q) use ($from, $to, $user) {
                    $q->whereNull('transaction_date')
                        ->orWhere(function ($dq) use ($from, $to) {
                            if ($from) {
                                $dq->where('transaction_date', '>=', $from);
                            }
                            if ($to) {
                                $dq->where('transaction_date', '<=', $to);
                            }
                        })
                        ->orWhere('user_id', $user->id);
                });
            }
            $realisasiSellInKg = (float) $siQuery->sum('volume_kg');
        } elseif ($assignedDistributorIds->isNotEmpty()) {
            $realisasiSellInKg = (float) SellinDistributor::whereIn('period', $periodList)
                ->whereIn('distributor_id', $assignedDistributorIds)
                ->sum('volume_kg');
        }

        if ($assignedAreaIds->isNotEmpty() && SelloutDistributor::whereIn('period', $periodList)->where('is_out_of_area', false)->whereIn('area_id', $assignedAreaIds)->exists()) {
            $realisasiSellOutKg = (float) SelloutDistributor::whereIn('period', $periodList)
                ->where('is_out_of_area', false)
                ->whereIn('area_id', $assignedAreaIds)
                ->sum('volume_kg');
            $realisasiOutlet = (int) SelloutDistributor::whereIn('period', $periodList)
                ->where('is_out_of_area', false)
                ->whereIn('area_id', $assignedAreaIds)
                ->sum('active_outlet_count');
        } elseif ($assignedDepoIds->isNotEmpty()) {
            $realisasiSellOutKg = (float) SelloutDistributor::whereIn('period', $periodList)
                ->where('is_out_of_area', false)
                ->whereIn('depo_id', $assignedDepoIds)
                ->sum('volume_kg');
            $realisasiOutlet = (int) SelloutDistributor::whereIn('period', $periodList)
                ->where('is_out_of_area', false)
                ->whereIn('depo_id', $assignedDepoIds)
                ->sum('active_outlet_count');
        }

        // Ambil kalkulasi insentif pribadi jika sudah dihitung di tabel incentive_calculations
        $myIncentives = IncentiveCalculation::whereIn('period', $periodList)
            ->where('user_id', $user->id)
            ->with(['grade'])
            ->get();

        $totalReward = (float) $myIncentives->sum('final_reward');
        $mainGrade = $myIncentives->first()?->grade?->grade_name ?? '-';
        $achSellInPct = $myTargetSellInKg > 0 ? round(($realisasiSellInKg / $myTargetSellInKg) * 100, 1) : 0.0;
        $achSellOutPct = $myTargetSellOutKg > 0 ? round(($realisasiSellOutKg / $myTargetSellOutKg) * 100, 1) : 0.0;
        $achOutletPct = $myTargetOutlet > 0 ? round(($realisasiOutlet / $myTargetOutlet) * 100, 1) : 0.0;
        $mainAch = $myIncentives->first()
            ? (float) $myIncentives->first()->achievement_percent
            : ($posCode === 'ASM' ? $achSellInPct : $achSellOutPct);

        // Evaluasi spesifik untuk Sales Industri
        if ($salesScheme === 'INDUSTRI') {
            $indEval = app(IncentiveCalculationService::class)->evaluateIndustriForPeriod($primaryPeriod, null, $user->id, null, true);
            $industriCard = $indEval['cards'][0] ?? null;
            if ($industriCard) {
                $sellIn = $industriCard['sell_in'] ?? [];
                $noo = $industriCard['noo'] ?? [];
                $myTargetSellInKg = (float) ($sellIn['target_quota'] ?? 0);
                $realisasiSellInKg = (float) ($sellIn['actual_realization'] ?? 0);
                $achSellInPct = (float) ($sellIn['achievement_percent'] ?? 0);
                $myTargetOutlet = (int) ($noo['target_quota'] ?? 0);
                $realisasiOutlet = (int) ($noo['actual_realization'] ?? 0);
                $achOutletPct = (float) ($noo['achievement_percent'] ?? 0);
                $totalReward = (float) ($industriCard['total_reward'] ?? $totalReward);
                $sellInGrade = $sellIn['grade_name'] ?? '-';
                $nooGrade = $noo['grade_name'] ?? '-';
                $mainGrade = $sellInGrade !== '-' ? $sellInGrade : $nooGrade;
                $mainAch = $achSellInPct;
            }
        }

        // Evaluasi spesifik untuk Sales Surabaya
        if ($salesScheme === 'SURABAYA') {
            $sbyEval = app(IncentiveCalculationService::class)->evaluateSurabayaForPeriod($primaryPeriod, null, $user->id, null, true);
            $surabayaCard = $sbyEval['cards'][0] ?? null;
            if ($surabayaCard) {
                $myTargetSellOutKg = (float) ($surabayaCard['target_kg'] ?? 0);
                $realisasiSellOutKg = (float) ($surabayaCard['actual_kg'] ?? 0);
                $achSellOutPct = (float) ($surabayaCard['achievement_percent'] ?? 0);
                $totalReward = (float) ($surabayaCard['total_reward'] ?? $totalReward);
                $mainGrade = $surabayaCard['grade_name'] ?? ($posCode === 'ASC' ? 'Koordinator ASC' : '-');
                $mainAch = $achSellOutPct;
            }
        }

        // Breakdown wilayah penugasan (Depo atau Area) khusus Konsumsi
        $breakdown = collect();
        if ($salesScheme === 'KONSUMSI') {
            $breakdown = $myTargets
                ->filter(fn ($t) => $t->depo_id !== null || $t->area_id !== null)
                ->groupBy(function ($t) {
                    return $t->level === 'DEPO' ? "DEPO_{$t->depo_id}" : "AREA_{$t->area_id}";
                })->map(function ($group) use ($period) {
                    $first = $group->first();
                    $isDepo = $first->level === 'DEPO';

                    $locRealKg = 0.0;
                    $locRealOutlet = 0;
                    if ($isDepo && $first->distributor_id) {
                        $locRealKg = (float) SellinDistributor::where('period', $period)
                            ->where('distributor_id', $first->distributor_id)
                            ->sum('volume_kg');
                    } elseif (!$isDepo && $first->area_id && SelloutDistributor::where('period', $period)->where('area_id', $first->area_id)->exists()) {
                        $locRealKg = (float) SelloutDistributor::where('period', $period)
                            ->where('area_id', $first->area_id)
                            ->sum('volume_kg');
                        $locRealOutlet = (int) SelloutDistributor::where('period', $period)
                            ->where('area_id', $first->area_id)
                            ->sum('active_outlet_count');
                    } elseif (!$isDepo && $first->depo_id) {
                        $locRealKg = (float) SelloutDistributor::where('period', $period)
                            ->where('depo_id', $first->depo_id)
                            ->sum('volume_kg');
                        $locRealOutlet = (int) SelloutDistributor::where('period', $period)
                            ->where('depo_id', $first->depo_id)
                            ->sum('active_outlet_count');
                    }

                    $locTargetKg = (float) $group->sum('target_quota');
                    $locAchPct = $locTargetKg > 0 ? round(($locRealKg / $locTargetKg) * 100, 1) : 0.0;

                    return [
                        'type' => $first->level,
                        'distributor_name' => $first->distributor?->name ?? '-',
                        'depo_name' => $first->depo?->name ?? '-',
                        'location_name' => $isDepo ? ($first->depo?->name ?? '-') : ($first->area?->name ?? '-'),
                        'location_code' => $isDepo ? ($first->depo?->code ?? '-') : ($first->area?->code ?? '-'),
                        'target_quota_kg' => $locTargetKg,
                        'realisasi_kg' => $locRealKg,
                        'ach_pct' => $locAchPct,
                        'target_outlet' => (int) $group->sum('target_outlet'),
                        'realisasi_outlet' => $locRealOutlet,
                        'brands' => $group->map(fn ($g) => [
                            'brand_name' => $g->brand?->name ?? '-',
                            'metric' => $g->metrik_target,
                            'target_quota' => (float) $g->target_quota,
                            'target_outlet' => (int) $g->target_outlet,
                        ])->values(),
                    ];
                })->values();
        }

        return [
            'mode' => 'SALES',
            'sales_scheme' => $salesScheme,
            'period' => $period,
            'available_periods' => $availablePeriods,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role?->displayName ?? 'Sales',
                'position' => $posCode,
                'position_name' => $user->position?->name ?? $posCode,
                'is_eligible_konsumsi' => (bool) $user->is_eligible_konsumsi,
                'is_eligible_industri' => (bool) $user->is_eligible_industri,
                'is_eligible_surabaya' => (bool) $user->is_eligible_surabaya,
            ],
            'kpi' => [
                'position' => $posCode,
                'sales_scheme' => $salesScheme,
                'my_target_sell_in_kg' => $myTargetSellInKg,
                'my_target_sell_out_kg' => $myTargetSellOutKg,
                'my_target_outlet' => $myTargetOutlet,
                'realisasi_sell_in_kg' => $realisasiSellInKg,
                'realisasi_sell_out_kg' => $realisasiSellOutKg,
                'realisasi_outlet' => $realisasiOutlet,
                'ach_sell_in_pct' => $achSellInPct,
                'ach_sell_out_pct' => $achSellOutPct,
                'ach_outlet_pct' => $achOutletPct,
                'overall_ach_pct' => $mainAch,
                'grade' => $mainGrade,
                'estimated_reward' => $totalReward,
                'total_assigned_depos' => $assignedDepoIds->count(),
                'total_assigned_areas' => $assignedAreaIds->count(),
            ],
            'industri_card' => $industriCard,
            'surabaya_card' => $surabayaCard,
            'breakdown' => $breakdown,
            'incentive_details' => $myIncentives->map(fn ($i) => [
                'kategori_skema' => $i->kategori_skema,
                'target_quota' => (float) $i->target_quota,
                'realization' => (float) $i->realization,
                'achievement_percent' => (float) $i->achievement_percent,
                'final_reward' => (float) $i->final_reward,
                'grade' => $i->grade?->grade_name ?? '-',
            ]),
        ];
    }
}

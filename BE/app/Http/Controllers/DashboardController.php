<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user()->load(['role', 'position']);
        $roleName = strtolower($user->role?->name ?? '');
        $isAdmin = in_array($roleName, ['admin', 'superadmin', 'administrator', 'admin sales']);

        // Ambil periode dari query, atau default ke periode terbaru di master_targets
        $latestPeriod = MasterTarget::max('period') ?? date('Ym');
        $period = $request->query('period', $latestPeriod);

        $availablePeriods = MasterTarget::distinct()
            ->orderByDesc('period')
            ->pluck('period')
            ->take(12)
            ->values();

        if ($availablePeriods->isEmpty()) {
            $availablePeriods = collect([$period]);
        }

        if ($isAdmin) {
            return response()->json($this->getAdminDashboard($user, $period, $availablePeriods));
        }

        return response()->json($this->getSalesDashboard($user, $period, $availablePeriods));
    }

    private function getAdminDashboard(User $user, string $period, $availablePeriods): array
    {
        $targetSellInKg = (float) MasterTarget::where('period', $period)
            ->where('metrik_target', 'SELL_IN')
            ->sum('target_quota');

        $targetSellOutKg = (float) MasterTarget::where('period', $period)
            ->where('metrik_target', 'SELL_OUT')
            ->sum('target_quota');

        $targetOutletCount = (int) MasterTarget::where('period', $period)
            ->where('level', 'AREA')
            ->sum('target_outlet');

        $realisasiSellInKg = (float) SellinDistributor::where('period', $period)->sum('volume_kg');
        $realisasiSellOutKg = (float) SelloutDistributor::where('period', $period)->sum('volume_kg');
        $realisasiOutletCount = (int) SelloutDistributor::where('period', $period)->sum('active_outlet_count');

        $achSellInPct = $targetSellInKg > 0 ? round(($realisasiSellInKg / $targetSellInKg) * 100, 1) : 0.0;
        $achSellOutPct = $targetSellOutKg > 0 ? round(($realisasiSellOutKg / $targetSellOutKg) * 100, 1) : 0.0;
        $achOutletPct = $targetOutletCount > 0 ? round(($realisasiOutletCount / $targetOutletCount) * 100, 1) : 0.0;

        $totalIncentivePool = (float) IncentiveCalculation::where('period', $period)->sum('final_reward');
        $totalDistributors = (int) Distributor::count();
        $totalDepos = (int) Depo::count();
        $totalAreas = (int) Area::count();
        $totalSalesPersonil = (int) User::whereHas('role', fn ($q) => $q->where('name', 'Sales'))->count();

        // Agregasi target sales periode ini (1 query efisien dengan GROUP BY)
        $userTargetsAgg = MasterTarget::where('period', $period)
            ->whereNotNull('user_id')
            ->selectRaw('user_id, SUM(target_quota) as total_kg, SUM(target_outlet) as total_outlet, COUNT(DISTINCT depo_id) as depo_count, COUNT(DISTINCT area_id) as area_count')
            ->groupBy('user_id')
            ->get()
            ->keyBy('user_id');

        // Agregasi kalkulasi insentif periode ini (1 query)
        $userCalcs = IncentiveCalculation::where('period', $period)
            ->get()
            ->groupBy('user_id');

        // Top Sales Leaderboard
        $salesLeaderboard = User::whereHas('role', fn ($q) => $q->where('name', 'Sales'))
            ->with(['position'])
            ->get()
            ->map(function ($s) use ($userTargetsAgg, $userCalcs) {
                $targetAgg = $userTargetsAgg->get($s->id);
                $targetKg = $targetAgg ? (float) $targetAgg->total_kg : 0.0;
                $targetOutlet = $targetAgg ? (int) $targetAgg->total_outlet : 0;
                $depoCount = $targetAgg ? (int) $targetAgg->depo_count : 0;
                $areaCount = $targetAgg ? (int) $targetAgg->area_count : 0;

                $calcs = $userCalcs->get($s->id);
                $firstCalc = $calcs?->first();
                $totalReward = $calcs ? (float) $calcs->sum('final_reward') : 0.0;
                $achPct = $firstCalc ? (float) $firstCalc->achievement_percent : 0.0;

                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'username' => $s->username,
                    'position' => $s->position?->code ?? '-',
                    'target_kg' => $targetKg,
                    'target_outlet' => $targetOutlet,
                    'depo_count' => $depoCount,
                    'area_count' => $areaCount,
                    'achievement_pct' => $achPct,
                    'estimated_reward' => $totalReward,
                ];
            })
            ->filter(fn ($s) => $s['target_kg'] > 0 || $s['target_outlet'] > 0)
            ->sortByDesc('target_kg')
            ->values()
            ->take(10);

        // Agregasi target distributor periode ini (1 query efisien dengan GROUP BY)
        $distTargetsAgg = MasterTarget::where('period', $period)
            ->whereNotNull('distributor_id')
            ->selectRaw("distributor_id, 
                SUM(CASE WHEN metrik_target = 'SELL_IN' THEN target_quota ELSE 0 END) as sell_in,
                SUM(CASE WHEN metrik_target = 'SELL_OUT' THEN target_quota ELSE 0 END) as sell_out")
            ->groupBy('distributor_id')
            ->get()
            ->keyBy('distributor_id');

        // Top Distributor Breakdown
        $distributorBreakdown = Distributor::withCount('depos')
            ->get()
            ->map(function ($d) use ($distTargetsAgg) {
                $agg = $distTargetsAgg->get($d->id);
                $sellIn = $agg ? (float) $agg->sell_in : 0.0;
                $sellOut = $agg ? (float) $agg->sell_out : 0.0;

                return [
                    'id' => $d->id,
                    'code' => $d->code,
                    'name' => $d->name,
                    'depos_count' => $d->depos_count,
                    'target_sell_in_kg' => $sellIn,
                    'target_sell_out_kg' => $sellOut,
                ];
            })
            ->filter(fn ($d) => $d['target_sell_in_kg'] > 0 || $d['target_sell_out_kg'] > 0)
            ->sortByDesc('target_sell_in_kg')
            ->values()
            ->take(8);

        // Tren Bulanan (1 query efisien dengan GROUP BY period)
        $trendPeriods = $availablePeriods->take(6);
        $trendAgg = MasterTarget::whereIn('period', $trendPeriods)
            ->selectRaw("period,
                SUM(CASE WHEN metrik_target = 'SELL_IN' THEN target_quota ELSE 0 END) as sell_in,
                SUM(CASE WHEN metrik_target = 'SELL_OUT' THEN target_quota ELSE 0 END) as sell_out")
            ->groupBy('period')
            ->get()
            ->keyBy('period');

        $monthlyTrend = $trendPeriods->reverse()->map(function ($p) use ($trendAgg) {
            $agg = $trendAgg->get($p);
            return [
                'period' => $p,
                'target_sell_in' => $agg ? (float) $agg->sell_in : 0.0,
                'target_sell_out' => $agg ? (float) $agg->sell_out : 0.0,
            ];
        })->values();

        return [
            'mode' => 'ADMIN',
            'period' => $period,
            'available_periods' => $availablePeriods,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'role' => $user->role?->displayName ?? $user->role?->name ?? 'Administrator',
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
                'total_incentive_pool' => $totalIncentivePool,
            ],
            'leaderboard' => $salesLeaderboard,
            'distributors' => $distributorBreakdown,
            'monthly_trend' => $monthlyTrend,
        ];
    }

    private function getSalesDashboard(User $user, string $period, $availablePeriods): array
    {
        $posCode = strtoupper($user->position?->code ?? 'SALES');

        $myTargets = MasterTarget::where('period', $period)
            ->where('user_id', $user->id)
            ->with(['distributor', 'depo', 'area', 'brand'])
            ->get();

        $myTargetSellInKg = (float) $myTargets->where('metrik_target', 'SELL_IN')->sum('target_quota');
        $myTargetSellOutKg = (float) $myTargets->where('metrik_target', 'SELL_OUT')->sum('target_quota');
        $myTargetOutlet = (int) $myTargets->where('level', 'AREA')->sum('target_outlet');

        // Depo atau Area ID yang ditugaskan ke sales ini
        $assignedDepoIds = $myTargets->whereNotNull('depo_id')->pluck('depo_id')->unique();
        $assignedAreaIds = $myTargets->whereNotNull('area_id')->pluck('area_id')->unique();

        $realisasiSellInKg = 0.0;
        $realisasiSellOutKg = 0.0;
        $realisasiOutlet = 0;

        $assignedDistributorIds = $myTargets->whereNotNull('distributor_id')->pluck('distributor_id')->unique();

        if ($assignedDistributorIds->isNotEmpty()) {
            $realisasiSellInKg = (float) SellinDistributor::where('period', $period)
                ->whereIn('distributor_id', $assignedDistributorIds)
                ->sum('volume_kg');
        }

        if ($assignedDepoIds->isNotEmpty()) {
            $realisasiSellOutKg = (float) SelloutDistributor::where('period', $period)
                ->whereIn('depo_id', $assignedDepoIds)
                ->sum('volume_kg');
            $realisasiOutlet = (int) SelloutDistributor::where('period', $period)
                ->whereIn('depo_id', $assignedDepoIds)
                ->sum('active_outlet_count');
        }

        $achSellInPct = $myTargetSellInKg > 0 ? round(($realisasiSellInKg / $myTargetSellInKg) * 100, 1) : 0.0;
        $achSellOutPct = $myTargetSellOutKg > 0 ? round(($realisasiSellOutKg / $myTargetSellOutKg) * 100, 1) : 0.0;
        $achOutletPct = $myTargetOutlet > 0 ? round(($realisasiOutlet / $myTargetOutlet) * 100, 1) : 0.0;

        // Ambil kalkulasi insentif pribadi jika sudah dihitung
        $myIncentives = IncentiveCalculation::where('period', $period)
            ->where('user_id', $user->id)
            ->with(['grade'])
            ->get();

        $totalReward = (float) $myIncentives->sum('final_reward');
        $mainGrade = $myIncentives->first()?->grade?->name ?? '-';
        $mainAch = $myIncentives->first() ? (float) $myIncentives->first()->achievement_percent : ($posCode === 'ASM' ? $achSellInPct : $achSellOutPct);

        // Breakdown wilayah penugasan (Depo atau Area)
        $breakdown = $myTargets->groupBy(function ($t) {
            return $t->depo_id ? "DEPO_{$t->depo_id}" : "AREA_{$t->area_id}";
        })->map(function ($group) {
            $first = $group->first();
            $isDepo = $first->level === 'DEPO';

            return [
                'type' => $first->level,
                'distributor_name' => $first->distributor?->name ?? '-',
                'location_name' => $isDepo ? ($first->depo?->name ?? '-') : ($first->area?->name ?? '-'),
                'location_code' => $isDepo ? ($first->depo?->code ?? '-') : ($first->area?->code ?? '-'),
                'target_quota_kg' => (float) $group->sum('target_quota'),
                'target_outlet' => (int) $group->sum('target_outlet'),
                'brands' => $group->map(fn ($g) => [
                    'brand_name' => $g->brand?->name ?? '-',
                    'metric' => $g->metrik_target,
                    'target_quota' => (float) $g->target_quota,
                    'target_outlet' => (int) $g->target_outlet,
                ])->values(),
            ];
        })->values();

        return [
            'mode' => 'SALES',
            'period' => $period,
            'available_periods' => $availablePeriods,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'role' => $user->role?->displayName ?? 'Sales',
                'position' => $posCode,
            ],
            'kpi' => [
                'position' => $posCode,
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
            'breakdown' => $breakdown,
            'incentive_details' => $myIncentives->map(fn ($i) => [
                'kategori_skema' => $i->kategori_skema,
                'target_quota' => (float) $i->target_quota,
                'realization' => (float) $i->realization,
                'achievement_percent' => (float) $i->achievement_percent,
                'final_reward' => (float) $i->final_reward,
                'grade' => $i->grade?->name ?? '-',
            ]),
        ];
    }
}

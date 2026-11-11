<?php

namespace App\Http\Controllers;

use App\Exports\IncentiveCalculationExport;
use App\Models\Area;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
            'period' => 'required|string|size:6',
            'position_id' => 'nullable|integer|exists:positions,id',
            'user_id' => 'nullable|integer|exists:users,id',
        ]);

        $authUserId = $request->user()->id;

        $results = $this->calculationService->execute(
            $validated['kategori_skema'],
            $validated['period'],
            $authUserId,
            isset($validated['position_id']) ? (int) $validated['position_id'] : null,
            isset($validated['user_id']) ? (int) $validated['user_id'] : null
        );

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
        $calculations = IncentiveCalculation::with(['user.position', 'targetHeader', 'grade', 'gradeBobot', 'calculatedBy'])
            ->when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->when($request->period, fn ($q) => $q->where('period', $request->period))
            ->when($request->position_id, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('position_id', $request->position_id)))
            ->when($request->user_id, fn ($q) => $q->where('user_id', $request->user_id))
            ->orderBy('user_id')
            ->orderBy('target_header_id')
            ->paginate($request->integer('per_page', 100));

        return response()->json($calculations);
    }

    public function exportExcel(Request $request): BinaryFileResponse
    {
        $request->validate([
            'kategori_skema' => 'nullable|in:KONSUMSI,INDUSTRI,SURABAYA',
            'period' => 'nullable|string|size:6',
            'position_id' => 'nullable|integer',
            'user_id' => 'nullable|integer',
        ]);

        $kategoriSkema = $request->query('kategori_skema');
        $period = $request->query('period');
        $positionId = $request->query('position_id') ? (int) $request->query('position_id') : null;
        $userId = $request->query('user_id') ? (int) $request->query('user_id') : null;

        $fileName = 'incentive_report_'.($kategoriSkema ?? 'ALL').'_'.($period ?? date('Ym')).'.xlsx';

        return Excel::download(
            new IncentiveCalculationExport($kategoriSkema, $period, $positionId, $userId),
            $fileName
        );
    }

    public function distributorBreakdown(Request $request): JsonResponse
    {
        $request->validate([
            'period' => 'required|string|size:6',
            'position_id' => 'nullable|integer',
            'user_id' => 'nullable|integer',
            'search' => 'nullable|string',
        ]);

        $cleanPeriod = preg_replace('/[^0-9]/', '', $request->period);
        $year = substr($cleanPeriod, 0, 4);
        $month = (int) substr($cleanPeriod, 4, 2);
        $periodFormatted = "{$month}/{$year}";

        $positionId = $request->filled('position_id') ? (int) $request->position_id : null;
        $userId = $request->filled('user_id') ? (int) $request->user_id : null;
        $search = $request->filled('search') ? trim(strtolower($request->search)) : null;

        // TargetHeaders for KONSUMSI
        $asmHeader = TargetHeader::where('kategori_skema', 'KONSUMSI')
            ->where('sales_type', 1)
            ->where('aktif', true)
            ->with('grades.bobots')
            ->first();

        $spvSoHeader = TargetHeader::where('kategori_skema', 'KONSUMSI')
            ->where('sales_type', 2)
            ->whereIn('type', ['Sell-Out', 'SELL_OUT'])
            ->where('aktif', true)
            ->with('grades.bobots')
            ->first();

        $spvAoHeader = TargetHeader::where('kategori_skema', 'KONSUMSI')
            ->where('sales_type', 2)
            ->whereIn('type', ['AO', 'ACTIVE_OUTLET', 'Active Outlet'])
            ->where('aktif', true)
            ->with('grades.bobots')
            ->first();

        $selectedUser = $userId ? User::with('position')->find($userId) : null;
        $userPosCode = strtoupper($selectedUser->position?->code ?? '');
        $isSpv = $selectedUser && $userPosCode === 'SPV';
        $isAsm = $selectedUser && $userPosCode === 'ASM';

        // Preload active assignments for ASM and SPV
        $asmAssignments = SalesDistributorAssignment::whereNotNull('distributor_id')
            ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
            ->where('is_active', true)
            ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
            ->with('user:id,name')
            ->get()
            ->keyBy('distributor_id');

        $spvAssignments = SalesDistributorAssignment::whereNotNull('area_id')
            ->whereHas('user.position', fn ($q) => $q->where('code', 'SPV'))
            ->where('is_active', true)
            ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
            ->with('user:id,name')
            ->get()
            ->keyBy('area_id');

        // 1. Get relevant DEPO target rows
        $depoQuery = MasterTarget::with(['distributor', 'depo', 'brand', 'user.position'])
            ->where('period', $cleanPeriod)
            ->where('kategori_skema', 'KONSUMSI')
            ->where('level', 'DEPO');

        $assignedAreaIds = collect();

        if ($isAsm) {
            $assignedDistIds = SalesDistributorAssignment::where('user_id', $userId)
                ->where('is_active', true)
                ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
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
                ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
                ->pluck('area_id')
                ->filter()
                ->unique();

            $assignedDepoIds = Area::whereIn('id', $assignedAreaIds)->pluck('depo_id')->filter()->unique();

            $spvDepoIds = MasterTarget::where('period', $cleanPeriod)
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
        } elseif ($positionId == 1) { // Filter Posisi ASM
            $asmUserIds = User::whereHas('position', fn ($q) => $q->where('code', 'ASM'))->pluck('id');
            $assignedDistIds = SalesDistributorAssignment::whereIn('user_id', $asmUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
                ->pluck('distributor_id')
                ->filter()
                ->unique();

            $depoQuery->where(function ($q) use ($asmUserIds, $assignedDistIds) {
                $q->whereIn('user_id', $asmUserIds);
                if ($assignedDistIds->isNotEmpty()) {
                    $q->orWhereIn('distributor_id', $assignedDistIds);
                }
            });
        } elseif ($positionId == 2) { // Filter Posisi SPV
            $spvUserIds = User::whereHas('position', fn ($q) => $q->where('code', 'SPV'))->pluck('id');
            $spvAreaIds = SalesDistributorAssignment::whereIn('user_id', $spvUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
                ->pluck('area_id')
                ->filter()
                ->unique();

            $spvDepoIds = MasterTarget::where('period', $cleanPeriod)
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

        // Realization records cache
        $allSellin = SellinDistributor::where('period', $cleanPeriod)->get();
        $allSellout = SelloutDistributor::where('period', $cleanPeriod)->get();

        // 2. Get relevant AREA target rows
        $areaQuery = MasterTarget::with(['area', 'brand', 'user.position'])
            ->where('period', $cleanPeriod)
            ->where('kategori_skema', 'KONSUMSI')
            ->where('level', 'AREA');

        if ($isSpv) {
            $areaQuery->where(function ($q) use ($userId, $assignedAreaIds) {
                $q->where('user_id', $userId);
                if ($assignedAreaIds->isNotEmpty()) {
                    $q->orWhereIn('area_id', $assignedAreaIds);
                }
            });
        } elseif ($positionId == 2) {
            $spvUserIds = User::whereHas('position', fn ($q) => $q->where('code', 'SPV'))->pluck('id');
            $spvAreaIds = SalesDistributorAssignment::whereIn('user_id', $spvUserIds)
                ->where('is_active', true)
                ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
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

        $allAreaTargets = $areaQuery->get()->groupBy(fn ($a) => $a->depo_id . '_' . ($a->brand_id ?? 0));

        $cardItems = [];
        $totalGrandReward = 0;
        $totalGrandTargetSi = 0;
        $totalGrandRealSi = 0;
        $totalGrandTargetSo = 0;
        $totalGrandRealSo = 0;
        $totalGrandTargetAo = 0;
        $totalGrandRealAo = 0;

        foreach ($depoTargets as $dt) {
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

            // Sell-In
            $targetSi = (float) $dt->target_quota;
            $realSi = (float) $allSellin->where('distributor_id', $dt->distributor_id)
                ->when($dt->brand_id, fn($c) => $c->where('brand_id', $dt->brand_id))
                ->sum('volume_kg');
            $achSiPct = $targetSi > 0 ? round(($realSi / $targetSi) * 100, 1) : 0.0;

            $rewardSi = $this->calculateRewardForMetric($asmHeader, $targetSi, $realSi);

            // Areas
            $areaGroupKey = $dt->depo_id . '_' . ($dt->brand_id ?? 0);
            $areaTargets = $allAreaTargets->get($areaGroupKey) ?? collect();

            if ($areaTargets->isEmpty()) {
                $areaTargets = $allAreaTargets->get($dt->depo_id . '_0') ?? collect();
            }

            $areaList = [];
            $depoTotalAreaReward = 0;
            $areaNo = 1;

            foreach ($areaTargets as $at) {
                $areaName = $at->area?->name ?? '-';
                $areaCode = $at->area?->code ?? '-';
                $spvName = $at->user?->name ?? $spvAssignments->get($at->area_id)?->user?->name ?? '-';
                $areaBrandName = $at->brand?->name ?? $brandName;

                $targetSo = (float) $at->target_quota;
                $targetAo = (int) $at->target_outlet;

                $realSo = (float) $allSellout->where('depo_id', $dt->depo_id)
                    ->when($at->brand_id, fn($c) => $c->where('brand_id', $at->brand_id))
                    ->sum('volume_kg');
                $realAo = (int) $allSellout->where('depo_id', $dt->depo_id)
                    ->when($at->brand_id, fn($c) => $c->where('brand_id', $at->brand_id))
                    ->sum('active_outlet_count');

                $achSoPct = $targetSo > 0 ? round(($realSo / $targetSo) * 100, 1) : 0.0;
                $achAoPct = $targetAo > 0 ? round(($realAo / $targetAo) * 100, 1) : 0.0;

                $rewardSo = $this->calculateRewardForMetric($spvSoHeader, $targetSo, $realSo);
                $rewardAo = $this->calculateRewardForMetric($spvAoHeader, (float) $targetAo, (float) $realAo);
                $subtotalAreaReward = $rewardSo + $rewardAo;

                $depoTotalAreaReward += $subtotalAreaReward;

                $areaList[] = [
                    'no' => $areaNo++,
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
                    'subtotal_area_reward' => $subtotalAreaReward,
                ];

                $totalGrandTargetSo += $targetSo;
                $totalGrandRealSo += $realSo;
                $totalGrandTargetAo += $targetAo;
                $totalGrandRealAo += $realAo;
            }

            $cardTotalReward = $isSpv ? $depoTotalAreaReward : $rewardSi;
            if (!$isSpv && !$isAsm && $rewardSi <= 0 && $depoTotalAreaReward > 0) {
                $cardTotalReward = $depoTotalAreaReward;
            }

            $totalGrandReward += $cardTotalReward;
            $totalGrandTargetSi += $targetSi;
            $totalGrandRealSi += $realSi;

            $cardItems[] = [
                'id' => $dt->id,
                'distributor_name' => $distName,
                'depo_name' => $depoName,
                'brand_name' => $brandName,
                'asm_name' => $asmName,
                'period' => $cleanPeriod,
                'period_formatted' => $periodFormatted,
                'sell_in_target' => $targetSi,
                'sell_in_real' => $realSi,
                'sell_in_ach_pct' => $achSiPct,
                'sell_in_reward' => $rewardSi,
                'total_depo_reward' => $cardTotalReward,
                'areas_count' => count($areaList),
                'areas' => $areaList,
            ];
        }

        return response()->json([
            'meta' => [
                'period' => $cleanPeriod,
                'period_formatted' => $periodFormatted,
                'position_id' => $positionId,
                'user_id' => $userId,
                'user_name' => $selectedUser?->name,
                'user_role' => $userPosCode,
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
        ]);
    }

    protected function calculateRewardForMetric(?TargetHeader $header, float $target, float $real): float
    {
        if (!$header || $target <= 0) return 0.0;

        $matchedGrade = $header->grades->first(function ($grade) use ($target) {
            return $target >= (float) $grade->target_from && $target <= (float) $grade->target_to;
        });

        if (!$matchedGrade && $header->grades->isNotEmpty()) {
            $maxGrade = $header->grades->sortByDesc(fn($g) => (float) $g->target_to)->first();
            $minGrade = $header->grades->sortBy(fn($g) => (float) $g->target_from)->first();
            $matchedGrade = $target > (float) $maxGrade->target_to ? $maxGrade : $minGrade;
        }

        if (!$matchedGrade) return 0.0;

        $achPct = ($real / $target) * 100.0;
        $matchedBobot = $matchedGrade->bobots->first(function ($tier) use ($achPct) {
            return $achPct >= (float) $tier->percent_from && $achPct <= (float) $tier->percent_to;
        });

        if (!$matchedBobot && $matchedGrade->bobots->isNotEmpty()) {
            $minPercent = (float) $matchedGrade->bobots->min(fn($t) => (float) $t->percent_from);
            if ($achPct >= $minPercent) {
                $matchedBobot = $matchedGrade->bobots
                    ->filter(fn($t) => $achPct >= (float) $t->percent_from)
                    ->sortByDesc(fn($t) => (float) $t->percent_from)
                    ->first();
            }
        }

        if (!$matchedBobot) return 0.0;

        $headerBobotFactor = (float) $header->bobot / 100.0;
        if ($matchedBobot->pengali) {
            $capThreshold = $target * ((float) $matchedBobot->percent_to / 100.0);
            $cappedReal = min($real, $capThreshold);
            return (float) $matchedBobot->bobot * $cappedReal * $headerBobotFactor;
        } else {
            return (float) $matchedBobot->nominal * $headerBobotFactor;
        }
    }
}

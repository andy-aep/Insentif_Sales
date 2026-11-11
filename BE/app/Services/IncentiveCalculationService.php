<?php

namespace App\Services;

use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SellinDistributor;
use App\Models\SellinIndustri;
use App\Models\SelloutDistributor;
use App\Models\SelloutSalesSurabaya;
use App\Models\TargetHeader;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class IncentiveCalculationService
{
    /**
     * Menjalankan kalkulasi insentif per kategori skema & periode (Format YYYYMM).
     */
    public function execute(
        string $kategoriSkema,
        string $period,
        int $authUserId,
        ?int $positionId = null,
        ?int $userId = null
    ): Collection {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);
        $year = substr($cleanPeriod, 0, 4);
        $month = substr($cleanPeriod, 4, 2);

        $startDate = Carbon::createFromDate((int) $year, (int) $month, 1)->startOfMonth()->format('Y-m-d');
        $endDate = Carbon::createFromDate((int) $year, (int) $month, 1)->endOfMonth()->format('Y-m-d');

        $periodYmdStart = $year.$month.'01';
        $periodYmdEnd = $year.$month.'31';

        // 1. Ambil seluruh personil aktif sesuai eligibility flag & filter posisi/user
        $eligibleUsers = User::whereNotNull('position_id')
            ->where('aktif_from', '<=', $endDate)
            ->where(function ($q) use ($startDate) {
                $q->whereNull('aktif_to')
                    ->orWhere('aktif_to', '>=', $startDate);
            })
            ->when($kategoriSkema === 'KONSUMSI', fn ($q) => $q->where('is_eligible_konsumsi', true))
            ->when($kategoriSkema === 'INDUSTRI', fn ($q) => $q->where('is_eligible_industri', true))
            ->when($kategoriSkema === 'SURABAYA', fn ($q) => $q->where('is_eligible_surabaya', true))
            ->when($positionId, fn ($q) => $q->where('position_id', $positionId))
            ->when($userId, fn ($q) => $q->where('id', $userId))
            ->with('position')
            ->get();

        $results = collect();

        foreach ($eligibleUsers as $user) {
            // 2. Ambil skema TargetHeader aktif sesuai posisi & kategori skema
            $targetHeaders = TargetHeader::where('kategori_skema', $kategoriSkema)
                ->where('sales_type', $user->position_id)
                ->where('aktif', true)
                ->where(function ($q) use ($periodYmdStart, $periodYmdEnd, $startDate, $endDate) {
                    $q->where(function ($sub) use ($periodYmdStart, $periodYmdEnd) {
                        $sub->where('aktif_from', '<=', $periodYmdEnd)
                            ->where('aktif_to', '>=', $periodYmdStart);
                    })->orWhere(function ($sub) use ($startDate, $endDate) {
                        $sub->where('aktif_from', '<=', $endDate)
                            ->where('aktif_to', '>=', $startDate);
                    });
                })
                ->with(['grades.bobots'])
                ->get();

            foreach ($targetHeaders as $header) {
                // 3. Ambil target kuota sales (Target Depo untuk ASM, Target Area untuk SPV)
                $normalizedMetric = strtoupper(str_replace('-', '_', trim($header->type)));
                $metricVariants = array_unique([$header->type, $normalizedMetric, str_replace('_', '-', $normalizedMetric)]);

                $targetQuery = MasterTarget::where('kategori_skema', $kategoriSkema)
                    ->whereIn('metrik_target', $metricVariants)
                    ->where('period', $cleanPeriod);

                $posCode = strtoupper($user->position?->code ?? '');

                $directQuery = (clone $targetQuery)->where('user_id', $user->id);
                if ($kategoriSkema === 'KONSUMSI') {
                    if ($posCode === 'SPV') {
                        $directQuery->where('level', 'AREA');
                    } elseif ($posCode === 'ASM') {
                        $directQuery->where('level', 'DEPO');
                    }
                }
                $isAoMetric = in_array($normalizedMetric, ['AO', 'ACTIVE_OUTLET', 'OUTLET', 'TARGET_OUTLET'])
                    || str_contains($normalizedMetric, 'AO')
                    || str_contains($normalizedMetric, 'OUTLET');

                $targetQuota = (float) $directQuery->sum('target_quota');
                if ($targetQuota <= 0 && $isAoMetric && $posCode === 'SPV') {
                    $targetQuota = (float) MasterTarget::where('kategori_skema', $kategoriSkema)
                        ->where('period', $cleanPeriod)
                        ->where('user_id', $user->id)
                        ->where('level', 'AREA')
                        ->sum('target_outlet');
                }

                if ($targetQuota <= 0 && $kategoriSkema === 'KONSUMSI') {
                    $assignments = SalesDistributorAssignment::where('user_id', $user->id)
                        ->where('is_active', true)
                        ->where('period', $cleanPeriod)
                        ->get();

                    if ($posCode === 'SPV') {
                        $areaIds = $assignments->pluck('area_id')->filter()->unique();
                        if ($isAoMetric) {
                            $targetQuota = (float) MasterTarget::where('kategori_skema', $kategoriSkema)
                                ->where('period', $cleanPeriod)
                                ->where('level', 'AREA')
                                ->whereIn('area_id', $areaIds)
                                ->sum('target_outlet');
                        } else {
                            $targetQuota = (float) (clone $targetQuery)
                                ->where('level', 'AREA')
                                ->whereIn('area_id', $areaIds)
                                ->sum('target_quota');
                        }
                    } elseif ($posCode === 'ASM') {
                        $depoIds = $assignments->pluck('depo_id')->filter()->unique();
                        $distIds = $assignments->pluck('distributor_id')->filter()->unique();
                        $asmQuery = (clone $targetQuery)->where('level', 'DEPO');
                        if ($depoIds->isNotEmpty()) {
                            $asmQuery->whereIn('depo_id', $depoIds);
                        } else {
                            $asmQuery->whereIn('distributor_id', $distIds);
                        }
                        $targetQuota = (float) $asmQuery->sum('target_quota');
                    }
                }

                if ($targetQuota <= 0) {
                    continue;
                }
                $realization = (float) $this->resolveRealization($user, $header, $cleanPeriod);

                // 4. Evaluasi Grade (Level 2) sesuai Setting Insentif
                $matchedGrade = $header->grades->first(function ($grade) use ($targetQuota) {
                    return $targetQuota >= (float) $grade->target_from && $targetQuota <= (float) $grade->target_to;
                });

                if (! $matchedGrade && $header->grades->isNotEmpty()) {
                    $maxGrade = $header->grades->sortByDesc(fn ($g) => (float) $g->target_to)->first();
                    $minGrade = $header->grades->sortBy(fn ($g) => (float) $g->target_from)->first();
                    $matchedGrade = $targetQuota > (float) $maxGrade->target_to ? $maxGrade : $minGrade;
                }

                if (! $matchedGrade) {
                    continue;
                }

                // 5. Evaluasi Persentase Pencapaian & Grade Bobot (Level 3)
                $achievementPercent = ($realization / $targetQuota) * 100.0;

                $matchedBobot = $matchedGrade->bobots->first(function ($tier) use ($achievementPercent) {
                    return $achievementPercent >= (float) $tier->percent_from && $achievementPercent <= (float) $tier->percent_to;
                });

                if (! $matchedBobot && $matchedGrade->bobots->isNotEmpty()) {
                    $minPercent = (float) $matchedGrade->bobots->min(fn ($t) => (float) $t->percent_from);
                    if ($achievementPercent >= $minPercent) {
                        $matchedBobot = $matchedGrade->bobots
                            ->filter(fn ($t) => $achievementPercent >= (float) $t->percent_from)
                            ->sortByDesc(fn ($t) => (float) $t->percent_from)
                            ->first();
                    }
                }

                // 6. Hitung Nominal Reward sesuai Setting Insentif
                $headerBobotFactor = (float) $header->bobot / 100.0;
                $cappedRealization = $realization;
                $firstBobot = $matchedGrade->bobots->sortBy(fn ($t) => (float) $t->percent_from)->first();
                $isRateBased = $matchedBobot ? (bool) $matchedBobot->pengali : (bool) ($firstBobot?->pengali ?? true);
                $unitRate = $matchedBobot ? (float) $matchedBobot->bobot : 0.0;
                $lumpSumNominal = $matchedBobot ? (float) $matchedBobot->nominal : 0.0;
                $totalReward = 0.0;

                if ($matchedBobot) {
                    if ($matchedBobot->pengali) {
                        // Model Rate-based dengan pembatasan volume (Cap)
                        $capThreshold = $targetQuota * ((float) $matchedBobot->percent_to / 100.0);
                        $cappedRealization = min($realization, $capThreshold);
                        $totalReward = (float) $matchedBobot->bobot * $cappedRealization * $headerBobotFactor;
                    } else {
                        // Model Nominal Flat (Lump-sum)
                        $totalReward = (float) $matchedBobot->nominal * $headerBobotFactor;
                    }
                }

                // Simpan kalkulasi ke database
                $calc = IncentiveCalculation::updateOrCreate(
                    [
                        'user_id' => $user->id,
                        'kategori_skema' => $kategoriSkema,
                        'target_header_id' => $header->id,
                        'period' => $cleanPeriod,
                    ],
                    [
                        'grade_id' => $matchedGrade->id,
                        'grade_bobot_id' => $matchedBobot?->id,
                        'target_quota' => $targetQuota,
                        'realization' => $realization,
                        'achievement_percent' => $achievementPercent,
                        'capped_realization' => $cappedRealization,
                        'is_rate_based' => $isRateBased,
                        'unit_rate' => $unitRate,
                        'lump_sum_nominal' => $lumpSumNominal,
                        'header_bobot_percent' => $header->bobot,
                        'final_reward' => $totalReward,
                        'calculated_by' => $authUserId,
                    ]
                );

                $results->push($calc->load(['user.position', 'targetHeader', 'grade', 'gradeBobot']));
            }
        }

        return $results;
    }

    protected function resolveRealization(User $user, TargetHeader $header, string $period): float
    {
        $metricType = strtoupper(str_replace('-', '_', trim($header->type)));
        $isAoMetric = in_array($metricType, ['AO', 'ACTIVE_OUTLET', 'OUTLET', 'TARGET_OUTLET'])
            || str_contains($metricType, 'AO')
            || str_contains($metricType, 'OUTLET');
        $isSellOut = str_contains($metricType, 'OUT') && ! $isAoMetric;

        if ($header->kategori_skema === 'KONSUMSI') {
            $posCode = strtoupper($user->position?->code ?? '');

            // 1. Cek penugasan langsung dari MasterTarget pada periode ini
            $userTargets = MasterTarget::where('kategori_skema', 'KONSUMSI')
                ->where('user_id', $user->id)
                ->where('period', $period)
                ->get();

            if ($userTargets->isNotEmpty()) {
                if ($posCode === 'ASM') {
                    $depoTargets = $userTargets->where('level', 'DEPO');
                    $distributorIds = ($depoTargets->isNotEmpty() ? $depoTargets : $userTargets)
                        ->pluck('distributor_id')
                        ->filter()
                        ->unique();
                    $depoIds = ($depoTargets->isNotEmpty() ? $depoTargets : $userTargets)
                        ->pluck('depo_id')
                        ->filter()
                        ->unique();

                    if ($isAoMetric) {
                        if ($depoIds->isEmpty() && $distributorIds->isNotEmpty()) {
                            $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        }
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count')
                            : 0.0;
                    } elseif ($isSellOut) {
                        if ($depoIds->isEmpty() && $distributorIds->isNotEmpty()) {
                            $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        }
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg')
                            : 0.0;
                    } else {
                        return $distributorIds->isNotEmpty()
                            ? (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg')
                            : 0.0;
                    }
                } elseif ($posCode === 'SPV') {
                    $areaTargets = $userTargets->where('level', 'AREA');
                    $depoIds = ($areaTargets->isNotEmpty() ? $areaTargets : $userTargets)
                        ->pluck('depo_id')
                        ->filter()
                        ->unique();
                    $distributorIds = ($areaTargets->isNotEmpty() ? $areaTargets : $userTargets)
                        ->pluck('distributor_id')
                        ->filter()
                        ->unique();

                    if ($isAoMetric) {
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count')
                            : 0.0;
                    } elseif ($isSellOut) {
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg')
                            : 0.0;
                    } else {
                        return $distributorIds->isNotEmpty()
                            ? (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg')
                            : 0.0;
                    }
                }
            }

            // 2. Fallback ke SalesDistributorAssignment bila ada
            $assignments = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('is_active', true)
                ->where('period', $period)
                ->get();

            if ($assignments->isNotEmpty()) {
                if ($posCode === 'NSM') {
                    $subordinateLsmAssignments = SalesDistributorAssignment::where('nsm_id', $user->id)
                        ->where('is_active', true)
                        ->where('period', $period)
                        ->get();

                    $directRegionIds = $assignments->pluck('region_id')->filter()->unique();
                    $assignedRegionIds = $subordinateLsmAssignments->pluck('region_id')
                        ->merge($directRegionIds)
                        ->filter()
                        ->unique();

                    if ($assignedRegionIds->isNotEmpty()) {
                        $distributorIds = Distributor::whereIn('region_id', $assignedRegionIds)->pluck('id');
                        if ($isAoMetric) {
                            $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                            return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count');
                        } elseif ($isSellOut) {
                            $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                            return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                        } else {
                            return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                        }
                    }

                    return $isAoMetric
                        ? (float) SelloutDistributor::where('period', $period)->sum('active_outlet_count')
                        : ($isSellOut
                            ? (float) SelloutDistributor::where('period', $period)->sum('volume_kg')
                            : (float) SellinDistributor::where('period', $period)->sum('volume_kg'));
                } elseif ($posCode === 'LSM') {
                    $regionIds = $assignments->pluck('region_id')->filter()->unique();
                    $distributorIds = Distributor::whereIn('region_id', $regionIds)->pluck('id');
                    if ($isAoMetric) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count');
                    } elseif ($isSellOut) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                } elseif ($posCode === 'ASM') {
                    $distributorIds = $assignments->pluck('distributor_id')->filter()->unique();
                    if ($isAoMetric) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count');
                    } elseif ($isSellOut) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                } elseif ($posCode === 'SPV') {
                    $depoIds = $assignments->pluck('depo_id')->filter()->unique();
                    if ($isAoMetric) {
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count');
                    } elseif ($isSellOut) {
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        $distributorIds = $assignments->pluck('distributor_id')->filter()->unique();
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                }
            }

            return 0.0;
        }

        return match ($header->kategori_skema) {
            'INDUSTRI' => (float) SellinIndustri::where('user_id', $user->id)
                ->where('period', $period)
                ->sum('tonase'),
            'SURABAYA' => $isAoMetric
                ? (float) SelloutSalesSurabaya::where(function ($q) use ($user) {
                    $q->where('sales_id', $user->id)
                        ->orWhere('coordinator_id', $user->id);
                })->where('period', $period)->sum('active_outlet_count')
                : (float) SelloutSalesSurabaya::where(function ($q) use ($user) {
                    $q->where('sales_id', $user->id)
                        ->orWhere('coordinator_id', $user->id);
                })->where('period', $period)->sum('volume'),
            default => 0.0,
        };
    }
}

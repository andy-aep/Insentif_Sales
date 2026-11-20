<?php

namespace App\Services;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IncentiveCalculation;
use App\Models\IndustriCustomer;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SalesIndustriAssignment;
use App\Models\SalesSurabayaAssignment;
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
        if (strtoupper($kategoriSkema) === 'INDUSTRI') {
            return $this->executeIndustri($period, $authUserId, $positionId, $userId);
        }
        if (strtoupper($kategoriSkema) === 'SURABAYA') {
            return $this->executeSurabaya($period, $authUserId, $positionId, $userId);
        }

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
                ->get()
                ->sortBy(function ($h) {
                    $t = strtoupper(str_replace('-', '_', trim((string) $h->type)));
                    return (str_contains($t, 'AO') || str_contains($t, 'OUTLET')) ? 1 : 0;
                })
                ->values();

            $siPassedForUser = false;
            $soPassedForUser = false;

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
                    if (in_array($posCode, ['SPV', 'ASC'], true)) {
                        $directQuery->where('level', 'AREA');
                    } elseif ($posCode === 'ASM') {
                        $directQuery->where('level', 'DEPO');
                    }
                }
                $isAoMetric = in_array($normalizedMetric, ['AO', 'ACTIVE_OUTLET', 'OUTLET', 'TARGET_OUTLET'])
                    || str_contains($normalizedMetric, 'AO')
                    || str_contains($normalizedMetric, 'OUTLET');
                $isSellOut = str_contains($normalizedMetric, 'OUT') && ! $isAoMetric;
                $isSellIn = ! $isAoMetric && ! $isSellOut;

                $targetQuota = (float) $directQuery->sum('target_quota');
                if ($targetQuota <= 0 && $isAoMetric && in_array($posCode, ['SPV', 'ASC'], true)) {
                    $targetQuota = (float) MasterTarget::where('kategori_skema', $kategoriSkema)
                        ->where('period', $cleanPeriod)
                        ->where('user_id', $user->id)
                        ->where('level', 'AREA')
                        ->sum('target_outlet');
                }

                // Untuk SPV/ASC Konsumsi yang memiliki skema SELL_IN di Setting Bobot:
                // Target & realisasi SELL_IN mengikuti Depo induk tempat Area miliknya berada (dengan bobot SPV).
                if ($targetQuota <= 0 && $kategoriSkema === 'KONSUMSI' && $isSellIn && in_array($posCode, ['SPV', 'ASC'], true)) {
                    $userAreaTargets = MasterTarget::where('kategori_skema', $kategoriSkema)
                        ->where('period', $cleanPeriod)
                        ->where('user_id', $user->id)
                        ->where('level', 'AREA')
                        ->get();
                    $spvAssigns = SalesDistributorAssignment::where('user_id', $user->id)
                        ->where('is_active', true)
                        ->where(fn ($q) => $q->where('period', $cleanPeriod)->orWhereNull('period'))
                        ->get();
                    $assignAreaIds = $spvAssigns->pluck('area_id')->filter()->unique();
                    $areaDepoIds = $assignAreaIds->isNotEmpty()
                        ? Area::whereIn('id', $assignAreaIds)->pluck('depo_id')
                        : collect();
                    $depoIds = $userAreaTargets->pluck('depo_id')
                        ->merge($spvAssigns->pluck('depo_id'))
                        ->merge($areaDepoIds)
                        ->filter()
                        ->unique();

                    if ($depoIds->isNotEmpty()) {
                        $targetQuota = (float) (clone $targetQuery)
                            ->where('level', 'DEPO')
                            ->whereIn('depo_id', $depoIds)
                            ->sum('target_quota');
                    }
                }

                if ($targetQuota <= 0 && $kategoriSkema === 'KONSUMSI') {
                    $assignments = SalesDistributorAssignment::where('user_id', $user->id)
                        ->where('is_active', true)
                        ->where('period', $cleanPeriod)
                        ->get();

                    if (in_array($posCode, ['SPV', 'ASC'], true)) {
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

                // 6. Hitung Nominal Reward sesuai Setting Insentif (tanpa cap realisasi)
                $headerBobotFactor = (float) $header->bobot / 100.0;
                $cappedRealization = $realization;
                $firstBobot = $matchedGrade->bobots->sortBy(fn ($t) => (float) $t->percent_from)->first();
                $isRateBased = $matchedBobot ? (bool) $matchedBobot->pengali : (bool) ($firstBobot?->pengali ?? true);
                $unitRate = $matchedBobot ? (float) $matchedBobot->bobot : 0.0;
                $lumpSumNominal = $matchedBobot ? (float) $matchedBobot->nominal : 0.0;
                $minAchPct = (float) ($header->min_achievement_pct ?? 0);
                $isPassed = $matchedBobot !== null && $achievementPercent >= $minAchPct;

                if ($kategoriSkema === 'KONSUMSI') {
                    if ($isSellIn && $isPassed) {
                        $siPassedForUser = true;
                    } elseif ($isSellOut && $isPassed) {
                        $soPassedForUser = true;
                    } elseif ($isAoMetric && ! ($siPassedForUser || $soPassedForUser)) {
                        $isPassed = false;
                    }
                }

                $totalReward = 0.0;
                if ($matchedBobot && $isPassed) {
                    if ($matchedBobot->pengali) {
                        // Model Rate-based tanpa cap: Bobot Tier * Realisasi * Bobot Header %
                        $totalReward = (float) $matchedBobot->bobot * $realization * $headerBobotFactor;
                    } else {
                        // Model Nominal Flat (AO): Nominal Tetap * Bobot Header %
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
                        return $this->sumSellinForUser($user, $period, $depoIds, $distributorIds);
                    }
                } elseif (in_array($posCode, ['SPV', 'ASC'], true)) {
                    $areaTargets = $userTargets->where('level', 'AREA');
                    $areaIds = $areaTargets->pluck('area_id')->filter()->unique();
                    $depoIds = ($areaTargets->isNotEmpty() ? $areaTargets : $userTargets)
                        ->pluck('depo_id')
                        ->filter()
                        ->unique();
                    $distributorIds = ($areaTargets->isNotEmpty() ? $areaTargets : $userTargets)
                        ->pluck('distributor_id')
                        ->filter()
                        ->unique();

                    if ($depoIds->isEmpty() && $areaIds->isNotEmpty()) {
                        $depoIds = Area::whereIn('id', $areaIds)->pluck('depo_id')->filter()->unique();
                    }

                    $hasAreaSellout = $areaIds->isNotEmpty()
                        && SelloutDistributor::where('period', $period)->whereIn('area_id', $areaIds)->exists();

                    if ($isAoMetric) {
                        if ($hasAreaSellout) {
                            return (float) SelloutDistributor::whereIn('area_id', $areaIds)->where('period', $period)->sum('active_outlet_count');
                        }
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('active_outlet_count')
                            : 0.0;
                    } elseif ($isSellOut) {
                        if ($hasAreaSellout) {
                            return (float) SelloutDistributor::whereIn('area_id', $areaIds)->where('period', $period)->sum('volume_kg');
                        }
                        return $depoIds->isNotEmpty()
                            ? (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg')
                            : 0.0;
                    } else {
                        return $this->sumSellinForUser($user, $period, $depoIds, $distributorIds);
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
                        $depoIds = $assignments->pluck('depo_id')->filter()->unique();
                        return $this->sumSellinForUser($user, $period, $depoIds, $distributorIds);
                    }
                } elseif (in_array($posCode, ['SPV', 'ASC'], true)) {
                    $areaIds = $assignments->pluck('area_id')->filter()->unique();
                    $depoIds = $assignments->pluck('depo_id')->filter()->unique();
                    if ($depoIds->isEmpty() && $areaIds->isNotEmpty()) {
                        $depoIds = Area::whereIn('id', $areaIds)->pluck('depo_id')->filter()->unique();
                    }
                    $hasAreaSellout = $areaIds->isNotEmpty()
                        && SelloutDistributor::where('period', $period)->where('is_out_of_area', false)->whereIn('area_id', $areaIds)->exists();

                    if ($isAoMetric) {
                        if ($hasAreaSellout) {
                            return (float) SelloutDistributor::whereIn('area_id', $areaIds)->where('period', $period)->where('is_out_of_area', false)->sum('active_outlet_count');
                        }
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->where('is_out_of_area', false)->sum('active_outlet_count');
                    } elseif ($isSellOut) {
                        if ($hasAreaSellout) {
                            return (float) SelloutDistributor::whereIn('area_id', $areaIds)->where('period', $period)->where('is_out_of_area', false)->sum('volume_kg');
                        }
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->where('is_out_of_area', false)->sum('volume_kg');
                    } else {
                        $distributorIds = $assignments->pluck('distributor_id')->filter()->unique();
                        return $this->sumSellinForUser($user, $period, $depoIds, $distributorIds);
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

    /**
     * Eksekusi dan simpan kalkulasi Insentif Sales Industri sesuai spesifikasi resmi:
     * - Cek is_eligible_industri (jika false -> insentif 0, tidak ada payout).
     * - Mendukung posisi ASM, SPV, ASC untuk metode SELL_IN & NOO.
     * - SELL_IN: tanpa cap realisasi! Actual Kg >= Min Ach % -> Grade match Target Kg -> Actual Kg * Rate * Bobot Header %.
     * - NOO: hitung customer baru transaksi pertama tahun/bulan berjalan -> Actual NOO / Target NOO >= Min Ach % -> Grade match Target Outlet -> Actual NOO Kg * Rate * Bobot Header %.
     */
    public function executeIndustri(
        string $period,
        int $authUserId,
        ?int $positionId = null,
        ?int $userId = null
    ): Collection {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);

        // Bersihkan hasil lama dalam cakupan filter agar status ineligibility / perubahan target bersih
        IncentiveCalculation::where('kategori_skema', 'INDUSTRI')
            ->where('period', $cleanPeriod)
            ->when($userId, fn ($q) => $q->where('user_id', $userId))
            ->when(!$userId && $positionId, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('position_id', $positionId)))
            ->delete();

        $evaluated = $this->evaluateIndustriForPeriod($cleanPeriod, $positionId, $userId, null, false);
        $results = collect();

        foreach ($evaluated['cards'] as $card) {
            if (!$card['is_eligible_industri']) {
                continue;
            }

            foreach ($card['header_records'] as $rec) {
                $calculation = IncentiveCalculation::create([
                    'user_id' => $card['user_id'],
                    'kategori_skema' => 'INDUSTRI',
                    'target_header_id' => $rec['target_header_id'],
                    'grade_id' => $rec['grade_id'],
                    'grade_bobot_id' => $rec['grade_bobot_id'],
                    'period' => $cleanPeriod,
                    'target_quota' => $rec['target_quota'],
                    'realization' => $rec['realization'],
                    'noo_volume_kg' => $rec['noo_volume_kg'],
                    'achievement_percent' => $rec['achievement_percent'],
                    'min_achievement_pct' => $rec['min_achievement_pct'],
                    'is_passed' => $rec['is_passed'],
                    'capped_realization' => $rec['capped_realization'],
                    'is_rate_based' => $rec['is_rate_based'],
                    'unit_rate' => $rec['unit_rate'],
                    'lump_sum_nominal' => $rec['lump_sum_nominal'],
                    'header_bobot_percent' => $rec['header_bobot_percent'],
                    'final_reward' => $rec['final_reward'],
                    'audit_notes' => $rec['audit_notes'],
                    'calculated_by' => $authUserId,
                ]);

                $results->push($calculation->load(['user.position', 'targetHeader', 'grade', 'gradeBobot']));
            }
        }

        return $results;
    }

    /**
     * Hitung total Sell-In Distributor (Kg) milik sales tertentu dengan memperhatikan
     * Depo penugasan dan rentang tanggal aktif (aktif_from - aktif_to) untuk split omset tengah bulan.
     */
    private function sumSellinForUser(User $user, string $period, $depoIds, $distributorIds): float
    {
        $hasDepo = $depoIds && $depoIds->isNotEmpty();
        $hasDist = $distributorIds && $distributorIds->isNotEmpty();

        if (! $hasDepo && ! $hasDist) {
            return 0.0;
        }

        $query = SellinDistributor::where('period', $period);

        if ($hasDepo && SellinDistributor::where('period', $period)->whereIn('depo_id', $depoIds)->exists()) {
            $query->whereIn('depo_id', $depoIds);
        } elseif ($hasDist) {
            $query->whereIn('distributor_id', $distributorIds);
        }

        $from = $user->aktif_from ? $user->aktif_from->format('Y-m-d') : null;
        $to = $user->aktif_to ? $user->aktif_to->format('Y-m-d') : null;
        if ($from || $to) {
            $query->where(function ($q) use ($from, $to, $user) {
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

        return (float) $query->sum('volume_kg');
    }

    /**
     * Evaluasi penuh skema Industri untuk keperluan eksekusi maupun audit breakdown card UI.
     */
    public function evaluateIndustriForPeriod(
        string $period,
        ?int $positionId = null,
        ?int $userId = null,
        ?string $search = null,
        bool $includeIneligibleIfFiltered = false
    ): array {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);
        $year = substr($cleanPeriod, 0, 4);
        $month = substr($cleanPeriod, 4, 2);

        $startDate = Carbon::createFromDate((int) $year, (int) $month, 1)->startOfMonth()->format('Y-m-d');
        $endDate = Carbon::createFromDate((int) $year, (int) $month, 1)->endOfMonth()->format('Y-m-d');
        $periodYmdStart = $year.$month.'01';
        $periodYmdEnd = $year.$month.'31';

        $usersQuery = User::with('position')
            ->whereNotNull('position_id')
            ->where(function ($q) use ($endDate) {
                $q->whereNull('aktif_from')->orWhere('aktif_from', '<=', $endDate);
            })
            ->where(function ($q) use ($startDate) {
                $q->whereNull('aktif_to')->orWhere('aktif_to', '>=', $startDate);
            })
            ->when($positionId, fn ($q) => $q->where('position_id', $positionId))
            ->when($userId, fn ($q) => $q->where('id', $userId))
            ->when($search, function ($q) use ($search) {
                $term = strtolower(trim($search));
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(name) like ?', ["%{$term}%"])
                        ->orWhereRaw('LOWER(username) like ?', ["%{$term}%"]);
                });
            })
            ->orderBy('name');

        if (!($includeIneligibleIfFiltered && $userId !== null)) {
            $usersQuery->where('is_eligible_industri', true);
        }

        $users = $usersQuery->get();

        $activeHeaders = TargetHeader::where('kategori_skema', 'INDUSTRI')
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
            ->get()
            ->groupBy('sales_type');

        $allTargets = MasterTarget::where('kategori_skema', 'INDUSTRI')
            ->where('period', $cleanPeriod)
            ->get()
            ->groupBy('user_id');

        $allAssignments = SalesIndustriAssignment::with('customer')
            ->where('is_active', true)
            ->where(function ($q) use ($cleanPeriod) {
                $q->where('period', $cleanPeriod)
                    ->orWhereNull('period')
                    ->orWhere('period', '');
            })
            ->get()
            ->groupBy('user_id');

        $allSellins = SellinIndustri::where('period', '<=', $cleanPeriod)
            ->get()
            ->filter(fn ($tx) => ((float) ($tx->volume_kg > 0 ? $tx->volume_kg : $tx->tonase)) > 0);

        $cards = [];
        $summaryTargetSellInKg = 0.0;
        $summaryActualSellInKg = 0.0;
        $summaryTargetNoo = 0.0;
        $summaryActualNoo = 0.0;
        $summaryActualNooKg = 0.0;
        $summaryTotalPayout = 0.0;

        foreach ($users as $user) {
            $posCode = strtoupper($user->position?->code ?? '');
            if (!$user->is_eligible_industri) {
                $cards[] = [
                    'user_id' => $user->id,
                    'user_name' => $user->name,
                    'username' => $user->username,
                    'position_id' => $user->position_id,
                    'position_code' => $posCode,
                    'position_name' => $user->position?->name ?? '-',
                    'is_eligible_industri' => false,
                    'period' => $cleanPeriod,
                    'ineligibility_reason' => 'Status Is Eligible Industri tidak aktif — insentif otomatis Rp 0.',
                    'sell_in' => null,
                    'noo' => null,
                    'customers' => [],
                    'assigned_customers_count' => 0,
                    'total_reward' => 0.0,
                    'header_records' => [],
                ];
                continue;
            }

            $userAssignments = ($allAssignments->get($user->id) ?? collect())
                ->filter(fn ($a) => $a->customer !== null && $a->customer->is_active);
            $assignedCustomers = $userAssignments
                ->unique('industri_customer_id')
                ->map(fn ($a) => $a->customer)
                ->values();

            $customerAuditList = [];
            $actualSellInKg = 0.0;
            $actualNooCount = 0;
            $actualNooKg = 0.0;

            foreach ($assignedCustomers as $customer) {
                $custId = (int) $customer->id;
                $custCode = strtoupper(trim((string) $customer->customer_code));
                $custName = strtolower(trim((string) $customer->customer_name));

                $matchedTxs = $allSellins->filter(function ($tx) use ($custId, $custCode, $custName) {
                    if ($tx->industri_customer_id !== null) {
                        return (int) $tx->industri_customer_id === $custId;
                    }
                    $txCode = strtoupper(trim((string) ($tx->customer_code ?? '')));
                    if ($txCode !== '' && $custCode !== '' && $txCode === $custCode) {
                        return true;
                    }
                    $txName = strtolower(trim((string) ($tx->customer_name ?? '')));
                    return $txName !== '' && $txName === $custName;
                });

                $currentYear = substr($cleanPeriod, 0, 4);
                $yearStartPeriod = "{$currentYear}01";

                $currentTxs = $matchedTxs->filter(fn ($tx) => $tx->period === $cleanPeriod)->values();
                // Reset NOO setahun sekali: hanya transaksi tahun berjalan sebelum periode ini yang menggugurkan NOO
                $earlierTxsInYear = $matchedTxs
                    ->filter(fn ($tx) => $tx->period >= $yearStartPeriod && $tx->period < $cleanPeriod)
                    ->values();

                $periodVolumeKg = (float) $currentTxs->sum(fn ($tx) => (float) ($tx->volume_kg > 0 ? $tx->volume_kg : $tx->tonase));
                $periodNominal = (float) $currentTxs->sum(fn ($tx) => (float) ($tx->nominal ?? 0));
                $actualSellInKg += $periodVolumeKg;

                $isNoo = false;
                $nooReason = 'Belum ada pembelian pada periode ini';

                if ($periodVolumeKg > 0) {
                    $hasExplicitTrue = $currentTxs->contains(fn ($tx) => $tx->is_noo === true);
                    $allExplicitFalse = $currentTxs->isNotEmpty() && $currentTxs->every(fn ($tx) => $tx->is_noo === false);
                    $firstPeriodProp = !empty($customer->first_transaction_period)
                        ? preg_replace('/[^0-9]/', '', $customer->first_transaction_period)
                        : null;
                    $hasPriorPeriodInSameYear = !empty($firstPeriodProp)
                        && $firstPeriodProp >= $yearStartPeriod
                        && $firstPeriodProp < $cleanPeriod;

                    if ($hasExplicitTrue) {
                        $isNoo = true;
                        $nooReason = 'NOO Baru (ditandai manual)';
                    } elseif ($allExplicitFalse) {
                        $isNoo = false;
                        $nooReason = 'Repeat / Bukan NOO (ditandai manual)';
                    } elseif ($earlierTxsInYear->isNotEmpty()) {
                        $firstPrev = $earlierTxsInYear->sortBy('period')->first();
                        $isNoo = false;
                        $nooReason = "Repeat customer tahun {$currentYear} (pernah transaksi {$firstPrev->period})";
                    } elseif ($hasPriorPeriodInSameYear) {
                        $isNoo = false;
                        $nooReason = "Repeat customer tahun {$currentYear} (transaksi awal {$firstPeriodProp})";
                    } else {
                        $isNoo = true;
                        $nooReason = "NOO Baru tahun {$currentYear} (pembelian pertama pada {$cleanPeriod})";
                    }

                    if ($isNoo) {
                        $actualNooCount += 1;
                        $actualNooKg += $periodVolumeKg;
                    }
                }

                $customerAuditList[] = [
                    'customer_id' => $custId,
                    'customer_code' => $customer->customer_code,
                    'customer_name' => $customer->customer_name,
                    'city' => $customer->city,
                    'customer_type' => $customer->customer_type,
                    'volume_kg' => round($periodVolumeKg, 2),
                    'nominal' => round($periodNominal, 2),
                    'tx_count' => $currentTxs->count(),
                    'is_noo' => $isNoo,
                    'noo_reason' => $nooReason,
                ];
            }

            $userHeaders = $activeHeaders->get($user->position_id) ?? collect();
            $userTargets = $allTargets->get($user->id) ?? collect();

            $sellInBreakdown = null;
            $nooBreakdown = null;
            $headerRecords = [];
            $userTotalReward = 0.0;

            foreach ($userHeaders as $header) {
                $normType = strtoupper(str_replace(['-', ' '], '_', trim($header->type)));
                $isNooMethod = $normType === 'NOO' || str_contains($normType, 'NOO') || str_contains($normType, 'NEW_OUTLET');
                $methodKey = $isNooMethod ? 'NOO' : 'SELL_IN';

                $targetQuota = (float) $userTargets
                    ->filter(function ($t) use ($isNooMethod) {
                        $m = strtoupper(str_replace(['-', ' '], '_', trim($t->metrik_target)));
                        $tIsNoo = $m === 'NOO' || str_contains($m, 'NOO') || str_contains($m, 'NEW_OUTLET');
                        return $tIsNoo === $isNooMethod;
                    })
                    ->sum('target_quota');

                $realizationValue = $isNooMethod ? (float) $actualNooCount : (float) $actualSellInKg;
                $rawAch = $targetQuota > 0 ? ($realizationValue / $targetQuota) * 100.0 : 0.0;
                $achievementPercent = round($rawAch, 2);
                $minAchievementPct = (float) ($header->min_achievement_pct ?? 0);
                $headerBobotPct = (float) ($header->bobot ?? 0);
                $isPassed = $targetQuota > 0 && $rawAch >= $minAchievementPct;

                $matchedGrade = $header->grades
                    ->sortBy(fn ($g) => (float) $g->target_from)
                    ->first(fn ($g) => $targetQuota > 0
                        && $targetQuota >= (float) $g->target_from
                        && $targetQuota <= (float) $g->target_to);

                $unitRate = 0.0;
                $lumpSumNominal = 0.0;
                $isRateBased = true;
                $matchedBobot = null;

                if ($matchedGrade) {
                    if ($matchedGrade->multiplier_rate !== null && (float) $matchedGrade->multiplier_rate > 0) {
                        $unitRate = (float) $matchedGrade->multiplier_rate;
                        $isRateBased = true;
                    } elseif ($matchedGrade->bobots->isNotEmpty()) {
                        $matchedBobot = $matchedGrade->bobots->first(fn ($b) => $rawAch >= (float) $b->percent_from && $rawAch <= (float) $b->percent_to);
                        if (!$matchedBobot) {
                            $matchedBobot = $matchedGrade->bobots
                                ->filter(fn ($b) => $rawAch >= (float) $b->percent_from)
                                ->sortByDesc(fn ($b) => (float) $b->percent_from)
                                ->first();
                        }
                        if ($matchedBobot) {
                            if ($matchedBobot->pengali) {
                                $unitRate = (float) $matchedBobot->bobot;
                                $isRateBased = true;
                            } else {
                                $lumpSumNominal = (float) $matchedBobot->nominal;
                                $isRateBased = false;
                            }
                        }
                    }
                }

                $volumeForPayoutKg = $isNooMethod ? (float) $actualNooKg : (float) $actualSellInKg;
                $grossReward = 0.0;
                $finalReward = 0.0;
                $auditNotes = null;

                if ($targetQuota <= 0) {
                    $auditNotes = 'Target belum diset (Target = 0)';
                } elseif (!$isPassed) {
                    $auditNotes = "Tidak lolos minimum achievement ({$achievementPercent}% < {$minAchievementPct}%)";
                } elseif (!$matchedGrade) {
                    $auditNotes = "Target {$targetQuota} tidak masuk range Grade manapun";
                } elseif ($isRateBased) {
                    $grossReward = $volumeForPayoutKg * $unitRate;
                    $finalReward = round($grossReward * ($headerBobotPct / 100.0), 2);
                    $auditNotes = 'Lolos - Pengali Tanpa Cap';
                } else {
                    $grossReward = $lumpSumNominal;
                    $finalReward = round($grossReward * ($headerBobotPct / 100.0), 2);
                    $auditNotes = 'Lolos - Flat Nominal';
                }

                $userTotalReward += $finalReward;

                $headerRecords[] = [
                    'target_header_id' => $header->id,
                    'grade_id' => $matchedGrade?->id,
                    'grade_bobot_id' => $matchedBobot?->id,
                    'target_quota' => $targetQuota,
                    'realization' => $realizationValue,
                    'noo_volume_kg' => $isNooMethod ? round($actualNooKg, 2) : null,
                    'achievement_percent' => $achievementPercent,
                    'min_achievement_pct' => $minAchievementPct,
                    'is_passed' => $isPassed,
                    'capped_realization' => $volumeForPayoutKg,
                    'is_rate_based' => $isRateBased,
                    'unit_rate' => $unitRate,
                    'lump_sum_nominal' => $lumpSumNominal,
                    'header_bobot_percent' => $headerBobotPct,
                    'final_reward' => $finalReward,
                    'audit_notes' => $auditNotes,
                ];

                $methodPayload = [
                    'target_header_id' => $header->id,
                    'header_name' => $header->nama,
                    'method' => $methodKey,
                    'target_quota' => round($targetQuota, 2),
                    'actual_realization' => round($realizationValue, 2),
                    'actual_volume_kg' => round($volumeForPayoutKg, 2),
                    'achievement_percent' => $achievementPercent,
                    'min_achievement_pct' => $minAchievementPct,
                    'is_passed' => $isPassed,
                    'grade_id' => $matchedGrade?->id,
                    'grade_name' => $matchedGrade?->grade_name,
                    'multiplier_rate' => $unitRate,
                    'header_weight_pct' => $headerBobotPct,
                    'gross_reward' => round($grossReward, 2),
                    'final_reward' => $finalReward,
                    'audit_notes' => $auditNotes,
                ];

                if ($isNooMethod) {
                    $nooBreakdown = $methodPayload;
                    $summaryTargetNoo += $targetQuota;
                } else {
                    $sellInBreakdown = $methodPayload;
                    $summaryTargetSellInKg += $targetQuota;
                }
            }

            $summaryActualSellInKg += $actualSellInKg;
            $summaryActualNoo += $actualNooCount;
            $summaryActualNooKg += $actualNooKg;
            $summaryTotalPayout += $userTotalReward;

            $cards[] = [
                'user_id' => $user->id,
                'user_name' => $user->name,
                'username' => $user->username,
                'position_id' => $user->position_id,
                'position_code' => $posCode,
                'position_name' => $user->position?->name ?? '-',
                'is_eligible_industri' => true,
                'period' => $cleanPeriod,
                'ineligibility_reason' => null,
                'sell_in' => $sellInBreakdown,
                'noo' => $nooBreakdown,
                'customers' => $customerAuditList,
                'assigned_customers_count' => $assignedCustomers->count(),
                'actual_sell_in_kg' => round($actualSellInKg, 2),
                'actual_noo_count' => $actualNooCount,
                'actual_noo_kg' => round($actualNooKg, 2),
                'total_reward' => round($userTotalReward, 2),
                'header_records' => $headerRecords,
            ];
        }

        return [
            'meta' => [
                'kategori_skema' => 'INDUSTRI',
                'period' => $cleanPeriod,
                'total_personil' => collect($cards)->where('is_eligible_industri', true)->count(),
                'total_cards' => count($cards),
                'total_target_sell_in_kg' => round($summaryTargetSellInKg, 2),
                'total_actual_sell_in_kg' => round($summaryActualSellInKg, 2),
                'total_target_noo' => round($summaryTargetNoo, 2),
                'total_actual_noo' => round($summaryActualNoo, 2),
                'total_actual_noo_kg' => round($summaryActualNooKg, 2),
                'total_payout' => round($summaryTotalPayout, 2),
            ],
            'cards' => $cards,
        ];
    }

    /**
     * Eksekusi dan simpan kalkulasi Insentif Sales Surabaya sesuai spesifikasi resmi:
     * - Mendukung posisi SM (Sales Motoris), TO (Sales Taking Order), dan ASC (Area Sales Coordinator).
     * - Tidak ada NOO: hanya penjualan langsung dalam satuan Kg.
     * - TO & SM: individu (Actual Kg >= Min Ach % -> Grade match Target Kg -> Actual Kg * Rate * Bobot Header %).
     * - ASC: evaluasi per bawahan (TO & SM); tiap bawahan yang lolos Min Ach ASC dicocokkan ke Grade ASC.
     */
    public function executeSurabaya(
        string $period,
        int $authUserId,
        ?int $positionId = null,
        ?int $userId = null
    ): Collection {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);

        IncentiveCalculation::where('kategori_skema', 'SURABAYA')
            ->where('period', $cleanPeriod)
            ->when($userId, fn ($q) => $q->where('user_id', $userId))
            ->when(!$userId && $positionId, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('position_id', $positionId)))
            ->delete();

        $evaluated = $this->evaluateSurabayaForPeriod($cleanPeriod, $positionId, $userId, null, false);
        $results = collect();

        foreach ($evaluated['cards'] as $card) {
            if (!$card['is_eligible_surabaya']) {
                continue;
            }

            foreach ($card['header_records'] as $rec) {
                $calculation = IncentiveCalculation::create([
                    'user_id' => $card['user_id'],
                    'kategori_skema' => 'SURABAYA',
                    'target_header_id' => $rec['target_header_id'],
                    'grade_id' => $rec['grade_id'],
                    'grade_bobot_id' => $rec['grade_bobot_id'],
                    'period' => $cleanPeriod,
                    'target_quota' => $rec['target_quota'],
                    'realization' => $rec['realization'],
                    'noo_volume_kg' => null,
                    'achievement_percent' => $rec['achievement_percent'],
                    'min_achievement_pct' => $rec['min_achievement_pct'],
                    'is_passed' => $rec['is_passed'],
                    'capped_realization' => $rec['capped_realization'],
                    'is_rate_based' => $rec['is_rate_based'],
                    'unit_rate' => $rec['unit_rate'],
                    'lump_sum_nominal' => $rec['lump_sum_nominal'],
                    'header_bobot_percent' => $rec['header_bobot_percent'],
                    'final_reward' => $rec['final_reward'],
                    'audit_notes' => $rec['audit_notes'],
                    'calculated_by' => $authUserId,
                ]);

                $results->push($calculation->load(['user.position', 'targetHeader', 'grade', 'gradeBobot']));
            }
        }

        return $results;
    }

    /**
     * Evaluasi penuh skema Sales Surabaya (TO, SM, dan ASC beserta breakdown per bawahan).
     */
    public function evaluateSurabayaForPeriod(
        string $period,
        ?int $positionId = null,
        ?int $userId = null,
        ?string $search = null,
        bool $includeIneligibleIfFiltered = false
    ): array {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);
        $year = substr($cleanPeriod, 0, 4);
        $month = substr($cleanPeriod, 4, 2);

        $startDate = Carbon::createFromDate((int) $year, (int) $month, 1)->startOfMonth()->format('Y-m-d');
        $endDate = Carbon::createFromDate((int) $year, (int) $month, 1)->endOfMonth()->format('Y-m-d');
        $periodYmdStart = $year.$month.'01';
        $periodYmdEnd = $year.$month.'31';

        $usersQuery = User::with('position')
            ->whereNotNull('position_id')
            ->where(function ($q) use ($endDate) {
                $q->whereNull('aktif_from')->orWhere('aktif_from', '<=', $endDate);
            })
            ->where(function ($q) use ($startDate) {
                $q->whereNull('aktif_to')->orWhere('aktif_to', '>=', $startDate);
            })
            ->when($positionId, fn ($q) => $q->where('position_id', $positionId))
            ->when($userId, fn ($q) => $q->where('id', $userId))
            ->when($search, function ($q) use ($search) {
                $term = strtolower(trim($search));
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(name) like ?', ["%{$term}%"])
                        ->orWhereRaw('LOWER(username) like ?', ["%{$term}%"]);
                });
            })
            ->orderBy('name');

        if (!($includeIneligibleIfFiltered && $userId !== null)) {
            $usersQuery->where('is_eligible_surabaya', true);
        }

        $users = $usersQuery->get();

        $activeHeaders = TargetHeader::where('kategori_skema', 'SURABAYA')
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
            ->get()
            ->groupBy('sales_type');

        $allTargets = MasterTarget::where('kategori_skema', 'SURABAYA')
            ->where('period', $cleanPeriod)
            ->get()
            ->groupBy('user_id');

        $allSellouts = SelloutSalesSurabaya::where('period', $cleanPeriod)
            ->get()
            ->groupBy('sales_id');

        $allAssignments = SalesSurabayaAssignment::with(['coordinator.position', 'sales.position'])
            ->where('is_active', true)
            ->where(function ($q) use ($cleanPeriod) {
                $q->where('period', $cleanPeriod)
                    ->orWhereNull('period')
                    ->orWhere('period', '');
            })
            ->get();

        $assignmentsByCoordinator = $allAssignments->groupBy('coordinator_id');
        $assignmentsBySales = $allAssignments->keyBy('sales_id');

        $cards = [];
        $summaryTargetKg = 0.0;
        $summaryActualKg = 0.0;
        $summaryTotalPayout = 0.0;

        foreach ($users as $user) {
            $posCode = strtoupper($user->position?->code ?? '');

            if (!$user->is_eligible_surabaya) {
                $cards[] = [
                    'user_id' => $user->id,
                    'user_name' => $user->name,
                    'username' => $user->username,
                    'position_id' => $user->position_id,
                    'position_code' => $posCode,
                    'position_name' => $user->position?->name ?? '-',
                    'is_eligible_surabaya' => false,
                    'period' => $cleanPeriod,
                    'ineligibility_reason' => 'Status Is Eligible Surabaya tidak aktif — insentif otomatis Rp 0.',
                    'asc_name' => null,
                    'target_header_id' => null,
                    'header_name' => null,
                    'min_achievement_pct' => 0.0,
                    'header_weight_pct' => 0.0,
                    'target_kg' => 0.0,
                    'actual_kg' => 0.0,
                    'achievement_percent' => 0.0,
                    'is_passed' => false,
                    'grade_name' => null,
                    'multiplier_rate' => 0.0,
                    'total_reward' => 0.0,
                    'audit_notes' => 'Tidak eligible Surabaya',
                    'subordinates' => [],
                    'subordinates_count' => 0,
                    'header_records' => [],
                ];
                continue;
            }

            $header = ($activeHeaders->get($user->position_id) ?? collect())->first();
            $minAchievementPct = (float) ($header?->min_achievement_pct ?? 0);
            $headerWeightPct = (float) ($header?->bobot ?? 100);

            if ($posCode === 'ASC') {
                $subAssignments = ($assignmentsByCoordinator->get($user->id) ?? collect())
                    ->filter(function ($a) use ($endDate, $startDate) {
                        $sub = $a->sales;
                        if (!$sub || !$sub->position) {
                            return false;
                        }
                        $subPos = strtoupper($sub->position->code);
                        if (!in_array($subPos, ['TO', 'SM'], true)) {
                            return false;
                        }
                        if ($sub->aktif_from && $sub->aktif_from > $endDate) {
                            return false;
                        }
                        if ($sub->aktif_to && $sub->aktif_to < $startDate) {
                            return false;
                        }
                        return true;
                    })
                    ->unique('sales_id')
                    ->values();

                $subordinates = [];
                $ascTotalReward = 0.0;
                $ascTotalSubTargetKg = 0.0;
                $ascTotalSubActualKg = 0.0;
                $passedCount = 0;

                foreach ($subAssignments as $assign) {
                    $subUser = $assign->sales;
                    $subPosCode = strtoupper($subUser->position?->code ?? '-');
                    $subTargetKg = (float) ($allTargets->get($subUser->id) ?? collect())->sum('target_quota');
                    $subActualKg = (float) ($allSellouts->get($subUser->id) ?? collect())->sum('volume');
                    $subRawAch = $subTargetKg > 0 ? ($subActualKg / $subTargetKg) * 100.0 : 0.0;
                    $subAchPct = round($subRawAch, 2);
                    $subPassed = $subTargetKg > 0 && $subRawAch >= $minAchievementPct;

                    $matchedGrade = null;
                    $rate = 0.0;
                    $isRateBased = true;
                    $lumpSumNominal = 0.0;
                    $matchedBobot = null;
                    $subReward = 0.0;
                    $subNotes = null;

                    if (!$header) {
                        $subNotes = 'Header setting ASC Surabaya belum aktif';
                    } elseif ($subTargetKg <= 0) {
                        $subNotes = 'Target bawahan belum diset (Target = 0)';
                    } elseif (!$subPassed) {
                        $subNotes = "Tidak lolos minimum achievement ({$subAchPct}% < {$minAchievementPct}%)";
                    } else {
                        $matchedGrade = $header->grades
                            ->sortBy(fn ($g) => (float) $g->target_from)
                            ->first(fn ($g) => $subTargetKg >= (float) $g->target_from && $subTargetKg <= (float) $g->target_to);

                        if (!$matchedGrade) {
                            $subNotes = "Target {$subTargetKg} Kg tidak masuk range Grade ASC";
                        } else {
                            [$rate, $isRateBased, $lumpSumNominal, $matchedBobot] = $this->resolveSurabayaRateForGrade($matchedGrade, $subRawAch);
                            if ($isRateBased) {
                                $subReward = round(($subActualKg * $rate) * ($headerWeightPct / 100.0), 2);
                                $subNotes = 'Lolos - Kontribusi ASC';
                            } else {
                                $subReward = round($lumpSumNominal * ($headerWeightPct / 100.0), 2);
                                $subNotes = 'Lolos - Flat Nominal ASC';
                            }
                            $passedCount++;
                        }
                    }

                    $ascTotalReward += $subReward;
                    $ascTotalSubTargetKg += $subTargetKg;
                    $ascTotalSubActualKg += $subActualKg;

                    $subordinates[] = [
                        'sales_id' => $subUser->id,
                        'sales_name' => $subUser->name,
                        'username' => $subUser->username,
                        'position_code' => $subPosCode,
                        'position_name' => $subUser->position?->name ?? '-',
                        'target_kg' => round($subTargetKg, 2),
                        'actual_kg' => round($subActualKg, 2),
                        'achievement_percent' => $subAchPct,
                        'is_passed' => $subPassed,
                        'status_label' => $subPassed ? 'Lolos' : 'Tidak Lolos',
                        'grade_id' => $matchedGrade?->id,
                        'grade_name' => $matchedGrade?->grade_name,
                        'multiplier_rate' => $rate,
                        'header_weight_pct' => $headerWeightPct,
                        'contribution_reward' => $subReward,
                        'audit_notes' => $subNotes,
                    ];
                }

                $ascAchPct = $ascTotalSubTargetKg > 0 ? round(($ascTotalSubActualKg / $ascTotalSubTargetKg) * 100.0, 2) : 0.0;
                $headerRecords = [];
                if ($header) {
                    $headerRecords[] = [
                        'target_header_id' => $header->id,
                        'grade_id' => null,
                        'grade_bobot_id' => null,
                        'target_quota' => round($ascTotalSubTargetKg, 2),
                        'realization' => round($ascTotalSubActualKg, 2),
                        'achievement_percent' => $ascAchPct,
                        'min_achievement_pct' => $minAchievementPct,
                        'is_passed' => $passedCount > 0,
                        'capped_realization' => round($ascTotalSubActualKg, 2),
                        'is_rate_based' => true,
                        'unit_rate' => 0.0,
                        'lump_sum_nominal' => 0.0,
                        'header_bobot_percent' => $headerWeightPct,
                        'final_reward' => round($ascTotalReward, 2),
                        'audit_notes' => "Evaluasi {$subAssignments->count()} bawahan ({$passedCount} lolos)",
                    ];
                }

                $summaryTotalPayout += $ascTotalReward;

                $cards[] = [
                    'user_id' => $user->id,
                    'user_name' => $user->name,
                    'username' => $user->username,
                    'position_id' => $user->position_id,
                    'position_code' => $posCode,
                    'position_name' => $user->position?->name ?? '-',
                    'is_eligible_surabaya' => true,
                    'period' => $cleanPeriod,
                    'ineligibility_reason' => null,
                    'asc_name' => null,
                    'target_header_id' => $header?->id,
                    'header_name' => $header?->nama ?? 'Belum ada Setting Header ASC',
                    'min_achievement_pct' => $minAchievementPct,
                    'header_weight_pct' => $headerWeightPct,
                    'target_kg' => round($ascTotalSubTargetKg, 2),
                    'actual_kg' => round($ascTotalSubActualKg, 2),
                    'achievement_percent' => $ascAchPct,
                    'is_passed' => $passedCount > 0,
                    'grade_name' => null,
                    'multiplier_rate' => 0.0,
                    'total_reward' => round($ascTotalReward, 2),
                    'audit_notes' => $header
                        ? "Evaluasi {$subAssignments->count()} bawahan ({$passedCount} lolos)"
                        : 'Setting Header ASC (SURABAYA) belum dikonfigurasi',
                    'subordinates' => $subordinates,
                    'subordinates_count' => count($subordinates),
                    'header_records' => $headerRecords,
                ];
                continue;
            }

            // Individu: TO (Sales Taking Order) & SM (Sales Motoris)
            $targetKg = (float) ($allTargets->get($user->id) ?? collect())->sum('target_quota');
            $actualKg = (float) ($allSellouts->get($user->id) ?? collect())->sum('volume');
            $rawAch = $targetKg > 0 ? ($actualKg / $targetKg) * 100.0 : 0.0;
            $achPct = round($rawAch, 2);
            $isPassed = $header !== null && $targetKg > 0 && $rawAch >= $minAchievementPct;
            $ascName = $assignmentsBySales->get($user->id)?->coordinator?->name;

            $matchedGrade = null;
            $rate = 0.0;
            $isRateBased = true;
            $lumpSumNominal = 0.0;
            $matchedBobot = null;
            $finalReward = 0.0;
            $auditNotes = null;

            if (!$header) {
                $auditNotes = "Setting Header {$posCode} (SURABAYA) belum dikonfigurasi";
            } elseif ($targetKg <= 0) {
                $auditNotes = 'Target belum diset (Target = 0)';
            } elseif (!$isPassed) {
                $auditNotes = "Tidak lolos minimum achievement ({$achPct}% < {$minAchievementPct}%)";
            } else {
                $matchedGrade = $header->grades
                    ->sortBy(fn ($g) => (float) $g->target_from)
                    ->first(fn ($g) => $targetKg >= (float) $g->target_from && $targetKg <= (float) $g->target_to);

                if (!$matchedGrade) {
                    $auditNotes = "Target {$targetKg} Kg tidak masuk range Grade {$posCode}";
                } else {
                    [$rate, $isRateBased, $lumpSumNominal, $matchedBobot] = $this->resolveSurabayaRateForGrade($matchedGrade, $rawAch);
                    if ($isRateBased) {
                        $finalReward = round(($actualKg * $rate) * ($headerWeightPct / 100.0), 2);
                        $auditNotes = 'Lolos - Pengali Penjualan Langsung';
                    } else {
                        $finalReward = round($lumpSumNominal * ($headerWeightPct / 100.0), 2);
                        $auditNotes = 'Lolos - Flat Nominal';
                    }
                }
            }

            $headerRecords = [];
            if ($header) {
                $headerRecords[] = [
                    'target_header_id' => $header->id,
                    'grade_id' => $matchedGrade?->id,
                    'grade_bobot_id' => $matchedBobot?->id,
                    'target_quota' => round($targetKg, 2),
                    'realization' => round($actualKg, 2),
                    'achievement_percent' => $achPct,
                    'min_achievement_pct' => $minAchievementPct,
                    'is_passed' => $isPassed,
                    'capped_realization' => round($actualKg, 2),
                    'is_rate_based' => $isRateBased,
                    'unit_rate' => $rate,
                    'lump_sum_nominal' => $lumpSumNominal,
                    'header_bobot_percent' => $headerWeightPct,
                    'final_reward' => $finalReward,
                    'audit_notes' => $auditNotes,
                ];
            }

            $summaryTargetKg += $targetKg;
            $summaryActualKg += $actualKg;
            $summaryTotalPayout += $finalReward;

            $cards[] = [
                'user_id' => $user->id,
                'user_name' => $user->name,
                'username' => $user->username,
                'position_id' => $user->position_id,
                'position_code' => $posCode,
                'position_name' => $user->position?->name ?? '-',
                'is_eligible_surabaya' => true,
                'period' => $cleanPeriod,
                'ineligibility_reason' => null,
                'asc_name' => $ascName,
                'target_header_id' => $header?->id,
                'header_name' => $header?->nama ?? "Belum ada Setting Header {$posCode}",
                'min_achievement_pct' => $minAchievementPct,
                'header_weight_pct' => $headerWeightPct,
                'target_kg' => round($targetKg, 2),
                'actual_kg' => round($actualKg, 2),
                'achievement_percent' => $achPct,
                'is_passed' => $isPassed,
                'grade_name' => $matchedGrade?->grade_name,
                'multiplier_rate' => $rate,
                'total_reward' => $finalReward,
                'audit_notes' => $auditNotes,
                'subordinates' => [],
                'subordinates_count' => 0,
                'header_records' => $headerRecords,
            ];
        }

        // Jika filter hanya menampilkan ASC, pakai total target/aktual dari bawahan agar KPI tidak 0
        if ($summaryTargetKg <= 0 && count($cards) > 0) {
            $summaryTargetKg = (float) collect($cards)->sum('target_kg');
            $summaryActualKg = (float) collect($cards)->sum('actual_kg');
        }

        return [
            'meta' => [
                'kategori_skema' => 'SURABAYA',
                'period' => $cleanPeriod,
                'total_personil' => collect($cards)->where('is_eligible_surabaya', true)->count(),
                'total_cards' => count($cards),
                'total_target_kg' => round($summaryTargetKg, 2),
                'total_actual_kg' => round($summaryActualKg, 2),
                'total_payout' => round($summaryTotalPayout, 2),
            ],
            'cards' => $cards,
        ];
    }

    /**
     * Resolve tarif pengali/nominal untuk Grade Surabaya (mendukung multiplier_rate desimal maupun GradeBobot fallback).
     */
    private function resolveSurabayaRateForGrade($matchedGrade, float $rawAch): array
    {
        if ($matchedGrade->multiplier_rate !== null && (float) $matchedGrade->multiplier_rate > 0) {
            return [(float) $matchedGrade->multiplier_rate, true, 0.0, null];
        }

        if ($matchedGrade->bobots->isNotEmpty()) {
            $matchedBobot = $matchedGrade->bobots->first(
                fn ($b) => $rawAch >= (float) $b->percent_from && $rawAch <= (float) $b->percent_to
            );
            if (!$matchedBobot) {
                $matchedBobot = $matchedGrade->bobots
                    ->filter(fn ($b) => $rawAch >= (float) $b->percent_from)
                    ->sortByDesc(fn ($b) => (float) $b->percent_from)
                    ->first();
            }
            if ($matchedBobot) {
                if ($matchedBobot->pengali) {
                    return [(float) $matchedBobot->bobot, true, 0.0, $matchedBobot];
                }
                return [0.0, false, (float) $matchedBobot->nominal, $matchedBobot];
            }
        }

        return [0.0, true, 0.0, null];
    }
}

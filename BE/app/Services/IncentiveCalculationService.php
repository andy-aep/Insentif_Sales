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
    public function execute(string $kategoriSkema, string $period, int $authUserId): Collection
    {
        $cleanPeriod = preg_replace('/[^0-9]/', '', $period);
        $year = substr($cleanPeriod, 0, 4);
        $month = substr($cleanPeriod, 4, 2);

        $startDate = Carbon::createFromDate((int) $year, (int) $month, 1)->startOfMonth()->format('Y-m-d');
        $endDate = Carbon::createFromDate((int) $year, (int) $month, 1)->endOfMonth()->format('Y-m-d');

        $periodYmdStart = $year.$month.'01';
        $periodYmdEnd = $year.$month.'31';

        // 1. Ambil seluruh personil aktif sesuai eligibility flag
        $eligibleUsers = User::where('aktif_from', '<=', $endDate)
            ->where(function ($q) use ($startDate) {
                $q->whereNull('aktif_to')
                    ->orWhere('aktif_to', '>=', $startDate);
            })
            ->when($kategoriSkema === 'KONSUMSI', fn ($q) => $q->where('is_eligible_konsumsi', true))
            ->when($kategoriSkema === 'INDUSTRI', fn ($q) => $q->where('is_eligible_industri', true))
            ->when($kategoriSkema === 'SURABAYA', fn ($q) => $q->where('is_eligible_surabaya', true))
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
                // 3. Ambil target kuota sales (bisa per brand dijumlahkan atau per depo/area)
                $targetQuery = MasterTarget::where('kategori_skema', $kategoriSkema)
                    ->where('metrik_target', $header->type)
                    ->where('period', $cleanPeriod);

                $directTargets = (clone $targetQuery)->where('user_id', $user->id)->get();
                $targetQuota = (float) $directTargets->sum('target_quota');

                if ($targetQuota <= 0 && $kategoriSkema === 'KONSUMSI') {
                    $posCode = strtoupper($user->position?->code ?? '');
                    $assignments = SalesDistributorAssignment::where('user_id', $user->id)
                        ->where('is_active', true)
                        ->where('period', $cleanPeriod)
                        ->get();

                    if ($posCode === 'SPV') {
                        $areaIds = $assignments->pluck('area_id')->filter()->unique();
                        $targetQuota = (float) (clone $targetQuery)->whereIn('area_id', $areaIds)->sum('target_quota');
                    } elseif ($posCode === 'ASM') {
                        $distIds = $assignments->pluck('distributor_id')->filter()->unique();
                        $targetQuota = (float) (clone $targetQuery)
                            ->whereIn('distributor_id', $distIds)
                            ->where(fn ($q) => $q->where('level', 'DEPO')->orWhereNull('level'))
                            ->sum('target_quota');
                        if ($targetQuota <= 0) {
                            $targetQuota = (float) (clone $targetQuery)->whereIn('distributor_id', $distIds)->sum('target_quota');
                        }
                    }
                }

                if ($targetQuota <= 0) {
                    continue;
                }
                $realization = (float) $this->resolveRealization($user, $header, $cleanPeriod);

                // 4. Evaluasi Grade (Level 2)
                $matchedGrade = $header->grades->first(function ($grade) use ($targetQuota) {
                    return $targetQuota >= (float) $grade->target_from && $targetQuota <= (float) $grade->target_to;
                });

                if (! $matchedGrade) {
                    continue;
                }

                // 5. Evaluasi Persentase Pencapaian & Grade Bobot (Level 3)
                $achievementPercent = ($realization / $targetQuota) * 100.0;

                $matchedBobot = $matchedGrade->bobots->first(function ($tier) use ($achievementPercent) {
                    return $achievementPercent >= (float) $tier->percent_from && $achievementPercent <= (float) $tier->percent_to;
                });

                if (! $matchedBobot) {
                    continue;
                }

                // 6. Hitung Nominal Reward
                $headerBobotFactor = (float) $header->bobot / 100.0;
                $cappedRealization = $realization;

                if ($matchedBobot->pengali) {
                    // Model Rate-based dengan pembatasan volume (Cap)
                    $capThreshold = $targetQuota * ((float) $matchedBobot->percent_to / 100.0);
                    $cappedRealization = min($realization, $capThreshold);
                    $totalReward = (float) $matchedBobot->bobot * $cappedRealization * $headerBobotFactor;
                } else {
                    // Model Nominal Flat (Lump-sum)
                    $totalReward = (float) $matchedBobot->nominal * $headerBobotFactor;
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
                        'grade_bobot_id' => $matchedBobot->id,
                        'target_quota' => $targetQuota,
                        'realization' => $realization,
                        'achievement_percent' => $achievementPercent,
                        'capped_realization' => $cappedRealization,
                        'is_rate_based' => $matchedBobot->pengali,
                        'unit_rate' => $matchedBobot->bobot,
                        'lump_sum_nominal' => $matchedBobot->nominal,
                        'header_bobot_percent' => $header->bobot,
                        'final_reward' => $totalReward,
                        'calculated_by' => $authUserId,
                    ]
                );

                $results->push($calc->load(['user', 'targetHeader', 'grade', 'gradeBobot']));
            }
        }

        return $results;
    }

    protected function resolveRealization(User $user, TargetHeader $header, string $period): float
    {
        $metricType = strtoupper($header->type);

        if ($header->kategori_skema === 'KONSUMSI') {
            $assignments = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('is_active', true)
                ->where('period', $period)
                ->get();

            if ($assignments->isNotEmpty()) {
                $posCode = strtoupper($user->position?->code ?? '');
                if ($posCode === 'NSM') {
                    // Cek apakah NSM ini memimpin LSM-LSM tertentu
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
                        // NSM Teritorial (misal: Indonesia Timur, Indonesia Barat, dll):
                        // Realisasi dihitung dari seluruh distributor di wilayah region LSM yang dipimpinnya
                        $distributorIds = Distributor::whereIn('region_id', $assignedRegionIds)->pluck('id');

                        if (str_contains($metricType, 'OUT')) {
                            $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                            return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                        } else {
                            return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                        }
                    }

                    // NSM Nasional Penuh: mencakup seluruh distributor nasional
                    return str_contains($metricType, 'OUT')
                        ? (float) SelloutDistributor::where('period', $period)->sum('volume_kg')
                        : (float) SellinDistributor::where('period', $period)->sum('volume_kg');
                } elseif ($posCode === 'LSM') {
                    // LSM memegang Region tertentu
                    $regionIds = $assignments->pluck('region_id')->filter()->unique();
                    $distributorIds = Distributor::whereIn('region_id', $regionIds)->pluck('id');
                    if (str_contains($metricType, 'OUT')) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                } elseif ($posCode === 'ASM') {
                    $distributorIds = $assignments->pluck('distributor_id')->filter()->unique();
                    if (str_contains($metricType, 'OUT')) {
                        $depoIds = Depo::whereIn('distributor_id', $distributorIds)->pluck('id');
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                } elseif ($posCode === 'SPV') {
                    $depoIds = $assignments->pluck('depo_id')->filter()->unique();
                    if (str_contains($metricType, 'OUT')) {
                        return (float) SelloutDistributor::whereIn('depo_id', $depoIds)->where('period', $period)->sum('volume_kg');
                    } else {
                        $distributorIds = $assignments->pluck('distributor_id')->filter()->unique();
                        return (float) SellinDistributor::whereIn('distributor_id', $distributorIds)->where('period', $period)->sum('volume_kg');
                    }
                }
            }

            return str_contains($metricType, 'OUT')
                ? (float) SelloutDistributor::where('period', $period)->sum('volume_kg')
                : (float) SellinDistributor::where('period', $period)->sum('volume_kg');
        }

        return match ($header->kategori_skema) {
            'INDUSTRI' => (float) SellinIndustri::where('user_id', $user->id)
                ->where('period', $period)
                ->sum('tonase'),
            'SURABAYA' => str_contains($metricType, 'AO') || str_contains($metricType, 'OUTLET')
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

<?php

namespace App\Exports;

use App\Models\IncentiveCalculation;
use Illuminate\Support\Enumerable;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;

class IncentiveCalculationExport implements FromCollection, WithHeadings, WithMapping
{
    public function __construct(
        protected ?string $kategoriSkema = null,
        protected ?string $period = null
    ) {}

    public function collection(): Enumerable
    {
        return IncentiveCalculation::with(['user.position', 'targetHeader', 'grade', 'gradeBobot', 'calculatedBy'])
            ->when($this->kategoriSkema, fn ($q) => $q->where('kategori_skema', $this->kategoriSkema))
            ->when($this->period, fn ($q) => $q->where('period', $this->period))
            ->get();
    }

    public function headings(): array
    {
        return [
            'ID',
            'Sales Name',
            'Username',
            'Position',
            'Kategori Skema',
            'Target Header',
            'Grade',
            'Tier Bobot',
            'Periode',
            'Target Quota',
            'Realisasi',
            'Pencapaian (%)',
            'Capped Realisasi',
            'Tipe Perhitungan',
            'Rate / Unit',
            'Lump Sum Nominal',
            'Header Bobot (%)',
            'Final Reward (Rp)',
            'Dihitung Oleh',
            'Waktu Perhitungan',
        ];
    }

    /**
     * @param  IncentiveCalculation  $calculation
     */
    public function map($calculation): array
    {
        return [
            $calculation->id,
            $calculation->user?->name ?? '-',
            $calculation->user?->username ?? '-',
            $calculation->user?->position?->name ?? '-',
            $calculation->kategori_skema,
            $calculation->targetHeader?->nama ?? '-',
            $calculation->grade?->grade_name ?? '-',
            $calculation->gradeBobot?->bobot_name ?? '-',
            $calculation->period,
            $calculation->target_quota,
            $calculation->realization,
            $calculation->achievement_percent.'%',
            $calculation->capped_realization,
            $calculation->is_rate_based ? 'Rate-based' : 'Flat Nominal',
            $calculation->unit_rate,
            $calculation->lump_sum_nominal,
            $calculation->header_bobot_percent.'%',
            $calculation->final_reward,
            $calculation->calculatedBy?->name ?? '-',
            $calculation->created_at?->format('Y-m-d H:i:s'),
        ];
    }
}

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
        protected ?string $period = null,
        protected ?int $positionId = null,
        protected ?int $userId = null
    ) {}

    public function collection(): Enumerable
    {
        return IncentiveCalculation::with(['user.position', 'targetHeader', 'grade', 'gradeBobot', 'calculatedBy'])
            ->when($this->kategoriSkema, fn ($q) => $q->where('kategori_skema', $this->kategoriSkema))
            ->when($this->period, fn ($q) => $q->where('period', $this->period))
            ->when($this->positionId, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('position_id', $this->positionId)))
            ->when($this->userId, fn ($q) => $q->where('user_id', $this->userId))
            ->orderBy('user_id')
            ->orderBy('target_header_id')
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
            'NOO Volume (Kg)',
            'Pencapaian (%)',
            'Min Achievement (%)',
            'Status Threshold',
            'Volume Pengali (Kg)',
            'Tipe Perhitungan',
            'Rate / Unit',
            'Lump Sum Nominal',
            'Header Bobot (%)',
            'Final Reward (Rp)',
            'Catatan Audit',
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
            $calculation->noo_volume_kg,
            $calculation->achievement_percent.'%',
            ($calculation->min_achievement_pct ?? 0).'%',
            $calculation->is_passed ? 'LOLOS' : 'TIDAK LOLOS',
            $calculation->capped_realization,
            $calculation->is_rate_based ? 'Rate-based' : 'Flat Nominal',
            $calculation->unit_rate,
            $calculation->lump_sum_nominal,
            $calculation->header_bobot_percent.'%',
            $calculation->final_reward,
            $calculation->audit_notes ?? '-',
            $calculation->calculatedBy?->name ?? '-',
            $calculation->created_at?->format('Y-m-d H:i:s'),
        ];
    }
}

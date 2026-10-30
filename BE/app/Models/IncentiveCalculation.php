<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IncentiveCalculation extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'kategori_skema',
        'target_header_id',
        'grade_id',
        'grade_bobot_id',
        'period',
        'target_quota',
        'realization',
        'achievement_percent',
        'capped_realization',
        'is_rate_based',
        'unit_rate',
        'lump_sum_nominal',
        'header_bobot_percent',
        'final_reward',
        'calculated_by',
    ];

    protected function casts(): array
    {
        return [
            'target_quota' => 'decimal:2',
            'realization' => 'decimal:2',
            'achievement_percent' => 'decimal:2',
            'capped_realization' => 'decimal:2',
            'is_rate_based' => 'boolean',
            'unit_rate' => 'decimal:2',
            'lump_sum_nominal' => 'decimal:2',
            'header_bobot_percent' => 'decimal:2',
            'final_reward' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function targetHeader(): BelongsTo
    {
        return $this->belongsTo(TargetHeader::class);
    }

    public function grade(): BelongsTo
    {
        return $this->belongsTo(Grade::class);
    }

    public function gradeBobot(): BelongsTo
    {
        return $this->belongsTo(GradeBobot::class);
    }

    public function calculatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'calculated_by');
    }
}

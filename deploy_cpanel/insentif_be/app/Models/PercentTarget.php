<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PercentTarget extends Model
{
    use HasFactory;

    protected $fillable = [
        'kategori_skema',
        'metrik_target',
        'percent_min',
        'percent_max',
        'performance_status',
        'badge_color',
        'is_eligible_payout',
    ];

    protected function casts(): array
    {
        return [
            'percent_min' => 'decimal:2',
            'percent_max' => 'decimal:2',
            'is_eligible_payout' => 'boolean',
        ];
    }
}

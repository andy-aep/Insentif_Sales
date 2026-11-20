<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class NilaiReward extends Model
{
    use HasFactory;

    protected $fillable = [
        'kategori_skema',
        'metrik_target',
        'kategori_grade',
        'standard_rate',
        'standard_nominal',
    ];

    protected function casts(): array
    {
        return [
            'standard_rate' => 'decimal:2',
            'standard_nominal' => 'decimal:2',
        ];
    }
}

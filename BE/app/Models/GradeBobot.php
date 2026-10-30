<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GradeBobot extends Model
{
    use HasFactory;

    protected $fillable = [
        'id_grade',
        'bobot_name',
        'percent_from',
        'percent_to',
        'pengali',
        'bobot',
        'nominal',
    ];

    protected function casts(): array
    {
        return [
            'pengali' => 'boolean',
            'bobot' => 'decimal:2',
            'nominal' => 'decimal:2',
            'percent_from' => 'decimal:2',
            'percent_to' => 'decimal:2',
        ];
    }

    public function grade(): BelongsTo
    {
        return $this->belongsTo(Grade::class, 'id_grade', 'id_grade');
    }

    public function incentiveCalculations(): HasMany
    {
        return $this->hasMany(IncentiveCalculation::class);
    }
}

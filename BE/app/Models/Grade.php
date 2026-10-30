<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Grade extends Model
{
    use HasFactory;

    protected $fillable = [
        'id_grade',
        'target_header_id',
        'grade_name',
        'target_from',
        'target_to',
    ];

    protected function casts(): array
    {
        return [
            'target_from' => 'decimal:2',
            'target_to' => 'decimal:2',
        ];
    }

    public function targetHeader(): BelongsTo
    {
        return $this->belongsTo(TargetHeader::class, 'target_header_id');
    }

    public function bobots(): HasMany
    {
        return $this->hasMany(GradeBobot::class, 'id_grade', 'id_grade');
    }

    public function incentiveCalculations(): HasMany
    {
        return $this->hasMany(IncentiveCalculation::class);
    }
}

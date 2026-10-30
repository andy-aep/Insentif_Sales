<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TargetHeader extends Model
{
    use HasFactory;

    protected $fillable = [
        'nama',
        'kategori_skema',
        'sales_type',
        'type',
        'bobot',
        'aktif',
        'aktif_from',
        'aktif_to',
    ];

    protected function casts(): array
    {
        return [
            'bobot' => 'decimal:2',
            'aktif' => 'boolean',
        ];
    }

    public function position(): BelongsTo
    {
        return $this->belongsTo(Position::class, 'sales_type');
    }

    public function grades(): HasMany
    {
        return $this->hasMany(Grade::class, 'target_header_id');
    }

    public function incentiveCalculations(): HasMany
    {
        return $this->hasMany(IncentiveCalculation::class);
    }
}

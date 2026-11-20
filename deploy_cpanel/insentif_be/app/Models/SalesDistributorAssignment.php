<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SalesDistributorAssignment extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'nsm_id',
        'lsm_id',
        'asm_id',
        'region_id',
        'distributor_id',
        'depo_id',
        'area_id',
        'period',
        'is_active',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function nsm(): BelongsTo
    {
        return $this->belongsTo(User::class, 'nsm_id');
    }

    public function lsm(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lsm_id');
    }

    public function asm(): BelongsTo
    {
        return $this->belongsTo(User::class, 'asm_id');
    }

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class, 'region_id');
    }

    public function distributor(): BelongsTo
    {
        return $this->belongsTo(Distributor::class, 'distributor_id');
    }

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class, 'depo_id');
    }

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    public function subordinateLsms(): HasMany
    {
        return $this->hasMany(SalesDistributorAssignment::class, 'nsm_id', 'user_id');
    }
}

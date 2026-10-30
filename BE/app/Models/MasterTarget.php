<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MasterTarget extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'distributor_id',
        'depo_id',
        'area_id',
        'brand_id',
        'level',
        'kategori_skema',
        'metrik_target',
        'period',
        'target_quota',
        'target_outlet',
    ];

    protected function casts(): array
    {
        return [
            'target_quota' => 'decimal:2',
            'target_outlet' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function distributor(): BelongsTo
    {
        return $this->belongsTo(Distributor::class);
    }

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class);
    }

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }
}

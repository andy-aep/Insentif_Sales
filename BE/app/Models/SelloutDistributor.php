<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SelloutDistributor extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'depo_id',
        'brand_id',
        'period',
        'volume_kg',
        'active_outlet_count',
    ];

    protected function casts(): array
    {
        return [
            'volume_kg' => 'decimal:2',
            'active_outlet_count' => 'integer',
        ];
    }

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(UploadBatch::class, 'batch_id', 'id');
    }
}

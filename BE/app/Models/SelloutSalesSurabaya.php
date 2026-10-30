<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SelloutSalesSurabaya extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'coordinator_id',
        'sales_id',
        'period',
        'volume',
        'active_outlet_count',
    ];

    protected function casts(): array
    {
        return [
            'volume' => 'decimal:2',
            'active_outlet_count' => 'integer',
        ];
    }

    public function coordinator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'coordinator_id');
    }

    public function sales(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sales_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(UploadBatch::class, 'batch_id', 'id');
    }
}

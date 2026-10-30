<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellinDistributor extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'distributor_id',
        'brand_id',
        'period',
        'volume_kg',
        'nominal',
        'sap_doc_no',
    ];

    protected function casts(): array
    {
        return [
            'volume_kg' => 'decimal:2',
            'nominal' => 'decimal:2',
        ];
    }

    public function distributor(): BelongsTo
    {
        return $this->belongsTo(Distributor::class);
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

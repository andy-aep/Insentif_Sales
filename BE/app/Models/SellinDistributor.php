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
        'depo_id',
        'user_id',
        'sap_slp_code',
        'sap_slp_name',
        'brand_id',
        'item_code',
        'item_name',
        'period',
        'transaction_date',
        'volume_kg',
        'nominal',
        'sap_doc_no',
    ];

    protected function casts(): array
    {
        return [
            'sap_slp_code' => 'integer',
            'transaction_date' => 'date:Y-m-d',
            'volume_kg' => 'decimal:2',
            'nominal' => 'decimal:2',
        ];
    }

    public function distributor(): BelongsTo
    {
        return $this->belongsTo(Distributor::class);
    }

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
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

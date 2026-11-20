<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellinIndustri extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'user_id',
        'industri_customer_id',
        'customer_code',
        'customer_name',
        'period',
        'tonase',
        'volume_kg',
        'nominal',
        'transaction_date',
        'is_noo',
        'sap_so_no',
    ];

    protected function casts(): array
    {
        return [
            'tonase' => 'decimal:2',
            'volume_kg' => 'decimal:2',
            'nominal' => 'decimal:2',
            'transaction_date' => 'date:Y-m-d',
            'is_noo' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function industriCustomer(): BelongsTo
    {
        return $this->belongsTo(IndustriCustomer::class, 'industri_customer_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(UploadBatch::class, 'batch_id', 'id');
    }
}

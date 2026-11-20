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
        'distributor_id',
        'depo_id',
        'area_id',
        'is_out_of_area',
        'brand_id',
        'period',
        'faktur',
        'transaction_date',
        'bulan',
        'customer_code',
        'customer_name',
        'alamat',
        'jenis_sales',
        'item_code',
        'item_name',
        'item_desc',
        'volume_kg',
        'nominal',
        'active_outlet_count',
        'kota_kab',
        'kecamatan',
        'salesman_dist',
        'pic',
        'tipe_outlet',
    ];

    protected function casts(): array
    {
        return [
            'transaction_date' => 'date:Y-m-d',
            'bulan' => 'integer',
            'volume_kg' => 'decimal:2',
            'nominal' => 'decimal:2',
            'active_outlet_count' => 'integer',
            'is_out_of_area' => 'boolean',
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

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
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

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UploadBatch extends Model
{
    use HasFactory, HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = [
        'id',
        'entity_type',
        'file_name',
        'total_rows',
        'success_rows',
        'failed_rows',
        'status',
        'uploaded_by',
        'rolled_back_at',
    ];

    protected function casts(): array
    {
        return [
            'total_rows' => 'integer',
            'success_rows' => 'integer',
            'failed_rows' => 'integer',
            'rolled_back_at' => 'datetime',
        ];
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function sellinDistributors(): HasMany
    {
        return $this->hasMany(SellinDistributor::class, 'batch_id', 'id');
    }

    public function selloutDistributors(): HasMany
    {
        return $this->hasMany(SelloutDistributor::class, 'batch_id', 'id');
    }

    public function sellinIndustris(): HasMany
    {
        return $this->hasMany(SellinIndustri::class, 'batch_id', 'id');
    }

    public function selloutSalesSurabayas(): HasMany
    {
        return $this->hasMany(SelloutSalesSurabaya::class, 'batch_id', 'id');
    }
}

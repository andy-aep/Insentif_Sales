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
        'customer_name',
        'period',
        'tonase',
        'sap_so_no',
    ];

    protected function casts(): array
    {
        return [
            'tonase' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(UploadBatch::class, 'batch_id', 'id');
    }
}

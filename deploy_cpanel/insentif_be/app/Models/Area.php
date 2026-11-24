<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Area extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'batch_id',
        'depo_id',
        'code',
        'name',
    ];

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class);
    }
}

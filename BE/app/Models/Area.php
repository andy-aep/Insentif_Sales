<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Area extends Model
{
    use HasFactory;

    protected $fillable = [
        'depo_id',
        'code',
        'name',
    ];

    public function depo(): BelongsTo
    {
        return $this->belongsTo(Depo::class);
    }
}

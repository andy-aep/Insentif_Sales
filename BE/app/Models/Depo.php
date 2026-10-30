<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Depo extends Model
{
    use HasFactory;

    protected $fillable = [
        'distributor_id',
        'code',
        'name',
    ];

    public function distributor(): BelongsTo
    {
        return $this->belongsTo(Distributor::class);
    }

    public function areas(): HasMany
    {
        return $this->hasMany(Area::class);
    }

    public function selloutDistributors(): HasMany
    {
        return $this->hasMany(SelloutDistributor::class);
    }
}

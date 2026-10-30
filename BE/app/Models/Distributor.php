<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Distributor extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'region_id',
    ];

    public function region(): BelongsTo
    {
        return $this->belongsTo(Region::class);
    }

    public function depos(): HasMany
    {
        return $this->hasMany(Depo::class);
    }

    public function sellinDistributors(): HasMany
    {
        return $this->hasMany(SellinDistributor::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(SalesDistributorAssignment::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Brand extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
    ];

    public function sellinDistributors(): HasMany
    {
        return $this->hasMany(SellinDistributor::class);
    }

    public function selloutDistributors(): HasMany
    {
        return $this->hasMany(SelloutDistributor::class);
    }
}

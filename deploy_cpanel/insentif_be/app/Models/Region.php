<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Region extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'description',
    ];

    public function distributors(): HasMany
    {
        return $this->hasMany(Distributor::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(SalesDistributorAssignment::class);
    }
}

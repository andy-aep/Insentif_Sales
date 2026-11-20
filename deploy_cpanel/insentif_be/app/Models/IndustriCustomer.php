<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class IndustriCustomer extends Model
{
    use HasFactory;

    protected $fillable = [
        'batch_id',
        'customer_code',
        'customer_name',
        'city',
        'customer_type',
        'first_transaction_period',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(SalesIndustriAssignment::class, 'industri_customer_id');
    }

    public function sellins(): HasMany
    {
        return $this->hasMany(SellinIndustri::class, 'industri_customer_id');
    }
}

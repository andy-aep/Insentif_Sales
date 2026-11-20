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

    public function items(): HasMany
    {
        return $this->hasMany(BrandItem::class)->orderBy('item_code');
    }

    public function sellinDistributors(): HasMany
    {
        return $this->hasMany(SellinDistributor::class);
    }

    public function selloutDistributors(): HasMany
    {
        return $this->hasMany(SelloutDistributor::class);
    }

    /**
     * Resolve Brand ID dari ItemCode SAP melalui tabel master brand_items.
     */
    public static function resolveIdByItemCode(?string $itemCode): ?int
    {
        $clean = strtoupper(trim((string) $itemCode));
        if ($clean === '') {
            return null;
        }

        $found = BrandItem::where('item_code', $clean)->value('brand_id');

        return $found ? (int) $found : null;
    }
}

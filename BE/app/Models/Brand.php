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
        'is_all_brands',
        'component_brand_ids',
    ];

    protected $casts = [
        'is_all_brands' => 'boolean',
        'component_brand_ids' => 'array',
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

    /**
     * Petakan setiap Brand ID ke daftar effective brand_id realisasi-nya.
     * - Jika is_all_brands === true (atau kode ALL/MIX), nilai = null (mencakup seluruh brand).
     * - Jika brand gabungan (component_brand_ids atau kode mengandung '+'), kembalikan gabungan ID dirinya + komponennya.
     * - Jika brand tunggal, kembalikan [brand_id].
     *
     * @param  iterable<int, Brand>  $brands
     * @return array<int, array<int, int>|null>
     */
    public static function buildEffectiveBrandIdsMap(iterable $brands): array
    {
        $brandList = collect($brands);
        $byToken = [];

        foreach ($brandList as $b) {
            $codeKey = strtoupper(trim((string) $b->code));
            $nameKey = strtoupper(trim((string) $b->name));
            if ($codeKey !== '') {
                $byToken[$codeKey] = (int) $b->id;
            }
            if ($nameKey !== '' && ! isset($byToken[$nameKey])) {
                $byToken[$nameKey] = (int) $b->id;
            }
        }

        $allBrandTokens = ['ALL', 'ALL_BRAND', 'ALL BRAND', 'MIX', 'SEMUA', 'SEMUA_BRAND'];
        $map = [];

        foreach ($brandList as $b) {
            $brandId = (int) $b->id;
            $codeKey = strtoupper(trim((string) $b->code));

            if ((bool) ($b->is_all_brands ?? false) || in_array($codeKey, $allBrandTokens, true)) {
                $map[$brandId] = null;
                continue;
            }

            $components = is_array($b->component_brand_ids) ? $b->component_brand_ids : [];
            $resolved = [];
            foreach ($components as $cId) {
                $intId = (int) $cId;
                if ($intId > 0) {
                    $resolved[] = $intId;
                }
            }

            if (empty($resolved) && str_contains($codeKey, '+')) {
                $parts = array_filter(array_map('trim', explode('+', $codeKey)), fn ($p) => $p !== '');
                foreach ($parts as $part) {
                    if (isset($byToken[$part])) {
                        $resolved[] = $byToken[$part];
                    }
                }
            }

            $resolved[] = $brandId;
            $map[$brandId] = array_values(array_unique($resolved));
        }

        return $map;
    }
}

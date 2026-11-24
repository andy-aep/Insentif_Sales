<?php

namespace App\Http\Controllers;

use App\Models\Brand;
use App\Models\BrandItem;
use App\Models\SellinDistributor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BrandController extends Controller
{
    public function index(): JsonResponse
    {
        $brands = Brand::with('items')->orderBy('id')->get();

        return response()->json($brands);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:brands,code',
            'name' => 'required|string|max:150',
            'item_codes' => 'nullable',
            'is_all_brands' => 'nullable|boolean',
            'component_brand_ids' => 'nullable|array',
            'component_brand_ids.*' => 'integer|exists:brands,id',
        ]);

        $upperCode = strtoupper(trim($validated['code']));
        $isAllBrands = $request->boolean('is_all_brands');
        $componentBrandIds = $this->resolveComponentBrandIds($request, $upperCode, null);
        $isComposite = $isAllBrands || ! empty($componentBrandIds);

        $itemCodes = $isComposite ? [] : $this->parseItemCodes($request->input('item_codes'));
        if (! empty($itemCodes) && ($conflict = $this->findConflictingItemCode($itemCodes, null))) {
            return response()->json([
                'message' => "ItemCode '{$conflict['item_code']}' sudah terdaftar pada Brand '{$conflict['brand_name']}'.",
            ], 422);
        }

        $brand = DB::transaction(function () use ($validated, $upperCode, $isAllBrands, $componentBrandIds, $itemCodes) {
            $brand = Brand::create([
                'code' => $upperCode,
                'name' => trim($validated['name']),
                'is_all_brands' => $isAllBrands,
                'component_brand_ids' => $isAllBrands ? [] : $componentBrandIds,
            ]);

            foreach ($itemCodes as $code) {
                BrandItem::create([
                    'brand_id' => $brand->id,
                    'item_code' => $code,
                ]);
            }

            if (! empty($itemCodes)) {
                SellinDistributor::whereIn('item_code', $itemCodes)
                    ->update(['brand_id' => $brand->id]);
            }

            return $brand->load('items');
        });

        return response()->json(['message' => 'Brand berhasil dibuat', 'data' => $brand], 201);
    }

    public function show(Brand $brand): JsonResponse
    {
        return response()->json(['data' => $brand->load('items')]);
    }

    public function update(Request $request, Brand $brand): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'sometimes|required|string|max:50|unique:brands,code,' . $brand->id,
            'name' => 'sometimes|required|string|max:150',
            'item_codes' => 'nullable',
            'is_all_brands' => 'nullable|boolean',
            'component_brand_ids' => 'nullable|array',
            'component_brand_ids.*' => 'integer|exists:brands,id',
        ]);

        $upperCode = isset($validated['code']) ? strtoupper(trim($validated['code'])) : strtoupper(trim((string) $brand->code));
        $isAllBrands = $request->has('is_all_brands') ? $request->boolean('is_all_brands') : (bool) $brand->is_all_brands;
        $hasCompositeUpdate = $request->has('is_all_brands') || $request->has('component_brand_ids');
        $componentBrandIds = $hasCompositeUpdate
            ? $this->resolveComponentBrandIds($request, $upperCode, $brand->id)
            : (is_array($brand->component_brand_ids) ? $brand->component_brand_ids : []);
        $isComposite = $isAllBrands || ! empty($componentBrandIds);

        $hasItemCodes = $request->has('item_codes') || $isComposite;
        $itemCodes = $isComposite ? [] : ($request->has('item_codes') ? $this->parseItemCodes($request->input('item_codes')) : []);

        if ($hasItemCodes && ! empty($itemCodes) && ($conflict = $this->findConflictingItemCode($itemCodes, $brand->id))) {
            return response()->json([
                'message' => "ItemCode '{$conflict['item_code']}' sudah terdaftar pada Brand '{$conflict['brand_name']}'.",
            ], 422);
        }

        $brand = DB::transaction(function () use ($brand, $validated, $upperCode, $hasCompositeUpdate, $isAllBrands, $componentBrandIds, $isComposite, $hasItemCodes, $itemCodes) {
            $updateData = [];
            if (isset($validated['code'])) {
                $updateData['code'] = $upperCode;
            }
            if (isset($validated['name'])) {
                $updateData['name'] = trim($validated['name']);
            }
            if ($hasCompositeUpdate) {
                $updateData['is_all_brands'] = $isAllBrands;
                $updateData['component_brand_ids'] = $isAllBrands ? [] : $componentBrandIds;
            }
            if (! empty($updateData)) {
                $brand->update($updateData);
            }

            if ($hasItemCodes || $isComposite) {
                BrandItem::where('brand_id', $brand->id)->delete();
                foreach ($itemCodes as $code) {
                    BrandItem::create([
                        'brand_id' => $brand->id,
                        'item_code' => $code,
                    ]);
                }
                if (! empty($itemCodes)) {
                    SellinDistributor::whereIn('item_code', $itemCodes)
                        ->update(['brand_id' => $brand->id]);
                }
            }

            return $brand->fresh()->load('items');
        });

        return response()->json(['message' => 'Brand berhasil diperbarui', 'data' => $brand]);
    }

    public function destroy(Brand $brand): JsonResponse
    {
        $brand->delete();

        return response()->json(['message' => 'Brand berhasil dihapus']);
    }

    /**
     * @return array<int, string>
     */
    private function parseItemCodes(mixed $raw): array
    {
        if (is_array($raw)) {
            $parts = $raw;
        } else {
            $parts = preg_split('/[\s,;]+/', (string) $raw) ?: [];
        }

        return collect($parts)
            ->map(fn ($v) => strtoupper(trim((string) $v)))
            ->filter(fn ($v) => $v !== '')
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @param  array<int, string>  $itemCodes
     * @return array{item_code: string, brand_name: string}|null
     */
    private function findConflictingItemCode(array $itemCodes, ?int $excludeBrandId): ?array
    {
        if (empty($itemCodes)) {
            return null;
        }

        $query = BrandItem::with('brand:id,code,name')
            ->whereIn('item_code', $itemCodes);

        if ($excludeBrandId !== null) {
            $query->where('brand_id', '!=', $excludeBrandId);
        }

        $existing = $query->first();
        if (! $existing) {
            return null;
        }

        return [
            'item_code' => $existing->item_code,
            'brand_name' => $existing->brand?->name ?? $existing->brand?->code ?? "Brand #{$existing->brand_id}",
        ];
    }

    /**
     * Resolve komponen brand_id untuk brand gabungan (dari payload atau kode bertanda '+').
     *
     * @return array<int, int>
     */
    private function resolveComponentBrandIds(Request $request, string $code, ?int $excludeId): array
    {
        if ($request->boolean('is_all_brands')) {
            return [];
        }

        $raw = $request->input('component_brand_ids');
        if (is_array($raw)) {
            $ids = collect($raw)
                ->map(fn ($v) => (int) $v)
                ->filter(fn ($v) => $v > 0 && ($excludeId === null || $v !== $excludeId))
                ->unique()
                ->values()
                ->all();
            if (! empty($ids)) {
                return $ids;
            }
        }

        if (str_contains($code, '+')) {
            $parts = array_filter(array_map('trim', explode('+', strtoupper($code))), fn ($p) => $p !== '');
            if (! empty($parts)) {
                return Brand::where(function ($q) use ($parts) {
                    $q->whereIn(DB::raw('UPPER(code)'), $parts)
                        ->orWhereIn(DB::raw('UPPER(name)'), $parts);
                })
                    ->when($excludeId !== null, fn ($q) => $q->where('id', '!=', $excludeId))
                    ->pluck('id')
                    ->map(fn ($id) => (int) $id)
                    ->unique()
                    ->values()
                    ->all();
            }
        }

        return [];
    }
}

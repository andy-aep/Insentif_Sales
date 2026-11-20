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
        $brands = Brand::with('items')->latest()->get();

        return response()->json($brands);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:brands,code',
            'name' => 'required|string|max:150',
            'item_codes' => 'nullable',
        ]);

        $itemCodes = $this->parseItemCodes($request->input('item_codes'));
        if ($conflict = $this->findConflictingItemCode($itemCodes, null)) {
            return response()->json([
                'message' => "ItemCode '{$conflict['item_code']}' sudah terdaftar pada Brand '{$conflict['brand_name']}'.",
            ], 422);
        }

        $brand = DB::transaction(function () use ($validated, $itemCodes) {
            $brand = Brand::create([
                'code' => strtoupper(trim($validated['code'])),
                'name' => trim($validated['name']),
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
        ]);

        $hasItemCodes = $request->has('item_codes');
        $itemCodes = $hasItemCodes ? $this->parseItemCodes($request->input('item_codes')) : [];

        if ($hasItemCodes && ($conflict = $this->findConflictingItemCode($itemCodes, $brand->id))) {
            return response()->json([
                'message' => "ItemCode '{$conflict['item_code']}' sudah terdaftar pada Brand '{$conflict['brand_name']}'.",
            ], 422);
        }

        $brand = DB::transaction(function () use ($brand, $validated, $hasItemCodes, $itemCodes) {
            $updateData = [];
            if (isset($validated['code'])) {
                $updateData['code'] = strtoupper(trim($validated['code']));
            }
            if (isset($validated['name'])) {
                $updateData['name'] = trim($validated['name']);
            }
            if (! empty($updateData)) {
                $brand->update($updateData);
            }

            if ($hasItemCodes) {
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
}

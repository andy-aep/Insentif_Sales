<?php

namespace App\Http\Controllers;

use App\Models\Brand;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BrandController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Brand::latest()->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:brands,code',
            'name' => 'required|string|max:150',
        ]);

        $brand = Brand::create($validated);

        return response()->json(['message' => 'Brand berhasil dibuat', 'data' => $brand], 201);
    }

    public function show(Brand $brand): JsonResponse
    {
        return response()->json(['data' => $brand]);
    }

    public function update(Request $request, Brand $brand): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'sometimes|required|string|max:50|unique:brands,code,'.$brand->id,
            'name' => 'sometimes|required|string|max:150',
        ]);

        $brand->update($validated);

        return response()->json(['message' => 'Brand berhasil diperbarui', 'data' => $brand]);
    }

    public function destroy(Brand $brand): JsonResponse
    {
        $brand->delete();

        return response()->json(['message' => 'Brand berhasil dihapus']);
    }
}

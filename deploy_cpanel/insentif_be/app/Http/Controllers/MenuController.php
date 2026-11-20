<?php

namespace App\Http\Controllers;

use App\Models\Menu;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuController extends Controller
{
    public function index(): JsonResponse
    {
        $menus = Menu::with('children')->whereNull('parent_id')->orderBy('order')->get();

        return response()->json($menus);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150',
            'route' => 'nullable|string|max:150',
            'icon' => 'nullable|string|max:100',
            'parent_id' => 'nullable|exists:menus,id',
            'order' => 'integer',
        ]);

        $menu = Menu::create($validated);

        return response()->json([
            'message' => 'Menu berhasil dibuat',
            'data' => $menu,
        ], 201);
    }

    public function show(Menu $menu): JsonResponse
    {
        return response()->json([
            'data' => $menu->load('children'),
        ]);
    }

    public function update(Request $request, Menu $menu): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:150',
            'route' => 'nullable|string|max:150',
            'icon' => 'nullable|string|max:100',
            'parent_id' => 'nullable|exists:menus,id',
            'order' => 'integer',
        ]);

        $menu->update($validated);

        return response()->json([
            'message' => 'Menu berhasil diperbarui',
            'data' => $menu,
        ]);
    }

    public function destroy(Menu $menu): JsonResponse
    {
        $menu->delete();

        return response()->json([
            'message' => 'Menu berhasil dihapus',
        ]);
    }
}

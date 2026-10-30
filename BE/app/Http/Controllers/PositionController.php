<?php

namespace App\Http\Controllers;

use App\Models\Position;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PositionController extends Controller
{
    public function index(): JsonResponse
    {
        $positions = Position::latest()->get();

        return response()->json($positions);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:150|unique:positions,name',
            'code' => 'required|string|max:50|unique:positions,code',
            'is_active' => 'boolean',
        ]);

        $position = Position::create($validated);

        return response()->json([
            'message' => 'Posisi berhasil dibuat',
            'data' => $position,
        ], 201);
    }

    public function show(Position $position): JsonResponse
    {
        return response()->json([
            'data' => $position,
        ]);
    }

    public function update(Request $request, Position $position): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:150|unique:positions,name,'.$position->id,
            'code' => 'sometimes|required|string|max:50|unique:positions,code,'.$position->id,
            'is_active' => 'boolean',
        ]);

        $position->update($validated);

        return response()->json([
            'message' => 'Posisi berhasil diperbarui',
            'data' => $position,
        ]);
    }

    public function destroy(Position $position): JsonResponse
    {
        $position->delete();

        return response()->json([
            'message' => 'Posisi berhasil dihapus',
        ]);
    }
}

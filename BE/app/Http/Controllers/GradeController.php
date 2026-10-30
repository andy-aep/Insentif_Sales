<?php

namespace App\Http\Controllers;

use App\Models\Grade;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class GradeController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $grades = Grade::with(['targetHeader', 'bobots'])
            ->when($request->target_header_id, fn ($q) => $q->where('target_header_id', $request->target_header_id))
            ->get();

        return response()->json($grades);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_grade' => 'nullable|uuid|unique:grades,id_grade',
            'target_header_id' => 'required|exists:target_headers,id',
            'grade_name' => 'required|string|max:100',
            'target_from' => 'required|numeric|min:0',
            'target_to' => 'required|numeric|gte:target_from',
        ]);

        if (empty($validated['id_grade'])) {
            $validated['id_grade'] = (string) Str::uuid();
        }

        $grade = Grade::create($validated);

        return response()->json([
            'message' => 'Grade berhasil dibuat',
            'data' => $grade->load(['targetHeader', 'bobots']),
        ], 201);
    }

    public function show(Grade $grade): JsonResponse
    {
        return response()->json([
            'data' => $grade->load(['targetHeader', 'bobots']),
        ]);
    }

    public function update(Request $request, Grade $grade): JsonResponse
    {
        $validated = $request->validate([
            'target_header_id' => 'sometimes|required|exists:target_headers,id',
            'grade_name' => 'sometimes|required|string|max:100',
            'target_from' => 'sometimes|required|numeric|min:0',
            'target_to' => 'sometimes|required|numeric|gte:target_from',
        ]);

        $grade->update($validated);

        return response()->json([
            'message' => 'Grade berhasil diperbarui',
            'data' => $grade->load(['targetHeader', 'bobots']),
        ]);
    }

    public function destroy(Grade $grade): JsonResponse
    {
        $grade->delete();

        return response()->json([
            'message' => 'Grade berhasil dihapus',
        ]);
    }
}

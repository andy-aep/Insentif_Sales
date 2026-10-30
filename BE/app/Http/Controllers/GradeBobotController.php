<?php

namespace App\Http\Controllers;

use App\Models\GradeBobot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GradeBobotController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $bobots = GradeBobot::with('grade.targetHeader')
            ->when($request->id_grade, fn ($q) => $q->where('id_grade', $request->id_grade))
            ->get();

        return response()->json($bobots);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_grade' => 'required|exists:grades,id_grade',
            'bobot_name' => 'required|string|max:100',
            'percent_from' => 'required|numeric|min:0',
            'percent_to' => 'required|numeric|gte:percent_from',
            'pengali' => 'boolean',
            'bobot' => 'numeric|min:0',
            'nominal' => 'numeric|min:0',
        ]);

        if (!empty($validated['pengali'])) {
            $validated['nominal'] = 0;
        } else {
            $validated['bobot'] = 0;
        }

        $gradeBobot = GradeBobot::create($validated);

        return response()->json([
            'message' => 'Grade Bobot berhasil dibuat',
            'data' => $gradeBobot->load('grade'),
        ], 201);
    }

    public function show(GradeBobot $gradeBobot): JsonResponse
    {
        return response()->json([
            'data' => $gradeBobot->load('grade.targetHeader'),
        ]);
    }

    public function update(Request $request, GradeBobot $gradeBobot): JsonResponse
    {
        $validated = $request->validate([
            'id_grade' => 'sometimes|required|exists:grades,id_grade',
            'bobot_name' => 'sometimes|required|string|max:100',
            'percent_from' => 'sometimes|required|numeric|min:0',
            'percent_to' => 'sometimes|required|numeric|gte:percent_from',
            'pengali' => 'boolean',
            'bobot' => 'numeric|min:0',
            'nominal' => 'numeric|min:0',
        ]);

        if (array_key_exists('pengali', $validated)) {
            if ($validated['pengali']) {
                $validated['nominal'] = 0;
            } else {
                $validated['bobot'] = 0;
            }
        }

        $gradeBobot->update($validated);

        return response()->json([
            'message' => 'Grade Bobot berhasil diperbarui',
            'data' => $gradeBobot->load('grade'),
        ]);
    }

    public function destroy(GradeBobot $gradeBobot): JsonResponse
    {
        $gradeBobot->delete();

        return response()->json([
            'message' => 'Grade Bobot berhasil dihapus',
        ]);
    }
}

<?php

namespace App\Http\Controllers;

use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\Position;
use App\Models\TargetHeader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TargetHeaderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $headers = TargetHeader::with(['position', 'grades.bobots'])
            ->when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->when($request->sales_type, fn ($q) => $q->where('sales_type', $request->sales_type))
            ->when($request->has('aktif'), fn ($q) => $q->where('aktif', $request->boolean('aktif')))
            ->latest()
            ->get();

        return response()->json($headers);
    }

    public function store(Request $request): JsonResponse
    {
        if ($request->filled('sales_type') && !is_numeric($request->sales_type)) {
            $pos = Position::where('code', $request->sales_type)->orWhere('name', 'like', "%{$request->sales_type}%")->first();
            if ($pos) {
                $request->merge(['sales_type' => $pos->id]);
            }
        }

        if ($request->filled('aktif_from')) {
            $request->merge(['aktif_from' => $this->normalizeDate($request->aktif_from)]);
        }
        if ($request->filled('aktif_to')) {
            $request->merge(['aktif_to' => $this->normalizeDate($request->aktif_to)]);
        }

        $validated = $request->validate([
            'nama' => 'required|string|max:255',
            'kategori_skema' => 'required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'sales_type' => 'required|exists:positions,id',
            'type' => 'required|string|max:100',
            'bobot' => 'nullable|numeric|min:0|max:100',
            'aktif' => 'boolean',
            'aktif_from' => 'required|string|size:8',
            'aktif_to' => 'required|string|size:8',
            'grades' => 'nullable|array',
        ]);

        $header = DB::transaction(function () use ($validated, $request) {
            $headerData = collect($validated)->except('grades')->toArray();
            $header = TargetHeader::create($headerData);

            if ($request->has('grades') && is_array($request->grades)) {
                $this->syncGradesAndBobots($header, $request->grades);
            }

            return $header;
        });

        return response()->json([
            'message' => 'Target Header berhasil dibuat',
            'data' => $header->load(['position', 'grades.bobots']),
        ], 201);
    }

    public function show(TargetHeader $targetHeader): JsonResponse
    {
        return response()->json([
            'data' => $targetHeader->load(['position', 'grades.bobots']),
        ]);
    }

    public function update(Request $request, TargetHeader $targetHeader): JsonResponse
    {
        if ($request->filled('sales_type') && !is_numeric($request->sales_type)) {
            $pos = Position::where('code', $request->sales_type)->orWhere('name', 'like', "%{$request->sales_type}%")->first();
            if ($pos) {
                $request->merge(['sales_type' => $pos->id]);
            }
        }

        if ($request->filled('aktif_from')) {
            $request->merge(['aktif_from' => $this->normalizeDate($request->aktif_from)]);
        }
        if ($request->filled('aktif_to')) {
            $request->merge(['aktif_to' => $this->normalizeDate($request->aktif_to)]);
        }

        $validated = $request->validate([
            'nama' => 'sometimes|required|string|max:255',
            'kategori_skema' => 'sometimes|required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'sales_type' => 'sometimes|required|exists:positions,id',
            'type' => 'sometimes|required|string|max:100',
            'bobot' => 'nullable|numeric|min:0|max:100',
            'aktif' => 'boolean',
            'aktif_from' => 'sometimes|required|string|size:8',
            'aktif_to' => 'sometimes|required|string|size:8',
            'grades' => 'nullable|array',
        ]);

        DB::transaction(function () use ($validated, $request, $targetHeader) {
            $headerData = collect($validated)->except('grades')->toArray();
            $targetHeader->update($headerData);

            if ($request->has('grades') && is_array($request->grades)) {
                $this->syncGradesAndBobots($targetHeader, $request->grades);
            }
        });

        return response()->json([
            'message' => 'Target Header berhasil diperbarui',
            'data' => $targetHeader->fresh()->load(['position', 'grades.bobots']),
        ]);
    }

    public function duplicate(TargetHeader $targetHeader): JsonResponse
    {
        $newHeader = DB::transaction(function () use ($targetHeader) {
            $targetHeader->load(['grades.bobots']);

            $cloned = $targetHeader->replicate();
            $cloned->nama = $targetHeader->nama . ' (Copy)';
            $cloned->save();

            foreach ($targetHeader->grades as $grade) {
                $newGradeId = (string) Str::uuid();
                $clonedGrade = $grade->replicate();
                $clonedGrade->target_header_id = $cloned->id;
                $clonedGrade->id_grade = $newGradeId;
                $clonedGrade->save();

                foreach ($grade->bobots as $bobot) {
                    $clonedBobot = $bobot->replicate();
                    $clonedBobot->id_grade = $newGradeId;
                    $clonedBobot->save();
                }
            }

            return $cloned;
        });

        return response()->json([
            'message' => 'Target Header berhasil diduplikasi',
            'data' => $newHeader->load(['position', 'grades.bobots']),
        ], 201);
    }

    public function destroy(TargetHeader $targetHeader): JsonResponse
    {
        $targetHeader->delete();

        return response()->json([
            'message' => 'Target Header berhasil dihapus',
        ]);
    }

    private function syncGradesAndBobots(TargetHeader $header, array $gradesData): void
    {
        $existingGrades = $header->grades()->get();
        foreach ($existingGrades as $oldGrade) {
            GradeBobot::where('id_grade', $oldGrade->id_grade)->delete();
            $oldGrade->delete();
        }

        foreach ($gradesData as $gData) {
            $idGrade = !empty($gData['id_grade']) ? $gData['id_grade'] : (string) Str::uuid();
            Grade::create([
                'id_grade' => $idGrade,
                'target_header_id' => $header->id,
                'grade_name' => $gData['grade_name'] ?? 'Grade',
                'target_from' => $gData['target_from'] ?? 0,
                'target_to' => $gData['target_to'] ?? 0,
            ]);

            $bobotsData = $gData['bobots'] ?? $gData['grade_bobots'] ?? [];
            if (is_array($bobotsData)) {
                foreach ($bobotsData as $bData) {
                    $isPengali = filter_var($bData['pengali'] ?? false, FILTER_VALIDATE_BOOLEAN);
                    GradeBobot::create([
                        'id_grade' => $idGrade,
                        'bobot_name' => $bData['bobot_name'] ?? 'Tier',
                        'percent_from' => $bData['percent_from'] ?? 0,
                        'percent_to' => $bData['percent_to'] ?? 0,
                        'pengali' => $isPengali,
                        'bobot' => $isPengali ? ($bData['bobot'] ?? 0) : 0,
                        'nominal' => !$isPengali ? ($bData['nominal'] ?? 0) : 0,
                    ]);
                }
            }
        }
    }

    private function normalizeDate(?string $date): ?string
    {
        if (empty($date)) {
            return null;
        }
        $trimmed = trim($date);
        // DD/MM/YYYY or DD-MM-YYYY
        if (preg_match('/^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$/', $trimmed, $m)) {
            return $m[3] . $m[2] . $m[1];
        }
        // YYYY-MM-DD or YYYY/MM/DD
        if (preg_match('/^(\d{4})[\/\-](\d{2})[\/\-](\d{2})$/', $trimmed, $m)) {
            return $m[1] . $m[2] . $m[3];
        }
        return preg_replace('/[^0-9]/', '', $trimmed);
    }
}


<?php

namespace App\Http\Controllers;

use App\Exports\IncentiveCalculationExport;
use App\Models\IncentiveCalculation;
use App\Services\IncentiveCalculationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class IncentiveCalculationController extends Controller
{
    public function __construct(
        protected IncentiveCalculationService $calculationService
    ) {}

    public function calculate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'kategori_skema' => 'required|in:KONSUMSI,INDUSTRI,SURABAYA',
            'period' => 'required|string|size:6',
        ]);

        $authUserId = $request->user()->id;

        $results = $this->calculationService->execute(
            $validated['kategori_skema'],
            $validated['period'],
            $authUserId
        );

        $totalPayout = $results->sum('final_reward');
        $totalPersonil = $results->pluck('user_id')->unique()->count();

        return response()->json([
            'message' => 'Kalkulasi insentif berhasil dijalankan',
            'meta' => [
                'kategori_skema' => $validated['kategori_skema'],
                'period' => $validated['period'],
                'total_personil' => $totalPersonil,
                'total_records' => $results->count(),
                'total_payout' => $totalPayout,
            ],
            'data' => $results,
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $calculations = IncentiveCalculation::with(['user.position', 'targetHeader', 'grade', 'gradeBobot', 'calculatedBy'])
            ->when($request->kategori_skema, fn ($q) => $q->where('kategori_skema', $request->kategori_skema))
            ->when($request->period, fn ($q) => $q->where('period', $request->period))
            ->when($request->user_id, fn ($q) => $q->where('user_id', $request->user_id))
            ->latest()
            ->paginate($request->integer('per_page', 25));

        return response()->json($calculations);
    }

    public function exportExcel(Request $request): BinaryFileResponse
    {
        $request->validate([
            'kategori_skema' => 'nullable|in:KONSUMSI,INDUSTRI,SURABAYA',
            'period' => 'nullable|string|size:6',
        ]);

        $kategoriSkema = $request->query('kategori_skema');
        $period = $request->query('period');

        $fileName = 'incentive_report_'.($kategoriSkema ?? 'ALL').'_'.($period ?? date('Ym')).'.xlsx';

        return Excel::download(
            new IncentiveCalculationExport($kategoriSkema, $period),
            $fileName
        );
    }
}

<?php

namespace App\Http\Controllers;

use App\Exports\BulkUploadTemplateExport;
use App\Models\UploadBatch;
use App\Services\BatchImportService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class BatchUploadController extends Controller
{
    protected array $allowedEntities = [
        'sellout_distributor',
        'distributor',
        'master_target_distributor',
        'sellin_distributor',
        'sellin_industri',
        'sellout_sales_surabaya',
        'depo',
        'area',
    ];

    public function __construct(
        protected BatchImportService $batchImportService
    ) {}

    public function downloadTemplate(string $entity): BinaryFileResponse|JsonResponse
    {
        $normalized = BatchImportService::normalizeEntity($entity);

        if (! in_array($normalized, $this->allowedEntities)) {
            return response()->json([
                'message' => 'Tipe entitas tidak valid. Entitas yang didukung: '.implode(', ', $this->allowedEntities),
            ], 422);
        }

        $fileName = "template_{$normalized}.xlsx";

        return Excel::download(
            new BulkUploadTemplateExport($normalized),
            $fileName
        );
    }

    public function upload(Request $request, string $entity): JsonResponse
    {
        $normalized = BatchImportService::normalizeEntity($entity);

        if (! in_array($normalized, $this->allowedEntities)) {
            return response()->json([
                'message' => 'Tipe entitas tidak valid. Entitas yang didukung: '.implode(', ', $this->allowedEntities),
            ], 422);
        }

        $request->validate([
            'file' => 'required|file|extensions:xlsx,xls,csv,txt|max:20480', // max 20MB
        ]);

        $file = $request->file('file');
        $fileName = $file->getClientOriginalName();
        $userId = $request->user()->id;

        $batch = $this->batchImportService->createBatch($normalized, $fileName, $userId);

        try {
            $processedBatch = $this->batchImportService->processFile($batch, $file);

            return response()->json([
                'message' => 'Upload batch berhasil diproses',
                'data' => $processedBatch,
            ]);
        } catch (Exception $e) {
            return response()->json([
                'message' => 'Gagal memproses batch: '.$e->getMessage(),
                'batch_id' => $batch->id,
            ], 500);
        }
    }

    public function rollback(string $batchId): JsonResponse
    {
        try {
            $this->batchImportService->rollback($batchId);

            return response()->json([
                'message' => "Batch {$batchId} berhasil di-rollback beserta seluruh data transaksi terkait.",
            ]);
        } catch (Exception $e) {
            return response()->json([
                'message' => 'Gagal melakukan rollback: '.$e->getMessage(),
            ], 400);
        }
    }

    public function history(Request $request): JsonResponse
    {
        $batches = UploadBatch::with('uploader')
            ->when($request->entity_type, fn ($q) => $q->where('entity_type', $request->entity_type))
            ->when($request->status, fn ($q) => $q->where('status', $request->status))
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($batches);
    }
}

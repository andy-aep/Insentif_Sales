<?php

namespace App\Http\Controllers;

use App\Exports\BulkUploadTemplateExport;
use App\Models\UploadBatch;
use App\Services\BatchImportService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class BatchUploadController extends Controller
{
    protected array $allowedEntities = [
        'sellout_distributor',
        'distributor',
        'master_target_distributor',
        'master_target_depo',
        'master_target_area',
        'sellin_distributor',
        'sellin_industri',
        'sellout_sales_surabaya',
        'depo',
        'area',
    ];

    public function __construct(
        protected BatchImportService $batchImportService
    ) {}

    public function downloadTemplate(Request $request, string $entity): BinaryFileResponse|JsonResponse
    {
        $normalized = BatchImportService::normalizeEntity($entity);

        if (! in_array($normalized, $this->allowedEntities)) {
            return response()->json([
                'message' => 'Tipe entitas tidak valid. Entitas yang didukung: '.implode(', ', $this->allowedEntities),
            ], 422);
        }

        $withData = filter_var($request->query('with_data'), FILTER_VALIDATE_BOOLEAN);
        $period = $request->query('period');

        $prefix = $withData ? 'data_export' : 'template';
        $periodSuffix = ($period && $period !== 'ALL') ? "_{$period}" : '';
        $fileName = "{$prefix}_{$normalized}{$periodSuffix}.xlsx";

        return Excel::download(
            new BulkUploadTemplateExport($normalized, $withData, $period),
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

        if (function_exists('set_time_limit')) {
            @set_time_limit(0);
        }
        @ini_set('max_execution_time', '0');
        @ini_set('memory_limit', '2048M');

        $request->validate([
            'file' => 'required|file|extensions:xlsx,xls,csv,txt|max:204800', // max 200MB
        ]);

        $file = $request->file('file');
        $fileName = $file->getClientOriginalName();
        $userId = $request->user()->id;

        $batch = $this->batchImportService->createBatch($normalized, $fileName, $userId);

        try {
            $storedPath = $file->storeAs('uploads/batches', $batch->id . '_' . $fileName);
            $batch->update(['file_path' => $storedPath]);
        } catch (Exception $e) {
            // Abaikan jika store gagal, proses tetap lanjut
        }

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

    public function downloadBatchFile(string $batchId): BinaryFileResponse|JsonResponse
    {
        $batch = UploadBatch::findOrFail($batchId);

        $filePath = null;
        if ($batch->file_path && Storage::exists($batch->file_path)) {
            $filePath = Storage::path($batch->file_path);
        } elseif ($batch->file_path && file_exists(storage_path('app/' . $batch->file_path))) {
            $filePath = storage_path('app/' . $batch->file_path);
        } else {
            $fallback = storage_path('app/uploads/batches/' . $batch->id . '_' . $batch->file_name);
            if (file_exists($fallback)) {
                $filePath = $fallback;
            }
        }

        if (! $filePath || ! file_exists($filePath)) {
            return response()->json([
                'message' => 'File spreadsheet untuk batch ini tidak ditemukan pada penyimpanan server.',
            ], 404);
        }

        return response()->download($filePath, $batch->file_name);
    }

    public function destroy(string $batchId): JsonResponse
    {
        try {
            $batch = UploadBatch::findOrFail($batchId);

            // Jika belum di-rollback, hapus seluruh data terkait di database
            if ($batch->status !== 'ROLLED_BACK') {
                $this->batchImportService->rollback($batchId);
            }

            // Hapus file fisik jika tersimpan
            if ($batch->file_path && Storage::exists($batch->file_path)) {
                Storage::delete($batch->file_path);
            }
            $fallback = storage_path('app/uploads/batches/' . $batch->id . '_' . $batch->file_name);
            if (file_exists($fallback)) {
                @unlink($fallback);
            }

            $batch->delete();

            return response()->json([
                'message' => "Batch {$batchId} berhasil dihapus permanen.",
            ]);
        } catch (Exception $e) {
            return response()->json([
                'message' => 'Gagal menghapus batch: ' . $e->getMessage(),
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

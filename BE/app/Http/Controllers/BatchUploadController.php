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
use Throwable;

class BatchUploadController extends Controller
{
    protected array $allowedEntities = [
        'sellout_distributor',
        'distributor',
        'master_target_distributor',
        'master_target_depo',
        'master_target_area',
        'master_target_industri',
        'master_target_surabaya',
        'sellin_distributor',
        'sellin_industri',
        'industri_customer',
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
        $distributorId = $request->query('distributor_id') ? (int) $request->query('distributor_id') : null;
        $depoId = $request->query('depo_id') ? (int) $request->query('depo_id') : null;
        $brandId = $request->query('brand_id') ? (int) $request->query('brand_id') : null;

        $prefix = $withData ? 'data_export' : 'template';
        $safePeriod = $period ? str_replace(',', '_', trim((string) $period)) : '';
        $periodSuffix = ($safePeriod !== '' && strtoupper($safePeriod) !== 'ALL')
            ? "_{$safePeriod}"
            : ($withData ? '_semua_periode' : '');
        $fileName = "{$prefix}_{$normalized}{$periodSuffix}.xlsx";

        return Excel::download(
            new BulkUploadTemplateExport($normalized, $withData, $period, $distributorId, $brandId, $depoId),
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

        if ($request->filled('chunk_base64') && $request->filled('upload_id')) {
            $validated = $request->validate([
                'upload_id' => 'required|string|max:100',
                'chunk_index' => 'required|integer|min:0',
                'total_chunks' => 'required|integer|min:1',
                'file_name' => 'required|string|max:255',
                'chunk_base64' => 'required|string',
                'period' => 'nullable|string|size:6',
                'distributor_id' => 'nullable|integer|exists:distributors,id',
            ]);

            $fileName = basename($validated['file_name']);
            $ext = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
            if (! in_array($ext, ['xlsx', 'xls', 'csv', 'txt'], true)) {
                return response()->json(['message' => 'Ekstensi file tidak didukung (gunakan xlsx, xls, csv, txt).'], 422);
            }

            $chunkDir = storage_path('app/chunk_uploads');
            if (! is_dir($chunkDir)) {
                @mkdir($chunkDir, 0775, true);
            }
            $safeId = preg_replace('/[^a-zA-Z0-9_-]/', '', $validated['upload_id']);
            $tempPath = $chunkDir . DIRECTORY_SEPARATOR . $safeId . '.' . $ext;
            $chunkIndex = (int) $validated['chunk_index'];
            $totalChunks = (int) $validated['total_chunks'];

            $decoded = base64_decode($validated['chunk_base64'], true);
            if ($decoded === false) {
                return response()->json(['message' => 'Data chunk base64 tidak valid.'], 422);
            }

            file_put_contents($tempPath, $decoded, $chunkIndex === 0 ? 0 : FILE_APPEND);

            if ($chunkIndex < $totalChunks - 1) {
                return response()->json([
                    'message' => 'Chunk diterima',
                    'chunk_index' => $chunkIndex,
                    'total_chunks' => $totalChunks,
                ]);
            }

            $userId = $request->user()->id;
            $batch = $this->batchImportService->createBatch(
                $normalized,
                $fileName,
                $userId,
                $validated['period'] ?? null,
                isset($validated['distributor_id']) ? (int) $validated['distributor_id'] : null
            );

            try {
                $storedRel = 'uploads/batches/' . $batch->id . '_' . $fileName;
                Storage::put($storedRel, file_get_contents($tempPath));
                $batch->update(['file_path' => $storedRel]);
            } catch (Throwable $e) {
                // Abaikan jika gagal simpan arsip
            }

            try {
                $processedBatch = $this->batchImportService->processFile($batch, $tempPath);
                @unlink($tempPath);

                return response()->json([
                    'message' => 'Upload batch berhasil diproses',
                    'data' => $processedBatch,
                ]);
            } catch (Throwable $e) {
                @unlink($tempPath);
                $msg = $e->getMessage();
                $status = str_contains($msg, 'Validasi') || str_contains($msg, 'Header kolom') || str_contains($msg, 'wajib') ? 422 : 500;

                return response()->json([
                    'message' => 'Gagal memproses batch: ' . $msg,
                    'batch_id' => $batch->id,
                ], $status);
            }
        }

        $validated = $request->validate([
            'file' => 'required|file|extensions:xlsx,xls,csv,txt|max:204800', // max 200MB
            'period' => 'nullable|string|size:6',
            'distributor_id' => 'nullable|integer|exists:distributors,id',
        ]);

        $file = $request->file('file');
        $fileName = $file->getClientOriginalName();
        $userId = $request->user()->id;

        $batch = $this->batchImportService->createBatch(
            $normalized,
            $fileName,
            $userId,
            $validated['period'] ?? null,
            isset($validated['distributor_id']) ? (int) $validated['distributor_id'] : null
        );

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
        } catch (Throwable $e) {
            $msg = $e->getMessage();
            $status = str_contains($msg, 'Validasi') || str_contains($msg, 'Header kolom') || str_contains($msg, 'wajib') ? 422 : 500;

            return response()->json([
                'message' => 'Gagal memproses batch: '.$msg,
                'batch_id' => $batch->id,
            ], $status);
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
                try {
                    $this->batchImportService->rollback($batchId);
                } catch (Exception $e) {
                    if ($batch->status === 'COMPLETED') {
                        throw $e;
                    }
                }
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
        $batches = UploadBatch::with(['uploader', 'distributor:id,code,name'])
            ->when($request->entity_type, fn ($q) => $q->where('entity_type', $request->entity_type))
            ->when($request->status, fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('period'), fn ($q) => $q->where('period', trim((string) $request->period)))
            ->when($request->filled('distributor_id'), fn ($q) => $q->where('distributor_id', $request->integer('distributor_id')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = '%' . strtolower(trim((string) $request->q)) . '%';
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(file_name) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(period, \'\')) LIKE ?', [$term])
                        ->orWhereHas('distributor', fn ($d) => $d->whereRaw('LOWER(name) LIKE ?', [$term])->orWhereRaw('LOWER(code) LIKE ?', [$term]));
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 200));

        return response()->json($batches);
    }
}

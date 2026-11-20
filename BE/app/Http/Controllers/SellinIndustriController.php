<?php

namespace App\Http\Controllers;

use App\Models\IndustriCustomer;
use App\Models\SalesIndustriAssignment;
use App\Models\SellinIndustri;
use App\Models\User;
use App\Services\SapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

class SellinIndustriController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = SellinIndustri::with(['user.position', 'industriCustomer'])
            ->when($request->filled('period'), fn ($q) => $q->where('period', $request->period))
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('industri_customer_id'), fn ($q) => $q->where('industri_customer_id', $request->industri_customer_id))
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = trim($request->q);
                $q->where(function ($sub) use ($term) {
                    $sub->where('customer_name', 'like', "%{$term}%")
                        ->orWhere('customer_code', 'like', "%{$term}%")
                        ->orWhere('sap_so_no', 'like', "%{$term}%");
                });
            })
            ->latest('id');

        return response()->json($query->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'nullable|exists:users,id',
            'industri_customer_id' => 'nullable|exists:industri_customers,id',
            'customer_code' => 'nullable|string|max:64',
            'customer_name' => 'nullable|string|max:255',
            'period' => 'required|string|size:6',
            'volume_kg' => 'nullable|numeric|min:0',
            'tonase' => 'nullable|numeric|min:0',
            'nominal' => 'nullable|numeric|min:0',
            'transaction_date' => 'nullable|date',
            'is_noo' => 'nullable|boolean',
            'sap_so_no' => 'nullable|string|max:255',
        ]);

        $customer = null;
        if (!empty($validated['industri_customer_id'])) {
            $customer = IndustriCustomer::find($validated['industri_customer_id']);
        } elseif (!empty($validated['customer_code'])) {
            $customer = IndustriCustomer::where('customer_code', strtoupper(trim($validated['customer_code'])))->first();
        } elseif (!empty($validated['customer_name'])) {
            $customer = IndustriCustomer::whereRaw('LOWER(customer_name) = ?', [strtolower(trim($validated['customer_name']))])->first();
        }

        if (!$customer && empty($validated['customer_name'])) {
            return response()->json([
                'message' => 'Pilih Customer Industri atau isi nama customer.',
            ], 422);
        }

        $customerName = $customer ? $customer->customer_name : trim($validated['customer_name']);
        $customerCode = $customer ? $customer->customer_code : (!empty($validated['customer_code']) ? strtoupper(trim($validated['customer_code'])) : null);

        $userId = $validated['user_id'] ?? null;
        if (!$userId && $customer) {
            $assignment = SalesIndustriAssignment::where('industri_customer_id', $customer->id)
                ->where('is_active', true)
                ->where(function ($q) use ($validated) {
                    $q->where('period', $validated['period'])
                        ->orWhereNull('period')
                        ->orWhere('period', '');
                })
                ->orderByRaw('CASE WHEN period = ? THEN 0 ELSE 1 END', [$validated['period']])
                ->first();
            $userId = $assignment?->user_id;
        }

        $volumeKg = (float) ($validated['volume_kg'] ?? $validated['tonase'] ?? 0);
        if ($volumeKg <= 0) {
            return response()->json([
                'message' => 'Volume (Kg) harus lebih besar dari 0.',
            ], 422);
        }

        $sellin = SellinIndustri::create([
            'user_id' => $userId,
            'industri_customer_id' => $customer?->id,
            'customer_code' => $customerCode,
            'customer_name' => $customerName,
            'period' => $validated['period'],
            'tonase' => $volumeKg,
            'volume_kg' => $volumeKg,
            'nominal' => (float) ($validated['nominal'] ?? 0),
            'transaction_date' => $validated['transaction_date'] ?? null,
            'is_noo' => $validated['is_noo'] ?? null,
            'sap_so_no' => $validated['sap_so_no'] ?? null,
        ]);

        return response()->json([
            'message' => 'Realisasi Sell-In Industri berhasil disimpan',
            'data' => $sellin->load(['user.position', 'industriCustomer']),
        ], 201);
    }

    public function update(Request $request, SellinIndustri $sellinIndustri): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'nullable|exists:users,id',
            'industri_customer_id' => 'nullable|exists:industri_customers,id',
            'period' => 'sometimes|required|string|size:6',
            'volume_kg' => 'nullable|numeric|min:0',
            'tonase' => 'nullable|numeric|min:0',
            'nominal' => 'nullable|numeric|min:0',
            'transaction_date' => 'nullable|date',
            'is_noo' => 'nullable|boolean',
            'sap_so_no' => 'nullable|string|max:255',
        ]);

        if (isset($validated['volume_kg']) || isset($validated['tonase'])) {
            $volumeKg = (float) ($validated['volume_kg'] ?? $validated['tonase'] ?? $sellinIndustri->volume_kg);
            $validated['volume_kg'] = $volumeKg;
            $validated['tonase'] = $volumeKg;
        }

        $sellinIndustri->update($validated);

        return response()->json([
            'message' => 'Realisasi Sell-In Industri berhasil diperbarui',
            'data' => $sellinIndustri->fresh()->load(['user.position', 'industriCustomer']),
        ]);
    }

    public function destroy(SellinIndustri $sellinIndustri): JsonResponse
    {
        $sellinIndustri->delete();

        return response()->json([
            'message' => 'Realisasi Sell-In Industri berhasil dihapus',
        ]);
    }

    public function syncFromSap(Request $request, SapService $sapService): JsonResponse
    {
        $validated = $request->validate([
            'period' => 'required|string|size:6',
            'slp_code' => 'nullable|integer',
            'card_code' => 'nullable|string|max:64',
        ]);

        $period = trim($validated['period']);

        try {
            $rows = $sapService->listSellinIndustri(
                $period,
                isset($validated['slp_code']) ? (int) $validated['slp_code'] : null,
                $validated['card_code'] ?? null
            );
        } catch (Throwable $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 502);
        }

        $usersBySlp = User::whereNotNull('sap_sales_code')
            ->get()
            ->keyBy('sap_sales_code');

        $createdCount = 0;
        $updatedCount = 0;
        $unmappedSales = [];

        DB::transaction(function () use ($rows, $usersBySlp, $period, &$createdCount, &$updatedCount, &$unmappedSales) {
            foreach ($rows as $row) {
                $slpCode = $row['slp_code'];
                $user = $slpCode !== null ? $usersBySlp->get($slpCode) : null;
                if ($slpCode !== null && ! $user) {
                    $unmappedSales[(string) $slpCode] = $row['slp_name'] ?: "SlpCode {$slpCode}";
                }

                $customer = IndustriCustomer::firstOrCreate(
                    ['customer_code' => $row['card_code']],
                    [
                        'customer_name' => $row['card_name'] ?: $row['card_code'],
                        'customer_type' => ($row['is_noo'] === true) ? 'NEW' : 'EXISTING',
                        'first_transaction_period' => $row['first_tx_period'] ?: null,
                        'is_active' => true,
                    ]
                );

                // Fallback ke SalesIndustriAssignment jika user belum dipetakan via sap_sales_code
                $userId = $user?->id;
                if (! $userId) {
                    $assignment = SalesIndustriAssignment::where('industri_customer_id', $customer->id)
                        ->where('is_active', true)
                        ->where(function ($q) use ($period) {
                            $q->where('period', $period)
                                ->orWhereNull('period')
                                ->orWhere('period', '');
                        })
                        ->orderByRaw('CASE WHEN period = ? THEN 0 ELSE 1 END', [$period])
                        ->first();
                    $userId = $assignment?->user_id;
                }

                $sapSoNo = $row['sap_so_no'] !== '' ? $row['sap_so_no'] : null;

                $existing = SellinIndustri::where('period', $row['period'])
                    ->where('customer_code', $row['card_code'])
                    ->where('sap_so_no', $sapSoNo)
                    ->first();

                $payload = [
                    'user_id' => $userId,
                    'industri_customer_id' => $customer->id,
                    'customer_code' => $row['card_code'],
                    'customer_name' => $row['card_name'] ?: $customer->customer_name,
                    'period' => $row['period'],
                    'tonase' => $row['volume_kg'],
                    'volume_kg' => $row['volume_kg'],
                    'nominal' => $row['nominal'],
                    'transaction_date' => $row['doc_date'],
                    'sap_so_no' => $sapSoNo,
                ];

                if ($row['is_noo'] !== null) {
                    $payload['is_noo'] = $row['is_noo'];
                }

                if ($existing) {
                    $existing->update($payload);
                    $updatedCount++;
                } else {
                    SellinIndustri::create($payload);
                    $createdCount++;
                }
            }
        });

        return response()->json([
            'message' => 'Sinkronisasi Realisasi Sell-In Industri dari SAP selesai.',
            'period' => $period,
            'total_fetched' => count($rows),
            'created_count' => $createdCount,
            'updated_count' => $updatedCount,
            'unmapped_sales' => $unmappedSales,
        ]);
    }
}

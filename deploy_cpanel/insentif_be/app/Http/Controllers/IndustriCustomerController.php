<?php

namespace App\Http\Controllers;

use App\Models\IndustriCustomer;
use App\Services\SapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class IndustriCustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = IndustriCustomer::with(['assignments' => fn ($q) => $q->where('is_active', true)->with('user.position')])
            ->when($request->filled('customer_type'), fn ($q) => $q->where('customer_type', strtoupper($request->customer_type)))
            ->when($request->has('is_active'), fn ($q) => $q->where('is_active', filter_var($request->is_active, FILTER_VALIDATE_BOOLEAN)))
            ->when($request->filled('q'), function ($q) use ($request) {
                $term = '%' . strtolower(trim((string) $request->q)) . '%';
                $q->where(function ($sub) use ($term) {
                    $sub->whereRaw('LOWER(COALESCE(customer_name, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(customer_code, \'\')) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(city, \'\')) LIKE ?', [$term]);
                });
            })
            ->orderBy('customer_name');

        return response()->json($query->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'customer_code' => 'nullable|string|max:64|unique:industri_customers,customer_code',
            'customer_name' => 'required|string|max:255',
            'city' => 'nullable|string|max:100',
            'customer_type' => 'nullable|in:NEW,EXISTING',
            'first_transaction_period' => 'nullable|string|max:6',
            'is_active' => 'boolean',
        ]);

        $code = !empty($validated['customer_code'])
            ? strtoupper(trim($validated['customer_code']))
            : 'IND-' . strtoupper(substr(md5(uniqid((string) mt_rand(), true)), 0, 6));

        $customer = IndustriCustomer::create([
            'customer_code' => $code,
            'customer_name' => trim($validated['customer_name']),
            'city' => $validated['city'] ?? null,
            'customer_type' => $validated['customer_type'] ?? 'NEW',
            'first_transaction_period' => $validated['first_transaction_period'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Customer Industri berhasil ditambahkan',
            'data' => $customer->load('assignments.user.position'),
        ], 201);
    }

    public function update(Request $request, IndustriCustomer $industriCustomer): JsonResponse
    {
        $validated = $request->validate([
            'customer_code' => 'sometimes|required|string|max:64|unique:industri_customers,customer_code,' . $industriCustomer->id,
            'customer_name' => 'sometimes|required|string|max:255',
            'city' => 'nullable|string|max:100',
            'customer_type' => 'sometimes|in:NEW,EXISTING',
            'first_transaction_period' => 'nullable|string|max:6',
            'is_active' => 'boolean',
        ]);

        if (isset($validated['customer_code'])) {
            $validated['customer_code'] = strtoupper(trim($validated['customer_code']));
        }
        if (isset($validated['customer_name'])) {
            $validated['customer_name'] = trim($validated['customer_name']);
        }

        $industriCustomer->update($validated);

        return response()->json([
            'message' => 'Customer Industri berhasil diperbarui',
            'data' => $industriCustomer->fresh()->load('assignments.user.position'),
        ]);
    }

    public function destroy(IndustriCustomer $industriCustomer): JsonResponse
    {
        $industriCustomer->delete();

        return response()->json([
            'message' => 'Customer Industri berhasil dihapus',
        ]);
    }

    public function sapList(SapService $sapService): JsonResponse
    {
        try {
            $data = $sapService->listIndustriCustomers();

            return response()->json([
                'data' => $data,
                'source' => config('services.sap.base_url'),
            ]);
        } catch (Throwable $e) {
            return response()->json([
                'message' => $e->getMessage(),
                'data' => [],
            ], 502);
        }
    }
}

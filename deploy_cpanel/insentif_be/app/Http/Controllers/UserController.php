<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\SapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Throwable;

class UserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $perPage = $request->boolean('all') ? 1000 : min(max($request->integer('per_page', 250), 1), 1000);

        $users = User::with(['role', 'position'])
            ->when($request->role_id, fn ($q) => $q->where('role_id', $request->role_id))
            ->when($request->position_id, fn ($q) => $q->where('position_id', $request->position_id))
            ->when($request->search, function ($q, $search) {
                $term = '%' . strtolower(trim((string) $search)) . '%';
                $q->where(function ($query) use ($term, $search) {
                    $query->whereRaw('LOWER(name) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(username) LIKE ?', [$term])
                        ->orWhereRaw('LOWER(COALESCE(sap_sales_name, \'\')) LIKE ?', [$term]);
                    if (is_numeric(trim((string) $search))) {
                        $query->orWhere('sap_sales_code', (int) trim((string) $search));
                    }
                });
            })
            ->orderBy('name')
            ->paginate($perPage);

        return response()->json($users);
    }

    public function store(Request $request): JsonResponse
    {
        $request->merge([
            'username' => strtolower(trim((string) $request->input('username', ''))),
        ]);

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'username' => ['required', 'string', 'min:3', 'max:64', 'regex:/^[a-z0-9._-]+$/', 'unique:users,username'],
            'email' => 'nullable|email|max:255|unique:users,email',
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
            'position_id' => 'nullable|exists:positions,id',
            'sap_sales_code' => 'nullable|integer',
            'sap_sales_name' => 'nullable|string|max:255',
            'aktif_from' => 'required|date',
            'aktif_to' => 'nullable|date|after_or_equal:aktif_from',
            'is_eligible_konsumsi' => 'boolean',
            'is_eligible_industri' => 'boolean',
            'is_eligible_surabaya' => 'boolean',
        ], [
            'username.regex' => 'Username hanya boleh berisi huruf kecil, angka, titik (.), underscore (_), atau strip (-), tanpa spasi.',
            'username.unique' => 'Username sudah digunakan oleh pengguna lain.',
            'username.min' => 'Username minimal 3 karakter.',
        ]);

        $validated['password'] = Hash::make($validated['password']);

        $user = User::create($validated);

        return response()->json([
            'message' => 'User berhasil ditambahkan',
            'data' => $user->load(['role', 'position']),
        ], 201);
    }

    public function show(User $user): JsonResponse
    {
        return response()->json([
            'data' => $user->load(['role.menuPermissions.menu', 'position']),
        ]);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        if ($request->has('username')) {
            $request->merge([
                'username' => strtolower(trim((string) $request->input('username', ''))),
            ]);
        }

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'username' => ['sometimes', 'required', 'string', 'min:3', 'max:64', 'regex:/^[a-z0-9._-]+$/', 'unique:users,username,'.$user->id],
            'email' => 'nullable|email|max:255|unique:users,email,'.$user->id,
            'password' => 'nullable|string|min:6',
            'role_id' => 'sometimes|required|exists:roles,id',
            'position_id' => 'nullable|exists:positions,id',
            'sap_sales_code' => 'nullable|integer',
            'sap_sales_name' => 'nullable|string|max:255',
            'aktif_from' => 'sometimes|required|date',
            'aktif_to' => 'nullable|date',
            'is_eligible_konsumsi' => 'boolean',
            'is_eligible_industri' => 'boolean',
            'is_eligible_surabaya' => 'boolean',
        ], [
            'username.regex' => 'Username hanya boleh berisi huruf kecil, angka, titik (.), underscore (_), atau strip (-), tanpa spasi.',
            'username.unique' => 'Username sudah digunakan oleh pengguna lain.',
            'username.min' => 'Username minimal 3 karakter.',
        ]);

        if (! empty($validated['password'])) {
            $validated['password'] = Hash::make($validated['password']);
        } else {
            unset($validated['password']);
        }

        $user->update($validated);

        return response()->json([
            'message' => 'User berhasil diperbarui',
            'data' => $user->fresh()->load(['role', 'position']),
        ]);
    }

    public function updatePassword(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'password' => 'required|string|min:6',
        ]);

        $user->update([
            'password' => Hash::make($validated['password']),
        ]);

        return response()->json([
            'message' => "Kata sandi user {$user->name} berhasil diperbarui",
        ]);
    }

    public function destroy(User $user): JsonResponse
    {
        $user->delete();

        return response()->json([
            'message' => 'User berhasil dihapus',
        ]);
    }

    public function sapSalesEmployees(Request $request, SapService $sapService): JsonResponse
    {
        try {
            $data = $sapService->listSalesEmployees($request->boolean('include_unassigned', false));

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

<?php

namespace App\Http\Controllers;

use App\Models\Role;
use App\Models\RoleMenuPermission;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RoleController extends Controller
{
    public function index(): JsonResponse
    {
        $roles = Role::with(['menuPermissions.menu'])->get();

        return response()->json($roles);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100|unique:roles,name',
            'display_name' => 'required|string|max:150',
            'description' => 'nullable|string',
            'permissions' => 'nullable|array',
            'permissions.*.menu_id' => 'required|exists:menus,id',
            'permissions.*.can_view' => 'boolean',
            'permissions.*.can_create' => 'boolean',
            'permissions.*.can_update' => 'boolean',
            'permissions.*.can_delete' => 'boolean',
        ]);

        $role = Role::create([
            'name' => $validated['name'],
            'display_name' => $validated['display_name'],
            'description' => $validated['description'] ?? null,
        ]);

        if (! empty($validated['permissions'])) {
            foreach ($validated['permissions'] as $perm) {
                RoleMenuPermission::create([
                    'role_id' => $role->id,
                    'menu_id' => $perm['menu_id'],
                    'can_view' => $perm['can_view'] ?? false,
                    'can_create' => $perm['can_create'] ?? false,
                    'can_update' => $perm['can_update'] ?? false,
                    'can_delete' => $perm['can_delete'] ?? false,
                ]);
            }
        }

        return response()->json([
            'message' => 'Role berhasil dibuat',
            'data' => $role->load('menuPermissions.menu'),
        ], 201);
    }

    public function show(Role $role): JsonResponse
    {
        return response()->json([
            'data' => $role->load('menuPermissions.menu'),
        ]);
    }

    public function update(Request $request, Role $role): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:100|unique:roles,name,'.$role->id,
            'display_name' => 'sometimes|required|string|max:150',
            'description' => 'nullable|string',
            'permissions' => 'nullable|array',
            'permissions.*.menu_id' => 'required|exists:menus,id',
            'permissions.*.can_view' => 'boolean',
            'permissions.*.can_create' => 'boolean',
            'permissions.*.can_update' => 'boolean',
            'permissions.*.can_delete' => 'boolean',
        ]);

        $role->update([
            'name' => $validated['name'] ?? $role->name,
            'display_name' => $validated['display_name'] ?? $role->display_name,
            'description' => $validated['description'] ?? $role->description,
        ]);

        if (isset($validated['permissions'])) {
            RoleMenuPermission::where('role_id', $role->id)->delete();
            foreach ($validated['permissions'] as $perm) {
                RoleMenuPermission::create([
                    'role_id' => $role->id,
                    'menu_id' => $perm['menu_id'],
                    'can_view' => $perm['can_view'] ?? false,
                    'can_create' => $perm['can_create'] ?? false,
                    'can_update' => $perm['can_update'] ?? false,
                    'can_delete' => $perm['can_delete'] ?? false,
                ]);
            }
        }

        return response()->json([
            'message' => 'Role berhasil diperbarui',
            'data' => $role->fresh()->load('menuPermissions.menu'),
        ]);
    }

    public function destroy(Role $role): JsonResponse
    {
        $role->delete();

        return response()->json([
            'message' => 'Role berhasil dihapus',
        ]);
    }
}

<?php

use App\Models\Menu;
use App\Models\Role;
use App\Models\RoleMenuPermission;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        $canonicalMenus = [
            ['name' => 'Dashboard', 'route' => '/dashboard', 'icon' => 'layout_grid', 'order' => 1],
            ['name' => 'Master Distributor', 'route' => '/master/distributor', 'icon' => 'building2', 'order' => 2],
            ['name' => 'Master Target Kuota', 'route' => '/master/target', 'icon' => 'target', 'order' => 3],
            ['name' => 'Realisasi Penjualan', 'route' => '/master/realisasi', 'icon' => 'shopping_bag', 'order' => 4],
            ['name' => 'Tim & Area Sales', 'route' => '/master/surabaya', 'icon' => 'users', 'order' => 5],
            ['name' => 'Insentif Distributor', 'route' => '/incentives/distributor', 'icon' => 'coins', 'order' => 6],
            ['name' => 'Insentif Industri', 'route' => '/incentives/industri', 'icon' => 'factory', 'order' => 7],
            ['name' => 'Insentif Surabaya', 'route' => '/incentives/surabaya', 'icon' => 'landmark', 'order' => 8],
            ['name' => 'Skema & Bobot', 'route' => '/settings/incentives', 'icon' => 'sliders', 'order' => 9],
            ['name' => 'Bulk Upload Data', 'route' => '/bulk-upload', 'icon' => 'upload_cloud', 'order' => 10],
            ['name' => 'Pengguna & Akses', 'route' => '/users', 'icon' => 'shield', 'order' => 11],
        ];

        // 1. Capture existing permissions from legacy grouped menus before removing them
        $legacyMasterMenu = Menu::where('route', '/master')->first();
        $legacyCalcMenu = Menu::where('route', '/incentives/calculate')->first();

        $legacyMasterPerms = $legacyMasterMenu
            ? RoleMenuPermission::where('menu_id', $legacyMasterMenu->id)->get()->keyBy('role_id')
            : collect();
        $legacyCalcPerms = $legacyCalcMenu
            ? RoleMenuPermission::where('menu_id', $legacyCalcMenu->id)->get()->keyBy('role_id')
            : collect();

        // 2. Upsert all 11 canonical sidebar menus
        $menuByRoute = [];
        foreach ($canonicalMenus as $item) {
            $menu = Menu::updateOrCreate(
                ['route' => $item['route']],
                [
                    'name' => $item['name'],
                    'icon' => $item['icon'],
                    'order' => $item['order'],
                    'parent_id' => null,
                ]
            );
            $menuByRoute[$item['route']] = $menu;
        }

        // 3. Migrate permissions for all roles
        $masterRoutes = ['/master/distributor', '/master/target', '/master/realisasi', '/master/surabaya'];
        $calcRoutes = ['/incentives/distributor', '/incentives/industri', '/incentives/surabaya'];

        $roles = Role::all();
        foreach ($roles as $role) {
            $roleName = strtolower(trim((string) $role->name));
            $isAdmin = in_array($roleName, ['administrator', 'superadmin', 'admin'], true);

            if ($isAdmin) {
                foreach ($menuByRoute as $menu) {
                    RoleMenuPermission::updateOrCreate(
                        ['role_id' => $role->id, 'menu_id' => $menu->id],
                        [
                            'can_view' => true,
                            'can_create' => true,
                            'can_update' => true,
                            'can_delete' => true,
                        ]
                    );
                }
                continue;
            }

            // Inherit legacy /master permissions into the 4 split master menus
            if ($legacyMasterPerms->has($role->id)) {
                $p = $legacyMasterPerms->get($role->id);
                foreach ($masterRoutes as $r) {
                    RoleMenuPermission::firstOrCreate(
                        ['role_id' => $role->id, 'menu_id' => $menuByRoute[$r]->id],
                        [
                            'can_view' => (bool) $p->can_view,
                            'can_create' => (bool) $p->can_create,
                            'can_update' => (bool) $p->can_update,
                            'can_delete' => (bool) $p->can_delete,
                        ]
                    );
                }
            }

            // Inherit legacy /incentives/calculate permissions into the 3 split incentive menus
            if ($legacyCalcPerms->has($role->id)) {
                $p = $legacyCalcPerms->get($role->id);
                foreach ($calcRoutes as $r) {
                    RoleMenuPermission::firstOrCreate(
                        ['role_id' => $role->id, 'menu_id' => $menuByRoute[$r]->id],
                        [
                            'can_view' => (bool) $p->can_view,
                            'can_create' => (bool) $p->can_create,
                            'can_update' => (bool) $p->can_update,
                            'can_delete' => (bool) $p->can_delete,
                        ]
                    );
                }
            }
        }

        // 4. Remove obsolete legacy grouped menus no longer in sidebar
        $obsoleteRoutes = ['/master', '/incentives/calculate', '/reports/incentives'];
        $obsoleteIds = Menu::whereIn('route', $obsoleteRoutes)->pluck('id');
        if ($obsoleteIds->isNotEmpty()) {
            RoleMenuPermission::whereIn('menu_id', $obsoleteIds)->delete();
            Menu::whereIn('id', $obsoleteIds)->delete();
        }
    }

    public function down(): void
    {
        // Non-destructive rollback: keep canonical menus intact
    }
};

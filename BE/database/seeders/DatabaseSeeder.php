<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\MasterTarget;
use App\Models\Menu;
use App\Models\PercentTarget;
use App\Models\Position;
use App\Models\Region;
use App\Models\Role;
use App\Models\RoleMenuPermission;
use App\Models\SalesDistributorAssignment;
use App\Models\SalesSurabayaAssignment;
use App\Models\SellinDistributor;
use App\Models\SellinIndustri;
use App\Models\SelloutSalesSurabaya;
use App\Models\TargetHeader;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Roles
        $adminRole = Role::create([
            'name' => 'Administrator',
            'display_name' => 'System Administrator',
            'description' => 'Akses penuh ke seluruh konfigurasi master data dan kalkulasi',
        ]);

        $adminSalesRole = Role::create([
            'name' => 'Admin Sales',
            'display_name' => 'Administrator Sales & Data',
            'description' => 'Akses upload batch transaksi dan eksekusi kalkulasi insentif',
        ]);

        $salesRole = Role::create([
            'name' => 'Sales',
            'display_name' => 'Sales Personil',
            'description' => 'Melihat target kuota dan pencapaian reward insentif pribadi',
        ]);

        // 2. Positions
        $posNsm = Position::create(['name' => 'National Sales Manager', 'code' => 'NSM', 'is_active' => true]);
        $posLsm = Position::create(['name' => 'Line / Local Sales Manager', 'code' => 'LSM', 'is_active' => true]);
        $posAsm = Position::create(['name' => 'Area Sales Manager', 'code' => 'ASM', 'is_active' => true]);
        $posSpv = Position::create(['name' => 'Sales Supervisor', 'code' => 'SPV', 'is_active' => true]);
        $posCoord = Position::create(['name' => 'Sales Coordinator', 'code' => 'COORD', 'is_active' => true]);
        $posTo = Position::create(['name' => 'Sales Taking Order', 'code' => 'TO', 'is_active' => true]);
        $posCanvasing = Position::create(['name' => 'Sales Canvasing', 'code' => 'CANVAS', 'is_active' => true]);

        // 3. Menus & Permissions
        $menus = [
            ['name' => 'Dashboard', 'route' => '/dashboard', 'icon' => 'dashboard', 'order' => 1],
            ['name' => 'Master Data', 'route' => '/master', 'icon' => 'database', 'order' => 2],
            ['name' => 'Setting Insentif', 'route' => '/settings/incentives', 'icon' => 'tune', 'order' => 3],
            ['name' => 'Bulk Upload & Batch', 'route' => '/bulk-upload', 'icon' => 'cloud_upload', 'order' => 4],
            ['name' => 'Kalkulasi Insentif', 'route' => '/incentives/calculate', 'icon' => 'calculate', 'order' => 5],
            ['name' => 'Laporan & Riwayat', 'route' => '/reports/incentives', 'icon' => 'assessment', 'order' => 6],
        ];

        foreach ($menus as $m) {
            $menu = Menu::create($m);
            // Give admin full access
            RoleMenuPermission::create([
                'role_id' => $adminRole->id,
                'menu_id' => $menu->id,
                'can_view' => true,
                'can_create' => true,
                'can_update' => true,
                'can_delete' => true,
            ]);

            // Give admin sales access
            RoleMenuPermission::create([
                'role_id' => $adminSalesRole->id,
                'menu_id' => $menu->id,
                'can_view' => true,
                'can_create' => true,
                'can_update' => true,
                'can_delete' => false,
            ]);

            // Sales only view dashboard and report
            if (in_array($m['name'], ['Dashboard', 'Laporan & Riwayat'])) {
                RoleMenuPermission::create([
                    'role_id' => $salesRole->id,
                    'menu_id' => $menu->id,
                    'can_view' => true,
                    'can_create' => false,
                    'can_update' => false,
                    'can_delete' => false,
                ]);
            }
        }

        // 4. Users
        $adminUser = User::create([
            'name' => 'Administrator',
            'username' => 'admin',
            'email' => 'admin@company.com',
            'password' => Hash::make('admin123'),
            'role_id' => $adminRole->id,
            'position_id' => null,
            'aktif_from' => '2024-01-01',
            'aktif_to' => null,
            'is_eligible_konsumsi' => true,
            'is_eligible_industri' => true,
            'is_eligible_surabaya' => true,
        ]);

        $salesKonsumsi = User::create([
            'name' => 'Budi Santoso (ASM)',
            'username' => 'budi_asm',
            'email' => 'budi@company.com',
            'password' => Hash::make('password'),
            'role_id' => $salesRole->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2024-01-01',
            'aktif_to' => null,
            'is_eligible_konsumsi' => true,
            'is_eligible_industri' => false,
            'is_eligible_surabaya' => false,
        ]);

        $salesSpvKonsumsi = User::create([
            'name' => 'Rian Pratama (SPV Konsumsi)',
            'username' => 'rian_spv',
            'email' => 'rian@company.com',
            'password' => Hash::make('password'),
            'role_id' => $salesRole->id,
            'position_id' => $posSpv->id,
            'aktif_from' => '2024-01-01',
            'aktif_to' => null,
            'is_eligible_konsumsi' => true,
            'is_eligible_industri' => false,
            'is_eligible_surabaya' => false,
        ]);

        $salesIndustri = User::create([
            'name' => 'Dewi Lestari (Industri)',
            'username' => 'dewi_industri',
            'email' => 'dewi@company.com',
            'password' => Hash::make('password'),
            'role_id' => $salesRole->id,
            'position_id' => $posSpv->id,
            'aktif_from' => '2024-01-01',
            'aktif_to' => null,
            'is_eligible_konsumsi' => false,
            'is_eligible_industri' => true,
            'is_eligible_surabaya' => false,
        ]);

        $salesSurabaya = User::create([
            'name' => 'Eko Prasetyo (TO Surabaya)',
            'username' => 'eko_surabaya',
            'email' => 'eko@company.com',
            'password' => Hash::make('password'),
            'role_id' => $salesRole->id,
            'position_id' => $posTo->id,
            'aktif_from' => '2024-01-01',
            'aktif_to' => null,
            'is_eligible_konsumsi' => false,
            'is_eligible_industri' => false,
            'is_eligible_surabaya' => true,
        ]);

        // 5. Brands & Organization
        $brand1 = Brand::create(['code' => 'BRD01', 'name' => 'Indoprima Dairy']);
        $brand2 = Brand::create(['code' => 'BRD02', 'name' => 'Indoprima Sweet']);

        $reg1 = Region::create(['code' => 'REG01', 'name' => 'Jawa Timur & Bali', 'description' => 'Wilayah Jatim, Madura, dan Bali']);
        $reg2 = Region::create(['code' => 'REG02', 'name' => 'Jawa Tengah & DIY', 'description' => 'Wilayah Jateng dan DIY']);
        $reg3 = Region::create(['code' => 'REG03', 'name' => 'Jawa Barat & DKI', 'description' => 'Wilayah Jabar, DKI, dan Banten']);

        $dist1 = Distributor::create(['code' => 'DST01', 'name' => 'PT Sumber Rejeki Utama', 'region_id' => $reg1->id]);
        $depo1 = Depo::create(['distributor_id' => $dist1->id, 'code' => 'DP01', 'name' => 'Depo Surabaya Timur']);
        $area1 = Area::create(['depo_id' => $depo1->id, 'code' => 'AR01', 'name' => 'Rungkut & Sekitarnya']);

        // 6. Target Headers & 3-Level Incentive Structure
        // KONSUMSI: Sell-In ASM
        $headerKonsumsi = TargetHeader::create([
            'nama' => 'Insentif Sell-In ASM Konsumsi',
            'kategori_skema' => 'KONSUMSI',
            'sales_type' => $posAsm->id,
            'type' => 'Sell-In',
            'bobot' => 100.00,
            'aktif' => true,
            'aktif_from' => '20240101',
            'aktif_to' => '20301231',
        ]);

        $gradeKonsumsi1 = Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $headerKonsumsi->id,
            'grade_name' => 'Grade Regular (50 Ton - 200 Ton)',
            'target_from' => 50000.00,
            'target_to' => 200000.00,
        ]);

        GradeBobot::create([
            'id_grade' => $gradeKonsumsi1->id_grade,
            'bobot_name' => 'Tier 80% - 99.9%',
            'percent_from' => 80.00,
            'percent_to' => 99.99,
            'pengali' => true,
            'bobot' => 25.00, // Rp 25 per kg
            'nominal' => 0,
        ]);

        GradeBobot::create([
            'id_grade' => $gradeKonsumsi1->id_grade,
            'bobot_name' => 'Tier 100% - 120%',
            'percent_from' => 100.00,
            'percent_to' => 120.00,
            'pengali' => true,
            'bobot' => 50.00, // Rp 50 per kg
            'nominal' => 0,
        ]);

        // INDUSTRI: Sell-In Tonase
        $headerIndustri = TargetHeader::create([
            'nama' => 'Insentif Sell-In Industri SPV',
            'kategori_skema' => 'INDUSTRI',
            'sales_type' => $posSpv->id,
            'type' => 'Sell-In',
            'bobot' => 100.00,
            'aktif' => true,
            'aktif_from' => '20240101',
            'aktif_to' => '20301231',
        ]);

        $gradeIndustri1 = Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $headerIndustri->id,
            'grade_name' => 'Grade Tier 1 (10 - 100 Ton)',
            'target_from' => 10.00,
            'target_to' => 100.00,
        ]);

        GradeBobot::create([
            'id_grade' => $gradeIndustri1->id_grade,
            'bobot_name' => 'Pencapaian 100%+',
            'percent_from' => 100.00,
            'percent_to' => 150.00,
            'pengali' => false,
            'bobot' => 0,
            'nominal' => 5000000.00, // Lump-sum Rp 5.000.000
        ]);

        // SURABAYA: Sell-Out TO
        $headerSurabaya = TargetHeader::create([
            'nama' => 'Insentif Sell-Out Surabaya TO',
            'kategori_skema' => 'SURABAYA',
            'sales_type' => $posTo->id,
            'type' => 'Sell-Out',
            'bobot' => 100.00,
            'aktif' => true,
            'aktif_from' => '20240101',
            'aktif_to' => '20301231',
        ]);

        $gradeSby1 = Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $headerSurabaya->id,
            'grade_name' => 'Grade Retail (1.000 - 10.000 kg)',
            'target_from' => 1000.00,
            'target_to' => 10000.00,
        ]);

        GradeBobot::create([
            'id_grade' => $gradeSby1->id_grade,
            'bobot_name' => 'Target Tercapai 100% - 120%',
            'percent_from' => 100.00,
            'percent_to' => 120.00,
            'pengali' => true,
            'bobot' => 100.00, // Rp 100 per kg
            'nominal' => 0,
        ]);

        // 7. Master Targets & Transactions for Current Period (202610)
        $currentPeriod = '202610';

        // Target untuk Budi (Konsumsi)
        MasterTarget::create([
            'user_id' => $salesKonsumsi->id,
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'period' => $currentPeriod,
            'target_quota' => 100000.00, // 100.000 kg
        ]);

        // Transaksi Sell-In Konsumsi (Realisasi 105.000 kg = 105%)
        SellinDistributor::create([
            'batch_id' => null,
            'distributor_id' => $dist1->id,
            'brand_id' => $brand1->id,
            'period' => $currentPeriod,
            'volume_kg' => 105000.00,
            'nominal' => 2625000000.00,
            'sap_doc_no' => 'SAP-SI-202610-001',
        ]);

        // Target untuk Dewi (Industri)
        MasterTarget::create([
            'user_id' => $salesIndustri->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'Sell-In',
            'period' => $currentPeriod,
            'target_quota' => 50.00, // 50 Ton
        ]);

        // Transaksi Sell-In Industri (Realisasi 55 Ton = 110%)
        SellinIndustri::create([
            'batch_id' => null,
            'user_id' => $salesIndustri->id,
            'customer_name' => 'PT Roti Mas Jaya',
            'period' => $currentPeriod,
            'tonase' => 55.00,
            'sap_so_no' => 'SO-IND-202610-101',
        ]);

        // Target untuk Eko (Surabaya)
        MasterTarget::create([
            'user_id' => $salesSurabaya->id,
            'kategori_skema' => 'SURABAYA',
            'metrik_target' => 'Sell-Out',
            'period' => $currentPeriod,
            'target_quota' => 5000.00, // 5.000 kg
        ]);

        // Transaksi Sell-Out Surabaya (Realisasi 5.200 kg = 104%)
        SelloutSalesSurabaya::create([
            'batch_id' => null,
            'sales_id' => $salesSurabaya->id,
            'period' => $currentPeriod,
            'volume' => 5200.00,
            'active_outlet_count' => 45,
        ]);

        // 8. Percent Target Standards
        PercentTarget::create([
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'percent_min' => 0.00,
            'percent_max' => 79.99,
            'performance_status' => 'Under-Target',
            'badge_color' => 'Red',
            'is_eligible_payout' => false,
        ]);

        PercentTarget::create([
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'percent_min' => 80.00,
            'percent_max' => 99.99,
            'performance_status' => 'Near-Target',
            'badge_color' => 'Yellow',
            'is_eligible_payout' => true,
        ]);

        PercentTarget::create([
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'percent_min' => 100.00,
            'percent_max' => 120.00,
            'performance_status' => 'On-Target',
            'badge_color' => 'Green',
            'is_eligible_payout' => true,
        ]);

        PercentTarget::create([
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'percent_min' => 120.01,
            'percent_max' => 999.99,
            'performance_status' => 'Super-Achiever',
            'badge_color' => 'Blue',
            'is_eligible_payout' => true,
        ]);

        // 9. Initial Sales Assignments (Konsumsi Distributor & Surabaya)
        SalesDistributorAssignment::create([
            'user_id' => $salesKonsumsi->id,
            'distributor_id' => $dist1->id,
            'period' => '202610',
            'is_active' => true,
            'notes' => 'ASM Wilayah Timur memegang PT Sumber Rejeki Utama beserta deponya',
        ]);

        SalesDistributorAssignment::create([
            'user_id' => $salesSpvKonsumsi->id,
            'asm_id' => $salesKonsumsi->id,
            'distributor_id' => $dist1->id,
            'depo_id' => $depo1->id,
            'area_id' => $area1->id,
            'period' => '202610',
            'is_active' => true,
            'notes' => 'SPV Area Rungkut di bawah ASM Budi Santoso',
        ]);

        SalesSurabayaAssignment::create([
            'coordinator_id' => $adminUser->id,
            'sales_id' => $salesSurabaya->id,
            'sales_type' => 'Taking Order',
            'period' => '202610',
            'is_active' => true,
        ]);
    }
}

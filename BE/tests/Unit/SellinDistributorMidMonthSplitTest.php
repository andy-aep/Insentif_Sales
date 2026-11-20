<?php

namespace Tests\Unit;

use App\Models\Area;
use App\Models\Brand;
use App\Models\BrandItem;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SellinDistributor;
use App\Models\SelloutDistributor;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class SellinDistributorMidMonthSplitTest extends TestCase
{
    use RefreshDatabase;

    public function test_sellin_distributor_splits_turnover_by_sales_active_dates_and_resolves_brand_from_item(): void
    {
        $roleAdmin = Role::firstOrCreate(['name' => 'Administrator'], ['display_name' => 'Administrator']);
        $roleSales = Role::firstOrCreate(['name' => 'Sales'], ['display_name' => 'Sales Personil']);
        $posAsm = Position::firstOrCreate(['code' => 'ASM'], ['name' => 'Area Sales Manager', 'is_active' => true]);

        $admin = User::create([
            'name' => 'Admin',
            'username' => 'admin_split',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);

        // Sales A aktif 1-15 Juli 2026, Sales B aktif 16-31 Juli 2026
        $salesA = User::create([
            'name' => 'ASM Pertama',
            'username' => 'asm_pertama',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2026-01-01',
            'aktif_to' => '2026-07-15',
            'is_eligible_konsumsi' => true,
        ]);

        $salesB = User::create([
            'name' => 'ASM Pengganti',
            'username' => 'asm_pengganti',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2026-07-16',
            'aktif_to' => null,
            'is_eligible_konsumsi' => true,
        ]);

        $dist = Distributor::create(['code' => 'DST0001', 'name' => 'TUTON, CV']);
        $depo = Depo::create(['distributor_id' => $dist->id, 'code' => 'C110003336', 'name' => 'TEGAL']);
        $brandJempol = Brand::firstOrCreate(['code' => 'JEMPOL'], ['name' => 'JEMPOL']);
        BrandItem::firstOrCreate(['item_code' => 'HD22'], ['brand_id' => $brandJempol->id]);

        $this->assertEquals($brandJempol->id, Brand::resolveIdByItemCode('HD22'));

        $header = TargetHeader::create([
            'nama' => 'Sell-In ASM',
            'kategori_skema' => 'KONSUMSI',
            'sales_type' => $posAsm->id,
            'type' => 'SELL_IN',
            'bobot' => 100,
            'min_achievement_pct' => 50,
            'aktif' => true,
            'aktif_from' => '20260101',
            'aktif_to' => '20261231',
        ]);
        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $header->id,
            'grade_name' => 'Grade 1',
            'target_from' => 1000,
            'target_to' => 100000,
            'multiplier_rate' => 2,
        ]);

        MasterTarget::create([
            'user_id' => $salesA->id,
            'distributor_id' => $dist->id,
            'depo_id' => $depo->id,
            'brand_id' => $brandJempol->id,
            'kategori_skema' => 'KONSUMSI',
            'level' => 'DEPO',
            'metrik_target' => 'SELL_IN',
            'period' => '202607',
            'target_quota' => 10000,
        ]);

        MasterTarget::create([
            'user_id' => $salesB->id,
            'distributor_id' => $dist->id,
            'depo_id' => $depo->id,
            'brand_id' => $brandJempol->id,
            'kategori_skema' => 'KONSUMSI',
            'level' => 'DEPO',
            'metrik_target' => 'SELL_IN',
            'period' => '202607',
            'target_quota' => 10000,
        ]);

        // Transaksi tanggal 10 Juli (10.000 Kg) -> milik Sales A
        SellinDistributor::create([
            'distributor_id' => $dist->id,
            'depo_id' => $depo->id,
            'brand_id' => $brandJempol->id,
            'item_code' => 'HD22',
            'period' => '202607',
            'transaction_date' => '2026-07-10',
            'volume_kg' => 10000,
            'nominal' => 50000000,
            'sap_doc_no' => '260710001',
        ]);

        // Transaksi tanggal 20 Juli (15.000 Kg) -> milik Sales B
        SellinDistributor::create([
            'distributor_id' => $dist->id,
            'depo_id' => $depo->id,
            'brand_id' => $brandJempol->id,
            'item_code' => 'HD22',
            'period' => '202607',
            'transaction_date' => '2026-07-20',
            'volume_kg' => 15000,
            'nominal' => 75000000,
            'sap_doc_no' => '260720001',
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('KONSUMSI', '202607', $admin->id);

        $resA = $results->firstWhere('user_id', $salesA->id);
        $resB = $results->firstWhere('user_id', $salesB->id);

        $this->assertEquals(10000.0, (float) $resA->realization);
        $this->assertEquals(15000.0, (float) $resB->realization);
    }

    public function test_asm_owns_all_areas_under_depo_while_spv_and_asc_only_own_their_area_sellout_plus_depo_sellin_weight(): void
    {
        $roleAdmin = Role::firstOrCreate(['name' => 'Administrator'], ['display_name' => 'Administrator']);
        $roleSales = Role::firstOrCreate(['name' => 'Sales'], ['display_name' => 'Sales Personil']);
        $posAsm = Position::firstOrCreate(['code' => 'ASM'], ['name' => 'Area Sales Manager', 'is_active' => true]);
        $posSpv = Position::firstOrCreate(['code' => 'SPV'], ['name' => 'Sales Supervisor', 'is_active' => true]);
        $posAsc = Position::firstOrCreate(['code' => 'ASC'], ['name' => 'Area Sales Coordinator', 'is_active' => true]);

        $admin = User::create([
            'name' => 'Admin Test',
            'username' => 'admin_hier',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);

        $lisa = User::create([
            'name' => 'Lisa ASM',
            'username' => 'lisa_asm',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2026-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $bayu = User::create([
            'name' => 'Bayu SPV',
            'username' => 'bayu_spv',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posSpv->id,
            'aktif_from' => '2026-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $alex = User::create([
            'name' => 'Alex ASC',
            'username' => 'alex_asc',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsc->id,
            'aktif_from' => '2026-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $dist = Distributor::create(['code' => 'DST-H', 'name' => 'PT Hierarki']);
        $depo = Depo::create(['distributor_id' => $dist->id, 'code' => 'DP-H', 'name' => 'Depo Utama']);
        $areaBayu = Area::create(['depo_id' => $depo->id, 'code' => 'AR-BAYU', 'name' => 'Area Bayu']);
        $areaAlex = Area::create(['depo_id' => $depo->id, 'code' => 'AR-ALEX', 'name' => 'Area Alex']);
        $brand = Brand::firstOrCreate(['code' => 'KAPAL'], ['name' => 'KAPAL']);

        // Header ASM: SELL_IN (bobot 70%) + SELL_OUT (bobot 30%)
        $asmSiHeader = TargetHeader::create([
            'nama' => 'ASM Sell-In', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsm->id,
            'type' => 'SELL_IN', 'bobot' => 70, 'min_achievement_pct' => 50, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gAsmSi = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $asmSiHeader->id, 'grade_name' => 'G1', 'target_from' => 1000, 'target_to' => 100000, 'multiplier_rate' => 10]);
        GradeBobot::create(['id_grade' => $gAsmSi->id_grade, 'bobot_name' => 'B1', 'percent_from' => 50, 'percent_to' => 200, 'bobot' => 10, 'pengali' => true, 'nominal' => 0]);

        $asmSoHeader = TargetHeader::create([
            'nama' => 'ASM Sell-Out', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsm->id,
            'type' => 'SELL_OUT', 'bobot' => 30, 'min_achievement_pct' => 50, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gAsmSo = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $asmSoHeader->id, 'grade_name' => 'G1', 'target_from' => 1000, 'target_to' => 100000, 'multiplier_rate' => 10]);
        GradeBobot::create(['id_grade' => $gAsmSo->id_grade, 'bobot_name' => 'B1', 'percent_from' => 50, 'percent_to' => 200, 'bobot' => 10, 'pengali' => true, 'nominal' => 0]);

        // Header SPV: SELL_IN (bobot 30% - berbeda dari ASM!) + SELL_OUT (bobot 70%)
        $spvSiHeader = TargetHeader::create([
            'nama' => 'SPV Sell-In', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posSpv->id,
            'type' => 'SELL_IN', 'bobot' => 30, 'min_achievement_pct' => 50, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gSpvSi = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $spvSiHeader->id, 'grade_name' => 'G1', 'target_from' => 1000, 'target_to' => 100000, 'multiplier_rate' => 10]);
        GradeBobot::create(['id_grade' => $gSpvSi->id_grade, 'bobot_name' => 'B1', 'percent_from' => 50, 'percent_to' => 200, 'bobot' => 10, 'pengali' => true, 'nominal' => 0]);

        $spvSoHeader = TargetHeader::create([
            'nama' => 'SPV Sell-Out', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posSpv->id,
            'type' => 'SELL_OUT', 'bobot' => 70, 'min_achievement_pct' => 50, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gSpvSo = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $spvSoHeader->id, 'grade_name' => 'G1', 'target_from' => 1000, 'target_to' => 100000, 'multiplier_rate' => 10]);
        GradeBobot::create(['id_grade' => $gSpvSo->id_grade, 'bobot_name' => 'B1', 'percent_from' => 50, 'percent_to' => 200, 'bobot' => 10, 'pengali' => true, 'nominal' => 0]);

        // Header ASC: SELL_OUT (bobot 100%)
        $ascSoHeader = TargetHeader::create([
            'nama' => 'ASC Sell-Out', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsc->id,
            'type' => 'SELL_OUT', 'bobot' => 100, 'min_achievement_pct' => 50, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gAscSo = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $ascSoHeader->id, 'grade_name' => 'G1', 'target_from' => 1000, 'target_to' => 100000, 'multiplier_rate' => 10]);
        GradeBobot::create(['id_grade' => $gAscSo->id_grade, 'bobot_name' => 'B1', 'percent_from' => 50, 'percent_to' => 200, 'bobot' => 10, 'pengali' => true, 'nominal' => 0]);

        // Targets: Lisa pegang Depo (Sell-In 20.000, Sell-Out 10.000), Bayu Area 1 (5.000), Alex Area 2 (5.000)
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'DEPO', 'metrik_target' => 'SELL_IN', 'period' => '202607', 'target_quota' => 20000]);
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'DEPO', 'metrik_target' => 'SELL_OUT', 'period' => '202607', 'target_quota' => 10000]);
        MasterTarget::create(['user_id' => $bayu->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaBayu->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'AREA', 'metrik_target' => 'SELL_OUT', 'period' => '202607', 'target_quota' => 5000]);
        MasterTarget::create(['user_id' => $alex->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaAlex->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'AREA', 'metrik_target' => 'SELL_OUT', 'period' => '202607', 'target_quota' => 5000]);

        // Realisasi: Sell-In Depo = 20.000 Kg, Sell-Out Area Bayu = 4.000 Kg, Sell-Out Area Alex = 6.000 Kg
        SellinDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depo->id, 'brand_id' => $brand->id, 'period' => '202607', 'transaction_date' => '2026-07-10', 'volume_kg' => 20000, 'nominal' => 100000000]);
        SelloutDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaBayu->id, 'brand_id' => $brand->id, 'period' => '202607', 'volume_kg' => 4000, 'active_outlet_count' => 10]);
        SelloutDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaAlex->id, 'brand_id' => $brand->id, 'period' => '202607', 'volume_kg' => 6000, 'active_outlet_count' => 12]);

        $results = app(IncentiveCalculationService::class)->execute('KONSUMSI', '202607', $admin->id);

        $lisaSi = $results->first(fn ($r) => $r->user_id === $lisa->id && $r->target_header_id === $asmSiHeader->id);
        $lisaSo = $results->first(fn ($r) => $r->user_id === $lisa->id && $r->target_header_id === $asmSoHeader->id);
        $bayuSi = $results->first(fn ($r) => $r->user_id === $bayu->id && $r->target_header_id === $spvSiHeader->id);
        $bayuSo = $results->first(fn ($r) => $r->user_id === $bayu->id && $r->target_header_id === $spvSoHeader->id);
        $alexSo = $results->first(fn ($r) => $r->user_id === $alex->id && $r->target_header_id === $ascSoHeader->id);

        // Lisa ASM: Sell-In Depo = 20.000 Kg (bobot 70%), Sell-Out Depo = 4.000 + 6.000 = 10.000 Kg (bobot 30%)
        $this->assertEquals(20000.0, (float) $lisaSi->realization);
        $this->assertEquals(140000.0, (float) $lisaSi->final_reward); // 20000 * 10 * 70%
        $this->assertEquals(10000.0, (float) $lisaSo->realization);

        // Bayu SPV: Sell-In Depo = 20.000 Kg (bobot 30%!), Sell-Out Area Bayu SAJA = 4.000 Kg (tidak ambil Area Alex)
        $this->assertEquals(20000.0, (float) $bayuSi->realization);
        $this->assertEquals(60000.0, (float) $bayuSi->final_reward); // 20000 * 10 * 30%
        $this->assertEquals(4000.0, (float) $bayuSo->realization);

        // Alex ASC: Sell-Out Area Alex SAJA = 6.000 Kg (tidak ambil Area Bayu)
        $this->assertEquals(6000.0, (float) $alexSo->realization);
    }

    public function test_distributor_breakdown_excel_formula_no_cap_and_ao_dependency_rule(): void
    {
        $roleSales = Role::firstOrCreate(['name' => 'Sales'], ['display_name' => 'Sales']);
        $roleAdmin = Role::firstOrCreate(['name' => 'Administrator'], ['display_name' => 'Administrator']);
        $posAsm = Position::firstOrCreate(['code' => 'ASM'], ['name' => 'Area Sales Manager']);

        $admin = User::create([
            'name' => 'Admin Test', 'username' => 'admin_excel', 'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id, 'aktif_from' => '2024-01-01',
        ]);
        $lisa = User::create([
            'name' => 'Lisa ASM', 'username' => 'lisa_excel', 'password' => Hash::make('password'),
            'role_id' => $roleSales->id, 'position_id' => $posAsm->id, 'aktif_from' => '2026-01-01',
        ]);

        $dist = Distributor::create(['code' => 'DST_SKT', 'name' => 'SAKTI']);
        $depo = Depo::create(['distributor_id' => $dist->id, 'code' => 'DP_BJG', 'name' => 'BOJONEGORO']);
        $areaB = Area::create(['depo_id' => $depo->id, 'code' => 'AR_BJG', 'name' => 'BOJONEGORO']);
        $depoFail = Depo::create(['distributor_id' => $dist->id, 'code' => 'DP_TBN', 'name' => 'TUBAN']);
        $areaFail = Area::create(['depo_id' => $depoFail->id, 'code' => 'AR_TBN', 'name' => 'TUBAN']);
        $brand = Brand::firstOrCreate(['code' => 'KAPAL'], ['name' => 'KAPAL']);

        // 3 Header ASM: SI (20%, min 80%), SO (80%, min 85%), AO (50%, min 90% Nominal Flat 20.000)
        $siHeader = TargetHeader::create([
            'nama' => 'ASM SI', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsm->id,
            'type' => 'SELL_IN', 'bobot' => 20, 'min_achievement_pct' => 80, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gSi = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $siHeader->id, 'grade_name' => 'G1', 'target_from' => 2000, 'target_to' => 23999, 'multiplier_rate' => 4]);
        GradeBobot::create(['id_grade' => $gSi->id_grade, 'bobot_name' => '100%', 'percent_from' => 100, 'percent_to' => 500, 'bobot' => 4, 'pengali' => true, 'nominal' => 0]);

        $soHeader = TargetHeader::create([
            'nama' => 'ASM SO', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsm->id,
            'type' => 'SELL_OUT', 'bobot' => 80, 'min_achievement_pct' => 85, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gSo = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $soHeader->id, 'grade_name' => 'G1', 'target_from' => 2000, 'target_to' => 23999, 'multiplier_rate' => 4]);
        GradeBobot::create(['id_grade' => $gSo->id_grade, 'bobot_name' => '100%', 'percent_from' => 100, 'percent_to' => 500, 'bobot' => 4, 'pengali' => true, 'nominal' => 0]);

        $aoHeader = TargetHeader::create([
            'nama' => 'ASM AO', 'kategori_skema' => 'KONSUMSI', 'sales_type' => $posAsm->id,
            'type' => 'AO', 'bobot' => 50, 'min_achievement_pct' => 90, 'aktif' => true,
            'aktif_from' => '20260101', 'aktif_to' => '20261231',
        ]);
        $gAo = Grade::create(['id_grade' => (string) Str::uuid(), 'target_header_id' => $aoHeader->id, 'grade_name' => 'G1', 'target_from' => 1, 'target_to' => 1000, 'multiplier_rate' => 0]);
        GradeBobot::create(['id_grade' => $gAo->id_grade, 'bobot_name' => '90%', 'percent_from' => 90, 'percent_to' => 500, 'bobot' => 0, 'pengali' => false, 'nominal' => 20000]);

        // Case 1 (sesuai Excel): Bojonegoro SI 18.000/18.000 (100% -> 72.000*20% = 14.400), SO 5.000/2.000 (250% tanpa cap -> 20.000*80% = 16.000), AO 10/10 (100% -> 20.000*50% = 10.000) => Total 40.400
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'DEPO', 'metrik_target' => 'SELL_IN', 'period' => '202607', 'target_quota' => 18000]);
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaB->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'AREA', 'metrik_target' => 'SELL_OUT', 'period' => '202607', 'target_quota' => 2000, 'target_outlet' => 10]);

        SellinDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depo->id, 'brand_id' => $brand->id, 'period' => '202607', 'transaction_date' => '2026-07-10', 'volume_kg' => 18000, 'nominal' => 90000000]);
        SelloutDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depo->id, 'area_id' => $areaB->id, 'brand_id' => $brand->id, 'period' => '202607', 'volume_kg' => 5000, 'active_outlet_count' => 10]);

        // Case 2 (Aturan 3 AO): Tuban SI 0/18.000 (gagal), SO 0/2.000 (gagal), tapi AO 10/10 (100%) => AO wajib 0 karena SI & SO gagal semua!
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depoFail->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'DEPO', 'metrik_target' => 'SELL_IN', 'period' => '202607', 'target_quota' => 18000]);
        MasterTarget::create(['user_id' => $lisa->id, 'distributor_id' => $dist->id, 'depo_id' => $depoFail->id, 'area_id' => $areaFail->id, 'brand_id' => $brand->id, 'kategori_skema' => 'KONSUMSI', 'level' => 'AREA', 'metrik_target' => 'SELL_OUT', 'period' => '202607', 'target_quota' => 2000, 'target_outlet' => 10]);
        SelloutDistributor::create(['distributor_id' => $dist->id, 'depo_id' => $depoFail->id, 'area_id' => $areaFail->id, 'brand_id' => $brand->id, 'period' => '202607', 'volume_kg' => 0, 'active_outlet_count' => 10]);

        $res = $this->actingAs($admin)->getJson("/api/incentives/distributor-breakdown?period=202607&user_id={$lisa->id}");
        $res->assertStatus(200);
        $cards = collect($res->json('data'));

        $bjg = $cards->firstWhere('depo_name', 'BOJONEGORO');
        $this->assertNotNull($bjg);
        $this->assertEquals(14400.0, (float) $bjg['sell_in_reward']);
        $this->assertEquals(16000.0, (float) $bjg['areas'][0]['sell_out_reward']);
        $this->assertEquals(10000.0, (float) $bjg['areas'][0]['ao_reward']);
        $this->assertEquals(40400.0, (float) $bjg['total_depo_reward']);

        $tbn = $cards->firstWhere('depo_name', 'TUBAN');
        $this->assertNotNull($tbn);
        $this->assertEquals(0.0, (float) $tbn['areas'][0]['ao_reward']);
        $this->assertEquals(0.0, (float) $tbn['total_depo_reward']);
    }
}

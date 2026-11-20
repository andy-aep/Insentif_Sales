<?php

namespace Tests\Unit;

use App\Models\Grade;
use App\Models\IncentiveCalculation;
use App\Models\IndustriCustomer;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SalesIndustriAssignment;
use App\Models\SellinIndustri;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class IndustriIncentiveCalculationTest extends TestCase
{
    use RefreshDatabase;

    private Role $roleAdmin;
    private Role $roleSales;
    private Position $posAsm;
    private Position $posSpv;
    private Position $posAsc;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->roleAdmin = Role::firstOrCreate(
            ['name' => 'Administrator'],
            ['display_name' => 'Administrator']
        );
        $this->roleSales = Role::firstOrCreate(
            ['name' => 'Sales'],
            ['display_name' => 'Sales Personil']
        );

        $this->posAsm = Position::firstOrCreate(
            ['code' => 'ASM'],
            ['name' => 'Area Sales Manager', 'is_active' => true]
        );
        $this->posSpv = Position::firstOrCreate(
            ['code' => 'SPV'],
            ['name' => 'Sales Supervisor', 'is_active' => true]
        );
        $this->posAsc = Position::where('code', 'ASC')->firstOrFail();

        $this->admin = User::create([
            'name' => 'Admin Test',
            'username' => 'admin_test',
            'password' => Hash::make('password'),
            'role_id' => $this->roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);
    }

    private function createIndustriHeadersForPosition(Position $position): array
    {
        $sellInHeader = TargetHeader::create([
            'nama' => "Insentif Sell-In Industri {$position->code}",
            'kategori_skema' => 'INDUSTRI',
            'sales_type' => $position->id,
            'type' => 'SELL_IN',
            'bobot' => 70.00,
            'min_achievement_pct' => 80.00,
            'aktif' => true,
            'aktif_from' => '20250101',
            'aktif_to' => '20301231',
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $sellInHeader->id,
            'grade_name' => 'Grade 1',
            'target_from' => 10000,
            'target_to' => 50000,
            'multiplier_rate' => 1,
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $sellInHeader->id,
            'grade_name' => 'Grade 2',
            'target_from' => 50001,
            'target_to' => 100000,
            'multiplier_rate' => 2,
        ]);

        $nooHeader = TargetHeader::create([
            'nama' => "Insentif NOO Industri {$position->code}",
            'kategori_skema' => 'INDUSTRI',
            'sales_type' => $position->id,
            'type' => 'NOO',
            'bobot' => 30.00,
            'min_achievement_pct' => 50.00,
            'aktif' => true,
            'aktif_from' => '20250101',
            'aktif_to' => '20301231',
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $nooHeader->id,
            'grade_name' => 'Grade 1',
            'target_from' => 1,
            'target_to' => 10,
            'multiplier_rate' => 100,
        ]);

        return [$sellInHeader, $nooHeader];
    }

    public function test_andre_spv_exact_simulation_without_cap(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $andre = User::create([
            'name' => 'Andre',
            'username' => 'andre_spv',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $period = '202611';

        MasterTarget::create([
            'user_id' => $andre->id,
            'kategori_skema' => 'INDUSTRI',
            'level' => 'SALES',
            'metrik_target' => 'SELL_IN',
            'period' => $period,
            'target_quota' => 40000,
        ]);

        MasterTarget::create([
            'user_id' => $andre->id,
            'kategori_skema' => 'INDUSTRI',
            'level' => 'SALES',
            'metrik_target' => 'NOO',
            'period' => $period,
            'target_quota' => 2,
        ]);

        // Customer Existing: sudah pernah transaksi awal 202604 (tahun yang sama, bukan NOO di 202611)
        $custExisting = IndustriCustomer::create([
            'customer_code' => 'IND-EXT-01',
            'customer_name' => 'PT Roti Lama Tbk',
            'customer_type' => 'EXISTING',
            'first_transaction_period' => '202604',
            'is_active' => true,
        ]);

        // Customer Baru: pertama kali beli di 202611 sebesar 10.000 Kg (NOO)
        $custNew = IndustriCustomer::create([
            'customer_code' => 'IND-NEW-01',
            'customer_name' => 'CV Biskuit Baru Jaya',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $andre->id,
            'industri_customer_id' => $custExisting->id,
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $andre->id,
            'industri_customer_id' => $custNew->id,
            'is_active' => true,
        ]);

        SellinIndustri::create([
            'user_id' => $andre->id,
            'industri_customer_id' => $custExisting->id,
            'customer_code' => $custExisting->customer_code,
            'customer_name' => $custExisting->customer_name,
            'period' => $period,
            'tonase' => 40000,
            'volume_kg' => 40000,
            'sap_so_no' => 'SO-202611-001',
        ]);

        SellinIndustri::create([
            'user_id' => $andre->id,
            'industri_customer_id' => $custNew->id,
            'customer_code' => $custNew->customer_code,
            'customer_name' => $custNew->customer_name,
            'period' => $period,
            'tonase' => 10000,
            'volume_kg' => 10000,
            'sap_so_no' => 'SO-202611-002',
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('INDUSTRI', $period, $this->admin->id, $this->posSpv->id, $andre->id);

        $this->assertCount(2, $results);

        $sellInRow = $results->firstWhere('targetHeader.type', 'SELL_IN');
        $nooRow = $results->firstWhere('targetHeader.type', 'NOO');

        // Sell In: Target 40.000, Actual 50.000 (125% >= 80%), NO CAP -> (50.000 * 1) * 70% = 35.000
        $this->assertEquals(40000.0, (float) $sellInRow->target_quota);
        $this->assertEquals(50000.0, (float) $sellInRow->realization);
        $this->assertEquals(125.0, (float) $sellInRow->achievement_percent);
        $this->assertTrue($sellInRow->is_passed);
        $this->assertEquals(50000.0, (float) $sellInRow->capped_realization);
        $this->assertEquals(35000.0, (float) $sellInRow->final_reward);

        // NOO: Target 2, Actual 1 (50% >= 50%), Volume 10.000 Kg -> (10.000 * 100) * 30% = 300.000
        $this->assertEquals(2.0, (float) $nooRow->target_quota);
        $this->assertEquals(1.0, (float) $nooRow->realization);
        $this->assertEquals(10000.0, (float) $nooRow->noo_volume_kg);
        $this->assertEquals(50.0, (float) $nooRow->achievement_percent);
        $this->assertTrue($nooRow->is_passed);
        $this->assertEquals(300000.0, (float) $nooRow->final_reward);

        // Grand total = 335.000
        $this->assertEquals(335000.0, (float) $results->sum('final_reward'));

        // Cek endpoint breakdown JSON API
        $res = $this->actingAs($this->admin)->getJson("/api/incentives/industri-breakdown?period={$period}&user_id={$andre->id}");
        $res->assertStatus(200)
            ->assertJsonPath('meta.total_payout', 335000)
            ->assertJsonPath('data.0.user_name', 'Andre')
            ->assertJsonPath('data.0.sell_in.final_reward', 35000)
            ->assertJsonPath('data.0.noo.final_reward', 300000)
            ->assertJsonPath('data.0.total_reward', 335000);
    }

    public function test_ineligible_user_gets_zero_and_cleans_stale_results(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $sales = User::create([
            'name' => 'Non Eligible Sales',
            'username' => 'non_eligible_spv',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => false,
        ]);

        $period = '202611';

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'SELL_IN',
            'period' => $period,
            'target_quota' => 20000,
        ]);

        $cust = IndustriCustomer::create([
            'customer_code' => 'IND-C01',
            'customer_name' => 'PT Customer C01',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'is_active' => true,
        ]);

        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'customer_name' => $cust->customer_name,
            'period' => $period,
            'tonase' => 30000,
            'volume_kg' => 30000,
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('INDUSTRI', $period, $this->admin->id, null, $sales->id);

        $this->assertCount(0, $results);
        $this->assertEquals(0, IncentiveCalculation::where('user_id', $sales->id)->count());

        $breakdown = $service->evaluateIndustriForPeriod($period, null, $sales->id, null, true);
        $this->assertFalse($breakdown['cards'][0]['is_eligible_industri']);
        $this->assertEquals(0.0, $breakdown['cards'][0]['total_reward']);
    }

    public function test_below_min_achievement_pct_returns_zero_reward(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $sales = User::create([
            'name' => 'Budi SPV',
            'username' => 'budi_ind',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $period = '202611';

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'SELL_IN',
            'period' => $period,
            'target_quota' => 50000,
        ]);

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'NOO',
            'period' => $period,
            'target_quota' => 4,
        ]);

        $cust = IndustriCustomer::create([
            'customer_code' => 'IND-LOW-01',
            'customer_name' => 'PT Low Ach',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'is_active' => true,
        ]);

        // Sell In = 39.500 / 50.000 = 79% (< 80%), NOO = 1 / 4 = 25% (< 50%)
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'customer_name' => $cust->customer_name,
            'period' => $period,
            'tonase' => 39500,
            'volume_kg' => 39500,
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('INDUSTRI', $period, $this->admin->id, null, $sales->id);

        $this->assertCount(2, $results);
        foreach ($results as $row) {
            $this->assertFalse($row->is_passed);
            $this->assertEquals(0.0, (float) $row->final_reward);
        }
    }

    public function test_repeat_purchase_later_in_same_year_is_not_counted_as_noo(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $sales = User::create([
            'name' => 'Citra SPV',
            'username' => 'citra_ind',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $cust = IndustriCustomer::create([
            'customer_code' => 'IND-RPT-01',
            'customer_name' => 'PT Repeat Order',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'is_active' => true,
        ]);

        // Bulan 202611: pembelian pertama (NOO)
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'customer_name' => $cust->customer_name,
            'period' => '202611',
            'tonase' => 15000,
            'volume_kg' => 15000,
        ]);

        // Bulan 202612: repeat purchase oleh customer yg sama di tahun berjalan
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $cust->id,
            'customer_name' => $cust->customer_name,
            'period' => '202612',
            'tonase' => 25000,
            'volume_kg' => 25000,
        ]);

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'NOO',
            'period' => '202612',
            'target_quota' => 1,
        ]);

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'SELL_IN',
            'period' => '202612',
            'target_quota' => 20000,
        ]);

        $service = app(IncentiveCalculationService::class);
        $resultsDec = $service->execute('INDUSTRI', '202612', $this->admin->id, null, $sales->id);

        $sellInDec = $resultsDec->firstWhere('targetHeader.type', 'SELL_IN');
        $nooDec = $resultsDec->firstWhere('targetHeader.type', 'NOO');

        $this->assertEquals(25000.0, (float) $sellInDec->realization);
        $this->assertEquals(17500.0, (float) $sellInDec->final_reward); // 25000 * 1 * 70%
        $this->assertEquals(0.0, (float) $nooDec->realization);
        $this->assertEquals(0.0, (float) $nooDec->noo_volume_kg);
        $this->assertEquals(0.0, (float) $nooDec->final_reward);
    }

    public function test_unassigned_customer_transactions_are_excluded(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $sales = User::create([
            'name' => 'Dedi SPV',
            'username' => 'dedi_ind',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $period = '202611';

        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'INDUSTRI',
            'metrik_target' => 'SELL_IN',
            'period' => $period,
            'target_quota' => 20000,
        ]);

        $assignedCust = IndustriCustomer::create([
            'customer_code' => 'IND-ASG-01',
            'customer_name' => 'PT Assigned',
            'customer_type' => 'EXISTING',
            'is_active' => true,
        ]);

        $unassignedCust = IndustriCustomer::create([
            'customer_code' => 'IND-UNASG-01',
            'customer_name' => 'PT Unassigned',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $assignedCust->id,
            'is_active' => true,
        ]);

        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $assignedCust->id,
            'customer_name' => $assignedCust->customer_name,
            'period' => $period,
            'tonase' => 20000,
            'volume_kg' => 20000,
        ]);

        // Walau user_id menunjuk Dedi, customer tidak di-assign -> wajib diabaikan
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $unassignedCust->id,
            'customer_name' => $unassignedCust->customer_name,
            'period' => $period,
            'tonase' => 50000,
            'volume_kg' => 50000,
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('INDUSTRI', $period, $this->admin->id, null, $sales->id);
        $sellIn = $results->firstWhere('targetHeader.type', 'SELL_IN');

        $this->assertEquals(20000.0, (float) $sellIn->realization);
        $this->assertEquals(14000.0, (float) $sellIn->final_reward); // 20.000 * 1 * 70%
    }

    public function test_supports_asm_spv_and_asc_positions(): void
    {
        $this->createIndustriHeadersForPosition($this->posAsm);
        $this->createIndustriHeadersForPosition($this->posAsc);

        $asmUser = User::create([
            'name' => 'ASM Industri',
            'username' => 'asm_ind',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posAsm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $ascUser = User::create([
            'name' => 'ASC Industri',
            'username' => 'asc_ind',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posAsc->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $period = '202611';

        $custAsm = IndustriCustomer::create([
            'customer_code' => 'IND-ASM-1',
            'customer_name' => 'PT Customer ASM',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        $custAsc = IndustriCustomer::create([
            'customer_code' => 'IND-ASC-1',
            'customer_name' => 'PT Customer ASC',
            'customer_type' => 'NEW',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create(['user_id' => $asmUser->id, 'industri_customer_id' => $custAsm->id, 'is_active' => true]);
        SalesIndustriAssignment::create(['user_id' => $ascUser->id, 'industri_customer_id' => $custAsc->id, 'is_active' => true]);

        MasterTarget::create(['user_id' => $asmUser->id, 'kategori_skema' => 'INDUSTRI', 'metrik_target' => 'SELL_IN', 'period' => $period, 'target_quota' => 30000]);
        MasterTarget::create(['user_id' => $ascUser->id, 'kategori_skema' => 'INDUSTRI', 'metrik_target' => 'SELL_IN', 'period' => $period, 'target_quota' => 60000]); // Grade 2 rate=2!

        SellinIndustri::create(['industri_customer_id' => $custAsm->id, 'customer_name' => $custAsm->customer_name, 'period' => $period, 'tonase' => 30000, 'volume_kg' => 30000]);
        SellinIndustri::create(['industri_customer_id' => $custAsc->id, 'customer_name' => $custAsc->customer_name, 'period' => $period, 'tonase' => 60000, 'volume_kg' => 60000]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('INDUSTRI', $period, $this->admin->id);

        $asmSellIn = $results->first(fn ($r) => $r->user_id === $asmUser->id && $r->targetHeader->type === 'SELL_IN');
        $ascSellIn = $results->first(fn ($r) => $r->user_id === $ascUser->id && $r->targetHeader->type === 'SELL_IN');

        // ASM: Grade 1 (rate 1), 30.000 * 1 * 70% = 21.000
        $this->assertEquals(21000.0, (float) $asmSellIn->final_reward);
        // ASC: Grade 2 (rate 2), 60.000 * 2 * 70% = 84.000
        $this->assertEquals(84000.0, (float) $ascSellIn->final_reward);
    }

    public function test_noo_resets_yearly_so_prior_year_customer_counts_as_noo_in_new_year(): void
    {
        $this->createIndustriHeadersForPosition($this->posSpv);

        $sales = User::create([
            'name' => 'Raka SPV',
            'username' => 'raka_spv_reset',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_industri' => true,
        ]);

        $custLama = IndustriCustomer::create([
            'customer_code' => 'IND-LAMA-01',
            'customer_name' => 'PT Pelanggan Tahunan',
            'customer_type' => 'EXISTING',
            'first_transaction_period' => '202512',
            'is_active' => true,
        ]);

        SalesIndustriAssignment::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $custLama->id,
            'is_active' => true,
        ]);

        // Transaksi tahun sebelumnya (202512)
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $custLama->id,
            'customer_code' => $custLama->customer_code,
            'customer_name' => $custLama->customer_name,
            'period' => '202512',
            'tonase' => 12000,
            'volume_kg' => 12000,
        ]);

        // Transaksi pertama di tahun 2026 (202604) -> wajib dihitung NOO (reset tahunan)
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $custLama->id,
            'customer_code' => $custLama->customer_code,
            'customer_name' => $custLama->customer_name,
            'period' => '202604',
            'tonase' => 15000,
            'volume_kg' => 15000,
        ]);

        // Transaksi kedua di tahun 2026 (202610) -> bukan NOO lagi karena sudah ambil di 202604
        SellinIndustri::create([
            'user_id' => $sales->id,
            'industri_customer_id' => $custLama->id,
            'customer_code' => $custLama->customer_code,
            'customer_name' => $custLama->customer_name,
            'period' => '202610',
            'tonase' => 20000,
            'volume_kg' => 20000,
        ]);

        foreach (['202604', '202610'] as $p) {
            MasterTarget::create(['user_id' => $sales->id, 'kategori_skema' => 'INDUSTRI', 'metrik_target' => 'SELL_IN', 'period' => $p, 'target_quota' => 10000]);
            MasterTarget::create(['user_id' => $sales->id, 'kategori_skema' => 'INDUSTRI', 'metrik_target' => 'NOO', 'period' => $p, 'target_quota' => 1]);
        }

        $service = app(IncentiveCalculationService::class);

        $evalApr = $service->evaluateIndustriForPeriod('202604', null, $sales->id);
        $cardApr = $evalApr['cards'][0];
        $this->assertEquals(1, $cardApr['actual_noo_count']);
        $this->assertTrue($cardApr['customers'][0]['is_noo']);

        $evalOct = $service->evaluateIndustriForPeriod('202610', null, $sales->id);
        $cardOct = $evalOct['cards'][0];
        $this->assertEquals(0, $cardOct['actual_noo_count']);
        $this->assertFalse($cardOct['customers'][0]['is_noo']);
    }
}

<?php

namespace Tests\Unit;

use App\Models\Grade;
use App\Models\IncentiveCalculation;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SalesSurabayaAssignment;
use App\Models\SelloutSalesSurabaya;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class SurabayaIncentiveCalculationTest extends TestCase
{
    use RefreshDatabase;

    private Role $roleAdmin;
    private Role $roleSales;
    private Position $posAsc;
    private Position $posTo;
    private Position $posSm;
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

        $this->posAsc = Position::where('code', 'ASC')->firstOrFail();
        $this->posTo = Position::firstOrCreate(
            ['code' => 'TO'],
            ['name' => 'Sales Taking Order', 'is_active' => true]
        );
        $this->posSm = Position::where('code', 'SM')->firstOrFail();

        $this->admin = User::create([
            'name' => 'Admin Test',
            'username' => 'admin_test_sby',
            'password' => Hash::make('password'),
            'role_id' => $this->roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);
    }

    private function seedSurabayaHeaders(): void
    {
        $ascHeader = TargetHeader::create([
            'nama' => 'Insentif Sales Surabaya ASC',
            'kategori_skema' => 'SURABAYA',
            'sales_type' => $this->posAsc->id,
            'type' => 'SELL_OUT',
            'bobot' => 100.00,
            'min_achievement_pct' => 100.00,
            'aktif' => true,
            'aktif_from' => '20250101',
            'aktif_to' => '20301231',
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $ascHeader->id,
            'grade_name' => 'Grade 1',
            'target_from' => 1000,
            'target_to' => 2500,
            'multiplier_rate' => 0.50,
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $ascHeader->id,
            'grade_name' => 'Grade 2',
            'target_from' => 2501,
            'target_to' => 5000,
            'multiplier_rate' => 0.25,
        ]);

        $toHeader = TargetHeader::create([
            'nama' => 'Insentif Sales Surabaya TO',
            'kategori_skema' => 'SURABAYA',
            'sales_type' => $this->posTo->id,
            'type' => 'SELL_OUT',
            'bobot' => 100.00,
            'min_achievement_pct' => 80.00,
            'aktif' => true,
            'aktif_from' => '20250101',
            'aktif_to' => '20301231',
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $toHeader->id,
            'grade_name' => 'Grade 1',
            'target_from' => 1000,
            'target_to' => 5000,
            'multiplier_rate' => 1.00,
        ]);

        $smHeader = TargetHeader::create([
            'nama' => 'Insentif Sales Surabaya SM',
            'kategori_skema' => 'SURABAYA',
            'sales_type' => $this->posSm->id,
            'type' => 'SELL_OUT',
            'bobot' => 100.00,
            'min_achievement_pct' => 80.00,
            'aktif' => true,
            'aktif_from' => '20250101',
            'aktif_to' => '20301231',
        ]);

        Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $smHeader->id,
            'grade_name' => 'Grade 1',
            'target_from' => 1000,
            'target_to' => 5000,
            'multiplier_rate' => 1.00,
        ]);
    }

    public function test_alex_asc_exact_simulation_with_bobi_to_and_nino_sm(): void
    {
        $this->seedSurabayaHeaders();
        $period = '202610';

        $alex = User::create([
            'name' => 'Alex',
            'username' => 'alex_asc_test',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posAsc->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        $bobi = User::create([
            'name' => 'Bobi',
            'username' => 'bobi_to_test',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posTo->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        $nino = User::create([
            'name' => 'Nino',
            'username' => 'nino_sm_test',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        SalesSurabayaAssignment::create([
            'coordinator_id' => $alex->id,
            'sales_id' => $bobi->id,
            'sales_type' => 'Taking Order',
            'period' => $period,
            'is_active' => true,
        ]);

        SalesSurabayaAssignment::create([
            'coordinator_id' => $alex->id,
            'sales_id' => $nino->id,
            'sales_type' => 'Sales Motoris',
            'period' => $period,
            'is_active' => true,
        ]);

        MasterTarget::create([
            'user_id' => $bobi->id,
            'kategori_skema' => 'SURABAYA',
            'level' => 'SALES',
            'metrik_target' => 'SELL_OUT',
            'period' => $period,
            'target_quota' => 1500,
        ]);

        MasterTarget::create([
            'user_id' => $nino->id,
            'kategori_skema' => 'SURABAYA',
            'level' => 'SALES',
            'metrik_target' => 'SELL_OUT',
            'period' => $period,
            'target_quota' => 3000,
        ]);

        SelloutSalesSurabaya::create([
            'coordinator_id' => $alex->id,
            'sales_id' => $bobi->id,
            'period' => $period,
            'volume' => 2000,
            'active_outlet_count' => 0,
        ]);

        SelloutSalesSurabaya::create([
            'coordinator_id' => $alex->id,
            'sales_id' => $nino->id,
            'period' => $period,
            'volume' => 4000,
            'active_outlet_count' => 0,
        ]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('SURABAYA', $period, $this->admin->id);

        $alexRow = $results->firstWhere('user_id', $alex->id);
        $bobiRow = $results->firstWhere('user_id', $bobi->id);
        $ninoRow = $results->firstWhere('user_id', $nino->id);

        $this->assertNotNull($alexRow);
        $this->assertEquals(2000.0, (float) $alexRow->final_reward);
        $this->assertEquals(2000.0, (float) $bobiRow->final_reward);
        $this->assertEquals(4000.0, (float) $ninoRow->final_reward);

        $res = $this->actingAs($this->admin)
            ->getJson("/api/incentives/surabaya-breakdown?period={$period}&user_id={$alex->id}");
        $res->assertStatus(200)
            ->assertJsonPath('data.0.user_name', 'Alex')
            ->assertJsonPath('data.0.total_reward', 2000)
            ->assertJsonPath('data.0.subordinates.0.sales_name', 'Bobi')
            ->assertJsonPath('data.0.subordinates.0.position_code', 'TO')
            ->assertJsonPath('data.0.subordinates.0.multiplier_rate', 0.5)
            ->assertJsonPath('data.0.subordinates.0.contribution_reward', 1000)
            ->assertJsonPath('data.0.subordinates.1.sales_name', 'Nino')
            ->assertJsonPath('data.0.subordinates.1.position_code', 'SM')
            ->assertJsonPath('data.0.subordinates.1.multiplier_rate', 0.25)
            ->assertJsonPath('data.0.subordinates.1.contribution_reward', 1000);
    }

    public function test_asc_partial_subordinate_fail_does_not_cancel_passing_subordinate(): void
    {
        $this->seedSurabayaHeaders();
        $period = '202610';

        $alex = User::create([
            'name' => 'Alex Partial',
            'username' => 'alex_partial',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posAsc->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        $bobi = User::create([
            'name' => 'Bobi Pass',
            'username' => 'bobi_pass',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posTo->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        $nino = User::create([
            'name' => 'Nino Fail',
            'username' => 'nino_fail',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posSm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => true,
        ]);

        SalesSurabayaAssignment::create(['coordinator_id' => $alex->id, 'sales_id' => $bobi->id, 'sales_type' => 'Taking Order', 'period' => $period, 'is_active' => true]);
        SalesSurabayaAssignment::create(['coordinator_id' => $alex->id, 'sales_id' => $nino->id, 'sales_type' => 'Sales Motoris', 'period' => $period, 'is_active' => true]);

        MasterTarget::create(['user_id' => $bobi->id, 'kategori_skema' => 'SURABAYA', 'level' => 'SALES', 'metrik_target' => 'SELL_OUT', 'period' => $period, 'target_quota' => 1500]);
        MasterTarget::create(['user_id' => $nino->id, 'kategori_skema' => 'SURABAYA', 'level' => 'SALES', 'metrik_target' => 'SELL_OUT', 'period' => $period, 'target_quota' => 3000]);

        SelloutSalesSurabaya::create(['coordinator_id' => $alex->id, 'sales_id' => $bobi->id, 'period' => $period, 'volume' => 2000]);
        SelloutSalesSurabaya::create(['coordinator_id' => $alex->id, 'sales_id' => $nino->id, 'period' => $period, 'volume' => 2500]); // 83.33% < 100%

        $service = app(IncentiveCalculationService::class);
        $breakdown = $service->evaluateSurabayaForPeriod($period, null, $alex->id);
        $card = $breakdown['cards'][0];

        $this->assertEquals(1000.0, $card['total_reward']);
        $this->assertFalse($card['subordinates'][1]['is_passed']);
        $this->assertEquals(0.0, $card['subordinates'][1]['contribution_reward']);
    }

    public function test_ineligible_surabaya_user_returns_zero_and_cleans_stale_results(): void
    {
        $this->seedSurabayaHeaders();
        $period = '202610';

        $sales = User::create([
            'name' => 'Ineligible TO',
            'username' => 'ineligible_to_sby',
            'password' => Hash::make('password'),
            'role_id' => $this->roleSales->id,
            'position_id' => $this->posTo->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_surabaya' => false,
        ]);

        MasterTarget::create(['user_id' => $sales->id, 'kategori_skema' => 'SURABAYA', 'level' => 'SALES', 'metrik_target' => 'SELL_OUT', 'period' => $period, 'target_quota' => 1500]);
        SelloutSalesSurabaya::create(['sales_id' => $sales->id, 'period' => $period, 'volume' => 2000]);

        $service = app(IncentiveCalculationService::class);
        $results = $service->execute('SURABAYA', $period, $this->admin->id, null, $sales->id);

        $this->assertCount(0, $results);
        $this->assertEquals(0, IncentiveCalculation::where('user_id', $sales->id)->count());

        $breakdown = $service->evaluateSurabayaForPeriod($period, null, $sales->id, null, true);
        $this->assertFalse($breakdown['cards'][0]['is_eligible_surabaya']);
        $this->assertEquals(0.0, $breakdown['cards'][0]['total_reward']);
    }
}

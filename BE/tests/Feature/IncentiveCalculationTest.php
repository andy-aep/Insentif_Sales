<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Distributor;
use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SellinDistributor;
use App\Models\TargetHeader;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class IncentiveCalculationTest extends TestCase
{
    use RefreshDatabase;

    public function test_incentive_calculation_service_and_api(): void
    {
        $roleAdmin = Role::create(['name' => 'Administrator', 'display_name' => 'Admin']);
        $roleSales = Role::create(['name' => 'Sales', 'display_name' => 'Sales Personil']);

        $posAsm = Position::create(['name' => 'ASM', 'code' => 'ASM', 'is_active' => true]);

        $admin = User::create([
            'name' => 'Admin User',
            'username' => 'admin',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);

        $sales = User::create([
            'name' => 'Sales Budi',
            'username' => 'sales_budi',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2024-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $brand = Brand::create(['code' => 'B01', 'name' => 'Brand Test']);
        $dist = Distributor::create(['code' => 'D01', 'name' => 'Distributor Test']);

        // Scheme
        $header = TargetHeader::create([
            'nama' => 'Insentif Sell-In ASM',
            'kategori_skema' => 'KONSUMSI',
            'sales_type' => $posAsm->id,
            'type' => 'Sell-In',
            'bobot' => 100.00,
            'aktif' => true,
            'aktif_from' => '20240101',
            'aktif_to' => '20301231',
        ]);

        $grade = Grade::create([
            'id_grade' => (string) Str::uuid(),
            'target_header_id' => $header->id,
            'grade_name' => 'Grade 1 (50k - 200k)',
            'target_from' => 50000.00,
            'target_to' => 200000.00,
        ]);

        GradeBobot::create([
            'id_grade' => $grade->id_grade,
            'bobot_name' => 'Tier 100% - 120%',
            'percent_from' => 100.00,
            'percent_to' => 120.00,
            'pengali' => true,
            'bobot' => 50.00, // Rp 50 / kg
            'nominal' => 0,
        ]);

        $period = '202610';

        // Target: 100,000 kg
        MasterTarget::create([
            'user_id' => $sales->id,
            'kategori_skema' => 'KONSUMSI',
            'metrik_target' => 'Sell-In',
            'period' => $period,
            'target_quota' => 100000.00,
        ]);

        // Realization: 105,000 kg
        SellinDistributor::create([
            'distributor_id' => $dist->id,
            'brand_id' => $brand->id,
            'period' => $period,
            'volume_kg' => 105000.00,
            'nominal' => 1000000000.00,
        ]);

        $token = $admin->createToken('admin-token')->plainTextToken;

        // Run calculation API
        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/incentives/calculate', [
                'kategori_skema' => 'KONSUMSI',
                'period' => $period,
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('meta.total_personil', 1)
            ->assertJsonPath('meta.total_records', 1)
            ->assertJsonPath('data.0.target_quota', '100000.00')
            ->assertJsonPath('data.0.realization', '105000.00')
            ->assertJsonPath('data.0.final_reward', '5250000.00'); // 105000 * 50 = 5,250,000

        // Fetch results API
        $resultsResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson("/api/incentives/results?period={$period}&kategori_skema=KONSUMSI");

        $resultsResponse->assertStatus(200)
            ->assertJsonPath('total', 1);

        // Export Excel API
        $exportResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->get("/api/incentives/export-excel?period={$period}&kategori_skema=KONSUMSI");

        $exportResponse->assertStatus(200);
    }
}

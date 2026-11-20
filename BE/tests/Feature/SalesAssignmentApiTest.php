<?php

namespace Tests\Feature;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\Position;
use App\Models\Region;
use App\Models\Role;
use App\Models\SalesDistributorAssignment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SalesAssignmentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_index_distributor_returns_expected_relations_and_filters_by_period(): void
    {
        $roleAdmin = Role::create(['name' => 'Administrator', 'display_name' => 'Administrator']);
        $roleSales = Role::create(['name' => 'Sales', 'display_name' => 'Sales Personil']);

        $posNsm = Position::create(['code' => 'NSM', 'name' => 'National Sales Manager', 'is_active' => true]);
        $posLsm = Position::create(['code' => 'LSM', 'name' => 'Line Sales Manager', 'is_active' => true]);
        $posAsm = Position::create(['code' => 'ASM', 'name' => 'Area Sales Manager', 'is_active' => true]);
        $posSpv = Position::create(['code' => 'SPV', 'name' => 'Sales Supervisor', 'is_active' => true]);

        $admin = User::create([
            'name' => 'Admin',
            'username' => 'admin_test',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2025-01-01',
        ]);

        $nsm = User::create([
            'name' => 'Bapak NSM',
            'username' => 'nsm_user',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posNsm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $lsm = User::create([
            'name' => 'Ibu LSM',
            'username' => 'lsm_user',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posLsm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $asm = User::create([
            'name' => 'Pak ASM',
            'username' => 'asm_user',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posAsm->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $spv = User::create([
            'name' => 'Mas SPV',
            'username' => 'spv_user',
            'password' => Hash::make('password'),
            'role_id' => $roleSales->id,
            'position_id' => $posSpv->id,
            'aktif_from' => '2025-01-01',
            'is_eligible_konsumsi' => true,
        ]);

        $region = Region::create(['code' => 'EAST', 'name' => 'Indonesia Timur']);
        $dist = Distributor::create(['code' => 'DST01', 'name' => 'PT Sumber', 'region_id' => $region->id]);
        $depo = Depo::create(['distributor_id' => $dist->id, 'code' => 'DP01', 'name' => 'Depo Tegal']);
        $area = Area::create(['depo_id' => $depo->id, 'code' => 'AR01', 'name' => 'Brebes']);

        SalesDistributorAssignment::create([
            'user_id' => $nsm->id,
            'region_id' => $region->id,
            'period' => '202610',
            'is_active' => true,
            'notes' => 'Wilayah Timur',
        ]);

        SalesDistributorAssignment::create([
            'user_id' => $lsm->id,
            'nsm_id' => $nsm->id,
            'region_id' => $region->id,
            'period' => '202610',
            'is_active' => true,
        ]);

        SalesDistributorAssignment::create([
            'user_id' => $spv->id,
            'asm_id' => $asm->id,
            'lsm_id' => $lsm->id,
            'region_id' => $region->id,
            'distributor_id' => $dist->id,
            'depo_id' => $depo->id,
            'area_id' => $area->id,
            'period' => '202611',
            'is_active' => true,
        ]);

        $resAll = $this->actingAs($admin)->getJson('/api/sales-distributor-assignments');
        $resAll->assertStatus(200)->assertJsonCount(3);

        $data = collect($resAll->json());
        $nsmRow = $data->firstWhere('user_id', $nsm->id);
        $this->assertNotNull($nsmRow);
        $this->assertEquals('NSM', $nsmRow['user']['position']['code']);
        $this->assertCount(1, $nsmRow['subordinate_lsms']);
        $this->assertEquals('Ibu LSM', $nsmRow['subordinate_lsms'][0]['user']['name']);

        $spvRow = $data->firstWhere('user_id', $spv->id);
        $this->assertEquals('Pak ASM', $spvRow['asm']['name']);
        $this->assertEquals('PT Sumber', $spvRow['distributor']['name']);
        $this->assertEquals('Indonesia Timur', $spvRow['distributor']['region']['name']);
        $this->assertEquals('Depo Tegal', $spvRow['depo']['name']);
        $this->assertEquals('Brebes', $spvRow['area']['name']);

        $resFiltered = $this->actingAs($admin)->getJson('/api/sales-distributor-assignments?period=202611');
        $resFiltered->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonPath('0.user_id', $spv->id);
    }
}

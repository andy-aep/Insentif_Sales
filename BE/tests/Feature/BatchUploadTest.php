<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Distributor;
use App\Models\Role;
use App\Models\SellinDistributor;
use App\Models\UploadBatch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class BatchUploadTest extends TestCase
{
    use RefreshDatabase;

    public function test_batch_rollback_cleans_up_data(): void
    {
        $roleAdmin = Role::create(['name' => 'Administrator', 'display_name' => 'Admin']);
        $admin = User::create([
            'name' => 'Admin User',
            'username' => 'admin',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);

        $dist = Distributor::create(['code' => 'DST01', 'name' => 'Distributor 1']);
        $brand = Brand::create(['code' => 'BRD01', 'name' => 'Brand 1']);

        $batchId = (string) Str::uuid();
        UploadBatch::create([
            'id' => $batchId,
            'entity_type' => 'sellin_distributor',
            'file_name' => 'sellin_october.xlsx',
            'status' => 'COMPLETED',
            'uploaded_by' => $admin->id,
            'total_rows' => 2,
            'success_rows' => 2,
        ]);

        SellinDistributor::create([
            'batch_id' => $batchId,
            'distributor_id' => $dist->id,
            'brand_id' => $brand->id,
            'period' => '202610',
            'volume_kg' => 10000,
            'nominal' => 250000000,
        ]);

        $this->assertDatabaseHas('sellin_distributors', ['batch_id' => $batchId]);

        $token = $admin->createToken('admin-token')->plainTextToken;

        // Execute rollback via API
        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson("/api/bulk-upload/rollback/{$batchId}");

        $response->assertStatus(200);

        // Verify transaction data was removed
        $this->assertDatabaseMissing('sellin_distributors', ['batch_id' => $batchId]);

        // Verify batch status updated
        $this->assertDatabaseHas('upload_batches', [
            'id' => $batchId,
            'status' => 'ROLLED_BACK',
        ]);
    }
}

<?php

namespace Tests\Unit;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\Role;
use App\Models\SelloutDistributor;
use App\Models\User;
use App\Services\BatchImportService;
use Exception;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SelloutDistributorStrictUploadTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private Distributor $distIndoPrima;
    private Depo $depoPontianak;
    private Area $areaPontianak;
    private Area $areaOtherDepo;
    private Brand $brandKapal;

    protected function setUp(): void
    {
        parent::setUp();

        $roleAdmin = Role::firstOrCreate(
            ['name' => 'Administrator'],
            ['display_name' => 'Administrator']
        );

        $this->admin = User::create([
            'name' => 'Admin Upload',
            'username' => 'admin_upload',
            'password' => Hash::make('password'),
            'role_id' => $roleAdmin->id,
            'aktif_from' => '2024-01-01',
        ]);

        $this->distIndoPrima = Distributor::create([
            'code' => 'DST0028',
            'name' => 'INDO PRIMA, CV',
        ]);

        $this->depoPontianak = Depo::create([
            'distributor_id' => $this->distIndoPrima->id,
            'code' => 'C110003678',
            'name' => 'PONTIANAK',
        ]);

        $this->areaPontianak = Area::create([
            'depo_id' => $this->depoPontianak->id,
            'code' => 'AR00100',
            'name' => 'PONTIANAK',
        ]);

        $otherDist = Distributor::create([
            'code' => 'DST0001',
            'name' => 'TUTON, CV',
        ]);
        $otherDepo = Depo::create([
            'distributor_id' => $otherDist->id,
            'code' => 'C110003336',
            'name' => 'TEGAL',
        ]);
        $this->areaOtherDepo = Area::create([
            'depo_id' => $otherDepo->id,
            'code' => 'AR00001',
            'name' => 'BREBES',
        ]);

        $this->brandKapal = Brand::firstOrCreate(
            ['code' => 'KAPAL'],
            ['name' => 'KAPAL']
        );
    }

    private function writeTempCsv(string $content): string
    {
        $path = tempnam(sys_get_temp_dir(), 'sellout_') . '.csv';
        file_put_contents($path, $content);

        return $path;
    }

    public function test_rejects_upload_when_areacode_column_is_missing(): void
    {
        $csv = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            '1983-07-26,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,1932-03-01,MARI MART,JL. DR. WAHIDIN,KAPAL,SELL OUT,B13,KOP 150,GARAM CAP KAPAL,3,20670,PONTIANAK,,JACKY,DANNY,RETAIL',
        ]);

        $path = $this->writeTempCsv($csv);
        $service = app(BatchImportService::class);
        $batch = $service->createBatch('sellout_distributor', 'missing_area.csv', $this->admin->id);

        try {
            $this->expectException(Exception::class);
            $this->expectExceptionMessageMatches('/AreaCode/');
            $service->processFile($batch, $path);
        } finally {
            @unlink($path);
        }
    }

    public function test_rejects_upload_when_date_or_month_or_area_depo_sync_is_invalid(): void
    {
        // Kasus 1: Tanggal tidak valid (2026-02-31)
        $csvBadDate = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            '1983-07-26,2026-02-31,2,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,1932-03-01,MARI MART,JL. DR. WAHIDIN,KAPAL,SELL OUT,B13,KOP 150,GARAM CAP KAPAL,3,20670,PONTIANAK,,JACKY,DANNY,RETAIL',
        ]);
        $path1 = $this->writeTempCsv($csvBadDate);
        $service = app(BatchImportService::class);
        $batch1 = $service->createBatch('sellout_distributor', 'bad_date.csv', $this->admin->id);

        try {
            $service->processFile($batch1, $path1);
            $this->fail('Expected exception for invalid date 2026-02-31');
        } catch (Exception $e) {
            $this->assertStringContainsString('Format Tanggal', $e->getMessage());
        } finally {
            @unlink($path1);
        }

        // Kasus 2: AreaCode milik Depo TEGAL (AR00001) tapi diisi pada Depo PONTIANAK
        $csvBadSync = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            '1983-07-26,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00001,1932-03-01,MARI MART,JL. DR. WAHIDIN,KAPAL,SELL OUT,B13,KOP 150,GARAM CAP KAPAL,3,20670,PONTIANAK,,JACKY,DANNY,RETAIL',
        ]);
        $path2 = $this->writeTempCsv($csvBadSync);
        $batch2 = $service->createBatch('sellout_distributor', 'bad_sync.csv', $this->admin->id);

        try {
            $service->processFile($batch2, $path2);
            $this->fail('Expected exception for unsynchronized AreaCode vs Depo');
        } catch (Exception $e) {
            $this->assertStringContainsString('tidak sinkron', $e->getMessage());
        } finally {
            @unlink($path2);
        }

        $this->assertEquals(0, SelloutDistributor::count());
    }

    public function test_accepts_valid_sellout_upload_and_computes_unique_active_outlets_and_returns(): void
    {
        $csvValid = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            '1983-07-26,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,1932-03-01,MARI MART,JL. DR. WAHIDIN,KAPAL,SELL OUT,B13,KOP 150 @ 3KG / BAL,GARAM CAP KAPAL 150GR @3KG/BAL,3,20670,PONTIANAK,,JACKY CHEDORRY,DANNY,RETAIL',
            '1983-07-26,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,1932-03-01,MARI MART,JL. DR. WAHIDIN,KAPAL,SELL OUT,B26,KOP 250 M @ 10 KG / BAL,GARAM CAP KAPAL 250GR @10KG/BAL,10,68900,PONTIANAK,,JACKY CHEDORRY,DANNY,RETAIL',
            '0318/07/26,2026-07-03,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,HKC0001,HKC PLASTIK,JL. JURUSAN ANJUNGAN,KAPAL,SELL OUT,B13,KOP 150 @ 3KG / BAL,GARAM CAP KAPAL 150GR @3KG/BAL,3,20670,SEI PINYU,,JACKY CHEDORRY,DANNY,RETAIL',
            '1086/R/07/26&,2026-07-22,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,HKC0001,HKC PLASTIK,JL. JURUSAN ANJUNGAN,KAPAL,SELL OUT,B13,KOP 150 @ 3KG / BAL,GARAM CAP KAPAL 150GR @3KG/BAL,-1,-6890,SEI PINYU,,JACKY CHEDORRY,DANNY,RETAIL',
        ]);

        $path = $this->writeTempCsv($csvValid);
        $service = app(BatchImportService::class);
        $batch = $service->createBatch('sellout_distributor', 'valid_sellout.csv', $this->admin->id);

        try {
            $processed = $service->processFile($batch, $path);
            $this->assertEquals('COMPLETED', $processed->status);
            $this->assertEquals(4, $processed->total_rows);
            $this->assertEquals(4, $processed->success_rows);

            // Total Volume: 3 + 10 + 3 - 1 = 15 Kg
            $this->assertEquals(15.0, (float) SelloutDistributor::where('period', '202607')->where('area_id', $this->areaPontianak->id)->sum('volume_kg'));
            // Active Outlet unik: MARI MART (1932-03-01) dan HKC PLASTIK (HKC0001) = 2 toko
            $this->assertEquals(2, (int) SelloutDistributor::where('period', '202607')->where('area_id', $this->areaPontianak->id)->sum('active_outlet_count'));
            $this->assertEquals('202607', $processed->period);
            $this->assertEquals($this->distIndoPrima->id, $processed->distributor_id);

            // Upload ulang bulan & distributor yang sama harus ditolak sebelum rollback
            $batchDup = $service->createBatch('sellout_distributor', 'dup_sellout.csv', $this->admin->id);
            $this->expectException(Exception::class);
            $this->expectExceptionMessageMatches('/sudah ada di Riwayat Upload/');
            $service->processFile($batchDup, $path);
        } finally {
            @unlink($path);
        }
    }

    public function test_rejects_multi_period_multi_distributor_zero_dpp_and_placeholder_codes(): void
    {
        $service = app(BatchImportService::class);

        // 1. Multi-distributor dalam 1 file
        $csvMultiDist = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            'F-01,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,C-01,MARI MART,JL. A,KAPAL,SELL OUT,B13,KOP 150,GARAM,3,20670,PONTIANAK,,JACKY,DANNY,RETAIL',
            'F-02,2026-07-02,7,C110003336,"TUTON, CV",TEGAL,AR00001,C-02,TOKO B,JL. B,KAPAL,SELL OUT,B13,KOP 150,GARAM,5,34450,TEGAL,,BUDI,DANNY,RETAIL',
        ]);
        $p2 = $this->writeTempCsv($csvMultiDist);
        try {
            $b2 = $service->createBatch('sellout_distributor', 'multi_dist.csv', $this->admin->id);
            try {
                $service->processFile($b2, $p2);
                $this->fail('Expected exception for multi-distributor file');
            } catch (Exception $e) {
                $this->assertStringContainsString('1 distributor', $e->getMessage());
            }
        } finally {
            @unlink($p2);
        }

        // 3. DPP = 0 dan kode placeholder '-'
        $csvZeroDpp = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            '-,2026-07-01,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,C-01,MARI MART,JL. A,KAPAL,SELL OUT,B13,KOP 150,GARAM,3,0,PONTIANAK,,JACKY,DANNY,RETAIL',
        ]);
        $p3 = $this->writeTempCsv($csvZeroDpp);
        try {
            $b3 = $service->createBatch('sellout_distributor', 'zero_dpp.csv', $this->admin->id);
            try {
                $service->processFile($b3, $p3);
                $this->fail('Expected exception for placeholder code / zero DPP');
            } catch (Exception $e) {
                $this->assertStringContainsString('Pengkodean wajib valid', $e->getMessage());
            }
        } finally {
            @unlink($p3);
        }

        $this->assertEquals(0, SelloutDistributor::count());
    }

    public function test_accepts_luar_area_code_as_out_of_area_non_incentive(): void
    {
        $csvLuar = implode("\n", [
            'Faktur,Tanggal,Bulan,KodeDistributor,NamaDistributor,Depo,AreaCode,KodeCustomer,NamaCustomer,Alamat,JenisBarang,JenisSales,ITM,NamaBarang,Barang,SalesKg,DPP,Kota/Kab,Kecamatan,SalesmanDist,PIC,TipeOutlet',
            'F-100,2026-07-10,7,C110003678,"INDO PRIMA, CV",PONTIANAK,LUAR,OUT-99,TOKO LUAR,JL. RAYA,KAPAL,SELL OUT,B13,KOP 150,GARAM,50,344500,SANGGAU,KAPUAS,JACKY,DANNY,RETAIL',
            'F-101,2026-07-11,7,C110003678,"INDO PRIMA, CV",PONTIANAK,AR00100,C-01,MARI MART,JL. A,KAPAL,SELL OUT,B13,KOP 150,GARAM,10,68900,PONTIANAK,,JACKY,DANNY,RETAIL',
        ]);

        $path = $this->writeTempCsv($csvLuar);
        $service = app(BatchImportService::class);
        $batch = $service->createBatch('sellout_distributor', 'luar_area.csv', $this->admin->id);

        try {
            $processed = $service->processFile($batch, $path);
            $this->assertEquals('COMPLETED', $processed->status);
            $this->assertEquals(2, $processed->success_rows);

            $outRow = SelloutDistributor::where('faktur', 'F-100')->first();
            $this->assertNotNull($outRow);
            $this->assertTrue((bool) $outRow->is_out_of_area);
            $this->assertNull($outRow->area_id);
            $this->assertEquals(0, (int) $outRow->active_outlet_count);

            $inRow = SelloutDistributor::where('faktur', 'F-101')->first();
            $this->assertNotNull($inRow);
            $this->assertFalse((bool) $inRow->is_out_of_area);
            $this->assertEquals($this->areaPontianak->id, $inRow->area_id);
            $this->assertEquals(1, (int) $inRow->active_outlet_count);

            // Verifikasi hanya baris Dalam Area (10 Kg) yang dihitung untuk insentif
            $eligibleKg = (float) SelloutDistributor::where('period', '202607')->where('is_out_of_area', false)->sum('volume_kg');
            $this->assertEquals(10.0, $eligibleKg);
        } finally {
            @unlink($path);
        }
    }
}

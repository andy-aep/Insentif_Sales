<?php

namespace Database\Seeders;

use App\Models\Area;
use App\Models\Brand;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\User;
use Illuminate\Database\Seeder;

class SampleTargetSeeder extends Seeder
{
    public function run(): void
    {
        $dist = Distributor::firstOrCreate(
            ['code' => 'DST01'],
            ['name' => 'PT Sumber Rejeki Utama', 'region_id' => 1]
        );

        $brandAb = Brand::firstOrCreate(
            ['code' => 'BRD01'],
            ['name' => 'Indoprima Dairy (Brand AB)']
        );

        $brandBa = Brand::firstOrCreate(
            ['code' => 'BRD02'],
            ['name' => 'Indoprima Sweet (Brand BA)']
        );

        $depoA1 = Depo::firstOrCreate(
            ['distributor_id' => $dist->id, 'code' => 'DP01'],
            ['name' => 'Depo A1 - Surabaya Timur']
        );

        $depoA2 = Depo::firstOrCreate(
            ['distributor_id' => $dist->id, 'code' => 'DP02'],
            ['name' => 'Depo A2 - Surabaya Barat']
        );

        $areaB1 = Area::firstOrCreate(
            ['depo_id' => $depoA1->id, 'code' => 'AR01'],
            ['name' => 'Area B1 (Rungkut)']
        );

        $areaB2 = Area::firstOrCreate(
            ['depo_id' => $depoA1->id, 'code' => 'AR02'],
            ['name' => 'Area B2 (Tenggilis)']
        );

        $asmUser = User::whereHas('position', fn ($q) => $q->where('code', 'ASM'))->first();
        $spvUser = User::whereHas('position', fn ($q) => $q->where('code', 'SPV'))->first();

        // 1. Depo A1 - Brand AB target 3000 kg (ASM)
        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_OUT',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => null,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'DEPO',
                'target_quota' => 3000,
                'target_outlet' => 50,
                'user_id' => $asmUser?->id,
            ]
        );

        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_IN',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => null,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'DEPO',
                'target_quota' => 3000,
                'target_outlet' => null,
                'user_id' => $asmUser?->id,
            ]
        );

        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'AO',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => null,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'DEPO',
                'target_quota' => 50,
                'target_outlet' => 50,
                'user_id' => $asmUser?->id,
            ]
        );

        // 2. Depo A2 - Brand BA target 3000 kg (ASM)
        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_OUT',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA2->id,
                'area_id' => null,
                'brand_id' => $brandBa->id,
            ],
            [
                'level' => 'DEPO',
                'target_quota' => 3000,
                'target_outlet' => 50,
                'user_id' => $asmUser?->id,
            ]
        );

        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_IN',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA2->id,
                'area_id' => null,
                'brand_id' => $brandBa->id,
            ],
            [
                'level' => 'DEPO',
                'target_quota' => 3000,
                'target_outlet' => null,
                'user_id' => $asmUser?->id,
            ]
        );

        // 3. Area B1 dari Depo A1 - Brand AB target 1500 kg (SPV)
        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_OUT',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => $areaB1->id,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'AREA',
                'target_quota' => 1500,
                'target_outlet' => 25,
                'user_id' => $spvUser?->id,
            ]
        );

        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'AO',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => $areaB1->id,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'AREA',
                'target_quota' => 25,
                'target_outlet' => 25,
                'user_id' => $spvUser?->id,
            ]
        );

        // 4. Area B2 dari Depo A1 - Brand AB target 1500 kg (SPV)
        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'SELL_OUT',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => $areaB2->id,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'AREA',
                'target_quota' => 1500,
                'target_outlet' => 25,
                'user_id' => $spvUser?->id,
            ]
        );

        MasterTarget::updateOrCreate(
            [
                'period' => '202610',
                'kategori_skema' => 'KONSUMSI',
                'metrik_target' => 'AO',
                'distributor_id' => $dist->id,
                'depo_id' => $depoA1->id,
                'area_id' => $areaB2->id,
                'brand_id' => $brandAb->id,
            ],
            [
                'level' => 'AREA',
                'target_quota' => 25,
                'target_outlet' => 25,
                'user_id' => $spvUser?->id,
            ]
        );
    }
}

<?php

namespace Database\Seeders;

use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\IndustriCustomer;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SalesIndustriAssignment;
use App\Models\SellinIndustri;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class IndustriDemoSeeder extends Seeder
{
    public function run(): void
    {
        DB::transaction(function (): void {
            $period = '202610';

            $salesRole = Role::firstOrCreate(
                ['name' => 'Sales'],
                [
                    'display_name' => 'Sales Personil',
                    'description' => 'Melihat target kuota dan pencapaian reward insentif pribadi',
                ]
            );

            $admin = User::whereHas('role', fn ($q) => $q->where('name', 'Administrator'))->first()
                ?? User::firstOrFail();

            $posAsm = Position::firstOrCreate(['code' => 'ASM'], ['name' => 'Area Sales Manager', 'is_active' => true]);
            $posSpv = Position::firstOrCreate(['code' => 'SPV'], ['name' => 'Sales Supervisor', 'is_active' => true]);
            $posAsc = Position::firstOrCreate(['code' => 'ASC'], ['name' => 'Area Sales Coordinator', 'is_active' => true]);

            // 1. Konfigurasi Target Header & Multi-Grade Industri (SPV, ASC, ASM)
            $this->upsertIndustriHeader(
                $posSpv,
                'SELL_IN',
                'Insentif Sell-In Industri SPV',
                70.00,
                80.00,
                [
                    ['grade_name' => 'Grade 1 (10.000 - 50.000 Kg)', 'target_from' => 10000, 'target_to' => 50000, 'multiplier_rate' => 1],
                    ['grade_name' => 'Grade 2 (50.001 - 100.000 Kg)', 'target_from' => 50001, 'target_to' => 100000, 'multiplier_rate' => 2],
                    ['grade_name' => 'Grade 3 (100.001 - 200.000 Kg)', 'target_from' => 100001, 'target_to' => 200000, 'multiplier_rate' => 3],
                    ['grade_name' => 'Grade 4 (> 200.000 Kg)', 'target_from' => 200001, 'target_to' => 999999999, 'multiplier_rate' => 4],
                ],
                2
            );

            $this->upsertIndustriHeader(
                $posSpv,
                'NOO',
                'Insentif NOO Industri SPV',
                30.00,
                50.00,
                [
                    ['grade_name' => 'Grade 1 (1 - 10 Outlet)', 'target_from' => 1, 'target_to' => 10, 'multiplier_rate' => 100],
                    ['grade_name' => 'Grade 2 (11 - 25 Outlet)', 'target_from' => 11, 'target_to' => 25, 'multiplier_rate' => 150],
                ]
            );

            $this->upsertIndustriHeader(
                $posAsc,
                'SELL_IN',
                'Insentif Sell-In Industri ASC',
                70.00,
                80.00,
                [
                    ['grade_name' => 'Grade 1 (5.000 - 50.000 Kg)', 'target_from' => 5000, 'target_to' => 50000, 'multiplier_rate' => 1],
                    ['grade_name' => 'Grade 2 (50.001 - 100.000 Kg)', 'target_from' => 50001, 'target_to' => 100000, 'multiplier_rate' => 2],
                    ['grade_name' => 'Grade 3 (100.001 - 200.000 Kg)', 'target_from' => 100001, 'target_to' => 200000, 'multiplier_rate' => 3],
                ]
            );

            $this->upsertIndustriHeader(
                $posAsc,
                'NOO',
                'Insentif NOO Industri ASC',
                30.00,
                50.00,
                [
                    ['grade_name' => 'Grade 1 (1 - 10 Outlet)', 'target_from' => 1, 'target_to' => 10, 'multiplier_rate' => 100],
                    ['grade_name' => 'Grade 2 (11 - 25 Outlet)', 'target_from' => 11, 'target_to' => 25, 'multiplier_rate' => 150],
                ]
            );

            $this->upsertIndustriHeader(
                $posAsm,
                'SELL_IN',
                'Insentif Sell-In Industri ASM',
                70.00,
                80.00,
                [
                    ['grade_name' => 'Grade 1 (20.000 - 100.000 Kg)', 'target_from' => 20000, 'target_to' => 100000, 'multiplier_rate' => 1.5],
                    ['grade_name' => 'Grade 2 (100.001 - 250.000 Kg)', 'target_from' => 100001, 'target_to' => 250000, 'multiplier_rate' => 2.5],
                ]
            );

            $this->upsertIndustriHeader(
                $posAsm,
                'NOO',
                'Insentif NOO Industri ASM',
                30.00,
                50.00,
                [
                    ['grade_name' => 'Grade 1 (1 - 15 Outlet)', 'target_from' => 1, 'target_to' => 15, 'multiplier_rate' => 120],
                    ['grade_name' => 'Grade 2 (16 - 30 Outlet)', 'target_from' => 16, 'target_to' => 30, 'multiplier_rate' => 180],
                ]
            );

            // 2. Personil Sales Industri (SPV Andre sesuai spesifikasi, + Citra ASC & Bima ASM)
            $andre = $this->upsertIndustriUser('andre_spv', 'Andre', $salesRole->id, $posSpv->id);
            $citra = $this->upsertIndustriUser('citra_asc', 'Citra', $salesRole->id, $posAsc->id);
            $bima = $this->upsertIndustriUser('bima_asm_ind', 'Bima', $salesRole->id, $posAsm->id);

            // 3. Master Target Industri periode 202610
            $targets = [
                [$andre->id, 'SELL_IN', 40000],
                [$andre->id, 'NOO', 2],
                [$citra->id, 'SELL_IN', 60000],
                [$citra->id, 'NOO', 3],
                [$bima->id, 'SELL_IN', 80000],
                [$bima->id, 'NOO', 2],
            ];

            foreach ($targets as [$uid, $metrik, $quota]) {
                MasterTarget::updateOrCreate(
                    [
                        'user_id' => $uid,
                        'kategori_skema' => 'INDUSTRI',
                        'metrik_target' => $metrik,
                        'period' => $period,
                    ],
                    [
                        'level' => 'SALES',
                        'target_quota' => $quota,
                        'target_outlet' => $metrik === 'NOO' ? (int) $quota : null,
                    ]
                );
            }

            // 4. Master Customer Industri + Penugasan Sales + Realisasi Sell-In
            $customersData = [
                // Andre SPV -> Total 50.000 Kg (40.000 Existing + 10.000 NOO Baru) = Rp 35.000 + Rp 300.000 = Rp 335.000
                [
                    'user' => $andre,
                    'code' => 'IND-EXT-01',
                    'name' => 'PT Roti Lama Tbk',
                    'city' => 'Jakarta',
                    'type' => 'EXISTING',
                    'first_period' => '202504',
                    'tonase' => 40000,
                    'nominal' => 600000000,
                    'is_noo' => false,
                    'tx_date' => '2026-10-08',
                    'sap_so_no' => 'SO-202610-IND-001',
                ],
                [
                    'user' => $andre,
                    'code' => 'IND-NEW-01',
                    'name' => 'CV Biskuit Baru Jaya',
                    'city' => 'Bekasi',
                    'type' => 'NEW',
                    'first_period' => $period,
                    'tonase' => 10000,
                    'nominal' => 150000000,
                    'is_noo' => true,
                    'tx_date' => '2026-10-18',
                    'sap_so_no' => 'SO-202610-IND-002',
                ],
                // Citra ASC -> Sell-In 55.000 Kg (91.67% lolos, Rp 77.000), NOO 1/3 (33.33% < 50% gagal) = Rp 77.000
                [
                    'user' => $citra,
                    'code' => 'IND-EXT-02',
                    'name' => 'PT Pabrik Mie Nusantara',
                    'city' => 'Tangerang',
                    'type' => 'EXISTING',
                    'first_period' => '202501',
                    'tonase' => 45000,
                    'nominal' => 675000000,
                    'is_noo' => false,
                    'tx_date' => '2026-10-10',
                    'sap_so_no' => 'SO-202610-IND-003',
                ],
                [
                    'user' => $citra,
                    'code' => 'IND-NEW-02',
                    'name' => 'UD Kerupuk Makmur Sentosa',
                    'city' => 'Sidoarjo',
                    'type' => 'NEW',
                    'first_period' => $period,
                    'tonase' => 10000,
                    'nominal' => 150000000,
                    'is_noo' => true,
                    'tx_date' => '2026-10-20',
                    'sap_so_no' => 'SO-202610-IND-004',
                ],
                // Bima ASM -> Sell-In 80.000 Kg (100% lolos, Rp 84.000), NOO 2/2 20.000 Kg (Rp 720.000) = Rp 804.000
                [
                    'user' => $bima,
                    'code' => 'IND-EXT-03',
                    'name' => 'PT Industri Makanan Sejahtera',
                    'city' => 'Cikarang',
                    'type' => 'EXISTING',
                    'first_period' => '202411',
                    'tonase' => 60000,
                    'nominal' => 900000000,
                    'is_noo' => false,
                    'tx_date' => '2026-10-05',
                    'sap_so_no' => 'SO-202610-IND-005',
                ],
                [
                    'user' => $bima,
                    'code' => 'IND-NEW-03',
                    'name' => 'PT Kue Artisan Prima',
                    'city' => 'Bandung',
                    'type' => 'NEW',
                    'first_period' => $period,
                    'tonase' => 12000,
                    'nominal' => 180000000,
                    'is_noo' => true,
                    'tx_date' => '2026-10-14',
                    'sap_so_no' => 'SO-202610-IND-006',
                ],
                [
                    'user' => $bima,
                    'code' => 'IND-NEW-04',
                    'name' => 'CV Snack Modern Abadi',
                    'city' => 'Semarang',
                    'type' => 'NEW',
                    'first_period' => $period,
                    'tonase' => 8000,
                    'nominal' => 120000000,
                    'is_noo' => true,
                    'tx_date' => '2026-10-24',
                    'sap_so_no' => 'SO-202610-IND-007',
                ],
            ];

            foreach ($customersData as $item) {
                $customer = IndustriCustomer::updateOrCreate(
                    ['customer_code' => $item['code']],
                    [
                        'customer_name' => $item['name'],
                        'city' => $item['city'],
                        'customer_type' => $item['type'],
                        'first_transaction_period' => $item['first_period'],
                        'is_active' => true,
                    ]
                );

                SalesIndustriAssignment::updateOrCreate(
                    [
                        'user_id' => $item['user']->id,
                        'industri_customer_id' => $customer->id,
                        'period' => $period,
                    ],
                    [
                        'is_active' => true,
                        'notes' => 'Demo contoh Sales Industri',
                    ]
                );

                SellinIndustri::updateOrCreate(
                    ['sap_so_no' => $item['sap_so_no']],
                    [
                        'user_id' => $item['user']->id,
                        'industri_customer_id' => $customer->id,
                        'customer_code' => $customer->customer_code,
                        'customer_name' => $customer->customer_name,
                        'period' => $period,
                        'tonase' => $item['tonase'],
                        'volume_kg' => $item['tonase'],
                        'nominal' => $item['nominal'],
                        'transaction_date' => $item['tx_date'],
                        'is_noo' => $item['is_noo'],
                    ]
                );
            }

            // 5. Jalankan kalkulasi agar riwayat tersimpan langsung di database
            app(IncentiveCalculationService::class)->execute('INDUSTRI', $period, $admin->id);
        });
    }

    private function upsertIndustriUser(string $username, string $name, int $roleId, int $positionId): User
    {
        return User::updateOrCreate(
            ['username' => $username],
            [
                'name' => $name,
                'password' => Hash::make('password'),
                'role_id' => $roleId,
                'position_id' => $positionId,
                'aktif_from' => '2024-01-01',
                'is_eligible_konsumsi' => false,
                'is_eligible_industri' => true,
                'is_eligible_surabaya' => false,
            ]
        );
    }

    private function upsertIndustriHeader(
        Position $position,
        string $type,
        string $nama,
        float $bobot,
        float $minAchievementPct,
        array $gradesData,
        ?int $preferredId = null
    ): TargetHeader {
        $header = null;
        if ($preferredId !== null) {
            $header = TargetHeader::where('id', $preferredId)
                ->where('kategori_skema', 'INDUSTRI')
                ->where('sales_type', $position->id)
                ->first();
        }

        if ($header === null) {
            $header = TargetHeader::where('kategori_skema', 'INDUSTRI')
                ->where('sales_type', $position->id)
                ->whereRaw("UPPER(REPLACE(REPLACE(TRIM(type), '-', '_'), ' ', '_')) = ?", [$type])
                ->first();
        }

        if ($header !== null) {
            $header->update([
                'nama' => $nama,
                'type' => $type,
                'bobot' => $bobot,
                'min_achievement_pct' => $minAchievementPct,
                'aktif' => true,
                'aktif_from' => '20240101',
                'aktif_to' => '20301231',
            ]);
        } else {
            $header = TargetHeader::create([
                'nama' => $nama,
                'kategori_skema' => 'INDUSTRI',
                'sales_type' => $position->id,
                'type' => $type,
                'bobot' => $bobot,
                'min_achievement_pct' => $minAchievementPct,
                'aktif' => true,
                'aktif_from' => '20240101',
                'aktif_to' => '20301231',
            ]);
        }

        $oldGradeIds = Grade::where('target_header_id', $header->id)->pluck('id_grade');
        if ($oldGradeIds->isNotEmpty()) {
            GradeBobot::whereIn('id_grade', $oldGradeIds)->delete();
            Grade::where('target_header_id', $header->id)->delete();
        }

        foreach ($gradesData as $g) {
            $idGrade = (string) Str::uuid();
            Grade::create([
                'id_grade' => $idGrade,
                'target_header_id' => $header->id,
                'grade_name' => $g['grade_name'],
                'target_from' => $g['target_from'],
                'target_to' => $g['target_to'],
                'multiplier_rate' => $g['multiplier_rate'],
            ]);

            GradeBobot::create([
                'id_grade' => $idGrade,
                'bobot_name' => 'Rate ' . $g['grade_name'],
                'percent_from' => $minAchievementPct,
                'percent_to' => 9999,
                'pengali' => true,
                'bobot' => $g['multiplier_rate'],
                'nominal' => 0,
            ]);
        }

        return $header;
    }
}

<?php

namespace Database\Seeders;

use App\Models\Grade;
use App\Models\GradeBobot;
use App\Models\MasterTarget;
use App\Models\Position;
use App\Models\Role;
use App\Models\SalesSurabayaAssignment;
use App\Models\SelloutSalesSurabaya;
use App\Models\TargetHeader;
use App\Models\User;
use App\Services\IncentiveCalculationService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class SurabayaDemoSeeder extends Seeder
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

            $posAsc = Position::firstOrCreate(['code' => 'ASC'], ['name' => 'Area Sales Coordinator', 'is_active' => true]);
            $posTo = Position::firstOrCreate(['code' => 'TO'], ['name' => 'Sales Taking Order', 'is_active' => true]);
            $posSm = Position::firstOrCreate(['code' => 'SM'], ['name' => 'Sales Motoris', 'is_active' => true]);

            // 1. Konfigurasi Setting Surabaya (ASC, TO, SM)
            $this->upsertSurabayaHeader(
                $posAsc,
                'Insentif Sales Surabaya ASC',
                100.00,
                100.00,
                [
                    ['grade_name' => 'Grade 1 (1.000 - 2.500 Kg)', 'target_from' => 1000, 'target_to' => 2500, 'multiplier_rate' => 0.50],
                    ['grade_name' => 'Grade 2 (2.501 - 5.000 Kg)', 'target_from' => 2501, 'target_to' => 5000, 'multiplier_rate' => 0.25],
                    ['grade_name' => 'Grade 3 (5.001 - 10.000 Kg)', 'target_from' => 5001, 'target_to' => 10000, 'multiplier_rate' => 0.20],
                    ['grade_name' => 'Grade 4 (> 10.000 Kg)', 'target_from' => 10001, 'target_to' => 999999999, 'multiplier_rate' => 0.15],
                ]
            );

            $this->upsertSurabayaHeader(
                $posTo,
                'Insentif Sell-Out Surabaya TO',
                100.00,
                80.00,
                [
                    ['grade_name' => 'Grade 1 (1.000 - 2.500 Kg)', 'target_from' => 1000, 'target_to' => 2500, 'multiplier_rate' => 1.00],
                    ['grade_name' => 'Grade 2 (2.501 - 5.000 Kg)', 'target_from' => 2501, 'target_to' => 5000, 'multiplier_rate' => 1.50],
                    ['grade_name' => 'Grade 3 (5.001 - 10.000 Kg)', 'target_from' => 5001, 'target_to' => 10000, 'multiplier_rate' => 2.00],
                    ['grade_name' => 'Grade 4 (> 10.000 Kg)', 'target_from' => 10001, 'target_to' => 999999999, 'multiplier_rate' => 2.50],
                ],
                3
            );

            $this->upsertSurabayaHeader(
                $posSm,
                'Insentif Sell-Out Surabaya SM',
                100.00,
                80.00,
                [
                    ['grade_name' => 'Grade 1 (1.000 - 2.500 Kg)', 'target_from' => 1000, 'target_to' => 2500, 'multiplier_rate' => 1.00],
                    ['grade_name' => 'Grade 2 (2.501 - 5.000 Kg)', 'target_from' => 2501, 'target_to' => 5000, 'multiplier_rate' => 1.50],
                    ['grade_name' => 'Grade 3 (5.001 - 10.000 Kg)', 'target_from' => 5001, 'target_to' => 10000, 'multiplier_rate' => 2.00],
                    ['grade_name' => 'Grade 4 (> 10.000 Kg)', 'target_from' => 10001, 'target_to' => 999999999, 'multiplier_rate' => 2.50],
                ]
            );

            // 2. Personil Sales Surabaya (Sesuai spesifikasi: Alex ASC, Bobi TO, Nino SM)
            $alex = $this->upsertSurabayaUser('alex_asc_sby', 'Alex (SBY)', $salesRole->id, $posAsc->id);
            $bobi = $this->upsertSurabayaUser('bobi_to_sby', 'Bobi', $salesRole->id, $posTo->id);
            $nino = $this->upsertSurabayaUser('nino_sm_sby', 'Nino', $salesRole->id, $posSm->id);

            // 3. Penugasan Hierarki ASC -> Bawahan (TO & SM)
            SalesSurabayaAssignment::updateOrCreate(
                ['coordinator_id' => $alex->id, 'sales_id' => $bobi->id, 'period' => $period],
                ['sales_type' => 'Taking Order', 'is_active' => true]
            );

            SalesSurabayaAssignment::updateOrCreate(
                ['coordinator_id' => $alex->id, 'sales_id' => $nino->id, 'period' => $period],
                ['sales_type' => 'Sales Motoris', 'is_active' => true]
            );

            // 4. Master Target Bulanan (TO & SM; ASC dievaluasi dari bawahan)
            MasterTarget::updateOrCreate(
                [
                    'user_id' => $bobi->id,
                    'kategori_skema' => 'SURABAYA',
                    'metrik_target' => 'SELL_OUT',
                    'period' => $period,
                ],
                ['level' => 'SALES', 'target_quota' => 1500, 'target_outlet' => null]
            );

            MasterTarget::updateOrCreate(
                [
                    'user_id' => $nino->id,
                    'kategori_skema' => 'SURABAYA',
                    'metrik_target' => 'SELL_OUT',
                    'period' => $period,
                ],
                ['level' => 'SALES', 'target_quota' => 3000, 'target_outlet' => null]
            );

            // 5. Realisasi Penjualan Langsung Surabaya (Kg)
            SelloutSalesSurabaya::updateOrCreate(
                ['sales_id' => $bobi->id, 'period' => $period],
                ['coordinator_id' => $alex->id, 'volume' => 2000, 'active_outlet_count' => 0]
            );

            SelloutSalesSurabaya::updateOrCreate(
                ['sales_id' => $nino->id, 'period' => $period],
                ['coordinator_id' => $alex->id, 'volume' => 4000, 'active_outlet_count' => 0]
            );

            // 6. Simpan hasil kalkulasi Surabaya ke riwayat
            app(IncentiveCalculationService::class)->execute('SURABAYA', $period, $admin->id);
        });
    }

    private function upsertSurabayaUser(string $username, string $name, int $roleId, int $positionId): User
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
                'is_eligible_industri' => false,
                'is_eligible_surabaya' => true,
            ]
        );
    }

    private function upsertSurabayaHeader(
        Position $position,
        string $nama,
        float $bobot,
        float $minAchievementPct,
        array $gradesData,
        ?int $preferredId = null
    ): TargetHeader {
        $header = null;
        if ($preferredId !== null) {
            $header = TargetHeader::where('id', $preferredId)
                ->where('kategori_skema', 'SURABAYA')
                ->where('sales_type', $position->id)
                ->first();
        }

        if ($header === null) {
            $header = TargetHeader::where('kategori_skema', 'SURABAYA')
                ->where('sales_type', $position->id)
                ->first();
        }

        if ($header !== null) {
            $header->update([
                'nama' => $nama,
                'type' => 'SELL_OUT',
                'bobot' => $bobot,
                'min_achievement_pct' => $minAchievementPct,
                'aktif' => true,
                'aktif_from' => '20240101',
                'aktif_to' => '20301231',
            ]);
        } else {
            $header = TargetHeader::create([
                'nama' => $nama,
                'kategori_skema' => 'SURABAYA',
                'sales_type' => $position->id,
                'type' => 'SELL_OUT',
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

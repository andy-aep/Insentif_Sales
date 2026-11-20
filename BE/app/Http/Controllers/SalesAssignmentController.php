<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\IndustriCustomer;
use App\Models\MasterTarget;
use App\Models\SalesDistributorAssignment;
use App\Models\SalesIndustriAssignment;
use App\Models\SalesSurabayaAssignment;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SalesAssignmentController extends Controller
{
    /**
     * Ambil seluruh penugasan Sales Distributor (Konsumsi: NSM, LSM, ASM, & SPV).
     * Memakai query ringan + lookup map agar 1.700+ baris tidak memicu overhead hidrasi Eloquent bersarang.
     */
    public function indexDistributor(Request $request): JsonResponse
    {
        $rows = DB::table('sales_distributor_assignments')
            ->select([
                'id',
                'user_id',
                'nsm_id',
                'lsm_id',
                'asm_id',
                'region_id',
                'distributor_id',
                'depo_id',
                'area_id',
                'period',
                'is_active',
                'notes',
            ])
            ->when($request->filled('period'), fn ($q) => $q->where('period', $request->period))
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('region_id'), fn ($q) => $q->where('region_id', $request->region_id))
            ->when($request->filled('distributor_id'), fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->when($request->filled('asm_id'), fn ($q) => $q->where('asm_id', $request->asm_id))
            ->when($request->filled('lsm_id'), fn ($q) => $q->where('lsm_id', $request->lsm_id))
            ->when($request->filled('nsm_id'), fn ($q) => $q->where('nsm_id', $request->nsm_id))
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get();

        if ($rows->isEmpty()) {
            return response()->json([]);
        }

        $userIds = [];
        $regionIds = [];
        $distIds = [];
        $depoIds = [];
        $areaIds = [];

        foreach ($rows as $r) {
            if ($r->user_id) {
                $userIds[$r->user_id] = true;
            }
            if ($r->nsm_id) {
                $userIds[$r->nsm_id] = true;
            }
            if ($r->lsm_id) {
                $userIds[$r->lsm_id] = true;
            }
            if ($r->asm_id) {
                $userIds[$r->asm_id] = true;
            }
            if ($r->region_id) {
                $regionIds[$r->region_id] = true;
            }
            if ($r->distributor_id) {
                $distIds[$r->distributor_id] = true;
            }
            if ($r->depo_id) {
                $depoIds[$r->depo_id] = true;
            }
            if ($r->area_id) {
                $areaIds[$r->area_id] = true;
            }
        }

        $positions = DB::table('positions')
            ->select('id', 'code', 'name')
            ->get()
            ->mapWithKeys(fn ($p) => [$p->id => [
                'id' => (int) $p->id,
                'code' => $p->code,
                'name' => $p->name,
            ]])
            ->all();

        $users = empty($userIds)
            ? []
            : DB::table('users')
                ->whereIn('id', array_keys($userIds))
                ->select(
                    'id',
                    'name',
                    'username',
                    'role_id',
                    'position_id',
                    'is_eligible_konsumsi',
                    'is_eligible_industri',
                    'is_eligible_surabaya'
                )
                ->get()
                ->mapWithKeys(function ($u) use ($positions) {
                    $pos = $u->position_id && isset($positions[$u->position_id])
                        ? $positions[$u->position_id]
                        : null;

                    return [$u->id => [
                        'id' => (int) $u->id,
                        'name' => $u->name,
                        'username' => $u->username,
                        'role_id' => (int) $u->role_id,
                        'position_id' => $u->position_id ? (int) $u->position_id : null,
                        'is_eligible_konsumsi' => (bool) $u->is_eligible_konsumsi,
                        'is_eligible_industri' => (bool) $u->is_eligible_industri,
                        'is_eligible_surabaya' => (bool) $u->is_eligible_surabaya,
                        'position' => $pos,
                    ]];
                })
                ->all();

        $distributorsRaw = empty($distIds)
            ? collect()
            : DB::table('distributors')
                ->whereIn('id', array_keys($distIds))
                ->select('id', 'code', 'name', 'region_id')
                ->get();

        foreach ($distributorsRaw as $d) {
            if ($d->region_id) {
                $regionIds[$d->region_id] = true;
            }
        }

        $regions = empty($regionIds)
            ? []
            : DB::table('regions')
                ->whereIn('id', array_keys($regionIds))
                ->select('id', 'code', 'name')
                ->get()
                ->mapWithKeys(fn ($reg) => [$reg->id => [
                    'id' => (int) $reg->id,
                    'code' => $reg->code,
                    'name' => $reg->name,
                ]])
                ->all();

        $distributors = [];
        foreach ($distributorsRaw as $d) {
            $distributors[$d->id] = [
                'id' => (int) $d->id,
                'code' => $d->code,
                'name' => $d->name,
                'region_id' => $d->region_id ? (int) $d->region_id : null,
                'region' => ($d->region_id && isset($regions[$d->region_id])) ? $regions[$d->region_id] : null,
            ];
        }

        $depos = empty($depoIds)
            ? []
            : DB::table('depos')
                ->whereIn('id', array_keys($depoIds))
                ->select('id', 'distributor_id', 'code', 'name')
                ->get()
                ->mapWithKeys(fn ($dp) => [$dp->id => [
                    'id' => (int) $dp->id,
                    'distributor_id' => $dp->distributor_id ? (int) $dp->distributor_id : null,
                    'code' => $dp->code,
                    'name' => $dp->name,
                ]])
                ->all();

        $areas = empty($areaIds)
            ? []
            : DB::table('areas')
                ->whereIn('id', array_keys($areaIds))
                ->select('id', 'depo_id', 'code', 'name')
                ->get()
                ->mapWithKeys(fn ($ar) => [$ar->id => [
                    'id' => (int) $ar->id,
                    'depo_id' => $ar->depo_id ? (int) $ar->depo_id : null,
                    'code' => $ar->code,
                    'name' => $ar->name,
                ]])
                ->all();

        $subordinateLsmsByNsm = [];
        foreach ($rows as $r) {
            if ($r->nsm_id) {
                $subordinateLsmsByNsm[$r->nsm_id][] = [
                    'id' => (int) $r->id,
                    'user_id' => (int) $r->user_id,
                    'nsm_id' => (int) $r->nsm_id,
                    'region_id' => $r->region_id ? (int) $r->region_id : null,
                    'period' => $r->period,
                    'is_active' => (bool) $r->is_active,
                    'user' => $users[$r->user_id] ?? null,
                    'region' => ($r->region_id && isset($regions[$r->region_id])) ? $regions[$r->region_id] : null,
                ];
            }
        }

        $payload = [];
        foreach ($rows as $r) {
            $userObj = $users[$r->user_id] ?? null;
            $posCode = strtoupper($userObj['position']['code'] ?? '');
            $subLsms = ($posCode === 'NSM' && isset($subordinateLsmsByNsm[$r->user_id]))
                ? $subordinateLsmsByNsm[$r->user_id]
                : [];

            $item = [
                'id' => (int) $r->id,
                'user_id' => (int) $r->user_id,
                'nsm_id' => $r->nsm_id ? (int) $r->nsm_id : null,
                'lsm_id' => $r->lsm_id ? (int) $r->lsm_id : null,
                'asm_id' => $r->asm_id ? (int) $r->asm_id : null,
                'region_id' => $r->region_id ? (int) $r->region_id : null,
                'distributor_id' => $r->distributor_id ? (int) $r->distributor_id : null,
                'depo_id' => $r->depo_id ? (int) $r->depo_id : null,
                'area_id' => $r->area_id ? (int) $r->area_id : null,
                'period' => $r->period,
                'is_active' => (bool) $r->is_active,
                'notes' => $r->notes,
                'user' => $userObj,
                'nsm' => ($r->nsm_id && isset($users[$r->nsm_id])) ? $users[$r->nsm_id] : null,
                'lsm' => ($r->lsm_id && isset($users[$r->lsm_id])) ? $users[$r->lsm_id] : null,
                'asm' => ($r->asm_id && isset($users[$r->asm_id])) ? $users[$r->asm_id] : null,
                'region' => ($r->region_id && isset($regions[$r->region_id])) ? $regions[$r->region_id] : null,
                'distributor' => ($r->distributor_id && isset($distributors[$r->distributor_id])) ? $distributors[$r->distributor_id] : null,
                'depo' => ($r->depo_id && isset($depos[$r->depo_id])) ? $depos[$r->depo_id] : null,
                'area' => ($r->area_id && isset($areas[$r->area_id])) ? $areas[$r->area_id] : null,
            ];

            if (!empty($subLsms)) {
                $item['subordinate_lsms'] = $subLsms;
            }

            $payload[] = $item;
        }

        return response()->json($payload);
    }

    /**
     * Simpan penugasan Sales Distributor (Konsumsi).
     * Aturan Hierarki:
     * - NSM: Membawahi seluruh nasional ATAU membawahi LSM/Region tertentu (misal: Indonesia Timur, Barat, dll)
     * - LSM: Atasan dari ASM, memegang Region tertentu dan melapor ke NSM
     * - ASM: Di bawah LSM, memegang Distributor beserta seluruh Depo & Area-nya
     * - SPV: Di bawah ASM, memanage Area tertentu dari Depo distributor tersebut
     */
    public function storeDistributor(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'required|exists:users,id',
            'region_id' => 'nullable|exists:regions,id',
            'distributor_id' => 'nullable|exists:distributors,id',
            'nsm_id' => 'nullable|exists:users,id',
            'lsm_id' => 'nullable|exists:users,id',
            'asm_id' => 'nullable|exists:users,id',
            'depo_id' => 'nullable|exists:depos,id',
            'area_id' => 'nullable|exists:areas,id',
            'lsm_ids' => 'nullable|array',
            'lsm_ids.*' => 'exists:users,id',
            'period' => 'nullable|string|max:6',
            'notes' => 'nullable|string|max:255',
        ]);

        $user = User::with('position')->findOrFail($validated['user_id']);

        if (!$user->is_eligible_konsumsi) {
            return response()->json([
                'message' => 'Sales personil ini belum ditandai eligible untuk Insentif Konsumsi (Distributor).',
            ], 422);
        }

        $posCode = strtoupper($user->position?->code ?? '');
        $period = !empty($validated['period']) ? $validated['period'] : '202610';

        $nsmId = $validated['nsm_id'] ?? null;
        $lsmId = $validated['lsm_id'] ?? null;
        $asmId = $validated['asm_id'] ?? null;
        $regionId = $validated['region_id'] ?? null;
        $distributorId = $validated['distributor_id'] ?? null;
        $depoId = null;
        $areaId = null;

        if ($posCode === 'NSM') {
            // Posisi NSM: Bisa membawahi seluruh nasional ATAU teritorial khusus (Indonesia Timur, Barat, dll)
            $assignment = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('period', $period)
                ->first();

            if ($assignment) {
                $assignment->update([
                    'region_id' => $regionId,
                    'notes' => $validated['notes'] ?? $assignment->notes,
                    'is_active' => true,
                ]);
            } else {
                $assignment = SalesDistributorAssignment::create([
                    'user_id' => $user->id,
                    'region_id' => $regionId,
                    'period' => $period,
                    'is_active' => true,
                    'notes' => $validated['notes'] ?? null,
                ]);
            }

            // Jika ada daftar LSM yang dipilih untuk dipimpin oleh NSM ini:
            if (array_key_exists('lsm_ids', $validated)) {
                $chosenLsmIds = $validated['lsm_ids'] ?? [];

                // Lepas NSM dari LSM yang tidak lagi dipilih
                SalesDistributorAssignment::where('nsm_id', $user->id)
                    ->where('period', $period)
                    ->whereNotIn('user_id', $chosenLsmIds)
                    ->update(['nsm_id' => null]);

                // Hubungkan LSM terpilih ke NSM ini
                if (!empty($chosenLsmIds)) {
                    SalesDistributorAssignment::whereIn('user_id', $chosenLsmIds)
                        ->where('period', $period)
                        ->update(['nsm_id' => $user->id]);
                }
            }

            return response()->json([
                'message' => 'Penugasan NSM berhasil disimpan',
                'data' => $assignment->load([
                    'user.position',
                    'subordinateLsms.user.position',
                    'subordinateLsms.region',
                    'region',
                ]),
            ], 201);
        } elseif ($posCode === 'LSM') {
            // Posisi LSM: Atasan ASM, wajib memegang Region tertentu
            if (empty($regionId)) {
                return response()->json([
                    'message' => 'LSM wajib memilih Region yang dipegang.',
                ], 422);
            }

            $exists = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('region_id', $regionId)
                ->where('period', $period)
                ->exists();

            if ($exists) {
                return response()->json([
                    'message' => "LSM {$user->name} sudah di-assign ke region ini untuk periode {$period}.",
                ], 422);
            }
        } elseif ($posCode === 'ASM') {
            // Posisi ASM: Atasan SPV, di bawah LSM, memegang penuh Distributor & deponya
            if (empty($distributorId)) {
                return response()->json([
                    'message' => 'ASM wajib memilih Distributor yang dipegang.',
                ], 422);
            }

            // Ambil region distributor jika belum diset
            $distributor = Distributor::find($distributorId);
            if ($distributor && $distributor->region_id && empty($regionId)) {
                $regionId = $distributor->region_id;
            }

            $exists = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('distributor_id', $distributorId)
                ->where('period', $period)
                ->exists();

            if ($exists) {
                return response()->json([
                    'message' => "ASM {$user->name} sudah di-assign ke distributor ini untuk periode {$period}.",
                ], 422);
            }
        } elseif ($posCode === 'SPV') {
            // Posisi SPV: wajib memiliki ASM penanggung jawab, Depo, dan Area
            if (empty($distributorId)) {
                return response()->json([
                    'message' => 'Pilih Distributor untuk penugasan SPV.',
                ], 422);
            }

            if (empty($asmId)) {
                return response()->json([
                    'message' => 'SPV harus ditempatkan di bawah atasan ASM penanggung jawab distributor.',
                ], 422);
            }

            if (empty($validated['depo_id'])) {
                return response()->json([
                    'message' => 'Pilih Depo untuk penugasan SPV.',
                ], 422);
            }

            if (empty($validated['area_id'])) {
                return response()->json([
                    'message' => 'Pilih Area yang di-manage oleh SPV.',
                ], 422);
            }

            $depo = Depo::where('id', $validated['depo_id'])
                ->where('distributor_id', $distributorId)
                ->first();

            if (!$depo) {
                return response()->json([
                    'message' => 'Depo yang dipilih tidak sesuai dengan Distributor.',
                ], 422);
            }

            $area = Area::where('id', $validated['area_id'])
                ->where('depo_id', $depo->id)
                ->first();

            if (!$area) {
                return response()->json([
                    'message' => 'Area yang dipilih tidak sesuai dengan Depo terpilih.',
                ], 422);
            }

            $distributor = Distributor::find($distributorId);
            if ($distributor && $distributor->region_id) {
                $regionId = $distributor->region_id;
            }

            $depoId = $depo->id;
            $areaId = $area->id;

            $exists = SalesDistributorAssignment::where('user_id', $user->id)
                ->where('area_id', $areaId)
                ->where('period', $period)
                ->exists();

            if ($exists) {
                return response()->json([
                    'message' => "SPV {$user->name} sudah di-assign ke Area {$area->name} untuk periode {$period}.",
                ], 422);
            }
        }

        $assignment = SalesDistributorAssignment::create([
            'user_id' => $user->id,
            'nsm_id' => $nsmId,
            'lsm_id' => $lsmId,
            'asm_id' => $asmId,
            'region_id' => $regionId,
            'distributor_id' => $distributorId,
            'depo_id' => $depoId,
            'area_id' => $areaId,
            'period' => $period,
            'is_active' => true,
            'notes' => $validated['notes'] ?? null,
        ]);

        // Sinkronisasi otomatis ke Master Target (PIC Depo = ASM, PIC Area = SPV)
        if ($posCode === 'ASM' && $distributorId) {
            MasterTarget::where('distributor_id', $distributorId)
                ->where('level', 'DEPO')
                ->where('kategori_skema', 'KONSUMSI')
                ->when($period, fn ($q) => $q->where('period', $period))
                ->update(['user_id' => $user->id]);
        } elseif ($posCode === 'SPV' && $areaId) {
            MasterTarget::where('area_id', $areaId)
                ->where('level', 'AREA')
                ->where('kategori_skema', 'KONSUMSI')
                ->when($period, fn ($q) => $q->where('period', $period))
                ->update(['user_id' => $user->id]);
        }

        return response()->json([
            'message' => 'Penugasan Sales Distributor berhasil disimpan',
            'data' => $assignment->load([
                'user.position',
                'nsm',
                'lsm',
                'asm',
                'region',
                'distributor.region',
                'depo',
                'area',
            ]),
        ], 201);
    }

    /**
     * Pemetaan massal 1 Distributor (ASM + seluruh Area SPV/ASC) sekaligus dalam 1 transaksi.
     */
    public function bulkMapDistributor(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'distributor_id' => 'required|integer|exists:distributors,id',
            'period' => 'nullable|string|max:6',
            'is_full_year' => 'nullable|boolean',
            'year' => 'nullable|string|size:4',
            'asm_user_id' => 'nullable|integer|exists:users,id',
            'areas' => 'nullable|array',
            'areas.*.depo_id' => 'required|integer|exists:depos,id',
            'areas.*.area_id' => 'required|integer|exists:areas,id',
            'areas.*.spv_user_id' => 'nullable|integer|exists:users,id',
        ]);

        $distributor = Distributor::findOrFail($validated['distributor_id']);
        $isFullYear = $request->boolean('is_full_year');
        $periods = [];
        if ($isFullYear) {
            $year = ! empty($validated['year']) ? $validated['year'] : substr((string) ($validated['period'] ?? date('Y')), 0, 4);
            for ($m = 1; $m <= 12; $m++) {
                $periods[] = sprintf('%04d%02d', (int) $year, $m);
            }
        } else {
            $p = preg_replace('/[^0-9]/', '', (string) ($validated['period'] ?? date('Ym')));
            $periods[] = strlen($p) === 6 ? $p : date('Ym');
        }

        $asmUserId = ! empty($validated['asm_user_id']) ? (int) $validated['asm_user_id'] : null;
        $areasInput = $validated['areas'] ?? [];

        DB::transaction(function () use ($distributor, $periods, $asmUserId, $areasInput) {
            foreach ($periods as $p) {
                // 1. Update/Replace ASM untuk Distributor ini pada periode $p
                SalesDistributorAssignment::where('distributor_id', $distributor->id)
                    ->whereNull('area_id')
                    ->where('period', $p)
                    ->delete();

                if ($asmUserId) {
                    SalesDistributorAssignment::create([
                        'user_id' => $asmUserId,
                        'region_id' => $distributor->region_id,
                        'distributor_id' => $distributor->id,
                        'depo_id' => null,
                        'area_id' => null,
                        'period' => $p,
                        'is_active' => true,
                    ]);
                }

                // Sinkronkan PIC Depo di Master Target
                MasterTarget::where('distributor_id', $distributor->id)
                    ->where('level', 'DEPO')
                    ->where('kategori_skema', 'KONSUMSI')
                    ->where('period', $p)
                    ->update(['user_id' => $asmUserId]);

                // 2. Update/Replace SPV/ASC untuk tiap Area pada periode $p
                foreach ($areasInput as $areaRow) {
                    $depoId = (int) $areaRow['depo_id'];
                    $areaId = (int) $areaRow['area_id'];
                    $spvUserId = ! empty($areaRow['spv_user_id']) ? (int) $areaRow['spv_user_id'] : null;

                    SalesDistributorAssignment::where('area_id', $areaId)
                        ->where('period', $p)
                        ->delete();

                    if ($spvUserId) {
                        SalesDistributorAssignment::create([
                            'user_id' => $spvUserId,
                            'asm_id' => $asmUserId,
                            'region_id' => $distributor->region_id,
                            'distributor_id' => $distributor->id,
                            'depo_id' => $depoId,
                            'area_id' => $areaId,
                            'period' => $p,
                            'is_active' => true,
                        ]);
                    }

                    // Sinkronkan PIC Area di Master Target
                    MasterTarget::where('area_id', $areaId)
                        ->where('level', 'AREA')
                        ->where('kategori_skema', 'KONSUMSI')
                        ->where('period', $p)
                        ->update(['user_id' => $spvUserId]);
                }
            }
        });

        return response()->json([
            'message' => $isFullYear
                ? "Pemetaan PIC {$distributor->name} untuk 12 bulan berhasil disimpan."
                : "Pemetaan PIC {$distributor->name} periode {$periods[0]} berhasil disimpan.",
        ]);
    }

    /**
     * Hapus penugasan Sales Distributor.
     */
    public function destroyDistributor(int $id): JsonResponse
    {
        $assignment = SalesDistributorAssignment::findOrFail($id);
        $userId = $assignment->user_id;
        $distId = $assignment->distributor_id;
        $areaId = $assignment->area_id;
        $period = $assignment->period;

        $assignment->delete();

        // Re-sinkronisasi Master Target ke penugasan lain atau null jika sudah tidak ada
        if ($distId) {
            $otherAsm = SalesDistributorAssignment::where('distributor_id', $distId)
                ->where('is_active', true)
                ->whereHas('user.position', fn ($q) => $q->where('code', 'ASM'))
                ->when($period, fn ($q) => $q->where('period', $period))
                ->first();

            MasterTarget::where('distributor_id', $distId)
                ->where('level', 'DEPO')
                ->where('user_id', $userId)
                ->when($period, fn ($q) => $q->where('period', $period))
                ->update(['user_id' => $otherAsm?->user_id]);
        }

        if ($areaId) {
            $otherSpv = SalesDistributorAssignment::where('area_id', $areaId)
                ->where('is_active', true)
                ->whereHas('user.position', fn ($q) => $q->where('code', 'SPV'))
                ->when($period, fn ($q) => $q->where('period', $period))
                ->first();

            MasterTarget::where('area_id', $areaId)
                ->where('level', 'AREA')
                ->where('user_id', $userId)
                ->when($period, fn ($q) => $q->where('period', $period))
                ->update(['user_id' => $otherSpv?->user_id]);
        }

        return response()->json([
            'message' => 'Penugasan Sales Distributor berhasil dihapus',
        ]);
    }

    /**
     * Ambil penugasan Sales Surabaya.
     */
    public function indexSurabaya(Request $request): JsonResponse
    {
        $query = SalesSurabayaAssignment::with(['coordinator.position', 'sales.position'])
            ->when($request->filled('period'), fn ($q) => $q->where('period', $request->period))
            ->latest();

        return response()->json($query->get());
    }

    /**
     * Simpan penugasan Sales Surabaya.
     */
    public function storeSurabaya(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'coordinator_id' => 'required|exists:users,id',
            'sales_id' => 'required|exists:users,id',
            'sales_type' => 'required|string|in:Taking Order,Sales Motoris,Canvasing,TO,SM',
            'period' => 'required|string|max:6',
        ]);

        $assignment = SalesSurabayaAssignment::create([
            'coordinator_id' => $validated['coordinator_id'],
            'sales_id' => $validated['sales_id'],
            'sales_type' => $validated['sales_type'],
            'period' => $validated['period'],
            'is_active' => true,
        ]);

        return response()->json([
            'message' => 'Penugasan Koordinator & Sales Surabaya berhasil disimpan',
            'data' => $assignment->load(['coordinator.position', 'sales.position']),
        ], 201);
    }

    /**
     * Hapus penugasan Sales Surabaya.
     */
    public function destroySurabaya(int $id): JsonResponse
    {
        $assignment = SalesSurabayaAssignment::findOrFail($id);
        $assignment->delete();

        return response()->json([
            'message' => 'Penugasan Sales Surabaya berhasil dihapus',
        ]);
    }

    /**
     * Ambil penugasan Sales Industri (ASM / SPV / ASC -> Customer Industri).
     */
    public function indexIndustri(Request $request): JsonResponse
    {
        $query = SalesIndustriAssignment::with(['user.position', 'customer'])
            ->when($request->filled('period'), function ($q) use ($request) {
                $p = $request->period;
                $q->where(function ($sub) use ($p) {
                    $sub->where('period', $p)
                        ->orWhereNull('period')
                        ->orWhere('period', '');
                });
            })
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('industri_customer_id'), fn ($q) => $q->where('industri_customer_id', $request->industri_customer_id))
            ->latest();

        return response()->json($query->get());
    }

    /**
     * Simpan penugasan Sales Industri (Sales ASM/SPV/ASC memegang Customer Industri tertentu).
     */
    public function storeIndustri(Request $request): JsonResponse
    {
        if (!$request->filled('industri_customer_id') && $request->filled('customer_id')) {
            $request->merge(['industri_customer_id' => $request->customer_id]);
        }

        $validated = $request->validate([
            'user_id' => 'required|exists:users,id',
            'industri_customer_id' => 'nullable|exists:industri_customers,id',
            'customer_code' => 'required_without:industri_customer_id|nullable|string|max:64',
            'customer_name' => 'required_without:industri_customer_id|nullable|string|max:255',
            'city' => 'nullable|string|max:100',
            'customer_type' => 'nullable|in:NEW,EXISTING',
            'period' => 'nullable|string|max:6',
            'notes' => 'nullable|string|max:255',
        ]);

        $user = User::with('position')->findOrFail($validated['user_id']);
        if (!$user->is_eligible_industri) {
            return response()->json([
                'message' => "User {$user->name} belum ditandai eligible untuk Insentif Industri (is_eligible_industri = false).",
            ], 422);
        }

        $posCode = strtoupper($user->position?->code ?? '');
        if (!in_array($posCode, ['ASM', 'SPV', 'ASC'], true)) {
            return response()->json([
                'message' => 'Posisi sales Industri hanya mendukung ASM, SPV, atau ASC.',
            ], 422);
        }

        $period = !empty($validated['period']) ? trim($validated['period']) : null;

        if (!empty($validated['industri_customer_id'])) {
            $customer = IndustriCustomer::findOrFail($validated['industri_customer_id']);
        } else {
            $code = strtoupper(trim((string) $validated['customer_code']));
            $customer = IndustriCustomer::firstOrCreate(
                ['customer_code' => $code],
                [
                    'customer_name' => trim((string) $validated['customer_name']),
                    'city' => !empty($validated['city']) ? trim((string) $validated['city']) : null,
                    'customer_type' => $validated['customer_type'] ?? 'EXISTING',
                    'is_active' => true,
                ]
            );
        }

        $exists = SalesIndustriAssignment::where('user_id', $user->id)
            ->where('industri_customer_id', $customer->id)
            ->where('is_active', true)
            ->when($period, fn ($q) => $q->where('period', $period), fn ($q) => $q->whereNull('period'))
            ->exists();

        if ($exists) {
            return response()->json([
                'message' => "{$user->name} sudah di-assign ke customer {$customer->customer_name}" . ($period ? " pada periode {$period}" : '') . '.',
            ], 422);
        }

        $assignment = SalesIndustriAssignment::create([
            'user_id' => $user->id,
            'industri_customer_id' => $customer->id,
            'period' => $period,
            'is_active' => true,
            'notes' => $validated['notes'] ?? null,
        ]);

        return response()->json([
            'message' => 'Penugasan Sales & Customer Industri berhasil disimpan',
            'data' => $assignment->load(['user.position', 'customer']),
        ], 201);
    }

    /**
     * Hapus penugasan Sales Industri.
     */
    public function destroyIndustri(int $id): JsonResponse
    {
        $assignment = SalesIndustriAssignment::findOrFail($id);
        $assignment->delete();

        return response()->json([
            'message' => 'Penugasan Sales Industri berhasil dihapus',
        ]);
    }
}

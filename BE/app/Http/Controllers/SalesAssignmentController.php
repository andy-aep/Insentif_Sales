<?php

namespace App\Http\Controllers;

use App\Models\Area;
use App\Models\Depo;
use App\Models\Distributor;
use App\Models\SalesDistributorAssignment;
use App\Models\SalesSurabayaAssignment;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SalesAssignmentController extends Controller
{
    /**
     * Ambil seluruh penugasan Sales Distributor (Konsumsi: NSM, LSM, ASM, & SPV).
     */
    public function indexDistributor(Request $request): JsonResponse
    {
        $query = SalesDistributorAssignment::with([
            'user.position',
            'nsm',
            'lsm',
            'asm',
            'region',
            'distributor.region',
            'depo',
            'area',
            'subordinateLsms.user.position',
            'subordinateLsms.region',
        ])
            ->when($request->filled('period'), fn ($q) => $q->where('period', $request->period))
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('region_id'), fn ($q) => $q->where('region_id', $request->region_id))
            ->when($request->filled('distributor_id'), fn ($q) => $q->where('distributor_id', $request->distributor_id))
            ->when($request->filled('asm_id'), fn ($q) => $q->where('asm_id', $request->asm_id))
            ->when($request->filled('lsm_id'), fn ($q) => $q->where('lsm_id', $request->lsm_id))
            ->when($request->filled('nsm_id'), fn ($q) => $q->where('nsm_id', $request->nsm_id))
            ->latest();

        return response()->json($query->get());
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
     * Hapus penugasan Sales Distributor.
     */
    public function destroyDistributor(int $id): JsonResponse
    {
        $assignment = SalesDistributorAssignment::findOrFail($id);
        $assignment->delete();

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
            'sales_type' => 'required|string|in:Taking Order,Canvasing',
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
}

<?php

use App\Http\Controllers\AreaController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BatchUploadController;
use App\Http\Controllers\BrandController;
use App\Http\Controllers\DepoController;
use App\Http\Controllers\DistributorController;
use App\Http\Controllers\GradeBobotController;
use App\Http\Controllers\GradeController;
use App\Http\Controllers\IncentiveCalculationController;
use App\Http\Controllers\MasterTargetController;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\NilaiRewardController;
use App\Http\Controllers\PercentTargetController;
use App\Http\Controllers\PositionController;
use App\Http\Controllers\RegionController;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\SalesAssignmentController;
use App\Http\Controllers\TargetHeaderController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Route;

// Public Authentication Route
Route::post('/login', [AuthController::class, 'login']);

// Authenticated Sanctum Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Master Access & Users
    Route::apiResource('users', UserController::class);
    Route::apiResource('roles', RoleController::class);
    Route::apiResource('positions', PositionController::class);
    Route::apiResource('menus', MenuController::class);

    // Master Organization & Brands
    Route::apiResource('regions', RegionController::class);
    Route::apiResource('brands', BrandController::class);
    Route::apiResource('distributors', DistributorController::class);
    Route::apiResource('depos', DepoController::class);
    Route::apiResource('areas', AreaController::class);

    // Penugasan Sales (Distributor ASM/SPV & Surabaya)
    Route::get('sales-distributor-assignments', [SalesAssignmentController::class, 'indexDistributor']);
    Route::post('sales-distributor-assignments', [SalesAssignmentController::class, 'storeDistributor']);
    Route::delete('sales-distributor-assignments/{id}', [SalesAssignmentController::class, 'destroyDistributor']);
    Route::get('sales-surabaya-assignments', [SalesAssignmentController::class, 'indexSurabaya']);
    Route::post('sales-surabaya-assignments', [SalesAssignmentController::class, 'storeSurabaya']);
    Route::delete('sales-surabaya-assignments/{id}', [SalesAssignmentController::class, 'destroySurabaya']);

    // Setting Insentif (3-Level) & Penunjang
    Route::post('target-headers/{target_header}/duplicate', [TargetHeaderController::class, 'duplicate']);
    Route::apiResource('target-headers', TargetHeaderController::class);
    Route::apiResource('grades', GradeController::class);
    Route::apiResource('grade-bobots', GradeBobotController::class);
    Route::apiResource('percent-targets', PercentTargetController::class);
    Route::apiResource('nilai-rewards', NilaiRewardController::class);
    Route::get('master-targets/periods', [MasterTargetController::class, 'periods']);
    Route::apiResource('master-targets', MasterTargetController::class);

    // Kalkulasi Insentif
    Route::post('/incentives/calculate', [IncentiveCalculationController::class, 'calculate']);
    Route::get('/incentives/results', [IncentiveCalculationController::class, 'index']);
    Route::get('/incentives/export-excel', [IncentiveCalculationController::class, 'exportExcel']);

    // Batch Management & Rollback
    Route::get('/bulk-upload/history', [BatchUploadController::class, 'history']);
    Route::get('/bulk-upload/template/{entity}', [BatchUploadController::class, 'downloadTemplate']);
    Route::post('/bulk-upload/rollback/{batchId}', [BatchUploadController::class, 'rollback']);
    Route::post('/bulk-upload/{entity}', [BatchUploadController::class, 'upload']);
});

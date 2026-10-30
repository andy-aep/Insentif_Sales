<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('master_targets', function (Blueprint $table) {
            $table->foreignId('distributor_id')->nullable()->after('user_id')->constrained('distributors')->nullOnDelete();
            $table->foreignId('depo_id')->nullable()->after('distributor_id')->constrained('depos')->nullOnDelete();
            $table->foreignId('area_id')->nullable()->after('depo_id')->constrained('areas')->nullOnDelete();
            $table->foreignId('brand_id')->nullable()->after('area_id')->constrained('brands')->nullOnDelete();
            $table->string('level')->default('DEPO')->after('brand_id');
            $table->integer('target_outlet')->nullable()->after('target_quota');
            $table->foreignId('user_id')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('master_targets', function (Blueprint $table) {
            $table->dropForeign(['distributor_id']);
            $table->dropForeign(['depo_id']);
            $table->dropForeign(['area_id']);
            $table->dropForeign(['brand_id']);
            $table->dropColumn(['distributor_id', 'depo_id', 'area_id', 'brand_id', 'level', 'target_outlet']);
        });
    }
};

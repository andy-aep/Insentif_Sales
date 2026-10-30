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
        Schema::create('regions', function (Blueprint $table) {
            $table->id();
            $table->string('code', 50)->unique();
            $table->string('name', 150);
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::table('distributors', function (Blueprint $table) {
            $table->foreignId('region_id')->nullable()->after('name')->constrained('regions')->onDelete('set null');
        });

        Schema::table('sales_distributor_assignments', function (Blueprint $table) {
            $table->foreignId('region_id')->nullable()->after('user_id')->constrained('regions')->onDelete('set null');
            $table->foreignId('lsm_id')->nullable()->after('asm_id')->constrained('users')->onDelete('set null');
            $table->foreignId('nsm_id')->nullable()->after('lsm_id')->constrained('users')->onDelete('set null');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sales_distributor_assignments', function (Blueprint $table) {
            $table->dropForeign(['nsm_id']);
            $table->dropForeign(['lsm_id']);
            $table->dropForeign(['region_id']);
            $table->dropColumn(['nsm_id', 'lsm_id', 'region_id']);
        });

        Schema::table('distributors', function (Blueprint $table) {
            $table->dropForeign(['region_id']);
            $table->dropColumn('region_id');
        });

        Schema::dropIfExists('regions');
    }
};

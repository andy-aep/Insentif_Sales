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
            $table->index('period', 'idx_mt_period');
            $table->index('kategori_skema', 'idx_mt_kategori_skema');
            $table->index('level', 'idx_mt_level');
            $table->index(['period', 'kategori_skema'], 'idx_mt_period_kategori');
            $table->index(['period', 'distributor_id'], 'idx_mt_period_distributor');
            $table->index(['period', 'user_id'], 'idx_mt_period_user');
            $table->index(['period', 'metrik_target'], 'idx_mt_period_metrik');
        });

        Schema::table('sales_distributor_assignments', function (Blueprint $table) {
            $table->index('period', 'idx_sda_period');
            $table->index('is_active', 'idx_sda_is_active');
            $table->index(['period', 'is_active'], 'idx_sda_period_active');
            $table->index(['distributor_id', 'period', 'is_active'], 'idx_sda_dist_period_act');
            $table->index(['area_id', 'period', 'is_active'], 'idx_sda_area_period_act');
            $table->index(['user_id', 'period', 'is_active'], 'idx_sda_user_period_act');
        });

        if (Schema::hasTable('sales_surabaya_assignments')) {
            Schema::table('sales_surabaya_assignments', function (Blueprint $table) {
                $table->index('period', 'idx_ssa_period');
                $table->index(['period', 'is_active'], 'idx_ssa_period_active');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('master_targets', function (Blueprint $table) {
            $table->dropIndex('idx_mt_period');
            $table->dropIndex('idx_mt_kategori_skema');
            $table->dropIndex('idx_mt_level');
            $table->dropIndex('idx_mt_period_kategori');
            $table->dropIndex('idx_mt_period_distributor');
            $table->dropIndex('idx_mt_period_user');
            $table->dropIndex('idx_mt_period_metrik');
        });

        Schema::table('sales_distributor_assignments', function (Blueprint $table) {
            $table->dropIndex('idx_sda_period');
            $table->dropIndex('idx_sda_is_active');
            $table->dropIndex('idx_sda_period_active');
            $table->dropIndex('idx_sda_dist_period_act');
            $table->dropIndex('idx_sda_area_period_act');
            $table->dropIndex('idx_sda_user_period_act');
        });

        if (Schema::hasTable('sales_surabaya_assignments')) {
            Schema::table('sales_surabaya_assignments', function (Blueprint $table) {
                $table->dropIndex('idx_ssa_period');
                $table->dropIndex('idx_ssa_period_active');
            });
        }
    }
};

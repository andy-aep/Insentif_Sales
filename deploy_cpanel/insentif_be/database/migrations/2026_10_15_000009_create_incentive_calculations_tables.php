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
        Schema::create('incentive_calculations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users');
            $table->enum('kategori_skema', ['KONSUMSI', 'INDUSTRI', 'SURABAYA']);
            $table->foreignId('target_header_id')->constrained('target_headers');
            $table->foreignId('grade_id')->constrained('grades');
            $table->foreignId('grade_bobot_id')->constrained('grade_bobots');
            $table->string('period', 6); // YYYYMM
            $table->decimal('target_quota', 14, 2);
            $table->decimal('realization', 14, 2);
            $table->decimal('achievement_percent', 7, 2);
            $table->decimal('capped_realization', 14, 2);
            $table->boolean('is_rate_based');
            $table->decimal('unit_rate', 10, 2);
            $table->decimal('lump_sum_nominal', 16, 2);
            $table->decimal('header_bobot_percent', 5, 2);
            $table->decimal('final_reward', 16, 2);
            $table->foreignId('calculated_by')->constrained('users');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('incentive_calculations');
    }
};

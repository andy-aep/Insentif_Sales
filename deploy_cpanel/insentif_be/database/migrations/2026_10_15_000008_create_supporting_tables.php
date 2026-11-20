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
        Schema::create('percent_targets', function (Blueprint $table) {
            $table->id();
            $table->enum('kategori_skema', ['KONSUMSI', 'INDUSTRI', 'SURABAYA']);
            $table->string('metrik_target'); // Sell-In, Sell-Out, AO, NOO
            $table->decimal('percent_min', 6, 2);
            $table->decimal('percent_max', 6, 2);
            $table->string('performance_status'); // Under-Target, Near-Target, On-Target, Super-Achiever
            $table->string('badge_color'); // Red, Yellow, Green, Blue
            $table->boolean('is_eligible_payout')->default(true);
            $table->timestamps();
        });

        Schema::create('nilai_rewards', function (Blueprint $table) {
            $table->id();
            $table->enum('kategori_skema', ['KONSUMSI', 'INDUSTRI', 'SURABAYA']);
            $table->string('metrik_target');
            $table->string('kategori_grade');
            $table->decimal('standard_rate', 10, 2)->default(0);
            $table->decimal('standard_nominal', 16, 2)->default(0);
            $table->timestamps();
        });

        Schema::create('master_targets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users');
            $table->enum('kategori_skema', ['KONSUMSI', 'INDUSTRI', 'SURABAYA']);
            $table->string('metrik_target'); // Sell-In, Sell-Out, AO, NOO
            $table->string('period', 6); // YYYYMM
            $table->decimal('target_quota', 14, 2);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('master_targets');
        Schema::dropIfExists('nilai_rewards');
        Schema::dropIfExists('percent_targets');
    }
};

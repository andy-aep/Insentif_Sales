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
        Schema::create('target_headers', function (Blueprint $table) {
            $table->id();
            $table->string('nama');
            $table->enum('kategori_skema', ['KONSUMSI', 'INDUSTRI', 'SURABAYA'])->index();
            $table->foreignId('sales_type')->constrained('positions'); // Relasi ke Master Posisi
            $table->string('type'); // Sell-In, Sell-Out, AO, NOO
            $table->decimal('bobot', 5, 2)->default(100.00); // persentase skema
            $table->boolean('aktif')->default(true);
            $table->string('aktif_from', 8); // YYYYMMDD
            $table->string('aktif_to', 8);   // YYYYMMDD
            $table->timestamps();
        });

        Schema::create('grades', function (Blueprint $table) {
            $table->id();
            $table->uuid('id_grade')->unique();
            $table->foreignId('target_header_id')->constrained('target_headers')->onDelete('cascade');
            $table->string('grade_name'); // Grade 1, Grade 2, Platinum
            $table->decimal('target_from', 14, 2);
            $table->decimal('target_to', 14, 2);
            $table->timestamps();
        });

        Schema::create('grade_bobots', function (Blueprint $table) {
            $table->id();
            $table->uuid('id_grade');
            $table->foreign('id_grade')->references('id_grade')->on('grades')->onDelete('cascade');
            $table->string('bobot_name'); // Tier 80%, Tier 100%
            $table->decimal('percent_from', 6, 2);
            $table->decimal('percent_to', 6, 2);
            $table->boolean('pengali')->default(false); // true: Rate-based (per unit), false: Flat nominal
            $table->decimal('bobot', 10, 2)->default(0); // tarif per unit jika pengali = true
            $table->decimal('nominal', 16, 2)->default(0); // rupiah flat jika pengali = false
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('grade_bobots');
        Schema::dropIfExists('grades');
        Schema::dropIfExists('target_headers');
    }
};

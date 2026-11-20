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
        Schema::create('upload_batches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('entity_type'); // sellin_distributor, sellout_distributor, etc.
            $table->string('file_name');
            $table->integer('total_rows')->default(0);
            $table->integer('success_rows')->default(0);
            $table->integer('failed_rows')->default(0);
            $table->string('status'); // PENDING, PROCESSING, COMPLETED, ROLLED_BACK
            $table->foreignId('uploaded_by')->constrained('users');
            $table->timestamp('rolled_back_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('upload_batches');
    }
};

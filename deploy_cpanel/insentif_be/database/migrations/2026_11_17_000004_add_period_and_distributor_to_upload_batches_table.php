<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('upload_batches', function (Blueprint $table) {
            $table->string('period', 6)->nullable()->index()->after('file_path');
            $table->foreignId('distributor_id')->nullable()->after('period')->constrained('distributors')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('upload_batches', function (Blueprint $table) {
            $table->dropForeign(['distributor_id']);
            $table->dropIndex(['period']);
            $table->dropColumn(['period', 'distributor_id']);
        });
    }
};

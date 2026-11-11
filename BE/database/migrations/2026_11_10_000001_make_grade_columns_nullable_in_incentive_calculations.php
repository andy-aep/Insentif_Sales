<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('incentive_calculations', function (Blueprint $table) {
            $table->unsignedBigInteger('grade_id')->nullable()->change();
            $table->unsignedBigInteger('grade_bobot_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('incentive_calculations', function (Blueprint $table) {
            $table->unsignedBigInteger('grade_id')->nullable(false)->change();
            $table->unsignedBigInteger('grade_bobot_id')->nullable(false)->change();
        });
    }
};


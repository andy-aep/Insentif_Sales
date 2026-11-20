<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sellout_distributors', function (Blueprint $table) {
            if (! Schema::hasColumn('sellout_distributors', 'is_out_of_area')) {
                $table->boolean('is_out_of_area')->default(false)->index()->after('area_id');
            }
            $table->unsignedBigInteger('area_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('sellout_distributors', function (Blueprint $table) {
            if (Schema::hasColumn('sellout_distributors', 'is_out_of_area')) {
                $table->dropIndex(['is_out_of_area']);
                $table->dropColumn('is_out_of_area');
            }
        });
    }
};

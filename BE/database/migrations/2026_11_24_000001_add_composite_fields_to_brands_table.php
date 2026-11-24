<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('brands', function (Blueprint $table) {
            if (! Schema::hasColumn('brands', 'is_all_brands')) {
                $table->boolean('is_all_brands')->default(false)->after('name');
            }
            if (! Schema::hasColumn('brands', 'component_brand_ids')) {
                $table->json('component_brand_ids')->nullable()->after('is_all_brands');
            }
        });
    }

    public function down(): void
    {
        Schema::table('brands', function (Blueprint $table) {
            $drops = [];
            if (Schema::hasColumn('brands', 'component_brand_ids')) {
                $drops[] = 'component_brand_ids';
            }
            if (Schema::hasColumn('brands', 'is_all_brands')) {
                $drops[] = 'is_all_brands';
            }
            if (! empty($drops)) {
                $table->dropColumn($drops);
            }
        });
    }
};

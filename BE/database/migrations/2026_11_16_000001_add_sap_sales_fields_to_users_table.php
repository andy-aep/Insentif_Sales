<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->integer('sap_sales_code')->nullable()->after('position_id')->index();
            $table->string('sap_sales_name')->nullable()->after('sap_sales_code');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['sap_sales_code']);
            $table->dropColumn(['sap_sales_code', 'sap_sales_name']);
        });
    }
};

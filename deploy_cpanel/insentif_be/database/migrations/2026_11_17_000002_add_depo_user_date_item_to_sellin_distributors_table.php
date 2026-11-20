<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sellin_distributors', function (Blueprint $table) {
            $table->unsignedBigInteger('depo_id')->nullable()->after('distributor_id')->index();
            $table->unsignedBigInteger('user_id')->nullable()->after('depo_id')->index();
            $table->integer('sap_slp_code')->nullable()->after('user_id')->index();
            $table->string('sap_slp_name', 255)->nullable()->after('sap_slp_code');
            $table->date('transaction_date')->nullable()->after('period')->index();
            $table->string('item_code', 64)->nullable()->after('brand_id')->index();
            $table->string('item_name', 255)->nullable()->after('item_code');
        });
    }

    public function down(): void
    {
        Schema::table('sellin_distributors', function (Blueprint $table) {
            $table->dropIndex(['depo_id']);
            $table->dropIndex(['user_id']);
            $table->dropIndex(['sap_slp_code']);
            $table->dropIndex(['transaction_date']);
            $table->dropIndex(['item_code']);
            $table->dropColumn([
                'depo_id',
                'user_id',
                'sap_slp_code',
                'sap_slp_name',
                'transaction_date',
                'item_code',
                'item_name',
            ]);
        });
    }
};

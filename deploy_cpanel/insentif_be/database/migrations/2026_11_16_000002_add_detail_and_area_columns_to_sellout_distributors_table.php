<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sellout_distributors', function (Blueprint $table) {
            $table->unsignedBigInteger('distributor_id')->nullable()->after('batch_id')->index();
            $table->unsignedBigInteger('area_id')->nullable()->after('depo_id')->index();
            $table->string('faktur', 100)->nullable()->after('period')->index();
            $table->date('transaction_date')->nullable()->after('faktur');
            $table->unsignedTinyInteger('bulan')->nullable()->after('transaction_date');
            $table->string('customer_code', 100)->nullable()->after('bulan')->index();
            $table->string('customer_name', 255)->nullable()->after('customer_code');
            $table->text('alamat')->nullable()->after('customer_name');
            $table->string('jenis_sales', 50)->nullable()->after('alamat');
            $table->string('item_code', 100)->nullable()->after('jenis_sales');
            $table->string('item_name', 255)->nullable()->after('item_code');
            $table->string('item_desc', 255)->nullable()->after('item_name');
            $table->decimal('nominal', 18, 2)->default(0)->after('volume_kg');
            $table->string('kota_kab', 150)->nullable()->after('active_outlet_count');
            $table->string('kecamatan', 150)->nullable()->after('kota_kab');
            $table->string('salesman_dist', 150)->nullable()->after('kecamatan');
            $table->string('pic', 150)->nullable()->after('salesman_dist');
            $table->string('tipe_outlet', 100)->nullable()->after('pic');
        });
    }

    public function down(): void
    {
        Schema::table('sellout_distributors', function (Blueprint $table) {
            $table->dropIndex(['distributor_id']);
            $table->dropIndex(['area_id']);
            $table->dropIndex(['faktur']);
            $table->dropIndex(['customer_code']);
            $table->dropColumn([
                'distributor_id',
                'area_id',
                'faktur',
                'transaction_date',
                'bulan',
                'customer_code',
                'customer_name',
                'alamat',
                'jenis_sales',
                'item_code',
                'item_name',
                'item_desc',
                'nominal',
                'kota_kab',
                'kecamatan',
                'salesman_dist',
                'pic',
                'tipe_outlet',
            ]);
        });
    }
};

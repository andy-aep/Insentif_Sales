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
        Schema::create('sellin_distributors', function (Blueprint $table) {
            $table->id();
            $table->uuid('batch_id')->nullable()->index();
            $table->foreignId('distributor_id')->constrained('distributors');
            $table->foreignId('brand_id')->constrained('brands');
            $table->string('period', 6); // YYYYMM
            $table->decimal('volume_kg', 14, 2);
            $table->decimal('nominal', 16, 2);
            $table->string('sap_doc_no')->nullable();
            $table->timestamps();
        });

        Schema::create('sellout_distributors', function (Blueprint $table) {
            $table->id();
            $table->uuid('batch_id')->nullable()->index();
            $table->foreignId('depo_id')->constrained('depos');
            $table->foreignId('brand_id')->constrained('brands');
            $table->string('period', 6); // YYYYMM
            $table->decimal('volume_kg', 14, 2);
            $table->integer('active_outlet_count')->default(0);
            $table->timestamps();
        });

        Schema::create('sellin_industris', function (Blueprint $table) {
            $table->id();
            $table->uuid('batch_id')->nullable()->index();
            $table->foreignId('user_id')->constrained('users'); // Sales Industri
            $table->string('customer_name');
            $table->string('period', 6);
            $table->decimal('tonase', 14, 2);
            $table->string('sap_so_no')->nullable();
            $table->timestamps();
        });

        Schema::create('sellout_sales_surabayas', function (Blueprint $table) {
            $table->id();
            $table->uuid('batch_id')->nullable()->index();
            $table->foreignId('coordinator_id')->nullable()->constrained('users');
            $table->foreignId('sales_id')->constrained('users'); // TO atau Canvasing
            $table->string('period', 6);
            $table->decimal('volume', 14, 2);
            $table->integer('active_outlet_count')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sellout_sales_surabayas');
        Schema::dropIfExists('sellin_industris');
        Schema::dropIfExists('sellout_distributors');
        Schema::dropIfExists('sellin_distributors');
    }
};

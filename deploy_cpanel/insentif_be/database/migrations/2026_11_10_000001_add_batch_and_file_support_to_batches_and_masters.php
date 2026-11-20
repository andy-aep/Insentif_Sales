<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('upload_batches', function (Blueprint $table) {
            if (!Schema::hasColumn('upload_batches', 'file_path')) {
                $table->string('file_path')->nullable()->after('file_name');
            }
        });

        Schema::table('master_targets', function (Blueprint $table) {
            if (!Schema::hasColumn('master_targets', 'batch_id')) {
                $table->char('batch_id', 36)->nullable()->after('id')->index();
            }
        });

        Schema::table('distributors', function (Blueprint $table) {
            if (!Schema::hasColumn('distributors', 'batch_id')) {
                $table->char('batch_id', 36)->nullable()->index();
            }
        });

        Schema::table('depos', function (Blueprint $table) {
            if (!Schema::hasColumn('depos', 'batch_id')) {
                $table->char('batch_id', 36)->nullable()->index();
            }
        });

        Schema::table('areas', function (Blueprint $table) {
            if (!Schema::hasColumn('areas', 'batch_id')) {
                $table->char('batch_id', 36)->nullable()->index();
            }
        });
    }

    public function down(): void
    {
        Schema::table('upload_batches', function (Blueprint $table) {
            if (Schema::hasColumn('upload_batches', 'file_path')) {
                $table->dropColumn('file_path');
            }
        });

        Schema::table('master_targets', function (Blueprint $table) {
            if (Schema::hasColumn('master_targets', 'batch_id')) {
                $table->dropColumn('batch_id');
            }
        });

        Schema::table('distributors', function (Blueprint $table) {
            if (Schema::hasColumn('distributors', 'batch_id')) {
                $table->dropColumn('batch_id');
            }
        });

        Schema::table('depos', function (Blueprint $table) {
            if (Schema::hasColumn('depos', 'batch_id')) {
                $table->dropColumn('batch_id');
            }
        });

        Schema::table('areas', function (Blueprint $table) {
            if (Schema::hasColumn('areas', 'batch_id')) {
                $table->dropColumn('batch_id');
            }
        });
    }
};


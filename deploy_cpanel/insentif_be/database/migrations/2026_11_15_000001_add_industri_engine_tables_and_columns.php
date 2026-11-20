<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!DB::table('positions')->where('code', 'ASC')->exists()) {
            DB::table('positions')->insert([
                'name' => 'Area Sales Coordinator',
                'code' => 'ASC',
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        Schema::table('target_headers', function (Blueprint $table) {
            if (!Schema::hasColumn('target_headers', 'min_achievement_pct')) {
                $table->decimal('min_achievement_pct', 6, 2)->default(0)->after('bobot');
            }
        });

        Schema::table('grades', function (Blueprint $table) {
            if (!Schema::hasColumn('grades', 'multiplier_rate')) {
                $table->decimal('multiplier_rate', 12, 2)->nullable()->after('target_to');
            }
        });

        if (!Schema::hasTable('industri_customers')) {
            Schema::create('industri_customers', function (Blueprint $table) {
                $table->id();
                $table->uuid('batch_id')->nullable()->index();
                $table->string('customer_code', 64)->unique();
                $table->string('customer_name');
                $table->string('city', 100)->nullable();
                $table->enum('customer_type', ['NEW', 'EXISTING'])->default('NEW');
                $table->string('first_transaction_period', 6)->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('sales_industri_assignments')) {
            Schema::create('sales_industri_assignments', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('industri_customer_id')->constrained('industri_customers')->cascadeOnDelete();
                $table->string('period', 6)->nullable()->index();
                $table->boolean('is_active')->default(true);
                $table->string('notes')->nullable();
                $table->timestamps();

                $table->index(['user_id', 'period'], 'sia_user_period_idx');
                $table->index(['industri_customer_id', 'period'], 'sia_customer_period_idx');
            });
        }

        Schema::table('sellin_industris', function (Blueprint $table) {
            $table->unsignedBigInteger('user_id')->nullable()->change();
            $table->decimal('tonase', 14, 2)->default(0)->change();

            if (!Schema::hasColumn('sellin_industris', 'industri_customer_id')) {
                $table->foreignId('industri_customer_id')
                    ->nullable()
                    ->after('user_id')
                    ->constrained('industri_customers')
                    ->nullOnDelete();
            }
            if (!Schema::hasColumn('sellin_industris', 'customer_code')) {
                $table->string('customer_code', 64)->nullable()->after('industri_customer_id')->index();
            }
            if (!Schema::hasColumn('sellin_industris', 'volume_kg')) {
                $table->decimal('volume_kg', 14, 2)->default(0)->after('tonase');
            }
            if (!Schema::hasColumn('sellin_industris', 'nominal')) {
                $table->decimal('nominal', 16, 2)->default(0)->after('volume_kg');
            }
            if (!Schema::hasColumn('sellin_industris', 'transaction_date')) {
                $table->date('transaction_date')->nullable()->after('nominal');
            }
            if (!Schema::hasColumn('sellin_industris', 'is_noo')) {
                $table->boolean('is_noo')->nullable()->after('transaction_date');
            }
        });

        Schema::table('incentive_calculations', function (Blueprint $table) {
            if (!Schema::hasColumn('incentive_calculations', 'min_achievement_pct')) {
                $table->decimal('min_achievement_pct', 6, 2)->nullable()->after('achievement_percent');
            }
            if (!Schema::hasColumn('incentive_calculations', 'is_passed')) {
                $table->boolean('is_passed')->default(true)->after('min_achievement_pct');
            }
            if (!Schema::hasColumn('incentive_calculations', 'noo_volume_kg')) {
                $table->decimal('noo_volume_kg', 14, 2)->nullable()->after('realization');
            }
            if (!Schema::hasColumn('incentive_calculations', 'audit_notes')) {
                $table->string('audit_notes')->nullable()->after('final_reward');
            }
        });
    }

    public function down(): void
    {
        Schema::table('incentive_calculations', function (Blueprint $table) {
            $cols = array_filter(
                ['min_achievement_pct', 'is_passed', 'noo_volume_kg', 'audit_notes'],
                fn ($col) => Schema::hasColumn('incentive_calculations', $col)
            );
            if ($cols) {
                $table->dropColumn(array_values($cols));
            }
        });

        Schema::table('sellin_industris', function (Blueprint $table) {
            if (Schema::hasColumn('sellin_industris', 'industri_customer_id')) {
                $table->dropConstrainedForeignId('industri_customer_id');
            }
            $cols = array_filter(
                ['customer_code', 'volume_kg', 'nominal', 'transaction_date', 'is_noo'],
                fn ($col) => Schema::hasColumn('sellin_industris', $col)
            );
            if ($cols) {
                $table->dropColumn(array_values($cols));
            }
        });

        Schema::dropIfExists('sales_industri_assignments');
        Schema::dropIfExists('industri_customers');

        Schema::table('grades', function (Blueprint $table) {
            if (Schema::hasColumn('grades', 'multiplier_rate')) {
                $table->dropColumn('multiplier_rate');
            }
        });

        Schema::table('target_headers', function (Blueprint $table) {
            if (Schema::hasColumn('target_headers', 'min_achievement_pct')) {
                $table->dropColumn('min_achievement_pct');
            }
        });

        DB::table('positions')->where('code', 'ASC')->delete();
    }
};

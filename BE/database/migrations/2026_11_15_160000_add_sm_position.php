<?php

use App\Models\Position;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        Position::firstOrCreate(
            ['code' => 'SM'],
            ['name' => 'Sales Motoris', 'is_active' => true]
        );
    }

    public function down(): void
    {
        Position::where('code', 'SM')->delete();
    }
};

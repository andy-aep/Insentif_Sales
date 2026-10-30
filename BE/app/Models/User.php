<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'username',
        'email',
        'password',
        'role_id',
        'position_id',
        'aktif_from',
        'aktif_to',
        'is_eligible_konsumsi',
        'is_eligible_industri',
        'is_eligible_surabaya',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'aktif_from' => 'date:Y-m-d',
            'aktif_to' => 'date:Y-m-d',
            'is_eligible_konsumsi' => 'boolean',
            'is_eligible_industri' => 'boolean',
            'is_eligible_surabaya' => 'boolean',
            'password' => 'hashed',
        ];
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    public function position(): BelongsTo
    {
        return $this->belongsTo(Position::class);
    }

    public function masterTargets(): HasMany
    {
        return $this->hasMany(MasterTarget::class);
    }

    public function incentiveCalculations(): HasMany
    {
        return $this->hasMany(IncentiveCalculation::class);
    }

    public function uploadBatches(): HasMany
    {
        return $this->hasMany(UploadBatch::class, 'uploaded_by');
    }

    public function distributorAssignments(): HasMany
    {
        return $this->hasMany(SalesDistributorAssignment::class, 'user_id');
    }

    public function managedSpvAssignments(): HasMany
    {
        return $this->hasMany(SalesDistributorAssignment::class, 'asm_id');
    }

    public function surabayaAssignments(): HasMany
    {
        return $this->hasMany(SalesSurabayaAssignment::class, 'sales_id');
    }
}

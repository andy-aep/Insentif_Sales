<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_login_with_valid_credentials(): void
    {
        $role = Role::create([
            'name' => 'Administrator',
            'display_name' => 'Admin',
        ]);

        User::create([
            'name' => 'Admin User',
            'username' => 'admin',
            'email' => 'admin@company.com',
            'password' => Hash::make('secret123'),
            'role_id' => $role->id,
            'aktif_from' => '2025-01-01',
        ]);

        $response = $this->postJson('/api/login', [
            'username' => 'admin',
            'password' => 'secret123',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'message',
                'token',
                'token_type',
                'user' => ['id', 'name', 'username'],
            ]);
    }

    public function test_user_cannot_login_with_invalid_credentials(): void
    {
        $role = Role::create([
            'name' => 'Administrator',
            'display_name' => 'Admin',
        ]);

        User::create([
            'name' => 'Admin User',
            'username' => 'admin',
            'password' => Hash::make('secret123'),
            'role_id' => $role->id,
            'aktif_from' => '2025-01-01',
        ]);

        $response = $this->postJson('/api/login', [
            'username' => 'admin',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['username']);
    }

    public function test_authenticated_user_can_access_me_and_logout(): void
    {
        $role = Role::create([
            'name' => 'Administrator',
            'display_name' => 'Admin',
        ]);

        $user = User::create([
            'name' => 'Admin User',
            'username' => 'admin',
            'password' => Hash::make('secret123'),
            'role_id' => $role->id,
            'aktif_from' => '2025-01-01',
        ]);

        $token = $user->createToken('test-token')->plainTextToken;

        $meResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/me');

        $meResponse->assertStatus(200)
            ->assertJsonPath('user.username', 'admin');

        $logoutResponse = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/logout');

        $logoutResponse->assertStatus(200)
            ->assertJsonPath('message', 'Logout berhasil');
    }
}

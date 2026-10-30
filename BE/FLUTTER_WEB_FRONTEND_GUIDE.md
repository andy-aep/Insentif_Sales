# PANDUAN IMPLEMENTASI FRONTEND FLUTTER WEB
## SISTEM PERHITUNGAN INSENTIF SALES

Dokumen ini merupakan panduan arsitektur teknis, struktur folder, pemodelan data Dart, *state management*, integrasi HTTP Client RESTful, serta spesifikasi antarmuka visual berbasis **Flutter Web (3.24+ / 3.27+)** yang terhubung secara penuh dengan **Backend Laravel 13** yang telah aktif di `http://127.0.0.1:8000/api`.

---

### 1. Arsitektur Teknis & Standar Sistem Frontend

* **Framework**: Flutter Web (Dart SDK 3.5+)
* **State Management**: `flutter_riverpod` (v2.6+) - Reaktif, *compile-time safe*, dan mudah diuji
* **Routing**: `go_router` (v14+) - Mendukung Web URL Deep-linking, Browser History (Back/Forward), dan *Authentication Route Guard*
* **HTTP Client**: `dio` (v5+) - Dilengkapi Interceptor otomatis untuk injeksi Laravel Sanctum Bearer Token, penanganan error terpusat (401 Unauthorized, 422 Validation Error), dan upload file Multipart
* **Penyimpanan Sesi Lokal**: `shared_preferences` - Menyimpan Auth Token dan Cache Profil Pengguna
* **Design System & Aestetika Visual**:
  * Clean Modern Dashboard & Glassmorphism Card
  * Palet Warna: Modern Corporate Indigo & Slate (`#1E293B`, `#4F46E5`, `#10B981`, `#F59E0B`, `#EF4444`)
  * Tipografi: Google Fonts (*Inter* & *Outfit*)
  * Data Visualization: `fl_chart` untuk grafik tren pencapaian sales
  * Data Table: Responsif dengan pagination, search bar, sortable column, dan status badges
  * File Handler: `file_picker` (Upload file massal drag-and-drop) & Web Stream Blob Download (Export laporan Excel)

---

### 2. Dependensi Proyek (`pubspec.yaml`)

```yaml
name: sales_incentive_web
description: "Frontend Flutter Web - Sistem Perhitungan Insentif Sales"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter

  # State Management & Dependency Injection
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Routing & Navigation
  go_router: ^14.8.0

  # Networking & HTTP
  dio: ^5.7.0
  http_parser: ^4.1.2

  # Local Persistence
  shared_preferences: ^2.3.5

  # Design, Icons, & Typography
  google_fonts: ^6.2.1
  lucide_icons: ^0.257.0
  intl: ^0.20.2
  fl_chart: ^0.70.2

  # File Picker & Web Download
  file_picker: ^8.1.7
  universal_html: ^2.2.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  riverpod_generator: ^2.6.3
  json_serializable: ^6.9.3
  json_annotation: ^4.9.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

---

### 3. Struktur Direktori Proyek (Clean Architecture)

```text
lib/
├── app.dart                          # Root MaterialApp & GoRouter config
├── main.dart                         # Entry point
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart        # URL Backend (/login, /incentives/calculate, dll)
│   │   └── app_colors.dart           # Palet warna modern
│   ├── network/
│   │   ├── api_exception.dart        # Model exception HTTP
│   │   ├── auth_interceptor.dart     # Auto-inject Bearer Token
│   │   └── dio_client.dart           # Singleton Dio instance
│   ├── theme/
│   │   └── app_theme.dart            # ThemeData (Dark & Light Glassmorphism)
│   └── utils/
│       ├── currency_formatter.dart   # Format Rupiah (Rp 1.000.000)
│       └── web_downloader.dart       # Trigger download blob file Excel di browser
├── data/
│   └── models/
│       ├── auth_user_model.dart      # User, Role, Position, Menu Permission
│       ├── master_model.dart         # Brand, Distributor, Depo, Area
│       ├── target_header_model.dart  # TargetHeader, Grade, GradeBobot (3 Level)
│       ├── master_target_model.dart  # Target Kuota Sales
│       ├── calculation_model.dart    # Hasil Kalkulasi Insentif & Summary Meta
│       └── upload_batch_model.dart   # Riwayat Upload Batch & Status Rollback
└── features/
    ├── auth/
    │   ├── providers/auth_provider.dart
    │   └── presentation/login_screen.dart
    ├── dashboard/
    │   ├── presentation/dashboard_layout.dart # Shell dengan Dynamic Sidebar & Topbar
    │   └── presentation/dashboard_home_screen.dart
    ├── master_data/
    │   └── presentation/organization_screen.dart # Master Distributor, Depo, Area, Brand
    ├── incentive_settings/
    │   └── presentation/incentive_scheme_screen.dart # Editor 3-Level Insentif
    ├── bulk_upload/
    │   └── presentation/bulk_upload_screen.dart      # Drag-and-drop & Rollback Table
    └── incentive_calculation/
        └── presentation/incentive_calculation_screen.dart # Filter, Trigger & Export Excel
```

---

### 4. Konfigurasi Jaringan & HTTP Client (`core/network/`)

#### A. Konfigurasi Endpoint (`core/constants/api_endpoints.dart`)
```dart
class ApiEndpoints {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';

  // Master Data
  static const String users = '/users';
  static const String roles = '/roles';
  static const String positions = '/positions';
  static const String menus = '/menus';
  static const String brands = '/brands';
  static const String distributors = '/distributors';
  static const String depos = '/depos';
  static const String areas = '/areas';

  // Setting Insentif
  static const String targetHeaders = '/target-headers';
  static const String grades = '/grades';
  static const String gradeBobots = '/grade-bobots';
  static const String percentTargets = '/percent-targets';
  static const String nilaiRewards = '/nilai-rewards';
  static const String masterTargets = '/master-targets';

  // Kalkulasi & Laporan
  static const String calculateIncentive = '/incentives/calculate';
  static const String incentiveResults = '/incentives/results';
  static const String exportExcel = '/incentives/export-excel';

  // Bulk Upload & Batch Rollback
  static String bulkUpload(String entity) => '/bulk-upload/$entity';
  static String rollbackBatch(String batchId) => '/bulk-upload/rollback/$batchId';
  static const String batchHistory = '/bulk-upload/history';
}
```

#### B. Dio Client & Auth Interceptor (`core/network/dio_client.dart`)
```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

class DioClient {
  static late Dio _dio;

  static Dio get instance => _dio;

  static void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            // Sesi token kedaluwarsa -> arahkan ke login
          }
          return handler.next(error);
        },
      ),
    );
  }
}
```

---

### 5. Pemodelan Data Dart (Data Models)

#### A. Model User, Role, & Permission (`data/models/auth_user_model.dart`)
```dart
class UserModel {
  final int id;
  final String name;
  final String username;
  final String? email;
  final int roleId;
  final int? positionId;
  final String aktifFrom;
  final String? aktifTo;
  final bool isEligibleKonsumsi;
  final bool isEligibleIndustri;
  final bool isEligibleSurabaya;
  final RoleModel? role;
  final PositionModel? position;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    required this.roleId,
    this.positionId,
    required this.aktifFrom,
    this.aktifTo,
    required this.isEligibleKonsumsi,
    required this.isEligibleIndustri,
    required this.isEligibleSurabaya,
    this.role,
    this.position,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      email: json['email'],
      roleId: json['role_id'],
      positionId: json['position_id'],
      aktifFrom: json['aktif_from'] ?? '',
      aktifTo: json['aktif_to'],
      isEligibleKonsumsi: json['is_eligible_konsumsi'] == true || json['is_eligible_konsumsi'] == 1,
      isEligibleIndustri: json['is_eligible_industri'] == true || json['is_eligible_industri'] == 1,
      isEligibleSurabaya: json['is_eligible_surabaya'] == true || json['is_eligible_surabaya'] == 1,
      role: json['role'] != null ? RoleModel.fromJson(json['role']) : null,
      position: json['position'] != null ? PositionModel.fromJson(json['position']) : null,
    );
  }
}

class RoleModel {
  final int id;
  final String name;
  final String displayName;
  final List<RoleMenuPermissionModel> menuPermissions;

  RoleModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.menuPermissions = const [],
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    var permList = json['menu_permissions'] as List? ?? [];
    return RoleModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      menuPermissions: permList.map((p) => RoleMenuPermissionModel.fromJson(p)).toList(),
    );
  }
}

class RoleMenuPermissionModel {
  final int menuId;
  final bool canView;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;
  final MenuModel? menu;

  RoleMenuPermissionModel({
    required this.menuId,
    required this.canView,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
    this.menu,
  });

  factory RoleMenuPermissionModel.fromJson(Map<String, dynamic> json) {
    return RoleMenuPermissionModel(
      menuId: json['menu_id'],
      canView: json['can_view'] == true || json['can_view'] == 1,
      canCreate: json['can_create'] == true || json['can_create'] == 1,
      canUpdate: json['can_update'] == true || json['can_update'] == 1,
      canDelete: json['can_delete'] == true || json['can_delete'] == 1,
      menu: json['menu'] != null ? MenuModel.fromJson(json['menu']) : null,
    );
  }
}

class MenuModel {
  final int id;
  final String name;
  final String? route;
  final String? icon;
  final int order;

  MenuModel({
    required this.id,
    required this.name,
    this.route,
    this.icon,
    required this.order,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'],
      name: json['name'],
      route: json['route'],
      icon: json['icon'],
      order: json['order'] ?? 0,
    );
  }
}

class PositionModel {
  final int id;
  final String name;
  final String code;

  PositionModel({required this.id, required this.name, required this.code});

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    return PositionModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
    );
  }
}
```

#### B. Model Hasil Kalkulasi Insentif (`data/models/calculation_model.dart`)
```dart
class IncentiveCalculationModel {
  final int id;
  final int userId;
  final String kategoriSkema;
  final String period;
  final double targetQuota;
  final double realization;
  final double achievementPercent;
  final double cappedRealization;
  final bool isRateBased;
  final double unitRate;
  final double lumpSumNominal;
  final double headerBobotPercent;
  final double finalReward;
  final UserModel? user;

  IncentiveCalculationModel({
    required this.id,
    required this.userId,
    required this.kategoriSkema,
    required this.period,
    required this.targetQuota,
    required this.realization,
    required this.achievementPercent,
    required this.cappedRealization,
    required this.isRateBased,
    required this.unitRate,
    required this.lumpSumNominal,
    required this.headerBobotPercent,
    required this.finalReward,
    this.user,
  });

  factory IncentiveCalculationModel.fromJson(Map<String, dynamic> json) {
    return IncentiveCalculationModel(
      id: json['id'],
      userId: json['user_id'],
      kategoriSkema: json['kategori_skema'] ?? '',
      period: json['period'] ?? '',
      targetQuota: double.tryParse(json['target_quota'].toString()) ?? 0.0,
      realization: double.tryParse(json['realization'].toString()) ?? 0.0,
      achievementPercent: double.tryParse(json['achievement_percent'].toString()) ?? 0.0,
      cappedRealization: double.tryParse(json['capped_realization'].toString()) ?? 0.0,
      isRateBased: json['is_rate_based'] == true || json['is_rate_based'] == 1,
      unitRate: double.tryParse(json['unit_rate'].toString()) ?? 0.0,
      lumpSumNominal: double.tryParse(json['lump_sum_nominal'].toString()) ?? 0.0,
      headerBobotPercent: double.tryParse(json['header_bobot_percent'].toString()) ?? 0.0,
      finalReward: double.tryParse(json['final_reward'].toString()) ?? 0.0,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}
```

---

### 6. Desain Modul & Antarmuka Visual Utama

#### Modul 1: Dynamic Responsive Sidebar (`DashboardLayout`)
* **Menu Dinamis**: Membaca izin menu (`RoleMenuPermission`) dari `user.role.menuPermissions`. Item menu hanya muncul jika `can_view == true`.
* **Navigasi GoRouter**:
  * `/dashboard` -> Ringkasan performa & KPI
  * `/settings/incentives` -> Editor Skema Insentif 3-Level
  * `/bulk-upload` -> Upload Batch Massal & Rollback Transaksi
  * `/incentives/calculate` -> Eksekusi Kalkulasi & Laporan Insentif
  * `/master/organization` -> Master Distributor, Depo, Area, & Brand

#### Modul 2: Bulk Upload & Rollback Center (`BulkUploadScreen`)
1. **Dropdown Pemilih Entitas**:
   * *Transaksi*: Sell-In Distributor, Sell-Out Distributor, Sell-In Industri, Sell-Out Surabaya
   * *Master Data*: Distributor, Depo, Area
2. **Dropzone File Picker**:
   * Mendukung drag-and-drop file `.xlsx`, `.xls`, `.csv`.
   * Menampilkan nama file, ukuran file, dan tombol "Upload & Proses".
3. **Riwayat Batch & Tombol Rollback**:
   * Menampilkan tabel riwayat dari `GET /api/bulk-upload/history`:
     * ID Batch (UUID ringkas)
     * Entitas
     * Baris Total / Sukses / Gagal
     * Status Badge (`COMPLETED` = Hijau, `ROLLED_BACK` = Merah, `PROCESSING` = Kuning)
     * Tombol Aksi: **Rollback** (Menampilkan modal konfirmasi sebelum memanggil `POST /api/bulk-upload/rollback/{id}`).

#### Modul 3: Engine Kalkulasi Insentif (`IncentiveCalculationScreen`)
1. **Filter Box Header**:
   * Dropdown Kategori Skema: `KONSUMSI`, `INDUSTRI`, `SURABAYA`
   * Field Periode (Input `YYYYMM`, misal: `202610` atau `202603`)
   * Tombol Aksi:
     * **"Hitung Insentif"**: Memanggil `POST /api/incentives/calculate`.
     * **"Export ke Excel"**: Men-download file spreadsheet secara langsung di browser via `GET /api/incentives/export-excel?kategori_skema=...&period=...`.
2. **Banner Ringkasan KPI**:
   * Total Personil yang Berhak
   * Total Kuota Target
   * Total Realisasi
   * **Total Akumulasi Reward (Rp)**
3. **Interactive Data Table**:
   * Kolom: Personil Sales, Jabatan, Target Kuota, Realisasi Aktual, % Pencapaian (Badge Merah/Kuning/Hijau/Biru sesuai standar), Model (Rate-based / Lump Sum), dan Nominal Final Reward (Format Rp).

---

### 7. Helper Web File Downloader (`core/utils/web_downloader.dart`)

Khusus untuk Flutter Web agar file Excel dari API dapat langsung di-download ke folder Download pengguna:

```dart
import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;
import '../network/dio_client.dart';

class WebDownloader {
  static Future<void> downloadExcel(String urlPath, String filename) async {
    final response = await DioClient.instance.get(
      urlPath,
      options: Options(responseType: ResponseType.bytes),
    );

    final blob = html.Blob(
      [response.data],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
```

---

### 8. Langkah Eksekusi & Menjalankan Proyek

```bash
# 1. Buat Proyek Baru Flutter Web di Folder Frontend (misal: FE)
cd c:\xampp\htdocs\Laravel
flutter create --platforms web FE
cd FE

# 2. Tambahkan Dependensi ke pubspec.yaml
flutter pub add flutter_riverpod go_router dio shared_preferences google_fonts lucide_icons intl fl_chart file_picker universal_html

# 3. Jalankan Aplikasi Flutter Web pada Port Khusus
flutter run -d chrome --web-port=3000
```

> **Catatan CORS**: Backend Laravel telah mengaktifkan konfigurasi `config/cors.php` dengan `allowed_origins => ['*']`, sehingga Flutter Web yang berjalan di `http://localhost:3000` dapat langsung terhubung ke Backend `http://127.0.0.1:8000/api` tanpa kendala CORS policy.

# Pedoman Pengembangan Sistem Insentif Penjualan

Dokumen ini mencatat keputusan arsitektur, konvensi data, dan pedoman implementasi untuk modul **Master Target Kuota**, **Bulk Upload & Rollback**, serta **Manajemen Pengguna (PIC)**.

---

## 1. Arsitektur Struktur Target Distributor

Sistem menggunakan model hierarki organisasi penjualan:
```
Distributor (DSTxxxx)
  └── Depo Cabang (C11xxxxxxx) [Level: DEPO / ASM]
        └── Area Penjualan (ARxxxxx) [Level: AREA / SPV]
```

### Aturan Data Target Depo (ASM)
- **Level**: `DEPO`
- **Kode Area**: Kosong (`NULL` / string kosong).
- **Metrik Utama**: `SELL_IN` (kuota dalam satuan Kg).
- **Target Outlet**: **Tidak ada** (`NULL` / ditiadakan). Tabel tampilan UI tidak menampilkan kolom `Target Outlet`.
- **PIC**: Area Sales Manager (ASM) yang bersangkutan (`position_id = 1`).

### Aturan Data Target Area (SPV)
- **Level**: `AREA`
- **Kode Area**: Wajib terisi sesuai Master Area (`AR00001` - `AR00174`).
- **Format Baris Tunggal (Opsi B)**: Cukup **1 baris per Brand** dengan metrik `SELL_OUT`.
- **Target Kuota**: Berisi target volume penjualan (`Kg`).
- **Target Outlet**: Berisi target sebaran toko Active Outlet (`Toko`).
- **Tidak ada baris `AO` terpisah**: Target toko melekat langsung pada baris `SELL_OUT` di kolom `target_outlet`. Perhitungan insentif otomatis membaca `target_outlet` dari baris `SELL_OUT` jika skema mengevaluasi bobot AO.
- **PIC**: Sales Supervisor (SPV) yang bersangkutan (`position_id = 2`).

---

## 2. Standar Bulk Upload Target (`master_target_distributor`)

Proses upload target distributor disatukan ke dalam **satu template dan satu jenis entitas**: `Master: Target Distributor (Depo & Area)`.

### Format Sheet 1 (`Data Upload`)
| Kolom | Tipe | Wajib? | Keterangan |
| :--- | :--- | :--- | :--- |
| `period` | String (YYYYMM / YYYY) | Ya | Contoh: `202610` atau `2026` (otomatis 12 bulan) |
| `distributor_code` | String | Ya | Kode Distributor, misal `DST0001` |
| `depo_code` | String | Ya | Kode Depo, misal `C110003336` |
| `area_code` | String | Opsional | **Kosongkan** untuk Target Depo, **Isi** untuk Target Area |
| `brand_code` | String | Ya | Kode Brand produk (`GARAMI`, `JEMPOL`, `KAPAL`, `LAYAR`, `TANGAN`) |
| `metrik_target` | Enum | Ya | `SELL_IN` (Depo), `SELL_OUT` (Area), `AO` (Area) |
| `target_quota` | Numeric | Ya | Kuota target dalam Kg (untuk SELL_IN/SELL_OUT) atau jumlah toko (untuk AO) |
| `target_outlet` | Numeric | Opsional | Khusus Area / AO. Kosongkan untuk Depo |
| `username` | String | Opsional | Username PIC (ASM jika Depo, SPV jika Area) |

### Format Sheet 2 (`Panduan & Kode Referensi`)
Otomatis dihasilkan melalui `BulkUploadTemplateExport` / `BulkUploadGuideSheet` yang memuat kamus kode aktif dari database:
- Daftar Brand Produk
- Daftar Wilayah / Region
- Daftar Distributor
- Daftar Depo Cabang
- Daftar Area Penjualan
- Daftar Username & Jabatan Sales

### Auto-Create User PIC pada Import
Logika di `BatchImportService.php`:
- Jika kolom `username` diisi dengan username yang belum terdaftar di tabel `users` (dan bukan `vacant`), sistem otomatis membuat akun baru:
  - Role: `Sales` (`role_id = 3`)
  - Posisi: `ASM` (`position_id = 1`) jika level `DEPO`, atau `SPV` (`position_id = 2`) jika level `AREA`
  - Status aktif: `is_eligible_konsumsi = 1`, `aktif_from = 2024-01-01`
- Ini memastikan relasi `user_id` tidak bernilai `NULL` dan kolom PIC tidak tampil kosong (`-`).

---

## 3. Konvensi Tampilan Frontend (Flutter)

### Layar Master Target Kuota (`master_target_screen.dart`)
Terdapat 3 tab utama:
1. **Target Distributor**: Menampilkan hirarki terpadu `Distributor -> Depo -> Area` menggunakan widget `TargetDistributorHierarchyView`.
2. **Target Industri**: Kuota skema Industri (Sales Industri, metric SELL_IN / NOO).
3. **Target Sales Surabaya**: Kuota skema Sales Surabaya (Canvasing / Taking Order).

### Layar Hirarki Distributor (`target_distributor_hierarchy_view.dart`)
- **Tabel Depo**: Menghilangkan kolom `Target Outlet` karena Depo hanya mengevaluasi Sell-In/Sell-Out tonase.
- **Tabel Area**: Menyertakan kolom `Target Outlet` untuk evaluasi Active Outlet.
- **Pencegahan RenderFlex Overflow**:
  - Semua dropdown filter form di dalam toolbar wajib menggunakan `isExpanded: true`.
  - Label text pada item dropdown wajib menggunakan `overflow: TextOverflow.ellipsis`.
  - Gunakan `prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36)` pada `InputDecoration` untuk mencegah icon default (48px) mendesak lebar form.

---

## 4. Integrasi Dashboard Real-Data (Eksekutif vs Sales Lapangan)

Dashboard dirancang adaptif berdasarkan peran pengguna via endpoint `GET /api/dashboard/summary?period=YYYYMM,YYYYMM` (mendukung Multi-Periode dipisah koma):

### A. Tampilan Eksekutif (`mode = ADMIN`)
- **Hak Akses**: `Administrator`, `Admin Sales`, role mengandung `Direksi`/`Director`/`Manager`/`Management`, posisi `NSM` (Nasional), dan posisi `LSM` (otomatis terfilter sesuai Region penugasan).
- **Sticky Multi-Periode Header**: Header, pemilih Multi-Periode, dan tombol refresh menempel di bagian atas agar mudah dijangkau saat halaman di-scroll.
- **KPI Utama & Executive Health Strip**:
  - 4 KPI Utama: Target & Realisasi Sell-In (`Kg`), Sell-Out (`Kg`), Active Outlet (`Toko`), dan Estimasi Budget Insentif (`Rp`).
  - Executive Health Strip: `Sell-Through Ratio (Sell-Out ÷ Sell-In %)`, `Total Omzet DPP`, dan `Rasio Budget Insentif / Omzet (%)`.
- **Sales Leaderboard & Top Distributor Sell-In**:
  - Leaderboard Top 15 personil sales (ASM/SPV) dengan rincian Sell-In, Sell-Out, dan AO (`Toko`).
  - Top Distributor menampilkan `Real / Target Kg` Sell-In, progress bar, badge `%` berwarna, serta toggle **`Top Pencapaian`** vs **`Perlu Perhatian (<80%)`**.
- **Analitik Region, Brand & Tren 6 Periode**:
  - **Performa per Region**: Sell-In, Sell-Out, AO (`Toko`), dan `Sell-Through %` per wilayah.
  - **Performa & Kontribusi Brand**: Pencapaian Sell-In/Sell-Out + `% Share` kontribusi per brand.
  - **Grafik Tren 6 Periode**: Komparasi `Target vs Realisasi` per bulan dengan toggle **`Sell-In`** / **`Sell-Out`**.

### B. Tampilan Sales Lapangan (`mode = SALES`)
- Khusus personil lapangan (`ASM`, `SPV`, `ASC`, `TO`, `CANVAS`, `SM`) sesuai skema (`KONSUMSI`, `INDUSTRI`, `SURABAYA`):
  - **ASM**: Target & Realisasi Sell-In Depo (`Kg`), capaian `%`, dan jumlah Depo kerja.
  - **SPV**: Target & Realisasi Sell-Out Area (`Kg`), Target & Aktual Active Outlet (`Toko`), dan jumlah Area kerja.
  - **Estimasi Insentif**: Grade pencapaian, nominal reward, dan rincian wilayah penugasan per brand (expandable).

---

## 5. Fitur Tarik Data Eksisting ke Template Excel, Input Manual & Penugasan Sales

### A. Penambahan & Edit Data Manual (1 Layar)
- **Master Distributor**: Tombol `+ Tambah Distributor`, `+ Tambah Depo`, dan `+ Tambah Area` pada layar `Master Distributor`.
- **Master Target Kuota**:
  - Form 1 layar untuk tambah & edit `Depo (Sell-In)` + `Area (Sell-Out & AO)` sekaligus.
  - Mendukung filter **Multi-Periode** dan kolom `Periode` pada tabel hirarki.
- **Tim & Area Sales (`Master Sales`)**:
  - 3 mode tampilan: **`Per Distributor`** (`DistributorAssignmentHierarchyView`), **`Per Sales`**, dan **`Tabel Datar`**.
  - Modal **`Atur PIC`** 1 layar menggunakan endpoint `POST /api/sales-distributor-assignments/bulk-map`.

### B. Tarik Data Eksisting ke Template Excel (`with_data = true`)
- Tersedia di `Master Target Kuota` (mendukung multi-periode), `Master Distributor`, dan `Bulk Upload & Rollback`.
- **API Endpoint**: `GET /api/bulk-upload/template/{entity}?with_data=true&period=YYYYMM,YYYYMM`.

---

## 6. Perhitungan Insentif Distributor & Standar Satuan
- **Live Auto-Calc**: Layar `Insentif Distributor` langsung mengalkulasi otomatis saat halaman dibuka atau periode diubah (tombol `Kunci Hitungan` dan ikon refresh ganda di header sudah ditiadakan).
- **Satuan Active Outlet (AO)**: Seluruh UI, KPI, tabel, dan export Excel WAJIB memakai satuan **`Toko`** / **`Outlet`**, **bukan `Kg`**.
- **Optimasi Memori & Export Excel**:
  - Agregasi realisasi multi-periode pada `SelloutDistributor` menggunakan SQL `GROUP BY` agar tidak melebihi batas memori PHP (`128 MB`).
  - `DistributorBreakdownExport` mengimplementasikan `WithMultipleSheets` dan `Export` agar `Save to Excel` berjalan tanpa error.

---

## 7. Standar RBAC & 11 Menu Sidebar
Tabel `menus` disinkronkan 1-to-1 dengan 11 menu sidebar (`dashboard_layout.dart`) melalui migrasi `2026_11_20_000001_sync_sidebar_menus_for_rbac.php` dan `DatabaseSeeder.php`:
1. `Dashboard` (`/dashboard`)
2. `Master Distributor` (`/master/distributor`)
3. `Master Target Kuota` (`/master/target`)
4. `Realisasi Penjualan` (`/master/realisasi`)
5. `Tim & Area Sales` (`/master/surabaya`)
6. `Insentif Distributor` (`/incentives/distributor`)
7. `Insentif Industri` (`/incentives/industri`)
8. `Insentif Surabaya` (`/incentives/surabaya`)
9. `Skema & Bobot` (`/settings/incentives`)
10. `Bulk Upload Data` (`/bulk-upload`)
11. `Pengguna & Akses` (`/users`)

Filter visibilitas sidebar di `dashboard_layout.dart` (`_isItemAllowed`) memprioritaskan exact route match terlebih dahulu sebelum fallback route grup lama.

---

## 8. Design System Frontend (Material 3 Light & Dark Mode)
- **Tema Terpusat**: `FE/lib/core/theme/app_theme.dart` (`useMaterial3: true`, font tunggal `PlusJakartaSans`, `AppSemanticColors` via `ThemeExtension`).
- **Palet Light Mode**: Scaffold `#F8FAFC`, Surface/Card/Sidebar `#FFFFFF`, Border `#E2E8F0`, Teks `#0F172A` / `#64748B`, Aksen Indigo `#4F46E5`.
- **Palet Dark Mode**: Scaffold `#0F172A`, Surface/Card/Sidebar `#1E293B`, Border `#334155`, Teks `#F8FAFC` / `#94A3B8`, Aksen Indigo `#6366F1`.
- **Aturan Wajib Styling**:
  - **Nol hardcode warna** di widget/screen (`Color(0x...)`, `Colors.white/black/grey`, atau `AppColors.*` statis dilarang di presentation layer). Wajib gunakan `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, `context.semantic`, atau `context.colors`.
  - Gunakan token `*Solid` (`successSolid`, `dangerSolid`, `warningSolid`, `infoSolid`) untuk background tombol terisi & SnackBar agar kontras teks putih memenuhi standar AA di Light maupun Dark Mode.
  - **Radius & Elevation**: `12px` untuk Card/Dialog/Panel utama, `8px` untuk Button/Input/Badge/Chip; `elevation: 0` dengan border tipis `1px` + shadow halus hanya di Light Mode.
  - Gunakan `initialValue:` (bukan `value:`) pada `DropdownButtonFormField` di Flutter 3.33+.

---

## 9. Alur Build & Auto-Deploy Produksi (cPanel)
- **Production URLs**:
  - Backend: `https://api-prod.garamonline.com` (`/home/susantimegah/public_html/api-prod.garamonline.com`, PHP 8.5, PostgreSQL `susantimegah_sales_insentif`)
  - Frontend: `https://insentif-dev.susantimegah.com` (`/home/susantimegah/public_html/insentif-dev.susantimegah.com`, di belakang Cloudflare CDN)
- **SSH/SFTP**: `susantimegah@163.61.58.29:22` menggunakan SSH key `C:\Users\Susan\.ssh\cpanel_insentif_rsa` (`.ppk` untuk WinSCP).
- **Perintah Build & Deploy**:
  1. Build FE: `flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=https://api-prod.garamonline.com/api`
  2. Deploy otomatis: `powershell -ExecutionPolicy Bypass -File "deploy_cpanel/deploy_ke_cpanel.ps1"`
     - Menyinkronkan BE & FE, memberi stempel cache-busting `?v=yyyyMMddHHmmss` pada `flutter_bootstrap.js` & `main.dart.js` (didukung `FE/web/.htaccess` `Cache-Control: no-cache` untuk bypass cache Cloudflare), mengunggah delta via WinSCP, dan menjalankan `php artisan optimize:clear` via SSH.

---

## 10. Lokasi File Kunci
- Backend Controllers: `BE/app/Http/Controllers/DashboardController.php`, `MasterTargetController.php`, `IncentiveCalculationController.php`, `SalesAssignmentController.php`, `RoleController.php`, `MenuController.php`
- Services & Exports: `BE/app/Services/BatchImportService.php`, `IncentiveCalculationService.php`, `BE/app/Exports/BulkUploadTemplateExport.php`, `DistributorBreakdownExport.php`
- Theme & Shell FE: `FE/lib/core/theme/app_theme.dart`, `FE/lib/core/constants/app_colors.dart`, `FE/lib/features/dashboard/presentation/dashboard_layout.dart`
- Layar Utama FE: `dashboard_home_screen.dart`, `master_target_screen.dart`, `target_distributor_hierarchy_view.dart`, `master_surabaya_screen.dart`, `distributor_assignment_hierarchy_view.dart`, `incentive_calculation_screen.dart`, `user_management_screen.dart`, `bulk_upload_screen.dart`
- Deploy Script: `deploy_cpanel/deploy_ke_cpanel.ps1` & `deploy_cpanel/deploy_ke_cpanel.bat`
- File Template Master: `templates/template_master_target_distributor.xlsx`


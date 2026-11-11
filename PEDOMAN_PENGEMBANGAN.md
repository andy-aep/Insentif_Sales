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

## 4. Integrasi Dashboard Real-Data (Admin vs Sales)

Dashboard dirancang adaptif berdasarkan peran pengguna via endpoint `GET /api/dashboard/summary?period=YYYYMM`:

### A. Tampilan Administrator (`mode = ADMIN`)
- **KPI Global**: Total Kuota Sell-In Depo (Kg), Total Kuota Sell-Out Area (Kg), Total Target Toko Ritel (AO), Total Estimasi Budget Insentif, Total Distributor (50), dan Total Sales (21).
- **Sales Leaderboard**: Top 10 personil sales (ASM/SPV) dengan target kuota terbesar, jumlah depo/area penugasan, dan capaian reward.
- **Top Distributor Breakdown**: Rangkuman 8 distributor terbesar beserta jumlah depo dan alokasi target.
- **Grafik Tren Bulanan**: Komparasi alokasi kuota Sell-In vs Sell-Out lintas periode aktif.

### B. Tampilan Sales Personil (`mode = SALES`)
- **KPI Personal**:
  - **ASM**: Target Sell-In Depo (Kg), Realisasi Sell-In, Capaian (%), dan jumlah Depo kerja.
  - **SPV**: Target Sell-Out Area (Kg), Target Active Outlet (Toko), Realisasi, Capaian (%), dan jumlah Area kerja.
  - **Estimasi Insentif**: Grade pencapaian dan nominal reward yang berhak diterima pada periode terpilih.
- **Rincian Wilayah Penugasan**: Daftar Depo/Area yang ditugaskan kepada sales tersebut, lengkap dengan rincian target per brand produk (expandable).
- **Selector Periode**: Dropdown pemilih periode aktif (misal `202612`, `202611`, `202610`) untuk melihat riwayat atau target masa depan.

---

## 5. Fitur Tarik Data Eksisting ke Template Excel & Input Manual

### A. Penambahan Data Manual (Tanpa Upload)
- **Master Distributor**: Tombol `+ Tambah Distributor`, `+ Tambah Depo`, dan `+ Tambah Area` pada masing-masing tab layar `Master Distributor`.
- **Master Target**: Tombol `+ Tambah Target Distributor` pada layar `Master Target Kuota` untuk membuat kuota per Depo/Area per Brand secara langsung melalui dialog form.

### B. Tarik Data Eksisting ke Template Excel (`with_data = true`)
- Tombol **`Tarik Excel Template`** tersedia di:
  1. Header layar `Master Target Kuota` (mengekspor data target periode aktif).
  2. Header layar `Master Distributor` (mengekspor struktur Region, Distributor, Depo, dan Area).
  3. Layar `Bulk Upload & Rollback` (opsi *Tarik Template + Data Eksisting*).
- **Format Output**:
  - Kolom sheet 1 (`Data Upload`) mengikuti urutan dan nama kolom template upload standar sehingga **dapat diedit dan diunggah ulang langsung tanpa mengubah struktur**.
  - Sheet 2 (`Panduan & Kode Referensi`) memuat referensi kode aktif (Brand, Distributor, Depo, Area, Sales).
- **API Endpoint**: `GET /api/bulk-upload/template/{entity}?with_data=true&period=YYYYMM`.

---

## 6. Lokasi File Kunci
- Backend Controller: `BE/app/Http/Controllers/MasterTargetController.php`
- Dashboard Controller: `BE/app/Http/Controllers/DashboardController.php`
- Import Service: `BE/app/Services/BatchImportService.php`
- Export Template: `BE/app/Exports/BulkUploadTemplateExport.php`
- Master Target View: `FE/lib/features/master_data/presentation/widgets/target_distributor_hierarchy_view.dart`
- Dashboard Screen: `FE/lib/features/dashboard/presentation/dashboard_home_screen.dart`
- Dashboard Provider: `FE/lib/features/dashboard/providers/dashboard_provider.dart`
- Bulk Upload Screen: `FE/lib/features/bulk_upload/presentation/bulk_upload_screen.dart`
- File Template Master: `templates/template_master_target_distributor.xlsx`


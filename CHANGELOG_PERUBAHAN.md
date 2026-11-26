# Changelog & Catatan Perubahan — Sales Insentif (PT Susanti Megah)

Dokumen ini mencatat seluruh perubahan fitur, perbaikan bug, migrasi database, serta tindakan pemulihan data produksi agar mudah ditelusuri saat perbaikan atau audit di kemudian hari.

---

## 2026-11-24

### 1. Fitur Brand Gabungan (Mix Brand / Multi-Brand & All Brand)
Memungkinkan admin membuat brand gabungan (2 brand seperti `KAPAL+JEMPOL`, 3+ brand seperti `KAPAL+JEMPOL+GARAMI`, atau `ALL_BRAND`) langsung dari **Master Distributor, Depo & Area ➔ Tab Brand** tanpa mengubah data realisasi SAP/Sell-Out.

- **Migrasi Database**:
  - [`BE/database/migrations/2026_11_24_000001_add_composite_fields_to_brands_table.php`](BE/database/migrations/2026_11_24_000001_add_composite_fields_to_brands_table.php)
  - Menambahkan kolom `is_all_brands` (`boolean`, default `false`) dan `component_brand_ids` (`json`, nullable) pada tabel `brands`.
- **Backend**:
  - [`BE/app/Models/Brand.php`](BE/app/Models/Brand.php): Menambahkan `is_all_brands` & `component_brand_ids` ke `$fillable` dan `$casts`, serta helper `Brand::buildEffectiveBrandIdsMap()` untuk memetakan brand gabungan ke seluruh ID brand anggotanya (termasuk fallback parsing kode bertanda `+` dan token `ALL` / `ALL_BRAND` / `MIX`).
  - [`BE/app/Http/Controllers/BrandController.php`](BE/app/Http/Controllers/BrandController.php):
    - `index()` diurutkan `orderBy('id')`.
    - `store()` & `update()` mendukung `is_all_brands` dan `component_brand_ids` (+ helper `resolveComponentBrandIds()`). Brand gabungan tidak menyimpan `BrandItem` SAP langsung agar tidak bentrok dengan brand tunggal.
  - [`BE/app/Http/Controllers/IncentiveCalculationController.php`](BE/app/Http/Controllers/IncentiveCalculationController.php):
    - `buildDistributorBreakdownPayload()` kini menjumlahkan realisasi **Sell-In Depo**, **Sell-Out Area**, dan **Active Outlet (AO)** lintas semua brand anggota ketika target Depo/Area memakai Brand Gabungan atau All Brand.
  - [`BE/app/Http/Controllers/DashboardController.php`](BE/app/Http/Controllers/DashboardController.php):
    - Bagian `$brandPerformance` menjumlahkan realisasi brand komponen untuk brand gabungan yang memiliki target.
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php):
    - `processMasterTargetDistributorBulk()` menormalisasi kode brand gabungan (`KAPAL + JEMPOL` $\rightarrow$ `KAPAL+JEMPOL`) dan otomatis mendaftarkan brand gabungan baru bila seluruh komponen bertanda `+` valid.
- **Frontend**:
  - [`FE/lib/data/models/master_model.dart`](FE/lib/data/models/master_model.dart): `BrandModel` ditambah field `isAllBrands`, `componentBrandIds`, dan getter `isComposite`.
  - [`FE/lib/features/master_data/providers/master_data_provider.dart`](FE/lib/features/master_data/providers/master_data_provider.dart): `saveBrand()` mengirim `is_all_brands` dan `component_brand_ids`.
  - [`FE/lib/features/master_data/presentation/master_distributor_screen.dart`](FE/lib/features/master_data/presentation/master_distributor_screen.dart):
    - Popup **+ Tambah / Edit Brand** ditambah mode `SegmentedButton`: **Brand Tunggal** vs **Brand Gabungan (Mix / All)**, toggle **Semua Brand (All Brand)**, `FilterChip` checklist brand tunggal (minimal 2), dan auto-fill kode/nama.
    - Tabel **Tab Brand** menampilkan badge komponen penyusun pada kolom ke-3.

---

### 2. Deskripsi Kode pada Panduan Template Upload Excel
Menambahkan keterangan lengkap pada **Sheet 2 Excel (`Panduan & Kode Referensi`)** dan panel panduan FE tanpa mengubah struktur kolom **Sheet 1 (`Data Upload`)**.

- **Backend**:
  - [`BE/app/Exports/BulkUploadTemplateExport.php`](BE/app/Exports/BulkUploadTemplateExport.php):
    - **Sheet 1 (`Data Upload`)** tetap 9 kolom (`period, distributor_code, depo_code, area_code, brand_code, metrik_target, target_quota, target_outlet, username`).
    - **Sheet 2 (`Panduan & Kode Referensi`)**:
      - **A. Brand**: tambah kolom `Tipe Brand` & `Deskripsi / Komponen Gabungan`.
      - **B. Region**: tambah kolom `Deskripsi`.
      - **C. Distributor**: tambah kolom `Region` & `Jumlah Depo` (limit dinaikkan ke 1000).
      - **D. Depo**: tambah kolom `Nama Distributor Induk` (limit dinaikkan ke 1000).
      - **E. Area**: tampilkan lengkap `Kode Depo`, `Nama Depo`, `Kode Distributor Induk`, `Nama Distributor` (limit dinaikkan ke 2000).
      - **F. User / Sales**: pisahkan `Kode Jabatan` & `Nama Jabatan`.
      - Contoh `brand_code` diperbarui ke `KAPAL / KAPAL+JEMPOL / ALL_BRAND`.
- **Frontend**:
  - [`FE/lib/features/bulk_upload/presentation/bulk_upload_screen.dart`](FE/lib/features/bulk_upload/presentation/bulk_upload_screen.dart): Pembaruan deskripsi panduan kolom `master_target_distributor` (tetap 9 kolom) dengan referensi Sheet 2 dan contoh Brand Gabungan.

---

### 3. Pemulihan Data Master Distributor & Pengaman Anti-Konflik Upload / Edit
Mengatasi insiden upload Excel `data_export_distributor_semua_periode (5).xlsx` (baris 184–188) di mana *Excel auto-drag* mengubah `DST0004` menjadi `DST0005`–`DST0009` dan menimpa nama distributor lain, serta bug hilangnya area saat edit distributor lewat UI.

- **Pemulihan Data Produksi (`susantimegah_sales_insentif`)**:
  - Mengembalikan nama & region `DST0004` (`PUJI SURYA INDAH, PT`, EAST), `DST0005` (`OGAN SAKTI PRATAMA, PT`, WEST), `DST0006` (`CAHAYA MITRA SEKAWAN, PT`, EAST), `DST0007` (`SINERGI DISTRIBUSI UTAMA, PT`, EAST), `DST0008` (`UNICHELL MAKMUR INDONESIA, PT`, EAST), `DST0009` (`SEMANGAT MUDA PERDANA, PT`, EAST).
  - Mengembalikan Depo `C110003969` (`KENDARI`), `C110003971` (`BANJARMASIN`), `C110003919` (`BALI`), `C110003920` (`LOMBOK` + `AR00028`), dan `C110003918` (`MADURA` + `AR00030`) ke `DST0004`.
  - Memulihkan Area `AR00037` (`JAMBI` pada `DST0005`) serta `AR00039`, `AR00040`, `AR00175` pada `DST0007`.
  - Menghapus area duplikat kosong `AR0194` & `AR0197`.
- **Pengaman Kode**:
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php): `processDistributorBulk()` kini menolak upload sebelum transaksi DB bila terdeteksi:
    1. 1 `distributor_code` memiliki >1 `distributor_name` berbeda dalam 1 file.
    2. 1 `distributor_name` dipakai >1 `distributor_code` berbeda (dalam file maupun bentrok dengan DB).
    3. 1 `depo_code` muncul di >1 `distributor_code` berbeda.
    4. 1 `area_code` bentrok dipakai di Depo lain.
  - [`BE/app/Http/Controllers/DistributorController.php`](BE/app/Http/Controllers/DistributorController.php): `index()` kini memuat eager-load `'depos.areas:id,depo_id,code,name'`.
  - [`FE/lib/features/master_data/presentation/master_distributor_screen.dart`](FE/lib/features/master_data/presentation/master_distributor_screen.dart): `_showComprehensiveDistributorDialog()` mengambil fallback area dari `masterDataProvider.areas` bila `d.areas` kosong, sehingga edit nama distributor tidak pernah menghapus area.

---

### 4. Standarisasi Auto-Generate Kode (`DSTxxxx` 4 Digit & `ARxxxxx` 5 Digit)
Menyeragamkan seluruh kode distributor menjadi 4 digit (`DST0001` dst.) dan kode area menjadi 5 digit (`AR00001` dst.) tanpa akhiran `-1`.

- **Perbaikan Data Produksi**:
  - `DST052` $\rightarrow$ `DST0052` (`SURYA SAKTI, CV`), `DST053` $\rightarrow$ `DST0053` (`HOKIE, CV`).
  - `AR00183-1` $\rightarrow$ `AR00185` (`BALIKPAPAN`), `AR00190-1` $\rightarrow$ `AR00191` (`BABULU`), `AR0192` $\rightarrow$ `AR00192` (`MAGELANG`), `AR0196` $\rightarrow$ `AR00206` (`BANJARMASIN`).
  - Hasil verifikasi produksi: `53` distributor (`0` non-4-digit), `188` area (`0` non-5-digit).
- **Perbaikan Backend**:
  - [`BE/app/Http/Controllers/DistributorController.php`](BE/app/Http/Controllers/DistributorController.php): Menambahkan `normalizeCodeFormat()` dan mengganti fallback collision `-1` dengan `nextSequentialCode(Area::class, 'AR', 5)`.
  - [`BE/app/Http/Controllers/DepoController.php`](BE/app/Http/Controllers/DepoController.php) & [`BE/app/Http/Controllers/AreaController.php`](BE/app/Http/Controllers/AreaController.php): Menormalisasi kode area ke 5 digit dan menghindari akhiran `-1`.
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php): Normalisasi kode saat import Distributor, serta lookup toleran pada import `Sell-Out` & `Master Target` agar file lama dengan `DST053` / `AR0192` tetap terbaca.

---

### 5. Fix Error `users_email_unique` Saat Import Master Target Distributor
Mengatasi error `SQLSTATE[23505]: duplicate key value violates unique constraint "users_email_unique"` (kasus `deda_spv@company.com` pada user `id=8` yang username-nya sudah diubah menjadi `ass_deda`).

- **Backend**:
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php):
    - Menambahkan helper `buildUserLookupMaps()` yang memetakan `username`, `email` lengkap, dan prefix email (sebelum `@`) secara case-insensitive + `trim()`.
    - Resolusi role `Sales` dan posisi `ASM` / `SPV` kini mengambil ID dinamis dari tabel `roles` & `positions`.
    - Sebelum `insertGetId` user baru, sistem mengecek kecocokan `username` maupun `email` di database, serta memberi suffix unik bila email kebetulan sudah dipakai user lain.

---

### 6. Fix Kartu Ganda Depo pada Perhitungan Insentif Distributor (`DEPO + SELL_OUT`)
Mengatasi munculnya 2 kartu identik (contoh: `UNICHELL MAKMUR INDONESIA, PT -> Depo: JEMBER | Brand: KAPAL`) akibat baris Excel `SELL_OUT` tanpa `area_code` yang tersimpan sebagai `level = DEPO`.

- **Pembersihan Data Produksi**: Menghapus `120` baris `master_targets` (`kategori_skema = KONSUMSI`, `level = DEPO`, `metrik_target != SELL_IN`).
- **Backend**:
  - [`BE/app/Http/Controllers/IncentiveCalculationController.php`](BE/app/Http/Controllers/IncentiveCalculationController.php): Menambahkan `->where('metrik_target', 'SELL_IN')` pada `$depoQuery` agar kartu Depo hanya membaca target `SELL_IN`.
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php): Di `processMasterTargetDistributorBulk()`, baris level `DEPO` (`area_code` kosong) yang bukan `SELL_IN` kini diabaikan agar tidak memicu kartu ganda di kemudian hari.

---

### 7. Re-Link 49.558 Baris `sellout_distributors` (`UNICHELL` & `SINERGI`) ke ID Area Terbaru
Menyambungkan ulang `49.558` baris `sellout_distributors` (20 kelompok `area_id` lama: `565`, `567`–`585`, `698`) yang sebelumnya tampil `Area: -` akibat area lama sempat terhapus saat bug Edit Distributor di UI. Seluruh baris dipetakan 1-to-1 ke ID Area terbaru (`718`–`727`, `921`–`923`, `928`–`935`) berdasarkan `depo_id` & `kota_kab` (`Remaining orphan area_id = 0`).

---

### 8. Proteksi Hapus Depo & Area Terpakai + Soft Deletes Hierarki Distributor
Mencegah insiden terputusnya relasi transaksi (`orphan area_id` / `orphan depo_id`) saat admin menghapus atau mengedit Distributor, Depo, maupun Area.

- **Migrasi Database**:
  - [`BE/database/migrations/2026_11_24_000002_add_soft_deletes_to_distributor_hierarchy.php`](BE/database/migrations/2026_11_24_000002_add_soft_deletes_to_distributor_hierarchy.php): Menambahkan `deleted_at` (`softDeletes`) pada tabel `distributors`, `depos`, dan `areas`.
- **Model & Controller**:
  - [`BE/app/Models/Distributor.php`](BE/app/Models/Distributor.php), [`BE/app/Models/Depo.php`](BE/app/Models/Depo.php), [`BE/app/Models/Area.php`](BE/app/Models/Area.php): Mengaktifkan trait `SoftDeletes`.
  - [`BE/app/Http/Controllers/DistributorController.php`](BE/app/Http/Controllers/DistributorController.php): Menambahkan `findAreaUsageReason()` dan `findDepoUsageReason()`. Menolak (`422`) penghapusan Distributor, Depo, maupun Area (baik via `DELETE` maupun saat dihapus dari nested form `PUT`) jika masih terpakai pada `sellin_distributors`, `sellout_distributors`, `master_targets`, atau `sales_distributor_assignments`.
  - [`BE/app/Http/Controllers/DepoController.php`](BE/app/Http/Controllers/DepoController.php) & [`BE/app/Http/Controllers/AreaController.php`](BE/app/Http/Controllers/AreaController.php): Menerapkan guard yang sama pada `update()` dan `destroy()`.
  - [`BE/app/Services/BatchImportService.php`](BE/app/Services/BatchImportService.php): Upsert distributor/depo/area otomatis mereset `deleted_at = null` bila kode lama di-import kembali.

---

### 9. Auto-Sync Realisasi Sell-In SAP Otomatis (Smart TTL 15 Menit)
Menghilangkan kebutuhan klik tombol **Sync SAP** manual setiap kali ingin melihat realisasi Sell-In terbaru di **Dashboard**, **Realisasi Penjualan**, maupun **Insentif Distributor**.

- **Backend**:
  - [`BE/app/Services/SellinSapSyncService.php`](BE/app/Services/SellinSapSyncService.php): Service baru dengan `syncIfStale()` (TTL cache 15 menit, concurrency `Cache::lock` 45 detik, fallback backoff 2 menit jika SAP tidak terjangkau agar halaman tetap terbuka normal). Auto-sync aktif untuk bulan berjalan, bulan lalu, serta bulan lalu yang masih `0` baris.
  - [`BE/app/Http/Controllers/SellinDistributorController.php`](BE/app/Http/Controllers/SellinDistributorController.php): `index()` otomatis memanggil `syncIfStale()`; `syncFromSap()` memanggil `syncPeriod()` secara terpusat.
  - [`BE/app/Http/Controllers/DashboardController.php`](BE/app/Http/Controllers/DashboardController.php) & [`BE/app/Http/Controllers/IncentiveCalculationController.php`](BE/app/Http/Controllers/IncentiveCalculationController.php): Otomatis memanggil `syncPeriodsIfStale()` sebelum menyajikan ringkasan & perhitungan insentif.

---

### 10. Infrastruktur Deploy
- [`deploy_cpanel/deploy_ke_cpanel.ps1`](deploy_cpanel/deploy_ke_cpanel.ps1): Menambahkan `-timeout=60` pada koneksi SFTP WinSCP untuk mengurangi timeout pada jaringan dengan latensi tinggi.
- Semua perubahan BE & FE di atas telah di-deploy ke produksi (`api-prod.garamonline.com` & `insentif-dev.susantimegah.com`).

---

## 2026-11-25

### 11. Fix Bug Loncat Area & Perubahan PIC pada Dialog Edit Target Kuota (+ Pemulihan Data Trenggalek)
Mengatasi bug saat membuka dialog **Ubah Target Area** (kasus `UNICHELL MAKMUR INDONESIA, PT` $\rightarrow$ `Depo PONOROGO C110001919` $\rightarrow$ `Area TRENGGALEK AR00217`), di mana pilihan Area otomatis loncat ke `PONOROGO (AR00216)` dan PIC berubah dari `Bayu Samodra` ke `Saturda Hasan Srihardino (@ass_dino)`.

- **Akar Masalah**:
  - `loadAreasForDepo()` di [`master_target_screen.dart`](FE/lib/features/master_data/presentation/master_target_screen.dart) mereset `selectedAreaId = null` dan memilih area abjad pertama ketika daftar area selesai dimuat.
  - `detectSpvForArea()` mengambil assignment aktif pertama tanpa mencocokkan `period` (`YYYYMM`) maupun mempertahankan `targetToEdit.userId`, lalu menimpanya saat simpan.
- **Frontend**:
  - [`FE/lib/features/master_data/presentation/master_target_screen.dart`](FE/lib/features/master_data/presentation/master_target_screen.dart):
    - Menambahkan parameter `preserveSelection` pada `loadAreasForDepo()` (diteruskan dari `loadDeposForDistributor()`) agar Area awal tetap terkunci saat dialog Edit terbuka.
    - Menjadikan `detectAsmForDistributor()` dan `detectSpvForArea()` sadar periode (`period`), mempertahankan `targetToEdit.userId`, serta mengganti banner read-only ASM/SPV dengan dropdown pemilihan PIC (`DropdownButtonFormField<int?>`) di mode **Ubah Target Depo** maupun **Ubah Target Area** (+ mode tahunan terpadu membiarkan backend me-resolve PIC per bulan).
- **Backend**:
  - [`BE/app/Http/Controllers/MasterTargetController.php`](BE/app/Http/Controllers/MasterTargetController.php):
    - Memperbaiki `hierarchy()` dan `store()` (`$resolveAsm`, `$resolveSpv`) agar resolusi assignment mendahulukan kecocokan `period` yang tepat (`CASE WHEN period = ? THEN 0 ELSE 1 END`, urut `id DESC`).
- **Pemulihan Data Produksi (`susantimegah_sales_insentif`)**:
  - Memindahkan kembali 3 baris `master_targets` `KAPAL` (`id=12091` `202606`, `id=12106` `202607`, `id=12121` `202608`) dari `AR00216 (PONOROGO)` ke `AR00217 (TRENGGALEK)` dengan PIC `Bayu Samodra` (`user_id=11`).
  - Memulihkan baris `202609` `KAPAL` (`id=12184`, `qty=26000`, `ao=130`, `user_id=11`) pada `AR00217 (TRENGGALEK)`.
  - Verifikasi DB: `AR00216` memiliki tepat `12` baris `JEMPOL` (`202601`–`202612`) dan `AR00217` memiliki tepat `12` baris `KAPAL` (`202601`–`202612`).
- Perubahan BE & FE telah di-build dan di-deploy ke produksi (`api-prod.garamonline.com` & `insentif-dev.susantimegah.com`).

---

### 12. Audit Menyeluruh & Test Aplikasi (Cascading Dropdown, Resolusi PIC per Periode, & Konsistensi DB)
Menindaklanjuti pengujian menyeluruh di seluruh modul FE, BE, dan database produksi untuk mencegah terulangnya bug loncat pilihan dropdown, resolusi PIC lintas periode/posisi, maupun hilangnya anak relasi saat edit.

- **Frontend (`FE/lib/features/...`)**:
  - [`master_target_screen.dart`](FE/lib/features/master_data/presentation/master_target_screen.dart): `detectAsmForDistributor()` kini menerima `depoId` + `period` (mengutamakan assignment depo/target depo di periode terkait sebelum fallback distributor) untuk mendukung distributor multi-ASM (misal `SAKTI SETIA SANTOSA, PT`); menambah `ValueKey` pada dropdown Distributor dan Brand.
  - [`master_distributor_screen.dart`](FE/lib/features/master_data/presentation/master_distributor_screen.dart): `_showDepoDialog()` kini mengambil fallback `state.areas.where((a) => a.depoId == depo.id)` saat `depo.areas` kosong agar edit Depo tidak mengosongkan area; menambah guard `initialValue` pada dropdown Distributor & Depo.
  - [`distributor_assignment_hierarchy_view.dart`](FE/lib/features/master_data/presentation/widgets/distributor_assignment_hierarchy_view.dart): `_showBulkMapDialog()` kini mempertahankan user ter-assign pada daftar pilihan, sinkron ulang pilihan ASM & SPV saat input `Periode (YYYYMM)` berubah (`syncForPeriod`), serta menambah `ValueKey` per periode.
  - [`master_surabaya_screen.dart`](FE/lib/features/master_data/presentation/master_surabaya_screen.dart): `_showAssignDistributorDialog()` kini mendukung posisi `ASC` setara `SPV` pada form bertingkat (ASM $\rightarrow$ Distributor $\rightarrow$ Depo $\rightarrow$ Area), menambah fallback Depo/Area dari `masterState`, auto-pilih ASM berdasarkan Distributor/periode, dan guard `initialValue`.
  - [`user_management_screen.dart`](FE/lib/features/users_management/presentation/user_management_screen.dart): `_showUserFormDialog()` menambah guard `initialValue` pada dropdown `Role Akses`, `Posisi Sales`, serta `ValueKey` pada `Kode Sales SAP`.
- **Backend (`BE/app/...`)**:
  - [`IncentiveCalculationController.php`](BE/app/Http/Controllers/IncentiveCalculationController.php): `buildDistributorBreakdownPayload()` kini memetakan ASM (per `depo_id:period` / `distributor_id:period`) dan SPV/ASC (per `area_id:period`) secara sadar periode.
  - [`DashboardController.php`](BE/app/Http/Controllers/DashboardController.php): Filter periode pada query `SalesDistributorAssignment` di `summary()` & `getSalesDashboard()`, serta dukungan posisi `ASC` setara `SPV`.
  - [`SalesAssignmentController.php`](BE/app/Http/Controllers/SalesAssignmentController.php) & [`BatchImportService.php`](BE/app/Services/BatchImportService.php): Mendukung `ASC` setara `SPV` dan menggantikan assignment SPV/ASC lama pada kombinasi `(area_id, period)` yang sama agar tidak terjadi duplikat PIC aktif.
- **Pembersihan Data Produksi (`susantimegah_sales_insentif`)**:
  - Menghapus duplikat assignment `id=1457` (`area_id=674 SANGGAU`, periode `202610`) dan `12` baris sisa `SPV`/`ASC` dengan `area_id IS NULL & depo_id IS NULL` (`id=343..354`). Verifikasi akhir: `dupAreaPeriodAssign = 0`, `badDepoDist = 0`, `badAreaDepo = 0`.
- **Verifikasi & Uji Live Produksi**:
  - `php -l` (4 file BE): lolos tanpa error; `flutter analyze` (seluruh `FE/`): `No issues found!`.
  - Build Flutter Web & deploy BE/FE ke produksi (`api-prod.garamonline.com` & `insentif-dev.susantimegah.com`) selesai.
  - Smoke test BE pada periode `202605`, `202610`, `202611`: `200 OK`, PIC `TRENGGALEK (AR00217)` sesuai (`Bayu Samodra` di `202605`, `Saturda Hasan Srihardino` di `202610`–`202611`).
  - Uji live browser pada `insentif-dev.susantimegah.com`: **Dashboard**, **Master Target Kuota** (Edit `202605` & `202611` `TRENGGALEK` tetap mengunci `AR00217` dengan PIC sesuai periode), **Master Distributor** (Edit Depo menampilkan area tercover), **Insentif Distributor** (`200 OK`), dan **Tim & Area Sales** (`Atur PIC` periode `202610` otomatis tampilkan `Saturda Hasan Srihardino`, dihentikan sebelum tes pindah ke `202605` atas permintaan user).

---

### 13. Fix Bug Tampilan Palsu "Akses Penuh" Hak Akses RBAC (`Admin Sales`)
Mengatasi ketidaksinkronan antara tampilan matriks **Pengguna & Akses ➔ Hak Akses** dengan menu sidebar pada role non-superadmin yang mengandung kata `admin` (contoh: `Admin Sales` / `Administrator Sales & Data`, di mana `#11 Pengguna & Akses` belum tersimpan di `role_menu_permissions` namun ditampilkan seolah-olah `Akses Penuh`).

- **Frontend**:
  - [`FE/lib/features/users_management/presentation/user_management_screen.dart`](FE/lib/features/users_management/presentation/user_management_screen.dart):
    - Memperketat fallback `_syncWorkingPermissions()` dari `role.name.toLowerCase().contains('admin')` menjadi exact match superadmin (`administrator` / `superadmin` / `admin`) agar selaras 1-to-1 dengan `dashboard_layout.dart`.
    - Reset `_lastSyncedRoleId` setelah simpan berhasil dan memanggil `authProvider.checkAuth()` bila role yang diubah adalah role user yang sedang login.
  - [`FE/lib/features/users_management/providers/user_management_provider.dart`](FE/lib/features/users_management/providers/user_management_provider.dart):
    - `updateRolePermissions()` kini mengembalikan `false` + pesan error ketika server merespons 4xx/5xx, tidak lagi menelan error sebagai sukses lokal.
- Verifikasi `flutter analyze` (`No issues found!`), build web, dan deploy ke produksi (`insentif-dev.susantimegah.com`) selesai.

## #14 - Template & Bulk Upload Master Target Sales Industri & Sales Surabaya (2026-11-25)
- **Backend**:
  - `BE/app/Http/Controllers/BatchUploadController.php`: Daftarkan entitas `master_target_industri` dan `master_target_surabaya` di `$allowedEntities`.
  - `BE/app/Exports/BulkUploadTemplateExport.php`: Tambah template kosong, export data eksisting (`getMasterTargetSalesData()`), serta panduan kolom Sheet 2 untuk `master_target_industri` (`SELL_IN` Kg & `NOO` Toko) dan `master_target_surabaya` (`SELL_OUT` Kg & `AO` Toko).
  - `BE/app/Services/BatchImportService.php`: Tambah normalisasi entitas, auto-detect guard, importer `processMasterTargetSalesBulk()` (mendukung ekspansi periode 4 digit `YYYY` ke 12 bulan, auto-create PIC sales jika belum terdaftar, serta upsert `master_targets`), dan dukungan rollback batch.
- **Frontend**:
  - `FE/lib/features/bulk_upload/presentation/bulk_upload_screen.dart`: Tambah opsi `Master: Target Sales Industri (Sell-In & NOO)` dan `Master: Target Sales Surabaya (Sell-Out & AO)` beserta panduan kolomnya pada dropdown Bulk Upload Center (tanpa `Sell-Out Surabaya` karena realisasi Sell-Out Surabaya berasal dari SAP).
  - `FE/lib/features/master_data/presentation/master_target_screen.dart`: Tombol **Tarik Excel Template** kini otomatis memilih entitas sesuai tab aktif (`master_target_distributor`, `master_target_industri`, atau `master_target_surabaya`).

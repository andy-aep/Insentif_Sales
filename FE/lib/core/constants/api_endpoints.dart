class ApiEndpoints {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';

  // 1. User & Access Management
  static const String users = '/users';
  static String userPassword(int id) => '/users/$id/password';
  static const String roles = '/roles';
  static String rolePermissions(int id) => '/roles/$id/permissions';
  static const String positions = '/positions';
  static const String menus = '/menus';

  // 2. Master Organisasi & Brand
  static const String regions = '/regions';
  static const String distributors = '/distributors';
  static const String depos = '/depos';
  static const String areas = '/areas';
  static const String brands = '/brands';

  // 3. Master Realisasi Penjualan (SAP / Upload)
  static const String sellinDistributors = '/sellin-distributors';
  static const String selloutDistributors = '/sellout-distributors';
  static const String sellinIndustris = '/sellin-industris';
  static const String selloutSurabayas = '/sellout-surabayas';

  // 4. Master Sales Assignments (Distributor Konsumsi & Surabaya)
  static const String salesDistributorAssignments = '/sales-distributor-assignments';
  static const String salesSurabayaAssignments = '/sales-surabaya-assignments';
  static const String surabayaAssignments = '/sales-surabaya-assignments';

  // 5. Master Target (Distributor, Industri, Surabaya)
  static const String masterTargets = '/master-targets';
  static const String masterTargetPeriods = '/master-targets/periods';

  // 6. Setting Insentif 3-Level
  static const String targetHeaders = '/target-headers';
  static const String grades = '/grades';
  static const String gradeBobots = '/grade-bobots';
  static const String percentTargets = '/percent-targets';
  static const String nilaiRewards = '/nilai-rewards';

  // 7. Kalkulasi & Laporan Insentif per Skema
  static const String calculateIncentive = '/incentives/calculate';
  static const String incentiveResults = '/incentives/results';
  static const String exportExcel = '/incentives/export-excel';

  // 8. Bulk Upload & Batch Rollback
  static String bulkUpload(String entity) => '/bulk-upload/$entity';
  static String bulkUploadTemplate(String entity) => '/bulk-upload/template/$entity';
  static String rollbackBatch(String batchId) => '/bulk-upload/rollback/$batchId';
  static const String batchHistory = '/bulk-upload/history';
}

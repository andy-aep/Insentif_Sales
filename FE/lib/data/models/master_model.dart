import 'auth_user_model.dart';

class BrandModel {
  final int id;
  final String code;
  final String name;

  BrandModel({required this.id, required this.code, required this.name});

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'name': name};
}

class RegionModel {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int distributorsCount;

  RegionModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.distributorsCount = 0,
  });

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      distributorsCount: json['distributors_count'] is int ? json['distributors_count'] : int.tryParse(json['distributors_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
  };
}

class DistributorModel {
  final int id;
  final String code;
  final String name;
  final String? address;
  final int? regionId;
  final RegionModel? region;
  final List<DepoModel> depos;

  DistributorModel({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.regionId,
    this.region,
    this.depos = const [],
  });

  factory DistributorModel.fromJson(Map<String, dynamic> json) {
    var depList = json['depos'] as List? ?? [];
    return DistributorModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      regionId: json['region_id'] != null ? int.tryParse(json['region_id'].toString()) : null,
      region: json['region'] != null ? RegionModel.fromJson(json['region']) : null,
      depos: depList.map((d) => DepoModel.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'address': address,
    'region_id': regionId,
  };
}

class DepoModel {
  final int id;
  final String code;
  final String name;
  final int? distributorId;
  final DistributorModel? distributor;
  final List<AreaModel> areas;

  DepoModel({
    required this.id,
    required this.code,
    required this.name,
    this.distributorId,
    this.distributor,
    this.areas = const [],
  });

  factory DepoModel.fromJson(Map<String, dynamic> json) {
    var arList = json['areas'] as List? ?? [];
    return DepoModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      distributorId: json['distributor_id'] != null ? int.tryParse(json['distributor_id'].toString()) : null,
      distributor: json['distributor'] != null ? DistributorModel.fromJson(json['distributor']) : null,
      areas: arList.map((a) => AreaModel.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'distributor_id': distributorId,
  };
}

class AreaModel {
  final int id;
  final String code;
  final String name;
  final int? depoId;
  final DepoModel? depo;

  AreaModel({
    required this.id,
    required this.code,
    required this.name,
    this.depoId,
    this.depo,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      depoId: json['depo_id'] != null ? int.tryParse(json['depo_id'].toString()) : null,
      depo: json['depo'] != null ? DepoModel.fromJson(json['depo']) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'name': name, 'depo_id': depoId};
}

// -----------------------------------------------------------------------
// Realisasi Penjualan Models (Sell-In & Sell-Out)
// -----------------------------------------------------------------------

class RealisasiSalesModel {
  final int id;
  final String entityType; // sellin_distributor, sellout_distributor, sellin_industri, sellout_surabaya
  final String period; // YYYYMM
  final int? userId;
  final int? distributorId;
  final int? depoId;
  final int? brandId;
  final String? customerCode;
  final String? customerName;
  final double volume; // Kg / Box
  final double amount; // Rp
  final int? activeOutlet; // AO
  final int? newOpenOutlet; // NOO
  final String? batchId;
  final UserModel? user;

  RealisasiSalesModel({
    required this.id,
    required this.entityType,
    required this.period,
    this.userId,
    this.distributorId,
    this.depoId,
    this.brandId,
    this.customerCode,
    this.customerName,
    required this.volume,
    required this.amount,
    this.activeOutlet,
    this.newOpenOutlet,
    this.batchId,
    this.user,
  });

  factory RealisasiSalesModel.fromJson(Map<String, dynamic> json) {
    return RealisasiSalesModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      entityType: json['entity_type'] ?? json['type'] ?? 'sellin_distributor',
      period: json['period']?.toString() ?? '',
      userId: json['user_id'] != null ? int.tryParse(json['user_id'].toString()) : null,
      distributorId: json['distributor_id'] != null ? int.tryParse(json['distributor_id'].toString()) : null,
      depoId: json['depo_id'] != null ? int.tryParse(json['depo_id'].toString()) : null,
      brandId: json['brand_id'] != null ? int.tryParse(json['brand_id'].toString()) : null,
      customerCode: json['customer_code'] ?? json['doc_no'],
      customerName: json['customer_name'] ?? json['distributor_name'],
      volume: double.tryParse(json['volume']?.toString() ?? json['qty']?.toString() ?? '0') ?? 0.0,
      amount: double.tryParse(json['amount']?.toString() ?? json['total_amount']?.toString() ?? '0') ?? 0.0,
      activeOutlet: json['active_outlet'] != null ? int.tryParse(json['active_outlet'].toString()) : null,
      newOpenOutlet: json['new_open_outlet'] != null ? int.tryParse(json['new_open_outlet'].toString()) : null,
      batchId: json['batch_id']?.toString(),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_type': entityType,
    'period': period,
    'user_id': userId,
    'distributor_id': distributorId,
    'depo_id': depoId,
    'brand_id': brandId,
    'customer_code': customerCode,
    'customer_name': customerName,
    'volume': volume,
    'amount': amount,
    'active_outlet': activeOutlet,
    'new_open_outlet': newOpenOutlet,
    'batch_id': batchId,
  };
}

// -----------------------------------------------------------------------
// Surabaya Coordinator & Sales Assignment Model
// -----------------------------------------------------------------------

class SurabayaAssignmentModel {
  final int id;
  final int coordinatorId;
  final int salesId;
  final String salesType; // 'Taking Order' atau 'Canvasing'
  final String period;
  final bool isActive;
  final UserModel? coordinator;
  final UserModel? sales;

  SurabayaAssignmentModel({
    required this.id,
    required this.coordinatorId,
    required this.salesId,
    required this.salesType,
    required this.period,
    required this.isActive,
    this.coordinator,
    this.sales,
  });

  factory SurabayaAssignmentModel.fromJson(Map<String, dynamic> json) {
    return SurabayaAssignmentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      coordinatorId: json['coordinator_id'] is int ? json['coordinator_id'] : int.tryParse(json['coordinator_id'].toString()) ?? 0,
      salesId: json['sales_id'] is int ? json['sales_id'] : int.tryParse(json['sales_id'].toString()) ?? 0,
      salesType: json['sales_type'] ?? 'Taking Order',
      period: json['period']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      coordinator: json['coordinator'] != null ? UserModel.fromJson(json['coordinator']) : null,
      sales: json['sales'] != null ? UserModel.fromJson(json['sales']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'coordinator_id': coordinatorId,
    'sales_id': salesId,
    'sales_type': salesType,
    'period': period,
    'is_active': isActive,
  };
}

// -----------------------------------------------------------------------
// Sales Distributor Assignment Model (Eligible Konsumsi: ASM & SPV)
// -----------------------------------------------------------------------

class SalesDistributorAssignmentModel {
  final int id;
  final int userId;
  final int? nsmId;
  final int? lsmId;
  final int? asmId;
  final int? regionId;
  final int? distributorId;
  final int? depoId;
  final int? areaId;
  final String period;
  final bool isActive;
  final String? notes;
  final UserModel? user;
  final UserModel? nsm;
  final UserModel? lsm;
  final UserModel? asm;
  final RegionModel? region;
  final DistributorModel? distributor;
  final DepoModel? depo;
  final AreaModel? area;
  final List<SalesDistributorAssignmentModel> subordinateLsms;

  SalesDistributorAssignmentModel({
    required this.id,
    required this.userId,
    this.nsmId,
    this.lsmId,
    this.asmId,
    this.regionId,
    this.distributorId,
    this.depoId,
    this.areaId,
    required this.period,
    required this.isActive,
    this.notes,
    this.user,
    this.nsm,
    this.lsm,
    this.asm,
    this.region,
    this.distributor,
    this.depo,
    this.area,
    this.subordinateLsms = const [],
  });

  factory SalesDistributorAssignmentModel.fromJson(Map<String, dynamic> json) {
    var subLsms = json['subordinate_lsms'] as List? ?? [];

    return SalesDistributorAssignmentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      nsmId: json['nsm_id'] != null ? int.tryParse(json['nsm_id'].toString()) : null,
      lsmId: json['lsm_id'] != null ? int.tryParse(json['lsm_id'].toString()) : null,
      asmId: json['asm_id'] != null ? int.tryParse(json['asm_id'].toString()) : null,
      regionId: json['region_id'] != null ? int.tryParse(json['region_id'].toString()) : null,
      distributorId: json['distributor_id'] != null ? int.tryParse(json['distributor_id'].toString()) : null,
      depoId: json['depo_id'] != null ? int.tryParse(json['depo_id'].toString()) : null,
      areaId: json['area_id'] != null ? int.tryParse(json['area_id'].toString()) : null,
      period: json['period']?.toString() ?? '202610',
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      notes: json['notes'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      nsm: json['nsm'] != null ? UserModel.fromJson(json['nsm']) : null,
      lsm: json['lsm'] != null ? UserModel.fromJson(json['lsm']) : null,
      asm: json['asm'] != null ? UserModel.fromJson(json['asm']) : null,
      region: json['region'] != null ? RegionModel.fromJson(json['region']) : null,
      distributor: json['distributor'] != null ? DistributorModel.fromJson(json['distributor']) : null,
      depo: json['depo'] != null ? DepoModel.fromJson(json['depo']) : null,
      area: json['area'] != null ? AreaModel.fromJson(json['area']) : null,
      subordinateLsms: subLsms.map((s) => SalesDistributorAssignmentModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'nsm_id': nsmId,
    'lsm_id': lsmId,
    'asm_id': asmId,
    'region_id': regionId,
    'distributor_id': distributorId,
    'depo_id': depoId,
    'area_id': areaId,
    'period': period,
    'is_active': isActive,
    'notes': notes,
  };
}


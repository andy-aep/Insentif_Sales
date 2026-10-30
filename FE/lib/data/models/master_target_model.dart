import 'auth_user_model.dart';
import 'master_model.dart';

class MasterTargetModel {
  final int id;
  final int? userId;
  final int? distributorId;
  final int? depoId;
  final int? areaId;
  final int? brandId;
  final String level; // 'DISTRIBUTOR', 'DEPO', 'AREA', 'SALES'
  final String period; // YYYYMM e.g. 202610
  final String kategoriSkema; // 'DISTRIBUTOR' (Konsumsi), 'INDUSTRI', 'SURABAYA'
  final String targetType; // 'SELL_IN', 'SELL_OUT', 'AO', 'NOO'
  final double targetQuota; // Volume (Kg / Box) atau kuota angka
  final int? targetOutlet; // AO atau NOO target count
  final UserModel? user;
  final DistributorModel? distributor;
  final DepoModel? depo;
  final AreaModel? area;
  final BrandModel? brand;

  MasterTargetModel({
    required this.id,
    this.userId,
    this.distributorId,
    this.depoId,
    this.areaId,
    this.brandId,
    this.level = 'DEPO',
    required this.period,
    required this.kategoriSkema,
    required this.targetType,
    required this.targetQuota,
    this.targetOutlet,
    this.user,
    this.distributor,
    this.depo,
    this.area,
    this.brand,
  });

  factory MasterTargetModel.fromJson(Map<String, dynamic> json) {
    return MasterTargetModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] != null ? (json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString())) : null,
      distributorId: json['distributor_id'] != null ? (json['distributor_id'] is int ? json['distributor_id'] : int.tryParse(json['distributor_id'].toString())) : null,
      depoId: json['depo_id'] != null ? (json['depo_id'] is int ? json['depo_id'] : int.tryParse(json['depo_id'].toString())) : null,
      areaId: json['area_id'] != null ? (json['area_id'] is int ? json['area_id'] : int.tryParse(json['area_id'].toString())) : null,
      brandId: json['brand_id'] != null ? (json['brand_id'] is int ? json['brand_id'] : int.tryParse(json['brand_id'].toString())) : null,
      level: json['level']?.toString() ?? 'DEPO',
      period: json['period']?.toString() ?? '',
      kategoriSkema: json['kategori_skema'] ?? json['kategori'] ?? 'DISTRIBUTOR',
      targetType: json['metrik_target'] ?? json['target_type'] ?? 'SELL_IN',
      targetQuota: double.tryParse(json['target_quota']?.toString() ?? json['quota']?.toString() ?? '0') ?? 0.0,
      targetOutlet: json['target_outlet'] != null ? int.tryParse(json['target_outlet'].toString()) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      distributor: json['distributor'] != null ? DistributorModel.fromJson(json['distributor']) : null,
      depo: json['depo'] != null ? DepoModel.fromJson(json['depo']) : null,
      area: json['area'] != null ? AreaModel.fromJson(json['area']) : null,
      brand: json['brand'] != null ? BrandModel.fromJson(json['brand']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'distributor_id': distributorId,
    'depo_id': depoId,
    'area_id': areaId,
    'brand_id': brandId,
    'level': level,
    'period': period,
    'kategori_skema': kategoriSkema,
    'metrik_target': targetType,
    'target_quota': targetQuota,
    'target_outlet': targetOutlet,
  };
}

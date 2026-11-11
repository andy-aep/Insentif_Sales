import 'auth_user_model.dart';

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
  final String metricType;
  final String headerName;
  final String gradeName;
  final String bobotName;
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
    this.metricType = '',
    this.headerName = '',
    this.gradeName = '',
    this.bobotName = '',
    this.user,
  });

  factory IncentiveCalculationModel.fromJson(Map<String, dynamic> json) {
    final targetHeader = json['target_header'] as Map<String, dynamic>?;
    final grade = json['grade'] as Map<String, dynamic>?;
    final gradeBobot = json['grade_bobot'] as Map<String, dynamic>?;

    return IncentiveCalculationModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      kategoriSkema: json['kategori_skema'] ?? '',
      period: json['period']?.toString() ?? '',
      targetQuota: double.tryParse(json['target_quota'].toString()) ?? 0.0,
      realization: double.tryParse(json['realization'].toString()) ?? 0.0,
      achievementPercent: double.tryParse(json['achievement_percent'].toString()) ?? 0.0,
      cappedRealization: double.tryParse(json['capped_realization'].toString()) ?? 0.0,
      isRateBased: json['is_rate_based'] == true || json['is_rate_based'] == 1 || json['is_rate_based'] == '1',
      unitRate: double.tryParse(json['unit_rate'].toString()) ?? 0.0,
      lumpSumNominal: double.tryParse(json['lump_sum_nominal'].toString()) ?? 0.0,
      headerBobotPercent: double.tryParse(json['header_bobot_percent'].toString()) ?? 0.0,
      finalReward: double.tryParse(json['final_reward'].toString()) ?? 0.0,
      metricType: targetHeader?['type']?.toString() ?? '',
      headerName: targetHeader?['nama']?.toString() ?? '',
      gradeName: grade?['grade_name']?.toString() ?? '',
      bobotName: gradeBobot?['bobot_name']?.toString() ?? 'Under Target',
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'kategori_skema': kategoriSkema,
    'period': period,
    'target_quota': targetQuota,
    'realization': realization,
    'achievement_percent': achievementPercent,
    'capped_realization': cappedRealization,
    'is_rate_based': isRateBased,
    'unit_rate': unitRate,
    'lump_sum_nominal': lumpSumNominal,
    'header_bobot_percent': headerBobotPercent,
    'final_reward': finalReward,
    'metric_type': metricType,
    'header_name': headerName,
    'grade_name': gradeName,
    'bobot_name': bobotName,
    'user': user?.toJson(),
  };
}

class IncentiveSummaryMeta {
  final int totalPersonil;
  final double totalQuota;
  final double totalRealization;
  final double totalReward;
  final double avgAchievement;

  IncentiveSummaryMeta({
    required this.totalPersonil,
    required this.totalQuota,
    required this.totalRealization,
    required this.totalReward,
    required this.avgAchievement,
  });

  factory IncentiveSummaryMeta.fromCalculations(List<IncentiveCalculationModel> list) {
    if (list.isEmpty) {
      return IncentiveSummaryMeta(
        totalPersonil: 0,
        totalQuota: 0,
        totalRealization: 0,
        totalReward: 0,
        avgAchievement: 0,
      );
    }

    final uniqueUsers = list.map((e) => e.userId).toSet().length;
    final totalQuota = list.fold<double>(0, (sum, item) => sum + item.targetQuota);
    final totalRealization = list.fold<double>(0, (sum, item) => sum + item.realization);
    final totalReward = list.fold<double>(0, (sum, item) => sum + item.finalReward);
    final avgAchievement = list.fold<double>(0, (sum, item) => sum + item.achievementPercent) / list.length;

    return IncentiveSummaryMeta(
      totalPersonil: uniqueUsers,
      totalQuota: totalQuota,
      totalRealization: totalRealization,
      totalReward: totalReward,
      avgAchievement: avgAchievement,
    );
  }
}

class DistributorBreakdownAreaModel {
  final int no;
  final String areaName;
  final String areaCode;
  final String brandName;
  final String spvName;
  final double sellOutTarget;
  final double sellOutReal;
  final double sellOutAchPct;
  final double sellOutReward;
  final int aoTarget;
  final int aoReal;
  final double aoAchPct;
  final double aoReward;
  final double subtotalAreaReward;

  DistributorBreakdownAreaModel({
    required this.no,
    required this.areaName,
    required this.areaCode,
    required this.brandName,
    required this.spvName,
    required this.sellOutTarget,
    required this.sellOutReal,
    required this.sellOutAchPct,
    required this.sellOutReward,
    required this.aoTarget,
    required this.aoReal,
    required this.aoAchPct,
    required this.aoReward,
    required this.subtotalAreaReward,
  });

  factory DistributorBreakdownAreaModel.fromJson(Map<String, dynamic> json) {
    return DistributorBreakdownAreaModel(
      no: (json['no'] as num?)?.toInt() ?? 1,
      areaName: json['area_name']?.toString() ?? '-',
      areaCode: json['area_code']?.toString() ?? '-',
      brandName: json['brand_name']?.toString() ?? '-',
      spvName: json['spv_name']?.toString() ?? '-',
      sellOutTarget: (json['sell_out_target'] as num?)?.toDouble() ?? 0.0,
      sellOutReal: (json['sell_out_real'] as num?)?.toDouble() ?? 0.0,
      sellOutAchPct: (json['sell_out_ach_pct'] as num?)?.toDouble() ?? 0.0,
      sellOutReward: (json['sell_out_reward'] as num?)?.toDouble() ?? 0.0,
      aoTarget: (json['ao_target'] as num?)?.toInt() ?? 0,
      aoReal: (json['ao_real'] as num?)?.toInt() ?? 0,
      aoAchPct: (json['ao_ach_pct'] as num?)?.toDouble() ?? 0.0,
      aoReward: (json['ao_reward'] as num?)?.toDouble() ?? 0.0,
      subtotalAreaReward: (json['subtotal_area_reward'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DistributorBreakdownCardModel {
  final int id;
  final String distributorName;
  final String depoName;
  final String brandName;
  final String asmName;
  final String period;
  final String periodFormatted;
  final double sellInTarget;
  final double sellInReal;
  final double sellInAchPct;
  final double sellInReward;
  final double totalDepoReward;
  final int areasCount;
  final List<DistributorBreakdownAreaModel> areas;

  DistributorBreakdownCardModel({
    required this.id,
    required this.distributorName,
    required this.depoName,
    required this.brandName,
    required this.asmName,
    required this.period,
    required this.periodFormatted,
    required this.sellInTarget,
    required this.sellInReal,
    required this.sellInAchPct,
    required this.sellInReward,
    required this.totalDepoReward,
    required this.areasCount,
    required this.areas,
  });

  factory DistributorBreakdownCardModel.fromJson(Map<String, dynamic> json) {
    final rawAreas = json['areas'] as List? ?? [];
    return DistributorBreakdownCardModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      distributorName: json['distributor_name']?.toString() ?? '-',
      depoName: json['depo_name']?.toString() ?? '-',
      brandName: json['brand_name']?.toString() ?? '-',
      asmName: json['asm_name']?.toString() ?? '-',
      period: json['period']?.toString() ?? '',
      periodFormatted: json['period_formatted']?.toString() ?? '',
      sellInTarget: (json['sell_in_target'] as num?)?.toDouble() ?? 0.0,
      sellInReal: (json['sell_in_real'] as num?)?.toDouble() ?? 0.0,
      sellInAchPct: (json['sell_in_ach_pct'] as num?)?.toDouble() ?? 0.0,
      sellInReward: (json['sell_in_reward'] as num?)?.toDouble() ?? 0.0,
      totalDepoReward: (json['total_depo_reward'] as num?)?.toDouble() ?? 0.0,
      areasCount: (json['areas_count'] as num?)?.toInt() ?? rawAreas.length,
      areas: rawAreas.map((a) => DistributorBreakdownAreaModel.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }
}

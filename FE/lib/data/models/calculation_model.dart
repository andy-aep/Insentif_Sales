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

// -----------------------------------------------------------------------
// Industri Incentive Audit Breakdown Models
// -----------------------------------------------------------------------

class IndustriMethodBreakdownModel {
  final int targetHeaderId;
  final String headerName;
  final String method; // SELL_IN or NOO
  final double targetQuota;
  final double actualRealization;
  final double actualVolumeKg;
  final double achievementPercent;
  final double minAchievementPct;
  final bool isPassed;
  final int? gradeId;
  final String? gradeName;
  final double multiplierRate;
  final double headerWeightPct;
  final double grossReward;
  final double finalReward;
  final String? auditNotes;

  IndustriMethodBreakdownModel({
    required this.targetHeaderId,
    required this.headerName,
    required this.method,
    required this.targetQuota,
    required this.actualRealization,
    required this.actualVolumeKg,
    required this.achievementPercent,
    required this.minAchievementPct,
    required this.isPassed,
    this.gradeId,
    this.gradeName,
    required this.multiplierRate,
    required this.headerWeightPct,
    required this.grossReward,
    required this.finalReward,
    this.auditNotes,
  });

  factory IndustriMethodBreakdownModel.fromJson(Map<String, dynamic> json) {
    return IndustriMethodBreakdownModel(
      targetHeaderId: (json['target_header_id'] as num?)?.toInt() ?? 0,
      headerName: json['header_name']?.toString() ?? '-',
      method: json['method']?.toString() ?? 'SELL_IN',
      targetQuota: (json['target_quota'] as num?)?.toDouble() ?? 0.0,
      actualRealization: (json['actual_realization'] as num?)?.toDouble() ?? 0.0,
      actualVolumeKg: (json['actual_volume_kg'] as num?)?.toDouble() ?? 0.0,
      achievementPercent: (json['achievement_percent'] as num?)?.toDouble() ?? 0.0,
      minAchievementPct: (json['min_achievement_pct'] as num?)?.toDouble() ?? 0.0,
      isPassed: json['is_passed'] == true || json['is_passed'] == 1,
      gradeId: (json['grade_id'] as num?)?.toInt(),
      gradeName: json['grade_name']?.toString(),
      multiplierRate: (json['multiplier_rate'] as num?)?.toDouble() ?? 0.0,
      headerWeightPct: (json['header_weight_pct'] as num?)?.toDouble() ?? 0.0,
      grossReward: (json['gross_reward'] as num?)?.toDouble() ?? 0.0,
      finalReward: (json['final_reward'] as num?)?.toDouble() ?? 0.0,
      auditNotes: json['audit_notes']?.toString(),
    );
  }
}

class IndustriCustomerTxModel {
  final int customerId;
  final String customerCode;
  final String customerName;
  final String? city;
  final String customerType;
  final double volumeKg;
  final double nominal;
  final int txCount;
  final bool isNoo;
  final String nooReason;

  IndustriCustomerTxModel({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.city,
    required this.customerType,
    required this.volumeKg,
    required this.nominal,
    required this.txCount,
    required this.isNoo,
    required this.nooReason,
  });

  factory IndustriCustomerTxModel.fromJson(Map<String, dynamic> json) {
    return IndustriCustomerTxModel(
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      customerCode: json['customer_code']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '-',
      city: json['city']?.toString(),
      customerType: json['customer_type']?.toString() ?? 'NEW',
      volumeKg: (json['volume_kg'] as num?)?.toDouble() ?? 0.0,
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
      txCount: (json['tx_count'] as num?)?.toInt() ?? 0,
      isNoo: json['is_noo'] == true || json['is_noo'] == 1,
      nooReason: json['noo_reason']?.toString() ?? '-',
    );
  }
}

class IndustriBreakdownCardModel {
  final int userId;
  final String userName;
  final String username;
  final int? positionId;
  final String positionCode;
  final String positionName;
  final bool isEligibleIndustri;
  final String period;
  final String? ineligibilityReason;
  final IndustriMethodBreakdownModel? sellIn;
  final IndustriMethodBreakdownModel? noo;
  final List<IndustriCustomerTxModel> customers;
  final int assignedCustomersCount;
  final double actualSellInKg;
  final int actualNooCount;
  final double actualNooKg;
  final double totalReward;

  IndustriBreakdownCardModel({
    required this.userId,
    required this.userName,
    required this.username,
    this.positionId,
    required this.positionCode,
    required this.positionName,
    required this.isEligibleIndustri,
    required this.period,
    this.ineligibilityReason,
    this.sellIn,
    this.noo,
    this.customers = const [],
    this.assignedCustomersCount = 0,
    this.actualSellInKg = 0.0,
    this.actualNooCount = 0,
    this.actualNooKg = 0.0,
    this.totalReward = 0.0,
  });

  factory IndustriBreakdownCardModel.fromJson(Map<String, dynamic> json) {
    final rawCustomers = json['customers'] as List? ?? [];
    return IndustriBreakdownCardModel(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      userName: json['user_name']?.toString() ?? '-',
      username: json['username']?.toString() ?? '',
      positionId: (json['position_id'] as num?)?.toInt(),
      positionCode: json['position_code']?.toString() ?? '',
      positionName: json['position_name']?.toString() ?? '-',
      isEligibleIndustri: json['is_eligible_industri'] == true || json['is_eligible_industri'] == 1,
      period: json['period']?.toString() ?? '',
      ineligibilityReason: json['ineligibility_reason']?.toString(),
      sellIn: json['sell_in'] != null
          ? IndustriMethodBreakdownModel.fromJson(json['sell_in'] as Map<String, dynamic>)
          : null,
      noo: json['noo'] != null
          ? IndustriMethodBreakdownModel.fromJson(json['noo'] as Map<String, dynamic>)
          : null,
      customers: rawCustomers
          .whereType<Map<String, dynamic>>()
          .map((c) => IndustriCustomerTxModel.fromJson(c))
          .toList(),
      assignedCustomersCount: (json['assigned_customers_count'] as num?)?.toInt() ?? rawCustomers.length,
      actualSellInKg: (json['actual_sell_in_kg'] as num?)?.toDouble() ?? 0.0,
      actualNooCount: (json['actual_noo_count'] as num?)?.toInt() ?? 0,
      actualNooKg: (json['actual_noo_kg'] as num?)?.toDouble() ?? 0.0,
      totalReward: (json['total_reward'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IndustriSummaryMeta {
  final int totalPersonil;
  final double totalTargetSellInKg;
  final double totalActualSellInKg;
  final double totalTargetNoo;
  final double totalActualNoo;
  final double totalActualNooKg;
  final double totalPayout;

  IndustriSummaryMeta({
    required this.totalPersonil,
    required this.totalTargetSellInKg,
    required this.totalActualSellInKg,
    required this.totalTargetNoo,
    required this.totalActualNoo,
    required this.totalActualNooKg,
    required this.totalPayout,
  });

  factory IndustriSummaryMeta.fromJson(Map<String, dynamic> json) {
    return IndustriSummaryMeta(
      totalPersonil: (json['total_personil'] as num?)?.toInt() ?? 0,
      totalTargetSellInKg: (json['total_target_sell_in_kg'] as num?)?.toDouble() ?? 0.0,
      totalActualSellInKg: (json['total_actual_sell_in_kg'] as num?)?.toDouble() ?? 0.0,
      totalTargetNoo: (json['total_target_noo'] as num?)?.toDouble() ?? 0.0,
      totalActualNoo: (json['total_actual_noo'] as num?)?.toDouble() ?? 0.0,
      totalActualNooKg: (json['total_actual_noo_kg'] as num?)?.toDouble() ?? 0.0,
      totalPayout: (json['total_payout'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SurabayaSubordinateModel {
  final int salesId;
  final String salesName;
  final String username;
  final String positionCode;
  final String positionName;
  final double targetKg;
  final double actualKg;
  final double achievementPercent;
  final bool isPassed;
  final String statusLabel;
  final String? gradeName;
  final double multiplierRate;
  final double headerWeightPct;
  final double contributionReward;
  final String? auditNotes;

  SurabayaSubordinateModel({
    required this.salesId,
    required this.salesName,
    required this.username,
    required this.positionCode,
    required this.positionName,
    required this.targetKg,
    required this.actualKg,
    required this.achievementPercent,
    required this.isPassed,
    required this.statusLabel,
    this.gradeName,
    required this.multiplierRate,
    required this.headerWeightPct,
    required this.contributionReward,
    this.auditNotes,
  });

  factory SurabayaSubordinateModel.fromJson(Map<String, dynamic> json) {
    return SurabayaSubordinateModel(
      salesId: (json['sales_id'] as num?)?.toInt() ?? 0,
      salesName: json['sales_name']?.toString() ?? '-',
      username: json['username']?.toString() ?? '',
      positionCode: json['position_code']?.toString() ?? '-',
      positionName: json['position_name']?.toString() ?? '-',
      targetKg: (json['target_kg'] as num?)?.toDouble() ?? 0.0,
      actualKg: (json['actual_kg'] as num?)?.toDouble() ?? 0.0,
      achievementPercent: (json['achievement_percent'] as num?)?.toDouble() ?? 0.0,
      isPassed: json['is_passed'] == true || json['is_passed'] == 1,
      statusLabel: json['status_label']?.toString() ?? '-',
      gradeName: json['grade_name']?.toString(),
      multiplierRate: (json['multiplier_rate'] as num?)?.toDouble() ?? 0.0,
      headerWeightPct: (json['header_weight_pct'] as num?)?.toDouble() ?? 100.0,
      contributionReward: (json['contribution_reward'] as num?)?.toDouble() ?? 0.0,
      auditNotes: json['audit_notes']?.toString(),
    );
  }
}

class SurabayaBreakdownCardModel {
  final int userId;
  final String userName;
  final String username;
  final int? positionId;
  final String positionCode;
  final String positionName;
  final bool isEligibleSurabaya;
  final String period;
  final String? ineligibilityReason;
  final String? ascName;
  final String? headerName;
  final double minAchievementPct;
  final double headerWeightPct;
  final double targetKg;
  final double actualKg;
  final double achievementPercent;
  final bool isPassed;
  final String? gradeName;
  final double multiplierRate;
  final double totalReward;
  final String? auditNotes;
  final List<SurabayaSubordinateModel> subordinates;
  final int subordinatesCount;

  SurabayaBreakdownCardModel({
    required this.userId,
    required this.userName,
    required this.username,
    this.positionId,
    required this.positionCode,
    required this.positionName,
    required this.isEligibleSurabaya,
    required this.period,
    this.ineligibilityReason,
    this.ascName,
    this.headerName,
    this.minAchievementPct = 0.0,
    this.headerWeightPct = 100.0,
    this.targetKg = 0.0,
    this.actualKg = 0.0,
    this.achievementPercent = 0.0,
    this.isPassed = false,
    this.gradeName,
    this.multiplierRate = 0.0,
    this.totalReward = 0.0,
    this.auditNotes,
    this.subordinates = const [],
    this.subordinatesCount = 0,
  });

  factory SurabayaBreakdownCardModel.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subordinates'] as List? ?? [];
    return SurabayaBreakdownCardModel(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      userName: json['user_name']?.toString() ?? '-',
      username: json['username']?.toString() ?? '',
      positionId: (json['position_id'] as num?)?.toInt(),
      positionCode: json['position_code']?.toString() ?? '',
      positionName: json['position_name']?.toString() ?? '-',
      isEligibleSurabaya: json['is_eligible_surabaya'] == true || json['is_eligible_surabaya'] == 1,
      period: json['period']?.toString() ?? '',
      ineligibilityReason: json['ineligibility_reason']?.toString(),
      ascName: json['asc_name']?.toString(),
      headerName: json['header_name']?.toString(),
      minAchievementPct: (json['min_achievement_pct'] as num?)?.toDouble() ?? 0.0,
      headerWeightPct: (json['header_weight_pct'] as num?)?.toDouble() ?? 100.0,
      targetKg: (json['target_kg'] as num?)?.toDouble() ?? 0.0,
      actualKg: (json['actual_kg'] as num?)?.toDouble() ?? 0.0,
      achievementPercent: (json['achievement_percent'] as num?)?.toDouble() ?? 0.0,
      isPassed: json['is_passed'] == true || json['is_passed'] == 1,
      gradeName: json['grade_name']?.toString(),
      multiplierRate: (json['multiplier_rate'] as num?)?.toDouble() ?? 0.0,
      totalReward: (json['total_reward'] as num?)?.toDouble() ?? 0.0,
      auditNotes: json['audit_notes']?.toString(),
      subordinates: rawSubs
          .whereType<Map<String, dynamic>>()
          .map((s) => SurabayaSubordinateModel.fromJson(s))
          .toList(),
      subordinatesCount: (json['subordinates_count'] as num?)?.toInt() ?? rawSubs.length,
    );
  }
}

class SurabayaSummaryMeta {
  final int totalPersonil;
  final double totalTargetKg;
  final double totalActualKg;
  final double totalPayout;

  SurabayaSummaryMeta({
    required this.totalPersonil,
    required this.totalTargetKg,
    required this.totalActualKg,
    required this.totalPayout,
  });

  factory SurabayaSummaryMeta.fromJson(Map<String, dynamic> json) {
    return SurabayaSummaryMeta(
      totalPersonil: (json['total_personil'] as num?)?.toInt() ?? 0,
      totalTargetKg: (json['total_target_kg'] as num?)?.toDouble() ?? 0.0,
      totalActualKg: (json['total_actual_kg'] as num?)?.toDouble() ?? 0.0,
      totalPayout: (json['total_payout'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

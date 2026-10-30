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

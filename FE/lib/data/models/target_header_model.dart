class TargetHeaderModel {
  final int id;
  final String nama;
  final String salesType; // e.g. ASM, SPV, Coordinator, atau '1', '2'
  final String? salesTypeName;
  final String type; // Sell-In, Sell-Out, Active Outlet (AO)
  final double bobot; // 100.00%
  final bool aktif;
  final String aktifFrom; // YYYYMMDD
  final String aktifTo; // YYYYMMDD
  final String? kategoriSkema; // KONSUMSI, INDUSTRI, SURABAYA
  final List<GradeModel> grades;

  TargetHeaderModel({
    required this.id,
    required this.nama,
    required this.salesType,
    this.salesTypeName,
    required this.type,
    required this.bobot,
    required this.aktif,
    required this.aktifFrom,
    required this.aktifTo,
    this.kategoriSkema,
    this.grades = const [],
  });

  String get formattedAktifFrom {
    final s = aktifFrom.replaceAll('-', '');
    if (s.length >= 8) {
      return '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}';
    }
    return aktifFrom;
  }

  String get formattedAktifTo {
    final s = aktifTo.replaceAll('-', '');
    if (s.length >= 8) {
      return '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}';
    }
    return aktifTo;
  }

  String get displayAktifFrom {
    final s = aktifFrom.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.length >= 8) {
      return '${s.substring(6, 8)}/${s.substring(4, 6)}/${s.substring(0, 4)}';
    }
    return aktifFrom;
  }

  String get displayAktifTo {
    final s = aktifTo.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.length >= 8) {
      return '${s.substring(6, 8)}/${s.substring(4, 6)}/${s.substring(0, 4)}';
    }
    return aktifTo;
  }

  String get displaySalesType {
    if (salesTypeName != null && salesTypeName!.isNotEmpty) {
      return salesTypeName!;
    }
    return salesType;
  }

  factory TargetHeaderModel.fromJson(Map<String, dynamic> json) {
    var gList = json['grades'] as List? ?? [];
    return TargetHeaderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      nama: json['nama'] ?? json['name'] ?? '',
      salesType: json['sales_type']?.toString() ?? '1',
      salesTypeName: json['position'] != null && json['position']['name'] != null
          ? '${json['position']['name']} (${json['position']['code'] ?? ''})'
          : null,
      type: json['type'] ?? 'Sell-In',
      bobot: double.tryParse(json['bobot']?.toString() ?? json['bobot_percent']?.toString() ?? '100') ?? 100.0,
      aktif: json['aktif'] == true || json['aktif'] == 1 || json['aktif'] == '1',
      aktifFrom: json['aktif_from']?.toString() ?? '',
      aktifTo: json['aktif_to']?.toString() ?? '',
      kategoriSkema: json['kategori_skema'] ?? (json['type']?.toString().toUpperCase() ?? 'KONSUMSI'),
      grades: gList.map((g) => GradeModel.fromJson(g as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'sales_type': salesType,
    'type': type,
    'bobot': bobot,
    'aktif': aktif,
    'aktif_from': aktifFrom,
    'aktif_to': aktifTo,
    'kategori_skema': kategoriSkema,
    'grades': grades.map((g) => g.toJson()).toList(),
  };
}

class GradeModel {
  final int id;
  final int? targetHeaderId;
  final String idGrade; // UUID or string ID
  final String gradeName;
  final double targetFrom; // Kg / Unit
  final double targetTo;
  final List<GradeBobotModel> gradeBobots;

  GradeModel({
    required this.id,
    this.targetHeaderId,
    required this.idGrade,
    required this.gradeName,
    required this.targetFrom,
    required this.targetTo,
    this.gradeBobots = const [],
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    var gbList = json['bobots'] as List? ?? json['grade_bobots'] as List? ?? json['percent_targets'] as List? ?? [];
    return GradeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      targetHeaderId: json['target_header_id'] != null ? int.tryParse(json['target_header_id'].toString()) : null,
      idGrade: json['id_grade']?.toString() ?? json['id']?.toString() ?? '',
      gradeName: json['grade_name'] ?? json['name'] ?? '',
      targetFrom: double.tryParse(json['target_from']?.toString() ?? '0') ?? 0.0,
      targetTo: double.tryParse(json['target_to']?.toString() ?? '0') ?? 0.0,
      gradeBobots: gbList.map((gb) => GradeBobotModel.fromJson(gb as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target_header_id': targetHeaderId,
    'id_grade': idGrade,
    'grade_name': gradeName,
    'target_from': targetFrom,
    'target_to': targetTo,
    'bobots': gradeBobots.map((b) => b.toJson()).toList(),
  };
}

class GradeBobotModel {
  final int id;
  final String idGrade;
  final String bobotName;
  final double percentFrom;
  final double percentTo;
  final bool pengali; // true = Rate-based (per unit), false = Lump Sum
  final double bobot; // Nilai pengali per unit realisasi jika pengali = true (Rp)
  final double nominal; // Nilai flat jika pengali = false (Rp)

  GradeBobotModel({
    required this.id,
    required this.idGrade,
    required this.bobotName,
    required this.percentFrom,
    required this.percentTo,
    required this.pengali,
    required this.bobot,
    required this.nominal,
  });

  factory GradeBobotModel.fromJson(Map<String, dynamic> json) {
    return GradeBobotModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      idGrade: json['id_grade']?.toString() ?? json['grade_id']?.toString() ?? '',
      bobotName: json['bobot_name'] ?? json['name'] ?? '',
      percentFrom: double.tryParse(json['percent_from']?.toString() ?? json['min_percent']?.toString() ?? '0') ?? 0.0,
      percentTo: double.tryParse(json['percent_to']?.toString() ?? json['max_percent']?.toString() ?? '0') ?? 0.0,
      pengali: json['pengali'] == true || json['pengali'] == 1 || json['pengali'] == '1' || json['is_rate_based'] == true,
      bobot: double.tryParse(json['bobot']?.toString() ?? json['rate_per_unit']?.toString() ?? '0') ?? 0.0,
      nominal: double.tryParse(json['nominal']?.toString() ?? json['lump_sum_nominal']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'id_grade': idGrade,
    'bobot_name': bobotName,
    'percent_from': percentFrom,
    'percent_to': percentTo,
    'pengali': pengali,
    'bobot': bobot,
    'nominal': nominal,
  };
}

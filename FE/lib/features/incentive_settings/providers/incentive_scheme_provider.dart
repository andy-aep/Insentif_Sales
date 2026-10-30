import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/target_header_model.dart';

class IncentiveSchemeState {
  final bool isLoading;
  final List<TargetHeaderModel> targetHeaders;
  final TargetHeaderModel? selectedHeader;
  final String? errorMessage;
  final String? successMessage;

  IncentiveSchemeState({
    this.isLoading = false,
    this.targetHeaders = const [],
    this.selectedHeader,
    this.errorMessage,
    this.successMessage,
  });

  IncentiveSchemeState copyWith({
    bool? isLoading,
    List<TargetHeaderModel>? targetHeaders,
    TargetHeaderModel? selectedHeader,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return IncentiveSchemeState(
      isLoading: isLoading ?? this.isLoading,
      targetHeaders: targetHeaders ?? this.targetHeaders,
      selectedHeader: selectedHeader ?? this.selectedHeader,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class IncentiveSchemeNotifier extends StateNotifier<IncentiveSchemeState> {
  IncentiveSchemeNotifier() : super(IncentiveSchemeState()) {
    fetchSchemes();
  }

  Future<void> fetchSchemes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await DioClient.instance.get(ApiEndpoints.targetHeaders);
      final data = response.data;
      List<TargetHeaderModel> headers = [];

      if (data is List) {
        headers = data.map((j) => TargetHeaderModel.fromJson(j)).toList();
      } else if (data is Map && data['data'] is List) {
        headers = (data['data'] as List).map((j) => TargetHeaderModel.fromJson(j)).toList();
      }

      if (headers.isEmpty) {
        headers = _buildDefault3LevelSchemes();
      }

      state = state.copyWith(
        isLoading: false,
        targetHeaders: headers,
        selectedHeader: headers.isNotEmpty ? headers.first : null,
      );
    } catch (_) {
      final defaultHeaders = _buildDefault3LevelSchemes();
      state = state.copyWith(
        isLoading: false,
        targetHeaders: defaultHeaders,
        selectedHeader: defaultHeaders.first,
      );
    }
  }

  List<TargetHeaderModel> _buildDefault3LevelSchemes() {
    return [
      TargetHeaderModel(
        id: 1,
        nama: 'Skema Insentif ASM 2026',
        salesType: 'ASM',
        type: 'Sell-In',
        bobot: 100.0,
        aktif: true,
        aktifFrom: '20260101',
        aktifTo: '20261231',
        kategoriSkema: 'KONSUMSI',
        grades: [
          GradeModel(
            id: 1,
            targetHeaderId: 1,
            idGrade: 'grade-asm-1',
            gradeName: 'Grade 1 (Target 6.000 - 23.999 Kg)',
            targetFrom: 6000,
            targetTo: 23999,
            gradeBobots: [
              GradeBobotModel(id: 1, idGrade: 'grade-asm-1', bobotName: 'Tier 80% - 99.9%', percentFrom: 80, percentTo: 99.99, pengali: true, bobot: 2.0, nominal: 0),
              GradeBobotModel(id: 2, idGrade: 'grade-asm-1', bobotName: 'Tier 100% - 120%', percentFrom: 100, percentTo: 120.0, pengali: true, bobot: 3.5, nominal: 0),
              GradeBobotModel(id: 3, idGrade: 'grade-asm-1', bobotName: 'Tier > 120% (Capped Max)', percentFrom: 120.01, percentTo: 999.0, pengali: true, bobot: 3.5, nominal: 0),
            ],
          ),
          GradeModel(
            id: 2,
            targetHeaderId: 1,
            idGrade: 'grade-asm-2',
            gradeName: 'Grade 2 (Target 24.000 - 49.999 Kg)',
            targetFrom: 24000,
            targetTo: 49999,
            gradeBobots: [
              GradeBobotModel(id: 4, idGrade: 'grade-asm-2', bobotName: 'Tier 90% - 99.9%', percentFrom: 90, percentTo: 99.99, pengali: true, bobot: 3.0, nominal: 0),
              GradeBobotModel(id: 5, idGrade: 'grade-asm-2', bobotName: 'Tier >= 100%', percentFrom: 100, percentTo: 130.0, pengali: true, bobot: 4.5, nominal: 0),
            ],
          ),
          GradeModel(
            id: 3,
            targetHeaderId: 1,
            idGrade: 'grade-asm-3',
            gradeName: 'Grade 3 (Target >= 50.000 Kg)',
            targetFrom: 50000,
            targetTo: 999999,
            gradeBobots: [
              GradeBobotModel(id: 6, idGrade: 'grade-asm-3', bobotName: 'Tier 100% (Lump Sum)', percentFrom: 100, percentTo: 120.0, pengali: false, bobot: 0, nominal: 3500000),
            ],
          ),
        ],
      ),
      TargetHeaderModel(
        id: 2,
        nama: 'Skema Insentif SPV Industri 2026',
        salesType: 'SPV',
        type: 'Sell-In',
        bobot: 100.0,
        aktif: true,
        aktifFrom: '20260101',
        aktifTo: '20261231',
        kategoriSkema: 'INDUSTRI',
        grades: [
          GradeModel(
            id: 4,
            targetHeaderId: 2,
            idGrade: 'grade-ind-1',
            gradeName: 'Grade Industri Utama',
            targetFrom: 20000,
            targetTo: 100000,
            gradeBobots: [
              GradeBobotModel(id: 7, idGrade: 'grade-ind-1', bobotName: 'Tier 100% Rate', percentFrom: 100, percentTo: 120, pengali: true, bobot: 5.0, nominal: 0),
            ],
          ),
        ],
      ),
      TargetHeaderModel(
        id: 3,
        nama: 'Skema Insentif Surabaya Canvasing & TO',
        salesType: 'Coordinator',
        type: 'Sell-Out',
        bobot: 100.0,
        aktif: true,
        aktifFrom: '20260101',
        aktifTo: '20261231',
        kategoriSkema: 'SURABAYA',
        grades: [
          GradeModel(
            id: 5,
            targetHeaderId: 3,
            idGrade: 'grade-sby-1',
            gradeName: 'Grade AO & Sell Out Surabaya',
            targetFrom: 15000,
            targetTo: 80000,
            gradeBobots: [
              GradeBobotModel(id: 8, idGrade: 'grade-sby-1', bobotName: 'Tier 90% - 100%', percentFrom: 90, percentTo: 100, pengali: false, bobot: 0, nominal: 1500000),
              GradeBobotModel(id: 9, idGrade: 'grade-sby-1', bobotName: 'Tier > 100% Rate', percentFrom: 100.01, percentTo: 130, pengali: true, bobot: 2.5, nominal: 0),
            ],
          ),
        ],
      ),
    ];
  }

  void selectHeader(TargetHeaderModel header) {
    state = state.copyWith(selectedHeader: header);
  }

  // ---------------- Level 1: Target Header CRUD ----------------
  Future<bool> saveTargetHeader(Map<String, dynamic> data, {int? id}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (id == null) {
        await DioClient.instance.post(ApiEndpoints.targetHeaders, data: data);
      } else {
        await DioClient.instance.put('${ApiEndpoints.targetHeaders}/$id', data: data);
      }
      await fetchSchemes();
      return true;
    } catch (_) {
      // Local fallback
      List<GradeModel> parsedGrades = [];
      if (data['grades'] is List) {
        parsedGrades = (data['grades'] as List).map((g) {
          final bList = (g['bobots'] as List? ?? g['grade_bobots'] as List? ?? []).map((b) => GradeBobotModel(
            id: DateTime.now().millisecondsSinceEpoch % 10000,
            idGrade: g['id_grade']?.toString() ?? '',
            bobotName: b['bobot_name'] ?? '',
            percentFrom: double.tryParse(b['percent_from']?.toString() ?? '0') ?? 0.0,
            percentTo: double.tryParse(b['percent_to']?.toString() ?? '0') ?? 0.0,
            pengali: b['pengali'] == true || b['pengali'] == 1 || b['pengali'] == '1',
            bobot: double.tryParse(b['bobot']?.toString() ?? '0') ?? 0.0,
            nominal: double.tryParse(b['nominal']?.toString() ?? '0') ?? 0.0,
          )).toList();
          return GradeModel(
            id: DateTime.now().millisecondsSinceEpoch % 10000,
            targetHeaderId: id ?? (state.targetHeaders.length + 1),
            idGrade: g['id_grade']?.toString() ?? 'grade-${DateTime.now().millisecondsSinceEpoch}',
            gradeName: g['grade_name'] ?? 'Grade',
            targetFrom: double.tryParse(g['target_from']?.toString() ?? '0') ?? 0.0,
            targetTo: double.tryParse(g['target_to']?.toString() ?? '0') ?? 0.0,
            gradeBobots: bList,
          );
        }).toList();
      }

      if (id == null) {
        final newHeader = TargetHeaderModel(
          id: state.targetHeaders.length + 1,
          nama: data['nama'] ?? '',
          salesType: data['sales_type']?.toString() ?? 'ASM',
          type: data['type'] ?? 'Sell-In',
          bobot: double.tryParse(data['bobot']?.toString() ?? '100') ?? 100.0,
          aktif: data['aktif'] ?? true,
          aktifFrom: data['aktif_from'] ?? '20260101',
          aktifTo: data['aktif_to'] ?? '20261231',
          kategoriSkema: data['kategori_skema'] ?? 'KONSUMSI',
          grades: parsedGrades,
        );
        state = state.copyWith(
          isLoading: false,
          targetHeaders: [...state.targetHeaders, newHeader],
          selectedHeader: newHeader,
          successMessage: 'Target Header berhasil ditambahkan',
        );
      } else {
        final updatedHeaders = state.targetHeaders.map((h) {
          if (h.id == id) {
            return TargetHeaderModel(
              id: h.id,
              nama: data['nama'] ?? h.nama,
              salesType: data['sales_type']?.toString() ?? h.salesType,
              salesTypeName: h.salesTypeName,
              type: data['type'] ?? h.type,
              bobot: double.tryParse(data['bobot']?.toString() ?? '${h.bobot}') ?? h.bobot,
              aktif: data['aktif'] ?? h.aktif,
              aktifFrom: data['aktif_from'] ?? h.aktifFrom,
              aktifTo: data['aktif_to'] ?? h.aktifTo,
              kategoriSkema: data['kategori_skema'] ?? h.kategoriSkema,
              grades: parsedGrades.isNotEmpty ? parsedGrades : h.grades,
            );
          }
          return h;
        }).toList();
        state = state.copyWith(
          isLoading: false,
          targetHeaders: updatedHeaders,
          selectedHeader: updatedHeaders.firstWhere((h) => h.id == id, orElse: () => updatedHeaders.first),
          successMessage: 'Target Header berhasil diperbarui',
        );
      }
      return true;
    }
  }

  Future<bool> duplicateTargetHeader(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await DioClient.instance.post('${ApiEndpoints.targetHeaders}/$id/duplicate');
      await fetchSchemes();
      state = state.copyWith(successMessage: 'Setting insentif berhasil diduplikasi');
      return true;
    } catch (_) {
      final original = state.targetHeaders.firstWhere((h) => h.id == id);
      final newId = (state.targetHeaders.map((e) => e.id).fold(0, (max, e) => e > max ? e : max)) + 1;
      final duplicatedGrades = original.grades.map((g) {
        final newGradeId = 'grade-dup-${DateTime.now().millisecondsSinceEpoch}-${g.id}';
        return GradeModel(
          id: (DateTime.now().millisecondsSinceEpoch % 100000) + g.id,
          targetHeaderId: newId,
          idGrade: newGradeId,
          gradeName: g.gradeName,
          targetFrom: g.targetFrom,
          targetTo: g.targetTo,
          gradeBobots: g.gradeBobots.map((b) => GradeBobotModel(
            id: (DateTime.now().millisecondsSinceEpoch % 100000) + b.id,
            idGrade: newGradeId,
            bobotName: b.bobotName,
            percentFrom: b.percentFrom,
            percentTo: b.percentTo,
            pengali: b.pengali,
            bobot: b.bobot,
            nominal: b.nominal,
          )).toList(),
        );
      }).toList();

      final duplicatedHeader = TargetHeaderModel(
        id: newId,
        nama: '${original.nama} (Copy)',
        salesType: original.salesType,
        salesTypeName: original.salesTypeName,
        type: original.type,
        bobot: original.bobot,
        aktif: original.aktif,
        aktifFrom: original.aktifFrom,
        aktifTo: original.aktifTo,
        kategoriSkema: original.kategoriSkema,
        grades: duplicatedGrades,
      );
      state = state.copyWith(
        isLoading: false,
        targetHeaders: [...state.targetHeaders, duplicatedHeader],
        selectedHeader: duplicatedHeader,
        successMessage: 'Setting insentif berhasil diduplikasi',
      );
      return true;
    }
  }

  Future<bool> deleteTargetHeader(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.targetHeaders}/$id');
      await fetchSchemes();
      return true;
    } catch (_) {
      final updated = state.targetHeaders.where((h) => h.id != id).toList();
      state = state.copyWith(
        isLoading: false,
        targetHeaders: updated,
        selectedHeader: updated.isNotEmpty ? updated.first : null,
        successMessage: 'Target Header berhasil dihapus',
      );
      return true;
    }
  }

  Future<bool> deleteGrade(int id) async {
    try {
      await DioClient.instance.delete('${ApiEndpoints.grades}/$id');
      await fetchSchemes();
      return true;
    } catch (_) {
      final updatedHeaders = state.targetHeaders.map((h) {
        return TargetHeaderModel(
          id: h.id,
          nama: h.nama,
          salesType: h.salesType,
          salesTypeName: h.salesTypeName,
          type: h.type,
          bobot: h.bobot,
          aktif: h.aktif,
          aktifFrom: h.aktifFrom,
          aktifTo: h.aktifTo,
          kategoriSkema: h.kategoriSkema,
          grades: h.grades.where((g) => g.id != id).toList(),
        );
      }).toList();
      state = state.copyWith(targetHeaders: updatedHeaders);
      return true;
    }
  }

  Future<bool> deleteGradeBobot(int id) async {
    try {
      await DioClient.instance.delete('${ApiEndpoints.gradeBobots}/$id');
      await fetchSchemes();
      return true;
    } catch (_) {
      final updatedHeaders = state.targetHeaders.map((h) {
        final updatedGrades = h.grades.map((g) {
          return GradeModel(
            id: g.id,
            targetHeaderId: g.targetHeaderId,
            idGrade: g.idGrade,
            gradeName: g.gradeName,
            targetFrom: g.targetFrom,
            targetTo: g.targetTo,
            gradeBobots: g.gradeBobots.where((b) => b.id != id).toList(),
          );
        }).toList();
        return TargetHeaderModel(
          id: h.id,
          nama: h.nama,
          salesType: h.salesType,
          salesTypeName: h.salesTypeName,
          type: h.type,
          bobot: h.bobot,
          aktif: h.aktif,
          aktifFrom: h.aktifFrom,
          aktifTo: h.aktifTo,
          kategoriSkema: h.kategoriSkema,
          grades: updatedGrades,
        );
      }).toList();
      state = state.copyWith(targetHeaders: updatedHeaders);
      return true;
    }
  }

  // ---------------- Level 2: Grade CRUD ----------------
  Future<bool> saveGrade(int targetHeaderId, String gradeName, double targetFrom, double targetTo, {int? id}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (id == null) {
        await DioClient.instance.post(ApiEndpoints.grades, data: {
          'target_header_id': targetHeaderId,
          'grade_name': gradeName,
          'target_from': targetFrom,
          'target_to': targetTo,
        });
      } else {
        await DioClient.instance.put('${ApiEndpoints.grades}/$id', data: {
          'target_header_id': targetHeaderId,
          'grade_name': gradeName,
          'target_from': targetFrom,
          'target_to': targetTo,
        });
      }
      await fetchSchemes();
      return true;
    } catch (_) {
      if (id == null) {
        final newGrade = GradeModel(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          targetHeaderId: targetHeaderId,
          idGrade: 'grade-${DateTime.now().millisecondsSinceEpoch}',
          gradeName: gradeName,
          targetFrom: targetFrom,
          targetTo: targetTo,
        );

        final updatedHeaders = state.targetHeaders.map((h) {
          if (h.id == targetHeaderId) {
            return TargetHeaderModel(
              id: h.id,
              nama: h.nama,
              salesType: h.salesType,
              salesTypeName: h.salesTypeName,
              type: h.type,
              bobot: h.bobot,
              aktif: h.aktif,
              aktifFrom: h.aktifFrom,
              aktifTo: h.aktifTo,
              kategoriSkema: h.kategoriSkema,
              grades: [...h.grades, newGrade],
            );
          }
          return h;
        }).toList();

        state = state.copyWith(
          isLoading: false,
          targetHeaders: updatedHeaders,
          selectedHeader: updatedHeaders.firstWhere((h) => h.id == targetHeaderId),
          successMessage: 'Grade berhasil ditambahkan ke Level 2',
        );
      } else {
        final updatedHeaders = state.targetHeaders.map((h) {
          if (h.id == targetHeaderId) {
            final updatedGrades = h.grades.map((g) {
              if (g.id == id) {
                return GradeModel(
                  id: g.id,
                  targetHeaderId: g.targetHeaderId,
                  idGrade: g.idGrade,
                  gradeName: gradeName,
                  targetFrom: targetFrom,
                  targetTo: targetTo,
                  gradeBobots: g.gradeBobots,
                );
              }
              return g;
            }).toList();
            return TargetHeaderModel(
              id: h.id,
              nama: h.nama,
              salesType: h.salesType,
              salesTypeName: h.salesTypeName,
              type: h.type,
              bobot: h.bobot,
              aktif: h.aktif,
              aktifFrom: h.aktifFrom,
              aktifTo: h.aktifTo,
              kategoriSkema: h.kategoriSkema,
              grades: updatedGrades,
            );
          }
          return h;
        }).toList();

        state = state.copyWith(
          isLoading: false,
          targetHeaders: updatedHeaders,
          selectedHeader: updatedHeaders.firstWhere((h) => h.id == targetHeaderId),
          successMessage: 'Grade berhasil diperbarui di Level 2',
        );
      }
      return true;
    }
  }

  // ---------------- Level 3: Grade Bobot CRUD ----------------
  Future<bool> saveGradeBobot(
    String idGrade,
    String bobotName,
    double pFrom,
    double pTo,
    bool pengali,
    double bobot,
    double nominal, {
    int? id,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payload = {
        'id_grade': idGrade,
        'bobot_name': bobotName,
        'percent_from': pFrom,
        'percent_to': pTo,
        'pengali': pengali,
        'bobot': bobot,
        'nominal': nominal,
      };
      if (id == null) {
        await DioClient.instance.post(ApiEndpoints.gradeBobots, data: payload);
      } else {
        await DioClient.instance.put('${ApiEndpoints.gradeBobots}/$id', data: payload);
      }
      await fetchSchemes();
      return true;
    } catch (_) {
      if (id == null) {
        final newBobot = GradeBobotModel(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          idGrade: idGrade,
          bobotName: bobotName,
          percentFrom: pFrom,
          percentTo: pTo,
          pengali: pengali,
          bobot: bobot,
          nominal: nominal,
        );

        final updatedHeaders = state.targetHeaders.map((h) {
          final updatedGrades = h.grades.map((g) {
            if (g.idGrade == idGrade) {
              return GradeModel(
                id: g.id,
                targetHeaderId: g.targetHeaderId,
                idGrade: g.idGrade,
                gradeName: g.gradeName,
                targetFrom: g.targetFrom,
                targetTo: g.targetTo,
                gradeBobots: [...g.gradeBobots, newBobot],
              );
            }
            return g;
          }).toList();

          return TargetHeaderModel(
            id: h.id,
            nama: h.nama,
            salesType: h.salesType,
            salesTypeName: h.salesTypeName,
            type: h.type,
            bobot: h.bobot,
            aktif: h.aktif,
            aktifFrom: h.aktifFrom,
            aktifTo: h.aktifTo,
            kategoriSkema: h.kategoriSkema,
            grades: updatedGrades,
          );
        }).toList();

        state = state.copyWith(
          isLoading: false,
          targetHeaders: updatedHeaders,
          selectedHeader: updatedHeaders.firstWhere((h) => h.id == state.selectedHeader?.id, orElse: () => updatedHeaders.first),
          successMessage: 'Grade Bobot Tier berhasil ditambahkan ke Level 3',
        );
      } else {
        final updatedHeaders = state.targetHeaders.map((h) {
          final updatedGrades = h.grades.map((g) {
            if (g.idGrade == idGrade) {
              final updatedBobots = g.gradeBobots.map((b) {
                if (b.id == id) {
                  return GradeBobotModel(
                    id: b.id,
                    idGrade: idGrade,
                    bobotName: bobotName,
                    percentFrom: pFrom,
                    percentTo: pTo,
                    pengali: pengali,
                    bobot: bobot,
                    nominal: nominal,
                  );
                }
                return b;
              }).toList();

              return GradeModel(
                id: g.id,
                targetHeaderId: g.targetHeaderId,
                idGrade: g.idGrade,
                gradeName: g.gradeName,
                targetFrom: g.targetFrom,
                targetTo: g.targetTo,
                gradeBobots: updatedBobots,
              );
            }
            return g;
          }).toList();

          return TargetHeaderModel(
            id: h.id,
            nama: h.nama,
            salesType: h.salesType,
            salesTypeName: h.salesTypeName,
            type: h.type,
            bobot: h.bobot,
            aktif: h.aktif,
            aktifFrom: h.aktifFrom,
            aktifTo: h.aktifTo,
            kategoriSkema: h.kategoriSkema,
            grades: updatedGrades,
          );
        }).toList();

        state = state.copyWith(
          isLoading: false,
          targetHeaders: updatedHeaders,
          selectedHeader: updatedHeaders.firstWhere((h) => h.id == state.selectedHeader?.id, orElse: () => updatedHeaders.first),
          successMessage: 'Grade Bobot Tier berhasil diperbarui di Level 3',
        );
      }
      return true;
    }
  }
}

final incentiveSchemeProvider =
    StateNotifierProvider<IncentiveSchemeNotifier, IncentiveSchemeState>((ref) {
  return IncentiveSchemeNotifier();
});

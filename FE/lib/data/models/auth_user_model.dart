class UserModel {
  final int id;
  final String name;
  final String username;
  final String? email;
  final int roleId;
  final int? positionId;
  final String aktifFrom;
  final String? aktifTo;
  final bool isEligibleKonsumsi;
  final bool isEligibleIndustri;
  final bool isEligibleSurabaya;
  final RoleModel? role;
  final PositionModel? position;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    required this.roleId,
    this.positionId,
    required this.aktifFrom,
    this.aktifTo,
    required this.isEligibleKonsumsi,
    required this.isEligibleIndustri,
    required this.isEligibleSurabaya,
    this.role,
    this.position,
  });

  static String _formatDate(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim();
    if (s.contains('T')) {
      return s.split('T').first;
    }
    if (s.length > 10) {
      return s.substring(0, 10);
    }
    return s;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      roleId: json['role_id'] is int ? json['role_id'] : int.tryParse(json['role_id'].toString()) ?? 0,
      positionId: json['position_id'] != null ? int.tryParse(json['position_id'].toString()) : null,
      aktifFrom: _formatDate(json['aktif_from']),
      aktifTo: json['aktif_to'] != null && json['aktif_to'].toString().isNotEmpty
          ? _formatDate(json['aktif_to'])
          : null,
      isEligibleKonsumsi: json['is_eligible_konsumsi'] == true || json['is_eligible_konsumsi'] == 1 || json['is_eligible_konsumsi'] == '1',
      isEligibleIndustri: json['is_eligible_industri'] == true || json['is_eligible_industri'] == 1 || json['is_eligible_industri'] == '1',
      isEligibleSurabaya: json['is_eligible_surabaya'] == true || json['is_eligible_surabaya'] == 1 || json['is_eligible_surabaya'] == '1',
      role: json['role'] != null ? RoleModel.fromJson(json['role']) : null,
      position: json['position'] != null ? PositionModel.fromJson(json['position']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'role_id': roleId,
      'position_id': positionId,
      'aktif_from': aktifFrom,
      'aktif_to': aktifTo,
      'is_eligible_konsumsi': isEligibleKonsumsi,
      'is_eligible_industri': isEligibleIndustri,
      'is_eligible_surabaya': isEligibleSurabaya,
      'role': role?.toJson(),
      'position': position?.toJson(),
    };
  }
}

class RoleModel {
  final int id;
  final String name;
  final String displayName;
  final String? description;
  final List<RoleMenuPermissionModel> menuPermissions;

  RoleModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.menuPermissions = const [],
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    var permList = json['menu_permissions'] as List? ?? [];
    return RoleModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description']?.toString(),
      menuPermissions: permList.map((p) => RoleMenuPermissionModel.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  RoleModel copyWith({
    int? id,
    String? name,
    String? displayName,
    String? description,
    List<RoleMenuPermissionModel>? menuPermissions,
  }) {
    return RoleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      menuPermissions: menuPermissions ?? this.menuPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'menu_permissions': menuPermissions.map((p) => p.toJson()).toList(),
    };
  }
}

class RoleMenuPermissionModel {
  final int menuId;
  final bool canView;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;
  final MenuModel? menu;

  RoleMenuPermissionModel({
    required this.menuId,
    required this.canView,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
    this.menu,
  });

  factory RoleMenuPermissionModel.fromJson(Map<String, dynamic> json) {
    return RoleMenuPermissionModel(
      menuId: json['menu_id'] is int ? json['menu_id'] : int.tryParse(json['menu_id'].toString()) ?? 0,
      canView: json['can_view'] == true || json['can_view'] == 1 || json['can_view'] == '1',
      canCreate: json['can_create'] == true || json['can_create'] == 1 || json['can_create'] == '1',
      canUpdate: json['can_update'] == true || json['can_update'] == 1 || json['can_update'] == '1',
      canDelete: json['can_delete'] == true || json['can_delete'] == 1 || json['can_delete'] == '1',
      menu: json['menu'] != null ? MenuModel.fromJson(json['menu'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      'can_view': canView,
      'can_create': canCreate,
      'can_update': canUpdate,
      'can_delete': canDelete,
      'menu': menu?.toJson(),
    };
  }
}

class MenuModel {
  final int id;
  final String name;
  final String? route;
  final String? icon;
  final int order;

  MenuModel({
    required this.id,
    required this.name,
    this.route,
    this.icon,
    required this.order,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      route: json['route'],
      icon: json['icon'],
      order: json['order'] is int ? json['order'] : int.tryParse(json['order'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'route': route,
      'icon': icon,
      'order': order,
    };
  }
}

class PositionModel {
  final int id;
  final String name;
  final String code;

  PositionModel({required this.id, required this.name, required this.code});

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    return PositionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
}

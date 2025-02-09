class PermissionStatus {
  final String status;
  final List<String> grantedPermissions;
  final List<String> deniedPermissions;
  final String? errorMessage;

  PermissionStatus({
    required this.status,
    required this.grantedPermissions,
    required this.deniedPermissions,
    this.errorMessage,
  });

  factory PermissionStatus.fromMap(Map<String, dynamic> map) {
    return PermissionStatus(
      status: map['status'] as String,
      grantedPermissions: List<String>.from(map['grantedPermissions']),
      deniedPermissions: List<String>.from(map['deniedPermissions']),
      errorMessage: map['errorMessage'] as String?,
    );
  }

  bool get isGranted => status == 'All permissions granted' || status == 'Permissions granted';
  bool get isDenied => !isGranted;
  bool get hasError => status == 'Error';

  @override
  String toString() {
    return 'PermissionStatus{status: $status, grantedPermissions: $grantedPermissions, deniedPermissions: $deniedPermissions, errorMessage: $errorMessage}';
  }
}
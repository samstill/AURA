/// Project Aura - Flow Challenge Models
/// =====================================
/// Data models for Authentik Flows API responses.

/// Component types returned by Authentik
enum FlowComponentType {
  identification('ak-stage-identification'),
  password('ak-stage-password'),
  authenticatorTotp('ak-stage-authenticator-totp'),
  authenticatorWebauthn('ak-stage-authenticator-webauthn'),
  authenticatorValidate('ak-stage-authenticator-validate'),
  accessDenied('ak-stage-access-denied'),
  redirect('xak-flow-redirect'),
  shell('ak-flow-shell-loading'),
  unknown('unknown');

  final String value;
  const FlowComponentType(this.value);

  static FlowComponentType fromString(String? value) {
    if (value == null) return FlowComponentType.unknown;
    return FlowComponentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FlowComponentType.unknown,
    );
  }
}

/// Base class for flow challenges
class FlowChallenge {
  final FlowComponentType component;
  final String? flowInfo;
  final String? pendingUser;
  final String? pendingUserAvatar;
  final Map<String, dynamic> rawData;

  FlowChallenge({
    required this.component,
    this.flowInfo,
    this.pendingUser,
    this.pendingUserAvatar,
    required this.rawData,
  });

  factory FlowChallenge.fromJson(Map<String, dynamic> json) {
    final component = FlowComponentType.fromString(json['component'] as String?);
    
    switch (component) {
      case FlowComponentType.identification:
        return IdentificationChallenge.fromJson(json);
      case FlowComponentType.password:
        return PasswordChallenge.fromJson(json);
      case FlowComponentType.authenticatorValidate:
        return AuthenticatorValidateChallenge.fromJson(json);
      case FlowComponentType.redirect:
        return RedirectChallenge.fromJson(json);
      case FlowComponentType.accessDenied:
        return AccessDeniedChallenge.fromJson(json);
      default:
        return FlowChallenge._internal(
          component: component,
          flowInfo: json['flow_info']?['title'] as String?,
          pendingUser: json['pending_user'] as String?,
          pendingUserAvatar: json['pending_user_avatar'] as String?,
          rawData: json,
        );
    }
  }

  FlowChallenge._internal({
    required this.component,
    this.flowInfo,
    this.pendingUser,
    this.pendingUserAvatar,
    required this.rawData,
  });

  bool get isSuccess => component == FlowComponentType.redirect;
  bool get isAccessDenied => component == FlowComponentType.accessDenied;
}

/// Identification stage
class IdentificationChallenge extends FlowChallenge {
  final String? userFields;
  final bool? passwordFields;
  final String? primaryAction;

  IdentificationChallenge({
    required super.component,
    super.flowInfo,
    required super.rawData,
    this.userFields,
    this.passwordFields,
    this.primaryAction,
  }) : super._internal();

  factory IdentificationChallenge.fromJson(Map<String, dynamic> json) {
    return IdentificationChallenge(
      component: FlowComponentType.identification,
      flowInfo: json['flow_info']?['title'] as String?,
      rawData: json,
      userFields: json['user_fields']?.toString(),
      passwordFields: json['password_fields'] as bool?,
      primaryAction: json['primary_action'] as String?,
    );
  }
}

/// Password stage
class PasswordChallenge extends FlowChallenge {
  final String? primaryAction;

  PasswordChallenge({
    required super.component,
    super.flowInfo,
    super.pendingUser,
    super.pendingUserAvatar,
    required super.rawData,
    this.primaryAction,
  }) : super._internal();

  factory PasswordChallenge.fromJson(Map<String, dynamic> json) {
    return PasswordChallenge(
      component: FlowComponentType.password,
      flowInfo: json['flow_info']?['title'] as String?,
      pendingUser: json['pending_user'] as String?,
      pendingUserAvatar: json['pending_user_avatar'] as String?,
      rawData: json,
      primaryAction: json['primary_action'] as String?,
    );
  }
}

/// Authenticator validation stage
class AuthenticatorValidateChallenge extends FlowChallenge {
  final List<Map<String, dynamic>> deviceChallenges;

  AuthenticatorValidateChallenge({
    required super.component,
    super.flowInfo,
    super.pendingUser,
    required super.rawData,
    this.deviceChallenges = const [],
  }) : super._internal();

  factory AuthenticatorValidateChallenge.fromJson(Map<String, dynamic> json) {
    return AuthenticatorValidateChallenge(
      component: FlowComponentType.authenticatorValidate,
      flowInfo: json['flow_info']?['title'] as String?,
      pendingUser: json['pending_user'] as String?,
      rawData: json,
      deviceChallenges: (json['device_challenges'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [],
    );
  }
}

/// Redirect challenge - success
class RedirectChallenge extends FlowChallenge {
  final String? redirectTo;

  RedirectChallenge({
    required super.component,
    super.flowInfo,
    required super.rawData,
    this.redirectTo,
  }) : super._internal();

  factory RedirectChallenge.fromJson(Map<String, dynamic> json) {
    return RedirectChallenge(
      component: FlowComponentType.redirect,
      flowInfo: json['flow_info']?['title'] as String?,
      rawData: json,
      redirectTo: json['to'] as String?,
    );
  }
}

/// Access denied challenge
class AccessDeniedChallenge extends FlowChallenge {
  final String? errorMessage;

  AccessDeniedChallenge({
    required super.component,
    super.flowInfo,
    required super.rawData,
    this.errorMessage,
  }) : super._internal();

  factory AccessDeniedChallenge.fromJson(Map<String, dynamic> json) {
    return AccessDeniedChallenge(
      component: FlowComponentType.accessDenied,
      flowInfo: json['flow_info']?['title'] as String?,
      rawData: json,
      errorMessage: json['error_message'] as String? ?? json['message'] as String?,
    );
  }
}

/// Flow error
class FlowError {
  final String? nonFieldErrors;
  final Map<String, List<String>> fieldErrors;

  FlowError({
    this.nonFieldErrors,
    this.fieldErrors = const {},
  });

  factory FlowError.fromJson(Map<String, dynamic> json) {
    final fieldErrors = <String, List<String>>{};
    
    json.forEach((key, value) {
      if (key != 'non_field_errors' && value is List) {
        fieldErrors[key] = value.map((e) => e.toString()).toList();
      }
    });

    final nonFieldErrors = json['non_field_errors'] as List<dynamic>?;
    
    return FlowError(
      nonFieldErrors: nonFieldErrors?.join(', '),
      fieldErrors: fieldErrors,
    );
  }

  String get displayError {
    if (nonFieldErrors != null && nonFieldErrors!.isNotEmpty) {
      return nonFieldErrors!;
    }
    if (fieldErrors.isNotEmpty) {
      return fieldErrors.entries
          .map((e) => '${e.key}: ${e.value.join(", ")}')
          .join('\n');
    }
    return 'Unknown error';
  }
}

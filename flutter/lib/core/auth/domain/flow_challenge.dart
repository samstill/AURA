/// Project Aura - Flow Challenge Models
/// =====================================
/// Data models for Authentik Flows API responses.
library;

/// Component types returned by Authentik
enum FlowComponentType {
  identification('ak-stage-identification'),
  password('ak-stage-password'),
  userLogin('ak-stage-user-login'),
  authenticatorTotp('ak-stage-authenticator-totp'),
  authenticatorWebauthn('ak-stage-authenticator-webauthn'),
  authenticatorValidate('ak-stage-authenticator-validate'),
  accessDenied('ak-stage-access-denied'),
  flowError('ak-stage-flow-error'),
  redirect('xak-flow-redirect'),
  shell('ak-flow-shell-loading'),
  autosubmit('ak-stage-autosubmit'),
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
      case FlowComponentType.flowError:
        return FlowErrorChallenge.fromJson(json);
      case FlowComponentType.userLogin:
      case FlowComponentType.autosubmit:
        // These stages complete automatically - treat as redirect
        return RedirectChallenge(
          component: FlowComponentType.redirect,
          flowInfo: json['flow_info']?['title'] as String?,
          rawData: json,
          redirectTo: '/',
        );
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

/// Flow error challenge - when the flow encounters an error
class FlowErrorChallenge extends FlowChallenge {
  final String? requestId;
  final String? errorMessage;

  FlowErrorChallenge({
    required super.component,
    super.flowInfo,
    required super.rawData,
    this.requestId,
    this.errorMessage,
  }) : super._internal();

  factory FlowErrorChallenge.fromJson(Map<String, dynamic> json) {
    return FlowErrorChallenge(
      component: FlowComponentType.flowError,
      flowInfo: json['flow_info']?['title'] as String?,
      rawData: json,
      requestId: json['request_id'] as String?,
      errorMessage: json['error'] as String? ?? json['message'] as String?,
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

  /// Returns a user-friendly, seductive error message
  String get displayError {
    final rawError = _getRawError();
    return _beautifyError(rawError);
  }

  String _getRawError() {
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

  /// Transform technical errors into seductive, user-friendly messages
  String _beautifyError(String error) {
    final lowerError = error.toLowerCase();
    
    // Connection / Network errors
    if (lowerError.contains('connection refused') ||
        lowerError.contains('socketexception') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('network is unreachable') ||
        lowerError.contains('connection reset')) {
      return "We can't reach our servers right now. Check your connection and we'll try again together.";
    }
    
    if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
      return "The connection is taking longer than expected. Let's give it another moment...";
    }
    
    if (lowerError.contains('connection closed') ||
        lowerError.contains('connection was reset') ||
        lowerError.contains('broken pipe')) {
      return "We lost the connection briefly. Don't worry, let's reconnect.";
    }
    
    // SSL / Certificate errors
    if (lowerError.contains('certificate') ||
        lowerError.contains('ssl') ||
        lowerError.contains('handshake')) {
      return "There's a security hiccup. Make sure you're on a trusted network.";
    }
    
    // Server errors
    if (lowerError.contains('500') || lowerError.contains('internal server')) {
      return "Our servers are having a moment. Please try again in a bit.";
    }
    
    if (lowerError.contains('503') || lowerError.contains('service unavailable')) {
      return "We're briefly away for maintenance. Be right back!";
    }
    
    if (lowerError.contains('502') || lowerError.contains('bad gateway')) {
      return "We're experiencing some traffic. Give us a second to clear the path.";
    }
    
    // Auth specific errors
    if (lowerError.contains('invalid password') ||
        lowerError.contains('incorrect password') ||
        lowerError.contains('wrong password')) {
      return "That password doesn't match. Take your time and try again.";
    }
    
    if (lowerError.contains('user not found') ||
        lowerError.contains('no user') ||
        lowerError.contains('invalid username') ||
        lowerError.contains('doesn\'t exist')) {
      return "We couldn't find that account. Double-check and try again?";
    }
    
    if (lowerError.contains('too many attempts') ||
        lowerError.contains('rate limit') ||
        lowerError.contains('locked')) {
      return "Too many attempts. Let's take a breath and try again shortly.";
    }
    
    if (lowerError.contains('expired') || lowerError.contains('session')) {
      return "Your session has expired. Let's start fresh.";
    }
    
    if (lowerError.contains('access denied') ||
        lowerError.contains('forbidden') ||
        lowerError.contains('not authorized')) {
      return "Access wasn't granted. Check your permissions or reach out for help.";
    }
    
    // Empty / Invalid responses
    if (lowerError.contains('empty response') ||
        lowerError.contains('invalid response') ||
        lowerError.contains('server returned html')) {
      return "Something unexpected happened. Let's try that again.";
    }
    
    // DNS / Host errors
    if (lowerError.contains('dns') ||
        lowerError.contains('resolve') ||
        lowerError.contains('host')) {
      return "We can't find the server. Check your internet connection.";
    }
    
    // Generic DIO errors
    if (lowerError.contains('dioexception') ||
        lowerError.contains('dioerror')) {
      if (lowerError.contains('cancel')) {
        return "The request was cancelled. Ready when you are.";
      }
      return "A connection issue occurred. Let's try once more.";
    }
    
    // If no pattern matches, return a friendly version of short errors
    // or a generic message for long technical ones
    if (error.length > 100 || error.contains('Exception') || error.contains('Error:')) {
      return "Something went wrong on our end. Please try again.";
    }
    
    // Return the original if it's already human-readable
    return error;
  }
}

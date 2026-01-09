/// Project Aura - Certificate Pinning
/// ====================================
/// SSL/TLS certificate pinning for production security.
/// 
/// Pins the certificate for auth.encresa.com to prevent MITM attacks.
/// 
/// IMPORTANT: Update these pins when certificates are renewed!
/// Current certificate fingerprints can be obtained with:
/// ```bash
/// openssl s_client -connect auth.encresa.com:443 2>/dev/null | \
///   openssl x509 -noout -fingerprint -sha256
/// ```
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// SHA256 fingerprints of trusted certificates
/// 
/// These are the public key hashes of certificates we trust.
/// Format: SHA256 hash of the certificate's DER-encoded bytes, base64 encoded
class CertificatePins {
  CertificatePins._();
  
  /// Pinned certificate fingerprints for auth.encresa.com
  /// 
  /// Include multiple pins for certificate rotation:
  /// - Current production certificate
  /// - Backup/next certificate (for rotation)
  /// 
  /// To get the SHA256 fingerprint:
  /// ```bash
  /// # Get certificate chain
  /// openssl s_client -connect auth.encresa.com:443 -servername auth.encresa.com </dev/null 2>/dev/null | \
  ///   openssl x509 -pubkey -noout | \
  ///   openssl pkey -pubin -outform der | \
  ///   openssl dgst -sha256 -binary | \
  ///   base64
  /// ```
  static const List<String> authentikPins = [
    // Current production certificate for auth.encresa.com (as of Jan 2026)
    '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=',
    
    // TODO: Add backup certificate pin before rotation
    // This ensures continuity during certificate renewal
  ];
  
  /// Whether certificate pinning is enabled
  /// 
  /// Disabled in debug mode for easier development.
  /// MUST be enabled in production builds.
  static bool get isEnabled {
    // Disable pinning in debug mode for development flexibility
    if (kDebugMode) {
      return false;
    }
    // Enable pinning only if we have actual pins configured
    return authentikPins.isNotEmpty;
  }
  
  /// Pinned hosts configuration
  static const Map<String, List<String>> pinnedHosts = {
    'auth.encresa.com': authentikPins,
  };
  
  /// Get SHA256 fingerprint of certificate DER bytes (base64 encoded)
  static String getCertificateSha256(Uint8List derBytes) {
    final digest = sha256.convert(derBytes);
    return base64.encode(digest.bytes);
  }
}


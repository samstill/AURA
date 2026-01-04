import 'package:cookie_jar/cookie_jar.dart';
// Conditional imports
import 'cookie_store_stub.dart'
    if (dart.library.io) 'cookie_store_io.dart'
    if (dart.library.html) 'cookie_store_web.dart';

/// Creates a platform-appropriate CookieJar
Future<CookieJar> makeCookieJar() => createCookieJar();

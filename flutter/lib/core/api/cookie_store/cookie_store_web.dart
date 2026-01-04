import 'package:cookie_jar/cookie_jar.dart';

/// Web implementation - uses in-memory CookieJar as PersistCookieJar (FileStorage) is not supported
Future<CookieJar> createCookieJar() async {
  return CookieJar();
}

import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

/// Native implementation - uses persistent file storage
Future<CookieJar> createCookieJar() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final cookiePath = '${appDocDir.path}/.cookies/';
  final directory = Directory(cookiePath);
  
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  
  return PersistCookieJar(storage: FileStorage(cookiePath));
}

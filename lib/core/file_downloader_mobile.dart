import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> saveAndOpenFile(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) {
    throw Exception('No se pudo abrir el archivo: ${result.message}');
  }
}

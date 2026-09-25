import 'dart:io';
import 'package:crypto/crypto.dart';

Future<bool> doesFileExist(String path) async {
  return File(path).exists();
}

Future<int> getFileSize(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return file.length();
  }
  return 0;
}

Future<bool> verifySha256(String filePath, String expectedSha256) async {
  final file = File(filePath);
  if (!await file.exists()) return false;

  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
}

Future<void> renameFile(String oldPath, String newPath) async {
  final oldFile = File(oldPath);
  final newFile = File(newPath);
  if (await newFile.exists()) {
    await newFile.delete();
  }
  await newFile.parent.create(recursive: true);
  await oldFile.rename(newPath);
}

Future<void> deleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

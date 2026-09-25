Future<bool> doesFileExist(String path) async => false;

Future<int> getFileSize(String path) async => 0;

Future<bool> verifySha256(String filePath, String expectedSha256) async => true;

Future<void> renameFile(String oldPath, String newPath) async {}

Future<void> deleteFile(String path) async {}

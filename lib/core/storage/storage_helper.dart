import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageHelper {
  static Future<Directory> getArticlesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final articlesDir = Directory(p.join(appDir.path, 'articles'));
    if (!await articlesDir.exists()) {
      await articlesDir.create(recursive: true);
    }
    return articlesDir;
  }

  /// Create a temporary directory for an article being downloaded
  /// Returns the path to the temp directory
  static Future<String> createTempArticleDirectory(String articleId) async {
    final articlesDir = await getArticlesDirectory();
    final tempDir = Directory(p.join(articlesDir.path, '$articleId.tmp'));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }

  /// Rename temp directory to final directory after verification
  /// This is the atomic write step
  static Future<bool> finalizeArticleDirectory(String articleId) async {
    final articlesDir = await getArticlesDirectory();
    final tempDir = Directory(p.join(articlesDir.path, '$articleId.tmp'));
    final finalDir = Directory(p.join(articlesDir.path, articleId));

    if (!await tempDir.exists()) {
      return false;
    }

    // If final dir exists, remove it first (shouldn't happen in normal flow)
    if (await finalDir.exists()) {
      await finalDir.delete(recursive: true);
    }

    // Atomic rename
    await tempDir.rename(finalDir.path);
    return true;
  }

  /// Get the path to an article's directory
  static Future<String> getArticlePath(String articleId) async {
    final articlesDir = await getArticlesDirectory();
    return p.join(articlesDir.path, articleId);
  }

  /// Get path to article's content.json
  static Future<String> getContentPath(String articleId) async {
    final articlePath = await getArticlePath(articleId);
    return p.join(articlePath, 'content.json');
  }

  /// Generate a UUID filename for images (prevents path traversal)
  static String generateImageFilename(String uuid) {
    // Always use UUID, never original filename from URL
    return '$uuid.jpg';
  }

  /// Get the images directory for an article
  static Future<Directory> getImagesDirectory(String articleId) async {
    final articlePath = await getArticlePath(articleId);
    final imagesDir = Directory(p.join(articlePath, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Check if article content exists and is valid
  static Future<bool> verifyArticleContent(String articleId) async {
    try {
      final contentPath = await getContentPath(articleId);
      final contentFile = File(contentPath);
      
      if (!await contentFile.exists()) {
        return false;
      }

      // Check if file is valid JSON
      final content = await contentFile.readAsString();
      if (content.isEmpty) return false;
      
      // Basic JSON validation
      if (!content.trimLeft().startsWith('{') && !content.trimLeft().startsWith('[')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete article directory and all its contents
  static Future<bool> deleteArticleDirectory(String articleId) async {
    try {
      final articlesDir = await getArticlesDirectory();
      final articleDir = Directory(p.join(articlesDir.path, articleId));
      final tempDir = Directory(p.join(articlesDir.path, '$articleId.tmp'));

      if (await articleDir.exists()) {
        await articleDir.delete(recursive: true);
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get total storage size used by articles
  static Future<int> getStorageUsage() async {
    try {
      final articlesDir = await getArticlesDirectory();
      int totalSize = 0;
      
      await for (final entity in articlesDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get available disk space (approximate — actual calculation is platform-specific)
  /// BUG 11: Note: stat.size returns the directory size, NOT available disk space.
  /// For true available space, platform plugins (e.g. disk_space) are needed.
  static Future<int> getAvailableSpace() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stat = await appDir.stat();
      return stat.size;
    } catch (e) {
      return 0;
    }
  }

  /// Save image with UUID filename (prevents path traversal)
  static Future<String> saveImage(String articleId, String imageUuid, List<int> bytes) async {
    final imagesDir = await getImagesDirectory(articleId);
    final filename = generateImageFilename(imageUuid);
    final file = File(p.join(imagesDir.path, filename));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

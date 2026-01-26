import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Firebase Storage 이미지 업로드 서비스
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 이미지 선택 (갤러리 또는 카메라)
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// 다중 이미지 선택 (갤러리)
  Future<List<XFile>?> pickMultipleImages({int maxImages = 10}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (images.isEmpty) return null;
      // maxImages 제한 적용
      return images.take(maxImages).toList();
    } catch (e) {
      return null;
    }
  }

  /// 이미지 업로드 (Firebase Storage)
  ///
  /// [file] 업로드할 파일
  /// [path] Storage 경로 (예: 'properties/{propertyId}/images/{fileName}')
  ///
  /// 반환: 다운로드 URL
  Future<String?> uploadImage({
    required XFile file,
    required String path,
  }) async {
    try {
      final Reference ref = _storage.ref().child(path);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
        );
        uploadTask = ref.putData(bytes, metadata);
      } else {
        final File imageFile = File(file.path);
        uploadTask = ref.putFile(imageFile);
      }

      final TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timeout after 60 seconds');
        },
      );

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 여러 이미지 업로드
  ///
  /// [files] 업로드할 파일 목록
  /// [basePath] 기본 경로 (예: 'properties/{propertyId}/images')
  ///
  /// 반환: 다운로드 URL 목록
  Future<List<String>> uploadImages({
    required List<XFile> files,
    required String basePath,
  }) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final path = '$basePath/$fileName';

      final url = await uploadImage(file: file, path: path);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// 이미지 삭제
  Future<bool> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}

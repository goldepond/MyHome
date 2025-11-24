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
        imageQuality: 85, // 이미지 품질 (0-100)
        maxWidth: 1920, // 최대 너비
        maxHeight: 1920, // 최대 높이
      );
      return image;
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
      
      // 파일을 업로드
      UploadTask uploadTask;
      if (kIsWeb) {
        // Web의 경우 bytes로 업로드
        final bytes = await file.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        // 모바일의 경우 File로 업로드
        final File imageFile = File(file.path);
        uploadTask = ref.putFile(imageFile);
      }

      // 업로드 완료 대기
      final TaskSnapshot snapshot = await uploadTask;
      
      // 다운로드 URL 반환
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
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


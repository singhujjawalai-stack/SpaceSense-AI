import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class StorageService {
  final Logger _logger = Logger();

  Future<Directory> get _appDocDir async {
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> get _originalsDir async {
    final appDir = await _appDocDir;
    final dir = Directory('${appDir.path}/spacesense/originals');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _analysesDir async {
    final appDir = await _appDocDir;
    final dir = Directory('${appDir.path}/spacesense/analyses');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // Save original image
  Future<String> saveOriginalImage(File imageFile, String roomId) async {
    try {
      final dir = await _originalsDir;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${roomId}_$timestamp.jpg';
      final savedFile = await imageFile.copy('${dir.path}/$fileName');
      _logger.d('Saved original image: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      _logger.e('Error saving original image: $e');
      rethrow;
    }
  }

  // Save analysis JSON
  Future<String> saveAnalysis(Map<String, dynamic> analysisData, String analysisId) async {
    try {
      final dir = await _analysesDir;
      final fileName = '$analysisId.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json.encode(analysisData));
      _logger.d('Saved analysis: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Error saving analysis: $e');
      rethrow;
    }
  }

  // Get all analyses
  Future<List<Map<String, dynamic>>> getAllAnalyses() async {
    try {
      final dir = await _analysesDir;
      final files = dir.listSync().where((f) => f.path.endsWith('.json')).toList();

      final analyses = <Map<String, dynamic>>[];
      for (var file in files) {
        final content = await File(file.path).readAsString();
        analyses.add(json.decode(content) as Map<String, dynamic>);
      }

      // Sort by analyzed_at timestamp (newest first)
      analyses.sort((a, b) {
        final aTime = DateTime.parse(a['analyzed_at'] as String);
        final bTime = DateTime.parse(b['analyzed_at'] as String);
        return bTime.compareTo(aTime);
      });

      return analyses;
    } catch (e) {
      _logger.e('Error getting all analyses: $e');
      return [];
    }
  }

  // Get analysis by ID
  Future<Map<String, dynamic>?> getAnalysis(String analysisId) async {
    try {
      final dir = await _analysesDir;
      final file = File('${dir.path}/$analysisId.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.e('Error getting analysis: $e');
      return null;
    }
  }

  // Delete analysis
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      final dir = await _analysesDir;
      final file = File('${dir.path}/$analysisId.json');
      if (await file.exists()) {
        await file.delete();
        _logger.d('Deleted analysis: $analysisId');
      }
    } catch (e) {
      _logger.e('Error deleting analysis: $e');
      rethrow;
    }
  }

  // Delete original image
  Future<void> deleteOriginalImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        _logger.d('Deleted original image: $imagePath');
      }
    } catch (e) {
      _logger.e('Error deleting original image: $e');
      rethrow;
    }
  }
}

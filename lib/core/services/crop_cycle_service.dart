import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../constants/api_constants.dart';
import '../models/crop_cycle_model.dart';
import '../network/api_client.dart';

class CropCycleService {
  final ApiClient _apiClient;

  CropCycleService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<CropCycleModel?> fetchActiveCycle(int demplotId) async {
    try {
      final response = await _apiClient.get(
        Uri.parse(ApiConstants.cropCycleActiveEndpoint(demplotId)),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return CropCycleModel.fromJson(body['data']);
      }
      return null;
    } catch (e) {
      // Return null on network error or not found to safely show empty state
      return null;
    }
  }

  Future<CropCycleModel> startCropCycle({
    required int demplotId,
    required String commodityName,
    required DateTime plantingDate,
    DateTime? targetHarvestDate,
    String? notes,
  }) async {
    final Map<String, dynamic> payload = {
      'demplotId': demplotId,
      'commodityName': commodityName,
      'plantingDate': plantingDate.toUtc().toIso8601String(),
    };
    if (targetHarvestDate != null) {
      payload['targetHarvestDate'] = targetHarvestDate.toUtc().toIso8601String();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes;
    }

    final response = await _apiClient.post(
      Uri.parse(ApiConstants.cropCycleStartEndpoint),
      body: payload,
    );

    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    if (responseBody['success'] == true && responseBody['data'] != null) {
      return CropCycleModel.fromJson(responseBody['data']);
    } else {
      throw ApiException('Gagal memulai siklus tanam.');
    }
  }

  Future<CropCycleModel> harvestCropCycle({
    required String id,
    DateTime? harvestDate,
    double? yieldKg,
    String? notes,
  }) async {
    final Map<String, dynamic> payload = {};
    if (harvestDate != null) {
      payload['harvestDate'] = harvestDate.toUtc().toIso8601String();
    }
    if (yieldKg != null) {
      payload['yieldKg'] = yieldKg;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes;
    }

    final response = await _apiClient.post(
      Uri.parse(ApiConstants.cropCycleHarvestEndpoint(id)),
      body: payload,
    );

    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    if (responseBody['success'] == true && responseBody['data'] != null) {
      return CropCycleModel.fromJson(responseBody['data']);
    } else {
      throw ApiException('Gagal menyelesaikan siklus tanam.');
    }
  }

  Future<List<CropCycleModel>> fetchHistory(int demplotId) async {
    final response = await _apiClient.get(
      Uri.parse(ApiConstants.cropCycleHistoryEndpoint(demplotId)),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);
    if (body['success'] == true && body['data'] != null) {
      final List<dynamic> data = body['data'];
      return data.map((json) => CropCycleModel.fromJson(json)).toList();
    }
    return [];
  }
}

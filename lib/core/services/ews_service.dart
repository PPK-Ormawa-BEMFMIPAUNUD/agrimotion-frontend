import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ews_status_model.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for fetching Early Warning System (EWS) status.
class EwsService {
  final http.Client _client;

  EwsService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches EWS status for a specific demplot.
  /// Uses a strict timeout and falls back to a safe offline calculation if
  /// the network or backend is unreachable.
  Future<EwsStatusModel> fetchEwsStatus(int demplotId) async {
    try {
      final url = Uri.parse(ApiConfig.ewsStatusEndpoint(demplotId));
      
      final response = await _client.get(
        url,
        headers: {
          'Cache-Control': 'no-cache',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return EwsStatusModel.fromJson(jsonResponse);
      } else {
        debugPrint(
            'EWS API error: ${response.statusCode}. Falling back to offline EWS.');
        return EwsStatusModel.fallback(demplotId);
      }
    } on TimeoutException {
      debugPrint('EWS API timeout. Falling back to offline EWS.');
      return EwsStatusModel.fallback(demplotId);
    } catch (e) {
      debugPrint('EWS API exception: $e. Falling back to offline EWS.');
      return EwsStatusModel.fallback(demplotId);
    }
  }
}

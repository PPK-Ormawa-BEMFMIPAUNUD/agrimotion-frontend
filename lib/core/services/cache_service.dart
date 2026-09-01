import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  throw UnimplementedError('cacheServiceProvider not initialized');
});

class CacheService {
  final SharedPreferences _prefs;
  final Map<String, dynamic> _memoryCache = {};
  
  static const String _cachePrefix = 'cache_';

  CacheService(this._prefs);

  static Future<CacheService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return CacheService(prefs);
  }

  /// Sets a value in the cache, both in-memory and persistently
  Future<void> setCacheData(String key, dynamic data) async {
    _memoryCache[key] = data;
    final prefsKey = '$_cachePrefix$key';
    try {
      if (data is String) {
        await _prefs.setString(prefsKey, data);
      } else {
        await _prefs.setString(prefsKey, jsonEncode(data));
      }
    } catch (e) {
      // Ignore serialization errors for persistent storage
    }
  }

  /// Gets a value from the cache. Returns memory cache if available, else persistent storage.
  dynamic getCacheData(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    
    final prefsKey = '$_cachePrefix$key';
    final storedString = _prefs.getString(prefsKey);
    if (storedString != null) {
      try {
        final decoded = jsonDecode(storedString);
        _memoryCache[key] = decoded; 
        return decoded;
      } catch (e) {
        // Not a JSON object, return as string
        _memoryCache[key] = storedString;
        return storedString;
      }
    }
    
    return null;
  }
  
  /// Clears a specific key
  Future<void> clear(String key) async {
    _memoryCache.remove(key);
    final prefsKey = '$_cachePrefix$key';
    await _prefs.remove(prefsKey);
  }

  /// Clears the entire cache (only keys with _cachePrefix)
  Future<void> clearAll() async {
    _memoryCache.clear();
    final keys = _prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';



import 'package:flutter/widgets.dart';

class CachedTileProvider extends TileProvider with WidgetsBindingObserver {
  final Map<String, Uint8List> _memoryCache = {};
  final BaseCacheManager _cacheManager = DefaultCacheManager();

  CachedTileProvider() {
    // Register this provider as a WidgetsBindingObserver
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);

    if (_memoryCache.containsKey(url)) {
      return MemoryImage(_memoryCache[url]!);
    }

    return CachedNetworkImageProvider(url, cacheManager: _cacheManager);
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    return options.urlTemplate
    !.replaceAll('{z}', '${coordinates.z}')
        .replaceAll('{x}', '${coordinates.x}')
        .replaceAll('{y}', '${coordinates.y}');
  }

  Future<void> precacheUrl(String url) async {
    if (!_memoryCache.containsKey(url)) {
      final file = await _cacheManager.getSingleFile(url);
      final bytes = await file.readAsBytes();
      _memoryCache[url] = bytes;
    }
  }

  void clearCache() {
    _memoryCache.clear();
    _cacheManager.emptyCache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      clearCache();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class CustomCacheManager extends CacheManager {
  static const key = "customCache";

  static CacheManager instance = CustomCacheManager._();

  CustomCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );
}


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../service/osm_map_service.dart';
import '../service/photo_request_queue.dart';

class OsmPlacePhoto extends StatefulWidget {
  const OsmPlacePhoto({
    super.key,
    required this.placeId,
    required this.width,
    required this.height,
  });
  final String placeId;
  final double width;
  final double height;
  @override
  State<OsmPlacePhoto> createState() => _OsmPlacePhotoState();
}

class _OsmPlacePhotoState extends State<OsmPlacePhoto> {
  static final _cache =
      <String, ({DateTime expires, List<Map<String, dynamic>> photos})>{};
  static final _queue = PhotoRequestQueue();
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OsmPlacePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeId != widget.placeId) _load();
  }

  void _load() {
    final generation = ++_generation;
    final id = widget.placeId;
    setState(() {
      _loading = true;
      _error = null;
      _photos = [];
    });
    // Keep two requests active so one slow place does not block every thumbnail.
    _queue.run(() async {
      if (!mounted || generation != _generation) return;
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token == null) throw Exception('Sign in to load photos.');
        final key = '${AppConfig.osmPlacesUrl}:$id';
        final cached = _cache[key];
        List<Map<String, dynamic>> photos;
        if (cached != null && cached.expires.isAfter(DateTime.now())) {
          photos = cached.photos;
        } else {
          final place = OsmMapService.knownPlace(id);
          final response = await http
              .post(
                Uri.parse(AppConfig.osmPlacesUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'action': 'photo',
                  'id': id,
                  if (place != null)
                    'place': {
                      'name': place.name,
                      'latitude': place.latitude,
                      'longitude': place.longitude,
                    },
                }),
              )
              .timeout(const Duration(seconds: 55));
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (response.statusCode != 200) {
            throw Exception(data['error'] ?? 'Photos unavailable');
          }
          final values =
              data['photos'] as List? ??
              (data['photo'] is Map ? [data['photo']] : []);
          photos = values
              .take(5)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          if (_cache.length >= 100) _cache.remove(_cache.keys.first);
          _cache[key] = (
            expires: photos.fold<DateTime>(
              DateTime.now().add(Duration(minutes: photos.isEmpty ? 0 : 30)),
              (expiry, photo) {
                final milliseconds = photo['expiresAt'];
                if (milliseconds is! num) return expiry;
                final permissionExpiry = DateTime.fromMillisecondsSinceEpoch(
                  milliseconds.toInt(),
                );
                return permissionExpiry.isBefore(expiry)
                    ? permissionExpiry
                    : expiry;
              },
            ),
            photos: photos,
          );
        }
        if (mounted && generation == _generation) {
          setState(() => _photos = photos);
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''),
          );
        }
      } finally {
        if (mounted && generation == _generation) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Widget _link(String label, String url) => TextButton(
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(label),
  );
  void _show() {
    var index = 0;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final photo = _photos[index];
          return AlertDialog(
            title: Text(
              photo['nearby'] == true ? 'Nearby street view' : 'Place photos',
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .35,
                      child: Image.network(
                        photo['url'] as String,
                        semanticLabel: photo['title'] as String,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('Photo unavailable')),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous photo',
                          onPressed: index > 0
                              ? () => update(() => index--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${index + 1} / ${_photos.length}'),
                        IconButton(
                          tooltip: 'Next photo',
                          onPressed: index + 1 < _photos.length
                              ? () => update(() => index++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    if (photo['nearby'] == true)
                      const Text(
                        'Street imagery nearby; not a verified venue photo.',
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        _link(
                          photo['source'] as String,
                          photo['sourceUrl'] as String,
                        ),
                        _link(
                          'By ${photo['author']}',
                          photo['authorUrl'] as String,
                        ),
                        _link(
                          photo['license'] as String,
                          photo['licenseUrl'] as String,
                        ),
                      ],
                    ),
                    const Text('Shown without cropping or editing.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: _loading
        ? const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : _photos.isEmpty
        ? Tooltip(
            message: _error ?? 'No suitable photo found',
            child: IconButton(
              tooltip: _error == null
                  ? 'No matching photo · retry'
                  : 'Retry photos',
              onPressed: _load,
              icon: Icon(
                _error == null
                    ? Icons.image_not_supported_outlined
                    : Icons.refresh,
              ),
            ),
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _show,
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      _photos.first['url'] as String,
                      fit: BoxFit.contain,
                      semanticLabel: _photos.first['title'] as String,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Text(
                    '${_photos.length} photos · credits',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
  );
}

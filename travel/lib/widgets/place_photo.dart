import 'package:flutter/material.dart';

class PlacePhoto extends StatelessWidget {
  const PlacePhoto({
    super.key,
    required this.placeName,
    required this.photoUrl,
    this.width = 76,
    this.height = 76,
    this.borderRadius = 16,
  });

  final String placeName;
  final String? photoUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final image = url == null || url.isEmpty
        ? _placeholder(context)
        : Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(context),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : _placeholder(context, loading: true),
          );

    return Semantics(
      button: url != null,
      label: url == null ? 'No photo for $placeName' : 'View photo of $placeName',
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: url == null ? null : () => _showPreview(context, url),
          child: Ink(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius - 1),
              child: image,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.photo_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  void _showPreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  width: double.infinity,
                  height: 620,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: 320,
                    child: Center(child: _placeholder(dialogContext)),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filled(
                  tooltip: 'Close photo',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

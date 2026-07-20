import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/product.dart';

/// Renders a [ProductImage], which may hold either a remote URL or inline
/// base64 (with or without a `data:image/...;base64,` prefix) — the server
/// stores both shapes under the same `imageBase64` key.
///
/// Decoded bytes are cached per instance so a rebuild (e.g. changing the
/// selected variant) does not re-decode a multi-hundred-KB string.
///
/// [decodeWidth] is not cosmetic — it is required to keep the app alive.
/// The API inlines full-resolution JPEGs as base64 with no thumbnail or
/// projection option, so decoding a grid of them at native size exhausts
/// memory and gets the process killed by Android's low-memory killer.
/// Passing it downsamples during decode, so only the pixels actually shown are
/// ever held in the image cache.
class ProductImageView extends StatefulWidget {
  const ProductImageView({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    required this.decodeWidth,
  });

  final ProductImage? image;
  final BoxFit fit;

  /// Target width in logical pixels; scaled by the device pixel ratio.
  final double decodeWidth;

  @override
  State<ProductImageView> createState() => _ProductImageViewState();
}

class _ProductImageViewState extends State<ProductImageView> {
  Uint8List? _bytes;
  String? _decodedFrom;

  @override
  void didUpdateWidget(ProductImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image?.data != oldWidget.image?.data) _decode();
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  void _decode() {
    final image = widget.image;
    if (image == null || image.isRemote) {
      _bytes = null;
      _decodedFrom = null;
      return;
    }
    if (_decodedFrom == image.data) return;

    try {
      final raw = image.data;
      final comma = raw.indexOf(',');
      // Strip a data-URI header if present; otherwise treat the whole string
      // as base64.
      final payload = raw.startsWith('data:') && comma != -1 ? raw.substring(comma + 1) : raw;
      _bytes = base64Decode(payload);
      _decodedFrom = raw;
    } catch (_) {
      _bytes = null;
      _decodedFrom = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    if (image == null) return const _ImagePlaceholder();

    // Decode at display size rather than native size — see the class doc.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (widget.decodeWidth * ratio).round().clamp(1, 4096);

    if (image.isRemote) {
      return Image.network(
        image.data,
        fit: widget.fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _ImagePlaceholder(showSpinner: true),
      );
    }

    final bytes = _bytes;
    if (bytes == null) return const _ImagePlaceholder();
    return Image.memory(
      bytes,
      fit: widget.fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.showSpinner = false});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: showSpinner
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.image_outlined, color: scheme.outline),
      ),
    );
  }
}

/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Replaces a live [BackdropFilter] over the (static) wallpaper with a
/// pre-blurred snapshot of the wallpaper that is blitted behind [child].
///
/// A live [BackdropFilter] re-samples and re-blurs the scene on *every*
/// composited frame, which is expensive on low-end GPUs (e.g. Android TV
/// sticks). Because the wallpaper is static, we blur it once into a [ui.Image]
/// and simply copy the region located under this widget each frame — a cheap
/// blit that naturally follows scrolling through the paint offset.
///
/// Falls back to a live [BackdropFilter] while the snapshot is being prepared
/// or when the wallpaper is a video (which is not static).
class CachedBlurBackdrop extends StatefulWidget {
  final double sigma;
  final Widget child;

  const CachedBlurBackdrop({super.key, required this.sigma, required this.child});

  @override
  State<CachedBlurBackdrop> createState() => _CachedBlurBackdropState();
}

class _CachedBlurBackdropState extends State<CachedBlurBackdrop> {
  ui.Image? _blurred;
  Size _builtSize = Size.zero;
  int _builtRevision = -1;
  String? _builtGradientId;
  double _builtSigma = -1;
  bool _building = false;

  @override
  void dispose() {
    _blurred?.dispose();
    super.dispose();
  }

  Widget _liveBlur() =>
      BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: widget.sigma, sigmaY: widget.sigma), child: widget.child);

  Future<void> _build(WallpaperService service, Size size, double dpr) async {
    if (_building) return;
    _building = true;
    try {
      final pxWidth = (size.width * dpr).round();
      final pxHeight = (size.height * dpr).round();
      final rect = Rect.fromLTWH(0, 0, pxWidth.toDouble(), pxHeight.toDouble());

      ui.Image? source;
      final provider = service.wallpaper;
      if (provider != null) {
        source = await _resolveImage(provider);
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final blurPaint =
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: widget.sigma * dpr,
              sigmaY: widget.sigma * dpr,
              tileMode: TileMode.clamp,
            );
      canvas.saveLayer(rect, blurPaint);
      if (source != null) {
        paintImage(canvas: canvas, rect: rect, image: source, fit: BoxFit.cover, filterQuality: FilterQuality.low);
      } else {
        canvas.drawRect(rect, Paint()..shader = service.gradient.gradient.createShader(rect));
      }
      canvas.restore();

      final image = await recorder.endRecording().toImage(pxWidth, pxHeight);
      source?.dispose();

      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _blurred?.dispose();
        _blurred = image;
        _builtSize = size;
        _builtRevision = service.wallpaperRevision;
        _builtGradientId = provider == null ? service.gradient.uuid : null;
        _builtSigma = widget.sigma;
      });
    } finally {
      _building = false;
    }
  }

  Future<ui.Image> _resolveImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WallpaperService>();
    // Video wallpapers are not static: keep the live blur.
    if (service.wallpaperVideoFile != null) {
      return _liveBlur();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final gradientId = service.wallpaper == null ? service.gradient.uuid : null;
        final stale =
            _blurred == null ||
            _builtSize != screen ||
            _builtRevision != service.wallpaperRevision ||
            _builtGradientId != gradientId ||
            _builtSigma != widget.sigma;
        if (stale && screen.width > 0 && screen.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _build(service, screen, dpr);
          });
        }
        final image = _blurred;
        if (image == null || stale) {
          // Snapshot not ready: fall back to the live blur for correctness.
          return _liveBlur();
        }
        return Stack(
          fit: StackFit.passthrough,
          children: [Positioned.fill(child: _BlurBlit(image: image, screenSize: screen)), widget.child],
        );
      },
    );
  }
}

/// Blits the region of the pre-blurred wallpaper [image] located under this
/// render box (in screen space) using the paint offset, so it stays aligned
/// with the wallpaper while scrolling.
class _BlurBlit extends LeafRenderObjectWidget {
  final ui.Image image;
  final Size screenSize;

  const _BlurBlit({required this.image, required this.screenSize});

  @override
  RenderObject createRenderObject(BuildContext context) => _BlurBlitRender(image, screenSize);

  @override
  void updateRenderObject(BuildContext context, _BlurBlitRender renderObject) {
    renderObject
      ..image = image
      ..screenSize = screenSize;
  }
}

class _BlurBlitRender extends RenderBox {
  ui.Image _image;
  Size _screenSize;

  _BlurBlitRender(this._image, this._screenSize);

  set image(ui.Image value) {
    if (value != _image) {
      _image = value;
      markNeedsPaint();
    }
  }

  set screenSize(Size value) {
    if (value != _screenSize) {
      _screenSize = value;
      markNeedsPaint();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final scaleX = _image.width / _screenSize.width;
    final scaleY = _image.height / _screenSize.height;
    final src = Rect.fromLTWH(offset.dx * scaleX, offset.dy * scaleY, size.width * scaleX, size.height * scaleY);
    final dst = offset & size;
    context.canvas.drawImageRect(_image, src, dst, Paint()..filterQuality = FilterQuality.low);
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/avatar_crop_math.dart';
import '../data/avatar_draft_controller.dart';

/// Side length of the uploaded avatar, in pixels.
const avatarOutputSize = 512;

/// Picks a photo from the library and lets the user crop it. Returns a
/// [avatarOutputSize]-square PNG, or `null` when the user backs out or the
/// photo cannot be used (after telling them why).
Future<Uint8List?> pickAndCropAvatar(
  BuildContext context, {
  Future<XFile?> Function()? pickImage,
}) async {
  final XFile? file;
  try {
    file = await (pickImage ?? _pickFromLibrary)();
  } on PlatformException {
    if (context.mounted) _snack(context, 'Could not open your photos.');
    return null;
  }
  if (file == null || !context.mounted) return null;
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } finally {
    await _deletePickedCopy(file);
  }
  final image = await decodeAvatarImage(bytes);
  if (!context.mounted) {
    image?.dispose();
    return null;
  }
  if (image == null) {
    _snack(context, AvatarDraftController.unsupportedMessage);
    return null;
  }
  try {
    return await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarCropScreen(image: image),
      ),
    );
  } finally {
    image.dispose();
  }
}

/// Full resolution is re-encoded after cropping anyway, so the picker keeps
/// full quality and only caps the size: 2048 px leaves room to zoom in on a
/// 512 px crop while bounding decoded memory (~16 MB RGBA).
Future<XFile?> _pickFromLibrary() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 2048,
  maxHeight: 2048,
);

/// image_picker copies every pick into the app cache (Android cacheDir,
/// iOS tmp). The draft lives in memory from here on, so the copy goes now
/// instead of whenever the OS clears the cache. The app holds no
/// storage/media permission and image_picker always returns its own cache
/// copy (Android scoped storage, iOS sandbox), so the delete cannot touch
/// the user's original photo.
Future<void> _deletePickedCopy(XFile file) async {
  if (file.path.isEmpty) return; // XFile.fromData in tests has no file.
  try {
    await File(file.path).delete();
  } on FileSystemException {
    // Already gone.
  }
}

/// Decodes the first frame of [bytes], or returns `null` when Flutter cannot
/// decode it. The caller owns (and disposes) the image.
Future<ui.Image?> decodeAvatarImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  } on Object {
    return null;
  }
}

/// Draws the [source] square of [image] into a [size]-square PNG. Only pixels
/// go through the canvas, so no metadata (EXIF, GPS) from the original file
/// reaches the output.
Future<Uint8List> renderAvatarCrop(
  ui.Image image,
  Rect source, {
  int size = avatarOutputSize,
}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(size, size);
  picture.dispose();
  try {
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding failed.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    output.dispose();
  }
}

/// Lets the user drag and pinch [image] under a circular guide, then pops
/// with the cropped PNG bytes, or `null` on cancel. The screen paints its own
/// clone of [image] (it keeps painting through the pop animation), so the
/// caller may dispose [image] as soon as the route's future completes.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.image});

  final ui.Image image;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  static const _gutter = 24.0;
  static const _barSpace = 120.0;

  late final ui.Image _image = widget.image.clone();
  AvatarCropTransform? _transform;
  AvatarCropTransform? _gestureStart;
  Offset _focalStart = Offset.zero;
  // Both follow the layout; build refreshes them before gestures read them.
  Size _viewport = Size.zero;
  double _diameter = 1;
  bool _encoding = false;

  Size get _imageSize =>
      Size(_image.width.toDouble(), _image.height.toDouble());

  @override
  void dispose() {
    _image.dispose();
    super.dispose();
  }

  AvatarCropTransform _current() =>
      (_transform ?? AvatarCropTransform.initial(_imageSize, _diameter))
          .clamped(_imageSize, _diameter);

  Offset _fromCircleCentre(Offset local) =>
      local - _viewport.center(Offset.zero);

  Future<void> _done() async {
    setState(() => _encoding = true);
    try {
      final bytes = await renderAvatarCrop(
        _image,
        _current().sourceRect(_imageSize, _diameter),
      );
      if (mounted) Navigator.of(context).pop(bytes);
    } on Object {
      if (!mounted) return;
      setState(() => _encoding = false);
      _snack(context, 'Could not crop that photo. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          // Screen width minus the gutters, shrunk in landscape so the circle
          // clears the hint and the buttons.
          _diameter = math.max(
            1.0,
            math.min(
              _viewport.width - 2 * _gutter,
              _viewport.height - 2 * _barSpace,
            ),
          );
          final transform = _current();
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _encoding
                    ? null
                    : (details) {
                        _gestureStart = _current();
                        _focalStart = _fromCircleCentre(
                          details.localFocalPoint,
                        );
                      },
                onScaleUpdate: _encoding
                    ? null
                    : (details) {
                        final start = _gestureStart;
                        if (start == null) return;
                        setState(() {
                          _transform = start.gesture(
                            focalStart: _focalStart,
                            focal: _fromCircleCentre(details.localFocalPoint),
                            gestureScale: details.scale,
                            image: _imageSize,
                            diameter: _diameter,
                          );
                        });
                      },
                child: CustomPaint(
                  painter: _CropPainter(
                    image: _image,
                    transform: transform,
                    diameter: _diameter,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Drag and pinch to position your photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _encoding
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cancel'),
                          ),
                          if (_encoding)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: _done,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Done'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.transform,
    required this.diameter,
  });

  final ui.Image image;
  final AvatarCropTransform transform;
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width, height),
      Rect.fromCenter(
        center: centre + transform.offset,
        width: width * transform.scale,
        height: height * transform.scale,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final circle = Rect.fromCircle(center: centre, radius: diameter / 2);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(circle),
      Paint()..color = Colors.black.withValues(alpha: .6),
    );
    canvas.drawOval(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.transform != transform ||
      old.diameter != diameter;
}

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

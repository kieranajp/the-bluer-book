import 'dart:async';

import 'package:camera/camera.dart';

/// Direction of a detected horizontal hand wave.
enum WaveDirection { left, right }

/// Touchless hand-wave detector for cooking mode.
///
/// Opens the front camera at low resolution, streams luminance frames, and
/// looks for a hand sweeping horizontally across the field of view. It does
/// **not** identify a hand specifically — it tracks the centroid of frame-to-
/// frame motion and, when that centroid travels far enough along the dominant
/// horizontal axis in one continuous movement, reports a [WaveDirection].
///
/// This is intentionally lightweight (no ML model, ~144 luminance samples per
/// frame) so it runs on-device without extra assets. It is best-effort and
/// experimental: greasy-hands cooking ergonomics over pixel-perfect accuracy.
///
/// Because the camera buffer is in sensor coordinates (often rotated 90° in
/// portrait) and the front camera is mirrored, the detector measures movement
/// on whichever buffer axis shows the larger displacement, and the on-screen
/// "swap direction" toggle can flip [invertDirection] if next/previous feel
/// reversed on a given device.
class WaveGestureController {
  WaveGestureController({
    required this.onWave,
    this.onError,
    this.invertDirection = false,
  });

  /// Called on the main isolate when a horizontal wave is recognised.
  final void Function(WaveDirection direction) onWave;

  /// Called if the camera cannot be started (no camera, permission denied, …).
  final void Function(Object error)? onError;

  /// Flip the left/right mapping. Front cameras are mirrored and sensor
  /// orientation varies, so this lets the UI correct the mapping per device.
  bool invertDirection;

  CameraController? _controller;
  bool _starting = false;
  bool _disposed = false;

  // ── Motion-tracking state ────────────────────────────────────────────
  /// Sampling grid resolution (cells per axis). 12×12 = 144 luminance reads.
  static const int _grid = 12;

  /// Per-cell luminance delta (0–255) that counts as "this cell moved".
  static const double _cellThreshold = 22;

  /// Minimum number of moving cells before a frame is considered "active".
  static const int _minMovingCells = 5;

  /// Fraction of the frame width the centroid must travel for a wave (0–1).
  static const double _minTravelFraction = 0.30;

  /// Ignore frames closer together than this (caps CPU on high-fps cameras).
  static const Duration _minFrameGap = Duration(milliseconds: 45);

  /// Quiet period after firing so one wave isn't counted multiple times.
  static const Duration _cooldown = Duration(milliseconds: 1100);

  /// Drop a gesture-in-progress if it drags on longer than this.
  static const Duration _maxGestureDuration = Duration(milliseconds: 1600);

  List<int>? _prevGrid;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processing = false;

  // Centroid trail for the gesture currently in progress.
  double? _trailStartX;
  double? _trailStartY;
  double? _trailLastX;
  double? _trailLastY;
  DateTime? _trailStart;

  CameraController? get cameraController => _controller;
  bool get isRunning => _controller?.value.isStreamingImages ?? false;

  /// Starts the front camera and begins watching for waves. Safe to call when
  /// already running. Reports failures through [onError] rather than throwing.
  Future<void> start() async {
    if (_disposed || _starting || isRunning) return;
    _starting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No cameras available');
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        _controller = null;
        return;
      }
      _resetTrail();
      _prevGrid = null;
      await controller.startImageStream(_onFrame);
    } catch (e) {
      _controller = null;
      onError?.call(e);
    } finally {
      _starting = false;
    }
  }

  /// Stops the camera stream and releases the camera.
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _resetTrail();
    _prevGrid = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore — we're tearing down anyway.
    }
    await controller.dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }

  void _resetTrail() {
    _trailStartX = null;
    _trailStartY = null;
    _trailLastX = null;
    _trailLastY = null;
    _trailStart = null;
  }

  void _onFrame(CameraImage image) {
    if (_processing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame) < _minFrameGap) return;
    _lastFrame = now;
    if (now.difference(_lastFire) < _cooldown) return;

    _processing = true;
    try {
      final grid = _sampleLuminance(image);
      final prev = _prevGrid;
      _prevGrid = grid;
      if (prev == null) return;

      // Centroid of motion across the sampling grid.
      double massSum = 0;
      double sumX = 0;
      double sumY = 0;
      int movingCells = 0;
      for (var i = 0; i < grid.length; i++) {
        final diff = (grid[i] - prev[i]).abs().toDouble();
        if (diff < _cellThreshold) continue;
        movingCells++;
        massSum += diff;
        sumX += diff * (i % _grid);
        sumY += diff * (i ~/ _grid);
      }

      if (movingCells < _minMovingCells || massSum <= 0) {
        // Motion stopped — evaluate whatever trail we've accumulated.
        _evaluateTrail(now);
        return;
      }

      final cx = sumX / massSum;
      final cy = sumY / massSum;

      if (_trailStartX == null) {
        _trailStartX = cx;
        _trailStartY = cy;
        _trailStart = now;
      } else if (now.difference(_trailStart!) > _maxGestureDuration) {
        // Gesture took too long to be a flick — restart from here.
        _trailStartX = cx;
        _trailStartY = cy;
        _trailStart = now;
      }
      _trailLastX = cx;
      _trailLastY = cy;
    } finally {
      _processing = false;
    }
  }

  void _evaluateTrail(DateTime now) {
    final startX = _trailStartX;
    final startY = _trailStartY;
    final lastX = _trailLastX;
    final lastY = _trailLastY;
    _resetTrail();
    if (startX == null || lastX == null || startY == null || lastY == null) {
      return;
    }

    final dx = lastX - startX;
    final dy = lastY - startY;
    // Only treat it as a horizontal wave if movement is mostly sideways.
    if (dx.abs() <= dy.abs()) return;
    if (dx.abs() < _grid * _minTravelFraction) return;

    var movingRight = dx > 0;
    if (invertDirection) movingRight = !movingRight;
    _lastFire = now;
    onWave(movingRight ? WaveDirection.right : WaveDirection.left);
  }

  /// Samples a [_grid]×[_grid] luminance grid from the Y plane. Works for both
  /// Android (planar yuv420) and iOS (biplanar) since plane 0 is luminance and
  /// [Plane.bytesPerRow] accounts for row padding on each platform.
  List<int> _sampleLuminance(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final width = image.width;
    final height = image.height;
    final grid = List<int>.filled(_grid * _grid, 0);

    for (var gy = 0; gy < _grid; gy++) {
      final py = (((gy + 0.5) / _grid) * height).floor().clamp(0, height - 1);
      final rowOffset = py * rowStride;
      for (var gx = 0; gx < _grid; gx++) {
        final px = (((gx + 0.5) / _grid) * width).floor().clamp(0, width - 1);
        final idx = rowOffset + px;
        grid[gy * _grid + gx] = idx < bytes.length ? bytes[idx] : 0;
      }
    }
    return grid;
  }
}

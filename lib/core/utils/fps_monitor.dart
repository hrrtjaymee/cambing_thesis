import 'dart:ui';
import 'package:flutter/scheduler.dart';

/// FPS Monitor that logs frame rate to console
class FpsMonitor {
  static final FpsMonitor _instance = FpsMonitor._internal();
  factory FpsMonitor() => _instance;
  FpsMonitor._internal();

  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();
  bool _isMonitoring = false;

  /// Start monitoring FPS
  void start() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _frameCount = 0;
    _lastTime = DateTime.now();
    
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    print('📊 FPS monitoring started');
  }

  /// Stop monitoring FPS
  void stop() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    print('📊 FPS monitoring stopped');
  }

  void _onFrame(Duration timestamp) {
    if (!_isMonitoring) return;

    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);

    // Log FPS every second
    if (elapsed.inMilliseconds >= 1000) {
      final fps = (_frameCount / elapsed.inSeconds).toStringAsFixed(1);
      print('📊 FPS: $fps');
      
      _frameCount = 0;
      _lastTime = now;
    }
  }
}

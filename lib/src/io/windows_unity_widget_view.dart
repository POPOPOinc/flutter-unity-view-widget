import 'dart:developer' as developer;
import 'dart:ffi' hide Size;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'windows_unity_widget_bindings.dart';

class WindowsUnityWidgetView extends StatefulWidget {
  const WindowsUnityWidgetView({
    super.key,
    this.onUnityWindowReady,
  });

  /// Unityウィンドウの初期化が完了したときに呼ばれるコールバック。
  /// 引数はインスタンスID。
  final void Function(int instanceId)? onUnityWindowReady;

  @override
  State<WindowsUnityWidgetView> createState() => _WindowsUnityWidgetViewState();
}

class _WindowsUnityWidgetViewState extends State<WindowsUnityWidgetView>
    with AutomaticKeepAliveClientMixin {
  /// pause中のインスタンスIDプール（dispose時に返却し、再ビルド時に再利用する）
  static final List<int> _pausedInstances = [];

  /// 作成されたUnityインスタンスのID。0 なら未作成。
  int _instanceId = 0;

  /// 前回適用した物理ピクセル矩形（リサイズ検知用）
  Rect _lastPhysicalRect = Rect.zero;

  /// C++側に渡すコールバック（NativeCallable.listener で生成）
  NativeCallable<Void Function(Int32)>? _onUnityWindowReadyCallable;

  @override
  void initState() {
    super.initState();

    if (widget.onUnityWindowReady != null) {
      _onUnityWindowReadyCallable =
          NativeCallable<Void Function(Int32)>.listener(
              _onUnityWindowReadyNative);
      NativeBindings.setOnUnityWindowReady(
          _onUnityWindowReadyCallable!.nativeFunction);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createUnityWindowFromLayout();
    });
  }

  void _onUnityWindowReadyNative(int instanceId) {
    developer.log('[WindowsUnityWidgetView] Unity window ready: id=$instanceId');
    widget.onUnityWindowReady?.call(instanceId);
  }

  @override
  void dispose() {
    if (_onUnityWindowReadyCallable != null) {
      NativeBindings.setOnUnityWindowReady(nullptr);
      _onUnityWindowReadyCallable!.close();
      _onUnityWindowReadyCallable = null;
    }
    if (_instanceId != 0) {
      developer
          .log('[WindowsUnityWidgetView] Pausing Unity instance: id=$_instanceId');
      NativeBindings.pauseUnityWindow(_instanceId);
      _pausedInstances.add(_instanceId);
      _instanceId = 0;
    }
    super.dispose();
  }

  /// RenderBox からスクリーン上の物理ピクセル矩形を算出する。
  /// RenderBox が未準備なら null を返す。
  Rect? _computePhysicalRect() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Rect.fromLTRB(
      (offset.dx * dpr).roundToDouble(),
      (offset.dy * dpr).roundToDouble(),
      ((offset.dx + size.width) * dpr).roundToDouble(),
      ((offset.dy + size.height) * dpr).roundToDouble(),
    );
  }

  void _createUnityWindowFromLayout() {
    if (_instanceId != 0) return;

    final rect = _computePhysicalRect();
    if (rect == null) {
      developer.log(
          '[WindowsUnityWidgetView] RenderBox not ready, retrying next frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createUnityWindowFromLayout();
      });
      return;
    }

    // pause中のインスタンスがあれば再利用する
    if (_pausedInstances.isNotEmpty) {
      _instanceId = _pausedInstances.removeLast();
      developer.log(
          '[WindowsUnityWidgetView] Resuming Unity instance: id=$_instanceId, rect=$rect');
      NativeBindings.resumeUnityWindow(_instanceId);
      NativeBindings.resizeUnityWindow(
        _instanceId,
        rect.left.toInt(),
        rect.top.toInt(),
        rect.right.toInt(),
        rect.bottom.toInt(),
      );
      _lastPhysicalRect = rect;
      return;
    }

    developer.log('[WindowsUnityWidgetView] Creating Unity window: rect=$rect');
    _instanceId = NativeBindings.createUnityWindow(
      rect.left.toInt(),
      rect.top.toInt(),
      rect.right.toInt(),
      rect.bottom.toInt(),
    );
    _lastPhysicalRect = rect;
  }

  void _resizeUnityWindowIfNeeded() {
    if (_instanceId == 0) return;

    final rect = _computePhysicalRect();
    if (rect == null || rect == _lastPhysicalRect) return;

    // 最小化時にFlutterのビューが0x0になるが、Unityウィンドウを0x0にリサイズすると
    // D3Dスワップチェーンが壊れて復元後に描画されなくなるためスキップする。
    if (rect.width <= 0 || rect.height <= 0) return;

    developer.log(
        '[WindowsUnityWidgetView] Resizing Unity window: id=$_instanceId rect=$rect');
    NativeBindings.resizeUnityWindow(
      _instanceId,
      rect.left.toInt(),
      rect.top.toInt(),
      rect.right.toInt(),
      rect.bottom.toInt(),
    );
    _lastPhysicalRect = rect;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // レイアウト完了後にリサイズを検知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resizeUnityWindowIfNeeded();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: const _NativeWindowPlaceholder(),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _NativeWindowPlaceholder extends CustomPainter {
  const _NativeWindowPlaceholder();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0x00000000),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

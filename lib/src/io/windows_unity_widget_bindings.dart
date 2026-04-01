import 'dart:ffi';

// int32_t FlutterUnityWidgetCreateUnityWindow(int32_t, int32_t, int32_t, int32_t)
typedef _CreateUnityWindowC = Int32 Function(
    Int32 left, Int32 top, Int32 right, Int32 bottom);
typedef _CreateUnityWindowDart = int Function(
    int left, int top, int right, int bottom);

// void FlutterUnityWidgetDisposeUnityWindow(int32_t)
typedef _DisposeUnityWindowC = Void Function(Int32 id);
typedef _DisposeUnityWindowDart = void Function(int id);

// void FlutterUnityWidgetResizeUnityWindow(int32_t, int32_t, int32_t, int32_t, int32_t)
typedef _ResizeUnityWindowC = Void Function(
    Int32 id, Int32 left, Int32 top, Int32 right, Int32 bottom);
typedef _ResizeUnityWindowDart = void Function(
    int id, int left, int top, int right, int bottom);

// void FlutterUnityWidgetSetOnUnityWindowReady(void (*callback)(int32_t))
typedef _SetOnUnityWindowReadyC = Void Function(
    Pointer<NativeFunction<Void Function(Int32)>> callback);
typedef _SetOnUnityWindowReadyDart = void Function(
    Pointer<NativeFunction<Void Function(Int32)>> callback);

// void FlutterUnityWidgetPauseUnityWindow(int32_t)
typedef _PauseUnityWindowC = Void Function(Int32 id);
typedef _PauseUnityWindowDart = void Function(int id);

// void FlutterUnityWidgetResumeUnityWindow(int32_t)
typedef _ResumeUnityWindowC = Void Function(Int32 id);
typedef _ResumeUnityWindowDart = void Function(int id);

final class NativeBindings {
  NativeBindings._();

  static final DynamicLibrary _lib = DynamicLibrary.process();

  /// 指定矩形のUnity子ウインドウを作成する。
  /// 戻り値はインスタンスID（int32_t）。失敗時は0。
  static final _CreateUnityWindowDart createUnityWindow = _lib
      .lookupFunction<_CreateUnityWindowC, _CreateUnityWindowDart>(
          'FlutterUnityWidgetCreateUnityWindow');

  /// Unity子ウインドウを破棄する。
  static final _DisposeUnityWindowDart disposeUnityWindow = _lib
      .lookupFunction<_DisposeUnityWindowC, _DisposeUnityWindowDart>(
          'FlutterUnityWidgetDisposeUnityWindow');

  /// Unity子ウインドウをリサイズする。
  static final _ResizeUnityWindowDart resizeUnityWindow = _lib
      .lookupFunction<_ResizeUnityWindowC, _ResizeUnityWindowDart>(
          'FlutterUnityWidgetResizeUnityWindow');

  /// Unityウィンドウ準備完了コールバックを登録する。
  static final _SetOnUnityWindowReadyDart setOnUnityWindowReady = _lib
      .lookupFunction<_SetOnUnityWindowReadyC, _SetOnUnityWindowReadyDart>(
          'FlutterUnityWidgetSetOnUnityWindowReady');

  /// Unityを一時停止する。
  static final _PauseUnityWindowDart pauseUnityWindow = _lib
      .lookupFunction<_PauseUnityWindowC, _PauseUnityWindowDart>(
          'FlutterUnityWidgetPauseUnityWindow');

  /// Unityを再開する。
  static final _ResumeUnityWindowDart resumeUnityWindow = _lib
      .lookupFunction<_ResumeUnityWindowC, _ResumeUnityWindowDart>(
          'FlutterUnityWidgetResumeUnityWindow');
}

import '../facade_controller.dart';
import 'windows_unity_widget_bindings.dart';

class WindowsUnityWidgetController extends UnityWidgetController {
  final int unityId;
  bool _paused = false;

  WindowsUnityWidgetController._({required this.unityId});

  @override
  Future<bool?>? isReady() => Future.value(true);

  @override
  Future<bool?>? isPaused() => Future.value(_paused);

  @override
  Future<bool?>? isLoaded() => Future.value(true);

  @override
  Future<bool?>? inBackground() => Future.value(false);

  @override
  Future<bool?>? create() => Future.value(true);

  @override
  Future<void>? pause() {
    NativeBindings.pauseUnityWindow(unityId);
    _paused = true;
    return Future.value();
  }

  @override
  Future<void>? resume() {
    NativeBindings.resumeUnityWindow(unityId);
    _paused = false;
    return Future.value();
  }

  @override
  Future<void>? postMessage(String gameObject, methodName, message) {
    throw UnsupportedError('postMessage is not supported on Windows');
  }

  @override
  Future<void>? postJsonMessage(
      String gameObject, String methodName, Map<String, dynamic> message) {
    throw UnsupportedError('postJsonMessage is not supported on Windows');
  }

  @override
  Future<void>? openInNativeProcess() {
    throw UnsupportedError('openInNativeProcess is not supported on Windows');
  }

  @override
  Future<void>? unload() {
    throw UnsupportedError('unload is not supported on Windows');
  }

  @override
  Future<void>? quit() {
    throw UnsupportedError('quit is not supported on Windows');
  }

  @override
  void dispose() {
    NativeBindings.disposeUnityWindow(unityId);
  }
}

//
//  FLTUnityViewController.swift
//  flutter_unity_widget
//
//  Created by Rex Raphael on 30/01/2021.
//

import Foundation
import UnityFramework

// Defines unity controllable from Flutter.
public class FLTUnityWidgetController: NSObject, FLTUnityOptionsSink, FlutterPlatformView {
    private var _rootView: FLTUnityView
    private var viewId: Int64 = 0
    private var channel: FlutterMethodChannel?
    private weak var registrar: (NSObjectProtocol & FlutterPluginRegistrar)?

    private var _disposed = false

    // Use shared logger
    private let logger = UnityLogger.shared

    // Convenience logging methods
    private func logInfo(_ message: String) {
        logger.info(message, category: "iOS-Controller")
    }

    private func logWarning(_ message: String) {
        logger.warning(message, category: "iOS-Controller")
    }

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        registrar: NSObjectProtocol & FlutterPluginRegistrar
    ) {
        self._rootView = FLTUnityView(frame: frame)
        super.init()

        globalControllers.append(self)

        self.viewId = viewId

        let channelName = String(format: "plugin.xraph.com/unity_view_%lld", viewId)
        self.channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())

        self.channel?.setMethodCallHandler(self.methodHandler)
        self.attachView()
    }

    func methodHandler(_ call: FlutterMethodCall, result: FlutterResult) {
        logInfo("[FLTUnityWidgetController] 📞 methodHandler() CALLED - called method: \(call.method)")
        if call.method == "unity#dispose" {
            self.dispose()
            result(nil)
        } else {
            self.reattachView()
            if call.method == "unity#isReady" {
                result(GetUnityPlayerUtils().unityIsInitiallized())
            } else if call.method == "unity#isLoaded" {
                let _isUnloaded = GetUnityPlayerUtils().isUnityLoaded()
                result(_isUnloaded)
            } else if call.method == "unity#createUnityPlayer" {
                startUnityIfNeeded {
                    // Unity初期化完了後の処理が必要であればここに追加
                }
                result(nil)
            } else if call.method == "unity#isPaused" {
                let _isPaused = GetUnityPlayerUtils().isUnityPaused()
                result(_isPaused)
            } else if call.method == "unity#pausePlayer" {
                GetUnityPlayerUtils().pause()
                result(nil)
            } else if call.method == "unity#postMessage" {
                self.postMessage(call: call, result: result)
                result(nil)
            } else if call.method == "unity#resumePlayer" {
                GetUnityPlayerUtils().resume()
                result(nil)
            } else if call.method == "unity#unloadPlayer" {
                GetUnityPlayerUtils().unload()
                result(nil)
            } else if call.method == "unity#quitPlayer" {
                GetUnityPlayerUtils().quit()
                result(nil)
            } else if call.method == "unity#waitForUnity" {
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func setDisabledUnload(enabled: Bool) {

    }

    public func view() -> UIView {
        return _rootView;
    }

    private func startUnityIfNeeded(onCompleted: @escaping () -> Void) {
        logInfo("[FLTUnityWidgetController] 🎬 startUnityIfNeeded() CALLED")
        logInfo("[FLTUnityWidgetController] 🎬 About to call createPlayer() - this is ASYNC!")

        GetUnityPlayerUtils().createPlayer(completed: { [self] (view: UIView?) in
            self.logInfo("[FLTUnityWidgetController] 🎬 createPlayer completed() callback received")
            self.logInfo("[FLTUnityWidgetController] 🎬 Received view: \(view != nil ? "not nil" : "nil")")

            // Unityプレイヤーの初期化が完了したので、完了ハンドラを呼び出す
            self.logInfo("[FLTUnityWidgetController] 🎬 Calling onCompleted handler...")
            onCompleted()
            self.logInfo("[FLTUnityWidgetController] 🎬 onCompleted handler finished")
        })

        logInfo("[FLTUnityWidgetController] 🎬 createPlayer() call returned (but NOT completed yet!)")
    }

    func attachView() {
        logInfo("[FLTUnityWidgetController] 🔗 attachView() START - Thread: \(Thread.current)")
        logInfo("[FLTUnityWidgetController] 🔗 Unity state: isInitialized=\(GetUnityPlayerUtils().unityIsInitiallized()), isPaused=\(GetUnityPlayerUtils().isUnityPaused())")

        logInfo("[FLTUnityWidgetController] 🔗 Step 1: Calling startUnityIfNeeded()...")
        startUnityIfNeeded { [weak self] in
            guard let self = self else { return }

            self.logInfo("[FLTUnityWidgetController] 🔗 Step 1: startUnityIfNeeded() COMPLETED!")

            // 既に呼ばれていたらスキップ
            if alreadySuperviewAttached() {
                self.logInfo("[FLTUnityWidgetController] 🎬 completed() already called once, skipping this invocation")
                return
            }

            self.logInfo("[FLTUnityWidgetController] 🔗 Step 2: Getting rootView from Unity...")
            let unityView = GetUnityPlayerUtils().ufw?.appController()?.rootView
            self.logInfo("[FLTUnityWidgetController] 🔗 Step 2: rootView = \(unityView != nil ? "not nil" : "nil")")

            if let superview = unityView?.superview {
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 3: Removing from existing superview...")
                unityView?.removeFromSuperview()
                superview.layoutIfNeeded()
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 3: Removed from superview")
            } else {
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 3: No existing superview")
            }

            if let unityView = unityView {
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 4: Adding unityView to _rootView...")
                self._rootView.addSubview(unityView)
                self._rootView.layoutIfNeeded()
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 4: Added to _rootView and layout updated")

                self.logInfo("[FLTUnityWidgetController] 🔗 Step 5: Invoking onViewReattached event...")
                self.channel?.invokeMethod("events#onViewReattached", arguments: "")
                self.logInfo("[FLTUnityWidgetController] 🔗 Step 5: onViewReattached event sent")
            } else {
                self.logWarning("[FLTUnityWidgetController] ⚠️ Step 4: unityView is nil, cannot add to _rootView!")
            }

            self.logInfo("[FLTUnityWidgetController] 🔗 Step 6: Calling resume()...")
            GetUnityPlayerUtils().resume()
            self.logInfo("[FLTUnityWidgetController] 🔗 Step 6: resume() called")

            self.logInfo("[FLTUnityWidgetController] 🔗 attachView() END")
        }

        logInfo("[FLTUnityWidgetController] 🔗 attachView() initiated, waiting for Unity initialization...")
    }

    func alreadySuperviewAttached() -> Bool {
        let unityView = GetUnityPlayerUtils().ufw?.appController()?.rootView
        let superview = unityView?.superview

        logInfo("[FLTUnityWidgetController] 🔄 Current superview: \(superview != nil ? "exists" : "nil"), _rootView: \(_rootView)")
        return superview == _rootView
    }

    func reattachView() {
        logInfo("[FLTUnityWidgetController] 🔄 reattachView() CALLED")
        
        if alreadySuperviewAttached() {
            logInfo("[FLTUnityWidgetController] 🔄 Superview matches, skipping attachView()")
        } else {
            logInfo("[FLTUnityWidgetController] 🔄 Superview mismatch, calling attachView()")
            attachView()
        }

        logInfo("[FLTUnityWidgetController] 🔄 Calling resume()...")
        GetUnityPlayerUtils().resume()
        logInfo("[FLTUnityWidgetController] 🔄 reattachView() END")
    }

    func removeViewIfNeeded() {
        if GetUnityPlayerUtils().ufw == nil {
            return
        }

        let unityView = GetUnityPlayerUtils().ufw?.appController()?.rootView
        if _rootView == unityView?.superview {
            if globalControllers.isEmpty {
                unityView?.removeFromSuperview()
                unityView?.superview?.layoutIfNeeded()
            } else {
                globalControllers.last?.reattachView()
            }
        }
        GetUnityPlayerUtils().resume()
    }

    func dispose() {
        if _disposed {
            return
        }

        globalControllers.removeAll{ value in
            return value == self
        }

        channel?.setMethodCallHandler(nil)
        removeViewIfNeeded()
        
        _disposed = true
    }
    
    /// Handles messages from unity in the current view
    func handleMessage(message: String) {
        self.channel?.invokeMethod("events#onUnityMessage", arguments: message)
    }
    
    
    /// Handles scene changed event from unity in the current view
    func handleSceneChangeEvent(info: Dictionary<String, Any>) {
        self.channel?.invokeMethod("events#onUnitySceneLoaded", arguments: info)
    }
    
    /// Post messages to unity from flutter
    func postMessage(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments else {
            result("iOS could not recognize flutter arguments in method: (postMessage)")
            return
        }

        if let myArgs = args as? [String: Any],
           let gObj = myArgs["gameObject"] as? String,
           let method = myArgs["methodName"] as? String,
           let message = myArgs["message"] as? String {
            GetUnityPlayerUtils().postMessageToUnity(gameObject: gObj, unityMethodName: method, unityMessage: message)
            result(nil)
        } else {
            result(FlutterError(code: "-1", message: "iOS could not extract " +
                   "flutter arguments in method: (postMessage)", details: nil))
        }
    }
}

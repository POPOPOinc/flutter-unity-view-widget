//
//  UnityPlayerUtils.swift
//  flutter_unity_widget
//
//  Created by Rex Raphael on 30/01/2021.
//

import Foundation
import UnityFramework
import os.log

private var unity_warmed_up = false
// Hack to work around iOS SDK 4.3 linker problem
// we need at least one __TEXT, __const section entry in main application .o files
// to get this section emitted at right time and so avoid LC_ENCRYPTION_INFO size miscalculation
private let constsection = 0

// keep arg for unity init from non main
var gArgc: Int32 = 0
var gArgv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>? = nil
var appLaunchOpts: [UIApplication.LaunchOptionsKey: Any]? = [:]

/***********************************PLUGIN_ENTRY STARTS**************************************/
public func InitUnityIntegration(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) {
    gArgc = argc
    gArgv = argv
}

public func InitUnityIntegrationWithOptions(
    argc: Int32,
    argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
    _ launchingOptions:  [UIApplication.LaunchOptionsKey: Any]?) {
    gArgc = argc
    gArgv = argv
    appLaunchOpts = launchingOptions
}
/***********************************PLUGIN_ENTRY END**************************************/

// Load unity framework for fisrt run
func UnityFrameworkLoad() -> UnityFramework? {
    var bundlePath: String? = nil
    bundlePath = Bundle.main.bundlePath
    bundlePath = (bundlePath ?? "") + "/Frameworks/UnityFramework.framework"

    let bundle = Bundle(path: bundlePath ?? "")
    if bundle?.isLoaded == false {
        bundle?.load()
    }

    return bundle?.principalClass?.getInstance()
}

/*********************************** GLOBAL FUNCS & VARS START**************************************/
public var globalControllers: Array<FLTUnityWidgetController> = [FLTUnityWidgetController]()

private var unityPlayerUtils: UnityPlayerUtils? = nil
func GetUnityPlayerUtils() -> UnityPlayerUtils {

    if unityPlayerUtils == nil {
        unityPlayerUtils = UnityPlayerUtils()
    }

    return unityPlayerUtils ?? UnityPlayerUtils()
}

/*********************************** GLOBAL FUNCS & VARS END****************************************/

var controller: UnityAppController?
var sharedApplication: UIApplication?

@objc protocol UnityEventListener: AnyObject {

    func onReceiveMessage(_ message: UnsafePointer<Int8>?)

}

@objc public class UnityPlayerUtils: UIResponder, UIApplicationDelegate, UnityFrameworkListener {
    var ufw: UnityFramework!
    private var _isUnityPaused = false
    private var _isUnityReady = false
    private var _isUnityLoaded = false

    // Logger for Unity lifecycle events
    private let logger = Logger(subsystem: "com.xraph.plugin.flutter_unity_widget", category: "UnityLifecycle")

    // File logging setup
    private let logQueue = DispatchQueue(label: "com.xraph.plugin.flutter_unity_widget.logQueue")
    private var logFilePath: String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("app_logs.txt").path
    }

    // Write log to app_logs.txt file
    private func writeToLogFile(_ message: String) {
        guard let filePath = logFilePath else {
            return
        }

        logQueue.async {
            // Format timestamp to match Flutter's DateTime.now().toString() format
            // "2026-02-04 18:21:17.828440"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
            formatter.timeZone = TimeZone.current
            let timestamp = formatter.string(from: Date())
            let logEntry = "\(timestamp)[Info][iOS-Unity]\(message)\n\n"

            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: filePath) {
                    if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    // File doesn't exist yet, create it
                    try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
                }
            }
        }
    }

    // Unified logging method (Logger + print + file)
    private func logInfo(_ message: String) {
        logger.info("\(message)")
        print(message)
        writeToLogFile(message)
    }

    // Unified warning logging method
    private func logWarning(_ message: String) {
        logger.warning("\(message)")
        print(message)
        writeToLogFile(message)
    }

    func initUnity() {
        if (self.unityIsInitiallized()) {
            self.ufw?.showUnityWindow()
            return
        }

        self.ufw = UnityFrameworkLoad()

        self.ufw?.setDataBundleId("com.unity3d.framework")

        registerUnityListener()
        self.ufw?.runEmbedded(withArgc: gArgc, argv: gArgv, appLaunchOpts: appLaunchOpts)

        if self.ufw?.appController() != nil {
            controller = self.ufw?.appController()
            controller?.unityMessageHandler = self.unityMessageHandlers
            controller?.unitySceneLoadedHandler = self.unitySceneLoadedHandlers
            self.ufw?.appController()?.window?.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue - 1)
        }
        _isUnityLoaded = true
    }

    // check if unity is initiallized
    func unityIsInitiallized() -> Bool {
        if self.ufw != nil {
            return true
        }

        return false
    }

    // Create new unity player
    func createPlayer(completed: @escaping (_ view: UIView?) -> Void) {
        if self.unityIsInitiallized() && self._isUnityReady {
            completed(controller?.rootView)
            return
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("UnityReady"), object: nil, queue: OperationQueue.main, using: { note in
            self._isUnityReady = true
            completed(controller?.rootView)
        })

        DispatchQueue.main.async {
//            if (sharedApplication == nil) {
//                sharedApplication = UIApplication.shared
//            }

            // Always keep Flutter window on top
//            let flutterUIWindow = sharedApplication?.keyWindow
//            flutterUIWindow?.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue + 1) // Always keep Flutter window in top
//            sharedApplication?.keyWindow?.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue + 1)

            self.initUnity()

            unity_warmed_up = true
            self._isUnityReady = true
            self._isUnityLoaded = true

            self.listenAppState()

            completed(controller?.rootView)
        }

    }

    func registerUnityListener() {
        if self.unityIsInitiallized() {
            self.ufw?.register(self)
        }
    }

    func unregisterUnityListener() {
        if self.unityIsInitiallized() {
            self.ufw?.unregisterFrameworkListener(self)
        }
    }

    @objc
    public func unityDidUnload(_ notification: Notification!) {
        unregisterUnityListener()
        self.ufw = nil
        self._isUnityReady = false
        self._isUnityLoaded = false
    }

    @objc func handleAppStateDidChange(notification: Notification?) {
        if !self._isUnityReady {
            return
        }

        let unityAppController = self.ufw?.appController() as? UnityAppController
        let application = UIApplication.shared

        if notification?.name == UIApplication.willResignActiveNotification {
            logInfo("🔴 [Unity Lifecycle] applicationWillResignActive - About to call Unity pause")
            unityAppController?.applicationWillResignActive(application)
            logInfo("🔴 [Unity Lifecycle] applicationWillResignActive - Completed")
        } else if notification?.name == UIApplication.didEnterBackgroundNotification {
            logInfo("🔵 [Unity Lifecycle] applicationDidEnterBackground")
            unityAppController?.applicationDidEnterBackground(application)
        } else if notification?.name == UIApplication.willEnterForegroundNotification {
            logInfo("🟢 [Unity Lifecycle] applicationWillEnterForeground")
            unityAppController?.applicationWillEnterForeground(application)
        } else if notification?.name == UIApplication.didBecomeActiveNotification {
            logInfo("🟢 [Unity Lifecycle] applicationDidBecomeActive - About to call Unity resume")
            unityAppController?.applicationDidBecomeActive(application)
            logInfo("🟢 [Unity Lifecycle] applicationDidBecomeActive - Completed")
        } else if notification?.name == UIApplication.willTerminateNotification {
            logInfo("⚫️ [Unity Lifecycle] applicationWillTerminate")
            unityAppController?.applicationWillTerminate(application)
        } else if notification?.name == UIApplication.didReceiveMemoryWarningNotification {
            logWarning("⚠️ [Unity Lifecycle] applicationDidReceiveMemoryWarning")
            unityAppController?.applicationDidReceiveMemoryWarning(application)
        }
    }


    // Listener for app lifecycle eventa
    func listenAppState() {
        for name in [
            UIApplication.didBecomeActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willTerminateNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.didReceiveMemoryWarningNotification
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleAppStateDidChange),
                name: name,
                object: nil)
        }
    }
    // Pause unity player
    func pause() {
        logInfo("🔴 [Unity Control] pause() called - Current state: isPaused=\(self._isUnityPaused)")
        self.ufw?.pause(true)
        self._isUnityPaused = true
        logInfo("🔴 [Unity Control] pause() completed - New state: isPaused=\(self._isUnityPaused)")
    }

    // Resume unity player
    func resume() {
        logInfo("🟢 [Unity Control] resume() called - Current state: isPaused=\(self._isUnityPaused)")
        self.ufw?.pause(false)
        self._isUnityPaused = false
        logInfo("🟢 [Unity Control] resume() completed - New state: isPaused=\(self._isUnityPaused)")
    }

    // Unoad unity player
    func unload() {
        self.ufw?.unloadApplication()
    }

    func isUnityLoaded() -> Bool {
        return _isUnityLoaded
    }

    func isUnityPaused() -> Bool {
        return _isUnityPaused
    }

    // Quit unity player application
    func quit() {
        self.ufw?.quitApplication(0)
        self._isUnityLoaded = false
    }

    // Post message to unity
    func postMessageToUnity(gameObject: String?, unityMethodName: String?, unityMessage: String?) {
        if self.unityIsInitiallized() {
            self.ufw?.sendMessageToGO(withName: gameObject, functionName: unityMethodName, message: unityMessage)
        }
    }

    /// Handle incoming unity messages looping through all controllers and passing payload to
    /// the controller handler methods
    @objc
    func unityMessageHandlers(_ message: UnsafePointer<Int8>?) {
        for c in globalControllers {
            if let strMsg = message {
                c.handleMessage(message: String(utf8String: strMsg) ?? "")
            } else {
                c.handleMessage(message: "")
            }
        }
    }

    func unitySceneLoadedHandlers(name: UnsafePointer<Int8>?, buildIndex: UnsafePointer<Int32>?, isLoaded: UnsafePointer<Bool>?, isValid: UnsafePointer<Bool>?) {
        if let sceneName = name,
           let bIndex = buildIndex,
           let loaded = isLoaded,
           let valid = isValid {

            let loadedVal = Bool((Int(bitPattern: loaded) != 0))
            let validVal = Bool((Int(bitPattern: valid) != 0))

            let addObject: Dictionary<String, Any> = [
                "name": String(utf8String: sceneName) ?? "",
                "buildIndex": Int(bitPattern: bIndex),
                "isLoaded": loadedVal,
                "isValid": validVal,
            ]

            for c in globalControllers {
                c.handleSceneChangeEvent(info: addObject)
            }
        }
    }
}

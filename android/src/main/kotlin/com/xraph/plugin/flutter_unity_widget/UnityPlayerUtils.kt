package com.xraph.plugin.flutter_unity_widget

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewGroup.LayoutParams
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.WindowManager
import android.widget.FrameLayout
import com.unity3d.player.IUnityPlayerLifecycleEvents
import com.unity3d.player.UnityPlayer
import java.util.concurrent.CopyOnWriteArraySet


class UnityPlayerUtils {

    companion object {
        private const val LOG_TAG = "UnityPlayerUtils"

        var controllers: ArrayList<FlutterUnityWidgetController> = ArrayList()
        var unityFrameLayout: FrameLayout? = null
        var unityPlayer: CustomUnityPlayer? = null
        var activity: Activity? = null
        var prevActivityRequestedOrientation: Int? = null

        var options: FlutterUnityWidgetOptions = FlutterUnityWidgetOptions()

        var unityPaused: Boolean = false
        var unityLoaded: Boolean = false
        var viewStaggered: Boolean = false

        private val mUnityEventListeners = CopyOnWriteArraySet<UnityEventListener>()

        // In 2023+ we can no longer override the UnityPlayer Framelayout (onAttachedToWindow).
        private val unityAttachListener = object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) {
                Log.i(LOG_TAG, "[DIAG] onAttachedToWindow: paused=$unityPaused loaded=$unityLoaded staggered=$viewStaggered parent=${view.parent?.javaClass?.simpleName}")
                UnityPlayerUtils.resume()
                UnityPlayerUtils.pause()
                UnityPlayerUtils.resume()
                Log.i(LOG_TAG, "[DIAG] onAttachedToWindow: triple cycle done, paused=$unityPaused")
            }

            override fun onViewDetachedFromWindow(view: View) {
                Log.i(LOG_TAG, "[DIAG] onDetachedFromWindow: paused=$unityPaused loaded=$unityLoaded")
            }
        }

        fun focus() {
            try {
                val focusResult = unityFrameLayout!!.requestFocus()
                Log.i(LOG_TAG, "[DIAG] focus: requestFocus=$focusResult paused=$unityPaused")
                unityPlayer!!.windowFocusChanged(focusResult)
                unityPlayer!!.resume()
                unityPaused = false
                Log.i(LOG_TAG, "[DIAG] focus: resume called, paused=$unityPaused")
            } catch (e: Exception) {
                Log.e(LOG_TAG, "[DIAG] focus: EXCEPTION $e")
            }
        }

        /**
         * Create a new unity player with callback
         */
        @SuppressLint("NewApi")
        fun createUnityPlayer(ule: IUnityPlayerLifecycleEvents, callback: OnCreateUnityViewCallback?) {
            if (activity == null) {
                throw java.lang.Exception("Unity activity is null")
            }

            if (unityFrameLayout != null) {
                unityLoaded = true
                unityFrameLayout!!.bringToFront()
                unityFrameLayout!!.requestLayout()
                unityFrameLayout!!.invalidate()
                focus()
                callback?.onReady()
                return
            }

            try {
                unityPlayer = CustomUnityPlayer(activity!!, ule)
                unityFrameLayout = unityPlayer!!.getFrameLayout()

                // Assign mUnityPlayer in the Activity, see FlutterUnityActivity.kt for more details
                if(activity is FlutterUnityActivity) {
                    (activity!! as FlutterUnityActivity)?.mUnityPlayer = (unityPlayer as java.lang.Object?);
                } else if(activity is IFlutterUnityActivity) {
                    (activity!! as IFlutterUnityActivity)?.setUnityPlayer(unityPlayer as java.lang.Object?);
                } else {
                     Log.e(LOG_TAG, "Could not set mUnityPlayer in activity");
                }
                

                // unityPlayer!!.z = (-1).toFloat()
                // addUnityViewToBackground(activity!!)
                unityLoaded = true

                // add onAttachedToWindow events
                addUnityAttachListener()

                if (!options.fullscreenEnabled) {
                    activity!!.window.addFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN);
                    activity!!.window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
                } else {
                    activity!!.window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
                }

                focus()
                callback?.onReady()
            } catch (e: Exception) {
                Log.e(LOG_TAG, e.toString())
            }
        }

        fun postMessage(gameObject: String, methodName: String, message: String) {
            UnityPlayer.UnitySendMessage(gameObject, methodName, message)
        }

        fun pause() {
            try {
                if (unityPlayer != null) {
                    unityPlayer!!.pause()
                    unityPaused = true
                }
            } catch (e: Exception) {
                Log.e(LOG_TAG, e.toString())
            }
        }

        fun resume() {
            try {
                if (unityPlayer != null) {
                    unityPlayer!!.resume()
                    unityPaused = false
                }
            } catch (e: Exception) {
                Log.e(LOG_TAG, e.toString())
            }
        }

        fun unload() {
            try {
                if (unityPlayer != null) {
                    unityPlayer!!.unload()
                    unityLoaded = false
                }
            } catch (e: Exception) {
                Log.e(LOG_TAG, e.toString())
            }
        }

        fun quitPlayer() {
            try {
                if (unityPlayer != null) {
                    removeUnityAttachListener()
                    unityPlayer!!.destroy()
                    unityLoaded = false
                }
            } catch (e: Error) {
                e.message?.let { Log.e(LOG_TAG, it) }
            }
        }

        /**
         * Invoke by unity C#
         */
        @JvmStatic
        fun onUnitySceneLoaded(name: String, buildIndex: Int, isLoaded: Boolean, isValid: Boolean) {
            for (listener in mUnityEventListeners) {
                try {
                    listener.onSceneLoaded(name, buildIndex, isLoaded, isValid)
                } catch (e: Exception) {
                    e.message?.let { Log.e(LOG_TAG, it) }
                }
            }
        }

        /**
         * Invoke by unity C#
         */
        @JvmStatic
        fun onUnityMessage(message: String) {
            // Log.d("UnityListener", "total listeners are ${mUnityEventListeners.size}")
            for (listener in mUnityEventListeners) {
                try {
                    listener.onMessage(message)
                } catch (e: Exception) {
                    e.message?.let { Log.e(LOG_TAG, it) }
                }
            }
        }

        fun addUnityEventListener(listener: UnityEventListener) {
            mUnityEventListeners.add(listener)
        }

        fun removeUnityEventListener(listener: UnityEventListener) {
            mUnityEventListeners.remove(listener)
        }

        private fun addUnityAttachListener() {
            unityFrameLayout?.addOnAttachStateChangeListener(unityAttachListener)
        }

        private fun removeUnityAttachListener() {
            unityFrameLayout?.removeOnAttachStateChangeListener(unityAttachListener)
        }

        private fun shakeActivity() {
            unityPlayer?.windowFocusChanged(true)
            if (prevActivityRequestedOrientation != null) {
                activity?.requestedOrientation = prevActivityRequestedOrientation!!
            }
        }

        fun removePlayer(controller: FlutterUnityWidgetController) {
            val isParent = unityFrameLayout!!.parent == controller.view
            Log.i(LOG_TAG, "[DIAG] removePlayer: isParent=$isParent remainingControllers=${controllers.size} paused=$unityPaused")
            if (isParent) {
                if (controllers.isEmpty()) {
                    (controller.view as FrameLayout).removeView(unityFrameLayout)
                    pause()
                    shakeActivity()
                    Log.i(LOG_TAG, "[DIAG] removePlayer: removed+paused, paused=$unityPaused staggered=$viewStaggered")
                } else {
                    controllers[controllers.size - 1].reattachToView()
                }
            }
        }

        fun reset() {
            unityLoaded = false
        }

        fun addUnityViewToGroup(group: ViewGroup) {
             val layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT)
//             val layoutParams = ViewGroup.LayoutParams(LayoutParams.FILL_PARENT, LayoutParams.FILL_PARENT)
//            val layoutParams = ViewGroup.LayoutParams(570, 770)
            group.addView(unityFrameLayout, layoutParams)
        }

        fun addUnityViewToBackground() {
            if (unityFrameLayout == null) {
                return
            }
            if (unityFrameLayout!!.parent != null) {
                (unityFrameLayout!!.parent as ViewGroup).removeView(unityFrameLayout)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                unityFrameLayout!!.z = -1f
            }
            val layoutParams = ViewGroup.LayoutParams(1, 1)
            activity!!.addContentView(unityFrameLayout, layoutParams)
        }
    }
}
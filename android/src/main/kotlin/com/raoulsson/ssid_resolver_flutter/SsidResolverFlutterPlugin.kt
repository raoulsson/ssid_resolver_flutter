package com.raoulsson.ssid_resolver_flutter

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.raoulsson.ssidresolverandroid.core.PermissionHandler
import com.raoulsson.ssidresolverandroid.core.PermissionHandler.Companion.PERMISSION_REQUEST_CODE
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SsidResolverFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private lateinit var coreResolver: CoreSSIDResolver
  private lateinit var permissionHandler: PermissionHandler
  private val scope = CoroutineScope(Dispatchers.Main)
  private var pendingResult: Result? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ssid_resolver_flutter")
    channel.setMethodCallHandler(this)
    permissionHandler = PermissionHandler(flutterPluginBinding.applicationContext)
    coreResolver = CoreSSIDResolver(flutterPluginBinding.applicationContext, permissionHandler)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "checkPermissionStatus" -> checkPermissionStatus(result)
      "requestPermission" -> requestPermission(result)
      "fetchSsid" -> fetchSsid(result)
      else -> result.notImplemented()
    }
  }

  private fun checkPermissionStatus(result: Result) {
    val currentPermissions = activity?.let { ContextCompat.checkSelfPermission(it, Manifest.permission.ACCESS_FINE_LOCATION) }
    val response = mapOf(
      "status" to if (currentPermissions == PackageManager.PERMISSION_GRANTED) "All permissions granted" else "Some permissions denied",
      "grantedPermissions" to permissionHandler.listGrantedPermissions(),
      "deniedPermissions" to permissionHandler.listDeniedPermissions(),
      "errorMessage" to null
    )
    result.success(response)
  }

  private fun requestPermission(result: Result) {
    if (activity == null) {
      result.error("NO_ACTIVITY", "Activity not attached", null)
      return
    }

    pendingResult = result
    val currentPermissions = permissionHandler.listGrantedPermissions()

    if (currentPermissions.containsAll(PermissionHandler.requiredPermissions)) {
      val response = mapOf(
        "status" to "Permissions granted",
        "grantedPermissions" to currentPermissions,
        "deniedPermissions" to emptyList<String>(),
        "errorMessage" to null
      )
      result.success(response)
      return
    }

    ActivityCompat.requestPermissions(
      activity!!,
      PermissionHandler.requiredPermissions.toTypedArray(),
      PERMISSION_REQUEST_CODE
    )
  }

  private fun fetchSsid(result: Result) {
    scope.launch {
      try {
        if (!permissionHandler.hasRequiredPermissions()) {
          result.error("PERMISSION_DENIED", "Required permissions not granted", null)
          return@launch
        }

        Log.d(TAG, "Fetching SSID")
        val ssid = coreResolver.fetchSSID()
        result.success(ssid)
      } catch (e: Exception) {
        result.error("SSID_ERROR", e.message, null)
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    Log.d(TAG, "onRequestPermissionsResult")
    if (requestCode == PERMISSION_REQUEST_CODE) {
      val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
      pendingResult?.let { result ->
        val response = mapOf(
          "status" to if (allGranted) "Permissions granted" else "Permissions denied",
          "grantedPermissions" to permissionHandler.listGrantedPermissions(),
          "deniedPermissions" to permissionHandler.listDeniedPermissions(),
          "errorMessage" to if (!allGranted) "Some permissions were denied" else null
        )
        result.success(response)
        pendingResult = null
      }
      return true
    }
    return false
  }

  companion object {
    private const val TAG = "SSIDResolver"
  }
}
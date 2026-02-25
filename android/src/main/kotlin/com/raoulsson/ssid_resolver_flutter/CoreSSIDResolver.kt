package com.raoulsson.ssid_resolver_flutter

import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.raoulsson.ssidresolverandroid.core.PermissionHandler
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume

class MissingPermissionException(message: String) : Exception(message)

class CoreSSIDResolver(
    private val context: Context,
    private var permissionHandler: PermissionHandler? = null
) {
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager

    init {
        if (permissionHandler == null) {
            permissionHandler = PermissionHandler(context)
        }
    }

    @SuppressLint("MissingPermission")
    suspend fun fetchSSID(): String {
        Log.d(TAG, "fetchSSID called on thread: ${Thread.currentThread().name}")

        if (!permissionHandler!!.hasRequiredPermissions()) {
            val deniedPermissions = permissionHandler!!.listDeniedPermissions().joinToString(", ")
            Log.d(TAG, "Missing permissions: $deniedPermissions")
            throw MissingPermissionException("Missing permissions: $deniedPermissions")
        }

        // 1. Try synchronous approach via NetworkCapabilities (API 29+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val ssid = getSSIDFromNetworkCapabilities()
            if (ssid != null) {
                Log.d(TAG, "Got SSID from NetworkCapabilities: $ssid")
                return ssid
            }
        }

        // 2. Try deprecated WifiManager.connectionInfo
        val ssid = getSSIDFromWifiManager()
        if (ssid != null) {
            Log.d(TAG, "Got SSID from WifiManager: $ssid")
            return ssid
        }

        // 3. Last resort: async callback approach with timeout
        Log.d(TAG, "Falling back to async network callback")
        return withTimeout(5000) {
            getSSIDFromNetworkCallback()
        }
    }

    @SuppressLint("MissingPermission")
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun getSSIDFromNetworkCapabilities(): String? {
        val network = connectivityManager.activeNetwork ?: return null
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return null
        if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null

        val wifiInfo = capabilities.transportInfo as? WifiInfo ?: return null
        return extractSSID(wifiInfo.ssid)
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun getSSIDFromWifiManager(): String? {
        val wifiInfo = wifiManager.connectionInfo ?: return null
        return extractSSID(wifiInfo.ssid)
    }

    private suspend fun getSSIDFromNetworkCallback(): String {
        return suspendCancellableCoroutine { continuation ->
            var networkCallback: ConnectivityManager.NetworkCallback? = null
            var hasResumed = false

            val safeResume = { result: String ->
                if (!hasResumed) {
                    hasResumed = true
                    networkCallback?.let {
                        try {
                            connectivityManager.unregisterNetworkCallback(it)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error unregistering callback", e)
                        }
                    }
                    continuation.resume(result)
                }
            }

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                @SuppressLint("MissingPermission")
                override fun onCapabilitiesChanged(
                    network: Network,
                    capabilities: NetworkCapabilities
                ) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val wifiInfo = capabilities.transportInfo as? WifiInfo
                        val ssid = wifiInfo?.ssid?.let { extractSSID(it) }
                        if (ssid != null) {
                            safeResume(ssid)
                            return
                        }
                    }
                    // Fallback to WifiManager for older APIs
                    @Suppress("DEPRECATION")
                    val ssid = wifiManager.connectionInfo?.ssid?.let { extractSSID(it) }
                    safeResume(ssid ?: "Unknown")
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    safeResume("Unknown")
                }
            }

            continuation.invokeOnCancellation {
                networkCallback?.let {
                    try {
                        connectivityManager.unregisterNetworkCallback(it)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error unregistering callback", e)
                    }
                }
            }

            try {
                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .build()
                connectivityManager.registerNetworkCallback(request, networkCallback!!)
            } catch (e: Exception) {
                Log.e(TAG, "Error registering network callback", e)
                safeResume("Unknown")
            }
        }
    }

    private fun extractSSID(rawSSID: String?): String? {
        if (rawSSID == null) return null
        val ssid = rawSSID.removeSurrounding("\"")
        return if (ssid.isNotEmpty() && ssid != "<unknown ssid>") ssid else null
    }

    companion object {
        private const val TAG = "SSIDResolver"
    }
}

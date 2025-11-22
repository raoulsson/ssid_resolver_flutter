package com.raoulsson.ssid_resolver_flutter

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
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

    suspend fun fetchSSID(): String {
        Log.d(TAG, "fetchSSID called on thread: ${Thread.currentThread().name}")

        if (!permissionHandler!!.hasRequiredPermissions()) {
            val deniedPermissions = permissionHandler!!.listDeniedPermissions().joinToString(", ")
            Log.d(TAG, "Missing permissions: $deniedPermissions")
            throw MissingPermissionException("Missing permissions: $deniedPermissions")
        }

        return withTimeout(5000) {
            suspendCancellableCoroutine { continuation ->
                var receiverRegistered = false
                var wifiScanReceiver: BroadcastReceiver? = null
                var networkCallback: ConnectivityManager.NetworkCallback? = null
                var hasResumed = false

                val cleanup = {
                    if (receiverRegistered) {
                        try {
                            wifiScanReceiver?.let { context.unregisterReceiver(it) }
                            receiverRegistered = false
                        } catch (e: Exception) {
                            Log.e(TAG, "Error unregistering receiver", e)
                        }
                    }
                    networkCallback?.let {
                        try {
                            connectivityManager.unregisterNetworkCallback(it)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error unregistering callback", e)
                        }
                    }
                }

                val safeResume = { result: String ->
                    if (!hasResumed) {
                        hasResumed = true
                        cleanup()
                        continuation.resume(result)
                    }
                }

                continuation.invokeOnCancellation {
                    cleanup()
                }

                networkCallback = object : ConnectivityManager.NetworkCallback() {
                    @RequiresApi(Build.VERSION_CODES.R)
                    override fun onCapabilitiesChanged(
                        network: Network,
                        capabilities: NetworkCapabilities
                    ) {
                        super.onCapabilitiesChanged(network, capabilities)
                        try {
                            wifiScanReceiver = object : BroadcastReceiver() {
                                @SuppressLint("MissingPermission")
                                override fun onReceive(context: Context, intent: Intent) {
                                    val scanResults = wifiManager.scanResults
                                    val connectedBssid = wifiManager.connectionInfo?.bssid
                                    val connectedNetwork = scanResults.firstOrNull {
                                        it.BSSID == connectedBssid
                                    }

                                    if (connectedNetwork != null) {
                                        val ssid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                            connectedNetwork.wifiSsid.toString()
                                        } else {
                                            connectedNetwork.SSID
                                        }.removeSurrounding("\"")

                                        if (ssid.isNotEmpty() && ssid != "<unknown ssid>") {
                                            safeResume(ssid)
                                        } else {
                                            safeResume("Unknown")
                                        }
                                    } else if (scanResults.isNotEmpty()) {
                                        val strongestNetwork = scanResults.maxByOrNull { it.level }
                                        if (strongestNetwork != null) {
                                            val ssid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                                strongestNetwork.wifiSsid.toString()
                                            } else {
                                                strongestNetwork.SSID
                                            }.removeSurrounding("\"")

                                            if (ssid.isNotEmpty() && ssid != "<unknown ssid>") {
                                                safeResume(ssid)
                                            } else {
                                                safeResume("Unknown")
                                            }
                                        } else {
                                            safeResume("Unknown")
                                        }
                                    } else {
                                        safeResume("Unknown")
                                    }
                                }
                            }

                            val intentFilter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
                            context.registerReceiver(wifiScanReceiver, intentFilter)
                            receiverRegistered = true
                            wifiManager.startScan()

                        } catch (e: Exception) {
                            Log.e(TAG, "Error in callback", e)
                            safeResume("Unknown")
                        }
                    }

                    override fun onLost(network: Network) {
                        super.onLost(network)
                        safeResume("Unknown")
                    }
                }

                try {
                    val request = NetworkRequest.Builder()
                        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                        .build()
                    connectivityManager.requestNetwork(request, networkCallback)
                } catch (e: Exception) {
                    Log.e(TAG, "Error requesting network", e)
                    safeResume("Unknown")
                }
            }
        }
    }

    companion object {
        private const val TAG = "SSIDResolver"
    }
}

package com.raoulsson.ssid_resolver_flutter

import android.content.Context
import android.net.ConnectivityManager
import android.util.Log
import java.net.Inet4Address
import java.net.InterfaceAddress
import java.net.NetworkInterface
import java.util.Collections

/**
 * Enumerates IPv4 network interfaces without touching WifiManager/DhcpInfo.
 *
 * That path needs ACCESS_FINE_LOCATION and only covers WiFi, so it fails silently
 * when the user has denied Location. java.net.NetworkInterface needs no permission
 * and works for any interface (WiFi, ethernet, tunnels), which is what a UDP
 * discovery caller actually needs to pick the right broadcast address.
 *
 * Kept in lockstep with the copy in the standalone ssid-resolver-android app
 * (core/NetworkInterfaceResolver.kt), which is where this one was lifted from.
 */
class NetworkInterfaceResolver(private val context: Context? = null) {

    fun fetchInterfaces(): List<Map<String, Any>> {
        val fromJavaNet = fetchViaNetworkInterface()
        if (fromJavaNet.isNotEmpty()) return fromJavaNet

        // Android 11 restricted /proc/net, and on some devices (observed on a
        // Samsung running Android 15) NetworkInterface.getNetworkInterfaces()
        // returns null outright rather than throwing. ConnectivityManager is the
        // supported route and gives the prefix length directly; it needs only
        // ACCESS_NETWORK_STATE, which is not a runtime permission.
        val fromConnectivity = fetchViaConnectivityManager()
        if (fromConnectivity.isEmpty()) {
            Log.w(TAG, "No IPv4 interfaces found by either NetworkInterface or ConnectivityManager")
        }
        return fromConnectivity
    }

    private fun fetchViaConnectivityManager(): List<Map<String, Any>> {
        val cm = context?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: run {
                Log.w(TAG, "No context available, cannot fall back to ConnectivityManager")
                return emptyList()
            }
        return try {
            val result = mutableListOf<Map<String, Any>>()
            for (network in cm.allNetworks) {
                val link = cm.getLinkProperties(network) ?: continue
                val name = link.interfaceName ?: "?"
                for (linkAddress in link.linkAddresses) {
                    val address = linkAddress.address
                    if (address !is Inet4Address) continue
                    val prefixLength = linkAddress.prefixLength
                    val maskInt = prefixLengthToMask(prefixLength)
                    val described = mapOf(
                        "name" to name,
                        "ip" to (address.hostAddress ?: "?"),
                        "netmask" to intToIp(maskInt),
                        "broadcast" to intToIp(deriveBroadcast(ipToInt(address), maskInt)),
                        "prefixLength" to prefixLength
                    )
                    Log.d(TAG, "interface (ConnectivityManager) $described")
                    result.add(described)
                }
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "ConnectivityManager enumeration failed", e)
            emptyList()
        }
    }

    private fun fetchViaNetworkInterface(): List<Map<String, Any>> {
        return try {
            val result = mutableListOf<Map<String, Any>>()
            // getNetworkInterfaces() is documented to return null when there are
            // no interfaces, and does so on restricted Android builds. Passing
            // that straight to Collections.list throws NPE.
            val enumeration = NetworkInterface.getNetworkInterfaces()
            if (enumeration == null) {
                Log.w(TAG, "NetworkInterface.getNetworkInterfaces() returned null")
                return emptyList()
            }
            val interfaces = Collections.list(enumeration)
            for (netIf in interfaces) {
                for (ifAddr in netIf.interfaceAddresses) {
                    val address = ifAddr.address
                    if (address !is Inet4Address) continue

                    val described = describe(netIf.name, address, ifAddr)
                    Log.d(TAG, "interface $described")
                    result.add(described)
                }
            }
            if (result.isEmpty()) {
                // The caller gets an empty list either way. Without this line
                // "the OS reported nothing" is indistinguishable from "the call
                // blew up", and the two need very different fixes.
                Log.w(TAG, "No IPv4 interfaces found")
            }
            result
        } catch (e: Exception) {
            // A discovery caller uses this to pick where to send UDP traffic; an
            // exception here must not become a crash, just an empty candidate list.
            Log.e(TAG, "Failed to enumerate network interfaces", e)
            emptyList()
        }
    }

    private fun describe(name: String, address: Inet4Address, ifAddr: InterfaceAddress): Map<String, Any> {
        val prefixLength = ifAddr.networkPrefixLength.toInt()
        val maskInt = prefixLengthToMask(prefixLength)
        val netmask = intToIp(maskInt)

        // getBroadcast() returns null for loopback and point-to-point (e.g. VPN
        // tunnel) interfaces, so fall back to deriving it from ip/mask ourselves.
        val broadcast = ifAddr.broadcast?.hostAddress
            ?: intToIp(deriveBroadcast(ipToInt(address), maskInt))

        return mapOf(
            "name" to name,
            "ip" to address.hostAddress,
            "netmask" to netmask,
            "broadcast" to broadcast,
            "prefixLength" to prefixLength
        )
    }

    private fun prefixLengthToMask(prefixLength: Int): Int {
        return if (prefixLength <= 0) 0 else (Int.MIN_VALUE shr (prefixLength - 1))
    }

    private fun deriveBroadcast(ip: Int, mask: Int): Int {
        return (ip and mask) or mask.inv()
    }

    private fun ipToInt(address: Inet4Address): Int {
        val bytes = address.address
        return ((bytes[0].toInt() and 0xFF) shl 24) or
            ((bytes[1].toInt() and 0xFF) shl 16) or
            ((bytes[2].toInt() and 0xFF) shl 8) or
            (bytes[3].toInt() and 0xFF)
    }

    private fun intToIp(value: Int): String {
        return "${(value shr 24) and 0xFF}.${(value shr 16) and 0xFF}.${(value shr 8) and 0xFF}.${value and 0xFF}"
    }

    companion object {
        private const val TAG = "NetworkInterfaceResolver"
    }
}

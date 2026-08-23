package com.raoulsson.ssid_resolver_flutter

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
 * Kept in lockstep with the copy in the standalone ssid-resolver-android app.
 */
class NetworkInterfaceResolver {

    fun fetchInterfaces(): List<Map<String, Any>> {
        return try {
            val result = mutableListOf<Map<String, Any>>()
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
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

package com.raoulsson.ssidresolverandroid.core

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class PermissionHandler(private val context: Context) {

    private fun isPermissionGranted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun hasRequiredPermissions(): Boolean =
        requiredPermissions.all { permission -> isPermissionGranted(permission) }

    fun listGrantedPermissions(): List<String> =
        requiredPermissions.filter { permission -> isPermissionGranted(permission) }

    fun listDeniedPermissions(): List<String> =
        requiredPermissions.filter { permission -> !isPermissionGranted(permission) }

    fun requestLocationPermission(activity: Activity, callback: (Boolean) -> Unit) {
        if (hasRequiredPermissions()) {
            callback(true)
            return
        }
        ActivityCompat.requestPermissions(
            activity,
            requiredPermissions.toTypedArray(),
            PERMISSION_REQUEST_CODE
        )
    }

    companion object {
        private const val TAG = "SSIDResolver"
        const val PERMISSION_REQUEST_CODE = 100
        val requiredPermissions: List<String> = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.CHANGE_NETWORK_STATE,
            Manifest.permission.ACCESS_WIFI_STATE,
            Manifest.permission.CHANGE_WIFI_STATE
        )
    }

}

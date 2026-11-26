package com.moaymandev.hadithsearcher

import android.content.Context
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.InstallException
import com.google.android.play.core.install.model.InstallErrorCode
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodChannel

object DistributionUpdates {
    fun availableVersionCode(context: Context, result: MethodChannel.Result) {
        AppUpdateManagerFactory.create(context).appUpdateInfo
            .addOnSuccessListener { info ->
                result.success(if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                    info.availableVersionCode()
                } else null)
            }
            .addOnFailureListener { error ->
                val code = (error as? InstallException)?.errorCode
                when (code) {
                    InstallErrorCode.ERROR_API_NOT_AVAILABLE,
                    InstallErrorCode.ERROR_APP_NOT_OWNED,
                    InstallErrorCode.ERROR_PLAY_STORE_NOT_FOUND,
                    InstallErrorCode.ERROR_INSTALL_UNAVAILABLE ->
                        result.error("play_update_unavailable", null, code)
                    else -> result.error("play_update", null, code)
                }
            }
            .addOnCanceledListener {
                result.error("play_update_cancelled", null, null)
            }
    }
}

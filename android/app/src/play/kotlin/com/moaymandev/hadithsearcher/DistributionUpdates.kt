package com.moaymandev.hadithsearcher

import android.content.Context
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
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
                result.error("play_update", error.message, null)
            }
    }
}

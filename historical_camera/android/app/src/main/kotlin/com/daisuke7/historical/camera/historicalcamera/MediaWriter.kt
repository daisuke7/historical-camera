package com.daisuke7.historical.camera.historicalcamera

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Gallery save (docs/06 §5). The temp file in cacheDir is the channel result
 * value; this copies it into the public gallery. (P2) MediaRecorder
 * recording will live here as well.
 */
object MediaWriter {
    private const val ALBUM = "HistoricalCamera"

    /** Saves [file] (a JPEG) to the gallery. Throws [PluginError] on failure. */
    fun saveToGallery(context: Context, file: File) {
        if (Build.VERSION.SDK_INT >= 29) {
            saveViaMediaStore(context, file)
        } else {
            saveLegacy(context, file)
        }
    }

    private fun saveViaMediaStore(context: Context, file: File) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_PICTURES}/$ALBUM")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw PluginError(ErrorCodes.SAVE_FAILED, "MediaStore insert failed")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { it.copyTo(output) }
            } ?: throw PluginError(ErrorCodes.SAVE_FAILED, "cannot open output stream")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw if (e is PluginError) e
            else PluginError(ErrorCodes.SAVE_FAILED, e.message ?: "save failed")
        }
    }

    /**
     * API 26-28: public Pictures directory + media scan. Requires
     * WRITE_EXTERNAL_STORAGE (docs/06 §2; requested from Dart on such
     * devices).
     */
    @Suppress("DEPRECATION")
    private fun saveLegacy(context: Context, file: File) {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES),
            ALBUM)
        if (!dir.exists() && !dir.mkdirs()) {
            throw PluginError(ErrorCodes.SAVE_FAILED, "cannot create album directory")
        }
        val target = File(dir, file.name)
        try {
            file.copyTo(target, overwrite = true)
        } catch (e: Exception) {
            throw PluginError(ErrorCodes.SAVE_FAILED, e.message ?: "copy failed")
        }
        MediaScannerConnection.scanFile(
            context, arrayOf(target.absolutePath), arrayOf("image/jpeg"), null)
    }
}

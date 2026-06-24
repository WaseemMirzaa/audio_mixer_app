package com.codetivelab.soundAxis

import android.app.Activity
import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

/**
 * Saves a backup ZIP into the public Downloads folder so it appears in
 * Files / My Files → Downloads (not the app-private Downloads path).
 */
class BackupExportHandler(private val activity: Activity) {

    fun saveToDownloads(sourcePath: String, displayName: String): Map<String, Any?> {
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalStateException("Backup file was not found")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = activity.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                put(MediaStore.Downloads.MIME_TYPE, "application/zip")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create Downloads entry")

            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(source).use { input -> input.copyTo(out) }
            } ?: throw IllegalStateException("Could not write backup to Downloads")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            return mapOf(
                "success" to true,
                "displayName" to displayName,
                "location" to "Downloads",
                "contentUri" to uri.toString(),
            )
        }

        @Suppress("DEPRECATION")
        val downloadsDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDir.exists()) {
            downloadsDir.mkdirs()
        }
        val dest = File(downloadsDir, displayName)
        source.copyTo(dest, overwrite = true)
        MediaScannerConnection.scanFile(
            activity,
            arrayOf(dest.absolutePath),
            arrayOf("application/zip"),
            null,
        )
        return mapOf(
            "success" to true,
            "displayName" to displayName,
            "location" to "Downloads",
            "path" to dest.absolutePath,
        )
    }
}

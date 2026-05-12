package com.example.gitnote

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gitnote/native_share"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val title = call.argument<String>("title") ?: "GitNote"
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "File path is empty.", null)
                            return@setMethodCallHandler
                        }

                        shareFile(path, title, mimeType)
                        result.success(true)
                    }

                    "saveFileToPublicDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val repoKey = call.argument<String>("repoKey") ?: "repo"
                        val repoPath = call.argument<String>("repoPath")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        if (sourcePath.isNullOrBlank() || repoPath.isNullOrBlank()) {
                            result.error("INVALID_PATH", "File path is empty.", null)
                            return@setMethodCallHandler
                        }

                        result.success(
                            saveFileToPublicDownloads(
                                sourcePath,
                                repoKey,
                                repoPath,
                                mimeType
                            )
                        )
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("NATIVE_FILE_FAILED", error.message, null)
            }
        }
    }

    private fun shareFile(path: String, title: String, mimeType: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("File does not exist: $path")
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.gitnote_file_provider",
            file
        )
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, title)
            putExtra(Intent.EXTRA_SUBJECT, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        packageManager.queryIntentActivities(
            shareIntent,
            0
        ).forEach { resolveInfo ->
            grantUriPermission(
                resolveInfo.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        val chooser = Intent.createChooser(shareIntent, null).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }

    private fun saveFileToPublicDownloads(
        sourcePath: String,
        repoKey: String,
        repoPath: String,
        mimeType: String
    ): String {
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalArgumentException("File does not exist: $sourcePath")
        }

        val cleanRepoKey = repoKey.replace(Regex("[^a-zA-Z0-9_\\-]"), "_")
        val cleanSegments = repoPath
            .split("/")
            .filter { it.isNotBlank() && it != "." && it != ".." }
        val displayName = cleanSegments.lastOrNull() ?: source.name
        val subDirectory = cleanSegments.dropLast(1).joinToString("/")
        val relativeDirectory = listOf(
            "Download",
            "GitNote",
            cleanRepoKey,
            subDirectory
        ).filter { it.isNotBlank() }.joinToString("/")

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.RELATIVE_PATH, relativeDirectory)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        }
        val uri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create download entry.")

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                source.inputStream().use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Unable to open download output stream.")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val completeValues = ContentValues().apply {
                    put(MediaStore.Downloads.IS_PENDING, 0)
                }
                contentResolver.update(uri, completeValues, null, null)
            }
        } catch (error: Throwable) {
            contentResolver.delete(uri, null, null)
            throw error
        }

        return listOf(
            "/storage/emulated/0",
            relativeDirectory,
            displayName
        ).joinToString("/")
    }
}

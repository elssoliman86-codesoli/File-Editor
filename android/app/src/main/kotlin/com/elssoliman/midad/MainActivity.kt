package com.elssoliman.midad

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.elssoliman.midad/storage"
    private var channel: MethodChannel? = null
    private var initialDocument: Map<String, Any?>? = null
    private val createDocument = 4101
    private var pendingExport: PendingExport? = null
    private var pendingResult: MethodChannel.Result? = null

    data class PendingExport(val name: String, val path: String, val hash: String)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialDocument = documentFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialDocument" -> result.success(initialDocument)
                "consumeInitialDocument" -> {
                    initialDocument = null
                    result.success(null)
                }
                "createDocument" -> {
                    if (pendingResult != null) {
                        result.error("BUSY", "Another document export is already active", null)
                        return@setMethodCallHandler
                    }
                    pendingExport = PendingExport(
                        call.argument<String>("name") ?: "document.bin",
                        call.argument<String>("path") ?: "",
                        call.argument<String>("sha256") ?: "",
                    )
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("mimeType") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, pendingExport?.name)
                    }
                    pendingResult = result
                    startActivityForResult(intent, createDocument)
                }
                "replaceDocument" -> {
                    val uri = call.argument<String>("uri") ?: return@setMethodCallHandler result.error("URI", "Missing source URI", null)
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("PATH", "Missing temp path", null)
                    val expected = call.argument<String>("sha256") ?: ""
                    try {
                        contentResolver.takePersistableUriPermission(uri.toUri(), Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    } catch (_: Exception) {
                        // A transient VIEW grant may still permit this one write; no broad permission is requested.
                    }
                    val receipt = copyToUri(uri.toUri(), path, expected, "wt")
                    result.success(receipt)
                }
                "setSecureScreen" -> {
                    if (call.argument<Boolean>("enabled") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val document = documentFromIntent(intent)
        if (document != null) channel?.invokeMethod("onDocumentIntent", document)
    }

    @Deprecated("Deprecated in Android Activity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createDocument) return
        val export = pendingExport
        pendingExport = null
        val result = pendingResult
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || export == null) {
            result?.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        } catch (_: Exception) {
            // Some document providers grant only transient access.
        }
        try {
            val receipt = copyToUri(uri, export.path, export.hash, "wt")
            result?.success(receipt)
        } catch (error: Exception) {
            result?.error("WRITE_FAILED", error.message, null)
        }
    }

    private fun copyToUri(uri: Uri, path: String, expectedHash: String, mode: String): Map<String, Any?> {
        if (path.isEmpty()) throw IllegalArgumentException("Temporary export path is empty")
        val descriptor = contentResolver.openFileDescriptor(uri, mode)
            ?: throw IllegalStateException("Document provider did not open the destination")
        descriptor.use { parcel ->
            FileInputStream(path).use { input ->
                FileOutputStream(parcel.fileDescriptor).use { output ->
                    input.copyTo(output)
                    output.flush()
                    output.fd.sync()
                }
            }
        }
        val digest = MessageDigest.getInstance("SHA-256")
        var bytes = 0L
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Saved document cannot be read back" }
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                bytes += count
                digest.update(buffer, 0, count)
            }
        }
        val actualHash = digest.digest().toHex()
        require(actualHash == expectedHash) { "Saved file hash does not match the generated document" }
        return mapOf(
            "uri" to uri.toString(),
            "name" to displayName(uri),
            "bytes" to bytes,
            "sha256" to actualHash,
            "verified" to true,
        )
    }

    private fun documentFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val uri = when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_EDIT -> intent.data
            @Suppress("DEPRECATION")
            Intent.ACTION_SEND -> intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: Exception) {
            // VIEW and SEND commonly provide a one-time grant rather than persistable access.
        }
        val name = displayName(uri)
        val target = File(File(cacheDir, "incoming"), "${System.nanoTime()}-$name")
        target.parentFile?.mkdirs()
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot read shared document" }
            target.outputStream().buffered().use { output ->
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    require(total <= 64 * 1024 * 1024) { "Shared document exceeds 64 MB" }
                    output.write(buffer, 0, count)
                }
            }
        }
        return mapOf(
            "path" to target.absolutePath,
            "name" to name,
            "uri" to uri.toString(),
            "mimeType" to (contentResolver.getType(uri) ?: intent.type),
        )
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) return cursor.getString(index)
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "document"
    }

    private fun String.toUri(): Uri = Uri.parse(this)
    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
}

package com.tarik.al.quran

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Native side of the adhan sound picker (lib/features/prayer/adhan_sound).
 *
 * - publish: copies a sound into the shared Notifications/Tarik Al Quran
 *   folder through MediaStore and returns its content:// uri. The adhan is
 *   a notification channel sound, played by the system, which can't read
 *   app-private files; a MediaStore entry this app wrote is readable by it.
 * - pick: the system file picker (needs no storage permission), copied to
 *   the cache so the Dart side can keep its own copy.
 * - preview: a plain MediaPlayer. just_audio_background allows a single
 *   just_audio player, and that one belongs to the Quran player.
 */
class AdhanSoundChannel(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private class NeedsPermission : Exception("permission")

    private val channel = MethodChannel(messenger, "tarik/adhan_sound")
    private val main = Handler(Looper.getMainLooper())
    private var pickResult: MethodChannel.Result? = null
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publish" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val title = call.argument<String>("title") ?: name
                val mime = call.argument<String>("mime") ?: "audio/mpeg"
                if (path == null || name == null || title == null) {
                    result.error("args", "path and name are required", null)
                    return
                }
                background(result) { publish(File(path), name, title, mime) }
            }
            "unpublish" -> {
                val uri = call.argument<String>("uri")
                if (uri == null) {
                    result.success(null)
                    return
                }
                background(result) {
                    // best effort: after a reinstall the entry is no longer ours
                    try {
                        activity.contentResolver.delete(Uri.parse(uri), null, null)
                    } catch (_: Exception) {
                    }
                    null
                }
            }
            "pick" -> pick(result)
            "previewStart" -> {
                val source = call.argument<String>("source")
                if (source == null) {
                    result.error("args", "source is required", null)
                    return
                }
                previewStart(source)
                result.success(null)
            }
            "previewStop" -> {
                previewStop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: NeedsPermission) {
                main.post { result.error("permission", "WRITE_EXTERNAL_STORAGE needed", null) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message, null) }
            }
        }.start()
    }

    private fun publish(src: File, name: String, title: String, mime: String): String {
        val resolver = activity.contentResolver
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, name)
                put(MediaStore.Audio.Media.TITLE, title)
                put(MediaStore.Audio.Media.MIME_TYPE, mime)
                put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_NOTIFICATIONS}/$FOLDER")
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values) ?: throw IOException("MediaStore insert failed")
            try {
                val out = resolver.openOutputStream(uri) ?: throw IOException("cannot open $uri")
                out.use { o -> src.inputStream().use { it.copyTo(o) } }
                val done = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
                resolver.update(uri, done, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return uri.toString()
        }
        // API 24-28: the public folder plus a MediaStore row; the Dart side
        // asks for the permission and retries when it is missing.
        if (activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) throw NeedsPermission()
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_NOTIFICATIONS), FOLDER)
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("cannot create $dir")
        val dst = File(dir, name)
        src.copyTo(dst, overwrite = true)
        @Suppress("DEPRECATION")
        val data = MediaStore.MediaColumns.DATA
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        resolver.delete(collection, "$data=?", arrayOf(dst.absolutePath))
        val values = ContentValues().apply {
            put(data, dst.absolutePath)
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.TITLE, title)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
        }
        return (resolver.insert(collection, values) ?: throw IOException("MediaStore insert failed")).toString()
    }

    private fun pick(result: MethodChannel.Result) {
        if (pickResult != null) {
            result.error("busy", "a picker is already open", null)
            return
        }
        pickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (e: Exception) {
            pickResult = null
            result.error("picker", e.message, null)
        }
    }

    /** Forwarded by MainActivity; true when the result was the picker's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pickResult ?: return true
        pickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // cancelled
            return true
        }
        background(result) {
            val resolver = activity.contentResolver
            var name = "adhan"
            var size = -1L
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
                ?.use { c ->
                    if (c.moveToFirst()) {
                        c.getString(0)?.let { name = it }
                        if (!c.isNull(1)) size = c.getLong(1)
                    }
                }
            if (size > MAX_BYTES) throw IOException("too_big")
            val out = File(activity.cacheDir, "adhan_pick")
            val input = resolver.openInputStream(uri) ?: throw IOException("cannot read $uri")
            input.use { i -> out.outputStream().use { i.copyTo(it) } }
            if (out.length() > MAX_BYTES) {
                out.delete()
                throw IOException("too_big")
            }
            mapOf("path" to out.absolutePath, "name" to name, "mime" to (resolver.getType(uri) ?: "audio/mpeg"))
        }
        return true
    }

    private fun previewStart(source: String) {
        previewStop()
        val uri = if (source.startsWith("/")) Uri.fromFile(File(source)) else Uri.parse(source)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        if (Build.VERSION.SDK_INT >= 26) {
            // transient focus: the Quran player pauses and resumes after
            val am = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
                .also { am.requestAudioFocus(it) }
        }
        val mp = MediaPlayer()
        player = mp
        mp.setAudioAttributes(attrs)
        mp.setOnPreparedListener {
            if (player === it) {
                it.start()
                channel.invokeMethod("previewStarted", null)
            }
        }
        mp.setOnCompletionListener { if (player === it) finished() }
        mp.setOnErrorListener { p, _, _ ->
            if (player === p) finished()
            true
        }
        try {
            mp.setDataSource(activity, uri)
            mp.prepareAsync()
        } catch (e: Exception) {
            finished()
        }
    }

    private fun finished() {
        previewStop()
        channel.invokeMethod("previewDone", null)
    }

    private fun previewStop() {
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        if (Build.VERSION.SDK_INT >= 26) {
            val am = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            focus?.let { am.abandonAudioFocusRequest(it) }
        }
        focus = null
    }

    fun dispose() {
        previewStop()
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val PICK_REQUEST = 0x5AD
        private const val MAX_BYTES = 20L * 1024 * 1024
        private const val FOLDER = "Tarik Al Quran"
    }
}

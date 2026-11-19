package com.writinghuman.writing_human

import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.os.Bundle
import android.net.Uri
import android.widget.Toast
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val channelName = "writing_human/source"
        private const val textLimit = 50000
        private const val inboxLimit = 20
        private const val photoLimit = 20 * 1024 * 1024
        private val inboxIo = Executors.newSingleThreadExecutor()
        private val photoIo = Executors.newSingleThreadExecutor()
    }

    private var sourceChannel: MethodChannel? = null
    private val inbox get() = getSharedPreferences("source_inbox", MODE_PRIVATE)
    private fun readInbox() = JSONArray(inbox.getString("pending", "[]"))
    private fun writeInbox(items: JSONArray) {
        check(inbox.edit().putString("pending", items.toString()).commit())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        rememberSharedSource(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        rememberSharedSource(intent)
    }

    private fun sharedPhotoFile(id: String) = File(filesDir, "source-$id.photo")

    private fun copySharedPhoto(uri: Uri, destination: File) {
        require(uri.scheme == "content")
        contentResolver.openInputStream(uri)?.use { input ->
            destination.outputStream().use { output ->
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count == -1) break
                    total += count
                    check(total <= photoLimit)
                    output.write(buffer, 0, count)
                }
                check(total > 0)
            }
        } ?: error("Missing image stream")
    }

    @Suppress("DEPRECATION")
    private fun rememberSharedSource(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val mime = intent.type.orEmpty()
        val image = if (mime.startsWith("image/")) {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
        } else null
        if (image == null && !mime.startsWith("text/")) return
        val text = (intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text)
            ?.toString()?.trim().orEmpty()
        if (text.isEmpty() && image == null) return
        if (text.length > textLimit) {
            Toast.makeText(this, "옮겨 쓸 구절만 골라 공유해 주세요.", Toast.LENGTH_LONG).show()
            return
        }
        // The delivery is copied once into the private inbox. Keep the
        // original record and the incoming review separate.
        val id = UUID.randomUUID().toString()
        setIntent(Intent(this, MainActivity::class.java).setAction(Intent.ACTION_MAIN))
        inboxIo.execute {
            try {
                val items = readInbox()
                check(items.length() < inboxLimit)
                if (image != null) copySharedPhoto(image, sharedPhotoFile(id))
                items.put(JSONObject().put("id", id).put("text", text).put("hasPhoto", image != null))
                writeInbox(items)
                runOnUiThread { sourceChannel?.invokeMethod("shareChanged", null) }
            } catch (_: Exception) {
                sharedPhotoFile(id).delete()
                runOnUiThread {
                    Toast.makeText(this, "받은 원문을 보관하지 못했어요. 붙여넣기를 사용해 주세요.", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sourceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> recognizePhoto(call.arguments as? ByteArray, result)
                    "pendingShares" -> inboxIo.execute {
                        try {
                            val items = readInbox()
                            result.success((0 until items.length()).map { index ->
                                val item = items.getJSONObject(index)
                                mapOf(
                                    "id" to item.getString("id"),
                                    "text" to item.getString("text"),
                                    "hasPhoto" to item.optBoolean("hasPhoto")
                                )
                            })
                        } catch (_: Exception) {
                            result.error("inbox", "Could not read the source inbox", null)
                        }
                    }
                    "sharedPhoto" -> inboxIo.execute {
                        try {
                            val id = call.arguments as? String ?: error("Missing ID")
                            val items = readInbox()
                            val exists = (0 until items.length()).any { index ->
                                val item = items.getJSONObject(index)
                                item.getString("id") == id && item.optBoolean("hasPhoto")
                            }
                            result.success(if (exists) sharedPhotoFile(id).path else null)
                        } catch (_: Exception) {
                            result.error("inbox", "Could not read the shared photo", null)
                        }
                    }
                    "acknowledgeShare" -> inboxIo.execute {
                        try {
                            val id = call.arguments as? String ?: error("Missing ID")
                            val items = readInbox()
                            val remaining = JSONArray()
                            for (index in 0 until items.length()) {
                                val item = items.getJSONObject(index)
                                if (item.getString("id") != id) remaining.put(item)
                            }
                            writeInbox(remaining)
                            if (runCatching { UUID.fromString(id).toString() }.getOrNull() == id) {
                                sharedPhotoFile(id).delete()
                            }
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("inbox", "Could not update the source inbox", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sourceChannel?.setMethodCallHandler(null)
        sourceChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun recognizePhoto(bytes: ByteArray?, result: MethodChannel.Result) {
        photoIo.execute {
            try {
                check(bytes != null && bytes.isNotEmpty())
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: error("Could not decode photo")
                val width = bitmap.width.toDouble()
                val height = bitmap.height.toDouble()
                fun box(rect: Rect?) = rect?.let {
                    listOf(it.left / width, it.top / height, it.right / width, it.bottom / height)
                }
                val image = InputImage.fromBitmap(bitmap, 0)
                val reader = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
                try {
                    reader.process(image)
                        .addOnSuccessListener { text ->
                            result.success(text.textBlocks.map { block ->
                                block.lines.map { line ->
                                    mapOf(
                                        "text" to line.text,
                                        "bounds" to box(line.boundingBox),
                                        "confidence" to line.confidence.toDouble(),
                                        "words" to line.elements.map { word ->
                                            mapOf(
                                                "text" to word.text,
                                                "bounds" to box(word.boundingBox),
                                                "confidence" to word.confidence.toDouble(),
                                            )
                                        },
                                    )
                                }
                            })
                        }
                        .addOnFailureListener { result.error("recognition", "Could not read the photo", null) }
                        .addOnCompleteListener {
                            reader.close()
                            bitmap.recycle()
                        }
                } catch (error: Exception) {
                    reader.close()
                    bitmap.recycle()
                    throw error
                }
            } catch (_: Exception) {
                result.error("recognition", "Could not read the photo", null)
            }
        }
    }
}

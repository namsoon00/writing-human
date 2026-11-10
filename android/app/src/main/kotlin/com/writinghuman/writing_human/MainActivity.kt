package com.writinghuman.writing_human

import android.content.Intent
import android.net.Uri
import android.os.Bundle
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
        rememberSharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        rememberSharedText(intent)
    }

    private fun rememberSharedText(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return
        val text = (intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text)
            ?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return
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
                items.put(JSONObject().put("id", id).put("text", text))
                writeInbox(items)
                runOnUiThread { sourceChannel?.invokeMethod("shareChanged", null) }
            } catch (_: Exception) {
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
                    "recognize" -> recognizePhoto(call.arguments as? String, result)
                    "pendingShares" -> inboxIo.execute {
                        try {
                            val items = readInbox()
                            result.success((0 until items.length()).map { index ->
                                val item = items.getJSONObject(index)
                                mapOf("id" to item.getString("id"), "text" to item.getString("text"))
                            })
                        } catch (_: Exception) {
                            result.error("inbox", "Could not read the source inbox", null)
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

    private fun recognizePhoto(path: String?, result: MethodChannel.Result) {
        photoIo.execute {
            try {
                val file = File(path ?: error("Missing photo"))
                check(file.isFile && file.length() in 1..(20L * 1024 * 1024))
                val image = InputImage.fromFilePath(applicationContext, Uri.fromFile(file))
                val reader = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
                try {
                    reader.process(image)
                        .addOnSuccessListener { text -> result.success(text.textBlocks.map { it.text }) }
                        .addOnFailureListener { result.error("recognition", "Could not read the photo", null) }
                        .addOnCompleteListener { reader.close() }
                } catch (error: Exception) {
                    reader.close()
                    throw error
                }
            } catch (_: Exception) {
                result.error("recognition", "Could not read the photo", null)
            }
        }
    }
}

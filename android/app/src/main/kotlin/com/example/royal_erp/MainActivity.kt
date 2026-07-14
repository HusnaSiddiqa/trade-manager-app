package com.example.royal_erp

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
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
            "royal_erp/file_provider"
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "getContentUri" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    try {
                        val file = File(filePath)
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("FILE_ERROR", e.message, null)
                    }
                }

                // Shares a PDF file directly to a WhatsApp contact.
                // Does URI creation, permission grant, and intent launch all in
                // native code so FLAG_GRANT_READ_URI_PERMISSION is effective.
                "shareToWhatsApp" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val waNumber = call.argument<String>("waNumber") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    try {
                        val file = File(filePath)
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )

                        // Explicitly grant WhatsApp read access to this URI.
                        // This is necessary in addition to the intent flag because
                        // explicit-package intents on Android 10+ need this call.
                        grantUriPermission(
                            "com.whatsapp",
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/pdf"
                            setPackage("com.whatsapp")
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (waNumber.isNotEmpty()) {
                                // jid routes directly to the contact's chat,
                                // bypassing WhatsApp's internal contact picker.
                                putExtra("jid", "$waNumber@s.whatsapp.net")
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: ActivityNotFoundException) {
                        result.error("WHATSAPP_NOT_FOUND", "WhatsApp is not installed", null)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}

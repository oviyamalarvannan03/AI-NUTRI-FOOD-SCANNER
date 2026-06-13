package com.nutriai.scanner

import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.android.gms.tasks.Tasks
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.nutriai.scanner/mlkit"
    private val executorService: ExecutorService = Executors.newFixedThreadPool(2)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "analyzeImage") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "File path is null", null)
                    return@setMethodCallHandler
                }
                
                executorService.execute {
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            runOnUiThread {
                                result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            }
                            return@execute
                        }
                        
                        val image = InputImage.fromFilePath(applicationContext, Uri.fromFile(file))
                        
                        // Process image labeling and text recognition
                        val labeler = ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS)
                        val labelTask = labeler.process(image)
                        
                        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        val textTask = recognizer.process(image)
                        
                        // Wait synchronously in background thread for tasks
                        Tasks.await(Tasks.whenAllComplete(labelTask, textTask))
                        
                        val labelsList = mutableListOf<Map<String, Any>>()
                        if (labelTask.isSuccessful) {
                            for (label in labelTask.result) {
                                labelsList.add(mapOf(
                                    "text" to label.text,
                                    "confidence" to label.confidence.toDouble(),
                                    "index" to label.index
                                ))
                            }
                        }
                        
                        var recognizedText = ""
                        if (textTask.isSuccessful) {
                            recognizedText = textTask.result.text
                        }
                        
                        val responseData = mapOf(
                            "labels" to labelsList,
                            "text" to recognizedText
                        )
                        
                        runOnUiThread {
                            result.success(responseData)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("ANALYSIS_FAILED", e.message ?: "Unknown error during image analysis", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

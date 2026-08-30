package au.com.bitbot.phonetowers.flutter

import android.content.Intent
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "au.com.bitbot.phonetowers.flutter.provider/screenshot"
    private val DEFAULT_SUBJECT = "Aus Phone Towers Problem Report"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler({ call, result ->
            if (call.method == "takeScreenshot") {
                // Dart now sends {"path": ..., "subject": ...} so the email subject (built once,
                // in Dart, from device model/id + app version - see ProblemReportHelper) can carry
                // useful metadata. Fall back to the bare image-path String (pre-existing shape) and
                // a sensible default subject in case an old Dart build or a missing argument shows up.
                val arguments = call.arguments
                if (arguments is Map<*, *>) {
                    val path = arguments["path"] as? String ?: ""
                    val subject = arguments["subject"] as? String ?: DEFAULT_SUBJECT
                    shareFile(path, subject)
                } else {
                    shareFile(arguments as String, DEFAULT_SUBJECT)
                }
            }
            // Note: this method is invoked on the main thread.

        })
    }

//    override fun configureFlutterEngine(@NonNull FlutterEngine flutterEngine)
//    {
//        GeneratedPluginRegistrant.registerWith(flutterEngine);
//        new MethodChannel (flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
//        .setMethodCallHandler(
//            (call, result) -> {
//        // Your existing code
//        if (methodCall.method == "takeScreenshot") {
//            shareFile(methodCall.arguments as String)
//        }
//
//    }
//        );
//    }

    private fun shareFile(image: String, subject: String) {
        val imageFile = File(this.applicationContext.cacheDir, image)
        val filePath = FileProvider.getUriForFile(this, "au.com.bitbot.phonetowers.flutter.provider", imageFile)

        val emailIntent = Intent(android.content.Intent.ACTION_SEND)
        emailIntent.putExtra(android.content.Intent.EXTRA_EMAIL,
                arrayOf("bitbot@bitbot.com.au"))
        emailIntent.putExtra(android.content.Intent.EXTRA_SUBJECT,
                subject)
        emailIntent.putExtra(android.content.Intent.EXTRA_TEXT,
                "Please attach your screenshot, describe the problem and Brad will get back to you...")
        emailIntent.type = "image/png"

        emailIntent.putExtra(Intent.EXTRA_STREAM, filePath)
        startActivity(Intent.createChooser(emailIntent, "Email screenshot to the developer"))
    }
}

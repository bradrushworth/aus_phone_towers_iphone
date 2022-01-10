package au.com.bitbot.phonetowers

import android.content.Intent
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "au.com.bitbot.phonetowers/screenshot"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler({ call, result ->
            if (call.method == "takeScreenshot") {
                shareFile(call.arguments as String)
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

    private fun shareFile(image: String) {
        val imageFile = File(this.applicationContext.cacheDir, image)
        val filePath = FileProvider.getUriForFile(this, "au.com.bitbot.phonetowers", imageFile)

        val emailIntent = Intent(android.content.Intent.ACTION_SEND)
        emailIntent.putExtra(android.content.Intent.EXTRA_EMAIL,
                arrayOf("bitbot@bitbot.com.au"))
        emailIntent.putExtra(android.content.Intent.EXTRA_SUBJECT,
                "Aus Phone Towers Problem Report")
        emailIntent.putExtra(android.content.Intent.EXTRA_TEXT,
                "Please attach your screenshot, describe the problem and Brad will get back to you...")
        emailIntent.type = "image/png"

        emailIntent.putExtra(Intent.EXTRA_STREAM, filePath)
        startActivity(Intent.createChooser(emailIntent, "Email screenshot to the developer"))
    }
}

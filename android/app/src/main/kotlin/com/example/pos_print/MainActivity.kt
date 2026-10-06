package com.example.pos_print

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Logcat me tag "POS_PRINT" filter karke saare logs dekh sakte ho.
 *
 * NEWPOS NEW9220 (Asmart OS) ka printer firmware ke com.pos.device.* SDK se chalta hai.
 * Yahan reflection use kiya hai, taaki sdk.jar ke bina bhi app build ho jaye
 * aur logs me saaf dikhe ki kaunsi class/method mili ya nahi mili.
 */
class MainActivity : FlutterActivity() {

    private val TAG = "POS_PRINT"
    private val CHANNEL = "pos_printer"

    // SDK class names (firmware se runtime par milti hain)
    private val CLS_SDK_MANAGER = "com.pos.device.SDKManager"
    private val CLS_SDK_CALLBACK = "com.pos.device.SDKManagerCallback"
    private val CLS_PRINTER = "com.pos.device.printer.Printer"
    private val CLS_PRINT_TASK = "com.pos.device.printer.PrintTask"
    private val CLS_PRINTER_CALLBACK = "com.pos.device.printer.PrinterCallback"

    // Print dark/halka karne ke liye yahan number do (jaise 100, 150, 200, 250). null = printer ka default.
    private val GRAY_OVERRIDE: Int? = 150

    // true = receipt ke upar ek mota kaala patta (test bar) print hoga.
    // Patta bhi blank aaye = paper/hardware ka masla. Sab theek hone ke baad false kar dena.
    private val PRINT_TEST_BAR = true

    @Volatile
    private var sdkReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine: channel '$CHANNEL' register ho raha hai")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "Method call aaya: ${call.method}")

                when (call.method) {
                    "deviceInfo" -> {
                        result.success(getDeviceInfo())
                    }

                    "printBitmap" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val width = call.argument<Int>("width") ?: 384
                        Log.d(TAG, "printBitmap: bytes=${bytes?.size}, width=$width")

                        if (bytes == null || bytes.isEmpty()) {
                            Log.e(TAG, "ERROR: image bytes null/empty aaye")
                            result.error("NO_DATA", "Image bytes nahi mile", null)
                            return@setMethodCallHandler
                        }

                        // Printing background thread me (UI freeze na ho)
                        Thread {
                            try {
                                val bmp = decodeAndScale(bytes, width)
                                val ok = printWithSdk(bmp)
                                Log.d(TAG, "print result: $ok")
                                runOnUiThread { result.success(ok) }
                            } catch (e: Exception) {
                                Log.e(TAG, "ERROR print me: ${e.javaClass.simpleName}: ${e.message}", e)
                                runOnUiThread {
                                    result.error("PRINT_FAILED", e.message ?: e.toString(), null)
                                }
                            }
                        }.start()
                    }

                    else -> {
                        Log.w(TAG, "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
    }

    /** PNG bytes -> Bitmap, paper width ke hisaab se scale */
    private fun decodeAndScale(bytes: ByteArray, targetWidth: Int): Bitmap {
        Log.d(TAG, "decodeAndScale: start")
        val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalStateException("Bitmap decode fail hua")
        Log.d(TAG, "decoded bitmap: ${src.width} x ${src.height}")

        val targetHeight = (src.height.toFloat() * targetWidth / src.width).toInt()
        val scaled = Bitmap.createScaledBitmap(src, targetWidth, targetHeight, true)
        Log.d(TAG, "scaled bitmap: ${scaled.width} x ${scaled.height}")
        return toBlackWhite(scaled)
    }

    /**
     * Thermal printer ke liye bitmap ko pure black/white banata hai.
     * Transparent hissa white maana jata hai. Blank print ka sabse common reason
     * halka/transparent/grey bitmap hota hai.
     */
    private fun toBlackWhite(src: Bitmap, threshold: Int = 180): Bitmap {
        val w = src.width
        val h = src.height
        val pixels = IntArray(w * h)
        src.getPixels(pixels, 0, w, 0, 0, w, h)

        var black = 0
        for (i in pixels.indices) {
            val p = pixels[i]
            val a = (p ushr 24) and 0xFF
            // alpha ko white background par blend karo
            val r = (((p shr 16) and 0xFF) * a + 255 * (255 - a)) / 255
            val g = (((p shr 8) and 0xFF) * a + 255 * (255 - a)) / 255
            val b = ((p and 0xFF) * a + 255 * (255 - a)) / 255
            val lum = (0.299 * r + 0.587 * g + 0.114 * b).toInt()
            if (lum < threshold) {
                pixels[i] = 0xFF000000.toInt()
                black++
            } else {
                pixels[i] = 0xFFFFFFFF.toInt()
            }
        }
        val pct = black * 100f / (w * h)
        Log.d(TAG, "toBlackWhite: black pixels = $black / ${w * h} ($pct%) -> 0% matlab bitmap hi blank hai")

        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        out.setPixels(pixels, 0, w, 0, 0, w, h)
        return out
    }

    // ============================================================
    //  NEWPOS SDK (com.pos.device.*) - reflection se
    // ============================================================

    /** Proxy ke Object methods (hashCode/equals/toString) handle karne ke liye */
    private fun objectMethod(proxy: Any, m: Method, args: Array<out Any?>?): Any? = when (m.name) {
        "hashCode" -> System.identityHashCode(proxy)
        "equals" -> proxy === args?.getOrNull(0)
        "toString" -> "POS_PRINT_PROXY"
        else -> null
    }

    /** SDKManager.init(context, callback) - sirf ek baar */
    private fun initSdk() {
        if (sdkReady) {
            Log.d(TAG, "initSdk: SDK pehle se ready hai")
            return
        }
        Log.d(TAG, "initSdk: SDKManager.init start")
        val mgrCls = Class.forName(CLS_SDK_MANAGER)
        val cbCls = Class.forName(CLS_SDK_CALLBACK)
        val latch = CountDownLatch(1)

        val cb = Proxy.newProxyInstance(cbCls.classLoader, arrayOf(cbCls)) { proxy, method, args ->
            Log.d(TAG, "SDKManagerCallback.${method.name} aaya")
            if (method.name == "onFinish") latch.countDown()
            objectMethod(proxy, method, args)
        }

        mgrCls.getMethod("init", Context::class.java, cbCls).invoke(null, applicationContext, cb)
        if (!latch.await(10, TimeUnit.SECONDS)) {
            throw IllegalStateException("SDKManager.init 10 sec me complete nahi hua (timeout)")
        }
        sdkReady = true
        Log.d(TAG, "initSdk: SDK ready")
    }

    /**
     * Bitmap print karta hai. true = print success (callback code 0).
     * Kuch bhi galat ho to logcat me exact reason + SDK ke methods ki list aayegi.
     */
    private fun printWithSdk(bitmap: Bitmap): Boolean {
        Log.d(TAG, "printWithSdk: bitmap ${bitmap.width} x ${bitmap.height}")
        try {
            initSdk()


            val printerCls = Class.forName(CLS_PRINTER)
            val taskCls = Class.forName(CLS_PRINT_TASK)
            val cbCls = Class.forName(CLS_PRINTER_CALLBACK)

            val printer = printerCls.getMethod("getInstance").invoke(null)
            Log.d(TAG, "Printer instance mila: $printer")

            // Printer status (paper/temperature etc.) - sirf log ke liye
            try {
                val st = printerCls.getMethod("getStatus").invoke(printer)
                Log.d(TAG, "printer status code: $st (0 = OK hona chahiye)")
            } catch (e: Exception) {
                Log.w(TAG, "getStatus nahi chala: ${e.javaClass.simpleName}: ${e.message}")
            }

            // Printer ki settings log (width/gray/adc/temperature)
            fun readInt(name: String): Int? = try {
                printerCls.getMethod(name).invoke(printer) as? Int
            } catch (e: Exception) {
                Log.w(TAG, "$name nahi chala: ${e.message}")
                null
            }
            val defGray = readInt("getDefaultGray")
            Log.d(
                TAG,
                "printer: width=${readInt("getWidth")}, defaultGray=$defGray, defaultAdc=${readInt("getDefaultAdc")}, " +
                        "temp=${readInt("getTemperature")}, maxTemp=${readInt("getMaxTemperature")}, voltage=${readInt("getVoltage")}"
            )

            val task = taskCls.getDeclaredConstructor().newInstance()
            Log.d(TAG, "task default gray = ${taskCls.getMethod("getGray").invoke(task)}")
            val toPrint = if (PRINT_TEST_BAR) withTestBar(bitmap) else bitmap
            taskCls.getMethod("setPrintBitmap", Bitmap::class.java).invoke(task, toPrint)

            // Gray = print ki darkness. Blank print ka bada reason gray 0/kam hona hota hai.
            val gray = GRAY_OVERRIDE ?: (if (defGray != null && defGray > 0) defGray else 150)
            taskCls.getMethod("setGray", Int::class.javaPrimitiveType!!).invoke(task, gray)
            Log.d(TAG, "task gray set: $gray (ab getGray = ${taskCls.getMethod("getGray").invoke(task)})")
            Log.d(TAG, "PrintTask ready, bitmap set ho gaya")

            val latch = CountDownLatch(1)
            var resultCode = -999
            val cb = Proxy.newProxyInstance(cbCls.classLoader, arrayOf(cbCls)) { proxy, method, args ->
                Log.d(TAG, "PrinterCallback.${method.name} aaya, args=${args?.toList()}")
                if (method.name == "onResult") {
                    resultCode = (args?.getOrNull(0) as? Int) ?: -1
                    latch.countDown()
                }
                objectMethod(proxy, method, args)
            }

            Log.d(TAG, "startPrint call kar rahe hain...")
            printerCls.getMethod("startPrint", taskCls, cbCls).invoke(printer, task, cb)

            if (!latch.await(30, TimeUnit.SECONDS)) {
                throw IllegalStateException("Print callback 30 sec me nahi aaya (timeout)")
            }
            Log.d(TAG, "print callback code: $resultCode")
            if (resultCode != 0) {
                throw IllegalStateException("Printer ne error code diya: $resultCode (paper/battery/temperature check karo)")
            }
            return true

        } catch (e: InvocationTargetException) {
            val real = e.targetException ?: e
            Log.e(TAG, "SDK ke andar error: ${real.javaClass.simpleName}: ${real.message}", real)
            throw IllegalStateException("SDK error: ${real.javaClass.simpleName}: ${real.message}")
        } catch (e: ReflectiveOperationException) {
            // ClassNotFound / NoSuchMethod - naam galat ya SDK mili nahi
            Log.e(TAG, "SDK class/method nahi mila: ${e.javaClass.simpleName}: ${e.message}", e)
            Log.e(TAG, "Neeche SDK classes ke actual methods dump ho rahe hain, ye logs bhej do:")
            dumpSdkClasses()
            throw IllegalStateException("SDK class/method nahi mila: ${e.message}")
        }
    }

    /** Receipt ke upar 40px ka pura kaala patta jodta hai (hardware/paper test ke liye) */
    private fun withTestBar(src: Bitmap): Bitmap {
        val barH = 40
        val out = Bitmap.createBitmap(src.width, src.height + barH + 10, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(out)
        canvas.drawColor(android.graphics.Color.WHITE)
        val paint = android.graphics.Paint().apply { color = android.graphics.Color.BLACK }
        canvas.drawRect(0f, 0f, src.width.toFloat(), barH.toFloat(), paint)
        canvas.drawBitmap(src, 0f, (barH + 10).toFloat(), null)
        Log.d(TAG, "withTestBar: ${out.width} x ${out.height} (upar kaala patta add hua)")
        return out
    }

    /** SDK ki classes aur unke methods log karta hai (galat naam ho to asli naam yahin dikhenge) */
    private fun dumpSdkClasses() {
        listOf(CLS_SDK_MANAGER, CLS_SDK_CALLBACK, CLS_PRINTER, CLS_PRINT_TASK, CLS_PRINTER_CALLBACK).forEach { name ->
            try {
                val c = Class.forName(name)
                Log.d(TAG, "CLASS $name (interface=${c.isInterface})")
                c.methods.forEach { m ->
                    Log.d(TAG, "    ${m.returnType.simpleName} ${m.name}(${m.parameterTypes.joinToString { it.simpleName }})")
                }
            } catch (e: Throwable) {
                Log.w(TAG, "CLASS $name NAHI MILI: ${e.javaClass.simpleName}")
            }
        }
    }

    /** Device + printer se related apps ki list + SDK classes available hain ya nahi */
    private fun getDeviceInfo(): String {
        val sb = StringBuilder()
        sb.appendLine("Manufacturer: ${Build.MANUFACTURER}")
        sb.appendLine("Brand: ${Build.BRAND}")
        sb.appendLine("Model: ${Build.MODEL}")
        sb.appendLine("Device: ${Build.DEVICE}")
        sb.appendLine("Android SDK: ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})")

        sb.appendLine("SDK classes:")
        listOf(CLS_SDK_MANAGER, CLS_PRINTER, CLS_PRINT_TASK, CLS_PRINTER_CALLBACK).forEach { name ->
            val found = try { Class.forName(name); true } catch (e: Throwable) { false }
            sb.appendLine("  - $name : ${if (found) "MILI" else "NAHI MILI"}")
        }

        try {
            val keywords = listOf("print", "worldline", "pine", "ingenico", "asmart", "pos", "sunmi", "pax", "newland", "telpo")
            val apps = packageManager.getInstalledApplications(0)
                .map { it.packageName }
                .filter { pkg -> keywords.any { pkg.lowercase().contains(it) } }
                .sorted()
            sb.appendLine("Printer/POS related packages (${apps.size}):")
            apps.forEach { sb.appendLine("  - $it") }
        } catch (e: Exception) {
            sb.appendLine("Package list error: ${e.message}")
        }

        val info = sb.toString()
        Log.d(TAG, "deviceInfo:\n$info")
        return info
    }
}
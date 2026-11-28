package com.varnix.ai.ultimateplus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.myket.billingclient.IabHelper
import ir.myket.billingclient.util.IabResult

class MainActivity : FlutterActivity() {
    private val channelName = "com.varnix.ai.ultimateplus/myket"
    private val subscriptionSku = "varnix_pro_30days_sub"
    private var billingHelper: IabHelper? = null
    private var setupInProgress = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> initializeBilling(result)
                    "querySubscription" -> querySubscription(result)
                    "purchaseSubscription" -> {
                        val payload = call.argument<String>("developerPayload").orEmpty()
                        purchaseSubscription(payload, result)
                    }
                    "dispose" -> {
                        billingHelper?.dispose()
                        billingHelper = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeBilling(result: MethodChannel.Result) {
        if (billingHelper != null) {
            result.success(mapOf("ready" to true))
            return
        }
        if (setupInProgress) {
            result.error("BILLING_BUSY", "اتصال به مایکت در حال آماده‌سازی است.", null)
            return
        }
        val publicKey = BuildConfig.MYKET_RSA_KEY
        if (publicKey.isBlank()) {
            result.error("MISSING_RSA_KEY", "کلید عمومی مایکت در تنظیمات ساخت APK قرار نگرفته است.", null)
            return
        }
        setupInProgress = true
        val helper = IabHelper(this, publicKey)
        helper.enableDebugLogging(BuildConfig.DEBUG, "VarnixMyket")
        billingHelper = helper
        helper.startSetup { setupResult: IabResult ->
            setupInProgress = false
            if (setupResult.isSuccess()) {
                result.success(mapOf("ready" to true))
            } else {
                billingHelper?.dispose()
                billingHelper = null
                result.error("MYKET_SETUP_FAILED", setupResult.message, null)
            }
        }
    }

    private fun purchaseReceipt(purchase: ir.myket.billingclient.util.Purchase): Map<String, Any?> =
        mapOf(
            "active" to (purchase.getPurchaseState() == 0),
            "sku" to purchase.getSku(),
            "orderId" to purchase.getOrderId(),
            "purchaseTime" to purchase.getPurchaseTime(),
            "originalJson" to purchase.getOriginalJson(),
            "signature" to purchase.getSignature(),
            "purchaseToken" to purchase.getToken()
        )

    private fun querySubscription(result: MethodChannel.Result) {
        val helper = billingHelper
        if (helper == null) {
            result.error("BILLING_NOT_READY", "ابتدا اتصال مایکت را برقرار کنید.", null)
            return
        }
        helper.queryInventoryAsync(true, listOf(subscriptionSku)) { queryResult, inventory ->
            if (!queryResult.isSuccess() || inventory == null) {
                result.error("MYKET_QUERY_FAILED", queryResult.message, null)
                return@queryInventoryAsync
            }
            val purchase = inventory.getPurchase(subscriptionSku)
            if (purchase == null || purchase.getPurchaseState() != 0) {
                result.success(mapOf("active" to false, "sku" to subscriptionSku))
                return@queryInventoryAsync
            }
            result.success(purchaseReceipt(purchase))
        }
    }

    private fun purchaseSubscription(payload: String, result: MethodChannel.Result) {
        val helper = billingHelper
        if (helper == null) {
            result.error("BILLING_NOT_READY", "اتصال مایکت آماده نیست.", null)
            return
        }
        if (payload.isBlank() || payload.length > 128) {
            result.error("INVALID_PURCHASE_PAYLOAD", "شناسه امن خرید معتبر نیست.", null)
            return
        }
        helper.launchSubscriptionPurchaseFlow(
            this,
            subscriptionSku,
            { purchaseResult, purchase ->
                if (!purchaseResult.isSuccess() || purchase == null) {
                    result.error("PURCHASE_FAILED", purchaseResult.message, null)
                    return@launchSubscriptionPurchaseFlow
                }
                val valid = purchase.getSku() == subscriptionSku &&
                    purchase.getPurchaseState() == 0 &&
                    purchase.getDeveloperPayload() == payload
                if (!valid) {
                    result.error("PURCHASE_INVALID", "تأیید اولیه خرید اشتراک ناموفق بود.", null)
                    return@launchSubscriptionPurchaseFlow
                }
                result.success(purchaseReceipt(purchase))
            },
            payload
        )
    }

    override fun onDestroy() {
        billingHelper?.dispose()
        billingHelper = null
        super.onDestroy()
    }
}

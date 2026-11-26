package com.varnix.ai.ultimateplus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.myket.billingclient.IabHelper
import ir.myket.billingclient.util.IabResult
import java.util.UUID

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
                    "purchaseSubscription" -> purchaseSubscription(result)
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
            val active = purchase != null && purchase.getPurchaseState() == 0
            result.success(
                mapOf(
                    "active" to active,
                    "sku" to subscriptionSku,
                    "orderId" to purchase?.getOrderId(),
                    "purchaseTime" to purchase?.getPurchaseTime()
                )
            )
        }
    }

    private fun purchaseSubscription(result: MethodChannel.Result) {
        val helper = billingHelper
        if (helper == null) {
            result.error("BILLING_NOT_READY", "اتصال مایکت آماده نیست.", null)
            return
        }
        val payload = UUID.randomUUID().toString()
        // Use Myket's dedicated subscription API rather than the generic item flow.
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
                    result.error("PURCHASE_INVALID", "تأیید خرید اشتراک ناموفق بود.", null)
                    return@launchSubscriptionPurchaseFlow
                }
                result.success(
                    mapOf(
                        "active" to true,
                        "sku" to purchase.getSku(),
                        "orderId" to purchase.getOrderId(),
                        "purchaseTime" to purchase.getPurchaseTime()
                    )
                )
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

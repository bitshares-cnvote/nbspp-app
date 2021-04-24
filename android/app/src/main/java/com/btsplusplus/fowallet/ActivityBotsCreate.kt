package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_bots_create.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityBotsCreate : BtsppActivity() {

    private var _op_data = JSONObject()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_bots_create)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val result_promise = args.opt("result_promise") as? Promise

        //  最低价格
        tv_min_price.let { tv ->
            tv.setOnClickListener {
                onInputDecimalClicked(title = resources.getString(R.string.kBotsCreateCellTitleMinPrice),
                        placeholder = resources.getString(R.string.kBotsCreateCellPlaceHolderMinPrice),
                        precision = 8,
                        n_min_value = null,
                        n_max_value = null,
                        n_scale = BigDecimal.ONE.multiplyByPowerOf10(8)) { n_value ->
                    _op_data.put("min_price", n_value.setScale(0))
                    tv.text = bigDecimalfromAmount(n_value.toPlainString(), 8).toPriceAmountString()
                }
            }
        }

        //  最高价格
        tv_max_price.let { tv ->
            tv.setOnClickListener {
                onInputDecimalClicked(title = resources.getString(R.string.kBotsCreateCellTitleMaxPrice),
                        placeholder = resources.getString(R.string.kBotsCreateCellPlaceHolderMaxPrice),
                        precision = 8,
                        n_min_value = null,
                        n_max_value = null,
                        n_scale = BigDecimal.ONE.multiplyByPowerOf10(8)) { n_value ->
                    _op_data.put("max_price", n_value.setScale(0))
                    tv.text = bigDecimalfromAmount(n_value.toPlainString(), 8).toPriceAmountString()
                }
            }
        }

        //  网格数量
        tv_grid_n.let { tv ->
            tv.setOnClickListener {
                onInputDecimalClicked(title = resources.getString(R.string.kBotsCreateCellTitleGridN),
                        placeholder = resources.getString(R.string.kBotsCreateCellPlaceHolderGridN),
                        precision = 0,
                        n_min_value = BigDecimal.valueOf(2),
                        n_max_value = BigDecimal.valueOf(99),
                        n_scale = null) { n_value ->
                    _op_data.put("grid_n", n_value)
                    tv.text = n_value.toPlainString()
                }
            }
        }

        //  每格交易数量
        tv_amount_per_grid.let { tv ->
            tv.setOnClickListener {
                val quote = _op_data.optJSONObject("quote")
                if (quote == null) {
                    showToast(resources.getString(R.string.kBotsCreateTipSelectQuoteAssetFirst))
                } else {
                    val precision = quote.getInt("precision")
                    onInputDecimalClicked(title = resources.getString(R.string.kBotsCreateCellTitleAmountPerGrid),
                            placeholder = resources.getString(R.string.kBotsCreateCellPlaceHolderAmountPerGrid),
                            precision = precision,
                            n_min_value = null,
                            n_max_value = null,
                            n_scale = BigDecimal.ONE.multiplyByPowerOf10(precision)) { n_value ->
                        _op_data.put("order_amount", n_value.setScale(0))
                        tv.text = bigDecimalfromAmount(n_value.toPlainString(), precision).toPriceAmountString()
                    }
                }
            }
        }

        //  交易资产
        tv_quote.let { tv ->
            tv.setOnClickListener {
                onSelectAsset(tv, ENetworkSearchType.enstAssetAll, "quote")
            }
        }

        //  报价资产
        tv_base.let { tv ->
            tv.setOnClickListener {
                onSelectAsset(tv, ENetworkSearchType.enstAssetAll, "base")
            }
        }

        //  返回按钮事件
        layout_back_activity.setOnClickListener { finish() }

        //  创建按钮事件
        btn_op_create_bots.setOnClickListener { onCreateButtonClicked(result_promise) }
    }

    private fun onSelectAsset(targetLabel: TextView, searchType: ENetworkSearchType, opKeyName: String) {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
            last_activity.goTo(ActivityBotsCreate::class.java, true, back = true)
            //  选择完毕
            if (opKeyName == "quote") {
                val old_quote = _op_data.optJSONObject("quote")
                if (old_quote != null && old_quote.getString("id") != asset_info.getString("id")) {
                    _op_data.remove("order_amount")
                    //  clear
                    tv_amount_per_grid.text = ""
                }
            }
            //  保存
            _op_data.put(opKeyName, asset_info)
            //  刷新UI
            targetLabel.text = asset_info.getString("symbol")
        }
        val title = resources.getString(R.string.kVcTitleSearchAssets)
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", searchType)
            put("kTitle", title)
        })
    }

    /**
     *  事件 - 部分数字输入框点击
     */
    private fun onInputDecimalClicked(title: String, placeholder: String, precision: Int, n_min_value: BigDecimal?, n_max_value: BigDecimal?, n_scale: BigDecimal?, callback: (n_value: BigDecimal) -> Unit) {
        UtilsAlert.showInputBox(this, title = title, placeholder = placeholder, is_password = false, iDecimalPrecision = precision).then {
            val value = it as? String
            if (value != null) {
                var n_value = Utils.auxGetStringDecimalNumberValue(value)
                //  最小值
                if (n_min_value != null && n_value < n_min_value) {
                    n_value = n_min_value
                }
                //  最大值
                if (n_max_value != null && n_value > n_max_value) {
                    n_value = n_max_value
                }
                //  缩放
                if (n_scale != null) {
                    n_value = n_value.multiply(n_scale)
                }
                callback(n_value)
            }
            return@then null
        }
    }

    private fun onCreateButtonClicked(result_promise: Promise?) {
        //  检查参数有效性
        val base = _op_data.optJSONObject("base")
        if (base == null) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseSelectBase))
            return
        }

        val quote = _op_data.optJSONObject("quote")
        if (quote == null) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseSelectQuote))
            return
        }

        val base_id = base.getString("id")
        val quote_id = quote.getString("id")
        if (base_id == quote_id) {
            showToast(resources.getString(R.string.kBotsCreateTipQuoteAndBaseIsSame))
            return
        }

        val grid_n = _op_data.opt("grid_n") as BigDecimal?
        if (grid_n == null) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseInputGridN))
            return
        }
        if (grid_n < BigDecimal.valueOf(2) || grid_n > BigDecimal.valueOf(99)) {
            showToast(resources.getString(R.string.kBotsCreateTipInvalidGridNRange))
            return
        }

        val order_amount = _op_data.optString("order_amount")
        if (order_amount.isEmpty()) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseInputAmountPerGrid))
            return
        }
        val n_order_amount = bigDecimalfromAmount(order_amount, quote.getInt("precision"))
        if (n_order_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseInputAmountPerGrid))
            return
        }

        var n_min_price: BigDecimal? = null
        val min_price = _op_data.optString("min_price")
        if (min_price.isNotEmpty()) {
            n_min_price = bigDecimalfromAmount(min_price, 8)
        }
        if (n_min_price == null || n_min_price <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseInputMinPrice))
            return
        }

        var n_max_price: BigDecimal? = null
        val max_price = _op_data.optString("max_price")
        if (max_price.isNotEmpty()) {
            n_max_price = bigDecimalfromAmount(max_price, 8)
        }
        if (n_max_price == null || n_max_price <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseInputMaxPrice))
            return
        }
        if (n_max_price <= n_min_price) {
            showToast(resources.getString(R.string.kBotsCreateTipPleaseReinputMinOrMaxPrice))
            return
        }

        guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
                val op_account_id = op_account.getString("id")

                val init_bots_data = JSONObject().apply {
                    put("args", JSONObject().apply {
                        put("grid_n", grid_n.toInt())
                        put("min_price", min_price)
                        put("max_price", max_price)
                        put("order_amount", order_amount)
                        put("base", base_id)
                        put("quote", quote_id)
                    })
                    put("status", "created")
                }

                val bots_key = FragmentBotsManager.calcBotsKey(init_bots_data.getJSONObject("args"), kAppStorageCatalogBotsGridBots, op_account_id)
                val key_values = jsonArrayfrom(jsonArrayfrom(bots_key, init_bots_data.toString()))

                val chainMgr = ChainObjectManager.sharedChainObjectManager()
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

                val p1 = chainMgr.queryAccountAllBotsData(op_account_id)
                val p2 = chainMgr.queryAllGrapheneObjectsSkipCache(jsonArrayfrom(op_account_id))

                Promise.all(p1, p2).then {
                    val data_array = it as JSONArray
                    val result_hash = data_array.getJSONObject(0)
                    val latest_storage_item = result_hash.optJSONObject(bots_key)
                    if (latest_storage_item != null) {
                        mask.dismiss()
                        showToast(resources.getString(R.string.kBotsCreateTipPleaseAdjustBotsArgs))
                        return@then null
                    }

                    return@then BitsharesClientManager.sharedBitsharesClientManager().accountStorageMap(op_account_id, false, kAppStorageCatalogBotsGridBots, key_values).then {
                        mask.dismiss()
                        showToast(resources.getString(R.string.kBotsCreateTipCreateOK))
                        //  返回上一个界面并刷新
                        finish()
                        result_promise?.resolve(true)
                        return@then null
                    }
                }.catch { err ->
                    mask.dismiss()
                    showGrapheneError(err)
                }
            }
        }
    }
}

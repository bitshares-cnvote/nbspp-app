package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.math.BigInteger

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentBotsManager.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentBotsManager.newInstance] factory method to
 * create an instance of this fragment.
 *
 */

const val kBotsAuthorizationStatus_AlreadyAuthorized = 0
const val kBotsAuthorizationStatus_ContinueToAuthorize = 1
const val kBotsAuthorizationStatus_StopAuthorization = 2

class FragmentBotsManager : BtsppFragment() {

    companion object {

        /**
         *  (public) 计算机器人的 bots_key。
         */
        fun calcBotsKey(bots_args: JSONObject, catalog: String, account_id: String): String {
            val args = bots_args.deepClone().apply {
                put("__bots_owner", account_id)
                put("__bots_type", catalog)
            }
            val sign_str = args.keys().toArrayList().sorted().map { arg_key -> String.format("%s=%s", arg_key, args.getString(arg_key)) }.joinToString("&")
            return sign_str.md5()
        }

        /**
         *  (public) 是否已授权服务器端处理量化交易判断。
         */
        fun isAuthorizedToTheBotsManager(latest_account_data: JSONObject): Boolean {
            val active_permission = latest_account_data.getJSONObject("active")
            val const_bots_account_id = SettingManager.sharedSettingManager().getAppGridBotsTraderAccount()
            val weight_threshold = active_permission.getInt("weight_threshold")
            for (item in active_permission.getJSONArray("account_auths").forin<JSONArray>()) {
                val account = item!!.getString(0)
                if (const_bots_account_id != account) {
                    continue
                }
                val weight = item.getInt(1)
                if (weight >= weight_threshold) {
                    return true
                }
            }
            return false
        }

    }

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _view: View? = null
    private var _dataArray = mutableListOf<JSONObject>()
    private lateinit var _full_account_data: JSONObject

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _full_account_data = json.getJSONObject("full_account_data")
    }

    /**
     *  (public) 查询清算单
     */
    fun queryMyBotsList(full_account_data: JSONObject) {
        waitingOnCreateView().then {
            _queryMyBotsListCore(full_account_data)
        }
    }

    private fun _queryMyBotsListCore(full_account_data: JSONObject) {
        activity?.let { ctx ->
            val op_account = full_account_data.getJSONObject("account")
            val account_name = op_account.getString("name")

            val chainMgr = ChainObjectManager.sharedChainObjectManager()

            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }

            chainMgr.queryAccountStorageInfo(account_name, kAppStorageCatalogBotsGridBots).then {
                val data_array = it as? JSONArray

                val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

                val pair_promise_hash = JSONObject()
                val asset_ids = JSONObject()

                if (data_array != null && data_array.length() > 0) {
                    for (storage_item in data_array.forin<JSONObject>()) {
                        val value = storage_item!!.optJSONObject("value")
                        if (value != null) {
                            val args = value.optJSONObject("args")
                            if (args != null) {
                                val base = args.optString("base")
                                val quote = args.optString("quote")
                                if (base.isNotEmpty()) {
                                    asset_ids.put(base, true)
                                }
                                if (quote.isNotEmpty()) {
                                    asset_ids.put(quote, true)
                                }
                                if (base.isNotEmpty() && quote.isNotEmpty()) {
                                    //  相同交易对只查询1次
                                    val pair_key = "${base}_$quote"
                                    if (!pair_promise_hash.has(pair_key)) {
                                        pair_promise_hash.put(pair_key, conn.async_exec_db("get_ticker", jsonArrayfrom(base, quote)))
                                    }
                                }
                            }
                        }
                    }
                }

                val asset_id_array = asset_ids.keys().toJSONArray()

                val p1 = Promise.all(pair_promise_hash.values())
                val p2 = chainMgr.queryAllGrapheneObjects(asset_id_array)
                val p3 = chainMgr.queryAccountBalance(op_account.getString("id"), asset_id_array = asset_id_array)
                val p4 = conn.async_exec_db("get_limit_orders_by_account", jsonArrayfrom(op_account.getString("id")))

                return@then Promise.all(p1, p2, p3, p4).then {
                    val ary = it as? JSONArray
                    onQueryMyBotsListResponsed(data_array, ticker_data_array = ary?.optJSONArray(0), balance_array = ary?.optJSONArray(2), limit_orders = ary?.optJSONArray(3))
                    mask.dismiss()
                    return@then null
                }
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
            }
            return@let
        }
    }

    private fun onQueryMyBotsListResponsed(data_container: Any?, ticker_data_array: JSONArray? = null, balance_array: JSONArray? = null, limit_orders: JSONArray? = null) {
        _dataArray.clear()

        //  处理数据
        if (data_container != null) {
            var data_array: JSONArray? = null
            if (data_container is JSONArray) {
                data_array = data_container
            } else if (data_container is JSONObject) {
                data_array = data_container.values()
            }
            if (data_array != null) {
                for (storage_item in data_array.forin<JSONObject>()) {
                    val valid = isValidBotsData(storage_item)

                    val value = storage_item!!.optJSONObject("value")
                    val status = value?.optString("status", null)

                    var tipmsg = ""

                    if (valid && status != null) {
                        if (status == "running") {
                            val i_init_time = value!!.optJSONObject("ext")?.optInt("init_time") ?: 0
                            val now_ts = Utils.now_ts()
                            val run_ts = Math.max(now_ts - i_init_time, 1)  //  REMARK：有可能有时间误差，默认最低取值1秒。
                            val run_days = run_ts / 86400
                            val run_hours = run_ts % 86400 / 3600
                            val run_mins = run_ts % 86400 % 3600 / 60
                            val run_secs = run_ts % 86400 % 3600 % 60
                            tipmsg = if (run_days > 0) {
                                String.format(resources.getString(R.string.kBotsCellLabelMsgRunTimeDHMS), run_days.toString(), run_hours.toString(), run_mins.toString(), run_secs.toString())
                            } else if (run_hours > 0) {
                                String.format(resources.getString(R.string.kBotsCellLabelMsgRunTimeHMS), run_hours.toString(), run_mins.toString(), run_secs.toString())
                            } else if (run_mins > 0) {
                                String.format(resources.getString(R.string.kBotsCellLabelMsgRunTimeMS), run_mins.toString(), run_secs.toString())
                            } else {
                                String.format(resources.getString(R.string.kBotsCellLabelMsgRunTimeS), run_secs.toString())
                            }
                        } else if (status == "created") {
                            //  刚创建，不显示提示信息。
                        } else {
                            tipmsg = value!!.optString("msg")
                        }
                    } else {
                        tipmsg = resources.getString(R.string.kBotsCellLabelMsgInvalidGrid)
                    }

                    _dataArray.add(JSONObject().apply {
                        put("valid", valid)
                        put("raw", storage_item)
                        put("tipmsg", tipmsg)
                    })
                }
            }
        }

        //  ticker数据，估值用。
        val data_ticker_hash = JSONObject()
        ticker_data_array?.let { list ->
            for (ticker_data in list.forin<JSONObject>()) {
                val pair_key = "${ticker_data!!.getString("base")}_${ticker_data.getString("quote")}"
                data_ticker_hash.put(pair_key, ticker_data)
            }
        }

        //  统计余额数据，估值用。
        val data_balance_hash = JSONObject()
        balance_array?.let { list ->
            for (balance in list.forin<JSONObject>()) {
                data_balance_hash.put(balance!!.getString("asset_id"), balance.getString("amount"))
            }
        }

        limit_orders?.let { list ->
            for (orders in list.forin<JSONObject>()) {
                val for_sale = orders!!.getString("for_sale")
                val sell_asset_id = orders.getJSONObject("sell_price").getJSONObject("base").getString("asset_id")
                if (data_balance_hash.has(sell_asset_id)) {
                    data_balance_hash.put(sell_asset_id, BigInteger(data_balance_hash.getString(sell_asset_id)).add(BigInteger(for_sale)).toString())
                } else {
                    data_balance_hash.put(sell_asset_id, for_sale)
                }
            }
        }

        //  根据ID降序排列
        if (_dataArray.size > 0) {
            _dataArray.sortByDescending { it.getJSONObject("raw").getString("id").split(".").last().toInt() }
        }

        //  刷新UI
        refreshUI(ticker_data_hash = data_ticker_hash, balance_hash = data_balance_hash)
    }

    /**
     *  (private) 是否是有效的机器人策略数据判断。
     */
    private fun isValidBotsData(storage_item: JSONObject?): Boolean {
        if (storage_item == null) {
            return false
        }
        val bots_key = storage_item.optString("key")
        if (bots_key.isEmpty()) {
            return false
        }
        val value = storage_item.optJSONObject("value")
        if (value == null) {
            return false
        }

        //  验证基本参数
        val args = value.optJSONObject("args")
        if (args == null) {
            return false
        }

        if (!args.has("grid_n") ||
                !args.has("min_price") ||
                !args.has("max_price") ||
                !args.has("order_amount") ||
                !args.has("base") ||
                !args.has("quote")) {
            return false
        }

        if (args.getString("base") == args.getString("quote")) {
            return false
        }

        //  验证 bots_key。
        val calcd_bots_key = FragmentBotsManager.calcBotsKey(args, storage_item.getString("catalog"), storage_item.getString("account"))
        if (calcd_bots_key != bots_key) {
            return false
        }

        return true
    }

    private fun refreshUI(ticker_data_hash: JSONObject? = null, balance_hash: JSONObject? = null) {
        if (_view == null) {
            return
        }
        if (this.activity == null) {
            return
        }
        val container: LinearLayout = _view!!.findViewById(R.id.layout_all_grid_orders)
        container.removeAllViews()

        if (_dataArray.size > 0) {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(24f))
            layout_params.gravity = Gravity.CENTER_VERTICAL
            for (item in _dataArray) {
                container.addView(createCell(item, ticker_data_hash, balance_hash, container))
            }
        } else {
            container.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, resources.getString(R.string.kBotsNoAnyGridBots)))
        }
    }

    private fun _getBalanceByAsset(asset: JSONObject, balance_hash: JSONObject): BigDecimal {
        val asset_id = asset.getString("id")
        return if (balance_hash.has(asset_id)) {
            bigDecimalfromAmount(balance_hash.getString(asset_id), asset.getInt("precision"))
        } else {
            BigDecimal.ZERO
        }
    }

    private fun _estimatedByBaseAsset(duck_ticker_data: JSONObject, n_base: BigDecimal, n_quote: BigDecimal): BigDecimal? {
        val highest_bid = duck_ticker_data.optString("highest_bid")
        val lowest_ask = duck_ticker_data.optString("lowest_ask")
        if (highest_bid.isEmpty() || lowest_ask.isEmpty()) {
            return null
        }
        val n_highest_bid = BigDecimal(highest_bid)
        val n_lowest_ask = BigDecimal(lowest_ask)
        val n_mid_price = n_highest_bid.add(n_lowest_ask).divide(BigDecimal(2), 16, BigDecimal.ROUND_UP)
        return n_quote.multiply(n_mid_price).add(n_base)
    }

    private fun _calcProfitAndApy(base_asset: JSONObject?, quote_asset: JSONObject?, ext_data: JSONObject?, n_total_arbitrage: BigDecimal?, ticker_data_hash: JSONObject?, balance_hash: JSONObject?): JSONObject? {
        if (ticker_data_hash == null || balance_hash == null) {
            return null
        }

        if (base_asset == null || quote_asset == null || ext_data == null || n_total_arbitrage == null) {
            return null
        }

        val pair_key = "${base_asset.getString("symbol")}_${quote_asset.getString("symbol")}"
        val ticker_data = ticker_data_hash.optJSONObject(pair_key)
        if (ticker_data == null) {
            return null
        }

        val base_precision = base_asset.getInt("precision")
        val quote_precision = quote_asset.getInt("precision")

        val n_init_balance_base = bigDecimalfromAmount(ext_data.optLong("init_balance_base").toString(), base_precision)
        val n_init_balance_quote = bigDecimalfromAmount(ext_data.optLong("init_balance_quote").toString(), quote_precision)
        val n_cancelled_order_base = bigDecimalfromAmount(ext_data.optLong("cancelled_order_base").toString(), base_precision)
        val n_cancelled_order_quote = bigDecimalfromAmount(ext_data.optLong("cancelled_order_quote").toString(), quote_precision)

        //  网格启动时候的账号总金额
        val n_started_base_balance = n_init_balance_base.add(n_cancelled_order_base)
        val n_started_quote_balance = n_init_balance_quote.add(n_cancelled_order_quote)

        //  网格启动初始化挂单金额

        val n_init_order_base = bigDecimalfromAmount(ext_data.optLong("init_order_base").toString(), base_precision)
        val n_init_order_quote = bigDecimalfromAmount(ext_data.optLong("init_order_quote").toString(), quote_precision)

        //  网格启动挂单完毕剩余的金额（多余的资金）
        val n_left_base = n_started_base_balance.subtract(n_init_order_base)
        val n_left_quote = n_started_quote_balance.subtract(n_init_order_quote)

        //  现在状态下的总金额
        val n_now_base_balance = _getBalanceByAsset(base_asset, balance_hash)
        val n_now_quote_balance = _getBalanceByAsset(quote_asset, balance_hash)

        val n_valid_base = n_now_base_balance.subtract(n_left_base)
        val n_valid_quote = n_now_quote_balance.subtract(n_left_quote)

        //  折算
        val n_est_old_base = _estimatedByBaseAsset(ext_data, n_init_order_base, n_init_order_quote)
        val n_est_now_base = _estimatedByBaseAsset(ticker_data, n_valid_base, n_valid_quote)
        if (n_est_old_base == null || n_est_now_base == null) {
            return null
        }

        //  浮动盈亏（以 base 资产计价）
        val n_profit = n_est_now_base.subtract(n_est_old_base).setScale(base_precision, BigDecimal.ROUND_UP)

        val now_ts = Utils.now_ts()
        val start_ts = ext_data.optInt("init_time")
        val diff_ts = Math.max(now_ts - start_ts, 1)    //  REMARK：有可能有时间误差，默认最低取值1秒。
        //  31622400 - 366天的秒数
        val n_apy = n_total_arbitrage.divide(n_est_old_base, 16, BigDecimal.ROUND_UP).multiply(BigDecimal(31622400)).divide(BigDecimal(diff_ts), 16, BigDecimal.ROUND_UP).multiplyByPowerOf10(2).setScale(2, BigDecimal.ROUND_UP)

        return JSONObject().apply {
            put("n_profit", n_profit)
            put("n_apy", n_apy)
        }
    }

    private fun createCell(data: JSONObject, ticker_data_hash: JSONObject?, balance_hash: JSONObject?, container: LinearLayout): LinearLayout {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  准备数据
        val storage_item = data.getJSONObject("raw")
        val value = storage_item.optJSONObject("value")
        val args = value?.optJSONObject("args")

        var base_asset: JSONObject? = null
        var quote_asset: JSONObject? = null
        var n_min_price: BigDecimal? = null
        var n_max_price: BigDecimal? = null
        var i_grid_n = 0
        var n_amount_per_grid: BigDecimal? = null
        var n_total_arbitrage: BigDecimal? = null
        if (args != null) {
            val base_id = args.optString("base")
            val quote_id = args.optString("quote")
            if (base_id.isNotEmpty()) {
                base_asset = chainMgr.getChainObjectByID(base_id)
            }
            if (quote_id.isNotEmpty()) {
                quote_asset = chainMgr.getChainObjectByIDSafe(quote_id)
                if (quote_asset != null) {
                    n_amount_per_grid = bigDecimalfromAmount(args.getString("order_amount"), quote_asset.getInt("precision"))
                }
            }
            i_grid_n = args.getInt("grid_n")
            n_min_price = bigDecimalfromAmount(args.getString("min_price"), 8)
            n_max_price = bigDecimalfromAmount(args.getString("max_price"), 8)
        }

        //  数据：套利次数和总套利金额
        val bid_num = value.optInt("bid_num")
        val ask_num = value.optInt("ask_num")
        val i_arbitrage = Math.min(bid_num, ask_num)
        if (base_asset != null && n_min_price != null && n_max_price != null && i_grid_n > 0 && n_amount_per_grid != null) {
            if (i_arbitrage > 0) {
                //  total = (max - min) / i_grid_n * amount_per_grid * i_arbitrage
                val n_grid_n = BigDecimal(i_grid_n)
                val n_arbitrage = BigDecimal(i_arbitrage)
                n_total_arbitrage = n_max_price.subtract(n_min_price).multiply(n_amount_per_grid).multiply(n_arbitrage).divide(n_grid_n, base_asset.getInt("precision"), BigDecimal.ROUND_UP)
            } else {
                n_total_arbitrage = BigDecimal.ZERO
            }
        }

        //  计算收益等相关数据
        val profit_apy_hash = _calcProfitAndApy(base_asset, quote_asset, value.optJSONObject("ext"), n_total_arbitrage, ticker_data_hash, balance_hash)

        //  第一行 交易对 - 状态
        val quote_symbol = if (quote_asset != null) quote_asset.getString("symbol") else "--"
        val base_symbol = if (base_asset != null) base_asset.getString("symbol") else "--"

        //  创建UI
        val cell = layoutInflater.inflate(R.layout.partial_cell_grid_bots_info, container, false).apply {
            //  第一行 交易对等
            findViewById<TextView>(R.id.tv_pair_name).text = String.format(resources.getString(R.string.kBotsCellLabelPairNameTitle), storage_item.getString("id").split(".").last(), quote_symbol, base_symbol)
            //  状态
            findViewById<TextView>(R.id.tv_status_flag).let { tv ->
                if (data.isTrue("valid") && value.has("status")) {
                    val status = value.getString("status")
                    if (status == "running") {
                        tv.text = resources.getString(R.string.kBotsCellLabelStatusRunning)
                        tv.background = resources.getDrawable(R.drawable.flag_buycolor)
                    } else {
                        tv.text = if (status == "created") {
                            resources.getString(R.string.kBotsCellLabelStatusCreated)
                        } else {
                            resources.getString(R.string.kBotsCellLabelStatusStopped)
                        }
                        tv.background = resources.getDrawable(R.drawable.flag_graycolor)
                    }
                } else {
                    tv.text = resources.getString(R.string.kBotsCellLabelStatusInvalid)
                    tv.background = resources.getDrawable(R.drawable.flag_settlement)
                }
            }

            //  第一排属性
            findViewById<TextView>(R.id.tv_price_range).let { tv ->
                tv.text = if (n_min_price != null && n_max_price != null) {
                    String.format("%s ~ %s", n_min_price.toPriceAmountString(), n_max_price.toPriceAmountString())
                } else {
                    "-- ~ --"
                }
            }
            findViewById<TextView>(R.id.tv_grid_n_and_amount_per_grid).let { tv ->
                tv.text = if (n_amount_per_grid != null) {
                    String.format("%s/%s", i_grid_n.toString(), n_amount_per_grid.toPriceAmountString())
                } else {
                    String.format("%s/%s", i_grid_n.toString(), "--")
                }
            }
            findViewById<TextView>(R.id.tv_trade_num).let { tv ->
                tv.text = String.format("%s/%s", i_arbitrage.toString(), value.optInt("trade_num").toString())
            }

            //  第二排属性
            findViewById<TextView>(R.id.tv_total_arbitrage).let { tv ->
                if (n_total_arbitrage != null) {
                    if (n_total_arbitrage > BigDecimal.ZERO) {
                        tv.text = String.format("+%s", n_total_arbitrage.toPriceAmountString())
                        tv.setTextColor(resources.getColor(R.color.theme01_buyColor))
                    } else {
                        tv.text = "0"
                        tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    }
                } else {
                    tv.text = "--"
                    tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
            }
            findViewById<TextView>(R.id.tv_profit).let { tv ->
                if (profit_apy_hash != null) {
                    val n_profit = profit_apy_hash.get("n_profit") as BigDecimal
                    if (n_profit > BigDecimal.ZERO) {
                        tv.text = String.format("+%s", n_profit.toPriceAmountString())
                        tv.setTextColor(resources.getColor(R.color.theme01_buyColor))
                    } else if (n_profit < BigDecimal.ZERO) {
                        tv.text = n_profit.toPriceAmountString()
                        tv.setTextColor(resources.getColor(R.color.theme01_sellColor))
                    } else {
                        tv.text = "0"
                        tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    }
                } else {
                    tv.text = "--"
                    tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
            }
            findViewById<TextView>(R.id.tv_apy).let { tv ->
                if (profit_apy_hash != null) {
                    val n_apy = profit_apy_hash.get("n_apy") as BigDecimal
                    tv.text = String.format("%s%%", n_apy.toPlainString())
                    if (n_apy > BigDecimal.ZERO) {
                        tv.setTextColor(resources.getColor(R.color.theme01_buyColor))
                    } else if (n_apy < BigDecimal.ZERO) {
                        tv.setTextColor(resources.getColor(R.color.theme01_sellColor))
                    } else {
                        tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    }
                } else {
                    tv.text = "--%"
                    tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
            }
            //  描述信息
            findViewById<TextView>(R.id.tv_message).let { tv ->
                val tipmsg = data.optString("tipmsg")
                if (tipmsg.isEmpty()) {
                    tv.visibility = View.GONE
                } else {
                    tv.visibility = View.VISIBLE
                    tv.text = tipmsg
                }
            }

            //  事件 - CELL点击
            setOnClickListener { onCellClicked(data) }
        }

        return cell as LinearLayout
    }

    private fun onCellClicked(data: JSONObject) {
        val list = arrayOf(
                resources.getString(R.string.kBotsActionStart),
                resources.getString(R.string.kBotsActionStop),
                resources.getString(R.string.kBotsActionDelete))
        ViewSelector.show(activity!!, "", list) { index: Int, result: String ->
            when (index) {
                0 -> {  //  启动
                    processingAuthorizationServer().then {
                        val authorizationStatus = it as Int
                        when (authorizationStatus) {
                            kBotsAuthorizationStatus_AlreadyAuthorized, kBotsAuthorizationStatus_ContinueToAuthorize -> _startBots(data, authorizationStatus)
                            kBotsAuthorizationStatus_StopAuthorization -> {
                                //  停止授权，不继续启动。
                            }
                            else -> {
                                //  ...
                            }
                        }
                        return@then null
                    }
                }
                1 -> {  //  停止
                    _stopBots(data)
                }
                2 -> {  //  删除
                    _deleteBots(data)
                }
            }
        }
    }

    /**
     *  (private) 检测机器人账号授权状态
     */
    private fun processingAuthorizationServer(): Promise {
        if (FragmentBotsManager.isAuthorizedToTheBotsManager(_full_account_data.getJSONObject("account"))) {
            //  已授权
            return Promise._resolve(kBotsAuthorizationStatus_AlreadyAuthorized)
        } else {
            val p = Promise()
            val value = resources.getString(R.string.kBotsActionStartTipsForAutoAuthorize)
            UtilsAlert.showMessageConfirm(activity!!, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
                if (it != null && it as Boolean) {
                    //  继续授权
                    p.resolve(kBotsAuthorizationStatus_ContinueToAuthorize)
                } else {
                    //  停止授权
                    p.resolve(kBotsAuthorizationStatus_StopAuthorization)
                }
            }
            return p
        }
    }

    private fun _startBots(item: JSONObject, authorizationStatus: Int) {
        activity?.let { ctx ->
            assert(authorizationStatus != kBotsAuthorizationStatus_StopAuthorization)

            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val client = BitsharesClientManager.sharedBitsharesClientManager()

            ctx.guardWalletUnlocked(true) { unlocked ->
                if (unlocked) {
                    val op_account = _full_account_data.getJSONObject("account")
                    val op_account_id = op_account.getString("id")
                    val storage_item = item.getJSONObject("raw")
                    val bots_key = storage_item.getString("key")

                    val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }

                    chainMgr.queryAccountAllBotsData(op_account_id).then {
                        val result_hash = it as JSONObject
                        val latest_storage_item = result_hash.optJSONObject(bots_key)
                        if (latest_storage_item == null) {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionErrTipsAlreadyDeleted))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        val status = latest_storage_item.optJSONObject("value")?.optString("status", null)
                        if (isValidBotsData(latest_storage_item) && status != null && status == "running") {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionErrTipsAlreadyStarted))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        //  启动参数
                        val new_bots_data = JSONObject().apply {
                            put("args", latest_storage_item.getJSONObject("value").get("args"))
                            put("status", "running")
                        }
                        val key_values = jsonArrayfrom(jsonArrayfrom(bots_key, new_bots_data.toString()))

                        return@then client.buildAndRunTransaction { builder ->
                            val const_bots_account_id = SettingManager.sharedSettingManager().getAppGridBotsTraderAccount()

                            //  OP - 授权服务器
                            if (authorizationStatus == kBotsAuthorizationStatus_ContinueToAuthorize) {
                                val new_active_permission = op_account.getJSONObject("active").deepClone()
                                val new_account_auths = JSONArray()
                                //  保留 account_auths 权限中的其他权限
                                for (item in new_active_permission.getJSONArray("account_auths").forin<JSONArray>()) {
                                    val account = item!!.getString(0)
                                    if (const_bots_account_id != account) {
                                        new_account_auths.put(item)
                                    }
                                }
                                //  授权账号：权重 100%
                                new_account_auths.put(jsonArrayfrom(const_bots_account_id, new_active_permission.getInt("weight_threshold")))
                                //  仅更新 account_auths 权限，key_auths 等权限保持不变 。
                                new_active_permission.put("account_auths", new_account_auths)

                                val opdata_bots_authority = JSONObject().apply {
                                    put("fee", jsonObjectfromKVS("amount", 0, "asset_id", chainMgr.grapheneCoreAssetID))
                                    put("account", op_account_id)
                                    put("active", new_active_permission)
                                }
                                builder.add_operation(EBitsharesOperations.ebo_account_update, opdata = opdata_bots_authority)
                            }

                            //  OP - 启动
                            builder.add_operation(EBitsharesOperations.ebo_custom, opdata = client.buildOpData_accountStorageMap(op_account_id, false, kAppStorageCatalogBotsGridBots, key_values))

                            //  OP - 转账
                            val opdata_transfer = JSONObject().apply {
                                put("fee", jsonObjectfromKVS("amount", 0, "asset_id", chainMgr.grapheneCoreAssetID))
                                put("from", op_account_id)
                                put("to", const_bots_account_id)
                                put("amount", jsonObjectfromKVS("amount", 1, "asset_id", chainMgr.grapheneCoreAssetID))
                            }
                            builder.add_operation(EBitsharesOperations.ebo_transfer, opdata = opdata_transfer)

                            //  获取签名KEY
                            builder.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(op_account_id, requireOwnerPermission = false))
                        }.then {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionTipsStartOK))
                            _queryMyBotsListCore(_full_account_data)
                        }
                    }.catch { err ->
                        mask.dismiss()
                        showGrapheneError(err)
                    }
                }
            }
        }
    }

    private fun _stopBots(item: JSONObject) {
        activity?.let { ctx ->
            ctx.guardWalletUnlocked(true) { unlocked ->
                if (unlocked) {
                    val op_account = _full_account_data.getJSONObject("account")
                    val op_account_id = op_account.getString("id")
                    val storage_item = item.getJSONObject("raw")
                    val bots_key = storage_item.getString("key")

                    val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }

                    ChainObjectManager.sharedChainObjectManager().queryAccountAllBotsData(op_account_id).then {
                        val result_hash = it as JSONObject
                        val latest_storage_item = result_hash.optJSONObject(bots_key)
                        if (latest_storage_item == null) {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionErrTipsAlreadyDeleted))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        val status = latest_storage_item.optJSONObject("value")?.optString("status", null)
                        if (!isValidBotsData(latest_storage_item) || status == null || status != "running") {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionTipsStopOK))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        val mutable_latest_value = latest_storage_item.getJSONObject("value").deepClone()
                        mutable_latest_value.put("status", "stopped")
                        mutable_latest_value.put("msg", resources.getString(R.string.kBotsCellLabelStopMessageUserStop))
                        val key_values = jsonArrayfrom(jsonArrayfrom(bots_key, mutable_latest_value.toString()))

                        return@then BitsharesClientManager.sharedBitsharesClientManager().accountStorageMap(op_account_id, false, kAppStorageCatalogBotsGridBots, key_values).then {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionTipsStopOK))
                            _queryMyBotsListCore(_full_account_data)
                        }
                    }.catch { err ->
                        mask.dismiss()
                        showGrapheneError(err)
                    }
                }
            }
        }
    }

    private fun _deleteBots(item: JSONObject) {
        activity?.let { ctx ->
            ctx.guardWalletUnlocked(true) { unlocked ->
                if (unlocked) {
                    val op_account = _full_account_data.getJSONObject("account")
                    val op_account_id = op_account.getString("id")
                    val storage_item = item.getJSONObject("raw")
                    val bots_key = storage_item.getString("key")

                    val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }

                    ChainObjectManager.sharedChainObjectManager().queryAccountAllBotsData(op_account_id).then {
                        val result_hash = it as JSONObject
                        val latest_storage_item = result_hash.optJSONObject(bots_key)
                        if (latest_storage_item == null) {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionErrTipsAlreadyDeleted))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        val status = latest_storage_item.optJSONObject("value")?.optString("status", null)
                        if (isValidBotsData(latest_storage_item) && status != null && status == "running") {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionErrTipsStopFirst))
                            //  刷新界面
                            onQueryMyBotsListResponsed(result_hash)
                            return@then null
                        }

                        val key_values = jsonArrayfrom(jsonArrayfrom(bots_key, JSONObject().toString()))

                        return@then BitsharesClientManager.sharedBitsharesClientManager().accountStorageMap(op_account_id, true, kAppStorageCatalogBotsGridBots, key_values).then {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kBotsActionTipsDeleteOK))
                            _queryMyBotsListCore(_full_account_data)
                        }
                    }.catch { err ->
                        mask.dismiss()
                        showGrapheneError(err)
                    }
                }
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_bots_manager, container, false)
        //  刷新界面
        refreshUI()
        return _view
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }


    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }
}

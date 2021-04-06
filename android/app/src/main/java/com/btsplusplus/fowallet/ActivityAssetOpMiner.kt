package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_asset_op_miner.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetOpMiner : BtsppActivity() {

    private lateinit var _full_account_data: JSONObject

    private lateinit var _curr_balance_asset: JSONObject
    private lateinit var _curr_receive_asset: JSONObject
    private lateinit var _n_curr_balance: BigDecimal

    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_asset_op_miner)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val miner_item = args.optJSONObject("miner_item")
        _full_account_data = args.getJSONObject("full_account")
        val title = args.getString("title")

        //  初始化数据
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val price = miner_item.getJSONObject("price")
        val amount_to_sell = price.getJSONObject("amount_to_sell")
        val min_to_receive = price.getJSONObject("min_to_receive")
        _curr_balance_asset = chainMgr.getChainObjectByID(amount_to_sell.getString("asset_id"))
        _curr_receive_asset = chainMgr.getChainObjectByID(min_to_receive.getString("asset_id"))
        _n_curr_balance = ModelUtils.findAssetBalance(_full_account_data, _curr_balance_asset)

        //  初始化UI
        tv_title.text = title
        btn_submit.text = String.format(resources.getString(R.string.kVcAssetOpMinerBtnName), _curr_balance_asset.getString("symbol"), _curr_receive_asset.getString("symbol"))
        drawUI_currAsset()
        drawUI_balance(false)
        drawUI_uitips(miner_item)

        //  事件 - 返回按钮
        layout_back_from_assets_op_miner.setOnClickListener { finish() }

        //  事件 - 全部按钮点击
        btn_tf_tailer_all.setOnClickListener { onSelectAllClicked() }

        //  事件 - 兑换按钮
        btn_submit.setOnClickListener { onSubmitClicked(miner_item) }

        //  输入框
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_curr_balance_asset.getInt("precision"))
        tf.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onAmountChanged)
    }

    private fun drawUI_currAsset() {
        //  输入框尾部资产名称：这是当前余额资产名
        tv_tf_tailer_asset_symbol.text = _curr_balance_asset.getString("symbol")
    }

    private fun drawUI_balance(not_enough: Boolean) {
        val symbol = _curr_balance_asset.getString("symbol")
        if (not_enough) {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_n_curr_balance.toPlainString()} $symbol(${resources.getString(R.string.kOtcMcAssetTransferBalanceNotEnough)})"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_n_curr_balance.toPlainString()} $symbol"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    private fun drawUI_uitips(miner_item: JSONObject) {
        val price = miner_item.getJSONObject("price")
        val amount_to_sell = price.getJSONObject("amount_to_sell")
        val min_to_receive = price.getJSONObject("min_to_receive")

        val n_amount_to_sell = bigDecimalfromAmount(amount_to_sell.getString("amount"), _curr_balance_asset.getInt("precision"))
        val n_min_to_receive = bigDecimalfromAmount(min_to_receive.getString("amount"), _curr_receive_asset.getInt("precision"))

        val n_unit_price = n_min_to_receive.divide(n_amount_to_sell, _curr_receive_asset.getInt("precision"), BigDecimal.ROUND_UP)

        tv_ui_tips.text = String.format(resources.getString(R.string.kVcAssetOpMinerUiTips), _curr_receive_asset.getString("symbol"), n_unit_price.toPriceAmountString())
    }

    /**
     *  (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        drawUI_balance(_n_curr_balance < Utils.auxGetStringDecimalNumberValue(str_amount))
    }

    /**
     *  (private) 选择全部数量
     */
    private fun onSelectAllClicked() {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(_n_curr_balance.toPlainString())
        tf.setSelection(tf.text.toString().length)
        //  onAmountChanged 会自动触发
    }

    /**
     *  事件 - 点击提交操作
     */
    private fun onSubmitClicked(miner_item: JSONObject) {
        val n_amount = Utils.auxGetStringDecimalNumberValue(_tf_amount_watcher.get_tf_string())

        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcAssetOpMinerSubmitTipsPleaseInputValidAmount))
            return
        }

        if (_n_curr_balance < n_amount) {
            showToast(resources.getString(R.string.kOtcMcAssetSubmitTipBalanceNotEnough))
            return
        }

        //  计算得到的数量
        val curr_receive_asset_precision = _curr_receive_asset.getInt("precision")

        val price = miner_item.getJSONObject("price")
        val amount_to_sell = price.getJSONObject("amount_to_sell")
        val min_to_receive = price.getJSONObject("min_to_receive")
        val n_amount_to_sell = bigDecimalfromAmount(amount_to_sell.getString("amount"), _curr_balance_asset.getInt("precision"))
        val n_min_to_receive = bigDecimalfromAmount(min_to_receive.getString("amount"), curr_receive_asset_precision)
        val n_final_receive = n_min_to_receive.multiply(n_amount).divide(n_amount_to_sell, curr_receive_asset_precision, BigDecimal.ROUND_DOWN)

        if (n_final_receive <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcAssetOpMinerSubmitTipsPleaseInputValidAmount))
            return
        }

        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _execAssetMinerCore(n_amount, n_final_receive)
            }
        }
    }

    /**
     *  (private) 执行快速兑换操作
     */
    private fun _execAssetMinerCore(n_amount: BigDecimal, n_receive: BigDecimal) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val op_account = _full_account_data.getJSONObject("account")

        //  根据兑换数量计算得到数量。
        val n_amount_pow = n_amount.multiplyByPowerOf10(_curr_balance_asset.getInt("precision"))
        val n_receive_pow = n_receive.multiplyByPowerOf10(_curr_receive_asset.getInt("precision"))

        val now_sec = Utils.now_ts()
        val expiration_ts = now_sec + 64281600L     //  两年后：64281600 = 3600*24*31*12*2

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", chainMgr.grapheneCoreAssetID)
            })
            put("seller", op_account.getString("id"))
            put("amount_to_sell", JSONObject().apply {
                put("amount", n_amount_pow.toPlainString())
                put("asset_id", _curr_balance_asset.getString("id"))
            })
            put("min_to_receive", JSONObject().apply {
                put("amount", n_receive_pow.toPlainString())
                put("asset_id", _curr_receive_asset.getString("id"))
            })
            put("expiration", expiration_ts)
            put("fill_or_kill", true)
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_limit_order_create, false, false,
                op, op_account) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
            BitsharesClientManager.sharedBitsharesClientManager().createLimitOrder(op).then {
                mask.dismiss()
                showToast(resources.getString(R.string.kVcAssetOpMinerSubmitTipSwapOK))
                //  [统计]
                btsppLogCustom("txAssetMinerFullOK", jsonObjectfromKVS("account", op_account.getString("id")))
                //  返回上一个界面并刷新
                finish()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetMinerFailed", jsonObjectfromKVS("account", op_account.getString("id")))
            }
        }
    }

}

package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_asset_op_lock.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetOpLock : BtsppActivity() {

    private lateinit var _curr_selected_asset: JSONObject   //  当前选中资产
    private var _full_account_data: JSONObject? = null      //  REMARK：提取手续费池等部分操作该参数为nil。
    private var _result_promise: Promise? = null

    private var _nCurrBalance = BigDecimal.ZERO
    private var _curr_lock_item: JSONObject? = null
    private var _iLockPeriodSeconds = 0 //  锁仓时间
    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_lock)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _full_account_data = args.optJSONObject("full_account")
        _result_promise = args.opt("result_promise") as? Promise
        setCurrentAsset(args.getJSONObject("current_asset"))

        //  初始化UI
        drawUI_title(args)
        drawUI_once()
        drawUI_currAsset()
        drawUI_balance(false)

        //  事件 - 全部
        btn_tf_tailer_all.setOnClickListener { onSelectAllClicked() }

        //  事件 - 提交
        btn_op_submit.setOnClickListener { onSubmitClicked() }

        //  事件 - 锁仓周期
        layout_stake_period.setOnClickListener { onLockPeriodClicked() }

        //  事件 - 返回
        layout_back_from_assets_op_common.setOnClickListener { finish() }

        //  输入框 TODO:7.0 如果切换资产则需要切换精度
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_curr_selected_asset.getInt("precision"))
        tf.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onAmountChanged)
    }

    /**
     *  (private) 设置当前资产
     */
    private fun setCurrentAsset(asset_info: JSONObject) {
        //  更新当前资产
        _curr_selected_asset = asset_info

        //  获取当前资产对应的锁仓挖矿条目，可能为nil。
        _curr_lock_item = SettingManager.sharedSettingManager().getAppAssetLockItem(_curr_selected_asset.getString("id"))

        //  获取默认锁仓时长
        _iLockPeriodSeconds = -1

        //  启用默认锁仓时间
        if (SettingManager.sharedSettingManager().isAppParametersTrue("enable_default_lock_period")) {
            if (_curr_lock_item != null) {
                for (level in _curr_lock_item!!.getJSONArray("levels").forin<JSONObject>()) {
                    if (_iLockPeriodSeconds <= 0) {
                        _iLockPeriodSeconds = level!!.getInt("seconds")
                    }
                    if (level!!.isTrue("default")) {
                        _iLockPeriodSeconds = level.getInt("seconds")
                        break
                    }
                }
            } else {
                val default_list = SettingManager.sharedSettingManager().getAppParameters("lock_period_list") as? JSONArray
                assert(default_list != null && default_list.length() > 0)
                _iLockPeriodSeconds = default_list!!.getInt(0)
            }
            assert(_iLockPeriodSeconds > 0)
        }

        //  更新资产对应的余额。
        _nCurrBalance = ModelUtils.findAssetBalance(_full_account_data!!, _curr_selected_asset)
    }

    private fun drawUI_title(args: JSONObject) {
        findViewById<TextView>(R.id.title).text = args.optString("title")
    }

    private fun drawUI_once() {
        tf_amount.hint = resources.getString(R.string.kVcAssetOpStakeMiningPlaceholderInputStakeAmount)
        btn_op_submit.text = resources.getString(R.string.kVcAssetOpStakeMiningBtnName)
    }

    private fun drawUI_lockPeriodValue() {
        if (_iLockPeriodSeconds > 0) {
            tv_stake_period.text = Utils.fmtNhoursAndDays(this, _iLockPeriodSeconds.toLong())
            tv_stake_period.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_stake_period.text = resources.getString(R.string.kVcAssetOpStakeMiningPlaceholderSelectStakePeriod)
            tv_stake_period.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun genTransferTipsMessage(): String {
        return if (_curr_lock_item != null) {
            val share_asset = _curr_lock_item!!.getString("share_asset")
            val lines = arrayListOf<String>()
            for (level in _curr_lock_item!!.getJSONArray("levels").forin<JSONObject>()) {
                lines.add(String.format(resources.getString(R.string.kVcAssetOpStakeMiningUITipsRewardRatioLineFmt),
                        (lines.size + 1).toString(), Utils.fmtNhoursAndDays(this, level!!.getString("seconds").toLong()),
                        bigDecimalfromAmount(level.getString("ratio"), 3).toPriceAmountString()))
            }
            String.format(resources.getString(R.string.kVcAssetOpStakeMiningUITipsStakeAsset), share_asset, lines.joinToString(""))
        } else {
            resources.getString(R.string.kVcAssetOpStakeMiningUITipsNonStakeAsset)
        }
    }

    /**
     *  (private) 是否允许切换资产
     */
    private fun isEnableSwitchAsset(): Boolean {
        //  允许切换锁仓资产
        return true
    }

    private fun drawUI_currAsset() {
        //  REMARK：这里显示选中资产名称，而不是余额资产名称。
        tv_asset_symbol.text = _curr_selected_asset.getString("symbol")

        if (isEnableSwitchAsset()) {
            tv_asset_symbol.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            iv_select_asset_right_arrow.visibility = View.VISIBLE

            //  事件 - 选择资产
            iv_select_asset_right_arrow.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            layout_select_asset_from_assets_op_common.setOnClickListener { onSelectAsset() }
        } else {
            tv_asset_symbol.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            iv_select_asset_right_arrow.visibility = View.INVISIBLE
            //  事件 - 无（不可选择）
            layout_select_asset_from_assets_op_common.setOnClickListener(null)
        }

        //  输入框尾部资产名称：这是当前余额资产名
        tv_tf_tailer_asset_symbol.text = _curr_selected_asset.getString("symbol")

        //  描绘当前周期
        drawUI_lockPeriodValue()

        //  UI - 界面底部描述信息
        tv_ui_msg.text = genTransferTipsMessage()
    }

    private fun drawUI_balance(not_enough: Boolean) {
        val symbol = _curr_selected_asset.getString("symbol")
        if (not_enough) {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol(${resources.getString(R.string.kOtcMcAssetTransferBalanceNotEnough)})"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    /**
     *  (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        drawUI_balance(_nCurrBalance < Utils.auxGetStringDecimalNumberValue(str_amount))
    }

    /**
     *  (private) 选择全部数量
     */
    private fun onSelectAllClicked() {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(_nCurrBalance.toPlainString())
        tf.setSelection(tf.text.toString().length)
        //  onAmountChanged 会自动触发
    }

    /**
     *  事件 - 点击选择资产
     */
    private fun onSelectAsset() {
        //  TODO:5.0 考虑默认备选列表？
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityAssetOpLock::class.java, true, back = true)
            //  选择完毕
            val new_id = it.getString("id")
            val old_id = _curr_selected_asset.getString("id")
            if (new_id != old_id) {
                setCurrentAsset(it)
                //  切换资产后重新输入
                _tf_amount_watcher.clear()
                drawUI_currAsset()
                drawUI_balance(false)
            }
        }

        val title = resources.getString(R.string.kVcTitleSearchAssets)
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", ENetworkSearchType.enstAssetAll)
            put("kTitle", title)
        })
    }

    private fun onLockPeriodClicked() {
        //  REMARK：锁仓时间。
        val default_list = JSONArray()
        if (_curr_lock_item != null) {
            for (level in _curr_lock_item!!.getJSONArray("levels").forin<JSONObject>()) {
                default_list.put(level!!.getInt("seconds"))
            }
        } else {
            for (sec in (SettingManager.sharedSettingManager().getAppParameters("lock_period_list") as JSONArray).forin<Int>()) {
                default_list.put(sec)
            }
        }

        val day_strings = JSONArray()
        var default_select = -1
        for (sec in default_list.forin<Int>()) {
            val name = Utils.fmtNhoursAndDays(this, sec!!.toLong())
            if (sec == _iLockPeriodSeconds) {
                default_select = day_strings.length()
            }
            day_strings.put(name)
        }

        ViewDialogNumberPicker(this, resources.getString(R.string.kVcAssetOpStakeMiningTitleStakePeriod), day_strings, null, default_select) { _index: Int, txt: String ->
            val sec = default_list.getInt(_index)
            if (sec != _iLockPeriodSeconds) {
                _iLockPeriodSeconds = sec
                drawUI_lockPeriodValue()
            }
        }.show()
    }

    /**
     *  事件 - 点击提交操作
     */
    private fun onSubmitClicked() {
        val n_amount = Utils.auxGetStringDecimalNumberValue(_tf_amount_watcher.get_tf_string())

        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcAssetOpStakeMiningTipsSelectValidStakeAmount))
            return
        }

        if (_curr_lock_item != null) {
            val n_min_amount = BigDecimal(_curr_lock_item!!.getString("min_amount"))
            if (n_amount < n_min_amount) {
                showToast(String.format(resources.getString(R.string.kVcAssetOpStakeMiningTipsLessThanMinStakeAmount), n_min_amount.toPlainString(), _curr_selected_asset.getString("symbol")))
                return
            }
        }

        if (_nCurrBalance < n_amount) {
            showToast(resources.getString(R.string.kOtcMcAssetSubmitTipBalanceNotEnough))
            return
        }

        if (_iLockPeriodSeconds <= 0) {
            showToast(resources.getString(R.string.kVcAssetOpStakeMiningTipsSelectStakePeriod))
            return
        }

        val value = String.format(resources.getString(R.string.kVcAssetOpStakeMiningAskConfirmTips), n_amount.toPlainString(), _curr_selected_asset.getString("symbol"))
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(true) { unlocked ->
                    if (unlocked) {
                        _execAssetLockCore(n_amount)
                    }
                }
            }
        }
    }

    /**
     *  (private) 执行锁仓操作
     */
    private fun _execAssetLockCore(n_amount: BigDecimal) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val uid = op_account.getString("id")
        val n_amount_pow = n_amount.multiplyByPowerOf10(_curr_selected_asset.getInt("precision"))

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        //  查询节点最新区块时间
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(BTS_DYNAMIC_GLOBAL_PROPERTIES_ID))).then {
            val data_array = it as JSONArray
            val data = data_array[0] as JSONObject

            val head_block_sec = Utils.parseBitsharesTimeString(data.getString("time"))
            //  REMARK：锁仓时间使用链上时间作为基准。如果当前节点未同步，比其他节点时间慢少许，则忽略；慢太多，则交易会提交失败，交易过期。
            //  对于节点差细微时间未同步，增加 90s 固定锁仓时间处理。
            val start_claim_ts = head_block_sec + _iLockPeriodSeconds.toLong() + 90
            val op = JSONObject().apply {
                put("fee", JSONObject().apply {
                    put("amount", 0)
                    put("asset_id", chainMgr.grapheneCoreAssetID)
                })
                put("creator", uid)
                put("owner", uid)
                put("amount", JSONObject().apply {
                    put("amount", n_amount_pow.toPlainString())
                    put("asset_id", _curr_selected_asset.getString("id"))
                })
                put("policy", jsonArrayfrom(1, JSONObject().apply {
                    put("start_claim", start_claim_ts)
                    put("vesting_seconds", 0)
                }))
            }

            //  锁仓不支持提案，因为提案最终执行之前不确定，会导致锁仓到期时间误差。
            BitsharesClientManager.sharedBitsharesClientManager().vestingBalanceCreate(op).then {
                mask.dismiss()
                showToast(resources.getString(R.string.kVcAssetOpStakeMiningSubmitTipsSuccess))
                //  [统计]
                btsppLogCustom("txAssetOnchainLockupFullOK", jsonObjectfromKVS("account", op_account.getString("id")))
                //  返回上一个界面并刷新
                _result_promise?.resolve(true)
                _result_promise = null
                finish()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetOnchainLockupFailed", jsonObjectfromKVS("account", op_account.getString("id")))
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

}

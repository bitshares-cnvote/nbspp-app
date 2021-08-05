package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.TextUtils
import android.view.Gravity
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.ViewEx.TextViewEx
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_my_lock_list.*
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class ActivityMyLockList : BtsppActivity() {

    private lateinit var _full_account_data: JSONObject
    private var _data_array = mutableListOf<JSONObject>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_my_lock_list)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _full_account_data = args.getJSONObject("full_account")

        //  事件 - 返回按钮
        layout_back_from_my_stake_list.setOnClickListener { finish() }

        //  查询
        queryVestingBalance()
    }

    private fun queryVestingBalance() {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()

        val account = _full_account_data.getJSONObject("account")
        val uid = account.getString("id")

        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val p1 = conn.async_exec_db("get_vesting_balances", jsonArrayfrom(uid))

        p1.then {
            val data_array = it as JSONArray

            val asset_ids = JSONObject()
            data_array.forEach<JSONObject> { nullable_vesting ->
                asset_ids.put(nullable_vesting!!.getJSONObject("balance").getString("asset_id"), true)
            }
            return@then chainMgr.queryAllAssetsInfo(asset_ids.keys().toJSONArray()).then {
                mask.dismiss()
                onQueryVestingBalanceResponsed(data_array)
                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryVestingBalanceResponsed(data_array: JSONArray) {
        //  更新数据
        _data_array.clear()

        if (data_array.length() > 0) {
            for (it in data_array.forin<JSONObject>()) {
                val vesting = it!!
                //  该界面仅显示普通 vesting balance，略过锁仓挖矿的 vesting balance 对象。
                if (!ModelUtils.isLockMiningVestingObject(vesting)) {
                    continue
                }
                //  略过总金额为 0 的待解冻金额对象。
                if (vesting.getJSONObject("balance").getString("amount").toLong() == 0L) {
                    continue
                }
                //  linear_vesting_policy = 0,
                //  cdd_vesting_policy = 1,
                //  instant_vesting_policy = 2,
                when (vesting.getJSONArray("policy").getInt(0)) {
                    EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value -> {
                        _data_array.add(vesting)
                    }
                    else -> {
                        //  不支持的其他的新类型
                    }
                }
            }
        }

        //  根据ID降序排列
        _data_array.sortByDescending { it.getString("id").split(".").last().toInt() }

        //  更新显示
        layout_stake_list_container.removeAllViews()
        if (_data_array.size > 0) {
            refreshUI(layout_stake_list_container)
        } else {
            layout_stake_list_container.addView(ViewUtils.createEmptyCenterLabel(this, R.string.kVcMyStakeListUITipsNoData.xmlstring(this)))
        }
    }

    private fun refreshUI(container: LinearLayout) {
        val self = this
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        _data_array.forEachIndexed { idx, vesting ->
            //  准备数据
            val balance = vesting.getJSONObject("balance")
            val balance_asset = chainMgr.getChainObjectByID(balance.getString("asset_id"))
            assert(vesting.getJSONArray("policy").getInt(0) == EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value)
            val balance_symbol = balance_asset.getString("symbol")

            val policy_data = vesting.getJSONArray("policy").getJSONObject(1)
            val start_claim_ts = Utils.parseBitsharesTimeString(policy_data.getString("start_claim"))
            val init_ts = Utils.parseBitsharesTimeString(policy_data.getString("coin_seconds_earned_last_update"))
            val now_ts = Utils.now_ts()     //  TODO:是否用区块时间判断
            var diff_ts = start_claim_ts - init_ts
            diff_ts -= diff_ts % 3600       //  REMARK：按小时取整，创建的时候正常浮动了一定秒数。

            val name = String.format(resources.getString(R.string.kVcMyStakeListCellStakeObjectID), vesting.getString("id").split(".").last())

            val precision = balance_asset.getInt("precision")

            //  format values
            val total_amount = OrgUtils.formatAssetString(balance.getString("amount"), precision)
            val str_period = Utils.fmtNhoursAndDays(this, diff_ts)
            val str_expire_time: String
            val b_expired: Boolean
            if (now_ts >= start_claim_ts) {
                str_expire_time = resources.getString(R.string.kVcMyStakeListCellAlreadyExpired)
                b_expired = true
            } else {
                str_expire_time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date(start_claim_ts * 1000))
                b_expired = false
            }

            //  UI - 第一行 名字 + 提取按钮（可选）
            val layout_line1 = LinearLayout(this).apply {
                //  属性
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 10.dp, 0, 0)
                }
                //  UI - 锁仓编号
                val tv_name = TextViewEx(self, name, dp_size = 13.0f, bold = true, color = R.color.theme01_textColorMain, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL, width = 0, weight = 8.0f).apply {
                    //  单行 尾部截断
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                }
                addView(tv_name)
                //  UI - 提取按钮
                if (b_expired) {
                    val tv_pickup = TextViewEx(self, R.string.kVestingCellBtnWithdrawal.xmlstring(self), dp_size = 13.0f, color = R.color.theme01_textColorHighlight, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL, width = 0, weight = 2.0f)
                    addView(tv_pickup)
                    // click event
                    tv_pickup.setOnClickListener { onWithdrawButtonClicked(vesting) }
                }
            }

            //  line2 title
            val layout_line2 = LinearLayout(self).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 10.dp, 0, 0)
                }
                addView(TextViewEx(self, "${R.string.kLabelTradeHisTitleAmount.xmlstring(self)}($balance_symbol)", dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL))
                addView(TextViewEx(self, R.string.kVcMyStakeListCellPeriodTitle.xmlstring(self), dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL))
                addView(TextViewEx(self, R.string.kVcMyStakeListCellLockExpiredTitle.xmlstring(self), dp_size = 11.0f, color = R.color.theme01_textColorGray, width = 0.dp, weight = 1.0f, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL))
            }

            //  line3 value
            val layout_line3 = LinearLayout(self).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 10.dp, 0, 10.dp)
                }
                addView(TextViewEx(self, total_amount, dp_size = 12.0f, color = R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL))
                addView(TextViewEx(self, str_period, dp_size = 12.0f, color = R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL))
                addView(TextViewEx(self, str_expire_time, dp_size = 12.0f, color = if (b_expired) R.color.theme01_textColorMain else R.color.theme01_textColorNormal, width = 0.dp, weight = 1.0f, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL))
            }

            container.apply {
                addView(layout_line1)
                addView(layout_line2)
                addView(layout_line3)
                addView(ViewLine(self))
            }
        }
    }

    private fun onWithdrawButtonClicked(vesting: JSONObject) {
        val policy = vesting.getJSONArray("policy")

        when (policy.getInt(0)) {
            //  验证提取日期
            EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value -> {
                val policy_data = policy.getJSONObject(1)
                val start_claim = policy_data.getString("start_claim")
                val start_claim_ts = Utils.parseBitsharesTimeString(start_claim)
                val now_ts = Utils.now_ts()
                if (now_ts <= start_claim_ts) {
                    val d = Date(start_claim_ts * 1000)
                    val f = SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
                    val s = f.format(d)
                    showToast(String.format(R.string.kVestingTipsStartClaim.xmlstring(this), s))
                    return
                }
            }
            else -> {
                assert(false)
            }
        }

        //  计算可提取数量
        val withdraw_available = Utils.calcVestingBalanceAmount(vesting)
        assert(withdraw_available > 0)

        //  ----- 准备提取 -----

        //  1、判断手续费是否足够。
        val extra_balance = JSONObject().apply {
            put(vesting.getJSONObject("balance").getString("asset_id"), withdraw_available)
        }
        val fee_item = ChainObjectManager.sharedChainObjectManager().getFeeItem(EBitsharesOperations.ebo_vesting_balance_withdraw, _full_account_data, extra_balance = extra_balance)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  2、解锁钱包or账号
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                processWithdrawVestingBalanceCore(vesting, _full_account_data, fee_item, withdraw_available)
            }
        }
    }

    private fun processWithdrawVestingBalanceCore(vesting: JSONObject, full_account_data: JSONObject, fee_item: JSONObject, withdraw_available: Long) {
        val balance_id = vesting.getString("id")
        val balance = vesting.getJSONObject("balance")

        val account = full_account_data.getJSONObject("account")
        val uid = account.getString("id")

        val op = JSONObject().apply {
            put("fee", jsonObjectfromKVS("amount", 0, "asset_id", fee_item.getString("fee_asset_id")))
            put("vesting_balance", balance_id)
            put("owner", uid)
            put("amount", jsonObjectfromKVS("amount", withdraw_available, "asset_id", balance.getString("asset_id")))
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_vesting_balance_withdraw, false, false,
                op, account) { isProposal, _ ->
            assert(!isProposal)
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().vestingBalanceWithdraw(op).then {
                mask.dismiss()
                showToast(String.format(R.string.kVcMyStakeListSubmitTipsClaimSuccess.xmlstring(this), balance_id))
                //  [统计]
                btsppLogCustom("txAssetOnchainLockupWithdrawFullOK", jsonObjectfromKVS("account", uid))
                //  刷新
                queryVestingBalance()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetOnchainLockupWithdrawFailed", jsonObjectfromKVS("account", uid))
            }
        }
    }

}

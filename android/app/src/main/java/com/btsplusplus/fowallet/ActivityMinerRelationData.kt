package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_miner_relation_data.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityMinerRelationData : BtsppActivity() {

    private var _asset_id = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_miner_relation_data)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _asset_id = args.getString("asset_id")
        val is_miner = _asset_id == "1.3.23"   //  TODO:MINER立即值

        //  初始化UI
        tv_title.text = args.getString("title")
        drawUI_header(is_miner)

        //  事件 - 返回按钮
        layout_back_from_miner_relation_data.setOnClickListener { finish() }

        //  查询
        queryAllData(is_miner)
    }

    private fun scanRecentMiningReward(data_history: JSONArray?, reward_account: String, reward_asset: String): JSONArray? {
        //        assert(reward_account && reward_asset);

        //  REMARK：定期锁仓挖矿根据vb对象发奖，同一个账号可能存在多个转账记录，需要把同block_num的所有记录一起计算。
        val data_array_history = JSONArray()
        var first_block_num = 0

        if (data_history != null && data_history.length() > 0) {
            for (history in data_history.forin<JSONObject>()) {
                val op = history!!.getJSONArray("op")
                if (op.getInt(0) == EBitsharesOperations.ebo_transfer.value) {
                    val opdata = op.getJSONObject(1)
                    if (reward_account == opdata.getString("from") && reward_asset == opdata.getJSONObject("amount").getString("asset_id")) {
                        if (data_array_history.length() <= 0) {
                            //  记录第一条记录
                            data_array_history.put(history)
                            first_block_num = history.getInt("block_num")
                        } else {
                            if (history.getInt("block_num") == first_block_num) {
                                //  记录其他同区块的记录
                                data_array_history.put(history)
                            } else {
                                //  区块号不同了，则说明已经不是同一批转账记录了。
                                break
                            }
                        }
                    }
                }
            }
        }
        //  返回
        return if (data_array_history.length() > 0) {
            data_array_history
        } else {
            null
        }
    }

    /**
     *  (public) 查询指定用户的活期和定期锁仓数量。
     */
    fun queryUserMiningStakeAmount(account_id: String, balance_asset_id: String, stake_asset_id: String?, n_stake_minimum: BigDecimal?): Promise {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val promise_map = JSONObject()

        promise_map.put("kBalance", chainMgr.queryAccountBalance(account_id, jsonArrayfrom(balance_asset_id)))
        if (stake_asset_id != null) {
            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            promise_map.put("kVesting", conn.async_exec_db("get_vesting_balances", jsonArrayfrom(account_id)))
        }
        val asset_ids = JSONObject().apply {
            put(balance_asset_id, true)
            if (stake_asset_id != null) {
                put(stake_asset_id, true)
            }
        }
        promise_map.put("kAssets", chainMgr.queryAllGrapheneObjects(asset_ids.keys().toJSONArray()))

        return Promise.map(promise_map).then {
            val hashdata = it as JSONObject

            //  统计活期挖矿数量（仅查询余额）
            val balance_array = hashdata.getJSONArray("kBalance")
            assert(balance_array.length() == 1)
            val balance_asset = chainMgr.getChainObjectByID(balance_asset_id)
            val n_balance_amount = bigDecimalfromAmount(balance_array.getJSONObject(0).getString("amount"), balance_asset.getInt("precision"))

            //  统计定期锁仓数量
            var n_total_staked = BigDecimal.ZERO
            if (stake_asset_id != null) {
                val vesting_array = hashdata.getJSONArray("kVesting")
                val stake_asset = chainMgr.getChainObjectByID(stake_asset_id)
                val stake_asset_precision = stake_asset.getInt("precision")
                val n_zero = BigDecimal.ZERO
                val now_ts = Utils.now_ts()

                for (vesting in vesting_array.forin<JSONObject>()) {
                    //  不是锁仓对象
                    if (!ModelUtils.isLockMiningVestingObject(vesting!!)) {
                        continue
                    }

                    //  REMARK：已经到期的作为无效锁仓对象处理
                    val policy_data = vesting.getJSONArray("policy").getJSONObject(1)
                    val start_claim_ts = Utils.parseBitsharesTimeString(policy_data.getString("start_claim"))
                    if (now_ts >= start_claim_ts) {
                        continue
                    }

                    val balance = vesting.getJSONObject("balance")

                    //  非锁仓资产。
                    if (balance.getString("asset_id") != stake_asset_id) {
                        continue
                    }

                    val n_amount = bigDecimalfromAmount(balance.getString("amount"), stake_asset_precision)

                    //  锁仓资产数量为0
                    if (n_amount == n_zero) {
                        continue
                    }

                    //  不满足最低锁仓数量
                    if (n_amount < n_stake_minimum!!) {
                        continue
                    }

                    //  累加
                    n_total_staked = n_total_staked.add(n_amount)
                }
            }
            //  返回
            return@then JSONObject().apply {
                put("n_amount", n_balance_amount)
                put("n_stake", n_total_staked)
                put("n_total", n_balance_amount.add(n_total_staked))
            }
        }
    }

    /**
     *  (private) 查询最近的挖矿奖励和推荐奖励数据。
     */
    private fun queryLatestRewardData(account_id: String, is_miner: Boolean): Promise {
        val settingMgr = SettingManager.sharedSettingManager()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  MINER 或 SCNY 发奖账号
        val reward_account = settingMgr.getAppParameters(if (is_miner) "reward_account_miner" else "reward_account_scny") as String
        //  发奖资产ID
        val reward_asset = settingMgr.getAppParameters("mining_reward_asset") as String
        //  推荐挖矿发奖账号
        val reward_account_shares = settingMgr.getAppParameters(if (is_miner) "reward_account_shares_miner" else "reward_account_shares_scny") as String


        //  查询最新的 100 条记录。
        val stop = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
        val start = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
        //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
        //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_history("get_account_history", jsonArrayfrom(account_id, stop, 100, start)).then {
            val data_history = it as? JSONArray

            val reward_history_mining = scanRecentMiningReward(data_history, reward_account, reward_asset)
            val reward_history_shares = scanRecentMiningReward(data_history, reward_account_shares, reward_asset)

            val reward_hash = JSONObject()
            val block_num_hash = JSONObject()

            reward_history_mining?.let { block_num_hash.put(it.first<JSONObject>()!!.getString("block_num"), true) }
            reward_history_shares?.let { block_num_hash.put(it.first<JSONObject>()!!.getString("block_num"), true) }

            if (block_num_hash.length() > 0) {
                return@then chainMgr.queryAllBlockHeaderInfos(block_num_hash.keys().toJSONArray(), skipQueryCache = false).then {
                    reward_history_mining?.let { his ->
                        reward_hash.put("mining", JSONObject().apply {
                            put("history", his)
                            put("header", chainMgr.getBlockHeaderInfoByBlockNumber(his.first<JSONObject>()!!.getString("block_num"))!!)
                        })
                    }
                    reward_history_shares?.let { his ->
                        reward_hash.put("shares", JSONObject().apply {
                            put("history", his)
                            put("header", chainMgr.getBlockHeaderInfoByBlockNumber(his.first<JSONObject>()!!.getString("block_num"))!!)
                        })
                    }
                    //  返回奖励数据
                    return@then reward_hash
                }
            } else {
                //  没有任何挖矿奖励
                return@then reward_hash
            }
        }
    }

    /**
     *  (private) 查询推荐数据（需要登录）。REMARK：不支持多签账号。
     */
    private fun queryAccountRelationData(op_account: JSONObject, is_miner: Boolean, login: Boolean): Promise {
        val walletMgr = WalletManager.sharedWalletManager()
        if (login) {
            assert(!walletMgr.isLocked())
            val sign_keys = walletMgr.getSignKeys(op_account.getJSONObject("active"))
            assert(sign_keys.length() == 1)
            val active_wif_key = walletMgr.getGraphenePrivateKeyByPublicKey(sign_keys.getString(0))!!.toWifString()
            return NbWalletAPI.sharedNbWalletAPI().login(this, op_account.getString("name"), active_wif_key).then {
                if (it == null || (it is JSONObject && it.has("error"))) {
                    return@then Promise._resolve(JSONObject().apply {
                        put("error", resources.getString(R.string.kMinerApiErrServerOrNetwork))
                    })
                } else {
                    return@then NbWalletAPI.sharedNbWalletAPI().queryRelation(this, op_account.getString("id"), is_miner)
                }
            }
        } else {
            return NbWalletAPI.sharedNbWalletAPI().queryRelation(this, op_account.getString("id"), is_miner)
        }
    }

    private fun queryAllData(is_miner: Boolean) {
        val i_master_minimum = SettingManager.sharedSettingManager().getAppParameters()!!.getInt(if (is_miner) "master_minimum_miner" else "master_minimum_scny")

        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val account_id = op_account.getString("id")

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        //  查询推荐关系
        val p1 = queryAccountRelationData(op_account, is_miner, login = false)

        //  查询收益数据（最近的NCN转账明细）
        val p2 = queryLatestRewardData(account_id, is_miner)

        //  查询用户定期活期数据
        var n_stake_minimum: BigDecimal? = null
        if (is_miner) {
            val lock_item = SettingManager.sharedSettingManager().getAppAssetLockItem("1.3.0")  //  REMARK: MINER stake asset_id
            if (lock_item != null) {
                n_stake_minimum = BigDecimal(lock_item.getString("min_amount"))
            }
        }
        val p3 = queryUserMiningStakeAmount(account_id,
                balance_asset_id = _asset_id,
                stake_asset_id = if (is_miner) "1.3.0" else null,  //   REMARK: MINER stake asset_id
                n_stake_minimum = n_stake_minimum)

        Promise.all(p1, p2, p3).then {
            val data_array = it as JSONArray
            val data_relation = data_array.optJSONObject(0)
            val data_reward_hash = data_array.optJSONObject(1)
            val data_user_mining_data = data_array.optJSONObject(2)
            if (data_relation == null || data_relation.has("error")) {
                mask.dismiss()
                //  第一次查询失败的情况
                if (WalletManager.isMultiSignPermission(op_account.getJSONObject("active"))) {
                    //  多签账号不支持
                    showToast(resources.getString(R.string.kMinerApiErrNotSupportedMultiAccount))
                } else {
                    //  非多签账号 解锁后重新查询。
                    guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            val mask02 = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                            queryAccountRelationData(op_account, is_miner, login = true).then {
                                if (it == null || (it is JSONObject && it.has("error"))) {
                                    mask02.dismiss()
                                    showToast(resources.getString(R.string.kMinerApiErrServerOrNetwork))
                                } else {
                                    onQueryResponsed(is_miner, it as JSONObject, data_reward_hash, data_user_mining_data, i_master_minimum)
                                    mask02.dismiss()
                                }
                            }
                        }
                    }
                }
            } else {
                onQueryResponsed(is_miner, data_relation, data_reward_hash, data_user_mining_data, i_master_minimum)
                mask.dismiss()
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryResponsed(is_miner: Boolean, data_miner: JSONObject, data_reward_hash: JSONObject, data_user_mining_data: JSONObject?, master_minimum: Int) {
        val data_miner_items = data_miner.optJSONArray("data")

        //  clear
        val data_array = JSONArray()

        //  推荐关系列表
        val f_user_mining_amount = (data_user_mining_data!!.get("n_total") as BigDecimal).toDouble()
        var total_amount = 0.0
        //  最低门槛降额
        if (f_user_mining_amount >= master_minimum) {
            if (data_miner_items != null && data_miner_items.length() > 0) {
                for (item in data_miner_items.forin<JSONObject>()) {
                    data_array.put(item!!)
                    total_amount += Math.min(item.getDouble("slave_hold"), f_user_mining_amount)
                }
            }
        }

        //  刷新
        drawUI_header(is_miner, data_array, (Math.floor(total_amount / master_minimum) * master_minimum).toInt(), data_reward_hash)
        drawUI_list(is_miner, data_array)
    }

    private fun drawUI_header(is_miner: Boolean, data_array: JSONArray? = null, total_amount: Int? = null, data_reward_hash: JSONObject? = null) {
        val str_miner_prefix: String
        val str_share_prefix: String
        val str_mining_asset_symbol: String
        if (is_miner) {
            str_miner_prefix = resources.getString(R.string.kMinerNBSMiningRewardTitle)
            str_share_prefix = resources.getString(R.string.kMinerNBSShareMiningRewardTitle)
            str_mining_asset_symbol = "MINER"
        } else {
            str_miner_prefix = resources.getString(R.string.kMinerCNYMiningRewardTitle)
            str_share_prefix = resources.getString(R.string.kMinerCNYShareMiningRewardTitle)
            str_mining_asset_symbol = "SCNY"
        }

        tv_invite_number.text = String.format(resources.getString(R.string.kMinerTotalInviteAccountTitle), if (data_array != null) data_array.length().toString() else "--")
        tv_invite_volume.text = String.format(resources.getString(R.string.kMinerTotalInviteAmountTitle), total_amount?.toString()
                ?: "--", str_mining_asset_symbol)

        val reward_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(SettingManager.sharedSettingManager().getAppParameters("mining_reward_asset") as String)

        if (data_reward_hash != null) {
            val reward_asset_precision = reward_asset.getInt("precision")

            //  抵押或锁仓挖矿
            val reward_mining = data_reward_hash.optJSONObject("mining")
            if (reward_mining != null) {
                var n_reward_amount = BigDecimal.ZERO
                for (history in reward_mining.getJSONArray("history").forin<JSONObject>()) {
                    val opdata = history!!.getJSONArray("op").getJSONObject(1)
                    assert(reward_asset.getString("id") == opdata.getJSONObject("amount").getString("asset_id"))
                    val n_curr_reward_amount = bigDecimalfromAmount(opdata.getJSONObject("amount").getString("amount"), reward_asset_precision)
                    n_reward_amount = n_reward_amount.add(n_curr_reward_amount)
                }
                val date_str = Utils.fmtMMddTimeShowString(reward_mining.getJSONObject("header").getString("timestamp"))
                tv_mining_reward_amount.text = String.format("%s(%s) %s %s", str_miner_prefix, date_str, n_reward_amount.toPriceAmountString(), reward_asset.getString("symbol"))
            } else {
                tv_mining_reward_amount.text = String.format("%s 0 %s", str_miner_prefix, reward_asset.getString("symbol"))
            }

            //  推荐挖矿
            val reward_shares = data_reward_hash.optJSONObject("shares")
            if (reward_shares != null) {
                var n_reward_amount = BigDecimal.ZERO
                for (history in reward_shares.getJSONArray("history").forin<JSONObject>()) {
                    val opdata = history!!.getJSONArray("op").getJSONObject(1)
                    assert(reward_asset.getString("id") == opdata.getJSONObject("amount").getString("asset_id"))
                    val n_curr_reward_amount = bigDecimalfromAmount(opdata.getJSONObject("amount").getString("amount"), reward_asset_precision)
                    n_reward_amount = n_reward_amount.add(n_curr_reward_amount)
                }
                val date_str = Utils.fmtMMddTimeShowString(reward_shares.getJSONObject("header").getString("timestamp"))
                tv_shares_reward_amount.text = String.format("%s(%s) %s %s", str_share_prefix, date_str, n_reward_amount.toPriceAmountString(), reward_asset.getString("symbol"))
            } else {
                tv_shares_reward_amount.text = String.format("%s 0 %s", str_share_prefix, reward_asset.getString("symbol"))
            }
        } else {
            tv_mining_reward_amount.text = String.format("%s -- %s", str_miner_prefix, reward_asset.getString("symbol"))
            tv_shares_reward_amount.text = String.format("%s -- %s", str_miner_prefix, reward_asset.getString("symbol"))
        }
    }

    private fun createCell(is_miner: Boolean, data: JSONObject): LinearLayout {
        val _ctx = this

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val layout = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = data.getString("account_name")
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
            })
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = String.format("%s %s", data.getString("slave_hold"), if (is_miner) "MINER" else "SCNY")
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })
            })
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = Utils.fmtAccountHistoryTimeShowString(data.getString("create_time"))
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                })
            })
        }
        return layout
    }

    private fun drawUI_list(is_miner: Boolean, data_array: JSONArray) {
        layout_of_miner_relation_data.removeAllViews()

        if (data_array.length() == 0) {
            layout_of_miner_relation_data.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kMinerSharesDataNoAnyShares), text_color = resources.getColor(R.color.theme01_textColorGray)))
        } else {
            data_array.forEach<JSONObject> {
                layout_of_miner_relation_data.addView(this.createCell(is_miner, it!!))
                layout_of_miner_relation_data.addView(ViewLine(this, margin_top = 6.dp, margin_bottom = 6.dp, line_height = 1))
            }
        }
    }
}

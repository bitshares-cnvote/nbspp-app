package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_miner_relation_data.*
import org.json.JSONArray
import org.json.JSONObject

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

        //  查询
        queryAllData(is_miner)
    }

    private fun scanRecentMiningReward(data_history: JSONArray?, reward_account: String, reward_asset: String): JSONObject? {
        //        assert(reward_account && reward_asset);
        if (data_history != null && data_history.length() > 0) {
            for (history in data_history.forin<JSONObject>()) {
                val op = history!!.getJSONArray("op")
                if (op.getInt(0) == EBitsharesOperations.ebo_transfer.value) {
                    val opdata = op.getJSONObject(1)
                    if (reward_account == opdata.getString("from") && reward_asset == opdata.getJSONObject("amount").getString("asset_id")) {
                        //  奖励的历史记录
                        return history
                    }
                }
            }
        }
        //  最近没有奖励记录
        return null
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

            reward_history_mining?.let { block_num_hash.put(it.getString("block_num"), true) }
            reward_history_shares?.let { block_num_hash.put(it.getString("block_num"), true) }

            if (block_num_hash.length() > 0) {
                return@then chainMgr.queryAllBlockHeaderInfos(block_num_hash.keys().toJSONArray(), skipQueryCache = false).then {
                    reward_history_mining?.let { his ->
                        reward_hash.put("mining", JSONObject().apply {
                            put("history", his)
                            put("header", chainMgr.getBlockHeaderInfoByBlockNumber(his.getString("block_num"))!!)
                        })
                    }
                    reward_history_shares?.let { his ->
                        reward_hash.put("shares", JSONObject().apply {
                            put("history", his)
                            put("header", chainMgr.getBlockHeaderInfoByBlockNumber(his.getString("block_num"))!!)
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
        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val account_id = op_account.getString("id")

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        //  查询推荐关系
        val p1 = queryAccountRelationData(op_account, is_miner, login = false)

        //  查询收益数据（最近的NCN转账明细）
        val p2 = queryLatestRewardData(account_id, is_miner)

        Promise.all(p1, p2).then {
            val data_array = it as JSONArray
            val data_relation = data_array.optJSONObject(0)
            val data_reward_hash = data_array.optJSONObject(1)
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
                                    onQueryResponsed(is_miner, it as JSONObject, data_reward_hash)
                                    mask02.dismiss()
                                }
                            }
                        }
                    }
                }
            } else {
                onQueryResponsed(is_miner, data_relation, data_reward_hash)
                mask.dismiss()
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryResponsed(is_miner: Boolean, data_miner: JSONObject, data_reward_hash: JSONObject) {
        val data_miner_items = data_miner.optJSONArray("data")

        //  clear
        val data_array = JSONArray()

        //  推荐关系列表
        var total_amount = 0.0
        if (data_miner_items != null && data_miner_items.length() > 0) {
            for (item in data_miner_items.forin<JSONObject>()) {
                data_array.put(item!!)
                total_amount += item.getDouble("slave_hold")
            }
        }

        //  刷新
        drawUI_header(is_miner, data_array, total_amount, data_reward_hash)
        drawUI_list(is_miner, data_array)
    }

    private fun drawUI_header(is_miner: Boolean, data_array: JSONArray? = null, total_amount: Double? = null, data_reward_hash: JSONObject? = null) {
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
            //  抵押或锁仓挖矿
            val reward_mining = data_reward_hash.optJSONObject("mining")
            if (reward_mining != null) {
                val opdata = reward_mining.getJSONObject("history").getJSONArray("op").getJSONObject(1)
                assert(reward_asset.getString("id") == opdata.getJSONObject("amount").getString("asset_id"))
                val n_reward_amount = bigDecimalfromAmount(opdata.getJSONObject("amount").getString("amount"), reward_asset.getInt("precision"))
                val date_str = Utils.fmtMMddTimeShowString(reward_mining.getJSONObject("header").getString("timestamp"))
                tv_mining_reward_amount.text = String.format("%s(%s) %s %s", str_miner_prefix, date_str, n_reward_amount.toPlainString(), reward_asset.getString("symbol"))
            } else {
                tv_mining_reward_amount.text = String.format("%s 0 %s", str_miner_prefix, reward_asset.getString("symbol"))
            }

            //  推荐挖矿
            val reward_shares = data_reward_hash.optJSONObject("shares")
            if (reward_shares != null) {
                val opdata = reward_shares.getJSONObject("history").getJSONArray("op").getJSONObject(1)
                assert(reward_asset.getString("id") == opdata.getJSONObject("amount").getString("asset_id"))
                val n_reward_amount = bigDecimalfromAmount(opdata.getJSONObject("amount").getString("amount"), reward_asset.getInt("precision"))
                val date_str = Utils.fmtMMddTimeShowString(reward_mining.getJSONObject("header").getString("timestamp"))
                tv_shares_reward_amount.text = String.format("%s(%s) %s %s", str_share_prefix, date_str, n_reward_amount.toPlainString(), reward_asset.getString("symbol"))
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
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })
            })
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1.6f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = Utils.fmtAccountHistoryTimeShowString(data.getString("create_time"))
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

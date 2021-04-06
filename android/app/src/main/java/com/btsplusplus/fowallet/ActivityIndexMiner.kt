package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_index_miner.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityIndexMiner : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_miner, navigationBarColor = R.color.theme01_tabBarColor)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(2)

        //  NBS锁仓挖矿
        val url_nbs_mining = SettingManager.sharedSettingManager().getAppUrls("mining_miner")
        if (url_nbs_mining != null && url_nbs_mining.isNotEmpty()) {
            layout_intro_nbs_mining.visibility = View.VISIBLE
            layout_intro_nbs_mining.setOnClickListener { openURL(url_nbs_mining) }
        } else {
            layout_intro_nbs_mining.visibility = View.INVISIBLE
        }
        //  NBS锁仓挖矿 - 一键挖矿
        layout_nbslock_oneclick_miner_from_miner.setOnClickListener {
            //  NBS TODO:立即值
            guardWalletExist { gotoMiningOrExit("1.3.0") }
        }
        //  NBS锁仓挖矿 - 一键退出
        layout_nbslock_oneclick_withdraw_from_miner.setOnClickListener {
            //  MINER TODO:立即值
            guardWalletExist { gotoMiningOrExit("1.3.23") }
        }

        //  NBCNY 抵押挖矿
        val url_cny_mining = SettingManager.sharedSettingManager().getAppUrls("mining_scny")
        if (url_cny_mining != null && url_cny_mining.isNotEmpty()) {
            layout_intro_cny_mining.visibility = View.VISIBLE
            layout_intro_cny_mining.setOnClickListener { openURL(url_cny_mining) }
        } else {
            layout_intro_cny_mining.visibility = View.INVISIBLE
        }
        //  NBCNY 抵押挖矿 - 一键挖矿
        layout_nbcnylock_oneclick_miner_from_miner.setOnClickListener {
            //  CNY TODO:立即值
            guardWalletExist { gotoMiningOrExit("1.3.14") }
        }
        //  NBCNY 抵押挖矿 - 一键退出
        layout_nbcnylock_oneclick_withdraw_from_miner.setOnClickListener {
            //  SCNY TODO:立即值
            guardWalletExist { gotoMiningOrExit("1.3.24") }
        }

        //  推荐挖矿
        val url_shares_mining = SettingManager.sharedSettingManager().getAppUrls("mining_shares")
        if (url_shares_mining != null && url_shares_mining.isNotEmpty()) {
            layout_intro_shares_mining.visibility = View.VISIBLE
            layout_intro_shares_mining.setOnClickListener { openURL(url_shares_mining) }
        } else {
            layout_intro_shares_mining.visibility = View.INVISIBLE
        }
        //  推荐挖矿 - MINER推荐挖矿数据
        layout_miner_recommend_data_from_miner.setOnClickListener {
            //  MINER TODO:立即值
            guardWalletExist { gotoViewMiningData("1.3.23", resources.getString(R.string.kVcTitleAssetMiningDataMiner)) }
        }
        //  推荐挖矿 - SCNY推荐挖矿数据
        layout_scny_recommend_data_from_miner.setOnClickListener {
            //  SCNY TODO:立即值
            guardWalletExist { gotoViewMiningData("1.3.24", resources.getString(R.string.kVcTitleAssetMiningDataMiner)) }
        }
        //  推荐挖矿 - 邀请好友
        layout_recommend_friends_from_miner.setOnClickListener {
            guardWalletExist {
                val value = VcUtils.genShareLink(this, true)
                if (Utils.copyToClipboard(this, value)) {
                    showToast(resources.getString(R.string.kShareLinkCopied))
                }
            }
        }
    }

    private fun gotoViewMiningData(asset_id: String, title: String) {
        goTo(ActivityMinerRelationData::class.java, true, args = JSONObject().apply {
            put("asset_id", asset_id)
            put("title", title)
        })
    }

    private fun gotoMiningOrExit(asset_id: String) {
        val miner_item = SettingManager.sharedSettingManager().getAppAssetMinerItem(asset_id)
        if (miner_item == null) {
            showToast(resources.getString(R.string.kMinerCellClickTipsDontSupportedFeature))
            return
        }

        assert(WalletManager.sharedWalletManager().isWalletExist())
        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")

        val min_to_receive_asset_id = miner_item.getJSONObject("price").getJSONObject("min_to_receive").getString("asset_id")

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val p1 = chainMgr.queryFullAccountInfo(op_account.getString("id"))
        val p2 = chainMgr.queryAllGrapheneObjects(jsonArrayfrom(asset_id, min_to_receive_asset_id))

        val self = this
        VcUtils.simpleRequest(this, Promise.all(p1, p2)) {
            val data_array = it as JSONArray
            val full_account = data_array.getJSONObject(0)
            goTo(ActivityAssetOpMiner::class.java, true, args = JSONObject().apply {
                put("miner_item", miner_item)
                put("full_account", full_account)
                put("title", if (miner_item.isTrue("miner")) self.resources.getString(R.string.kVcTitleAssetOpMinerIn) else self.resources.getString(R.string.kVcTitleAssetOpMinerOut))
            })
        }
    }
}

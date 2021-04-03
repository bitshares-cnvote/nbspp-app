package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import kotlinx.android.synthetic.main.activity_index_miner.*

class ActivityIndexMiner : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_miner, navigationBarColor = R.color.theme01_tabBarColor)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(2)

        // NBS锁仓挖矿
        layout_nbslock_from_miner.setOnClickListener {  }
        // NBS锁仓挖矿 - 一键挖矿
        layout_nbslock_oneclick_miner_from_miner.setOnClickListener {
            goTo(ActivityAssetOpMiner::class.java, true)
        }
        // NBS锁仓挖矿 - 一键退出
        layout_nbslock_oneclick_withdraw_from_miner.setOnClickListener {  }
        // NBCNY 抵押挖矿
        layout_nbcnylock_from_miner.setOnClickListener {  }
        // NBCNY 抵押挖矿 - 一键挖矿
        layout_nbcnylock_oneclick_miner_from_miner.setOnClickListener {  }
        // NBCNY 抵押挖矿 - 一键退出
        layout_nbcnylock_oneclick_withdraw_from_miner.setOnClickListener {  }
        // 推荐挖矿
        layout_recommend_miner_from_miner.setOnClickListener {  }
        // 推荐挖矿 - MINER推荐挖矿数据
        layout_miner_recommend_data_from_miner.setOnClickListener {
            goTo(ActivityMinerRelationData::class.java, true)
        }
        // 推荐挖矿 - SCNY推荐挖矿数据
        layout_scny_recommend_data_from_miner.setOnClickListener {  }
        // 推荐挖矿 - SCNY推荐挖矿数据
        layout_recommend_friends_from_miner.setOnClickListener {  }
    }
}

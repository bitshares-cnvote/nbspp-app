package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_asset_op_miner.*
import org.w3c.dom.Text

class ActivityAssetOpMiner : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_asset_op_miner)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_assets_op_miner.setOnClickListener { finish() }

        findViewById<TextView>(R.id.tv_curr_balance).text = "可用 51.3574 NBS"
        findViewById<TextView>(R.id.tv_tf_tailer_asset_symbol).text = "NBS"

        // 全部按钮点击
        findViewById<TextView>(R.id.btn_tf_tailer_all).setOnClickListener {  }

        // 兑换按钮
        val btn_submit = findViewById<Button>(R.id.btn_submit)
        btn_submit.text = "NBS 兑换 MINER"
        btn_submit.setOnClickListener {  }

    }
}

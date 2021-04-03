package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_miner_relation_data.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityMinerRelationData : BtsppActivity() {

    private lateinit var _layout_of_miner_relation_data: LinearLayout
    private lateinit var _data: JSONArray
    private lateinit var _asset_name: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setAutoLayoutContentView(R.layout.activity_miner_relation_data)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _layout_of_miner_relation_data = layout_of_miner_relation_data

        findViewById<TextView>(R.id.tv_invite_number).text = "总共邀请10人"
        findViewById<TextView>(R.id.valid_invation_volume).text = "有效邀请持有量 1001.33"
        findViewById<TextView>(R.id.miner_lock_profits).text = "MINER锁仓挖矿收益 100MCN"
        findViewById<TextView>(R.id.miner_recommend_profits).text = "MINER推荐挖矿收益200MCN"

        layout_back_from_miner_relation_data.setOnClickListener { finish() }

        _asset_name = "MINER"

        getData()
        refreshUI()

    }

    private fun getData() {
        _data = JSONArray().apply {
            for ( i in 0 .. 30) {
                this.put(JSONObject().apply {
                    put("name", "text-${i}")
                    put("quantity", "1.1")
                    put("datetime","2019-12-12 13:12:00")
                })
            }
        }
    }

    private fun createCell(data: JSONObject) : LinearLayout {
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
                    text = data.getString("name")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
            })
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                val quantity = data.getString("quantity")
                addView(TextView(_ctx).apply {
                    text = "${quantity}${_asset_name}"
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
                    text = data.getString("datetime")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                })
            })
        }
        return layout
    }

    private fun refreshUI(){
        if (_data.length() == 0) {
            _layout_of_miner_relation_data.addView(ViewUtils.createEmptyCenterLabel(this, "没有任何推荐数据", text_color = resources.getColor(R.color.theme01_textColorGray)))
        } else {
            _data.forEach<JSONObject> {
                this._layout_of_miner_relation_data.addView(this.createCell(it!!))
                this._layout_of_miner_relation_data.addView(ViewLine(this, margin_top = 6.dp, margin_bottom = 6.dp))
            }
        }
    }
}

package com.btsplusplus.fowallet

import android.content.Context
import android.view.View
import android.widget.LinearLayout
import bitshares.dp

class ViewLine : View {

    constructor(context: Context,
                margin_top: Int = 0, margin_bottom: Int = 0, margin_left: Int = 0, margin_right: Int = 0,
                line_height: Int = 1.dp,
                line_color: Int = R.color.theme01_bottomLineColor) : super(context) {
        this.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, line_height).apply {
            setMargins(margin_left, margin_top, margin_right, margin_bottom)
        }
        this.setBackgroundColor(resources.getColor(line_color))
    }

}
package com.eugenally.scroll_receipt

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs

/**
 * 인스타그램 위에 떠 있는 🧾 버튼.
 * 접근성 서비스 전용 창(TYPE_ACCESSIBILITY_OVERLAY)을 쓰기 때문에
 * "다른 앱 위에 표시" 권한을 따로 받을 필요가 없다.
 */
class FloatingBubble(
    private val service: AccessibilityService,
    private val onTap: () -> Unit,
    private val onLongPress: () -> Unit,
) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val density = service.resources.displayMetrics.density
    private var view: TextView? = null
    private val size = (48 * density).toInt()
    private val margin = (8 * density).toInt()

    /** 오른쪽 가장자리에 붙어 있으면, 글자가 늘어날 때 왼쪽으로 자라도록 */
    private var dockedRight = true

    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        size,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = service.resources.displayMetrics.widthPixels - size - margin
        y = (service.resources.displayMetrics.heightPixels * 0.55).toInt()
    }

    val isShowing get() = view != null

    fun show() {
        if (view != null) return
        val tv = TextView(service).apply {
            gravity = Gravity.CENTER
            textSize = 13f
            setTextColor(Color.WHITE)
            text = "🧾"
            minWidth = size
            setPadding((14 * density).toInt(), 0, (14 * density).toInt(), 0)
            background = GradientDrawable().apply {
                cornerRadius = size / 2f   // 글자가 없으면 원, 있으면 알약 모양
                setColor(Color.parseColor("#E61B1B1F"))
                setStroke((2 * density).toInt(), Color.parseColor("#E1306C"))
            }
            elevation = 8 * density
        }
        attachTouch(tv)
        wm.addView(tv, params)
        view = tv
    }

    fun hide() {
        view?.let { runCatching { wm.removeView(it) } }
        view = null
    }

    /** 버튼 안에 오늘 본 광고 수와 스크롤 거리를 실시간으로 표시 */
    fun update(meters: Double, ads: Int) {
        val v = view ?: return
        val parts = buildList {
            if (ads > 0) add("광고 $ads")
            if (meters >= 1) add("${meters.toInt()}m")
        }
        val label = if (parts.isEmpty()) "🧾" else "🧾 " + parts.joinToString(" · ")
        if (v.text == label) return
        v.text = label
        v.post { keepDocked(v) }
    }

    private fun keepDocked(v: TextView) {
        if (!dockedRight || view !== v) return
        params.x = service.resources.displayMetrics.widthPixels - v.width - margin
        wm.updateViewLayout(v, params)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachTouch(tv: TextView) {
        val slop = ViewConfiguration.get(service).scaledTouchSlop
        val longPressMs = ViewConfiguration.getLongPressTimeout().toLong()
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0
        var dragging = false
        var longPressed = false
        val longPress = Runnable { longPressed = true; onLongPress() }

        tv.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = params.x; startY = params.y
                    dragging = false; longPressed = false
                    v.postDelayed(longPress, longPressMs)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        v.removeCallbacks(longPress)
                    }
                    if (dragging) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        wm.updateViewLayout(v, params)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    v.removeCallbacks(longPress)
                    if (dragging) snapToEdge(v as TextView)
                    else if (!longPressed) onTap()
                }
                MotionEvent.ACTION_CANCEL -> v.removeCallbacks(longPress)
            }
            true
        }
    }

    /** 놓으면 가까운 화면 가장자리로 붙는다 */
    private fun snapToEdge(v: TextView) {
        val w = service.resources.displayMetrics.widthPixels
        dockedRight = params.x + v.width / 2 >= w / 2
        params.x = if (dockedRight) w - v.width - margin else margin
        wm.updateViewLayout(v, params)
    }
}

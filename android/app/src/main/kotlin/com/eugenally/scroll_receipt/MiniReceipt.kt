package com.eugenally.scroll_receipt

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 🧾 버튼을 누르면 인스타그램 위에 바로 펼쳐지는 작은 영수증.
 * 앱을 전환하지 않으므로 인스타그램 세션이 끊기지 않는다.
 * 바깥을 누르면 닫히고, "전체 영수증"을 누르면 공유용 전체 화면을 연다.
 */
class MiniReceipt(
    private val service: AccessibilityService,
    private val store: StatsStore,
    private val onOpenFull: () -> Unit,
) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val density = service.resources.displayMetrics.density
    private val handler = Handler(Looper.getMainLooper())
    private val won = NumberFormat.getIntegerInstance(Locale.KOREA)
    private var root: View? = null

    /** 열려 있는 동안 갱신할 값 칸 (항목 이름 → TextView) */
    private val values = mutableMapOf<String, TextView>()

    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    )

    private val tick = object : Runnable {
        override fun run() {
            bind()
            handler.postDelayed(this, 1000)
        }
    }

    val isShowing get() = root != null

    fun toggle() = if (isShowing) hide() else show()

    fun show() {
        if (root != null) return
        val v = build()
        wm.addView(v, params)
        root = v
        bind()
        handler.postDelayed(tick, 1000)
    }

    fun hide() {
        handler.removeCallbacks(tick)
        root?.let { runCatching { wm.removeView(it) } }
        root = null
        values.clear()
    }

    // ───────── 화면 구성 ─────────

    @SuppressLint("SetTextI18n")
    private fun build(): View {
        val ctx: Context = service
        val dim = FrameLayout(ctx).apply {
            setBackgroundColor(Color.parseColor("#99000000"))
            setOnClickListener { hide() }
        }

        val column = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(18))
            background = GradientDrawable().apply {
                setColor(PAPER)
                cornerRadius = dp(4).toFloat()
            }
            elevation = dp(12).toFloat()
            isClickable = true   // 카드 안을 눌러도 닫히지 않도록
        }

        card.addView(text(STORE, 17f, bold = true, center = true))
        card.addView(text(
            "$BRANCH ·${SimpleDateFormat("yyyy.MM.dd HH:mm", Locale.KOREA).format(Date())}",
            11f, center = true,
        ))
        card.addView(dashes())
        card.addView(row("1일 이용시간", "usage"))
        card.addView(row("스크롤 거리", "meters"))
        card.addView(dashes())
        card.addView(item("친구 게시물", "friendPosts"))
        card.addView(item("모르는 사람 추천", "suggestedPosts"))
        card.addView(item("광고", "ads"))
        card.addView(item("릴스", "reels"))
        card.addView(dashes())
        card.addView(row("좋아요 누름", "likes"))
        card.addView(doubleLine())
        card.addView(row("총 소비한 인생", "total", bold = true))

        val buttons = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(14), 0, 0)
        }
        buttons.addView(button("닫기", filled = false) { hide() }, weighted(right = dp(6)))
        buttons.addView(button("전체 영수증 →", filled = true) { hide(); onOpenFull() }, weighted(left = dp(6)))

        column.addView(card, LinearLayout.LayoutParams(dp(300), LinearLayout.LayoutParams.WRAP_CONTENT))
        column.addView(buttons, LinearLayout.LayoutParams(dp(300), LinearLayout.LayoutParams.WRAP_CONTENT))
        dim.addView(column, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        ))

        // 영수증이 위에서 아래로 출력되듯 펼쳐진다. 창에 붙기 전에 시작하면 애니메이션이
        // 시작 상태(높이 0, 투명)에 멈춰 카드가 안 보일 수 있어, 붙은 뒤에 시작한다
        card.pivotY = 0f
        card.scaleY = 0f
        dim.alpha = 0f
        dim.post {
            card.animate().scaleY(1f).setDuration(220).start()
            dim.animate().alpha(1f).setDuration(150).start()
        }
        return dim
    }

    private fun bind() {
        val t = store.today()
        values["usage"]?.text = fmtDuration(t["usageMs"] as Long)
        values["total"]?.text = fmtDuration(t["totalUsageMs"] as Long)
        values["meters"]?.text = String.format(Locale.US, "%.1fm", t["scrollMeters"] as Double)
        values["likes"]?.text = "${t["likes"]}회"
        for (k in listOf("friendPosts", "suggestedPosts", "ads", "reels")) {
            val n = t[k] as Int
            values[k]?.text = "${n}개"
            values["$k.price"]?.text = "₩${won.format(n * 100)}"
        }
    }

    // ───────── 작은 부품들 ─────────

    private fun text(s: String, size: Float, bold: Boolean = false, center: Boolean = false) =
        TextView(service).apply {
            text = s
            textSize = size
            setTextColor(INK)
            typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            if (center) gravity = Gravity.CENTER
            setPadding(0, dp(2), 0, dp(2))
        }

    private fun row(label: String, key: String, bold: Boolean = false) = LinearLayout(service).apply {
        orientation = LinearLayout.HORIZONTAL
        val size = if (bold) 15f else 13f
        addView(text(label, size, bold), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        addView(text("", size, bold).apply { gravity = Gravity.END }.also { values[key] = it })
    }

    private fun item(label: String, key: String) = LinearLayout(service).apply {
        orientation = LinearLayout.HORIZONTAL
        addView(text(label, 13f), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        addView(
            text("", 13f).apply { gravity = Gravity.END }.also { values[key] = it },
            LinearLayout.LayoutParams(dp(48), LinearLayout.LayoutParams.WRAP_CONTENT),
        )
        addView(
            text("", 13f).apply { gravity = Gravity.END }.also { values["$key.price"] = it },
            LinearLayout.LayoutParams(dp(72), LinearLayout.LayoutParams.WRAP_CONTENT),
        )
    }

    private fun dashes(): View = Rule(service, dashed = true).withHeight(dp(14))

    private fun doubleLine(): View = Rule(service, dashed = false).withHeight(dp(14))

    private fun View.withHeight(h: Int) = apply {
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, h)
    }

    private fun button(label: String, filled: Boolean, onClick: () -> Unit) = TextView(service).apply {
        text = label
        textSize = 14f
        gravity = Gravity.CENTER
        setPadding(0, dp(12), 0, dp(12))
        setTextColor(if (filled) INK else Color.WHITE)
        background = GradientDrawable().apply {
            cornerRadius = dp(24).toFloat()
            if (filled) setColor(PINK) else setStroke(dp(1), Color.parseColor("#80FFFFFF"))
        }
        setOnClickListener { onClick() }
    }

    private fun weighted(left: Int = 0, right: Int = 0) =
        LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            leftMargin = left; rightMargin = right
        }

    private fun fmtDuration(ms: Long): String {
        val m = ms / 60_000
        val h = m / 60
        return when {
            h >= 24 -> "${h / 24}일 ${h % 24}시간 ${m % 60}분"
            h > 0 -> "${h}시간 ${m % 60}분"
            else -> "${m}분"
        }
    }

    private fun dp(v: Int) = (v * density).toInt()

    /** 영수증 구분선: 점선(- - -) 또는 이중선(═══) */
    private class Rule(ctx: Context, private val dashed: Boolean) : View(ctx) {
        private val d = ctx.resources.displayMetrics.density
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = INK
            strokeWidth = 1.2f * d
            if (dashed) pathEffect = DashPathEffect(floatArrayOf(5 * d, 4 * d), 0f)
        }

        override fun onDraw(c: Canvas) {
            val mid = height / 2f
            if (dashed) {
                c.drawLine(0f, mid, width.toFloat(), mid, paint)
            } else {
                c.drawLine(0f, mid - 2 * d, width.toFloat(), mid - 2 * d, paint)
                c.drawLine(0f, mid + 2 * d, width.toFloat(), mid + 2 * d, paint)
            }
        }
    }

    companion object {
        // lib/receipt/receipt_copy.dart 의 storeName / branch 와 같은 문구
        private const val STORE = "★ SCROLL MART ★"
        private const val BRANCH = "인스타그램 지점"
        private val PAPER = Color.parseColor("#FBFAF4")
        private val INK = Color.parseColor("#1B1B1F")
        private val PINK = Color.parseColor("#FFB3C1")
    }
}

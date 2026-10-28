package com.eugenally.scroll_receipt

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * 인스타그램 위에 뜨는 스크랩 창.
 * 지금 화면에 보이던 글을 문장 단위로 보여주고, 누른 문장들을 모아 아래 칸에 채운다.
 * 아래 칸은 직접 고칠 수 있어서 문장 일부만 남길 수도 있다.
 */
class ScrapSheet(
    private val service: AccessibilityService,
    private val store: ScrapStore,
) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val density = service.resources.displayMetrics.density
    private var root: View? = null

    // 글을 고쳐 쓸 수 있어야 하므로 다른 오버레이와 달리 포커스를 받는다 (키보드가 뜬다)
    @Suppress("DEPRECATION")
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
    }

    val isShowing get() = root != null

    fun show(pieces: List<String>, author: String?) {
        hide()
        if (pieces.isEmpty()) {
            Toast.makeText(service, "스크랩할 글이 화면에 없어요", Toast.LENGTH_SHORT).show()
            return
        }
        val v = build(pieces, author)
        wm.addView(v, params)
        root = v
    }

    fun hide() {
        root?.let { runCatching { wm.removeView(it) } }
        root = null
    }

    // ───────── 화면 구성 ─────────

    @SuppressLint("SetTextI18n")
    private fun build(pieces: List<String>, author: String?): View {
        val ctx: Context = service
        val dim = object : FrameLayout(ctx) {
            // 포커스를 받는 창이라 뒤로 가기가 여기로 온다
            override fun dispatchKeyEvent(e: KeyEvent): Boolean {
                if (e.keyCode == KeyEvent.KEYCODE_BACK && e.action == KeyEvent.ACTION_UP) {
                    hide(); return true
                }
                return super.dispatchKeyEvent(e)
            }
        }.apply {
            setBackgroundColor(Color.parseColor("#99000000"))
            setOnClickListener { hide() }
        }

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = GradientDrawable().apply {
                setColor(PAPER)
                cornerRadius = dp(6).toFloat()
            }
            elevation = dp(12).toFloat()
            isClickable = true   // 카드 안을 눌러도 닫히지 않도록
        }

        card.addView(text("✂️ 마음에 드는 문장을 고르세요", 15f, bold = true))
        if (author != null) card.addView(text("@$author", 12f).apply { setTextColor(FADED) })

        val edit = EditText(ctx).apply {
            textSize = 14f
            setTextColor(INK)
            hint = "고른 문장이 여기에 모여요. 직접 고쳐도 돼요"
            setHintTextColor(FADED)
            minLines = 2
            maxLines = 5
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                setStroke(dp(1), FADED)
                cornerRadius = dp(4).toFloat()
            }
            setPadding(dp(10), dp(8), dp(10), dp(8))
        }

        val picked = BooleanArray(pieces.size)
        val list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        pieces.forEachIndexed { i, s ->
            list.addView(text(s, 14f).apply {
                setPadding(dp(10), dp(8), dp(10), dp(8))
                background = chip(false)
                setOnClickListener {
                    picked[i] = !picked[i]
                    background = chip(picked[i])
                    edit.setText(pieces.filterIndexed { j, _ -> picked[j] }.joinToString("\n"))
                    edit.setSelection(edit.text.length)
                }
            }, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(6) })
        }
        val scroll = ScrollView(ctx).apply { addView(list) }
        card.addView(scroll, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
        ).apply { topMargin = dp(6); bottomMargin = dp(10) })
        card.addView(edit)

        val buttons = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(12), 0, 0)
        }
        buttons.addView(button("취소", filled = false) { hide() }, weighted(right = dp(6)))
        buttons.addView(button("스크랩 저장", filled = true) {
            val s = edit.text.toString().trim()
            if (s.isEmpty()) {
                Toast.makeText(service, "저장할 문장을 골라 주세요", Toast.LENGTH_SHORT).show()
            } else {
                store.add(s, author)
                Toast.makeText(service, "스크랩했어요 ✂️", Toast.LENGTH_SHORT).show()
                hide()
            }
        }, weighted(left = dp(6)))
        card.addView(buttons)

        val dm = service.resources.displayMetrics
        dim.addView(card, FrameLayout.LayoutParams(
            minOf(dp(340), dm.widthPixels - dp(32)),
            (dm.heightPixels * 0.75).toInt(),
            Gravity.CENTER,
        ))
        return dim
    }

    // ───────── 작은 부품들 ─────────

    private fun text(s: String, size: Float, bold: Boolean = false) = TextView(service).apply {
        text = s
        textSize = size
        setTextColor(INK)
        if (bold) typeface = Typeface.DEFAULT_BOLD
        setPadding(0, dp(2), 0, dp(2))
    }

    private fun chip(on: Boolean) = GradientDrawable().apply {
        cornerRadius = dp(4).toFloat()
        setColor(if (on) PINK else Color.WHITE)
        setStroke(dp(1), if (on) ACCENT else Color.parseColor("#DDDAD0"))
    }

    private fun button(label: String, filled: Boolean, onClick: () -> Unit) = TextView(service).apply {
        text = label
        textSize = 14f
        gravity = Gravity.CENTER
        setPadding(0, dp(12), 0, dp(12))
        setTextColor(INK)
        background = GradientDrawable().apply {
            cornerRadius = dp(24).toFloat()
            if (filled) setColor(PINK) else setStroke(dp(1), FADED)
        }
        setOnClickListener { onClick() }
    }

    private fun weighted(left: Int = 0, right: Int = 0) =
        LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
            leftMargin = left; rightMargin = right
        }

    private fun dp(v: Int) = (v * density).toInt()

    companion object {
        private val PAPER = Color.parseColor("#FBFAF4")
        private val INK = Color.parseColor("#1B1B1F")
        private val FADED = Color.parseColor("#8A8A8E")
        private val PINK = Color.parseColor("#FFB3C1")
        private val ACCENT = Color.parseColor("#E1306C")
    }
}

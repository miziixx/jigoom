package com.zia.dashinbox

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class QuickInputActivity : AppCompatActivity() {

    private lateinit var prefs: Prefs

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)

        // 로그인 안 됐으면 로그인 화면으로
        if (!prefs.loggedIn()) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        setContentView(R.layout.activity_quick_input)
        // 키보드 자동 표시
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)

        val edit = findViewById<EditText>(R.id.input)
        val send = findViewById<Button>(R.id.send)
        edit.requestFocus()

        send.setOnClickListener {
            val t = edit.text.toString().trim()
            if (t.isEmpty()) { finish(); return@setOnClickListener }
            send.isEnabled = false
            send.text = "보내는 중…"
            Thread {
                var code = try { Supa.insert(t, prefs.access ?: "") } catch (e: Exception) { -1 }
                if (code == 401) {
                    // 토큰 만료 → 갱신 후 1회 재시도
                    try {
                        val tk = Supa.refresh(prefs.refresh ?: "")
                        prefs.access = tk.access
                        prefs.refresh = tk.refresh
                        code = Supa.insert(t, tk.access)
                    } catch (e: Exception) { code = 401 }
                }
                val ok = code in 200..299
                runOnUiThread {
                    if (ok) {
                        Toast.makeText(this, "받은함에 담았어요 ✓", Toast.LENGTH_SHORT).show()
                        finish()
                    } else if (code == 401) {
                        Toast.makeText(this, "로그인이 만료됐어요. 다시 로그인해줘.", Toast.LENGTH_LONG).show()
                        startActivity(Intent(this, LoginActivity::class.java))
                        finish()
                    } else {
                        Toast.makeText(this, "전송 실패 — 네트워크를 확인해줘.", Toast.LENGTH_LONG).show()
                        send.isEnabled = true
                        send.text = "받은함에 담기"
                    }
                }
            }.start()
        }
    }
}

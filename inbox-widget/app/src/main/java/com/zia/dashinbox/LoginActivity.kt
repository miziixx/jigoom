package com.zia.dashinbox

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class LoginActivity : AppCompatActivity() {

    private lateinit var prefs: Prefs

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)
        setContentView(R.layout.activity_login)

        val emailEt = findViewById<EditText>(R.id.email)
        val pwEt = findViewById<EditText>(R.id.pw)
        val loginBtn = findViewById<Button>(R.id.login)
        val logoutBtn = findViewById<Button>(R.id.logout)
        val status = findViewById<TextView>(R.id.status)

        prefs.email?.let { emailEt.setText(it) }
        refreshStatus(status)

        loginBtn.setOnClickListener {
            val email = emailEt.text.toString().trim()
            val pw = pwEt.text.toString()
            if (email.isEmpty() || pw.isEmpty()) {
                status.text = "이메일과 비밀번호를 입력해줘"
                return@setOnClickListener
            }
            loginBtn.isEnabled = false
            loginBtn.text = "로그인 중…"
            Thread {
                try {
                    val tk = Supa.login(email, pw)
                    prefs.access = tk.access
                    prefs.refresh = tk.refresh
                    prefs.email = email
                    runOnUiThread {
                        Toast.makeText(this, "로그인 완료!", Toast.LENGTH_SHORT).show()
                        loginBtn.isEnabled = true
                        loginBtn.text = "로그인"
                        refreshStatus(status)
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        status.text = "로그인 실패: ${e.message}"
                        loginBtn.isEnabled = true
                        loginBtn.text = "로그인"
                    }
                }
            }.start()
        }

        logoutBtn.setOnClickListener {
            prefs.clear()
            Toast.makeText(this, "로그아웃됨", Toast.LENGTH_SHORT).show()
            refreshStatus(status)
        }
    }

    private fun refreshStatus(status: TextView) {
        status.text = if (prefs.loggedIn())
            "✅ 로그인됨: ${prefs.email ?: ""}\n홈 화면에 위젯을 추가하면 바로 메모할 수 있어요."
        else
            "로그인하면 홈 위젯으로 받은함에 바로 메모할 수 있어요."
    }
}

package com.zia.dashinbox

import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

data class Tokens(val access: String, val refresh: String)

object Supa {

    private fun open(urlStr: String): HttpURLConnection {
        val c = URL(urlStr).openConnection() as HttpURLConnection
        c.requestMethod = "POST"
        c.connectTimeout = 12000
        c.readTimeout = 12000
        c.doOutput = true
        c.setRequestProperty("apikey", Config.SB_KEY)
        c.setRequestProperty("Content-Type", "application/json")
        return c
    }

    private fun body(c: HttpURLConnection, json: String): Pair<Int, String> {
        c.outputStream.use { it.write(json.toByteArray(Charsets.UTF_8)) }
        val code = c.responseCode
        val stream = if (code in 200..299) c.inputStream else c.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
        return code to text
    }

    private fun errMsg(resp: String): String {
        return try {
            val j = JSONObject(resp)
            j.optString("error_description",
                j.optString("msg", j.optString("message", resp)))
        } catch (e: Exception) { resp.ifEmpty { "알 수 없는 오류" } }
    }

    /** 이메일/비번 로그인 → 토큰 */
    fun login(email: String, pw: String): Tokens {
        val c = open("${Config.SB_URL}/auth/v1/token?grant_type=password")
        val payload = JSONObject().put("email", email).put("password", pw).toString()
        val (code, resp) = body(c, payload)
        if (code !in 200..299) throw IOException(errMsg(resp))
        val j = JSONObject(resp)
        return Tokens(j.getString("access_token"), j.getString("refresh_token"))
    }

    /** 리프레시 토큰으로 액세스 토큰 갱신 */
    fun refresh(refreshToken: String): Tokens {
        val c = open("${Config.SB_URL}/auth/v1/token?grant_type=refresh_token")
        val payload = JSONObject().put("refresh_token", refreshToken).toString()
        val (code, resp) = body(c, payload)
        if (code !in 200..299) throw IOException(errMsg(resp))
        val j = JSONObject(resp)
        return Tokens(j.getString("access_token"), j.getString("refresh_token"))
    }

    /** 받은함 큐에 한 줄 넣기. 성공 201, 만료 401 */
    fun insert(text: String, access: String): Int {
        val c = open("${Config.SB_URL}/rest/v1/inbox_queue")
        c.setRequestProperty("Authorization", "Bearer $access")
        c.setRequestProperty("Prefer", "return=minimal")
        val payload = JSONObject().put("text", text).toString()
        val (code, _) = body(c, payload)
        return code
    }
}

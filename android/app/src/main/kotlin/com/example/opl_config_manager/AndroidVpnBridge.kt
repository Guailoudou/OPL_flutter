package com.example.opl_config_manager

import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import openp2p.Openp2p
import org.json.JSONObject
import java.net.InetAddress
import kotlin.concurrent.thread

/** Routes only SD-WAN destinations; the core's own sockets use the underlying network. */
class AndroidVpnBridge(private val service: VpnService) {
    @Volatile private var active = false
    @Volatile private var session: TunSession? = null
    private var fingerprint = ""

    private class TunSession(val descriptor: ParcelFileDescriptor) {
        val input = ParcelFileDescriptor.AutoCloseInputStream(ParcelFileDescriptor.dup(descriptor.fileDescriptor))
        val output = ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(descriptor.fileDescriptor))
        fun close() {
            runCatching { descriptor.close() }
            runCatching { input.close() }
            runCatching { output.close() }
        }
    }

    fun start() {
        active = true
        SdwanFeed.listener = { json -> if (active) configure(json) }
        SdwanFeed.start()
        thread(name = "opl-tun-output", isDaemon = true) {
            val buffer = ByteArray(65536)
            while (active) {
                try {
                    val length = Openp2p.androidWrite(buffer, 500).toInt()
                    if (length > 0 && length <= buffer.size) session?.output?.write(buffer, 0, length)
                } catch (error: Throwable) {
                    if (active) Log.w("OPL-VPN", "Packet output failed", error)
                }
            }
        }
    }

    @Synchronized private fun configure(json: String) {
        if (!active) return
        try {
            val info = JSONObject(json)
            val gateway = cidr(info.optString("gateway"))
            val nodes = info.optJSONArray("Nodes")
            val ownName = Openp2p.getAndroidNodeName()
            var address = ""
            val routes = linkedSetOf<Pair<String, Int>>()
            if (gateway != null) routes.add(gateway)
            if (nodes != null) {
                for (index in 0 until nodes.length()) {
                    val node = nodes.getJSONObject(index)
                    if (node.optString("name") == ownName) address = node.optString("ip")
                    for (resource in node.optString("resource").split(',')) {
                        cidr(resource.trim())?.let { routes.add(it) }
                    }
                }
            }
            if (gateway == null || address.isEmpty() || info.optInt("enable", 1) == 0) {
                closeTun()
                return
            }
            val mtu = info.optInt("mtu", 1420).takeIf { it in 1280..9000 } ?: 1420
            val key = "$address/$gateway/$mtu/${routes.sortedBy { it.toString() }}"
            if (key == fingerprint) return
            val builder = service.Builder().setSession("OPL SD-WAN")
                .setMtu(mtu).setBlocking(true)
                .addAddress(address.substringBefore('/'), gateway.second)
                .addDisallowedApplication(service.packageName)
            for ((network, prefix) in routes) builder.addRoute(network, prefix)
            val descriptor = builder.establish() ?: throw IllegalStateException("VPN authorization was revoked")
            val next = TunSession(descriptor)
            closeTun()
            session = next
            fingerprint = key
            thread(name = "opl-tun-input", isDaemon = true) {
                val buffer = ByteArray(65536)
                try {
                    while (active && session === next) {
                        val length = next.input.read(buffer)
                        if (length < 0) break
                        if (length > 0 && session === next) Openp2p.androidRead(buffer, length.toLong())
                    }
                } catch (error: Throwable) {
                    if (active && session === next) Log.w("OPL-VPN", "Packet input failed", error)
                }
            }
            Log.i("OPL-VPN", "SD-WAN VPN interface established")
        } catch (error: Throwable) {
            Log.e("OPL-VPN", "Invalid or unavailable SD-WAN VPN configuration", error)
        }
    }

    private fun cidr(value: String): Pair<String, Int>? {
        val parts = value.split('/')
        if (parts.size != 2) return null
        val prefix = parts[1].toIntOrNull()?.takeIf { it in 0..32 } ?: return null
        val octets = parts[0].split('.').map { it.toIntOrNull() }
        if (octets.size != 4 || octets.any { it == null || it !in 0..255 }) return null
        val bytes = octets.map { it!!.toByte() }.toByteArray()
        for (index in bytes.indices) {
            val bits = (prefix - index * 8).coerceIn(0, 8)
            bytes[index] = (bytes[index].toInt() and (0xff shl (8 - bits))).toByte()
        }
        return InetAddress.getByAddress(bytes).hostAddress!! to prefix
    }

    @Synchronized private fun closeTun() {
        session?.close()
        session = null
        fingerprint = ""
    }

    @Synchronized fun stop() {
        active = false
        SdwanFeed.listener = null
        closeTun()
    }

    /** The gomobile config call blocks in native code; keep one consumer per core process. */
    private object SdwanFeed {
        @Volatile var listener: ((String) -> Unit)? = null
        private var started = false
        @Synchronized fun start() {
            if (started) return
            started = true
            thread(name = "opl-sdwan-config", isDaemon = true) {
                val buffer = ByteArray(1024 * 1024)
                while (true) {
                    try {
                        val length = Openp2p.getAndroidSDWANConfig(buffer).toInt()
                        if (length in 1..buffer.size) listener?.invoke(String(buffer, 0, length, Charsets.UTF_8))
                    } catch (error: Throwable) {
                        Log.w("OPL-VPN", "Waiting for SD-WAN configuration", error)
                        Thread.sleep(1000)
                    }
                }
            }
        }
    }
}

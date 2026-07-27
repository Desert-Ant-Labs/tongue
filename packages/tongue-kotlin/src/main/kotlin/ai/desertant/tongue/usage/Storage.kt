package ai.desertant.tongue.usage

import java.util.UUID
import java.util.prefs.Preferences

/**
 * Cross-session persistence for the turnstile — the device id and the re-emit
 * state. A port of desert-ant-core's `Sources/Usage/Storage.swift`, with one
 * difference forced by this artifact being a plain jar rather than an AAR.
 *
 * Core reaches Android's SharedPreferences through its JNI host bridge. There is
 * no native layer here, and the jar does not compile against the Android SDK — it
 * has to keep working on a bare JVM — so an Android caller passes its `Context` in
 * and it is used reflectively. No Android types appear in the signature and the
 * jar stays dependency-free.
 *
 * Backends, in the order [defaultStorage] tries them:
 *
 *   Android   SharedPreferences, when a Context was supplied
 *   JVM       java.util.prefs.Preferences
 *   fallback  in-memory (no persistence)
 *
 * Keys match core exactly, so an app embedding several Desert Ant SDKs shares one
 * device id rather than counting as several devices.
 */
private const val DEVICE_ID_KEY = "ai.desertant.usage.deviceId"

private fun stateKey(appKey: String, deviceId: String) = "ai.desertant.usage.$appKey.$deviceId.state"

/** A minimal string key/value store the turnstile persists into. */
public interface UsageStorage {
    public fun get(key: String): String?
    public fun set(key: String, value: String)
}

/** The stable per-install device id, generated and persisted on first use. */
internal fun UsageStorage.persistentDeviceId(): String {
    val existing = get(DEVICE_ID_KEY)
    if (!existing.isNullOrEmpty()) return existing
    val id = UUID.randomUUID().toString()
    set(DEVICE_ID_KEY, id)
    return id
}

/** The turnstile state for an (app key, device): "lastActiveAt,carryCallCount". */
internal fun UsageStorage.loadState(appKey: String, deviceId: String): UsageState {
    val raw = get(stateKey(appKey, deviceId)) ?: return UsageState()
    val parts = raw.split(",")
    if (parts.size != 2) return UsageState()
    val last = parts[0].toLongOrNull() ?: return UsageState()
    val carry = parts[1].toIntOrNull() ?: return UsageState()
    return UsageState(last, carry)
}

internal fun UsageStorage.saveState(state: UsageState, appKey: String, deviceId: String) {
    set(stateKey(appKey, deviceId), "${state.lastActiveAt},${state.carryCallCount}")
}

/** No persistence; also handy for tests. */
public class InMemoryStorage(private val values: MutableMap<String, String> = mutableMapOf()) : UsageStorage {
    override fun get(key: String): String? = values[key]
    override fun set(key: String, value: String) { values[key] = value }
}

/**
 * Android SharedPreferences, reached reflectively so this file compiles and runs
 * on a bare JVM. [forContext] returns null when the object is not a Context or the
 * platform is not Android, letting [defaultStorage] fall through.
 */
internal class AndroidPreferencesStorage private constructor(private val prefs: Any) : UsageStorage {
    private val getString = prefs.javaClass.getMethod("getString", String::class.java, String::class.java)
    private val edit = prefs.javaClass.getMethod("edit")

    override fun get(key: String): String? =
        runCatching { getString.invoke(prefs, key, null) as String? }.getOrNull()

    override fun set(key: String, value: String) {
        runCatching {
            val editor = edit.invoke(prefs)!!
            val put = editor.javaClass.getMethod("putString", String::class.java, String::class.java)
            put.isAccessible = true
            val applied = put.invoke(editor, key, value)!!
            applied.javaClass.getMethod("apply").apply { isAccessible = true }.invoke(applied)
        }
    }

    companion object {
        fun forContext(context: Any?): UsageStorage? {
            if (context == null) return null
            return runCatching {
                val method = context.javaClass.getMethod(
                    "getSharedPreferences", String::class.java, Int::class.javaPrimitiveType,
                )
                val prefs = method.invoke(context, "ai.desertant.usage", 0)!!
                AndroidPreferencesStorage(prefs) as UsageStorage
            }.getOrNull()
        }
    }
}

/** JVM backend. Not used on Android, where the backing store is unreliable. */
internal class JvmPreferencesStorage : UsageStorage {
    private val node: Preferences = Preferences.userRoot().node("ai/desertant/usage")
    override fun get(key: String): String? = runCatching { node.get(key, null) }.getOrNull()
    override fun set(key: String, value: String) { runCatching { node.put(key, value); node.flush() } }
}

/** True when running on Android, where java.util.prefs cannot be trusted. */
internal fun isAndroid(): Boolean =
    System.getProperty("java.vm.vendor")?.contains("Android", ignoreCase = true) == true ||
        System.getProperty("java.runtime.name")?.contains("Android", ignoreCase = true) == true ||
        runCatching { Class.forName("android.os.Build") }.isSuccess

/**
 * The best available store. A Context (Android) wins; otherwise JVM preferences,
 * unless we are on Android without a Context, where nothing persists and every
 * process would otherwise look like a new device — in-memory is the honest answer
 * there, and [makeClient] warns once.
 */
internal fun defaultStorage(context: Any? = null): UsageStorage =
    AndroidPreferencesStorage.forContext(context)
        ?: if (isAndroid()) InMemoryStorage() else JvmPreferencesStorage()

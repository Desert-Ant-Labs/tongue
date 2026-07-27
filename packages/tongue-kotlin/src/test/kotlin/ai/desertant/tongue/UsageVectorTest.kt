package ai.desertant.tongue

import ai.desertant.tongue.usage.ClientDeps
import ai.desertant.tongue.usage.IngestBody
import ai.desertant.tongue.usage.UsageClient
import ai.desertant.tongue.usage.UsageState
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Replays `usage_vectors.json` through this port's hand-written [UsageClient].
 *
 * The JavaScript port replays the identical file; the Swift SDK uses
 * desert-ant-core's client directly rather than porting it. Three copies of one
 * state machine is exactly where drift hides, and a wrong turnstile is a billing
 * error rather than a visible bug, so the contract is pinned here the same way the
 * model's normalizer, hasher and router are. See docs/USAGE.md.
 */
class UsageVectorTest {

    @Test
    fun turnstileMatchesTheSharedContract() {
        val json = read("usage_vectors.json")
        val windowMs = numberField(json, "windowMs") ?: error("no windowMs")

        val cases = caseObjects(json)
        check(cases.isNotEmpty()) { "no cases in usage_vectors.json" }

        for (case in cases) {
            val name = stringField(case, "name") ?: "unnamed"
            var state = UsageState(
                numberField(case, "stateLastActiveAt") ?: 0,
                (numberField(case, "stateCarry") ?: 0).toInt(),
            )
            var now = 0L
            val sends = mutableListOf<IngestBody>()

            val client = UsageClient(
                ClientDeps(
                    deviceId = "device-under-test",
                    platform = "test",
                    sdkVersion = "0.0.0",
                    windowMs = windowMs,
                    now = { now },
                    loadState = { state },
                    saveState = { state = it },
                    send = { sends.add(it) },
                ),
            )

            val kinds = stringArray(case, "stepKinds")
            val ats = numberArray(case, "stepAt")
            val ns = numberArray(case, "stepN")
            kinds.forEachIndexed { i, kind ->
                now = ats[i]
                when (kind) {
                    "start" -> client.start()
                    "flush" -> client.flush()
                    "record" -> client.recordCall(ns[i].toInt())
                    else -> error("unknown step $kind")
                }
            }

            val expected = numberArray(case, "sendCounts")
            assertEquals(expected.size, sends.size, "$name: send count")
            expected.forEachIndexed { i, count ->
                val event = sends[i].events.first()
                assertEquals("load", event.name, "$name: event name")
                assertEquals("device-under-test", event.deviceId, "$name: deviceId")
                assertEquals(count.toInt(), event.callCount ?: -1, "$name: callCount[$i]")
            }
            assertEquals(
                numberField(case, "finalLastActiveAt"), state.lastActiveAt, "$name: final lastActiveAt",
            )
            assertEquals(
                (numberField(case, "finalCarry") ?: 0).toInt(), state.carryCallCount, "$name: final carry",
            )
        }
    }

    // A reader for this document's shape only: flat objects inside "cases", whose
    // values are numbers, strings, or arrays of those. Same reason the model
    // vectors have one — the artifact takes no JSON dependency, so neither do its
    // tests. The vectors are deliberately free of nested objects so this stays
    // this short.
    private fun read(name: String): String =
        javaClass.classLoader.getResourceAsStream(name)?.use { it.readBytes().toString(Charsets.UTF_8) }
            ?: error("$name is missing from the test resources")

    private fun caseObjects(json: String): List<String> {
        val start = json.indexOf("\"cases\"")
        if (start < 0) return emptyList()
        val open = json.indexOf('[', start)
        val out = mutableListOf<String>()
        var depth = 0
        var objectStart = -1
        var index = open
        var inString = false
        var escaped = false
        while (index < json.length) {
            val c = json[index]
            when {
                escaped -> escaped = false
                c == '\\' && inString -> escaped = true
                c == '"' -> inString = !inString
                inString -> {}
                c == '{' -> { if (depth == 0) objectStart = index; depth++ }
                c == '}' -> { depth--; if (depth == 0 && objectStart >= 0) { out.add(json.substring(objectStart, index + 1)); objectStart = -1 } }
                c == ']' && depth == 0 -> return out
            }
            index++
        }
        return out
    }

    private fun stringField(obj: String, key: String): String? =
        Regex("\"$key\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"").find(obj)?.groupValues?.get(1)

    private fun numberField(obj: String, key: String): Long? =
        Regex("\"$key\"\\s*:\\s*(-?\\d+)").find(obj)?.groupValues?.get(1)?.toLongOrNull()

    private fun arrayBody(obj: String, key: String): String? =
        Regex("\"$key\"\\s*:\\s*\\[([^\\]]*)\\]").find(obj)?.groupValues?.get(1)

    private fun numberArray(obj: String, key: String): List<Long> =
        arrayBody(obj, key)?.split(",")?.mapNotNull { it.trim().toLongOrNull() } ?: emptyList()

    private fun stringArray(obj: String, key: String): List<String> =
        arrayBody(obj, key)
            ?.split(",")
            ?.map { it.trim().removeSurrounding("\"") }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
}

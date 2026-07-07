package com.codetivelab.soundAxis

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.pow

/**
 * Manages per-track Android AudioEffect instances (Equalizer, BassBoost,
 * Virtualizer, LoudnessEnhancer) keyed by a caller-supplied [trackId].
 *
 * Each effect is attached to the audio session of the corresponding
 * just_audio AudioPlayer.  All effects are released when [releaseAll] is
 * called (app destroy) or when [closeEffects] is called for a specific track.
 */
class AudioEffectsPlugin : MethodChannel.MethodCallHandler {

    private data class TrackEffects(
        val eq: Equalizer,
        val bassBoost: BassBoost,
        val virtualizer: Virtualizer,
        val loudness: LoudnessEnhancer,
    )

    private val effects = mutableMapOf<String, TrackEffects>()

    // UI band labels (Hz) — map to nearest device EQ center frequency.
    private val targetEqHz = intArrayOf(60, 230, 910, 3600, 14000)

    /// Perceptual curve: mid-slider values feel stronger on OEM effect APIs.
    private fun curvedStrength(strength: Double): Short =
        (strength.coerceIn(0.0, 1.0).pow(0.55) * 1000.0).toInt().toShort()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val trackId = call.argument<String>("trackId")
        if (trackId == null) {
            result.error("MISSING_ARG", "trackId is required", null)
            return
        }

        when (call.method) {
            "openEffects" -> {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                openEffects(trackId, sessionId, result)
            }
            "setEqBands" -> {
                val levels = call.argument<List<Double>>("levels")
                if (levels == null) {
                    result.error("MISSING_ARG", "levels required", null)
                    return
                }
                setEqBands(trackId, levels, result)
            }
            "setBassBoost" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                setBassBoost(trackId, strength, result)
            }
            "setVirtualizer" -> {
                val strength = call.argument<Double>("strength") ?: 0.0
                setVirtualizer(trackId, strength, result)
            }
            "setLoudness" -> {
                val gainDb = call.argument<Double>("gainDb") ?: 0.0
                setLoudness(trackId, gainDb, result)
            }
            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setEnabled(trackId, enabled, result)
            }
            "closeEffects" -> {
                closeEffects(trackId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Open ────────────────────────────────────────────────────────────────

    private fun openEffects(trackId: String, sessionId: Int, result: MethodChannel.Result) {
        // Release any previously opened effects for this track.
        closeEffects(trackId)

        if (sessionId == 0) {
            // Session 0 = global effect; we skip to avoid affecting other apps.
            result.error("INVALID_SESSION", "Audio session ID is 0; effects skipped", null)
            return
        }

        try {
            val eq = Equalizer(0, sessionId).apply { enabled = true }
            val bb = BassBoost(0, sessionId).apply { enabled = true }
            val virt = Virtualizer(0, sessionId).apply { enabled = true }
            val loud = LoudnessEnhancer(sessionId).apply { enabled = true }

            effects[trackId] = TrackEffects(eq, bb, virt, loud)
            result.success(eq.numberOfBands.toInt())
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    // ── EQ ──────────────────────────────────────────────────────────────────

    private fun setEqBands(trackId: String, levels: List<Double>, result: MethodChannel.Result) {
        val eq = effects[trackId]?.eq ?: run { result.success(null); return }
        try {
            val bandCount = eq.numberOfBands.toInt()
            val min = eq.bandLevelRange[0]
            val max = eq.bandLevelRange[1]
            for (i in levels.indices) {
                if (i >= targetEqHz.size) break
                val targetHz = targetEqHz[i]
                var bestBand = 0
                var bestDist = Long.MAX_VALUE
                for (b in 0 until bandCount) {
                    val center = eq.getCenterFreq(b.toShort()).toLong()
                    val dist = abs(center - targetHz)
                    if (dist < bestDist) {
                        bestDist = dist
                        bestBand = b
                    }
                }
                // levels are in dB; Android Equalizer uses millibels.
                val mb = (levels[i] * 1.15 * 100.0).toInt().toShort()
                eq.setBandLevel(bestBand.toShort(), mb.coerceIn(min, max))
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_EQ_FAILED", e.message, null)
        }
    }

    // ── Bass Boost ──────────────────────────────────────────────────────────

    private fun setBassBoost(trackId: String, strength: Double, result: MethodChannel.Result) {
        val bb = effects[trackId]?.bassBoost ?: run { result.success(null); return }
        try {
            bb.setStrength(curvedStrength(strength))
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_BASS_FAILED", e.message, null)
        }
    }

    // ── Virtualizer ─────────────────────────────────────────────────────────

    private fun setVirtualizer(trackId: String, strength: Double, result: MethodChannel.Result) {
        val virt = effects[trackId]?.virtualizer ?: run { result.success(null); return }
        try {
            virt.setStrength(curvedStrength(strength))
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_VIRT_FAILED", e.message, null)
        }
    }

    // ── Loudness Enhancer ───────────────────────────────────────────────────

    private fun setLoudness(trackId: String, gainDb: Double, result: MethodChannel.Result) {
        val loud = effects[trackId]?.loudness ?: run { result.success(null); return }
        try {
            // LoudnessEnhancer target gain in millibels (0 = off, up to ~1200 mB).
            val mb = (gainDb.coerceIn(0.0, 12.0) * 100.0).toFloat()
            loud.setTargetGain(mb.toInt())
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_LOUD_FAILED", e.message, null)
        }
    }

    // ── Enable / disable all effects for a track ────────────────────────────

    private fun setEnabled(trackId: String, enabled: Boolean, result: MethodChannel.Result) {
        val te = effects[trackId] ?: run { result.success(null); return }
        te.eq.enabled = enabled
        te.bassBoost.enabled = enabled
        te.virtualizer.enabled = enabled
        te.loudness.enabled = enabled
        result.success(null)
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    private fun closeEffects(trackId: String) {
        effects.remove(trackId)?.also { te ->
            runCatching { te.eq.release() }
            runCatching { te.bassBoost.release() }
            runCatching { te.virtualizer.release() }
            runCatching { te.loudness.release() }
        }
    }

    fun releaseAll() {
        effects.keys.toList().forEach { closeEffects(it) }
    }
}

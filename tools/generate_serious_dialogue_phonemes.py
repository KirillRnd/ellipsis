"""Generate the serious, sprite-informed dialogue phoneme set for Ellipsis."""

from __future__ import annotations

import math
import random
import wave
from dataclasses import dataclass
from pathlib import Path


SAMPLE_RATE = 44_100


@dataclass(frozen=True)
class VoiceSpec:
    filename: str
    duration: float
    fundamental: float
    formants: tuple[tuple[float, float, float], ...]
    rolloff: float = 1.2
    pitch_fall: float = 0.0
    breath: float = 0.05
    rumble: float = 0.03
    rasp: float = 0.05
    pulse_depth: float = 0.0
    pulse_rate: float = 24.0
    metal: tuple[tuple[float, float, float], ...] = ()
    seed: int = 1


VOICES = (
    VoiceSpec(
        "dialogue_colorless_prism.wav", 0.060, 112.0,
        ((430.0, 150.0, 2.4), (920.0, 220.0, 1.5), (1680.0, 330.0, 0.45)),
        rolloff=1.25, pitch_fall=-0.025, breath=0.15, rumble=0.04, rasp=0.08,
        metal=((710.0, 0.045, 24.0),), seed=101,
    ),
    VoiceSpec(
        "dialogue_cron_blue_beacon.wav", 0.072, 86.0,
        ((370.0, 135.0, 2.7), (760.0, 190.0, 1.8), (1420.0, 280.0, 0.55)),
        rolloff=1.15, pitch_fall=-0.015, breath=0.035, rumble=0.06, rasp=0.035,
        metal=((565.0, 0.075, 21.0), (1030.0, 0.035, 28.0)), seed=202,
    ),
    VoiceSpec(
        "dialogue_rahn_red_pulse.wav", 0.076, 74.0,
        ((320.0, 130.0, 3.0), (650.0, 175.0, 1.9), (1180.0, 260.0, 0.45)),
        rolloff=1.05, pitch_fall=-0.085, breath=0.12, rumble=0.11, rasp=0.30,
        pulse_depth=0.12, pulse_rate=31.0,
        metal=((480.0, 0.08, 26.0), (870.0, 0.04, 34.0)), seed=303,
    ),
    VoiceSpec(
        "dialogue_violet_phase.wav", 0.058, 126.0,
        ((500.0, 145.0, 2.5), (1040.0, 210.0, 1.6), (1960.0, 300.0, 0.55)),
        rolloff=1.30, pitch_fall=-0.018, breath=0.045, rumble=0.025, rasp=0.035,
        pulse_depth=0.035, pulse_rate=22.0,
        metal=((820.0, 0.035, 32.0),), seed=404,
    ),
    VoiceSpec(
        "dialogue_irvel_green_branch.wav", 0.070, 94.0,
        ((405.0, 145.0, 2.5), (860.0, 220.0, 1.45), (1540.0, 330.0, 0.45)),
        rolloff=1.28, pitch_fall=-0.028, breath=0.17, rumble=0.045, rasp=0.045,
        metal=((615.0, 0.035, 22.0), (735.0, 0.025, 25.0)), seed=505,
    ),
    VoiceSpec(
        "dialogue_tiu_feather_map.wav", 0.058, 118.0,
        ((455.0, 140.0, 2.4), (1080.0, 210.0, 1.35), (1840.0, 300.0, 0.40)),
        rolloff=1.34, pitch_fall=-0.022, breath=0.075, rumble=0.025, rasp=0.055,
        pulse_depth=0.045, pulse_rate=27.0,
        metal=((690.0, 0.025, 30.0),), seed=606,
    ),
    VoiceSpec(
        "dialogue_golden_lantern.wav", 0.090, 62.0,
        ((285.0, 120.0, 3.1), (585.0, 165.0, 2.0), (1060.0, 250.0, 0.6)),
        rolloff=1.02, pitch_fall=-0.012, breath=0.025, rumble=0.12, rasp=0.025,
        pulse_depth=0.055, pulse_rate=18.0,
        metal=((430.0, 0.11, 17.0), (790.0, 0.065, 22.0), (1210.0, 0.025, 28.0)), seed=707,
    ),
    VoiceSpec(
        "dialogue_orum_cubic_seal.wav", 0.076, 70.0,
        ((330.0, 125.0, 2.9), (690.0, 180.0, 1.85), (1280.0, 260.0, 0.5)),
        rolloff=1.08, pitch_fall=-0.035, breath=0.035, rumble=0.09, rasp=0.055,
        pulse_depth=0.14, pulse_rate=26.0,
        metal=((510.0, 0.085, 25.0), (910.0, 0.04, 31.0)), seed=808,
    ),
    VoiceSpec(
        "dialogue_varn_friendly_beam.wav", 0.072, 82.0,
        ((275.0, 115.0, 2.8), (880.0, 190.0, 2.0), (1570.0, 280.0, 0.45)),
        rolloff=1.18, pitch_fall=0.018, breath=0.045, rumble=0.075, rasp=0.045,
        metal=((630.0, 0.035, 25.0),), seed=909,
    ),
    VoiceSpec(
        "dialogue_hollow_armor.wav", 0.088, 54.0,
        ((250.0, 130.0, 2.2), (520.0, 190.0, 1.45), (980.0, 290.0, 0.35)),
        rolloff=1.00, pitch_fall=-0.10, breath=0.24, rumble=0.18, rasp=0.18,
        pulse_depth=0.10, pulse_rate=19.0,
        metal=((350.0, 0.13, 15.0), (610.0, 0.08, 19.0), (1010.0, 0.035, 24.0)), seed=1010,
    ),
)


def _envelope(t: float, duration: float) -> float:
    attack = min(1.0, t / 0.004)
    release = min(1.0, max(0.0, duration - t) / 0.018)
    body = 0.72 + 0.28 * math.exp(-13.0 * t)
    return attack * release * body


def _render(spec: VoiceSpec) -> list[float]:
    rng = random.Random(spec.seed)
    frame_count = round(spec.duration * SAMPLE_RATE)
    raw_noise = [rng.uniform(-1.0, 1.0) for _ in range(frame_count)]
    low_noise: list[float] = []
    low_state = 0.0
    for value in raw_noise:
        low_state += 0.075 * (value - low_state)
        low_noise.append(low_state)

    phase = rng.random() * math.tau
    harmonic_phases = [rng.random() * math.tau for _ in range(32)]
    output: list[float] = []
    for index in range(frame_count):
        t = index / SAMPLE_RATE
        progress = t / spec.duration
        fundamental = spec.fundamental * (
            1.0 + spec.pitch_fall * progress + 0.0025 * math.sin(math.tau * 5.1 * t)
        )
        phase += math.tau * fundamental / SAMPLE_RATE

        voiced = 0.0
        weight_sum = 0.0
        for harmonic in range(1, 25):
            frequency = fundamental * harmonic
            if frequency >= SAMPLE_RATE * 0.42:
                break
            formant_gain = 1.0
            for center, width, gain in spec.formants:
                distance = (frequency - center) / width
                formant_gain += gain * math.exp(-0.5 * distance * distance)
            weight = formant_gain / (harmonic ** spec.rolloff)
            voiced += weight * math.sin(harmonic * phase + harmonic_phases[harmonic])
            weight_sum += weight
        voiced /= max(1.0, weight_sum * 0.55)

        rough_modulation = 1.0 + spec.rasp * (
            0.65 * math.sin(math.tau * 29.0 * t + 0.4)
            + 0.35 * low_noise[index]
        )
        pulse = 1.0 - spec.pulse_depth + spec.pulse_depth * (
            0.5 + 0.5 * math.sin(math.tau * spec.pulse_rate * t - math.pi / 2.0)
        )
        noise_high = raw_noise[index] - low_noise[index]
        breath = spec.breath * (0.72 * noise_high + 0.28 * low_noise[index])
        rumble = spec.rumble * low_noise[index] * math.sin(math.tau * 92.0 * t + 0.2)

        metal = 0.0
        for frequency, amount, decay in spec.metal:
            metal += amount * math.sin(math.tau * frequency * t + 0.6) * math.exp(-decay * t)

        onset = 0.075 * math.sin(math.tau * 105.0 * t) * math.exp(-55.0 * t)
        sample = (voiced * rough_modulation * pulse + breath + rumble + metal + onset)
        output.append(sample * _envelope(t, spec.duration))

    peak = max(abs(value) for value in output)
    gain = 0.82 / max(peak, 1e-9)
    return [max(-1.0, min(1.0, value * gain)) for value in output]


def _write_pcm16(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for sample in samples:
        integer = round(sample * 32767.0)
        frames.extend(integer.to_bytes(2, "little", signed=True))
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(frames)


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    workspace_root = repo_root.parent
    destinations = (
        repo_root / "godot" / "assets" / "audio" / "dialogue",
        workspace_root / "creative" / "sounds" / "dialogue_phonemes",
    )
    for spec in VOICES:
        samples = _render(spec)
        for destination in destinations:
            _write_pcm16(destination / spec.filename, samples)
        print(f"{spec.filename}: {len(samples) / SAMPLE_RATE:.3f}s")


if __name__ == "__main__":
    main()

"""生成两秒钟的低保真电脑启动提示音。"""

import math
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
DURATION_S = 2.0
OUTPUT = Path("interactables/computer/audio/boot.wav")


def envelope(time_s: float) -> float:
    """让音效平滑淡入淡出，避免波形切断产生爆音。"""
    fade_in = min(1.0, time_s / 0.06)
    fade_out = min(1.0, (DURATION_S - time_s) / 0.35)
    return max(0.0, min(fade_in, fade_out))


def main() -> None:
    """写入由三个柔和正弦音组成的单声道 WAV。"""
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    notes_hz = (261.63, 392.00, 523.25)
    for index in range(int(SAMPLE_RATE * DURATION_S)):
        time_s = index / SAMPLE_RATE
        stage = min(2, int(time_s / 0.55))
        tone = math.sin(math.tau * notes_hz[stage] * time_s)
        overtone = math.sin(math.tau * notes_hz[stage] * 2.0 * time_s) * 0.16
        sample = int((tone + overtone) * envelope(time_s) * 8_500)
        frames.extend(struct.pack("<h", max(-32_768, min(32_767, sample))))
    with wave.open(str(OUTPUT), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)
    print(OUTPUT)


if __name__ == "__main__":
    main()

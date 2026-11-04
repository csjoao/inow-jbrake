"""Gera os sons de "operação concluída" em assets/sounds/.

Sem dependências externas: síntese simples em WAV mono 16-bit, 44.1 kHz.
Rodar da raiz do projeto:  python3 tool/gen_sounds.py
"""
import math
import struct
import wave

sr = 44100


def _save(path, samples):
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(
            b''.join(
                struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples
            )
        )


def _tone(f, dur, kind='sine', partials=None, decay='linear', vol=0.5,
          attack=0.004, rel=0.04):
    out = []
    for k in range(int(sr * dur)):
        x = k / sr
        if kind == 'sine':
            s = math.sin(2 * math.pi * f * x)
        elif kind == 'square':
            s = sum(math.sin(2 * math.pi * f * h * x) / h for h in (1, 3, 5, 7)) * 0.55
        else:  # partials
            s = sum(a * math.sin(2 * math.pi * f * m * x) for m, a in partials)
        if decay == 'linear':
            env = min(1, x / attack) * min(1, (dur - x) / rel)
        else:
            env = min(1, x / attack) * math.exp(-x * decay)
        out.append(s * env * vol)
    return out


def _seq(notes, gap=0.0, **kw):
    out = []
    for f, dur in notes:
        out += _tone(f, dur, **kw)
        out += [0.0] * int(sr * gap)
    return out


def build():
    bell = dict(kind='partials', partials=[(1, 0.6), (2.01, 0.3), (3.01, 0.15), (4.2, 0.08)])
    sounds = {
        'sino': _tone(880, 0.6, decay=6, vol=0.5, **bell),
        'marimba': _tone(659.25, 0.4, kind='partials',
                         partials=[(1, 0.7), (4, 0.25), (10, 0.05)], decay=12, vol=0.55),
        'tada': _seq([(587.33, 0.12), (880.0, 0.3)], kind='partials',
                     partials=[(1, 0.5), (2, 0.3), (3, 0.12)], rel=0.08, vol=0.5),
        'game': _seq([(988, 0.07), (1319, 0.16)], kind='square', rel=0.05, vol=0.42),
        'bloop': _tone(392, 0.22, rel=0.1, vol=0.5),
        'acorde': None,  # preenchido abaixo
    }
    # pop: varredura de frequência pra cima
    n = int(sr * 0.14)
    pop = []
    for k in range(n):
        x = k / sr
        f = 500 + 2500 * (x / 0.14)
        pop.append(math.sin(2 * math.pi * f * x) * min(1, x / 0.003) * min(1, (0.14 - x) / 0.04) * 0.5)
    sounds['pop'] = pop
    # acorde: três notas juntas com decaimento de sino
    chord = [0.0] * int(sr * 0.6)
    for f in (523.25, 659.25, 783.99):
        t = _tone(f, 0.6, kind='partials', partials=[(1, 0.5), (2.01, 0.2)], decay=5, vol=0.3)
        for i, v in enumerate(t):
            chord[i] += v
    sounds['acorde'] = chord

    for name, s in sounds.items():
        _save(f'assets/sounds/{name}.wav', s)
    print('gerados:', ', '.join(sounds))


if __name__ == '__main__':
    build()

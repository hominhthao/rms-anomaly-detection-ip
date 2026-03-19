# scripts/gen_test_vectors.py
import numpy as np

Fs = 2000
N  = 16
t  = np.arange(N) / Fs

# TC1: Normal road noise, 0.3g RMS, ±16g sensor (2048 LSB/g)
normal = np.random.normal(0, 0.3 * 2048, N).astype(int)
normal = np.clip(normal, -32768, 32767)

# TC2: Bearing fault — 120Hz harmonic + noise
bearing_hz = 120
fault = (np.random.normal(0, 0.1 * 2048, N) +
         1.5 * 2048 * np.sin(2 * np.pi * bearing_hz * t))
fault = np.clip(fault.astype(int), -32768, 32767)

np.savetxt("tb/vec_normal.hex", normal & 0xFFFF, fmt="%04x")
np.savetxt("tb/vec_fault.hex",  fault  & 0xFFFF, fmt="%04x")

print(f"Normal RMS²: {np.mean(normal**2):.0f} LSB²")
print(f"Fault  RMS²: {np.mean(fault**2):.0f} LSB²")

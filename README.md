# RMS Anomaly Detection Digital IP

Synthesizable RTL IP core for vibration anomaly detection using window-based RMS computation.

## Architecture
```
data_in [15:0]
     │
     ▼
┌─────────────┐   squared [31:0]   ┌─────────────┐   data_out [35:0]
│ squaring_   │ ─────────────────▶ │ accumulator │ ─────────────────▶ (to shift-avg)
│ unit        │                    │             │
└─────────────┘                    └─────────────┘
                                        │
                                   valid_out (pulse every 16 samples)
```

## Modules

### `squaring_unit`
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `data_in` | input | 16-bit signed | Raw vibration sample |
| `data_out` | output | 32-bit unsigned | Squared result |

Combinational multiply — synthesizes to single DSP/multiplier block.

### `accumulator`
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1-bit | System clock |
| `rst_n` | input | 1-bit | Active-low sync reset |
| `data_in` | input | 32-bit | Squared sample from squaring_unit |
| `valid_in` | input | 1-bit | Input data valid strobe |
| `data_out` | output | 36-bit | Sum of 16 squared samples |
| `valid_out` | output | 1-bit | Pulses high when window of 16 samples complete |

Accumulates 16 samples per window. `valid_out` pulses for 1 cycle when window is full and sum is ready.

## Simulation Results

| Test | Input | Expected | Result |
|------|-------|----------|--------|
| Squaring positive | +5 | 25 | ✅ 25 |
| Squaring negative | -5 | 25 | ✅ 25 |
| Squaring large | +200 | 40000 | ✅ 40000 |
| Accumulator window | 16 × 100 | 1600 | ✅ 1600 |
| valid_out timing | 16 samples | pulse @ sample 16 | ✅ |

## Tools
- Simulation: Icarus Verilog + GTKWave
- Synthesis target: Intel Cyclone IV (Quartus)

## Status
| Module | RTL | Testbench | Simulation |
|--------|-----|-----------|------------|
| squaring_unit | ✅ | ✅ | ✅ |
| accumulator | ✅ | ✅ | ✅ |
| shift_avg (÷16) | 🔄 | ⬜ | ⬜ |
| FSM controller | 🔄 | ⬜ | ⬜ |
| Top-level integration | ⬜ | ⬜ | ⬜ |

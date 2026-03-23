# PROJECT BRIEF — RMS Anomaly Detection IP

> Paste file này vào đầu conversation mới để Claude hiểu ngay context.
> Cập nhật mỗi khi hoàn thành một milestone.

---

## 1. Project là gì

RTL IP core phát hiện bất thường rung động bằng **windowed RMS² computation**.
Thiết kế để offload hoàn toàn việc xử lý DSP khỏi CPU — host MCU chỉ nhận
interrupt khi `anomaly_flag` lên HIGH.

**Repo:** https://github.com/hominhthao/rms-anomaly-detection-ip  
**Author:** Hồ Minh Thao — HCMUT, Electronics & Telecommunications

---

## 2. Kiến trúc pipeline (5 module, fully synthesizable)

```
data_in [15:0] signed (ADC sample)
     │
     ▼
┌─────────────┐  sq [31:0]
│squaring_unit│ ──────────▶ x² combinational, latency 0 cycle
└─────────────┘
     │
     ▼
┌─────────────┐  sum [35:0] + valid_out (pulse mỗi 16 sample)
│ accumulator │ ──────────▶ Σ 16 samples, sequential, 16-cycle latency
└─────────────┘
     │
     ▼
┌─────────────┐  avg [31:0]
│  shift_avg  │ ──────────▶ >> 4 (÷16), zero LUT — pure wire routing
└─────────────┘
     │
     ▼
┌─────────────┐  anomaly_flag + valid_out
│  comparator │ ──────────▶ avg > THRESHOLD, combinational
└─────────────┘
     │
     ▼
┌─────────────┐
│   rms_top   │ — structural top, kết nối 4 module trên
└─────────────┘
```

**Quyết định thiết kế quan trọng:** Dùng RMS² thay vì true RMS để tránh
sqrt — `RMS² > T²` tương đương `RMS > T`, zero detection accuracy loss.

---

## 3. Port interface — rms_top

```verilog
module rms_top #(
    parameter THRESHOLD = 32'd1_200_000  // Calibrated: 3× normal RMS², ±16g sensor
)(
    input  wire              clk,         // Fmax verified: 120.5 MHz
    input  wire              rst_n,       // Active-low synchronous reset
    input  wire signed [15:0] data_in,   // ADC sample, signed 2's complement
    input  wire              valid_in,   // HIGH với mỗi valid ADC sample
    output wire [31:0]       avg_out,    // Mean square (RMS²)
    output wire              valid_out,  // Pulse 1 cycle khi window complete
    output wire              anomaly_flag // HIGH khi RMS² > THRESHOLD
);
```

**Bit-width rationale:**
- `squaring_unit`: 16-bit signed → 32-bit unsigned. Max: 32767² = 1.07B < 2³¹ ✅
- `accumulator`: 32 + log₂(16) = 36-bit. Tránh overflow khi max input × 16 window
- `shift_avg`: zero LUT — synthesizes to wire routing only

---

## 4. Sensor model & test vectors

**Sensor:** ±16g MEMS accelerometer, sensitivity 2048 LSB/g, Fs = 2 kHz  
**Generator:** `scripts/gen_test_vectors.py` (NumPy, physical-derived model)

```python
# TC1: Normal road noise — 0.3g RMS broadband
normal = np.random.normal(0, 0.3 * 2048, N)   # σ = 614 LSB

# TC2: Bearing fault — 1.5g @ 120Hz + 0.1g noise
fault = 1.5 * 2048 * np.sin(2π × 120Hz × t) + noise
```

**Test results (từ simulation thực tế):**

| Test Case | avg_out (LSB²) | anomaly_flag | Kết quả |
|-----------|---------------|--------------|---------|
| TC1 — Normal road | ~290,080 | 0 | ✅ No false positive |
| TC2 — Bearing fault | ~4,790,948 | 1 | ✅ Fault detected |

- TC1 cách threshold **4.1× dưới** — robust với road variation
- TC2 cách threshold **4.0× trên** — reliable detection
- Separation ratio TC1/TC2: **~16.5×**

> Lưu ý: vec_normal.hex và vec_fault.hex được generate bằng random seed
> nên giá trị RMS² thay đổi mỗi lần chạy gen_test_vectors.py.
> Các giá trị trên là từ lần chạy gần nhất.

---

## 5. Synthesis results (Gowin GW1N-1, Gowin EDA 1.9.9)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT4 | 177 | 1152 | **15.4%** |
| Register | 73 | 945 | 7.7% |
| DSP | 0 | 4 | **0%** |

**Fmax: 120.5 MHz** — constraint 50 MHz, slack +11.7 ns, margin **2.4×**

Critical path: 35-bit carry chain trong `accumulator`.

---

## 6. Status các module

| Module | RTL | Testbench | Simulation | Ghi chú |
|--------|-----|-----------|------------|---------|
| `squaring_unit` | ✅ | ✅ | ✅ | Comb, LUT-based multiplier (no DSP) |
| `accumulator` | ✅ | ✅ | ✅ | Sequential, 4-bit counter nội bộ |
| `shift_avg` | ✅ | ✅ | ✅ | Zero LUT, pure wire routing |
| `comparator` | ✅ | ✅ | ✅ | Comb, THRESHOLD = 1_200_000 |
| `rms_top` | ✅ | ✅ | ✅ | Full pipeline verified với physical vectors |
| `demo_top` | ✅ | ⬜ | ⬜ | **Wrapper Tang Nano 1K — mới viết, chưa flash** |

---

## 7. Demo plan — Tang Nano 1K (GW1NZ-LV1, 1152 LUT)

### Pin assignment
| Tín hiệu | Pin | Mô tả |
|----------|-----|-------|
| `clk` | 45 | Onboard 27 MHz oscillator |
| `btn` | 3 | BTN1, active-low, toggle TC1↔TC2 |
| `led_r` | 16 | Đỏ = anomaly (active-low) |
| `led_g` | 17 | Xanh = normal (active-low) |

### Test vectors hardcoded trong demo_top ROM
```
TC1 — Normal:  16 × (+1000) → avg = 1_000_000 < 1_200_000 → LED XANH
TC2 — Anomaly: 16 × (+1100) → avg = 1_210_000 > 1_200_000 → LED ĐỎ
```

> Lưu ý: Demo dùng simplified hardcoded vector vì Tang Nano 1K không có ADC.
> Physical vectors chỉ dùng trong simulation.

### Luồng hoạt động FSM (3 state)
```
Bấm BTN → S_IDLE → S_SEND (feed 16 samples, 1/cycle) → S_WAIT (4 cycles) → S_IDLE
                                                              ↓
                                                    valid_out pulse
                                                         ↓
                                              latch anomaly_flag → LED giữ nguyên
```

### Các quyết định thiết kế demo
| Quyết định | Lý do |
|-----------|-------|
| 2-FF synchronizer trước debounce | Tránh metastability từ async button |
| Debounce = 135,000 cycles (~5ms) | Đủ cho nút cơ học |
| LED latch (không assign thẳng) | valid_out chỉ pulse 1 cycle = 37ns, mắt không thấy |
| FSM WAIT = 4 cycles | Pipeline latency thực tế 1 cycle, +3 buffer an toàn |

---

## 8. File structure thực tế

```
rms-anomaly-detection-ip/
├── src/
│   ├── squaring_unit.v
│   ├── accumulator.v
│   ├── shift_avg.v
│   ├── comparator.v
│   └── rms_top.v
├── tb/
│   ├── tb_squaring_unit.v
│   ├── tb_accumulator.v
│   ├── tb_shift_avg.v
│   ├── tb_rms_top.v
│   ├── vec_normal.hex      ← generated by gen_test_vectors.py
│   └── vec_fault.hex       ← generated by gen_test_vectors.py
├── scripts/
│   └── gen_test_vectors.py
├── sim/waveform/
│   ├── wave_acc.vcd
│   ├── wave_rms_top.vcd
│   ├── wave_shift.vcd
│   └── wave_squa.vcd
├── img/
│   ├── synthesis_resource.png
│   ├── synthesis_timing.png
│   ├── synthesis_schematic_pipeline.png
│   ├── synthesis_schematic_comparator.png
│   ├── waveform_accumulator.png
│   ├── waveform_rms_top.png
│   ├── waveform_shift_avg.png
│   └── waveform_squaring_unit.png
├── PROJECT_BRIEF.md        ← file này
├── README.md
├── LICENSE
└── .gitignore

— Files mới, chưa push lên repo —
demo_top.v              ← Top-level wrapper Tang Nano 1K
tang_nano_1k.cst        ← Physical constraint (pin assignment)
tang_nano_1k.sdc        ← Timing constraint (27 MHz)
```

---

## 9. Việc cần làm tiếp theo

- [ ] Copy `demo_top.v`, `tang_nano_1k.cst`, `tang_nano_1k.sdc` vào `~/RMS_PJ/`
- [ ] `git add . && git commit -m "feat: add Tang Nano 1K demo files" && git push`
- [ ] Mở Gowin EDA → tạo project mới → add tất cả `src/*.v` + `demo_top.v`
- [ ] Set top module = `demo_top`, add `.cst` và `.sdc`
- [ ] Chạy synthesis → kiểm tra LUT count
- [ ] Generate bitstream → flash lên Tang Nano 1K
- [ ] Test thực tế: bấm nút → LED xanh (TC1) → bấm lại → LED đỏ (TC2)
- [ ] Quay video demo 30 giây → upload lên README

---

## 10. Reproduce simulation

```bash
# Generate test vectors
python3 scripts/gen_test_vectors.py

# Simulate full pipeline
iverilog -o sim/top_sim \
  src/squaring_unit.v src/accumulator.v \
  src/shift_avg.v src/comparator.v src/rms_top.v \
  tb/tb_rms_top.v
vvp sim/top_sim

# View waveform
gtkwave sim/waveform/wave_rms_top.vcd
```

**Tools:** Icarus Verilog v11 · GTKWave v3.4 · Gowin EDA 1.9.9 · Python 3.x + NumPy

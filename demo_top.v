// =============================================================
// demo_top.v — Tang Nano 1K Demo Wrapper
// RMS Anomaly Detection IP
// Board  : Sipeed Tang Nano 1K (GW1NZ-LV1, 1152 LUT)
// Clock  : 27 MHz onboard oscillator
// BTN    : PIN 3  — chọn TC1 (normal) / TC2 (anomaly)
// LED_R  : PIN 16 — anomaly detected
// LED_G  : PIN 17 — normal (no anomaly)
// =============================================================
// Test vectors (hardcoded ROM):
//   TC1 — 16 × (+1000) → avg = 1_000_000 < 1_200_000 → NORMAL
//   TC2 — 16 × (+1100) → avg = 1_210_000 > 1_200_000 → ANOMALY
// =============================================================

module demo_top (
    input  wire clk,        // 27 MHz
    input  wire btn,        // active-low (onboard pull-up)
    output wire led_r,      // anomaly  — active-low on Tang Nano
    output wire led_g       // normal   — active-low on Tang Nano
);

// ------------------------------------------------------------------
// 1. Button debounce  (~5 ms @ 27 MHz = 135_000 cycles)
// ------------------------------------------------------------------
localparam DEBOUNCE_MAX = 135_000;

reg  [17:0] db_cnt;
reg         btn_sync0, btn_sync1;   // 2-FF synchronizer
reg         btn_stable;
reg         btn_prev;
wire        btn_pressed;            // single-cycle pulse on release

// 2-FF sync (button vào từ async domain)
always @(posedge clk) begin
    btn_sync0 <= ~btn;      // invert: active-high bên trong
    btn_sync1 <= btn_sync0;
end

// Debounce counter
always @(posedge clk) begin
    if (btn_sync1 == btn_stable) begin
        db_cnt <= 0;
    end else begin
        db_cnt <= db_cnt + 1;
        if (db_cnt == DEBOUNCE_MAX - 1) begin
            btn_stable <= btn_sync1;
            db_cnt     <= 0;
        end
    end
end

// Detect rising edge of stable button (press)
always @(posedge clk) btn_prev <= btn_stable;
assign btn_pressed = btn_stable & ~btn_prev;

// ------------------------------------------------------------------
// 2. TC selector (toggle on each button press)
// ------------------------------------------------------------------
reg tc_sel;   // 0 = TC1 (normal), 1 = TC2 (anomaly)

always @(posedge clk) begin
    if (btn_pressed) tc_sel <= ~tc_sel;
end

// ------------------------------------------------------------------
// 3. Hardcoded ROM — 32 entries × 16-bit signed
//    [0..15]  = TC1: all +1000  → avg = 1_000_000 (NORMAL)
//    [16..31] = TC2: all +1100  → avg = 1_210_000 (ANOMALY)
// ------------------------------------------------------------------
reg signed [15:0] rom [0:31];
integer i;

initial begin
    for (i = 0;  i < 16; i = i + 1) rom[i]    = 16'sd1000;
    for (i = 16; i < 32; i = i + 1) rom[i]    = 16'sd1100;
end

// ------------------------------------------------------------------
// 4. Sequencer FSM — feeds 16 samples into rms_top, one per cycle
// ------------------------------------------------------------------
// States
localparam S_IDLE    = 2'd0;
localparam S_SEND    = 2'd1;
localparam S_WAIT    = 2'd2;

reg  [1:0]  state;
reg  [3:0]  sample_idx;     // 0..15
reg         rms_rst_n;
reg  signed [15:0] data_in;
reg         valid_in;

// Pipeline latency: squaring(comb) + acc(1) + shift(comb) + cmp(comb) = 1 cycle
// valid_out pulses exactly 1 cycle after 16th sample accumulates
// Add small wait margin = 4 cycles
localparam WAIT_CYCLES = 4;
reg [2:0] wait_cnt;

always @(posedge clk) begin
    case (state)
        S_IDLE: begin
            valid_in   <= 1'b0;
            rms_rst_n  <= 1'b0;    // hold reset
            sample_idx <= 4'd0;
            wait_cnt   <= 0;
            if (btn_pressed) begin
                rms_rst_n <= 1'b1; // release reset
                state     <= S_SEND;
            end
        end

        S_SEND: begin
            data_in    <= rom[{tc_sel, sample_idx}];
            valid_in   <= 1'b1;
            if (sample_idx == 4'd15) begin
                sample_idx <= 4'd0;
                valid_in   <= 1'b0;
                state      <= S_WAIT;
            end else begin
                sample_idx <= sample_idx + 1;
            end
        end

        S_WAIT: begin
            wait_cnt <= wait_cnt + 1;
            if (wait_cnt == WAIT_CYCLES - 1)
                state <= S_IDLE;
        end

        default: state <= S_IDLE;
    endcase
end

// ------------------------------------------------------------------
// 5. rms_top instance
// ------------------------------------------------------------------
wire [31:0] avg_out;
wire        rms_valid_out;
wire        anomaly_flag;

rms_top u_rms (
    .clk         (clk),
    .rst_n       (rms_rst_n),
    .data_in     (data_in),
    .valid_in    (valid_in),
    .avg_out     (avg_out),
    .valid_out   (rms_valid_out),
    .anomaly_flag(anomaly_flag)
);

// ------------------------------------------------------------------
// 6. Latch result when valid_out pulses — hold until next run
// ------------------------------------------------------------------
reg led_r_reg;
reg led_g_reg;

always @(posedge clk) begin
    if (!rms_rst_n) begin
        led_r_reg <= 1'b0;
        led_g_reg <= 1'b0;
    end else if (rms_valid_out) begin
        led_r_reg <=  anomaly_flag;   // anomaly  → red ON
        led_g_reg <= ~anomaly_flag;   // normal   → green ON
    end
end

// Tang Nano LEDs are active-low
assign led_r = ~led_r_reg;
assign led_g = ~led_g_reg;

endmodule

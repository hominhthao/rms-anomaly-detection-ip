// =============================================================
// demo_top.v — Tang Nano 1K Demo Wrapper
// RMS Anomaly Detection IP
// Board  : Sipeed Tang Nano 1K (GW1NZ-LV1, 1152 LUT)
// Clock  : 27 MHz onboard oscillator
// BTN    : PIN 13 — KEY_A (giữ = TC2 anomaly, thả = TC1 normal)
// LED_R  : PIN 9  — anomaly (active-low)
// LED_G  : PIN 11 — normal  (active-low)
// UART TX: PIN 18 — 115200 8N1
// =============================================================

module demo_top (
    input  wire clk,
    input  wire btn,
    output wire led_r,
    output wire led_g,
    output wire uart_tx_pin
);

// ------------------------------------------------------------------
// 1. Button sync
// ------------------------------------------------------------------
reg btn_sync0, btn_sync1;
always @(posedge clk) begin
    btn_sync0 <= ~btn;
    btn_sync1 <= btn_sync0;
end
wire tc_sel = btn_sync1;

// ------------------------------------------------------------------
// 2. Hardcoded ROM
// ------------------------------------------------------------------
reg signed [15:0] rom [0:31];
integer ii;
initial begin
    for (ii = 0;  ii < 16; ii = ii + 1) rom[ii]  = 16'sd1000;
    for (ii = 16; ii < 32; ii = ii + 1) rom[ii]  = 16'sd1100;
end

// ------------------------------------------------------------------
// 3. Free-running sequencer (đã verify hoạt động)
// ------------------------------------------------------------------
reg [3:0]         sample_idx = 4'd0;
reg signed [15:0] data_in    = 16'sd0;
reg               valid_in   = 1'b0;
wire              rms_rst_n  = 1'b1;

always @(posedge clk) begin
    data_in    <= rom[{tc_sel, sample_idx}];
    valid_in   <= 1'b1;
    sample_idx <= sample_idx + 1;
end

// ------------------------------------------------------------------
// 4. rms_top instance
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
// 5. LED latch
// ------------------------------------------------------------------
reg led_r_reg = 1'b0;
reg led_g_reg = 1'b1;

always @(posedge clk) begin
    if (rms_valid_out) begin
        led_r_reg <=  anomaly_flag;
        led_g_reg <= ~anomaly_flag;
    end
end

assign led_r = ~led_r_reg;
assign led_g = ~led_g_reg;

// ------------------------------------------------------------------
// 6. UART TX instance
// ------------------------------------------------------------------
reg        uart_send = 1'b0;
reg  [7:0] uart_data = 8'd0;
wire       uart_busy;

uart_tx #(.CLKS_PER_BIT(234)) u_uart (
    .clk    (clk),
    .i_send (uart_send),
    .i_data (uart_data),
    .o_tx   (uart_tx_pin),
    .o_busy (uart_busy)
);

// Message ROM: 2 × 24 bytes
// [NORMAL]  RMS2=1000000\r\n
// [ANOMALY] RMS2=1210000\r\n
reg [7:0] msg_rom [0:47];
initial begin
    msg_rom[ 0]=8'h5B; msg_rom[ 1]=8'h4E; msg_rom[ 2]=8'h4F; msg_rom[ 3]=8'h52;
    msg_rom[ 4]=8'h4D; msg_rom[ 5]=8'h41; msg_rom[ 6]=8'h4C; msg_rom[ 7]=8'h5D;
    msg_rom[ 8]=8'h20; msg_rom[ 9]=8'h20; msg_rom[10]=8'h52; msg_rom[11]=8'h4D;
    msg_rom[12]=8'h53; msg_rom[13]=8'h32; msg_rom[14]=8'h3D; msg_rom[15]=8'h31;
    msg_rom[16]=8'h30; msg_rom[17]=8'h30; msg_rom[18]=8'h30; msg_rom[19]=8'h30;
    msg_rom[20]=8'h30; msg_rom[21]=8'h30; msg_rom[22]=8'h0D; msg_rom[23]=8'h0A;
    // [ANOMALY] RMS2=1210000\r\n
    msg_rom[24]=8'h5B; msg_rom[25]=8'h41; msg_rom[26]=8'h4E; msg_rom[27]=8'h4F;
    msg_rom[28]=8'h4D; msg_rom[29]=8'h41; msg_rom[30]=8'h4C; msg_rom[31]=8'h59;
    msg_rom[32]=8'h5D; msg_rom[33]=8'h20; msg_rom[34]=8'h52; msg_rom[35]=8'h4D;
    msg_rom[36]=8'h53; msg_rom[37]=8'h32; msg_rom[38]=8'h3D; msg_rom[39]=8'h31;
    msg_rom[40]=8'h32; msg_rom[41]=8'h31; msg_rom[42]=8'h30; msg_rom[43]=8'h30;
    msg_rom[44]=8'h30; msg_rom[45]=8'h30; msg_rom[46]=8'h0D; msg_rom[47]=8'h0A;
end

// UART sender FSM
// Chỉ lấy kết quả khi UART đang idle — bỏ qua các valid_out pulse khi busy
localparam U_IDLE = 2'd0;
localparam U_LOAD = 2'd1;
localparam U_WAIT = 2'd2;

reg [1:0] u_state       = U_IDLE;
reg [4:0] u_idx         = 5'd0;
reg       anomaly_latch = 1'b0;

always @(posedge clk) begin
    uart_send <= 1'b0;

    case (u_state)
        U_IDLE: begin
            // Chỉ capture khi valid_out pulse VÀ UART không busy
            if (rms_valid_out && !uart_busy) begin
                anomaly_latch <= anomaly_flag;
                u_idx         <= 5'd0;
                u_state       <= U_LOAD;
            end
        end

        U_LOAD: begin
            uart_data <= msg_rom[{anomaly_latch, u_idx[3:0]}];
            uart_send <= 1'b1;
            u_state   <= U_WAIT;
        end

        U_WAIT: begin
            if (!uart_busy) begin
                if (u_idx == 5'd23) begin
                    u_state <= U_IDLE;
                end else begin
                    u_idx   <= u_idx + 1;
                    u_state <= U_LOAD;
                end
            end
        end

        default: u_state <= U_IDLE;
    endcase
end

endmodule
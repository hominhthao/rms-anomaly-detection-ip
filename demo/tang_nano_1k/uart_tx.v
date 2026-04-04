// =============================================================
// uart_tx.v — Simple UART Transmitter
// 8N1, configurable baud via CLKS_PER_BIT parameter
// 27 MHz / 115200 = 234 clocks per bit
// =============================================================
// Interface:
//   i_send     : pulse HIGH 1 cycle to start transmission
//   i_data     : 8-bit data to send (sampled when i_send=1)
//   o_tx       : UART TX line
//   o_busy     : HIGH while transmitting
// =============================================================

module uart_tx #(
    parameter CLKS_PER_BIT = 234    // 27_000_000 / 115200
)(
    input  wire       clk,
    input  wire       i_send,       // 1-cycle pulse to send
    input  wire [7:0] i_data,
    output reg        o_tx   = 1'b1,
    output wire       o_busy
);

localparam S_IDLE  = 2'd0;
localparam S_START = 2'd1;
localparam S_DATA  = 2'd2;
localparam S_STOP  = 2'd3;

reg [1:0]  state    = S_IDLE;
reg [7:0]  clk_cnt  = 0;
reg [2:0]  bit_idx  = 0;
reg [7:0]  shift    = 0;

assign o_busy = (state != S_IDLE);

always @(posedge clk) begin
    case (state)
        S_IDLE: begin
            o_tx <= 1'b1;
            if (i_send) begin
                shift   <= i_data;
                clk_cnt <= 0;
                state   <= S_START;
            end
        end

        S_START: begin
            o_tx <= 1'b0;   // start bit
            if (clk_cnt == CLKS_PER_BIT - 1) begin
                clk_cnt <= 0;
                bit_idx <= 0;
                state   <= S_DATA;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end

        S_DATA: begin
            o_tx <= shift[bit_idx];
            if (clk_cnt == CLKS_PER_BIT - 1) begin
                clk_cnt <= 0;
                if (bit_idx == 3'd7) begin
                    state <= S_STOP;
                end else begin
                    bit_idx <= bit_idx + 1;
                end
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end

        S_STOP: begin
            o_tx <= 1'b1;   // stop bit
            if (clk_cnt == CLKS_PER_BIT - 1) begin
                clk_cnt <= 0;
                state   <= S_IDLE;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    endcase
end

endmodule

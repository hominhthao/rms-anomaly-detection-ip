`timescale 1ns/1ns 

module tb_rms_top ;
reg clk;
reg rst_n;
reg valid_in;
reg [15:0] data_in;

wire [31:0] avg_out;
wire valid_out;
wire anomaly_flag;

rms_top uut (.clk(clk), .rst_n(rst_n), .anomaly_flag(anomaly_flag), .valid_in(valid_in), .data_in(data_in), .avg_out(avg_out), .valid_out(valid_out));

initial clk = 0;
always #5 clk = ~clk; 

// task gửi 16 sampples
task send_window (input signed [15:0] sample);

begin
repeat(16) begin
	valid_in = 1'b1;
	data_in = sample;
	@(posedge clk);
end
	valid_in = 1'b0;
end
endtask

// Thêm vào phần khai báo (trước initial begin)
reg signed [15:0] vec_normal [0:15];
reg signed [15:0] vec_fault  [0:15];

integer i;

initial begin
    $dumpfile("sim/waveform/wave_rms_top.vcd");
    $dumpvars(0, tb_rms_top);

    $readmemh("tb/vec_normal.hex", vec_normal);
    $readmemh("tb/vec_fault.hex",  vec_fault);

    rst_n = 0; valid_in = 0; data_in = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // TC1: Normal road vibration (~0.3g RMS, ±16g sensor)
    for (i = 0; i < 16; i = i + 1) begin
        @(posedge clk);
        data_in  = vec_normal[i];
        valid_in = 1;
    end
    // valid_out pulse tại đây — capture ngay
    @(posedge clk);
    valid_in = 0;
    @(posedge clk); // 1 cycle settle
    $display("TC1 [Normal ~0.3g RMS @ ±16g]: avg_out=%0d LSB2, anomaly=%b (expected anomaly=0)",
             avg_out, anomaly_flag);

    repeat(4) @(posedge clk);

    // TC2: Bearing fault (~1.5g RMS @ 120Hz)
    for (i = 0; i < 16; i = i + 1) begin
        @(posedge clk);
        data_in  = vec_fault[i];
        valid_in = 1;
    end
    @(posedge clk);
    valid_in = 0;
    @(posedge clk);
    $display("TC2 [Bearing fault ~1.5g RMS @ 120Hz]: avg_out=%0d LSB2, anomaly=%b (expected anomaly=1)",
             avg_out, anomaly_flag);

    repeat(4) @(posedge clk);
    $finish;
end

endmodule 


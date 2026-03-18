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

initial begin
$dumpfile("wave.vcd");
$dumpvars (0, tb_rms_top);
rst_n = 0;
data_in =0; 
valid_in =0;
#20 rst_n = 1;

//test 1
send_window(100);
@(posedge valid_out);
@(posedge clk); 
$display("test_case1: avg_out=%0d, anomaly_flag=%b (expected 10000 anomaly_flag=0)", avg_out, anomaly_flag);

//test 2
send_window(1000);
@(posedge valid_out);
@(posedge clk);
$display ("testcase 2: avg_out=%0d, anomaly_flag=%b (expected 1000000 anomaly_flag=1)", avg_out, anomaly_flag);

#500 $finish;
end

endmodule 


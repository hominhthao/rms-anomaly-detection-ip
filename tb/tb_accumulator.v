`timescale 1ns/1ns

module tb_accumulator ;

reg clk;
reg rst_n;
reg [31:0] data_in;
reg valid_in ;

wire [35:0]  data_out;
wire valid_out;

accumulator uut (.clk(clk), .rst_n(rst_n), .data_in(data_in), .data_out(data_out), .valid_out(valid_out), .valid_in(valid_in));

always #5 clk = ~clk;
initial begin
$dumpfile("wave_2.vcd");
$dumpvars(0, tb_accumulator);

clk =0;
rst_n=0;
valid_in =0;
data_in = 0;

#20 rst_n = 1'b1; 

repeat(16) begin
valid_in = 1;
data_in = 100;
@(posedge valid_out); 
@(posedge clk);
end 

$display("data_out = %0d (expected 1600)", data_out);
$finish;
end 

endmodule 


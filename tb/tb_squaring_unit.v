`timescale 1ns/1ns
module tb_squaring_unit ;

reg signed [15:0] data_in;
wire [31:0] data_out;

squaring_unit uut (.data_in(data_in), .data_out(data_out)); // instance

initial begin 
$dumpfile("wave.vcd");
$dumpvars(0, tb_squaring_unit);

// 4 test case

data_in = 5; #10; $display ("data_in =%0d, data_out=%0d (expected 25)", data_in, data_out);  
data_in = -5; #10; $display ("data_in =%0d, data_out=%0d (expected 25)", data_in, data_out);
data_in = 200; #10; $display ("data_in =%0d, data_out=%0d (expected 40000)", data_in, data_out);
data_in = -200; #10; $display ("data_in =%0d, data_out=%0d (expected 40000)", data_in, data_out);

$finish;

end
endmodule 

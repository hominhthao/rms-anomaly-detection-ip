`timescale 1ns/1ps

module tb_shift_avg ;

reg [35:0] data_in;
reg valid_in ;

wire [31:0] data_out; 
wire valid_out; 

shift_avg uut (.data_in(data_in), .data_out(data_out), .valid_in(valid_in), .valid_out(valid_out));

initial begin 
$dumpfile("wave.vcd");
$dumpvars(0,tb_shift_avg);

#10 data_in = 36'd1600;
#10  valid_in = 1'b1;

#1 $display ("data_out = %0d (expected 100)", data_out);

$finish;
end
endmodule 


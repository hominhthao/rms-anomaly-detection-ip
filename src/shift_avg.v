module shift_avg (
input wire [35:0] data_in, // output from accumlator
input wire valid_in, // valid_out from accumulator

output wire [31:0] data_out, // chia cho 16 = shift >> 4
output wire valid_out
);

assign data_out = data_in >> 4 ;
assign valid_out = valid_in; 

endmodule

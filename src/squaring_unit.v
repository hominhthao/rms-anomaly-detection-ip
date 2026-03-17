module squaring_unit (
input wire signed [15:0] data_in,
output wire [31:0] data_out
);

assign data_out = data_in *  data_in;

endmodule

module rms_top (

input wire clk,
input wire rst_n,
input wire signed [15:0] data_in,
input wire valid_in,
output wire [31:0] avg_out,
output wire valid_out,
output wire anomaly_flag
);

assign avg_out = shift_data;

//internal wire -> kết nối các module lại với nhau
wire [31:0] sq_to_acc;
wire [35:0] acc_to_shift;
wire acc_valid;
wire [31:0] shift_data;
wire shift_valid;

//instance module squaring_unit
squaring_unit uut_squ (.data_in(data_in), .data_out(sq_to_acc));

//instance module accmulator
accumulator uut_acc (.data_in(sq_to_acc), .valid_out(acc_valid), .valid_in(valid_in), .data_out(acc_to_shift), .clk(clk), .rst_n(rst_n));

//instance module shift_avg
shift_avg uut_shift (.data_in(acc_to_shift), .valid_in(acc_valid), .data_out(shift_data), .valid_out(shift_valid));

//instance module comparator
comparator uut_com (.data_in(shift_data), .valid_in(shift_valid), .anomaly_flag(anomaly_flag), .valid_out(valid_out)); 

endmodule 

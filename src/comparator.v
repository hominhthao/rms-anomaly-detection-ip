module comparator #(parameter THRESHOLD = 1200000) (

input wire [31:0] data_in, // avg_out từ shift_avg
input wire valid_in, // valid_out từ shift_avg

output wire anomaly_flag, 
output wire valid_out 
);

 
assign anomaly_flag = (data_in > THRESHOLD) ? 1'b1 : 1'b0;
assign valid_out = valid_in;

endmodule 

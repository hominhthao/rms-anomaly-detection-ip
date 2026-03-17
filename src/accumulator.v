module accumulator (
input wire clk,
input wire rst_n,
input wire [31:0] data_in, // data_out của squaring  
input valid_in, 

output reg [35:0]  data_out,
output reg  valid_out // raise high if enough 16 samples
);

reg [3:0] counter ; // đếm số sample đã nhận (16 sample) 
reg [35:0] accumulator ;
 
always @(posedge clk) begin

if (!rst_n) begin
counter <= 1'b0;
data_out <= 1'b0;
accumulator <=1'b0;
valid_out <=1'b0; 
end else

if (valid_in == 1'b1) begin
	if (counter == 15) begin 
	counter <= 1'b0;
	valid_out <= 1'b1;
	data_out <= accumulator + data_in;
	accumulator <= 1'b0 ;	
	end 
	else begin 
	accumulator <= data_in + accumulator; 
	counter <= counter + 1;
	valid_out <= 1'b0;

	end 
end else begin 
valid_out <= 1'b0 ;
end 
end 

endmodule

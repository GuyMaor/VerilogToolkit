module async_fifo(wdata,
			rdata,
			wen,
			ren,
			is_full,
			is_empty,
			wclk,
			rclk,
			rst);

	parameter WIDTH = 16;	
	parameter ADDR_BITS = 3;
	localparam SIZE = 1<<ADDR_BITS;


	//Delcare inputs and outputs
	input [WIDTH-1:0] wdata;
	output wire [WIDTH-1:0] rdata;
	
	input wen;
	input ren;
	output wire is_full;
	output wire is_empty;
	input wclk;
	input rclk;
	input rst;
	
	//Delcare internal signals
	wire [ADDR_BITS:0] rptr_enc;
	wire [ADDR_BITS:0] wptr_enc;
	wire [ADDR_BITS-1:0] raddr;
	wire [ADDR_BITS-1:0] waddr;
	
	//Implement memory unit
	reg [WIDTH-1:0] mem_block [0:SIZE-1];
	
	read_ptr_module #(ADDR_BITS) read_ptr_inst(
		.ren(ren),
		.rptr_enc(rptr_enc),		
		.wptr_enc(wptr_enc),
		.is_empty(is_empty),
		.raddr(raddr),
		.rst(rst),
		.clk(rclk));
		
	write_ptr_module #(ADDR_BITS) write_ptr_inst(
						.wen(wen),
						.rptr_enc(rptr_enc),		
						.wptr_enc(wptr_enc),
						.is_full(is_full),
						.waddr(waddr),
						.rst(rst),
						.clk(wclk));

	always @(posedge wclk)
	begin
		if((~is_full) & wen)
			mem_block[waddr] <= wdata;
	end
	
	assign rdata = mem_block[raddr];
endmodule

module read_ptr_module(	ren,
						wptr_enc,
						rptr_enc,
						is_empty,
						raddr,
						rst,
						clk);
						
	parameter ADDR_BITS = 3;
	
	input ren, rst, clk;
	input [ADDR_BITS:0] wptr_enc;
	output wire [ADDR_BITS-1:0] raddr;
	output reg [ADDR_BITS:0] rptr_enc;
	output wire is_empty;
	
	//Address as a register
	reg [ADDR_BITS:0] rptr_counter;
	
	//Declare sync registers
	reg [ADDR_BITS:0] wptr_enc_sync1;
	reg [ADDR_BITS:0] wptr_enc_sync2;
	
	//Decoded read pointer
	wire [ADDR_BITS:0] wptr_wire;
	
	//Implement sync registers and address pointer
	always @(posedge clk or negedge rst)
	begin
		if(~rst)
		begin
			wptr_enc_sync1 <= 0;
			wptr_enc_sync2 <= 0;
			rptr_enc <= 2'b11<<(ADDR_BITS-1);
			rptr_counter <= 1<<ADDR_BITS;
		end
		else
		begin
			wptr_enc_sync1 <= wptr_enc;
			wptr_enc_sync2 <= wptr_enc_sync1;
			if(!is_empty & ren)
				rptr_counter <= rptr_counter + 1;
			rptr_enc <= rptr_counter ^ (rptr_counter>>1);
		end
	end
	
	//waddr is basically rptr_counter
	assign raddr = rptr_counter;
	
	//Decode wptr
	assign wptr_wire[ADDR_BITS] = wptr_enc_sync2[ADDR_BITS];
	generate
		genvar i;
		for(i = 0; i<ADDR_BITS; i = i+1)
		begin
			assign wptr_wire[i] = wptr_wire[i+1] ^ wptr_enc_sync2[i];
		end
	endgenerate
	
	//Implement is empty
  assign is_empty = (wptr_wire ^ (1<<ADDR_BITS)) == rptr_counter;

endmodule

module write_ptr_module(wen,
						wptr_enc,
						rptr_enc,
						is_full,
						waddr,
						rst,
						clk);
						
	parameter ADDR_BITS = 3;
	
	input wen, rst, clk;
	input [ADDR_BITS:0] rptr_enc;
	output wire [ADDR_BITS-1:0] waddr;
	output reg [ADDR_BITS:0] wptr_enc;
	output wire is_full;
	
	//Address as a register
	reg [ADDR_BITS:0] wptr_counter;
	
	//Declare sync registers
	reg [ADDR_BITS:0] rptr_enc_sync1;
	reg [ADDR_BITS:0] rptr_enc_sync2;
	
	//Decoded read pointer
	wire [ADDR_BITS:0] rptr_wire;
	
	//Implement sync registers and address pointer
	always @(posedge clk or negedge rst)
	begin
		if(~rst)
		begin
			rptr_enc_sync1 <= 2'b11<<(ADDR_BITS-1);
			rptr_enc_sync2 <= 2'b11<<(ADDR_BITS-1);
			wptr_enc <= 0;
			wptr_counter <= 0;
		end
		else
		begin
			rptr_enc_sync1 <= rptr_enc;
			rptr_enc_sync2 <= rptr_enc_sync1;
			if(!is_full & wen)
				wptr_counter <= wptr_counter + 1;
			wptr_enc <= wptr_counter ^ (wptr_counter>>1);
		end
	end
	
	//waddr is basically wptr_counter
	assign waddr = wptr_counter;
	
	//Decode rptr
	assign rptr_wire[ADDR_BITS] = rptr_enc_sync2[ADDR_BITS];
	generate
		genvar i;
		for(i = 0; i<ADDR_BITS; i = i+1)
		begin
			assign rptr_wire[i] = rptr_wire[i+1] ^ rptr_enc_sync2[i];
		end
	endgenerate
	
	//Implement is full
	assign is_full = rptr_wire == wptr_counter;

endmodule
module sync_fifo_256to64 #(
  parameter DATA_WIDTH_I  = 256, 
  parameter DATA_WIDTH_O  = 64,
  parameter FIFO_DEPTH    = 8,
  parameter OUTPUT_MODE   = 0 //0: comb output, 1: sque output
  )(
  //Global signals.
  input                           clk,
  input                           rst_n,
  
  //FIFO write.
  input                           fifo_wr,
  input       [DATA_WIDTH_I-1:0]  fifo_din,
  output                          fifo_full,
  //FIFO read.
  input                           fifo_rd,
  output  reg [DATA_WIDTH_O-1:0]  fifo_dout,
  output                          fifo_empty
  );

localparam  ADDR_WIDTH  = $clog2(FIFO_DEPTH);

reg [ADDR_WIDTH-1:0]  rd_ptr;
reg [ADDR_WIDTH-1:0]  wr_ptr;
reg [ADDR_WIDTH:0]    fifo_cnt;

reg [DATA_WIDTH_O-1:0]  buf_mem [0:FIFO_DEPTH-1];

//Write data in FIFO --------------------------------------
integer i;
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    for(i=0; i<FIFO_DEPTH; i=i+1)
      buf_mem[i]  <=  {DATA_WIDTH_O{1'b0}};
  else if(fifo_wr)
    {buf_mem[wr_ptr+3], buf_mem[wr_ptr+2], buf_mem[wr_ptr+1], buf_mem[wr_ptr]} <=  fifo_din;
end

//wr_ptr logic.
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    wr_ptr  <=  'b0;
  else if(fifo_wr)
    wr_ptr  <=  wr_ptr + 'd4;
end

//fifo_full.
assign  fifo_full = (fifo_cnt > 'd4);

//Read data frome FIFO ------------------------------------
generate
  if(OUTPUT_MODE == 0)
    always @(*)
      fifo_dout = buf_mem[rd_ptr];
  else begin
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n)
        fifo_dout <=  'b0;
      else if (fifo_rd)
        fifo_dout <=  buf_mem[rd_ptr];
    end
  end
endgenerate

//rd_ptr logic.
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rd_ptr  <=  'b0;
  else if(fifo_rd)
    rd_ptr  <=  rd_ptr + 1'b1;
end

//fifo_empty and fifo_aempty.
assign  fifo_empty  = (fifo_cnt == 'd0);

//fifo_cnt logic ------------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    fifo_cnt  <=  'd0;
  end else if(fifo_wr & fifo_rd) begin
    fifo_cnt  <=  fifo_cnt + 'd3;
  end else if(fifo_wr) begin
    fifo_cnt  <=  fifo_cnt + 'd4;
  end else if(fifo_rd) begin
    fifo_cnt  <=  fifo_cnt - 'd1;
  end
end

endmodule

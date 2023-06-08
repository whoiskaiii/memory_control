module axi_slv_wchannel #(
  parameter AXI_DATA_WIDTH  = 256,
            AXI_ADDR_WIDTH  = 25
  )(
  //Global signals.
  input                         clk, //400MHz --> 2.5ns
  input                         rst_n,
  //axi_s_aw signals.
  input                         axi_s_awvalid,
  output                        axi_s_awready,
  input   [7:0]                 axi_s_awlen,
  input   [AXI_ADDR_WIDTH-1:0]  axi_s_awaddr,
  //axi_s_w signals.
  input                         axi_s_wvalid,
  output                        axi_s_wready,
  input                         axi_s_wlast,
  input   [AXI_DATA_WIDTH-1:0]  axi_s_wdata,
  //w_frame signals.
  output                        axi2arb_wframe_valid,
  input                         axi2arb_wframe_ready,
  output  [96:0]                axi2arb_wframe_data
  );

//wchannel FSM.
localparam  IDLE  = 1'b0,
            WR    = 1'b1;

//wchannel FSM.
reg           wchannel_cs;
reg           wchannel_ns;
//wchannel frame.
reg   [21:0]  awaddr_reg; //Save the row address and column address of array.
reg   [7:0]   awlen_reg; //Save the len of burst.
wire          wframe_sof;
wire          wframe_eof;
reg           wframe_eof_last;
reg   [10:0]  wframe_cnt;
//wchannel fifo.
wire          wchannel_fifo_wr;
wire          wchannel_fifo_full;
wire          wchannel_fifo_rd;
wire  [63:0]  wchannel_fifo_dout;
wire          wchannel_fifo_empty;

//Handshake.
assign  axi_s_awready         = (wchannel_cs==IDLE);
assign  axi_s_wready          = !wchannel_fifo_full;
assign  axi2arb_wframe_valid  = ((wchannel_cs==WR) && !wchannel_fifo_empty);
assign  axi2arb_wframe_data   = {awlen_reg, wframe_eof, wframe_sof, 1'b1, wchannel_fifo_dout, awaddr_reg};
//FIFO write and read.
assign  wchannel_fifo_wr = (axi_s_wvalid & axi_s_wready);
assign  wchannel_fifo_rd = (axi2arb_wframe_ready & !wchannel_fifo_empty);
//wframe sof and eof.
assign  wframe_sof      = (axi2arb_wframe_valid && ((wframe_cnt==0) || (awaddr_reg[5:0]==0)));
//assign  wframe_eof_last = (wframe_cnt==(awlen_reg+1)*4-1);
assign  wframe_eof      = ((awaddr_reg[5:0]==63) || wframe_eof_last);

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    wframe_eof_last <=  1'b0;
  else if(wframe_cnt==((awlen_reg+1)*4-1))
    wframe_eof_last <=  1'b1;
  else if(wchannel_cs==IDLE)
    wframe_eof_last <=  1'b0;
end

//awaddr_reg
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    awaddr_reg  <=  'd0;
  else if(axi_s_awvalid & axi_s_awready)
    awaddr_reg  <=  axi_s_awaddr[3+:22]; //The lower 3-bit is discarded for address alignment.
  else if(axi2arb_wframe_valid & axi2arb_wframe_ready)
    awaddr_reg  <=  awaddr_reg + 1'b1; //The address is incremented when the handshake with
                                       //the next module is successful
end

//awlen_reg
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    awlen_reg <=  'd0;
  else if(axi_s_awvalid & axi_s_awready)
    awlen_reg <=  axi_s_awlen;
end

//wframe_cnt
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    wframe_cnt  <=  'd0;
  else if(wframe_eof_last)
    wframe_cnt  <=  'd0;
  else if(axi2arb_wframe_valid & axi2arb_wframe_ready)
    wframe_cnt  <=  wframe_cnt + 1;
end

//wchannel FSM --------------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    wchannel_cs <=  IDLE;
  else
    wchannel_cs <=  wchannel_ns;
end

always @(*) begin
  wchannel_ns = IDLE; //Avoid latch.
  case(wchannel_cs)
    IDLE: wchannel_ns = axi_s_awvalid ? WR : IDLE;
    WR:   wchannel_ns = (axi2arb_wframe_valid & axi2arb_wframe_ready & wframe_eof_last) ? IDLE : WR;
  endcase
end

sync_fifo_256to64 #(
  .DATA_WIDTH_I (256),
  .DATA_WIDTH_O (64),
  .FIFO_DEPTH   (8),
  .OUTPUT_MODE  (0)
  ) u_sync_fifo_256to64 (
  .clk        (clk),
  .rst_n      (rst_n),
  .fifo_wr    (wchannel_fifo_wr),
  .fifo_din   (axi_s_wdata),
  .fifo_full  (wchannel_fifo_full),
  .fifo_rd    (wchannel_fifo_rd),
  .fifo_dout  (wchannel_fifo_dout),
  .fifo_empty (wchannel_fifo_empty)
);

endmodule

module axi_slv_rchannel #(
  parameter AXI_DATA_WIDTH  = 256,
            AXI_ADDR_WIDTH  = 25
  )(
  //Global signals.
  input                         clk, //400MHz --> 2.5ns
  input                         rst_n,
  //axi_s_ar signals.
  input                         axi_s_arvalid,
  output                        axi_s_arready,
  input   [7:0]                 axi_s_arlen,
  input   [AXI_ADDR_WIDTH-1:0]  axi_s_araddr,
  //axi_s_r signals.
  output                        axi_s_rvalid,
  output                        axi_s_rlast,
  output  [AXI_DATA_WIDTH-1:0]  axi_s_rdata,
  //r_frame signals.
  output                        axi2arb_rframe_valid,
  input                         axi2arb_rframe_ready,
  output  [96:0]                axi2arb_rframe_data,
  //array_r signals.
  input                         array_rdata_valid,
  input   [63:0]                array_rdata
  );

//rchannel FSM.
localparam  IDLE  = 1'b0,
            RD    = 1'b1;

//rchannel FSM.
reg           rchannel_cs;
reg           rchannel_ns;
//rchannel frame.
reg   [21:0]  araddr_reg; //Save the row address and column address of array.
wire          rframe_sof;
wire          rframe_eof;
reg           rframe_eof_last;
reg   [10:0]  rframe_cnt;
reg   [7:0]   arlen_reg;
//rdata fifo.
wire          rchannel_fifo_wr;
wire          rchannel_fifo_full;
reg           rchannel_fifo_rd;
wire          rchannel_fifo_empty;
reg   [10:0]  rdata_cnt;
//arlen_fifo.
wire          arlen_fifo_wr;
reg           arlen_fifo_rd;
wire          arlen_fifo_empty;
wire          arlen_fifo_full;
wire  [7:0]   arlen_fifo_dout;

//Handshake.
assign  axi_s_arready         = ((rchannel_cs==IDLE) && ~arlen_fifo_full);
assign  axi2arb_rframe_valid  = ((rchannel_cs==RD) && ~arlen_fifo_empty);
assign  axi2arb_rframe_data   = {arlen_fifo_dout, rframe_eof, rframe_sof, 1'b0, 64'd0, araddr_reg};
//arlen fifo.
assign  arlen_fifo_wr = (axi_s_arvalid && axi_s_arready);
//assign  arlen_fifo_rd = (rdata_cnt==((arlen_fifo_dout+1)*4));
//rdata fifo and axi_s_r.
assign  rchannel_fifo_wr  = array_rdata_valid;
//assign  rchannel_fifo_rd  = ((rdata_cnt[1:0]==0) && (|rdata_cnt)); //Multiple of 4.
assign  axi_s_rvalid      = rchannel_fifo_rd;
assign  axi_s_rlast       = arlen_fifo_rd;
//rframe sof and eof.
assign  rframe_sof      = (axi2arb_rframe_valid && ((rframe_cnt==0) || (araddr_reg[5:0]==0)));
//assign  rframe_eof_last = (rframe_cnt==((arlen_reg+1)*4-1));
assign  rframe_eof      = ((araddr_reg[5:0]==63) || rframe_eof_last);

always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    rframe_eof_last <=  1'b0;
  else if(rframe_cnt==((arlen_reg+1)*4-1))
    rframe_eof_last <=  1'b1;
  else if(rchannel_cs==IDLE)
    rframe_eof_last <=  1'b0;
end


//araddr_reg.
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    araddr_reg  <=  'd0;
  else if(axi_s_arvalid & axi_s_arready)
    araddr_reg  <=  axi_s_araddr[3+:22]; //The lower 3-bit is discarded for address alignment.
  else if(axi2arb_rframe_valid & axi2arb_rframe_ready)
    araddr_reg  <=  araddr_reg + 1'b1; //The address is incremented when the handshake with
                                       //the next module is successful
end

//wframe_cnt
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rframe_cnt  <=  'd0;
  else if(rframe_eof_last)
    rframe_cnt  <=  'd0;
  else if(axi2arb_rframe_valid & axi2arb_rframe_ready)
    rframe_cnt  <=  rframe_cnt + 1;
end

//rdata_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    rdata_cnt <=  'd0;
  else if(arlen_fifo_rd)
    rdata_cnt <=  'd0;
  else if(array_rdata_valid)
    rdata_cnt <=  rdata_cnt + 1'b1;
end

//rchannel_fifo_rd
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    rchannel_fifo_rd  <=  1'b0;
  else if(rchannel_fifo_rd)
    rchannel_fifo_rd  <=  1'b0;
  else if((rdata_cnt[1:0]==0) && (|rdata_cnt)) //Multiple of 4.
    rchannel_fifo_rd  <=  1'b1;
end

//arlen_reg
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    arlen_reg <=  'd0;
  else if(axi_s_arvalid & axi_s_arready)
    arlen_reg <=  axi_s_arlen;
end

//arlen_fifo_rd
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    arlen_fifo_rd <=  'd0;
  else if(arlen_fifo_rd)
    arlen_fifo_rd <=  'd0;
  else if(rdata_cnt==((arlen_fifo_dout+1)*4))
    arlen_fifo_rd <=  'd1;
end

//rchannel FSM --------------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rchannel_cs <=  IDLE;
  else
    rchannel_cs <=  rchannel_ns;
end

always @(*) begin
  rchannel_ns = IDLE; //Avoid latch.
  case(rchannel_cs)
    IDLE: rchannel_ns = axi_s_arvalid ? RD : IDLE;
    RD:   rchannel_ns = (axi2arb_rframe_valid & axi2arb_rframe_ready & rframe_eof_last) ? IDLE : RD;
  endcase
end

//arlen_fifo
DW_fifo_s1_sf #(
  .width(8),
  .depth(2)
  ) u_arlen_fifo (
  .clk          (clk),
  .rst_n        (rst_n),
  .push_req_n   (~arlen_fifo_wr),
  .pop_req_n    (~arlen_fifo_rd),
  .diag_n       (1'b1),
  .data_in      (axi_s_arlen),
  .empty        (arlen_fifo_empty),
  .almost_empty (),
  .half_full    (),
  .almost_full  (),
  .full         (arlen_fifo_full),
  .error        (),
  .data_out     (arlen_fifo_dout)
);

//rdata fifo
sync_fifo_64to256 #(
  .DATA_WIDTH_I (64),
  .DATA_WIDTH_O (256),
  .FIFO_DEPTH   (8),
  .OUTPUT_MODE  (0)
  ) u_sync_fifo_64to256 (
  .clk        (clk),
  .rst_n      (rst_n),
  .fifo_wr    (rchannel_fifo_wr),
  .fifo_din   (array_rdata),
  .fifo_full  (rchannel_fifo_full),
  .fifo_rd    (rchannel_fifo_rd),
  .fifo_dout  (axi_s_rdata),
  .fifo_empty (rchannel_fifo_empty)
);

endmodule

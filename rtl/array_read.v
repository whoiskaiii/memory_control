module array_read #(
  parameter ARRAY_COL_ADDR_WIDTH    = 6,
            ARRAY_ROW_ADDR_WIDTH    = 16,
            ARRAY_DATA_WIDTH        = 64,
            ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      ARRAY_DATA_WIDTH //3 is rw_flag, sof and eof.
  )(
  //Global.
  input                                     clk,
  input                                     rst_n,
  //array_read frame.
  input                                     array_rframe_valid,
  input       [ARRAY_FRAME_DATA_WIDTH-1:0]  array_rframe_data,
  output                                    array_rframe_ready,
  input                                     array_rd_start,
  output                                    array_rd_done,
  //Timing config.
  input       [7:0]                         array_tRCD_RD,
  input       [7:0]                         array_tRAS,
  input       [7:0]                         array_tRTP,
  input       [7:0]                         array_tRP,
  //array_interface.
  output  reg                               array_cs_n,
  output      [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr,
  output  reg                               array_caddr_vld_rd,
  output      [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_rd,
  input                                     array_rdata_vld,
  input       [ARRAY_DATA_WIDTH-1:0]        array_rdata,
  //sync_array_r.
  output                                    sync_array_rdata_vld,
  output      [ARRAY_DATA_WIDTH-1:0]        sync_array_rdata
  );

reg [7:0] timing_cnt;
reg [7:0] tras_cnt;

wire  array_rdata_fifo_full;
wire  array_rdata_fifo_empty;
wire  array_rdata_fifo_pop;

localparam  IDLE    = 3'd0,
            TSADDR  = 3'd1,
            TRCD_RD = 3'd2,
            RD      = 3'd3,
            RD_LAST = 3'd4,
            TRTP    = 3'd5,
            PRE_TRP = 3'd6,
            TRP     = 3'd7;

reg [2:0] array_rd_cs;
reg [2:0] array_rd_ns;

//array_read FSM -----------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_rd_cs <=  'd0;
  else
    array_rd_cs <=  array_rd_ns;
end

always @(*) begin
  array_rd_ns = IDLE;
  case(array_rd_cs)
    IDLE: 
      array_rd_ns = array_rd_start ? TSADDR : IDLE;
    TSADDR:
      array_rd_ns = TRCD_RD;
    TRCD_RD: begin
      if(timing_cnt=='d0) begin
        if(array_rframe_data[88:87]==2'd3) //[87]: sof, [88]: eof.
          array_rd_ns = RD_LAST; //read single data.
        else
          array_rd_ns = RD;
      end else
        array_rd_ns = TRCD_RD;
    end
    RD: begin
      if(array_rframe_data[88]) //eof
        array_rd_ns = RD_LAST;
      else
        array_rd_ns = RD;
    end
    RD_LAST:
      array_rd_ns = TRTP;
    TRTP: begin
      if(timing_cnt=='d0 && tras_cnt=='d0)
        array_rd_ns = PRE_TRP;
      else
        array_rd_ns = TRTP;
    end
    PRE_TRP:
      array_rd_ns = TRP;
    TRP: begin
      if(timing_cnt=='d0)
        array_rd_ns = IDLE;
      else
        array_rd_ns = TRP;
    end
  endcase
end

//array_rframe --------------------------------------------
assign  array_rframe_ready  = (array_rd_cs==RD && ~array_caddr_vld_rd) ||
                              (array_rd_cs==RD_LAST && ~array_caddr_vld_rd);
                              //(array_rd_cs==IDLE)

//array_interface -----------------------------------------
//array_raddr.
assign  array_raddr = ((array_rd_cs==TSADDR) || (array_rd_cs==TRCD_RD) ||
                      (array_rd_cs==RD) || (array_rd_cs==RD_LAST)) ?
                      array_rframe_data[21:6] : 'd0;
//array_caddr_wr
assign  array_caddr_rd  = ((array_rd_cs==RD) || (array_rd_cs==RD_LAST)) ?
                          array_rframe_data[5:0] : 'd0;

//timing_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    timing_cnt  <=  'd0;
  else if(array_rd_cs==TSADDR)
    timing_cnt  <=  array_tRCD_RD - 1'b1;
  else if(array_rd_cs==RD_LAST)
    timing_cnt  <=  array_tRTP - 1'b1;
  else if(array_rd_cs==PRE_TRP)
    timing_cnt  <=  array_tRP - 'd2;
  else if(timing_cnt=='d0)
    timing_cnt  <=  'd0;
  else
    timing_cnt  <=  timing_cnt - 1'b1;
end
//array_cs_n
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_cs_n  <=  'b1;
  else if(array_rd_cs==TSADDR)
    array_cs_n  <=  'b0;
  else if(array_rd_cs==TRTP && timing_cnt=='d0)
    array_cs_n  <=  'b1;
end
//array_caddr_vld_rd
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_caddr_vld_rd  <=  'd0;
  else if(array_rd_cs==TRCD_RD && timing_cnt=='d0)
    array_caddr_vld_rd  <=  'd1;
  else if(array_rd_cs==RD)
    array_caddr_vld_rd  <=  ~array_caddr_vld_rd;
end
//tras_cnt
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    tras_cnt  <=  'd0;
  else if(array_rd_cs==TSADDR)
    tras_cnt  <=  array_tRAS - 1'b1;
  else if(tras_cnt=='d0)
    tras_cnt  <=  tras_cnt;
  else
    tras_cnt  <=  tras_cnt - 1'b1;
end

//array_wr_done
assign  array_rd_done = (array_rd_cs==TRP) && (timing_cnt=='d0);

//array_rdata_fifo_pop
assign  array_rdata_fifo_pop  = ~array_rdata_fifo_empty;
//array_rdata_vld
assign  sync_array_rdata_vld  = array_rdata_fifo_pop;

//rdata through async_fifo.
DW_fifo_s2_sf #(
  .width(64),
  .depth(8)
  ) u_DW_fifo_s2_sf (
  .clk_push   (array_rdata_vld),
  .clk_pop    (clk),
  .rst_n      (rst_n),
  .push_req_n (1'b0),
  .pop_req_n  (~array_rdata_fifo_pop),
  .data_in    (array_rdata),
  .push_empty (),
  .push_ae    (),
  .push_hf    (),
  .push_af    (),
  .push_full  (array_rdata_fifo_full),
  .push_error (),
  .pop_empty  (array_rdata_fifo_empty),
  .pop_ae     (),
  .pop_hf     (),
  .pop_af     (),
  .pop_full   (),
  .pop_error  (),
  .data_out   (sync_array_rdata)
  );

endmodule

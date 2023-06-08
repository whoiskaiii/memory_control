module array_write #(
  parameter ARRAY_COL_ADDR_WIDTH    = 6,
            ARRAY_ROW_ADDR_WIDTH    = 16,
            ARRAY_DATA_WIDTH        = 64,
            ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      ARRAY_DATA_WIDTH //3 is rw_flag, sof and eof.
  )(
  //Global.
  input                                     clk,
  input                                     rst_n,
  //array_write frame.
  input                                     array_wframe_valid,
  input       [ARRAY_FRAME_DATA_WIDTH-1:0]  array_wframe_data,
  output                                    array_wframe_ready,
  input                                     array_wr_start,
  output                                    array_wr_done,
  //Timing config.
  input       [7:0]                         array_tRCD_WR,
  input       [7:0]                         array_tRAS,
  input       [7:0]                         array_tWR,
  input       [7:0]                         array_tRP,
  //array_interface.
  output  reg                               array_cs_n,
  output      [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr,
  output  reg                               array_caddr_vld_wr,
  output      [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_wr,
  output                                    array_wdata_vld,
  output      [ARRAY_DATA_WIDTH-1:0]        array_wdata
  );

reg [7:0] timing_cnt;
reg [7:0] tras_cnt;

localparam  IDLE    = 3'd0,
            TSADDR  = 3'd1,
            TRCD_WR = 3'd2,
            WR      = 3'd3,
            WR_LAST = 3'd4,
            TWR     = 3'd5,
            PRE_TRP = 3'd6,
            TRP     = 3'd7;

reg [2:0] array_wr_cs;
reg [2:0] array_wr_ns;

//array_write FSM -----------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_wr_cs <=  'd0;
  else
    array_wr_cs <=  array_wr_ns;
end

always @(*) begin
  array_wr_ns = IDLE;
  case(array_wr_cs)
    IDLE: 
      array_wr_ns = array_wr_start ? TSADDR : IDLE;
    TSADDR:
      array_wr_ns = TRCD_WR;
    TRCD_WR: begin
      if(timing_cnt=='d0) begin
        if(array_wframe_data[88:87]==2'd3) //[87]: sof, [88]: eof.
          array_wr_ns = WR_LAST; //write single data.
        else
          array_wr_ns = WR;
      end else
        array_wr_ns = TRCD_WR;
    end
    WR: begin
      if(array_wframe_data[88]) //eof
        array_wr_ns = WR_LAST;
      else
        array_wr_ns = WR;
    end
    WR_LAST:
      array_wr_ns = TWR;
    TWR: begin
      if(timing_cnt=='d0 && tras_cnt=='d0)
        array_wr_ns = PRE_TRP;
      else
        array_wr_ns = TWR;
    end
    PRE_TRP:
      array_wr_ns = TRP;
    TRP: begin
      if(timing_cnt=='d0)
        array_wr_ns = IDLE;
      else
        array_wr_ns = TRP;
    end
  endcase
end

//array_wframe --------------------------------------------
assign  array_wframe_ready  = (array_wr_cs==WR && ~array_caddr_vld_wr) ||
                              (array_wr_cs==WR_LAST && ~array_caddr_vld_wr);
                              //(array_wr_cs==IDLE)

//array_interface -----------------------------------------
//array_raddr.
assign  array_raddr = ((array_wr_cs==TSADDR) || (array_wr_cs==TRCD_WR) ||
                      (array_wr_cs==WR) || (array_wr_cs==WR_LAST)) ?
                      array_wframe_data[21:6] : 'd0;
//array_caddr_wr
assign  array_caddr_wr  = ((array_wr_cs==WR) || (array_wr_cs==WR_LAST)) ?
                          array_wframe_data[5:0] : 'd0;

//timing_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    timing_cnt  <=  'd0;
  else if(array_wr_cs==TSADDR)
    timing_cnt  <=  array_tRCD_WR - 1'b1;
  else if(array_wr_cs==WR_LAST)
    timing_cnt  <=  array_tWR - 1'b1;
  else if(array_wr_cs==PRE_TRP)
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
  else if(array_wr_cs==TSADDR)
    array_cs_n  <=  'b0;
  else if(array_wr_cs==TWR && timing_cnt=='d0)
    array_cs_n  <=  'b1;
end
//array_caddr_vld_wr
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_caddr_vld_wr  <=  'd0;
  else if(array_wr_cs==TRCD_WR && timing_cnt=='d0)
    array_caddr_vld_wr  <=  'd1;
  else if(array_wr_cs==WR)
    array_caddr_vld_wr  <=  ~array_caddr_vld_wr;
end
//array_wdata_vld
assign  array_wdata_vld = ~array_caddr_vld_wr;
//array_wdata
assign  array_wdata = ((array_wr_cs==WR) || (array_wr_cs==WR_LAST)) ? 
                      array_wframe_data[85:22] : 'd0;
//tras_cnt
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    tras_cnt  <=  'd0;
  else if(array_wr_cs==TSADDR)
    tras_cnt  <=  array_tRAS - 1'b1;
  else if(tras_cnt=='d0)
    tras_cnt  <=  tras_cnt;
  else
    tras_cnt  <=  tras_cnt - 1'b1;
end

//array_wr_done
assign  array_wr_done = (array_wr_cs==TRP) && (timing_cnt=='d0);
endmodule

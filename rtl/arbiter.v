module arbiter #(
  parameter ARRAY_COL_ADDR_WIDTH    = 6,
            ARRAY_ROW_ADDR_WIDTH    = 16,
            ARRAY_DATA_WIDTH        = 64,
            AXI_LEN_WIDTH           = 8,
            FRAME_DATA_WIDTH        = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      AXI_LEN_WIDTH + ARRAY_DATA_WIDTH, //3 is rw_flag, sof and eof.
            ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      ARRAY_DATA_WIDTH //3 is rw_flag, sof and eof.
  )(
  //Global signals.
  input                                 clk,
  input                                 rst_n,
  //mc enalbe.
  input                                 mc_en,
  //w_frame signals.
  input                                 axi2arb_wframe_valid,
  output                                axi2arb_wframe_ready,
  input   [FRAME_DATA_WIDTH-1:0]        axi2arb_wframe_data,
  //r_frame signals.
  input                                 axi2arb_rframe_valid,
  output                                axi2arb_rframe_ready,
  input   [FRAME_DATA_WIDTH-1:0]        axi2arb_rframe_data,
  //internal_frame signals.
  output                                axi2array_frame_valid,
  input                                 axi2array_frame_ready,
  output  [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data,
  //aix bus read and write priority.
  input   [1:0]                         axi_rw_prio
  );

localparam  IDLE  = 2'd0,
            WR    = 2'd1,
            RD    = 2'd2;

reg [1:0]               arbiter_cs;
reg [1:0]               arbiter_ns;
reg                     cur_axi_rw_prio; //0: RD; 1: WR.
reg [AXI_LEN_WIDTH-1:0] frame_cnt; //frame data cnt.
reg [7:0]               len_reg;
wire                    wframe_eof;
wire                    rframe_eof;

//axi2arb frame handshake.
assign  axi2arb_wframe_ready  = (arbiter_cs==WR) && axi2array_frame_ready;
assign  axi2arb_rframe_ready  = (arbiter_cs==RD) && axi2array_frame_ready;
//axi2array frame handshake.
assign  axi2array_frame_valid = ((arbiter_cs==WR) && axi2arb_wframe_valid) ||
                                ((arbiter_cs==RD) && axi2arb_rframe_valid);
//axi2array_frame_data.
assign  axi2array_frame_data  = (arbiter_cs==WR) ? axi2arb_wframe_data[88:0] :
                                (arbiter_cs==RD) ? axi2arb_rframe_data[88:0] : 'd0;
//wframe_eof and rframe_eof.
assign  wframe_eof  = axi2arb_wframe_data[88];
assign  rframe_eof  = axi2arb_rframe_data[88];

//Current rw priority switching.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    cur_axi_rw_prio <=  'd0;
  else if((arbiter_cs==IDLE) && ({axi2arb_wframe_valid, axi2arb_rframe_valid}==2'b11))
    cur_axi_rw_prio <=  ~cur_axi_rw_prio;
end

//read or write len_reg
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    len_reg <=  'd0;
  else if(axi2arb_wframe_valid && axi2arb_wframe_ready)
    len_reg <=  axi2arb_wframe_data[96:89];
  else if(axi2arb_rframe_valid && axi2arb_rframe_ready)
    len_reg <=  axi2arb_rframe_data[96:89];
end

//frame_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    frame_cnt <=  'd0;
  else if(frame_cnt==(len_reg+1)*4)
    frame_cnt <=  'd0;
  else if(axi2array_frame_valid && axi2array_frame_ready)
    frame_cnt <=  frame_cnt + 1;
end

//arbiter FSM.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    arbiter_cs  <=  1'b0;
  else
    arbiter_cs  <=  arbiter_ns;
end

always @(*) begin
  arbiter_ns  = IDLE; //Aviod latch.
  case(arbiter_cs)
    IDLE: begin
      case({axi2arb_wframe_valid, axi2arb_rframe_valid})
        2'b00:  arbiter_ns  = IDLE;
        2'b01:  arbiter_ns  = RD;
        2'b10:  arbiter_ns  = WR;
        2'b11:  begin //Read and write requests arrive at the same time, so arbitration is required.
          case(axi_rw_prio)
            2'b00:  arbiter_ns  = RD;
            2'b01:  arbiter_ns  = WR;
            2'b10:  arbiter_ns  = cur_axi_rw_prio ? WR : RD;
            2'b11:  arbiter_ns  = WR;
          endcase
        end
      endcase
    end
    WR: begin
      if(axi2array_frame_valid && axi2array_frame_ready && wframe_eof && (frame_cnt==((len_reg+1)*4-1)))
        arbiter_ns  = IDLE;
      else
        arbiter_ns  = WR;
    end
    RD: begin
      if(axi2array_frame_valid && axi2array_frame_ready && rframe_eof && (frame_cnt==((len_reg+1)*4-1)))
        arbiter_ns  = IDLE;
      else
        arbiter_ns  = RD;
    end
  endcase
end

endmodule

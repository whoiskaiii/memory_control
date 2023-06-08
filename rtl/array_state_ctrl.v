module array_state_ctrl #(
  parameter ARRAY_COL_ADDR_WIDTH    = 6,
            ARRAY_ROW_ADDR_WIDTH    = 16,
            ARRAY_DATA_WIDTH        = 64,
            ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      ARRAY_DATA_WIDTH //3 is rw_flag, sof and eof.
  )(
  //Global.
  input                                     clk,
  input                                     rst_n,
  //mc enalbe.
  input                                     mc_en,
  //internal_frame.
  input                                     axi2array_frame_valid,
  input       [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data,
  output                                    axi2array_frame_ready,
  //array_write frame.
  output                                    array_wframe_valid,
  output      [ARRAY_FRAME_DATA_WIDTH-1:0]  array_wframe_data,
  input                                     array_wframe_ready,
  output                                    array_wr_start,
  input                                     array_wr_done,
  //array_read frame.
  output                                    array_rframe_valid,
  output      [ARRAY_FRAME_DATA_WIDTH-1:0]  array_rframe_data,
  input                                     array_rframe_ready,
  output                                    array_rd_start,
  input                                     array_rd_done,
  //array_refresh.
  input                                     array_rf_period_sel,
  input       [24:0]                        array_rf_period_0,
  input       [24:0]                        array_rf_period_1,
  output  reg                               array_rf_start,
  input                                     array_rf_done,
  //array_mux_sel.
  output      [1:0]                         array_mux_sel
  );

localparam  IDLE      = 2'd0,
            ARRAY_WR  = 2'd1,
            ARRAY_RD  = 2'd2,
            ARRAY_RF  = 2'd3;

reg [1:0] array_state_ctrl_cs;
reg [1:0] array_state_ctrl_ns;

wire  [24:0]  array_rf_period; //Select array_rf_period0/1.
reg   [24:0]  array_rf_cnt;

//internal_frame ------------------------------------------
assign  axi2array_frame_ready = ((array_state_ctrl_cs==ARRAY_WR) && array_wframe_ready) ||
                                ((array_state_ctrl_cs==ARRAY_RD) && array_rframe_ready);

//array_wframe --------------------------------------------
assign  array_wframe_valid  = (array_state_ctrl_cs==ARRAY_WR) && axi2array_frame_valid;
assign  array_wframe_data   = (array_state_ctrl_cs==ARRAY_WR) ?
                              axi2array_frame_data : 'd0;
//array_wr_start, [86]: r/w flag, [87]: sof.
assign  array_wr_start      = axi2array_frame_valid &&
                              axi2array_frame_data[86] && axi2array_frame_data[87];

//array_wframe --------------------------------------------
assign  array_rframe_valid  = (array_state_ctrl_cs==ARRAY_RD) && axi2array_frame_valid;
assign  array_rframe_data   = (array_state_ctrl_cs==ARRAY_RD) ?
                              axi2array_frame_data : 'd0;
//array_rd_start, [86]: r/w flag, [87]: sof.
assign  array_rd_start      = axi2array_frame_valid &&
                              (~axi2array_frame_data[86]) && axi2array_frame_data[87];

//array_rf ------------------------------------------------
//array_rf_period_sel.
assign  array_rf_period = array_rf_period_sel ? array_rf_period_0 : array_rf_period_1;
//array_rf_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_rf_cnt  <=  'd0;
  else if(~mc_en)
    array_rf_cnt  <=  'd0;
  else if(array_rf_cnt>=array_rf_period)
    array_rf_cnt  <=  'd0;
  else
    array_rf_cnt  <=  array_rf_cnt + 1'b1;
end
//array_rf_start.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_rf_start  <=  1'b0;
  else if(~mc_en)
    array_rf_cnt    <=  1'd0;
  else if(array_rf_cnt>=array_rf_period)
    array_rf_start  <=  1'b1;
  else if(array_state_ctrl_cs==ARRAY_RF)
    array_rf_start  <=  1'b0;
end

//array_state_ctrl FSM ------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_state_ctrl_cs <=  'd0;
  else
    array_state_ctrl_cs <=  array_state_ctrl_ns;
end

always @(*) begin
  array_state_ctrl_ns = IDLE;
  case(array_state_ctrl_cs)
    IDLE: begin
      if(mc_en) begin
        if(array_rf_start)
          array_state_ctrl_ns = ARRAY_RF;
        else if(array_wr_start)
          array_state_ctrl_ns = ARRAY_WR;
        else if(array_rd_start)
          array_state_ctrl_ns = ARRAY_RD;
      end else
        array_state_ctrl_ns = IDLE;
    end
    ARRAY_WR: array_state_ctrl_ns = array_wr_done ? IDLE : ARRAY_WR;
    ARRAY_RD: array_state_ctrl_ns = array_rd_done ? IDLE : ARRAY_RD;
    ARRAY_RF: array_state_ctrl_ns = array_rf_done ? IDLE : ARRAY_RF;
  endcase
end

assign  array_mux_sel = array_state_ctrl_cs;

endmodule

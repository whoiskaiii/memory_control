module array_refresh #(
  parameter ARRAY_ROW_ADDR_WIDTH  = 16
  )(
  //Global.
  input                                     clk,
  input                                     rst_n,
  //array_refresh.
  input                                     array_rf_start,
  output                                    array_rf_done,
  //Timing config.
  input       [7:0]                         array_tRAS,
  input       [7:0]                         array_tRP,
  //array_interface.
  output  reg                               array_cs_n,
  output      [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr
  );

reg [7:0]                       timing_cnt;
reg [7:0]                       tras_cnt;
reg [2:0]                       rf_row_cnt;
//reg [ARRAY_ROW_ADDR_WIDTH-1:0]  rf_row_cnt;

localparam  IDLE    = 3'd0,
            TSADDR  = 3'd1,
            TRAS    = 3'd2,
            PRE_TRP = 3'd3,
            TRP     = 3'd4;

reg [2:0] array_rf_cs;
reg [2:0] array_rf_ns;

//array_refresh FSM -----------------------------------------
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_rf_cs <=  'd0;
  else
    array_rf_cs <=  array_rf_ns;
end

always @(*) begin
  array_rf_ns = IDLE;
  case(array_rf_cs)
    IDLE:
      array_rf_ns = array_rf_start ? TSADDR : IDLE;
    TSADDR:
      array_rf_ns = TRAS;
    TRAS: begin
      if(tras_cnt=='d0)
        array_rf_ns = PRE_TRP;
      else
        array_rf_ns = TRAS;
    end
    PRE_TRP:
      array_rf_ns = TRP;
    TRP: begin
      if(timing_cnt=='d0) begin
        if(rf_row_cnt=='d0)
          array_rf_ns = IDLE;
        else
          array_rf_ns = TSADDR;
      end else
        array_rf_ns = TRP;
    end
  endcase
end

//array_cs_n
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    array_cs_n  <=  'b1;
  else if(array_rf_cs==TSADDR)
    array_cs_n  <=  'b0;
  else if(array_rf_cs==TRAS && tras_cnt=='d0)
    array_cs_n  <=  'b1;
end

//tras_cnt
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    tras_cnt  <=  'd0;
  else if(array_rf_cs==TSADDR)
    tras_cnt  <=  array_tRAS - 1'b1;
  else if(tras_cnt=='d0)
    tras_cnt  <=  tras_cnt;
  else
    tras_cnt  <=  tras_cnt - 1'b1;
end

//timing_cnt.
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    timing_cnt  <=  'd0;
  else if(array_rf_cs==PRE_TRP)
    timing_cnt  <=  array_tRP - 'd2;
  else if(timing_cnt=='d0)
    timing_cnt  <=  'd0;
  else
    timing_cnt  <=  timing_cnt - 1'b1;
end

//rf_row_cnt
always @(posedge clk or negedge rst_n) begin
  if(~rst_n)
    rf_row_cnt  <=  'b0;
  else if(array_rf_cs==PRE_TRP)
    rf_row_cnt  <=  rf_row_cnt + 1'b1;
end

//array_rf_done
assign  array_rf_done = (array_rf_cs==TRP) && (timing_cnt=='d0) &&
                        (rf_row_cnt=='d0);

//array_raddr
assign  array_raddr = rf_row_cnt;

endmodule

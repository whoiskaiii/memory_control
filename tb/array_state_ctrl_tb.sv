module array_state_ctrl_tb();
parameter ARRAY_COL_ADDR_WIDTH    = 6,
          ARRAY_ROW_ADDR_WIDTH    = 16,
          ARRAY_DATA_WIDTH        = 64,
          ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    ARRAY_DATA_WIDTH, //3 is rw_flag, sof and eof.
          CLK_CYC                 = 2.5;
//Global.
reg                                 clk;
reg                                 rst_n;
//mc enalbe.
reg                                 mc_en;
//internal_frame.
reg                                 axi2array_frame_valid;
reg   [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data;
wire                                axi2array_frame_ready;
//array_write frame.
wire                                array_wframe_valid;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  array_wframe_data;
reg                                 array_wframe_ready;
wire                                array_wr_start;
reg                                 array_wr_done;
//array_read frame.
wire                                array_rframe_valid;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  array_rframe_data;
reg                                 array_rframe_ready;
wire                                array_rd_start;
reg                                 array_rd_done;
//array_refresh.
reg                                 array_rf_period_sel;
reg   [24:0]                        array_rf_period_0;
reg   [24:0]                        array_rf_period_1;
wire                                array_rf_start;
reg                                 array_rf_done;

//task send_wframe ----------------------------------------
integer wframe_cnt;
task send_wframe;
  input [7:0] frame_len;
  begin
    for(wframe_cnt=0; wframe_cnt<((frame_len+1)*4); wframe_cnt=wframe_cnt+1) begin
      if(wframe_cnt==0) begin //1st frame.
        @(posedge clk) begin 
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  wframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd1; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b1; //Write flag.
          axi2array_frame_data[87]    <=  1'b1; //sof.
          axi2array_frame_data[88]    <=  1'b0; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end else if (wframe_cnt==((frame_len+1)*4)-1) begin //Last frame.
        @(posedge clk) begin
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  wframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd1; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b1; //Write flag.
          axi2array_frame_data[87]    <=  1'b0; //sof.
          axi2array_frame_data[88]    <=  1'b1; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end else begin //Other frame.
        @(posedge clk) begin
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  wframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd1; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b1; //Write flag.
          axi2array_frame_data[87]    <=  1'b0; //sof.
          axi2array_frame_data[88]    <=  1'b0; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end
      #1;
      wait(axi2array_frame_ready);
    end
    @(posedge clk) begin
      axi2array_frame_valid <=  1'b0;
    end
    repeat(3) @(posedge clk);
    array_wr_done <=  1'b1;
    @(posedge clk);
    array_wr_done <=  1'b0;
  end
endtask

//task send_rframe ----------------------------------------
integer rframe_cnt;
task send_rframe;
  input [7:0] frame_len;
  begin
    for(rframe_cnt=0; rframe_cnt<((frame_len+1)*4); rframe_cnt=rframe_cnt+1) begin
      if(rframe_cnt==0) begin //1st frame.
        @(posedge clk) begin 
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  rframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd0; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b0; //Read flag.
          axi2array_frame_data[87]    <=  1'b1; //sof.
          axi2array_frame_data[88]    <=  1'b0; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end else if (rframe_cnt==((frame_len+1)*4)-1) begin //Last frame.
        @(posedge clk) begin
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  rframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd0; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b0; //Read flag.
          axi2array_frame_data[87]    <=  1'b0; //sof.
          axi2array_frame_data[88]    <=  1'b1; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end else begin //Other frame.
        @(posedge clk) begin
          //axi2array_frame_data.
          axi2array_frame_data[21:0]  <=  rframe_cnt[21:0]; //[5:0]: caddr, [21:6] raddr.
          axi2array_frame_data[85:22] <=  64'd0; //[85:22]: data.
          axi2array_frame_data[86]    <=  1'b0; //Read flag.
          axi2array_frame_data[87]    <=  1'b0; //sof.
          axi2array_frame_data[88]    <=  1'b0; //eof.
          //axi2array_frame_valid.
          axi2array_frame_valid       <=  1'b1;
        end
      end
    #1;
    wait(axi2array_frame_ready);
    end
    @(posedge clk) begin
      axi2array_frame_valid <=  1'b0;
    end
    repeat(3) @(posedge clk);
    array_rd_done <=  1'b1;
    @(posedge clk);
    array_rd_done <=  1'b0;
  end
endtask

//Generate clk.
initial begin
  #0;
  clk = 1'b0;
  forever #(CLK_CYC)  clk = ~clk;
end

//ready
initial begin
  wait(mc_en);
  forever @(posedge clk) begin
    array_wframe_ready  <=  ~array_wframe_ready;
    array_rframe_ready  <=  ~array_rframe_ready;
  end
end

initial begin
  //Global.
  rst_n                 = 0;
  //mc enalbe.
  mc_en                 = 0;
  //internal_frame.       
  axi2array_frame_valid = 0;
  axi2array_frame_data  = 0;
  //array_write frame.    
  array_wframe_ready    = 0;
  array_wr_done         = 0;
  //array_read frame.     
  array_rframe_ready    = 0;
  array_rd_done         = 0;
  //array_refresh.        
  array_rf_period_sel   = 0;
  array_rf_period_0     = 0;
  array_rf_period_1     = 0;
  array_rf_done         = 0;

  //rst_n
  repeat(3) @(posedge clk);
  rst_n = 1;

  //array_rf_period
  repeat(3) @(posedge clk);
  array_rf_period_0   = 'd20;
  array_rf_period_1   = 'd16;
  //array_rf_period switching.
  repeat(3) @(posedge clk);
  array_rf_period_sel = 1;

  //mc_en
  repeat(3) @(posedge clk);
  mc_en = 1;

  fork
    begin //Fork 1: send wframe and rframe.
      //send wframe ---------------------------------------
      repeat(3) @(posedge clk);
      send_wframe(1); //(frame_len)
        
      //send rframe ---------------------------------------
      repeat(3) @(posedge clk);
      send_rframe(2); //(frame_len)
    end
    begin //Fork 2: array_rf_done
      //array_rf_done -----------------------------------
      @(negedge array_rf_start);
      repeat(10) @(posedge clk);
      array_rf_done <=  1'b1;
      @(posedge clk);
      array_rf_done <=  1'b0;
      
      @(negedge array_rf_start);
      repeat(10) @(posedge clk);
      array_rf_done <=  1'b1;
      @(posedge clk);
      array_rf_done <=  1'b0;
    end
  join

  repeat(20) @(posedge clk);
  $finish();
end

initial begin
  #10_000;
  $finish();
end

array_state_ctrl u_array_state_ctrl (
  //Global.
  .clk                  (clk),
  .rst_n                (rst_n),
  //mc enalbe.                                  
  .mc_en                (mc_en),
  //internal_frame.                             
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_data (axi2array_frame_data),
  .axi2array_frame_ready(axi2array_frame_ready),
  //array_write frame.                          
  .array_wframe_valid   (array_wframe_valid),
  .array_wframe_data    (array_wframe_data),
  .array_wframe_ready   (array_wframe_ready),
  .array_wr_start       (array_wr_start),
  .array_wr_done        (array_wr_done),
  //array_read frame.                           
  .array_rframe_valid   (array_rframe_valid),
  .array_rframe_data    (array_rframe_data),
  .array_rframe_ready   (array_rframe_ready),
  .array_rd_start       (array_rd_start),
  .array_rd_done        (array_rd_done),
  //array_refresh.                              
  .array_rf_period_sel  (array_rf_period_sel),
  .array_rf_period_0    (array_rf_period_0),
  .array_rf_period_1    (array_rf_period_1),
  .array_rf_start       (array_rf_start),
  .array_rf_done        (array_rf_done)
  );

endmodule

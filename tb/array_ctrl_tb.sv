module array_ctrl_tb();
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
//array_refresh.
reg                                 array_rf_period_sel;
reg   [24:0]                        array_rf_period_0;
reg   [24:0]                        array_rf_period_1;
//Timing config.
reg   [7:0]                         array_tRCD_WR;
reg   [7:0]                         array_tRAS;
reg   [7:0]                         array_tWR;
reg   [7:0]                         array_tRP;
reg   [7:0]                         array_tRCD_RD;
reg   [7:0]                         array_tRTP;
//array_interface.
wire                                array_cs_n;
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr;
wire                                array_caddr_vld_wr;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_wr;
wire                                array_caddr_vld_rd;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_rd;
wire                                array_wdata_vld;
wire  [ARRAY_DATA_WIDTH-1:0]        array_wdata;
//array_rdata.
reg                                 array_rdata_vld;
reg   [ARRAY_DATA_WIDTH-1:0]        array_rdata;
//sync_array_r.
wire                                sync_array_rdata_vld;
wire  [ARRAY_DATA_WIDTH-1:0]        sync_array_rdata;

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
  end
endtask

//task gen_rdata
integer rdata_cnt;
task gen_rdata;
  input [7:0] mum_rdata;
  begin
    for(rdata_cnt=0; rdata_cnt<mum_rdata; rdata_cnt=rdata_cnt+1) begin
      @(posedge clk) begin
        //rdata.
        array_rdata     <=  {{$random}, {$random}};
        //rdata_valid.
        array_rdata_vld <=  1'b0;
      end
      @(posedge clk) begin
        array_rdata_vld <=  1'b1;
      end
    end
  end
endtask

//Generate clk.
initial begin
  #0;
  clk = 1'b0;
  forever #(CLK_CYC)  clk = ~clk;
end

initial begin
  //Global.
  rst_n                 = 0;
  //mc enalbe.
  mc_en                 = 0;
  //internal_frame.       
  axi2array_frame_valid = 0;
  axi2array_frame_data  = 0;
  //array_refresh.        
  array_rf_period_sel   = 0;
  array_rf_period_0     = 0;
  array_rf_period_1     = 0;
  //Timing config.
  array_tRCD_WR       = 8'h7;
  array_tRAS          = 8'h10;
  array_tWR           = 8'h6;
  array_tRP           = 8'h6;
  array_tRCD_RD       = 8'h7;
  array_tRTP          = 8'h3;
  array_rdata_vld     = 'd1;
  array_rdata         = 'd0;


  //rst_n
  repeat(3) @(posedge clk);
  rst_n = 1;

  //array_rf_period
  repeat(3) @(posedge clk);
  array_rf_period_0   = 'd100; //25'h16E3600;
  array_rf_period_1   = 'd120; //25'h1312D00;
  //array_rf_period switching.
  repeat(3) @(posedge clk);
  array_rf_period_sel = 1;

  //mc_en
  repeat(3) @(posedge clk);
  mc_en = 1;

  //send wframe ---------------------------------------
  repeat(3) @(posedge clk);
  send_wframe(16); //(frame_len)
    
  //send rframe ---------------------------------------
  repeat(3) @(posedge clk);
  send_rframe(32); //(frame_len)
  gen_rdata(10); //(mum_rdata)
  
  wait(u_array_ctrl.array_rf_done);


  repeat(20) @(posedge clk);
  $finish();
end

//initial begin
//  #100_000;
//  $finish();
//end

array_ctrl u_array_ctrl (
  //Global.
  .clk                  (clk),
  .rst_n                (rst_n),
  //mc enalbe.                                  
  .mc_en                (mc_en),
  //internal_frame.                             
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_data (axi2array_frame_data),
  .axi2array_frame_ready(axi2array_frame_ready),
  //array_refresh.                              
  .array_rf_period_sel  (array_rf_period_sel),
  .array_rf_period_0    (array_rf_period_0),
  .array_rf_period_1    (array_rf_period_1),
  //Timing config.
  .array_tRCD_WR        (array_tRCD_WR),
  .array_tRAS           (array_tRAS),
  .array_tWR            (array_tWR),
  .array_tRP            (array_tRP),
  .array_tRCD_RD        (array_tRCD_RD),
  .array_tRTP           (array_tRTP),
  //array_interface.
  .array_cs_n           (array_cs_n),
  .array_raddr          (array_raddr),
  .array_caddr_vld_wr   (array_caddr_vld_wr),
  .array_caddr_wr       (array_caddr_wr),
  .array_caddr_vld_rd   (array_caddr_vld_rd),
  .array_caddr_rd       (array_caddr_rd),
  .array_wdata_vld      (array_wdata_vld),
  .array_wdata          (array_wdata),
  //array_rdata.
  .array_rdata_vld      (array_rdata_vld),
  .array_rdata          (array_rdata),
  //sync_array_r.
  .sync_array_rdata_vld (sync_array_rdata_vld),
  .sync_array_rdata     (sync_array_rdata)
  );

endmodule

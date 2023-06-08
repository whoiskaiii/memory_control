module axi_slv_tb();
parameter AXI_ADDR_WIDTH          = 25,
          AXI_DATA_WIDTH          = 256,
          ARRAY_COL_ADDR_WIDTH    = 6,
          ARRAY_ROW_ADDR_WIDTH    = 16,
          ARRAY_DATA_WIDTH        = 64,
          AXI_LEN_WIDTH           = 8,
          FRAME_DATA_WIDTH        = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    AXI_LEN_WIDTH + ARRAY_DATA_WIDTH,
                                    //3 is rw_flag, sof and eof.
          ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    ARRAY_DATA_WIDTH,
                                    //3 is rw_flag, sof and eof.
          CLK_CYC                 = 2.5; //400MHz
//global signals.
reg                                 clk;
reg                                 rst_n;
//axi_s_aw signals.
reg                                 axi_s_awvalid;
wire                                axi_s_awready;
reg   [7:0]                         axi_s_awlen;
reg   [AXI_ADDR_WIDTH-1:0]          axi_s_awaddr;
//axi_s_w signals.
reg                                 axi_s_wvalid;
wire                                axi_s_wready;
reg                                 axi_s_wlast;
reg   [AXI_DATA_WIDTH-1:0]          axi_s_wdata;
//axi_s_ar signals.
reg                                 axi_s_arvalid;
wire                                axi_s_arready;
reg   [7:0]                         axi_s_arlen;
reg   [AXI_ADDR_WIDTH-1:0]          axi_s_araddr;
//axi_s_r signals.
wire                                axi_s_rvalid;
wire                                axi_s_rlast;
wire  [AXI_DATA_WIDTH-1:0]          axi_s_rdata;
//apb_cfg signals.
reg                                 mc_en;
reg   [1:0]                         axi_rw_prio;
//internal_frame signals.
wire                                axi2array_frame_valid;
reg                                 axi2array_frame_ready;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data;
//array_r signals.
reg                                 array_rdata_valid;
reg   [ARRAY_DATA_WIDTH-1:0]        array_rdata;

//---------------------------------------------------------
integer cnt_len;
//task axi_awchannel
task axi_awchannel;
  input [AXI_ADDR_WIDTH-1:0]  axi_s_awaddr_t;
  input [7:0]                 axi_s_awlen_t;
  begin
    @(posedge clk) begin
      axi_s_awvalid <=  1'b1;
      axi_s_awaddr  <=  axi_s_awaddr_t;
      axi_s_awlen   <=  axi_s_awlen_t;
    end
    #1
    wait(axi_s_awready);
    @(posedge clk) begin
      axi_s_awvalid <=  1'b0;
    end
  end
endtask

//task axi_wchannel
task axi_wchannel;
  input [AXI_DATA_WIDTH-1:0]  axi_s_wdata_t;
  begin
    @(posedge clk) begin
      axi_s_wvalid  <=  1'b1;
      axi_s_wdata   <=  axi_s_wdata_t;
    end
    #1;
    wait(axi_s_wready);
    @(posedge clk) begin
      axi_s_wvalid  <=  1'b0;
    end
  end
endtask

//task axi_wr
task axi_wr;
  input [AXI_ADDR_WIDTH-1:0]  axi_s_awaddr_t;
  input [7:0]                 axi_s_awlen_t;
  begin
    axi_awchannel(axi_s_awaddr_t, axi_s_awlen_t);
    for(cnt_len=0; cnt_len<axi_s_awlen_t+1; cnt_len=cnt_len+1) begin
      @(posedge clk) begin
        if(cnt_len==axi_s_awlen_t)
          axi_s_wlast <=  1'b1;
      end
      axi_wchannel({{$random()}, {$random()}, {$random()}, {$random()},
                    {$random()}, {$random()}, {$random()}, {$random()}});
                    //8 32-bit random numbers.
    end
    @(posedge clk)
    axi_s_wlast <=  1'b0;
  end
endtask

//---------------------------------------------------------
integer cnt_rdata;
//task axi_archannel
task axi_archannel;
  input [AXI_ADDR_WIDTH-1:0]  axi_s_araddr_t;
  input [7:0]                 axi_s_arlen_t;
  begin
    @(posedge clk) begin
      axi_s_arvalid <=  1'b1;
      axi_s_araddr  <=  axi_s_araddr_t;
      axi_s_arlen   <=  axi_s_arlen_t;
    end
    #1;
    wait(axi_s_arready);
    @(posedge clk) begin
      axi_s_arvalid <=  1'b0;
    end
  end
endtask

//task array_r
task array_r;
  input [7:0]   axi_s_arlen_t;
  begin
    for(cnt_rdata=0; cnt_rdata<((axi_s_arlen_t+1)*4); cnt_rdata=cnt_rdata+1) begin
      @(posedge clk) begin
        #1;
        array_rdata_valid <=  1'b1;
        array_rdata       <=  {{$random()}, {$random()}};
      end
      @(posedge clk) begin
        #1;
        array_rdata_valid <=  1'b0;
      end
    end
  end
endtask

//Generate clk
initial begin
  #0;
  clk = 0;
  forever #(CLK_CYC)  clk = ~clk;
end

initial begin
  rst_n                 = 0;
  axi_s_awvalid         = 0;
  axi_s_awlen           = 0;
  axi_s_awaddr          = 0;
  axi_s_wvalid          = 0;
  axi_s_wlast           = 0;
  axi_s_wdata           = 0;
  axi_s_arvalid         = 0;
  axi_s_arlen           = 0;
  axi_s_araddr          = 0;
  mc_en                 = 0;
  axi_rw_prio           = 0;
  axi2array_frame_ready = 1;
  array_rdata_valid     = 0;
  array_rdata           = 0;

  repeat(3) @(posedge clk);
  rst_n = 1;

  repeat(5) @(posedge clk) begin
    fork
      begin //Fork 1: w_channel
        repeat(3) @(posedge clk);
        axi_wr(25'd24, 8'd32); //axi_wr(axi_s_awaddr, axi_s_awlen)
        repeat(9) @(posedge clk);
        axi_wr(25'd60, 8'd16); //axi_wr(axi_s_awaddr, axi_s_awlen)
      end
      begin //Fork 2: r_channel
        repeat(3) @(posedge clk);
        axi_archannel(25'd24, 8'd18); //axi_archannel(axi_s_araddr, axi_s_arlen)
        repeat(9) @(posedge clk);
        axi_archannel(25'd40, 8'd36); //axi_archannel(axi_s_araddr, axi_s_arlen)
        repeat(9) @(posedge clk);
        array_r(8'd18); //array_r(axi_s_arlen)
        repeat(9) @(posedge clk);
        array_r(8'd36); //array_r(axi_s_arlen)
      end
    join
  end

  repeat(9) @(posedge clk);
  $finish();
end

initial begin
  #5000_00;
  $finish();
end

axi_slv #(
  .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH        ), 
  .AXI_DATA_WIDTH         (AXI_DATA_WIDTH        ), 
  .ARRAY_COL_ADDR_WIDTH   (ARRAY_COL_ADDR_WIDTH  ), 
  .ARRAY_ROW_ADDR_WIDTH   (ARRAY_ROW_ADDR_WIDTH  ), 
  .ARRAY_DATA_WIDTH       (ARRAY_DATA_WIDTH      ), 
  .AXI_LEN_WIDTH          (AXI_LEN_WIDTH         ), 
  .FRAME_DATA_WIDTH       (FRAME_DATA_WIDTH      ), 
  .ARRAY_FRAME_DATA_WIDTH (ARRAY_FRAME_DATA_WIDTH) 
  ) u_axi_slv (
  //global signals.
  .clk                  (clk  ),
  .rst_n                (rst_n),
  //axi_s_aw signals.
  .axi_s_awvalid        (axi_s_awvalid),
  .axi_s_awready        (axi_s_awready),
  .axi_s_awlen          (axi_s_awlen  ),
  .axi_s_awaddr         (axi_s_awaddr ),
  //axi_s_w signals.
  .axi_s_wvalid         (axi_s_wvalid),
  .axi_s_wready         (axi_s_wready),
  .axi_s_wlast          (axi_s_wlast ),
  .axi_s_wdata          (axi_s_wdata ),
  //axi_s_ar signals.
  .axi_s_arvalid        (axi_s_arvalid),
  .axi_s_arready        (axi_s_arready),
  .axi_s_arlen          (axi_s_arlen  ),
  .axi_s_araddr         (axi_s_araddr ),
  //axi_s_r signals.
  .axi_s_rvalid         (axi_s_rvalid),
  .axi_s_rlast          (axi_s_rlast ),
  .axi_s_rdata          (axi_s_rdata ),
  //apb_cfg signals.
  .mc_en                (mc_en      ),
  .axi_rw_prio          (axi_rw_prio),
  //internal_frame signals.
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_ready(axi2array_frame_ready),
  .axi2array_frame_data (axi2array_frame_data ),
  //array_r signals.
  .array_rdata_valid    (array_rdata_valid),
  .array_rdata          (array_rdata      )
  );

endmodule

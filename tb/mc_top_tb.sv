module mc_top_tb();

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
          DATA_WIDTH              = 32,
          ADDR_WIDTH              = 8,
          AXI_CLK_CYC             = 2.5,
          APB_CLK_CYC             = 20;

//global signals.
reg                                 clk;
reg                                 rst_n;
//axi_slv -----------------------------------------------------
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
//array_ctrl --------------------------------------------------
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
//mc_apb_cfg --------------------------------------------------
//apb signals.
reg                                 apb_pclk;
reg                                 apb_prst_n;
reg                                 apb_psel;
reg                                 apb_pwrite;
reg                                 apb_penable;
reg   [ADDR_WIDTH-1:0]              apb_paddr;
reg   [DATA_WIDTH-1:0]              apb_pwdata;
wire                                apb_pready; //apb_pready always 1.
wire  [DATA_WIDTH-1:0]              apb_prdata;

//axi_slv task --------------------------------------------------
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

//mc_apb_cfg task -----------------------------------------------
//task apb_wr
task apb_wr;
  input [ADDR_WIDTH-1:0]  waddr;
  input [DATA_WIDTH-1:0]  wdata;
  begin
    @(posedge apb_pclk) begin
      apb_paddr   <=  waddr;
      apb_pwrite  <=  1'b1;
      apb_psel    <=  1'b1;
      apb_pwdata  <=  wdata;
    end

    @(posedge apb_pclk) begin
      apb_penable <=  1'b1;
    end
    
    #1;
    wait(apb_pready);

    @(posedge apb_pclk) begin
      apb_psel    <=  1'b0;
      apb_penable <=  1'b0;
    end
  end
endtask

//task apb_rd
task apb_rd;
  input   [ADDR_WIDTH-1:0]  raddr;
  begin
    @(posedge apb_pclk) begin
      apb_paddr   <=  raddr;
      apb_pwrite  <=  1'b0;
      apb_psel    <=  1'b1;
    end
    
    @(posedge apb_pclk) begin
      apb_penable <=  1'b1;
    end

    #1;
    wait(apb_pready);

    @(posedge apb_pclk) begin
      apb_psel    <=  1'b0;
      apb_penable <=  1'b0;
    end
  end
endtask

//array_ctrl task -----------------------------------------------
//task array_r
task array_r;
  input [7:0]   axi_s_arlen_t;
  begin
    for(cnt_rdata=0; cnt_rdata<((axi_s_arlen_t+1)*4); cnt_rdata=cnt_rdata+1) begin
      @(posedge clk) begin
        #1;
        array_rdata_vld <=  1'b0;
        array_rdata     <=  {{$random()}, {$random()}};
      end
      @(posedge clk) begin
        #1;
        array_rdata_vld <=  1'b1;
      end
    end
  end
endtask

//Generate clk
initial begin
  #0;
  clk       = 0;
  forever #(AXI_CLK_CYC)  clk = ~clk;
end

initial begin
  #0;
  apb_pclk  = 0;
  forever #(APB_CLK_CYC)  apb_pclk  = ~apb_pclk;
end

initial begin
  rst_n                 = 0;
  apb_prst_n            = 0;
  //axi_slv
  axi_s_awvalid         = 0;
  axi_s_awlen           = 0;
  axi_s_awaddr          = 0;
  axi_s_wvalid          = 0;
  axi_s_wlast           = 0;
  axi_s_wdata           = 0;
  axi_s_arvalid         = 0;
  axi_s_arlen           = 0;
  axi_s_araddr          = 0;
  //array_ctrl.
  array_rdata_vld       = 0;
  array_rdata           = 0;
  //mc_apb_cfg.
  apb_pclk              = 0;
  apb_psel              = 0;
  apb_pwrite            = 0;
  apb_penable           = 0;
  apb_paddr             = 0;
  apb_pwdata            = 0;

  repeat(3) @(posedge clk);
  rst_n       = 1;
  apb_prst_n  = 1;

  repeat(3) @(posedge clk);
  apb_wr('d0, 'd1); //apb_wr(waddr, wdata), mc_en set 1.

  @(posedge clk) begin
    fork
      begin //Fork 1: w_channel
        repeat(1) @(posedge clk);
        axi_wr(25'd24, 8'd32); //axi_wr(axi_s_awaddr, axi_s_awlen)
        //wait(axi_s_wready);
        //wait(axi_s_awready);
        //repeat(9) @(posedge clk);
        //axi_wr(25'd60, 8'd12); //axi_wr(axi_s_awaddr, axi_s_awlen)
        //wait(axi_s_wready);
        //wait(axi_s_awready);
      end
      begin //Fork 2: r_channel
        repeat(1) @(posedge clk);
        axi_archannel(25'd24, 8'd32); //axi_archannel(axi_s_araddr, axi_s_arlen)
        //wait(axi_s_arready);
        repeat(500) @(posedge clk);
        array_r(8'd32); //array_r(axi_s_arlen)
      end
    join
  end

  repeat(200) @(posedge clk);
  $finish();
end

initial begin
  #10_000;
  $finish();
end

mc_top u_mc_top (
  //global signals.
  .clk                          (clk),                 
  .rst_n                        (rst_n),
  //axi_slv -----------------------------------------------------
  //axi_s_aw signals.
  .axi_s_awvalid                (axi_s_awvalid),
  .axi_s_awready                (axi_s_awready),
  .axi_s_awlen                  (axi_s_awlen),
  .axi_s_awaddr                 (axi_s_awaddr),
  //axi_s_w signals.
  .axi_s_wvalid                 (axi_s_wvalid),
  .axi_s_wready                 (axi_s_wready),
  .axi_s_wlast                  (axi_s_wlast),
  .axi_s_wdata                  (axi_s_wdata),
  //axi_s_ar signals.
  .axi_s_arvalid                (axi_s_arvalid),
  .axi_s_arready                (axi_s_arready),
  .axi_s_arlen                  (axi_s_arlen),
  .axi_s_araddr                 (axi_s_araddr),
  //axi_s_r signals.
  .axi_s_rvalid                 (axi_s_rvalid),
  .axi_s_rlast                  (axi_s_rlast),
  .axi_s_rdata                  (axi_s_rdata),
  //array_ctrl --------------------------------------------------
  //array_interface.
  .array_cs_n                   (array_cs_n),
  .array_raddr                  (array_raddr),
  .array_caddr_vld_wr           (array_caddr_vld_wr),
  .array_caddr_wr               (array_caddr_wr),
  .array_caddr_vld_rd           (array_caddr_vld_rd),
  .array_caddr_rd               (array_caddr_rd),
  .array_wdata_vld              (array_wdata_vld),
  .array_wdata                  (array_wdata),
  //array_rdata.   
  .array_rdata_vld              (array_rdata_vld),
  .array_rdata                  (array_rdata),
  //mc_apb_cfg --------------------------------------------------
  //apb signals. 
  .apb_pclk                     (apb_pclk),
  .apb_prst_n                   (apb_prst_n),
  .apb_psel                     (apb_psel),
  .apb_pwrite                   (apb_pwrite),
  .apb_penable                  (apb_penable),
  .apb_paddr                    (apb_paddr),
  .apb_pwdata                   (apb_pwdata),
  .apb_pready                   (apb_pready),
  .apb_prdata                   (apb_prdata)                         
  );

endmodule

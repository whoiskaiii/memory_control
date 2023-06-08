module mc_top #(
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
            ADDR_WIDTH              = 8
  )(
  //global signals.
  input                                 clk,
  input                                 rst_n,
  //axi_slv -----------------------------------------------------
  //axi_s_aw signals.
  input                                 axi_s_awvalid,
  output                                axi_s_awready,
  input   [7:0]                         axi_s_awlen,
  input   [AXI_ADDR_WIDTH-1:0]          axi_s_awaddr,
  //axi_s_w signals.
  input                                 axi_s_wvalid,
  output                                axi_s_wready,
  input                                 axi_s_wlast,
  input   [AXI_DATA_WIDTH-1:0]          axi_s_wdata,
  //axi_s_ar signals.
  input                                 axi_s_arvalid,
  output                                axi_s_arready,
  input   [7:0]                         axi_s_arlen,
  input   [AXI_ADDR_WIDTH-1:0]          axi_s_araddr,
  //axi_s_r signals.
  output                                axi_s_rvalid,
  output                                axi_s_rlast,
  output  [AXI_DATA_WIDTH-1:0]          axi_s_rdata,
  //array_ctrl --------------------------------------------------
  //array_interface.
  output                                array_cs_n,
  output  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr,
  output                                array_caddr_vld_wr,
  output  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_wr,
  output                                array_caddr_vld_rd,
  output  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_rd,
  output                                array_wdata_vld,
  output  [ARRAY_DATA_WIDTH-1:0]        array_wdata,
  //array_rdata.
  input                                 array_rdata_vld,
  input   [ARRAY_DATA_WIDTH-1:0]        array_rdata,
  //mc_apb_cfg --------------------------------------------------
  //apb signals.
  input                         apb_pclk,
  input                         apb_prst_n,
  input                         apb_psel,
  input                         apb_pwrite,
  input                         apb_penable,
  input       [ADDR_WIDTH-1:0]  apb_paddr,
  input       [DATA_WIDTH-1:0]  apb_pwdata,
  output                        apb_pready, //apb_pready always 1.
  output      [DATA_WIDTH-1:0]  apb_prdata
  );

//mc_apb_cfg <---> axi_slv ---------------------------
//mc_apb_cfg.
wire                                mc_en;
wire                                sync_mc_en;
wire          [1:0]                 axi_rw_prio;
// axi_slv <---> array_ctrl --------------------------
//internal_frame.
wire                                axi2array_frame_valid;
wire                                axi2array_frame_ready;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data;
//array_r.
wire                                sync_array_rdata_valid;
wire  [ARRAY_DATA_WIDTH-1:0]        sync_array_rdata;
//array_ctrl <---> mc_apb_cfg ------------------------
//array_refresh.
wire                                array_rf_period_sel;
wire  [24:0]                        array_rf_period_0;
wire  [24:0]                        array_rf_period_1;
//Timing config.
wire  [7:0]                         array_tRCD_WR;
wire  [7:0]                         array_tRAS;
wire  [7:0]                         array_tWR;
wire  [7:0]                         array_tRP;
wire  [7:0]                         array_tRCD_RD;
wire  [7:0]                         array_tRTP;
wire  [7:0]                         array_tRC;

DW_sync #(
  .width    ('d1)
  ) u_DW_sync (
  .data_s   (mc_en),
  .clk_d    (clk),
  .rst_d_n  (rst_n),
  .init_d_n (rst_n),
  .test     (1'b1),
  .data_d   (sync_mc_en)
  );

//axi_slv -----------------------------------------------------
axi_slv u_axi_slv (
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
  .mc_en                (sync_mc_en ),
  .axi_rw_prio          (axi_rw_prio),
  //internal_frame signals.
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_ready(axi2array_frame_ready),
  .axi2array_frame_data (axi2array_frame_data ),
  //array_r signals.
  .array_rdata_valid    (sync_array_rdata_valid),
  .array_rdata          (sync_array_rdata      )
  );

//array_ctrl ----------------------------------------------------
array_ctrl u_array_ctrl (
  //Global.
  .clk                  (clk),
  .rst_n                (rst_n),
  //mc enalbe.                                  
  .mc_en                (sync_mc_en),
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
  .sync_array_rdata_vld (sync_array_rdata_valid),
  .sync_array_rdata     (sync_array_rdata)
  );

//mc_apb_cfg ----------------------------------------------------
mc_apb_cfg u_mc_apb_cfg (
  //apb signals.
  .apb_pclk             (apb_pclk),
  .apb_prst_n           (apb_prst_n),
  .apb_psel             (apb_psel),
  .apb_pwrite           (apb_pwrite),
  .apb_penable          (apb_penable),
  .apb_paddr            (apb_paddr),
  .apb_pwdata           (apb_pwdata),
  .apb_pready           (apb_pready),
  .apb_prdata           (apb_prdata),
  //Config signals
  .mc_en                (mc_en),
  .axi2array_rw_prio    (axi_rw_prio),
  .array_tRAS           (array_tRAS),
  .array_tRP            (array_tRP),
  .array_tRC            (array_tRC),
  .array_tRCD_WR        (array_tRCD_WR),
  .array_tRCD_RD        (array_tRCD_RD),
  .array_tWR            (array_tWR),
  .array_tRTP           (array_tRTP),
  .array_rf_period_0    (array_rf_period_0),
  .array_rf_period_1    (array_rf_period_1),
  .array_rf_period_sel  (array_rf_period_sel)
);

endmodule

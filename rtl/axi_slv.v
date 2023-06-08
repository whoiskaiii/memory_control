module axi_slv #(
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
                                      ARRAY_DATA_WIDTH
                                      //3 is rw_flag, sof and eof.
  )(
  //global signals.
  input                                 clk,
  input                                 rst_n,
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
  //apb_cfg signals.
  input                                 mc_en,
  input   [1:0]                         axi_rw_prio,
  //internal_frame signals.
  output                                axi2array_frame_valid,
  input                                 axi2array_frame_ready,
  output  [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data,
  //array_r signals.
  input                                 array_rdata_valid,
  input   [ARRAY_DATA_WIDTH-1:0]        array_rdata
  );

//w_frame signals.
wire                          axi2arb_wframe_valid;
wire                          axi2arb_wframe_ready;
wire  [FRAME_DATA_WIDTH-1:0]  axi2arb_wframe_data;
//r_frame signals.
wire                          axi2arb_rframe_valid;
wire                          axi2arb_rframe_ready;
wire  [FRAME_DATA_WIDTH-1:0]  axi2arb_rframe_data;


//axi_slv_wchannel instantiation --------------------------
axi_slv_wchannel #(
  .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
  ) u_axi_slv_wchannel (
  //global signals
  .clk                  (clk),
  .rst_n                (rst_n),
  //axi_s_aw signals.
  .axi_s_awvalid        (axi_s_awvalid),
  .axi_s_awready        (axi_s_awready),
  .axi_s_awlen          (axi_s_awlen),
  .axi_s_awaddr         (axi_s_awaddr),
  //axi_s_w signals.
  .axi_s_wvalid         (axi_s_wvalid),
  .axi_s_wready         (axi_s_wready),
  .axi_s_wlast          (axi_s_wlast),
  .axi_s_wdata          (axi_s_wdata),
  //w_frame signals.
  .axi2arb_wframe_valid (axi2arb_wframe_valid),
  .axi2arb_wframe_ready (axi2arb_wframe_ready),
  .axi2arb_wframe_data  (axi2arb_wframe_data)
  );

//axi_slv_rchannel instantiation --------------------------
axi_slv_rchannel #(
  .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
  ) u_axi_slv_rchannel (
  //global signals
  .clk                  (clk),
  .rst_n                (rst_n),
  //axi_s_ar signals.
  .axi_s_arvalid        (axi_s_arvalid),
  .axi_s_arready        (axi_s_arready),
  .axi_s_arlen          (axi_s_arlen),
  .axi_s_araddr         (axi_s_araddr),
  //axi_s_r signals.
  .axi_s_rvalid         (axi_s_rvalid),
  .axi_s_rlast          (axi_s_rlast),
  .axi_s_rdata          (axi_s_rdata),
  //r_frame signals.
  .axi2arb_rframe_valid (axi2arb_rframe_valid),
  .axi2arb_rframe_ready (axi2arb_rframe_ready),
  .axi2arb_rframe_data  (axi2arb_rframe_data),
  //array_r signals.
  .array_rdata_valid    (array_rdata_valid),
  .array_rdata          (array_rdata)
  );

//arbiter instantiation -----------------------------------
arbiter u_arbiter (
  //Global signals.
  .clk                  (clk),                
  .rst_n                (rst_n),
  //w_frame signals.
  .axi2arb_wframe_valid (axi2arb_wframe_valid),
  .axi2arb_wframe_ready (axi2arb_wframe_ready),
  .axi2arb_wframe_data  (axi2arb_wframe_data),
  //w_frame signals.
  .axi2arb_rframe_valid (axi2arb_rframe_valid),
  .axi2arb_rframe_ready (axi2arb_rframe_ready),
  .axi2arb_rframe_data  (axi2arb_rframe_data),
  //internal frame signal.
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_ready(axi2array_frame_ready),
  .axi2array_frame_data (axi2array_frame_data),
  //apb_cfg signals.
  .axi_rw_prio          (axi_rw_prio),
  .mc_en                (mc_en)
  );

endmodule

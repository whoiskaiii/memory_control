module array_ctrl #(
  parameter ARRAY_COL_ADDR_WIDTH    = 6,
            ARRAY_ROW_ADDR_WIDTH    = 16,
            ARRAY_DATA_WIDTH        = 64,
            ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                      ARRAY_DATA_WIDTH //3 is rw_flag, sof and eof.
  )(
  //Global.
  input                                 clk,
  input                                 rst_n,
  //mc enalbe.
  input                                 mc_en,
  //internal_frame.
  input                                 axi2array_frame_valid,
  input   [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data,
  output                                axi2array_frame_ready,
  //array_refresh.
  input                                 array_rf_period_sel,
  input   [24:0]                        array_rf_period_0,
  input   [24:0]                        array_rf_period_1,
  //Timing config.
  input   [7:0]                         array_tRCD_WR,
  input   [7:0]                         array_tRAS,
  input   [7:0]                         array_tWR,
  input   [7:0]                         array_tRP,
  input   [7:0]                         array_tRCD_RD,
  input   [7:0]                         array_tRTP,
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
  //sync_array_r.
  output                                sync_array_rdata_vld,
  output  [ARRAY_DATA_WIDTH-1:0]        sync_array_rdata
  );

//array_write frame.
wire                                array_wframe_valid;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  array_wframe_data;
wire                                array_wframe_ready;
wire                                array_wr_start;
wire                                array_wr_done;
//array_read frame.
wire                                array_rframe_valid;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  array_rframe_data;
wire                                array_rframe_ready;
wire                                array_rd_start;
wire                                array_rd_done;
//array_refresh.
wire                                array_rf_start;
wire                                array_rf_done;
//array_mux_sel.
wire  [1:0]                         array_mux_sel;
//array_writer_interface.
wire                                array_wr_cs_n;        
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_wr_raddr;       
wire                                array_wr_caddr_vld_wr;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_wr_caddr_wr;    
wire                                array_wr_wdata_vld;   
wire  [ARRAY_DATA_WIDTH-1:0]        array_wr_wdata;       
//array_read_interface.
wire                                array_rd_cs_n;        
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_rd_raddr;       
wire                                array_rd_caddr_vld_rd;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_rd_caddr_rd;    
//array_refresh_interface.
wire                                array_rf_cs_n;        
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_rf_raddr;       

//array_state_ctrl ----------------------------------------------
array_state_ctrl u_array_state_ctrl (
  //Global.
  .clk                    (clk),                    
  .rst_n                  (rst_n),
  //mc enalbe.       
  .mc_en                  (mc_en),
  //internal_frame.   
  .axi2array_frame_valid  (axi2array_frame_valid),
  .axi2array_frame_data   (axi2array_frame_data),
  .axi2array_frame_ready  (axi2array_frame_ready),
  //array_write frame. 
  .array_wframe_valid     (array_wframe_valid),
  .array_wframe_data      (array_wframe_data),
  .array_wframe_ready     (array_wframe_ready),
  .array_wr_start         (array_wr_start),
  .array_wr_done          (array_wr_done),
  //array_read frame.   
  .array_rframe_valid     (array_rframe_valid),
  .array_rframe_data      (array_rframe_data),
  .array_rframe_ready     (array_rframe_ready),
  .array_rd_start         (array_rd_start),
  .array_rd_done          (array_rd_done),
  //array_refresh.       
  .array_rf_period_sel    (array_rf_period_sel),
  .array_rf_period_0      (array_rf_period_0),
  .array_rf_period_1      (array_rf_period_1),
  .array_rf_start         (array_rf_start),
  .array_rf_done          (array_rf_done),
  //array_mux_sel.        
  .array_mux_sel          (array_mux_sel)
  );

//array_write ---------------------------------------------------
array_write u_array_write (
  //Global.              
  .clk                (clk),
  .rst_n              (rst_n),
  //array_write frame.  
  .array_wframe_valid (array_wframe_valid),
  .array_wframe_data  (array_wframe_data),
  .array_wframe_ready (array_wframe_ready),
  .array_wr_start     (array_wr_start),
  .array_wr_done      (array_wr_done),
  //Timing config.       
  .array_tRCD_WR      (array_tRCD_WR),
  .array_tRAS         (array_tRAS),
  .array_tWR          (array_tWR),
  .array_tRP          (array_tRP),
  //array_interface.     
  .array_cs_n         (array_wr_cs_n),
  .array_raddr        (array_wr_raddr),
  .array_caddr_vld_wr (array_wr_caddr_vld_wr),
  .array_caddr_wr     (array_wr_caddr_wr),
  .array_wdata_vld    (array_wr_wdata_vld),
  .array_wdata        (array_wr_wdata)      
  );

//array_read ----------------------------------------------------
array_read u_array_read (
  //Global.             
  .clk                  (clk),
  .rst_n                (rst_n),
  //array_read frame.   
  .array_rframe_valid   (array_rframe_valid),
  .array_rframe_data    (array_rframe_data),
  .array_rframe_ready   (array_rframe_ready),
  .array_rd_start       (array_rd_start),
  .array_rd_done        (array_rd_done),
  //Timing config.      
  .array_tRCD_RD        (array_tRCD_RD),
  .array_tRAS           (array_tRAS),
  .array_tRTP           (array_tRTP),
  .array_tRP            (array_tRP),
  //array_interface.    
  .array_cs_n           (array_rd_cs_n),
  .array_raddr          (array_rd_raddr),
  .array_caddr_vld_rd   (array_rd_caddr_vld_rd),
  .array_caddr_rd       (array_rd_caddr_rd),
  .array_rdata_vld      (array_rdata_vld),
  .array_rdata          (array_rdata),
  //sync_array_r.       
  .sync_array_rdata_vld (sync_array_rdata_vld),
  .sync_array_rdata     (sync_array_rdata)
  );

//array_refresh -------------------------------------------------
array_refresh u_array_refrsh (
  //Global.
  .clk            (clk),               
  .rst_n          (rst_n),
  //array_refresh. 
  .array_rf_start (array_rf_start),
  .array_rf_done  (array_rf_done),
  //Timing config.  
  .array_tRAS     (array_tRAS),
  .array_tRP      (array_tRP),
  //array_interface. 
  .array_cs_n     (array_rf_cs_n),
  .array_raddr    (array_rf_raddr)
  );

//array_mux -----------------------------------------------------
array_mux u_array_mux (
  //array_mux_sel.                      
  .array_mux_sel          (array_mux_sel),
  //array_write_interface.   
  .array_wr_cs_n          (array_wr_cs_n),
  .array_wr_raddr         (array_wr_raddr),
  .array_wr_caddr_vld_wr  (array_wr_caddr_vld_wr),
  .array_wr_caddr_wr      (array_wr_caddr_wr),
  .array_wr_wdata_vld     (array_wr_wdata_vld),
  .array_wr_wdata         (array_wr_wdata),
  //array_read_interface.    
  .array_rd_cs_n          (array_rd_cs_n),
  .array_rd_raddr         (array_rd_raddr),
  .array_rd_caddr_vld_rd  (array_rd_caddr_vld_rd),
  .array_rd_caddr_rd      (array_rd_caddr_rd),
  //array_refresh_interface. 
  .array_rf_cs_n          (array_rf_cs_n),
  .array_rf_raddr         (array_rf_raddr),
  //array_interface.        
  .array_cs_n             (array_cs_n),
  .array_raddr            (array_raddr),
  .array_caddr_vld_wr     (array_caddr_vld_wr),
  .array_caddr_wr         (array_caddr_wr),
  .array_caddr_vld_rd     (array_caddr_vld_rd),
  .array_caddr_rd         (array_caddr_rd),
  .array_wdata_vld        (array_wdata_vld),
  .array_wdata            (array_wdata)                               
  );

endmodule

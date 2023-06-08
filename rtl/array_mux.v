module array_mux #(
  parameter ARRAY_COL_ADDR_WIDTH  = 6,
            ARRAY_ROW_ADDR_WIDTH  = 16,
            ARRAY_DATA_WIDTH      = 64
  )(
  //array_mux_sel.
  input       [1:0]                       array_mux_sel,
  //array_write_interface.
  input                                   array_wr_cs_n,
  input       [ARRAY_ROW_ADDR_WIDTH-1:0]  array_wr_raddr,
  input                                   array_wr_caddr_vld_wr,
  input       [ARRAY_COL_ADDR_WIDTH-1:0]  array_wr_caddr_wr,
  input                                   array_wr_wdata_vld,
  input       [ARRAY_DATA_WIDTH-1:0]      array_wr_wdata,
  //array_read_interface.
  input                                   array_rd_cs_n,
  input       [ARRAY_ROW_ADDR_WIDTH-1:0]  array_rd_raddr,
  input                                   array_rd_caddr_vld_rd,
  input       [ARRAY_COL_ADDR_WIDTH-1:0]  array_rd_caddr_rd,
  //array_refresh_interface.
  input                                   array_rf_cs_n,
  input       [ARRAY_ROW_ADDR_WIDTH-1:0]  array_rf_raddr,
  //array_interface.
  output  reg                             array_cs_n,
  output  reg [ARRAY_ROW_ADDR_WIDTH-1:0]  array_raddr,
  output  reg                             array_caddr_vld_wr,
  output  reg [ARRAY_COL_ADDR_WIDTH-1:0]  array_caddr_wr,
  output  reg                             array_caddr_vld_rd,
  output  reg [ARRAY_COL_ADDR_WIDTH-1:0]  array_caddr_rd,
  output  reg                             array_wdata_vld,
  output  reg [ARRAY_DATA_WIDTH-1:0]      array_wdata
  );

always @(*) begin
  array_cs_n          = 'd1;
  array_raddr         = 'd0;
  array_caddr_vld_wr  = 'd0;
  array_caddr_wr      = 'd0; 
  array_caddr_vld_rd  = 'd0;
  array_caddr_rd      = 'd0; 
  array_wdata_vld     = 'd1; 
  array_wdata         = 'd0;
  case(array_mux_sel)
    2'd0: begin //IDLE
      array_cs_n          = 'd1;
      array_raddr         = 'd0;
      array_caddr_vld_wr  = 'd0;
      array_caddr_wr      = 'd0; 
      array_wdata_vld     = 'd1;
      array_wdata         = 'd0;
    end
    2'd1: begin //WR
      array_cs_n          = array_wr_cs_n;
      array_raddr         = array_wr_raddr;
      array_caddr_vld_wr  = array_wr_caddr_vld_wr;
      array_caddr_wr      = array_wr_caddr_wr; 
      array_wdata_vld     = array_wr_wdata_vld; 
      array_wdata         = array_wr_wdata;
    end
    2'd2: begin //RD
      array_cs_n          =  array_rd_cs_n;
      array_raddr         =  array_rd_raddr;
      array_caddr_vld_rd  =  array_rd_caddr_vld_rd;
      array_caddr_rd      =  array_rd_caddr_rd;
    end
    2'd3: begin //RF
      array_cs_n          = array_rf_cs_n;
      array_raddr         = array_rf_raddr;
    end
  endcase
end

endmodule


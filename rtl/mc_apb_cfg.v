module mc_apb_cfg #(
  parameter DATA_WIDTH  = 32,
            ADDR_WIDTH  = 8
  )(
  //apb signals.
  input                         apb_pclk,
  input                         apb_prst_n,
  input                         apb_psel,
  input                         apb_pwrite,
  input                         apb_penable,
  input       [ADDR_WIDTH-1:0]  apb_paddr,
  input       [DATA_WIDTH-1:0]  apb_pwdata,
  output                        apb_pready, //apb_pready always 1.
  output  reg [DATA_WIDTH-1:0]  apb_prdata,

  //Config signals.
  output  reg         mc_en,
  output  reg [1:0]   axi2array_rw_prio,
  output  reg [7:0]   array_tRAS,
  output  reg [7:0]   array_tRP,
  output  reg [7:0]   array_tRC,
  output  reg [7:0]   array_tRCD_WR,
  output  reg [7:0]   array_tRCD_RD,
  output  reg [7:0]   array_tWR,
  output  reg [7:0]   array_tRTP,
  output  reg [24:0]  array_rf_period_0,
  output  reg [24:0]  array_rf_period_1,
  output  reg         array_rf_period_sel
  );

wire  apb_wr;
wire  apb_rd;

assign  apb_pready  = 1'b1;
assign  apb_wr      = apb_psel & apb_pwrite & apb_penable & apb_pready;
assign  apb_rd      = apb_psel & !apb_pwrite & apb_penable & apb_pready;

//apb write data.
always @(posedge apb_pclk or negedge apb_prst_n) begin
  if(!apb_prst_n) begin
    mc_en               <=  1'b0;
    axi2array_rw_prio   <=  2'h0;
    array_tRAS          <=  8'h10;
    array_tRP           <=  8'h6;
    array_tRC           <=  8'h16;
    array_tRCD_WR       <=  8'h7;
    array_tRCD_RD       <=  8'h7;
    array_tWR           <=  8'h6;
    array_tRTP          <=  8'h3;
    array_rf_period_0   <=  25'd500; //25'h16E3600;
    array_rf_period_1   <=  25'd520; //25'h1312D00;
    array_rf_period_sel <=  1'b0;
  end else if(apb_wr) begin
    case(apb_paddr)
      8'h00:
        mc_en               <=  apb_pwdata[0];
      8'h04:
        axi2array_rw_prio   <=  apb_pwdata[1:0];
      8'h08: begin
        array_tRAS          <=  apb_pwdata[7:0];
        array_tRP           <=  apb_pwdata[15:8];
        array_tRC           <=  apb_pwdata[23:16];
      end
      8'h0C: begin
        array_tRCD_WR       <=  apb_pwdata[7:0];
        array_tRCD_RD       <=  apb_pwdata[15:8];
        array_tWR           <=  apb_pwdata[23:16];
        array_tRTP          <=  apb_pwdata[31:24];
      end  
      8'h10:
        array_rf_period_0   <=  apb_pwdata[24:0];
      8'h14:
        array_rf_period_1   <=  apb_pwdata[24:0];
      8'h18:
        array_rf_period_sel <=  apb_pwdata[0];
      default:;
    endcase
  end
end

//apb read data.
always @(posedge apb_pclk or negedge apb_prst_n) begin
  if(!apb_prst_n) begin
    apb_prdata  <=  'b0;
  end else if(apb_rd) begin
    case(apb_paddr)
      8'h00:    apb_prdata <=  {31'd0, mc_en};
      8'h04:    apb_prdata <=  {30'd0, axi2array_rw_prio};
      8'h08:    apb_prdata <=  {8'd0, array_tRC, array_tRP, array_tRAS};
      8'h0C:    apb_prdata <=  {array_tRTP, array_tWR, array_tRCD_RD, array_tRCD_WR};
      8'h10:    apb_prdata <=  {7'd0, array_rf_period_0};
      8'h14:    apb_prdata <=  {7'd0, array_rf_period_1};
      8'h18:    apb_prdata <=  {31'd0, array_rf_period_sel};
      default:  apb_prdata <=  'b0; //When an invalid address is read, return 0.
    endcase
  end
end

endmodule

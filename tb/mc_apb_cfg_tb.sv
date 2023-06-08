module mc_apb_cfg_tb();

parameter DATA_WIDTH  = 32;
parameter ADDR_WIDTH  = 8;

parameter CLK_CYC     = 20; //20ns --> 50MHz

//apb signals.
reg                     apb_pclk;
reg                     apb_prst_n;
reg                     apb_psel;
reg                     apb_pwrite;
reg                     apb_penable;
reg   [ADDR_WIDTH-1:0]  apb_paddr;
reg   [DATA_WIDTH-1:0]  apb_pwdata;
wire                    apb_pready; //apb_pready always 1.
wire  [DATA_WIDTH-1:0]  apb_prdata;
//Config signals.
wire                    mc_en;
wire  [1:0]             axi2array_rw_prio;
wire  [7:0]             array_tRAS;
wire  [7:0]             array_tRP;
wire  [7:0]             array_tRC;
wire  [7:0]             array_tRCD_WR;
wire  [7:0]             array_tRCD_RD;
wire  [7:0]             array_tWR;
wire  [7:0]             array_tRTP;
wire  [24:0]            array_rf_period_0;
wire  [24:0]            array_rf_period_1;
wire                    array_rf_period_sel;

always #(CLK_CYC/2) apb_pclk  = ~apb_pclk;

//task apb_wr -------------------------------------------
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

//task apb_rd -------------------------------------------
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

//apb write and read --------------------------------------
integer                   cnt;
reg                       error_flag;
reg     [ADDR_WIDTH-1:0]  raddr;
reg     [ADDR_WIDTH-1:0]  waddr;
reg     [DATA_WIDTH-1:0]  wdata;

initial begin
  apb_pclk    = 0;
  apb_prst_n  = 0;
  apb_psel    = 0;
  apb_pwrite  = 0;
  apb_penable = 0;
  apb_paddr   = 0;
  apb_pwdata  = 0;
  error_flag  = 0;
  raddr       = 0;
  waddr       = 0;
  wdata       = 0;

  repeat(4) @(posedge apb_pclk);
  apb_prst_n =  1;
  repeat(3) @(posedge apb_pclk);
  for(cnt=0; cnt<7; cnt=cnt+1) begin
    waddr = 4*cnt;
    wdata = {$random}; //32-bit positive random number.
    apb_wr(waddr, wdata);

    raddr = waddr;
    case(raddr)
      8'h00: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {31'b0, wdata[0]})
          error_flag  = 1;
      end
      8'h04: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {30'b0, wdata[1:0]})
          error_flag  = 1;
      end
      8'h08: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {8'b0, wdata[23:0]})
          error_flag  = 1;
      end
      8'h0C: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != wdata)
          error_flag  = 1;
      end
      8'h10: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {7'b0, wdata[24:0]})
          error_flag  = 1;
      end
      8'h14: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {7'b0, wdata[24:0]})
          error_flag  = 1;
      end
      8'h18: begin
        apb_rd(raddr);
        @(posedge apb_pclk);
        if(apb_prdata != {31'b0, wdata[0]})
          error_flag  = 1;
      end
      default:
        error_flag  = 1;
    endcase
  end
  repeat(5) @(posedge apb_pclk);
  if(error_flag == 1) begin
    $display("**********");
    $display("**Error!**");
    $display("**********");
  end else begin
    $display("**********");
    $display("**Pass!***");
    $display("**********");
  end

  repeat(3) @(posedge apb_pclk);
  $finish;
end

mc_apb_cfg #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)
  ) u_mc_apb_cfg (
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
  .axi2array_rw_prio    (axi2array_rw_prio),
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


module axi_slv_rchannel_tb();

parameter AXI_DATA_WIDTH  = 256,
          AXI_ADDR_WIDTH  = 25,
          CLK_CYC         = 2.5;
//Global signals
reg                         clk; //400MHz --> 2.5ns
reg                         rst_n;
//axi_s_aw signals.
reg                         axi_s_arvalid;
wire                        axi_s_arready;
reg   [7:0]                 axi_s_arlen;
reg   [AXI_ADDR_WIDTH-1:0]  axi_s_araddr;
//axi_s_w signals.
wire                        axi_s_rvalid;
wire                        axi_s_rlast;
wire  [AXI_DATA_WIDTH-1:0]  axi_s_rdata;
//w_frame signals.
wire                        axi2arb_rframe_valid;
reg                         axi2arb_rframe_ready;
wire  [96:0]                axi2arb_rframe_data;
//array_r signals.
reg                         array_rdata_valid;
reg   [63:0]                array_rdata;

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

//Generate clk.
initial begin
  #0;
  clk = 0;
  forever #(CLK_CYC/2)  clk = ~clk;
end

initial begin
  rst_n                 = 0;
  axi_s_arvalid         = 0;
  axi_s_arlen           = 0;
  axi_s_araddr          = 0;
  axi2arb_rframe_ready  = 1;
  array_rdata_valid     = 0;
  array_rdata           = 0;
  cnt_rdata             = 0;

  repeat(3) @(posedge clk);
  rst_n = 1;
  
  repeat(3) @(posedge clk);
  axi_archannel(25'd24, 8'd18);
  axi_archannel(25'd40, 8'd36);
  
  repeat(9) @(posedge clk);
  array_r(8'd18);
  repeat(9) @(posedge clk);
  array_r(8'd36);

  repeat(9) @(posedge clk);
  $finish();
end

axi_slv_rchannel #(
  .AXI_DATA_WIDTH(256),
  .AXI_ADDR_WIDTH(25)
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

endmodule

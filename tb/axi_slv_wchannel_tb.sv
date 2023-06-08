module axi_slv_wchannel_tb();

parameter AXI_DATA_WIDTH  = 256,
          AXI_ADDR_WIDTH  = 25,
          CLK_CYC         = 2.5;
//Global signals
reg                         clk; //400MHz --> 2.5ns
reg                         rst_n;
//axi_s_aw signals.
reg                         axi_s_awvalid;
wire                        axi_s_awready;
reg   [7:0]                 axi_s_awlen;
reg   [AXI_ADDR_WIDTH-1:0]  axi_s_awaddr;
//axi_s_w signals.
reg                         axi_s_wvalid;
wire                        axi_s_wready;
reg                         axi_s_wlast;
reg   [AXI_DATA_WIDTH-1:0]  axi_s_wdata;
//w_frame signals.
wire                        axi2arb_wframe_valid;
reg                         axi2arb_wframe_ready;
wire  [96:0]                axi2arb_wframe_data;

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
                    {$random()}, {$random()}, {$random()}, {$random()}}); //8 32-bit random numbers.
    end
    @(posedge clk)
    axi_s_wlast <=  1'b0;
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
  axi_s_awvalid         = 0;
  axi_s_awlen           = 0;
  axi_s_awaddr          = 0;
  axi_s_wvalid          = 0;
  axi_s_wlast           = 0;
  axi_s_wdata           = 0;
  axi2arb_wframe_ready  = 1;
  cnt_len               = 0;

  repeat(4) @(posedge clk);
  rst_n = 1;
  repeat(3) @(posedge clk);
  axi_wr(25'd24, 8'd32); //axi_wr(axi_s_awaddr, axi_s_awlen)
  
  repeat(20) @(posedge clk);
  axi_wr(25'd60, 8'd16); //axi_wr(axi_s_awaddr, axi_s_awlen)

  repeat(20) @(posedge clk);
  $finish();
end

axi_slv_wchannel #(
  .AXI_DATA_WIDTH(256),
  .AXI_ADDR_WIDTH(25)
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

endmodule

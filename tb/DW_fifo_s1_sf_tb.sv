module DW_fifo_s1_sf_tb();

parameter CLK_CYC = 2.5;
//Global signals
reg         clk; //400MHz --> 2.5ns
reg         rst_n;
reg         arlen_fifo_wr;
reg         arlen_fifo_rd;
reg   [7:0] axi_s_arlen;
wire        arlen_fifo_empty;
wire        arlen_fifo_full;
wire  [7:0] arlen_fifo_dout;

wire        arlen_fifo_almost_empty;
wire        arlen_fifo_half_full;
wire        arlen_fifo_almost_full;
wire        arlen_fifo_error;


//Generate clk.
initial begin
  #0;
  clk = 0;
  forever #(CLK_CYC/2)  clk = ~clk;
end

task fifo_wr;
  input [7:0] axi_s_arlen_t;
  begin
    @(posedge clk) begin
      arlen_fifo_wr <=  1'b1;
      axi_s_arlen   <=  axi_s_arlen_t;
    end
    @(posedge clk) begin
      arlen_fifo_wr <=  1'b0;
    end
  end
endtask

task fifo_rd;
  begin
    @(posedge clk) begin
      arlen_fifo_rd <=  1'b1;
    end
    @(posedge clk) begin
      arlen_fifo_rd <=  1'b0;
    end
  end
endtask

initial begin
  rst_n         = 0;
  arlen_fifo_wr = 0;
  arlen_fifo_rd = 0;
  axi_s_arlen   = 0;

  repeat(3) @(posedge clk);
  rst_n = 1;

  repeat(3) @(posedge clk);
  fifo_wr(8'd1);
  
  repeat(9) @(posedge clk);
  fifo_wr(8'd4);
  
  repeat(9) @(posedge clk);
  fifo_rd();
  repeat(9) @(posedge clk);
  fifo_rd();

  repeat(9) @(posedge clk);
  $finish();
end

//arlen_fifo
DW_fifo_s1_sf #(
  .width    (8),
  .depth    (2),
  .ae_level (1),
  .af_level (1),
  .err_mode (0),
  .rst_mode (0)
  ) u_arlen_fifo (
  .clk          (clk),
  .rst_n        (rst_n),
  .push_req_n   (~arlen_fifo_wr),
  .pop_req_n    (~arlen_fifo_rd),
  .diag_n       (1'b1),
  .data_in      (axi_s_arlen),
  .empty        (arlen_fifo_empty),
  .almost_empty (arlen_fifo_almost_empty), //
  .half_full    (arlen_fifo_half_full), //
  .almost_full  (arlen_fifo_almost_full), //
  .full         (arlen_fifo_full),
  .error        (arlen_fifo_error), //
  .data_out     (arlen_fifo_dout)
);

endmodule

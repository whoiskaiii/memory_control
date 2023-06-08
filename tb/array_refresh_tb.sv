module array_refresh_tb();

parameter ARRAY_ROW_ADDR_WIDTH  = 16,
          CLK_CYC               = 2.5;

//Global.
reg                               clk;
reg                               rst_n;
//array_refresh.
reg                               array_rf_start;
wire                              array_rf_done;
//Timing config.
reg   [7:0]                       array_tRAS;
reg   [7:0]                       array_tRP;
//array_interface.
wire                              array_cs_n;
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]  array_raddr;

task rf_start;
  begin
    @(posedge clk) begin
      array_rf_start  <=  1'b1;
    end
    @(posedge clk) begin
      array_rf_start  <=  1'b0;
    end
  end
endtask

//Generate clk.
initial begin
  #0;
  clk = 0;
  forever #(CLK_CYC)  clk = ~clk;
end

initial begin
  rst_n           = 0;
  //array_refresh.
  array_rf_start  = 0;
  //Timing config.
  array_tRAS      = 8'h10;
  array_tRP       = 8'h6;

  repeat(3) @(posedge clk);
  rst_n = 1;

  repeat(3) @(posedge clk);
  rf_start();

  wait(array_rf_done);
  repeat(9) @(posedge clk);
  $finish();
end

array_refresh u_array_refresh(
  .clk            (clk),
  .rst_n          (rst_n),
  .array_rf_start (array_rf_start),
  .array_rf_done  (array_rf_done),
  .array_tRAS     (array_tRAS),
  .array_tRP      (array_tRP),
  .array_cs_n     (array_cs_n),
  .array_raddr    (array_raddr)
);

endmodule

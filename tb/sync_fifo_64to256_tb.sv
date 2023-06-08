module sync_fifo_64to256_tb();

parameter DATA_WIDTH_I  = 64;
parameter DATA_WIDTH_O  = 256;
parameter FIFO_DEPTH    = 8;
parameter OUTPUT_MODE   = 0; //0: comb output, 1: sque output

parameter CLK_CYC       = 2.5; //2.5ns --> 400MHz

//Global signals.
reg                       clk;
reg                       rst_n;

//FIFO write.
reg                       fifo_wr;
reg   [DATA_WIDTH_I-1:0]  fifo_din;
wire                      fifo_full;
//FIFO read.
reg                       fifo_rd;
wire  [DATA_WIDTH_O-1:0]  fifo_dout;
wire                      fifo_empty;

integer cnt;
integer rand0;
integer wait_cyc;

always #(CLK_CYC/2) clk = ~clk;

initial begin
  clk       = 0;
  rst_n     = 0;
  fifo_wr   = 0;
  fifo_din  = 0;
  fifo_rd   = 0;

  repeat(10) @(posedge clk); #0.1;
  rst_n =  1;
  repeat(3) @(posedge clk); #0.1;

  //Write data in FIFO ------------------------------------
  for(cnt=0; cnt<16; cnt=cnt+1) begin
    if(!fifo_full) begin
      fifo_wr   = 1;
      fifo_din  = {64{cnt[0]}};
      rand0     = {$random()}%8; //0~7
      @(posedge clk); #0.1;
      fifo_wr   = 0;
    end

    //wait_cyc
    if(rand0<5) begin
      wait_cyc  = {$random()}%4; //0~3
      if(wait_cyc==0)
        wait_cyc = 1;

      repeat(wait_cyc) @(posedge clk); #0.1;
    end
  end

  //Read data from FIFO -----------------------------------
  @(posedge clk); #0.1;
  for(cnt=0; cnt<16; cnt=cnt+1) begin
      if(!fifo_empty) begin
      fifo_rd = 1;
      rand0   = {$random()}%8; //0~7
      @(posedge clk); #0.1;
      fifo_rd = 0;
    end

    //wait_cyc
    if(rand0<8) begin
      wait_cyc  = {$random()}%4; //0~3
      if(wait_cyc==0)
        wait_cyc = 1;

      repeat(wait_cyc) @(posedge clk); #0.1;
    end
  end

  repeat(20) @(posedge clk); #0.1;
  $display("Info: Simulation completed.");
  $finish();
end

  sync_fifo_64to256 #(
    .DATA_WIDTH_I(DATA_WIDTH_I),
    .DATA_WIDTH_O(DATA_WIDTH_O),
    .FIFO_DEPTH(FIFO_DEPTH),
    .OUTPUT_MODE(OUTPUT_MODE)
    ) u_sync_fifo_64to256 (
    .clk        (clk),
    .rst_n      (rst_n),
    .fifo_wr    (fifo_wr),
    .fifo_din   (fifo_din),
    .fifo_full  (fifo_full),
    .fifo_rd    (fifo_rd),
    .fifo_dout  (fifo_dout),
    .fifo_empty (fifo_empty)
  );

endmodule

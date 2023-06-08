module array_write_tb();
 
parameter ARRAY_COL_ADDR_WIDTH    = 6,
          ARRAY_ROW_ADDR_WIDTH    = 16,
          ARRAY_DATA_WIDTH        = 64,
          ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    ARRAY_DATA_WIDTH, //3 is rw_flag, sof and eof.
          CLK_CYC                 = 2.5;

//Global.
reg                                 clk;
reg                                 rst_n;
//array_write frame.
reg                                 array_wframe_valid;
reg   [ARRAY_FRAME_DATA_WIDTH-1:0]  array_wframe_data;
wire                                array_wframe_ready;
reg                                 array_wr_start;
wire                                array_wr_done;
//Timing config.
reg   [7:0]                         array_tRCD_WR;
reg   [7:0]                         array_tRAS;
reg   [7:0]                         array_tWR;
reg   [7:0]                         array_tRP;
//array_interface.
wire                                array_cs_n;
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr;
wire                                array_caddr_vld_wr;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_wr;
wire                                array_wdata_vld;
wire  [ARRAY_DATA_WIDTH-1:0]        array_wdata;

//task wframe2array ---------------------------------------
integer wframe_cnt;
task wframe2array;
  input [7:0] frame_len;
  begin
    for(wframe_cnt=0; wframe_cnt<((frame_len+1)*4); wframe_cnt=wframe_cnt+1) begin
      if(wframe_cnt==0) begin //1st frame.
        @(posedge clk) begin 
          //array_wframe_data.
          array_wframe_data[21:0]   <=  wframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_wframe_data[85:22]  <=  wframe_cnt+'d10; //[85:22]: data.
          array_wframe_data[86]     <=  1'b1; //Write flag.
          array_wframe_data[87]     <=  1'b1; //sof.
          array_wframe_data[88]     <=  1'b0; //eof.
          //array_wframe_valid.
          array_wframe_valid        <=  1'b1;
          array_wr_start            <=  1'b1;
        end
      end else if (wframe_cnt==((frame_len+1)*4)-1) begin //Last frame.
        @(posedge clk) begin
          //array_wframe_data.
          array_wframe_data[21:0]   <=  wframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_wframe_data[85:22]  <=  wframe_cnt+'d10; //[85:22]: data.
          array_wframe_data[86]     <=  1'b1; //Write flag.
          array_wframe_data[87]     <=  1'b0; //sof.
          array_wframe_data[88]     <=  1'b1; //eof.
          //array_wframe_valid.
          array_wframe_valid        <=  1'b1;
        end
      end else begin //Other frame.
        @(posedge clk) begin
          //array_wframe_data.
          array_wframe_data[21:0]   <=  wframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_wframe_data[85:22]  <=  wframe_cnt+'d10; //[85:22]: data.
          array_wframe_data[86]     <=  1'b1; //Write flag.
          array_wframe_data[87]     <=  1'b0; //sof.
          array_wframe_data[88]     <=  1'b0; //eof.
          //array_wframe_valid.
          array_wframe_valid        <=  1'b1;
          array_wr_start            <=  1'b0;
        end
      end
      #1;
      wait(array_wframe_ready);
    end
    @(posedge clk) begin
      array_wframe_valid    <=  1'b0;
      array_wframe_data[88] <=  1'b0; //eof.
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
  #0;
  //Global.
  rst_n               = 0;
  //array_write frame.
  array_wframe_valid  = 0;
  array_wframe_data   = 0;
  array_wr_start      = 0;
  //Timing config.
  array_tRCD_WR       = 8'h7;
  array_tRAS          = 8'h10;
  array_tWR           = 8'h6;
  array_tRP           = 8'h6;

  repeat(3) @(posedge clk);
  rst_n = 1;

  repeat(3) @(posedge clk);
  wframe2array('d1); //(frame_len)

  wait(array_wr_done);
  repeat(9) @(posedge clk);
  $finish();
end

//inst
array_write u_array_write (
  //Global                
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
  .array_cs_n         (array_cs_n),
  .array_raddr        (array_raddr),
  .array_caddr_vld_wr (array_caddr_vld_wr),
  .array_caddr_wr     (array_caddr_wr),
  .array_wdata_vld    (array_wdata_vld),
  .array_wdata        (array_wdata)
);

endmodule

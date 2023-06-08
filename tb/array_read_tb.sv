module array_read_tb();
 
parameter ARRAY_COL_ADDR_WIDTH    = 6,
          ARRAY_ROW_ADDR_WIDTH    = 16,
          ARRAY_DATA_WIDTH        = 64,
          ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    ARRAY_DATA_WIDTH, //3 is rw_flag, sof and eof.
          CLK_CYC                 = 2.5;

//Global.
reg                                 clk;
reg                                 rst_n;
//array_rdite frame.
reg                                 array_rframe_valid;
reg   [ARRAY_FRAME_DATA_WIDTH-1:0]  array_rframe_data;
wire                                array_rframe_ready;
reg                                 array_rd_start;
wire                                array_rd_done;
//Timing config.
reg   [7:0]                         array_tRCD_RD;
reg   [7:0]                         array_tRAS;
reg   [7:0]                         array_tRTP;
reg   [7:0]                         array_tRP;
//array_interface.
wire                                array_cs_n;
wire  [ARRAY_ROW_ADDR_WIDTH-1:0]    array_raddr;
wire                                array_caddr_vld_rd;
wire  [ARRAY_COL_ADDR_WIDTH-1:0]    array_caddr_rd;
reg                                 array_rdata_vld;
reg   [ARRAY_DATA_WIDTH-1:0]        array_rdata;
//sync_array_r
wire                                sync_array_rdata_vld;
wire  [ARRAY_DATA_WIDTH-1:0]        sync_array_rdata;

//task rframe2array ---------------------------------------
integer rframe_cnt;
task rframe2array;
  input [7:0] frame_len;
  begin
    for(rframe_cnt=0; rframe_cnt<((frame_len+1)*4); rframe_cnt=rframe_cnt+1) begin
      if(rframe_cnt==0) begin //1st frame.
        @(posedge clk) begin 
          //array_rframe_data.
          array_rframe_data[21:0]   <=  rframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_rframe_data[85:22]  <=  'd0; //[85:22]: data.
          array_rframe_data[86]     <=  1'b0; //read flag.
          array_rframe_data[87]     <=  1'b1; //sof.
          array_rframe_data[88]     <=  1'b0; //eof.
          //array_rframe_valid.
          array_rframe_valid        <=  1'b1;
          array_rd_start            <=  1'b1;
        end
      end else if (rframe_cnt==((frame_len+1)*4)-1) begin //Last frame.
        @(posedge clk) begin
          //array_rframe_data.
          array_rframe_data[21:0]   <=  rframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_rframe_data[85:22]  <=  'd0; //[85:22]: data.
          array_rframe_data[86]     <=  1'b0; //read flag.
          array_rframe_data[87]     <=  1'b0; //sof.
          array_rframe_data[88]     <=  1'b1; //eof.
          //array_rframe_valid.
          array_rframe_valid        <=  1'b1;
        end
      end else begin //Other frame.
        @(posedge clk) begin
          //array_rframe_data.
          array_rframe_data[21:0]   <=  rframe_cnt[21:0]+'d65; //[5:0]: caddr, [21:6] raddr.
          array_rframe_data[85:22]  <=  'd0; //[85:22]: data.
          array_rframe_data[86]     <=  1'b0; //read flag.
          array_rframe_data[87]     <=  1'b0; //sof.
          array_rframe_data[88]     <=  1'b0; //eof.
          //array_rframe_valid.
          array_rframe_valid        <=  1'b1;
          array_rd_start            <=  1'b0;
        end
      end
      #1;
      wait(array_rframe_ready);
    end
    @(posedge clk) begin
      array_rframe_valid    <=  1'b0;
      array_rframe_data[88] <=  1'b0; //eof.
    end
  end
endtask

//task rdata ----------------------------------------------
integer rdata_cnt;
task rdata;
  input [7:0] frame_len;
  begin
    for(rdata_cnt=0; rdata_cnt<((frame_len+1)*4); rdata_cnt=rdata_cnt+1) begin
      @(negedge clk) begin
        array_rdata_vld <=  1'b0;
        array_rdata     <=  {{$random()}, {$random()}};
      end
      @(negedge clk) begin
        array_rdata_vld <=  1'b1;
      end
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
  //array_rdite frame.
  array_rframe_valid  = 0;
  array_rframe_data   = 0;
  array_rd_start      = 0;
  //Timing config.
  array_tRCD_RD       = 8'h7;
  array_tRAS          = 8'h10;
  array_tRTP          = 8'h3;
  array_tRP           = 8'h6;
  //array_interface
  array_rdata         = 0;
  array_rdata_vld     = 1;

  repeat(3) @(posedge clk);
  rst_n = 1;

  fork
    begin //Fork 1: send rframe.
      repeat(3) @(posedge clk);
      rframe2array('d1); //(frame_len)
      wait(array_rd_done);
    end
    begin //Fork 2: return rdata.
      @(negedge array_cs_n);
      repeat(array_tRCD_RD) @(posedge clk);
      repeat(3) @(posedge clk); //tRD: read data delay.
      rdata('d1); //(frame_len)
    end
  join

  repeat(9) @(posedge clk);
  $finish();
end

//inst
array_read u_array_read (
  //Global                
  .clk                  (clk),                
  .rst_n                (rst_n),
  //array_rdite frame.      
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
  .array_cs_n           (array_cs_n),
  .array_raddr          (array_raddr),
  .array_caddr_vld_rd   (array_caddr_vld_rd),
  .array_caddr_rd       (array_caddr_rd),
  .array_rdata_vld      (array_rdata_vld),
  .array_rdata          (array_rdata),
  //sync_array_r
  .sync_array_rdata_vld (sync_array_rdata_vld),
  .sync_array_rdata     (sync_array_rdata)
);

endmodule

module arbiter_tb();
parameter ARRAY_COL_ADDR_WIDTH    = 6,
          ARRAY_ROW_ADDR_WIDTH    = 16,
          ARRAY_DATA_WIDTH        = 64,
          AXI_LEN_WIDTH           = 8,
          FRAME_DATA_WIDTH        = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    AXI_LEN_WIDTH + ARRAY_DATA_WIDTH,
          ARRAY_FRAME_DATA_WIDTH  = 3 + ARRAY_COL_ADDR_WIDTH + ARRAY_ROW_ADDR_WIDTH +
                                    ARRAY_DATA_WIDTH,
          CLK_CYC                 = 2.5;

//Global signals.
reg                                 clk;
reg                                 rst_n;
//w_frame signals.
reg                                 axi2arb_wframe_valid;
wire                                axi2arb_wframe_ready;
reg   [FRAME_DATA_WIDTH-1:0]        axi2arb_wframe_data;
//r_frame signals.
reg                                 axi2arb_rframe_valid;
wire                                axi2arb_rframe_ready;
reg   [FRAME_DATA_WIDTH-1:0]        axi2arb_rframe_data;
//internal_frame signals.
wire                                axi2array_frame_valid;
reg                                 axi2array_frame_ready;
wire  [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2array_frame_data;
//aix bus read and write priority.
reg   [1:0]                         axi_rw_prio;
reg                                 mc_en;

integer wframe_data_cnt;
integer rframe_data_cnt;

//task send_rwframe.
task send_rwframe;
  input [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2arb_wframe_data_t;
  input [ARRAY_FRAME_DATA_WIDTH-1:0]  axi2arb_rframe_data_t;
  input [AXI_LEN_WIDTH-1:0]           wframe_len_t;
  input [AXI_LEN_WIDTH-1:0]           rframe_len_t;
  begin
    fork
      //fork 1: wframe data.
      begin
        for(wframe_data_cnt=0; wframe_data_cnt<((wframe_len_t+1)*4); wframe_data_cnt=wframe_data_cnt+1) begin
          @(posedge clk) begin
            axi2arb_wframe_valid  <=  1'b1;
            axi2arb_wframe_data   <=  {wframe_len_t, axi2arb_wframe_data_t};
            if(wframe_data_cnt==0) begin //sof
              axi2arb_wframe_data[87] <=  1'b1;
            end else begin
              axi2arb_wframe_data[87] <=  1'b0;
            end
            if(wframe_data_cnt==((wframe_len_t+1)*4-1)) begin //eof
              axi2arb_wframe_data[88] <=  1'b1;
            end else begin
              axi2arb_wframe_data[88] <=  1'b0;
            end
          end
          #1;
          wait(axi2arb_wframe_ready);
          @(posedge clk) begin
            axi2arb_wframe_valid  <=  1'b0;
          end
        end
      end
      //fork 2: rframe data.
      begin
        for(rframe_data_cnt=0; rframe_data_cnt<((rframe_len_t+1)*4); rframe_data_cnt=rframe_data_cnt+1) begin
          @(posedge clk) begin
            axi2arb_rframe_valid  <=  1'b1;
            axi2arb_rframe_data   <=  {rframe_len_t, axi2arb_rframe_data_t};
            if(rframe_data_cnt==0) begin //sof
              axi2arb_rframe_data[87] <=  1'b1;
            end else begin
              axi2arb_rframe_data[87] <=  1'b0;
            end
            if(rframe_data_cnt==((rframe_len_t+1)*4-1)) begin //eof
              axi2arb_rframe_data[88] <=  1'b1;
            end else begin
              axi2arb_rframe_data[88] <=  1'b0;
            end
          end
          #1;
          wait(axi2arb_rframe_ready);
          @(posedge clk) begin
            axi2arb_rframe_valid  <=  1'b0;
          end
        end
      end
    join
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
  axi2arb_wframe_valid  = 0;
  axi2arb_wframe_data   = 0;
  axi2arb_rframe_valid  = 0;
  axi2arb_rframe_data   = 0;
  axi2array_frame_ready = 1;
  axi_rw_prio           = 0;
  mc_en                 = 1;
  
  repeat(3) @(posedge clk);
  rst_n = 1;

  //RD prio.
  repeat(5) @(posedge clk);
  send_rwframe(89'd1, 89'd0, 8'd1, 8'd2);

  //WR prio.
  axi_rw_prio = 1;
  repeat(5) @(posedge clk);
  send_rwframe(89'd1, 89'd0, 8'd1, 8'd2);

  //round robin.
  axi_rw_prio = 2;
  repeat(5) @(posedge clk);
  send_rwframe(89'd1, 89'd0, 8'd1, 8'd2);
  repeat(5) @(posedge clk);
  send_rwframe(89'd1, 89'd0, 8'd1, 8'd2);

  repeat(9) @(posedge clk);
  $finish();
end

arbiter u_arbiter (
  //Global signals.
  .clk                  (clk),                
  .rst_n                (rst_n),
  //w_frame signals.
  .axi2arb_wframe_valid (axi2arb_wframe_valid),
  .axi2arb_wframe_ready (axi2arb_wframe_ready),
  .axi2arb_wframe_data  (axi2arb_wframe_data),
  //w_frame signals.
  .axi2arb_rframe_valid (axi2arb_rframe_valid),
  .axi2arb_rframe_ready (axi2arb_rframe_ready),
  .axi2arb_rframe_data  (axi2arb_rframe_data),
  //internal frame signal.
  .axi2array_frame_valid(axi2array_frame_valid),
  .axi2array_frame_ready(axi2array_frame_ready),
  .axi2array_frame_data (axi2array_frame_data),
  //apb_cfg signals.
  .axi_rw_prio          (axi_rw_prio),
  .mc_en                (mc_en)
  );

endmodule

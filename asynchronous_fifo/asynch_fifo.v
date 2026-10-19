module async_fifo #(parameter DATA_WIDTH= 8,
                    parameter DEPTH = 16,
                    parameter ADDR_WIDTH = 4)
                    ( input wr_clk,
                   input rd_clk,
                   input wr_enb,
                   input rd_enb,
                   input rst_n,
                   input [DATA_WIDTH-1:0] din,
                   output reg [DATA_WIDTH-1:0] dout,
                   output full,
                   output empty);
                   
                   
                   reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
                   
                   reg [ADDR_WIDTH:0] wr_bin,rd_bin;
                   reg [ADDR_WIDTH:0] wr_gray,rd_gray;
                   
                   reg [ADDR_WIDTH:0] wr_gray_syn1,wr_gray_syn2;
                   reg [ADDR_WIDTH:0] rd_gray_syn1,rd_gray_syn2;
                   
                   //binary to gray function
                   function [ADDR_WIDTH:0] b2g(input [ADDR_WIDTH:0]b);
                   b2g = b ^(b>>1);
                   endfunction
                   
                   //sychronize write pointer to read domain
                   always @(posedge rd_clk or posedge rst_n) begin
                   if (rst_n) begin
                   wr_gray_syn1 <= 0;
                   wr_gray_syn2 <= 0;
                   end else begin
                   wr_gray_syn1 <= wr_gray;
                   wr_gray_syn2 <= wr_gray_syn1;
                   end
                   end
                   
                   //synchronize read pointer yo write doamin
                   always @(posedge wr_clk or posedge  rst_n)begin
                   if (rst_n) begin
                   rd_gray_syn1 <= 0;
                   rd_gray_syn2 <= 0;
                   end else begin
                   rd_gray_syn1 <= rd_gray;
                   rd_gray_syn2 <= rd_gray_syn1;
                   end
                   end
                   
                  assign full  = (b2g(wr_bin + 1) == {~rd_gray_syn2[ADDR_WIDTH:ADDR_WIDTH-1], rd_gray_syn2[ADDR_WIDTH-2:0]});
                  assign empty = (wr_gray_syn2 == rd_gray);
                  
                  //write domain
                  always @(posedge wr_clk or posedge rst_n) begin
                  if (rst_n) begin
                  wr_gray <= 0;
                  wr_bin <= 0;
                  end else if (!full && wr_enb) begin
                  mem[wr_bin[ADDR_WIDTH-1:0]] <= din;
                  wr_bin <= wr_bin + 1;
                  wr_gray <= b2g(wr_bin+1);
                  end
                  end
                   
                  //read domain
                  always @(posedge rd_clk or posedge rst_n) begin
                  if(rst_n) begin
                  rd_gray <= 0;
                  rd_bin <= 0;
                  dout <= 0;
                  end else if (!empty && rd_enb) begin
                  dout <= mem[rd_bin[ADDR_WIDTH-1:0]];
                  rd_bin <= rd_bin + 1;
                  rd_gray <= b2g(rd_bin + 1);
                  end
                  end
endmodule

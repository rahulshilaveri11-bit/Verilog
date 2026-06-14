module TOP_FIFO(
    input clk,rst,input [7:0] data_top_in,output [7:0] data_top_out
    );
    wire [7:0] data_out_temp;
    wire write_enb;
    wire read_enb;
    wire [7:0] data_out_fifo;
    
    mod_a MA(clk,rst,data_top_in,data_out_temp,write_enb);
    FIFO_8x8 FIFO(clk,rst,write_enb,read_enb,data_out_temp,data_out_fifo,full,empty);
    mod_b MB(clk,rst,data_out_fifo,data_top_out,read_enb);
    
endmodule

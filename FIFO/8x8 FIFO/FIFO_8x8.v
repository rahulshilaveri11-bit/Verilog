module FIFO_8x8(
    input clk,rst,write_enb,read_enb,
    input [7:0] data_in,
    output reg [7:0] data_out,
    output full,empty

    );
    reg [2:0] write_ptr;
    reg [2:0]read_ptr;
    reg [7:0] mem [7:0];
    integer i;
    
    always @(posedge clk) 
      begin
       if(rst) begin
        write_ptr <= 0;
        read_ptr <= 0;
        data_out <= 0;
        for ( i = 0;  i <8 ; i= i +1) 
          mem[i] <= 0;
          end
       else begin
         if (write_enb && !full) begin
          mem[write_ptr] <= data_in;
          write_ptr <= write_ptr + 1'b1;
          end
         if (read_enb && !empty) begin
          data_out <= mem[read_ptr];
          read_ptr <= read_ptr + 1'b1;  
          end
        end
       end
        assign full = ((write_ptr + 1'b1 ) == read_ptr )? 1'b1: 1'b0;
        assign empty = (write_ptr == read_ptr);
endmodule

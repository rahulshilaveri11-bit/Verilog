module message_padding(
input clk,rst, input valid_input,// 1 when input msg in valid
input [7:0] byte_in,// one msg byte
input last_byte,
output reg [511:0] block_out, //padded block
output reg block_valid,// 1 when block_out is resdy
output reg last_block //1 when this is last block
    );
    
    reg [7:0] buf_bytes[63:0];// memory of 512 bits or 64 bytes used to build the current block
    reg [6:0] buf_ptr; //tracks byte index form 0 to 63
    reg [63:0] total_bits ; //total length of the message bit 
    reg padding_done;
    reg flush_is_last;
    reg  [2:0] next_state_after_flush;
    integer i;
    
    parameter IDLE             = 3'b000;
    parameter RECEIVING        = 3'b001;
    parameter PADDING          = 3'b010;
    parameter EXTRA_BLOCK_FILL = 3'b011;
    parameter FLUSH            = 3'b100;

    reg [2:0] STATE;
    
    task flush_block;
    input is_last; //take one input to denote if this the final block
    integer j;
    reg [511:0] assembled;
    begin
      assembled = 512'd0; //converts the 64 byte arry into single 512 bit register
        for(j=0;j<64;j=j+1)
         begin
         assembled[511-(j*8) -:8] = buf_bytes[j] ; //maps the buf_bytes[0] to the MSB of the 
         end
        block_out <= assembled;
        block_valid <= 1'b1;
        last_block <= is_last;
       end
    endtask
     
     //main the sequential block FSM
     always @(posedge clk or posedge rst)
        begin
          if (rst) begin
            buf_ptr <= 7'd0;
            total_bits <= 64'b0;
            padding_done <= 1'b0;
            next_state_after_flush <= 1'b0;
            flush_is_last <= 0;
            block_valid <= 1'b0;
            last_block <= 1'b0;
            block_out <= 512'b0;
            STATE <= IDLE;
            for( i=0;i<64;i=i+1)
              buf_bytes[i] <= 8'h00;
          end else begin
            //default turn them off
            block_valid <= 1'b0;
            last_block <= 1'b0;
            
          case(STATE)
          
          IDLE : begin
                 if (valid_input) begin
                    buf_bytes[0] <= byte_in;
                    buf_ptr <= 7'd1;
                    total_bits <= 64'd8;
                    padding_done <= 1'b0;
                    
                    if (last_byte)
                       STATE <= PADDING;
                    else
                       STATE <= RECEIVING;
                    end
                 end
                 
           RECEIVING :  begin
                        if(valid_input) begin
                          buf_bytes[buf_ptr] <= byte_in;
                          total_bits <= total_bits + 64'd8;
                        if(last_byte) begin
                          if (buf_ptr == 7'd63) begin
                            flush_is_last <= 1'b0;
                            next_state_after_flush <= PADDING;
                            padding_done <= 1'b0;
                            STATE <= FLUSH;
                          end else begin
                            buf_ptr <= buf_ptr + 1'b1;
                            STATE <= PADDING;
                        end
                        end else if (buf_ptr == 7'd63) begin
                          flush_is_last <= 1'b0;
                          next_state_after_flush <= RECEIVING;
                          STATE <= FLUSH;
                        end else begin
                          buf_ptr <= buf_ptr + 1'b1;
                        end
                      end
                    end     
          PADDING : begin
                     if (~padding_done) begin
                     buf_bytes[buf_ptr] <= 8'h80;   // Fixed: non-blocking
                     buf_ptr <= buf_ptr + 1;
                     padding_done <= 1'b1;
                    end
                else if (buf_ptr <= 7'd56) begin   
                     if(buf_ptr < 7'd56) begin
                        buf_bytes[buf_ptr] <= 8'h00;
                        buf_ptr <= buf_ptr + 1;
                     end else begin
                        buf_bytes[56] <= total_bits[63:56];
                        buf_bytes[57] <= total_bits[55:48];
                        buf_bytes[58] <= total_bits[47:40];
                        buf_bytes[59] <= total_bits[39:32];
                        buf_bytes[60] <= total_bits[31:24];
                        buf_bytes[61] <= total_bits[23:16];
                        buf_bytes[62] <= total_bits[15:8];
                        buf_bytes[63] <= total_bits[7:0];
                        flush_is_last <= 1'b1;
                        next_state_after_flush <= IDLE;
                        STATE <= FLUSH;
               end
               end else begin
                        if(buf_ptr < 7'd63) begin
                        buf_bytes[buf_ptr] <= 8'h00;
                        buf_ptr <= buf_ptr + 1;
               end else begin
                        flush_is_last <= 1'b0;
                        next_state_after_flush <= EXTRA_BLOCK_FILL;
                        STATE <= FLUSH;
                        end
                    end
                end
           FLUSH : begin
                    flush_block(flush_is_last);
                    for(i=0;i<64;i=i+1) //clearing buffer for the next block
                    buf_bytes[i] <= 8'h0;
                    buf_ptr <= 7'd0;
                    STATE <= next_state_after_flush;
                  end           
           EXTRA_BLOCK_FILL : begin
                for(i=0;i<56;i=i+1) begin
                  buf_bytes[i] <= 8'h00;
                    // Length field
                buf_bytes[56] <= total_bits[63:56];
                buf_bytes[57] <= total_bits[55:48];
                buf_bytes[58] <= total_bits[47:40];
                buf_bytes[59] <= total_bits[39:32];
                buf_bytes[60] <= total_bits[31:24];
                buf_bytes[61] <= total_bits[23:16];
                buf_bytes[62] <= total_bits[15:8];
                buf_bytes[63] <= total_bits[7:0];
                flush_is_last <= 1'b1;   // this IS the last block
                next_state_after_flush <= IDLE;
                STATE <= FLUSH;
                  end  
                end

            endcase
        end
    end

endmodule   

module axi_top_ram#(parameter  data_width = 32,
                    parameter addr_width = 16,
                    parameter depth = 65536)(
                    
                    input aclk,arstn,
                    
                    //wirte address channel
                    input [addr_width - 1 : 0] s_axi_awaddr,
                    input s_axi_awvalid,output reg s_axi_awready,
                    
                    //write datta channel
                    input [data_width - 1 : 0] s_axi_wdata,
                    input [data_width/8-1:0] s_axi_wstrb,
                    input s_axi_wvalid,output reg s_axi_wready,
                    
                    //write response channel
                     input s_axi_bready,
                     output reg [1:0] s_axi_bresp,
                     output reg s_axi_bvalid,
                     
                     //read data channel
                     output reg [data_width - 1 : 0] s_axi_rdata,
                     output reg [1:0] s_axi_rresp,
                     output reg s_axi_rvalid,
                     input s_axi_rready,
                     
                     //read address channel
                     input [addr_width - 1 : 0] s_axi_araddr,
                     input s_axi_arvalid,
                     output reg s_axi_arready);
                     
                     localparam resp_okey = 2'b00;
                     localparam resp_slv_err = 2'b10;
                     
                     //parameters of write fsm 
                     localparam WR_IDLE = 2'b00;
                     localparam WR_DATA = 2'b01;
                     localparam WR_RESP = 2'b10;
                     
                     //parameters of read fsm
                     localparam RD_IDLE = 2'b00;
                     localparam RD_ADDR = 2'b01;
                     localparam RD_DATA = 2'b10;
                     
                     //internal signals
                     reg [1:0] write_state,next_write_state;
                     reg [1:0] read_state,next_read_state;
                      reg [addr_width - 1 : 0] write_addr_reg,read_addr_reg;
                      reg [data_width - 1 : 0] write_data_reg;
                      reg [data_width/8-1:0] write_strb_reg;
                      
                     
                     //RAM interfcae signlas
                     reg ram_write_enb;
                     reg [addr_width - 1 : 0] ram_addr;
                     reg [data_width - 1 : 0] ram_wdata;
                     wire [data_width - 1 : 0] ram_rdata;
                     
                     //instansiating RAM (pass depth parameter)
                     ram_design #(
                         .DATA_WIDTH(data_width),
                         .ADDR_WIDTH(addr_width),
                         .DEPTH(depth)
                     ) dut (
                         .clk(aclk),
                         .rst_n(arstn),
                         .write_enb(ram_write_enb),
                         .addr(ram_addr),
                         .wdata(ram_wdata),
                         .rdata(ram_rdata),
                         .wstrb(write_strb_reg)
                     );
                     
                     
                     //write adddress channel
                     always @(posedge aclk) begin
                        if(~arstn) begin
                           s_axi_awready <= 0;
                           write_addr_reg <= {addr_width{1'b0}};
                           end
                        else begin
                        case(write_state)
                           WR_IDLE : begin
                                    s_axi_awready <= 1'b1;
                                    if(s_axi_awready && s_axi_awvalid) begin
                                       write_addr_reg <= s_axi_awaddr;
                                       s_axi_awready <= 1'b0;
                                       end
                                       end
                                    default : begin s_axi_awready <= 1'b0; end
                         endcase
                         end
                         end
                                       
                       //WRITE data channel
                       always @(posedge aclk) begin
                           if (~arstn) begin
                              s_axi_wready <= 1'b0;
                              write_data_reg <= {data_width{1'b0}};
                              write_strb_reg <= {data_width/8{1'b0}};
                              end
                           else begin
                                case(write_state)
                                   WR_DATA : begin
                                               s_axi_wready <= 1'b1;
                                               //Only capture data on valid handshake
                                               if (s_axi_wvalid && s_axi_wready) begin
                                                      write_data_reg <= s_axi_wdata;
                                                      write_strb_reg <= s_axi_wstrb;
                                                      s_axi_wready   <= 1'b0;
                                               end
                                             end
                                             default: begin
                                                        s_axi_wready <= 1'b0;
                                                      end
                                             endcase
                                            end
                                         end
                               
                      //WRITE RESOPNCE channel
                   always @(posedge aclk) begin
                          if (~arstn) begin
                             s_axi_bvalid <= 1'b0;
                             s_axi_bresp <= resp_okey;
                             end
                          else begin
                               if(write_state == WR_RESP && !s_axi_bvalid) begin
                                  s_axi_bvalid <= 1'b1;
                                  s_axi_bresp <= resp_okey;
                                  end
                               else if (s_axi_bvalid && s_axi_bready) begin
                                  s_axi_bvalid <= 1'b0;
                               end
                            end    
                           end 
                                    
                         //READ address chaneel
                         always @(posedge aclk) begin
                            if(~arstn) begin
                               s_axi_arready <=  1'b0;
                               read_addr_reg <= {addr_width{1'b0}};
                               end
                            else begin
                              case(read_state) 
                                     RD_IDLE : begin
                                             s_axi_arready <= 1'b1;
                                             if (s_axi_arready && s_axi_arvalid) begin
                                                 read_addr_reg <= s_axi_araddr;
                                                 s_axi_arready <= 1'b0;
                                              end
                                             end
                                             default : begin s_axi_arready <= 1'b0 ; end
                                             endcase
                                            end 
                                            end
                                   
                            // Read data channel
                              always @(posedge aclk) begin
                               if(~arstn) begin
                                  s_axi_rdata <= {data_width{1'b0}};
                                  s_axi_rresp <= resp_okey;
                                  s_axi_rvalid <= 1'b0;
                               end
                               else begin
                                   case(read_state)
                                     RD_DATA: begin
                                                if (!s_axi_rvalid) begin
                                                    // Assert rvalid once with the data
                                                    s_axi_rdata  <= ram_rdata;
                                                    s_axi_rresp  <= resp_okey;
                                                    s_axi_rvalid <= 1'b1;
                                                end
                                                else if (s_axi_rvalid && s_axi_rready) begin
                                                    // Handshake complete, deassert
                                                    s_axi_rvalid <= 1'b0;
                                                end
                                            end
                                            default: begin
                                                        s_axi_rvalid <= 1'b0;
                                                     end
                                             endcase
                                            end
                                         end

                                 // Write FSM - Sequential
                                 always @(posedge aclk) begin
                                     if (~arstn)
                                        write_state <= WR_IDLE;
                                     else
                                        write_state <= next_write_state;
                                     end
                                     
                                     //write FSM combinational (FIX: use blocking assignments)
                                     always @(*) begin
                                       next_write_state = write_state;
                                       case(write_state)
                                         WR_IDLE : begin
                                                    if(s_axi_awready && s_axi_awvalid) 
                                                    next_write_state = WR_DATA;
                                                   end
                                         WR_DATA : begin 
                                                    if(s_axi_wready && s_axi_wvalid)
                                                    next_write_state = WR_RESP;
                                                   end
                                         WR_RESP : begin
                                                    if (s_axi_bready && s_axi_bvalid)
                                                    next_write_state = WR_IDLE;
                                                  end
                                         default : begin next_write_state = WR_IDLE; end
                                         endcase
                                       end
                                       
                                    //read FSm sequnetial
                                      always @(posedge aclk) begin
                                         if (~arstn) 
                                           read_state <= RD_IDLE;
                                         else 
                                           read_state <= next_read_state;
                                         end
                                        
                                        //read FSM combinational
                                        always @(*) begin
                                        next_read_state = read_state;
                                        case(read_state)
                                           RD_IDLE : begin
                                                      if(s_axi_arready && s_axi_arvalid)
                                                      next_read_state = RD_ADDR;
                                                     end 
                                           RD_ADDR : next_read_state = RD_DATA;
                                           
                                           RD_DATA : begin
                                                      if (s_axi_rvalid && s_axi_rready)
                                                      next_read_state = RD_IDLE;
                                                    end
                                           default : next_read_state = RD_IDLE;
                                        endcase
                                      end
                                   
                                   //unifed ram contoller 
                                   // FIX: Use s_axi_wdata directly instead of write_data_reg
                                   // to avoid capturing stale data due to same-cycle non-blocking update
                                   always @(posedge aclk) begin
                                     if(!arstn) begin
                                         ram_addr <= {addr_width{1'b0}};
                                         ram_write_enb <= 1'b0;
                                         ram_wdata <= {data_width{1'b0}};
                                         end
                                         else begin
                                            ram_write_enb <= 1'b0; //default no write
                                             if (write_state == WR_DATA && s_axi_wvalid && s_axi_wready) begin
                                             ram_addr      <= write_addr_reg >> 2;  // word-align address
                                             ram_wdata     <= s_axi_wdata;          // use bus data directly
                                             write_strb_reg <= s_axi_wstrb;         // capture strobe for RAM
                                             ram_write_enb <= 1'b1;
                                             end
                                             else if (read_state == RD_ADDR) begin
                                               ram_addr <= read_addr_reg >> 2;      // word-align address
                                               end
                                             end
                                           end
                                               
                                             
endmodule

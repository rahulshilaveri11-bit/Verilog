module mac_unit #(parameter DATA_WIDTH = 16,
                  parameter ACC_WIDTH = 32)
                  (input wire clk,rst_n,
                  input wire valid_in,
                  input wire last_in,
                  input wire [DATA_WIDTH-1:0] a,b,
                  output wire signed [ACC_WIDTH-1:0] data_out,
                  output wire valid_out);


                  logic signed [ACC_WIDTH-1:0] acc;

                  always_ff @(posedge clk or negedge rst_n) begin
                    if(rst_n) begin
                        data_out <= 0;
                        valid_out <= 0;
                        acc <= 0;
                    end else begin
                        if (valid_in) begin
                            if (last_in) begin
                                data_out <= acc + (a*b);
                                valid_out <= 1;
                                acc <= 0;
                            end else 
                               begin
                                acc <= acc + (a*b);
                                valid_out <= 0;
                               end
                        end
                    end
                  end
endmodule 

                  



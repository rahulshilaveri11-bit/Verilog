module ram_design #(parameter DATA_WIDTH = 32,
                    parameter ADDR_WIDTH = 16,
                    parameter DEPTH = 65536)(
    input clk,
    input rst_n,
    input write_enb,
    input [ADDR_WIDTH - 1 : 0] addr,
    input [DATA_WIDTH - 1 : 0] wdata,
    input [DATA_WIDTH/8-1:0] wstrb,
    output reg [DATA_WIDTH - 1 : 0] rdata
);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
        end else begin
            // Read (synchronous)
            rdata <= mem[addr];
            
            // Write with byte enables
            if (write_enb) begin
                for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                    if (wstrb[i])
                        mem[addr][i*8 +: 8] <= wdata[i*8 +: 8];
                end
            end
        end
    end

endmodule

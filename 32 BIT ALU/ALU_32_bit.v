module ALU_32_bit(
input [31:0] a, b ,input [2:0] opcodes,
output reg [31:0] y
    );
    always @(a,b,opcodes) begin
      case(opcodes)
        3'b000: y = a + b;
        3'b001: y = a - b;
        3'b010: y = a * b;
        3'b011: y = a **b;
        3'b100: y = a & b;
        3'b101: y = a | b;
        3'b110: y = ~a;
        3'b111: y = ~(a | b);
        endcase
        end
endmodule

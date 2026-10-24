module ALU_32_bit#(parameter WIDTH = 32)
                  (input [WIDTH - 1 : 0] A,B,
                  input enb,
                   input [3:0] alu_ctr,
                   output reg [WIDTH - 1:0] result,
                   output zero,overflow,carry,negative );
                   
       //opcodes 
    localparam [3:0] OP_ADD  = 4'b0000;
    localparam [3:0] OP_SUB  = 4'b0001;
    localparam [3:0] OP_AND  = 4'b0010;
    localparam [3:0] OP_OR   = 4'b0011;
    localparam [3:0] OP_XOR  = 4'b0100;
    localparam [3:0] OP_NOT  = 4'b0101;
    localparam [3:0] OP_SLL  = 4'b0110;  // Shift Left Logical
    localparam [3:0] OP_SRL  = 4'b0111;  // Shift Right Logical
    localparam [3:0] OP_SRA  = 4'b1000;  // Shift Right Arithmetic
    localparam [3:0] OP_SLT  = 4'b1001;  // Set Less Than (signed)
    localparam [3:0] OP_SLTU = 4'b1010;  // Set Less Than Unsigned
    localparam [3:0] OP_LUI  = 4'b1011;  // Load Upper Immediate (pass B)
    
    //internal signals for arthimatic operation
    wire [WIDTH : 0] add_sub_result; //WODTH + 1 for carry
    wire [WIDTH - 1 : 0] b_muxed;// B or !B for sub
    wire cin;
    
    assign cin = (alu_ctr == OP_SUB) || (alu_ctr == OP_SLT) || (alu_ctr == OP_SLTU);
    assign b_muxed = cin ? 1 : 0;
    assign add_sub_result = {1'b0,A}+{1'b0,b_muxed}+{{WIDTH{1'b0}},cin};
    
    //ALU logic
    always @(*) begin
      if (~enb) 
        result = {WIDTH{1'b0}};
      else begin
        case(alu_ctr)
           OP_ADD: result = add_sub_result[WIDTH-1:0];
           OP_SUB: result = add_sub_result[WIDTH -1 :0];
           OP_AND: result = A & B;
           OP_OR : result = A | B;
           OP_XOR: result = A ^ B;
           OP_NOT: result = ~A;
           OP_SLL: result = A << B[$clog2(WIDTH)-1:0];
           OP_SRL: result = A >> B[$clog2(WIDTH)-1:0];
           OP_SRA: result = $signed(A) >>> B[$clog2(WIDTH)-1:0];
           OP_SLT: result = {{(WIDTH-1){1'b0}}, overflow ? ~add_sub_result[WIDTH-1] : add_sub_result[WIDTH-1]};
           OP_SLTU:result = {{(WIDTH-1){1'b0}}, add_sub_result[WIDTH]};   
           OP_LUI: result = B;
           default : result = {WIDTH{1'b0}};
        endcase
        end
        end   
      
      //Status flags
      assign zero = (result == {WIDTH{1'b0}});
      assign negative = result[WIDTH-1];
      assign carry = add_sub_result[WIDTH];
      
       // Signed overflow: occurs when carry into MSB != carry out of MSB
      assign overflow = (A[WIDTH-1] == b_muxed[WIDTH-1]) && 
                      (result[WIDTH-1] != A[WIDTH-1]) && 
                      ((alu_ctr == OP_ADD) || (alu_ctr == OP_SUB) || (alu_ctr == OP_SLT));
              
endmodule

module expander_block(
    input  wire        clk,
    input  wire        rst,
    input  wire        load,
    input  wire [511:0] message,
    output reg  [31:0] wt
);

    `include "sha_256_functions.vh"   // sig0, sig1, etc.

    // 16 shift registers (R1 .. R16) - each 32-bit
    reg [31:0] R [1:16];

    // Temp registers for the pipelined carry-skip adders
    reg [31:0] reg1, reg2;

    // Round counter 0 .. 63
    reg [6:0] t;

    // 16 message words (loaded from the 512-bit block)
    reg [31:0] M [0:15];

    // Adder nets
    wire [31:0] sum1, sum2, final_sum;
    wire [31:0] sig0_out, sig1_out;
    wire        c1, c2, c3;

    // Mux feeding R1: message word or feedback
    wire [31:0] mux_out;

    
    // sig1 is computed on R1 (will become R2 -> Wt-2 in next cycle)
    assign sig1_out = sig1(R[1]);

    // sig0 is computed on R14 (will become R15 -> Wt-15 in next cycle)
    assign sig0_out = sig0(R[14]);

    // CSKA1: R6 + R15  (one cycle early: they become R7 + R16 -> Wt-7 + Wt-16)
    carry_skip_adder_32bit CSKA1 (
        .a   (R[6]),
        .b   (R[15]),
        .cin (1'b0),
        .sum (sum1),
        .cout(c1)
    );

    // CSKA2: sig1_out + sig0_out
    carry_skip_adder_32bit CSKA2 (
        .a   (sig1_out),
        .b   (sig0_out),
        .cin (1'b0),
        .sum (sum2),
        .cout(c2)
    );

    // CSKA3: reg1 + reg2  (produces the feedback word Wt for t >= 16)
    carry_skip_adder_32bit CSKA3 (
        .a   (reg1),
        .b   (reg2),
        .cin (1'b0),
        .sum (final_sum),
        .cout(c3)
    );

    // Mux at the bottom of Fig. 1
    //   t = 0..14  -> feed M[t+1] into R1 so the next cycle outputs the next message word
    //   t >= 15    -> feed the feedback final_sum (W16, W17, ...)
    assign mux_out = (t < 7'd15) ? M[t + 7'd1] : final_sum;

    // Sequential logic
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 1; i <= 16; i = i + 1) R[i] <= 32'b0;
            for (i = 0; i < 16; i = i + 1) M[i] <= 32'b0;
            reg1 <= 32'b0;
            reg2 <= 32'b0;
            wt   <= 32'b0;
            t    <= 7'd0;
        end
        else if (load) begin
            // Split 512-bit message into 16 x 32-bit words
            M[0]  <= message[511:480];
            M[1]  <= message[479:448];
            M[2]  <= message[447:416];
            M[3]  <= message[415:384];
            M[4]  <= message[383:352];
            M[5]  <= message[351:320];
            M[6]  <= message[319:288];
            M[7]  <= message[287:256];
            M[8]  <= message[255:224];
            M[9]  <= message[223:192];
            M[10] <= message[191:160];
            M[11] <= message[159:128];
            M[12] <= message[127:96];
            M[13] <= message[95:64];
            M[14] <= message[63:32];
            M[15] <= message[31:0];

            // Prime R1 with M0; clear the rest of the chain
            R[1] <= message[511:480];
            for (i = 2; i <= 16; i = i + 1) R[i] <= 32'b0;

            reg1 <= 32'b0;
            reg2 <= 32'b0;
            wt   <= 32'b0;
            t    <= 7'd0;
        end
        else begin
            // Pipeline stage 1: capture adder outputs in temp regs
            reg1 <= sum1;   // R6 + R15
            reg2 <= sum2;   // sig1(R1) + sig0(R14)

            // Shift register chain (R1 -> R2 -> ... -> R16)
            for (i = 16; i > 1; i = i - 1)
                R[i] <= R[i-1];

            // R1 gets next message word or the feedback word
            R[1] <= mux_out;

            // Output current Wt (read old R1 before it is updated this cycle)
            wt <= R[1];

            // Advance round counter
            if (t < 7'd63)
                t <= t + 7'd1;
            else
                t <= 7'd0;
        end
    end

endmodule

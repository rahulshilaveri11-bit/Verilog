module compressor_block(
input clk,rst,start,last_block,
input [31:0] Wt,
output reg [255:0] hash_out,
output reg hash_valid
    );
    
    `include "sha_256_functions.vh"
    
    localparam [31:0] H0_INIT = 32'h6a09e667;  //initial hash values
    localparam [31:0] H1_INIT = 32'hbb67ae85;
    localparam [31:0] H2_INIT = 32'h3c6ef372;
    localparam [31:0] H3_INIT = 32'ha54ff53a;
    localparam [31:0] H4_INIT = 32'h510e527f;
    localparam [31:0] H5_INIT = 32'h9b05688c;
    localparam [31:0] H6_INIT = 32'h1f83d9ab;
    localparam [31:0] H7_INIT = 32'h5be0cd19;
    
    reg [31:0] H0,H1,H2,H3,H4,H5,H6,H7 ;  //
    
    reg [31:0] A,B,C,D,E,F,G,H ; //these are working registers
    
    reg [6:0] round;
    
    reg [31:0] reg3,reg4; //added values are stored here
    
     reg [31:0] Kt; //round constants

    always @(*) begin
        case (round)
            7'd0:  Kt=32'h428a2f98; 7'd1:  Kt=32'h71374491;
            7'd2:  Kt=32'hb5c0fbcf; 7'd3:  Kt=32'he9b5dba5;
            7'd4:  Kt=32'h3956c25b; 7'd5:  Kt=32'h59f111f1;
            7'd6:  Kt=32'h923f82a4; 7'd7:  Kt=32'hab1c5ed5;
            7'd8:  Kt=32'hd807aa98; 7'd9:  Kt=32'h12835b01;
            7'd10: Kt=32'h243185be; 7'd11: Kt=32'h550c7dc3;
            7'd12: Kt=32'h72be5d74; 7'd13: Kt=32'h80deb1fe;
            7'd14: Kt=32'h9bdc06a7; 7'd15: Kt=32'hc19bf174;
            7'd16: Kt=32'he49b69c1; 7'd17: Kt=32'hefbe4786;
            7'd18: Kt=32'h0fc19dc6; 7'd19: Kt=32'h240ca1cc;
            7'd20: Kt=32'h2de92c6f; 7'd21: Kt=32'h4a7484aa;
            7'd22: Kt=32'h5cb0a9dc; 7'd23: Kt=32'h76f988da;
            7'd24: Kt=32'h983e5152; 7'd25: Kt=32'ha831c66d;
            7'd26: Kt=32'hb00327c8; 7'd27: Kt=32'hbf597fc7;
            7'd28: Kt=32'hc6e00bf3; 7'd29: Kt=32'hd5a79147;
            7'd30: Kt=32'h06ca6351; 7'd31: Kt=32'h14292967;
            7'd32: Kt=32'h27b70a85; 7'd33: Kt=32'h2e1b2138;
            7'd34: Kt=32'h4d2c6dfc; 7'd35: Kt=32'h53380d13;
            7'd36: Kt=32'h650a7354; 7'd37: Kt=32'h766a0abb;
            7'd38: Kt=32'h81c2c92e; 7'd39: Kt=32'h92722c85;
            7'd40: Kt=32'ha2bfe8a1; 7'd41: Kt=32'ha81a664b;
            7'd42: Kt=32'hc24b8b70; 7'd43: Kt=32'hc76c51a3;
            7'd44: Kt=32'hd192e819; 7'd45: Kt=32'hd6990624;
            7'd46: Kt=32'hf40e3585; 7'd47: Kt=32'h106aa070;
            7'd48: Kt=32'h19a4c116; 7'd49: Kt=32'h1e376c08;
            7'd50: Kt=32'h2748774c; 7'd51: Kt=32'h34b0bcb5;
            7'd52: Kt=32'h391c0cb3; 7'd53: Kt=32'h4ed8aa4a;
            7'd54: Kt=32'h5b9cca4f; 7'd55: Kt=32'h682e6ff3;
            7'd56: Kt=32'h748f82ee; 7'd57: Kt=32'h78a5636f;
            7'd58: Kt=32'h84c87814; 7'd59: Kt=32'h8cc70208;
            7'd60: Kt=32'h90befffa; 7'd61: Kt=32'ha4506ceb;
            7'd62: Kt=32'hbef9a3f7; 7'd63: Kt=32'hc67178f2;
            default: Kt=32'h00000000;
        endcase
    end
    // outputs og the combinational CKTS
    wire [31:0] SIG0_out; 
    wire [31:0] MAJ_out;
    wire [31:0] SIG1_out;
    wire [31:0] CHO_out;
    
    assign SIG0_out = SIG0(A);
    assign MAJ_out = majority(A,B,C);
    assign SIG1_out = SIG1(E);
    assign CHO_out = choose(E,F,G);
    
    wire [31:0] SIG1_choose; wire c1;// CSKA1 = SIG1(E)+CHO
    carry_skip_adder_32bit CSA321(.a(SIG1_out),.b(CHO_out),.cin(1'b0),.sum(SIG1_choose),.cout(c1));
    
    wire [31:0] temp2; wire c2; //CSAK2 = SIG0(A) + MAJ
    carry_skip_adder_32bit CSA322(.a(SIG0_out),.b(MAJ_out),.cin(1'b0),.sum(temp2),.cout(c2));
    
    wire [31:0]sum_BF; wire c3; //CSKA3 = B + F
    carry_skip_adder_32bit CSA323(.a(B),.b(F),.cin(1'b0),.sum(sum_BF),.cout(c3));
    
    wire [31:0] Wt_Kt; wire c4; //CSKA4 = Wt + Kt
    carry_skip_adder_32bit CSA324(.a(Wt),.b(Kt),.cin(1'b0),.sum(Wt_Kt),.cout(c4));
    
    wire [31:0] sum_DH; wire c5; //CSKA5 = d+H
    carry_skip_adder_32bit CSA325(.a(D),.b(H),.cin(1'b0),.sum(sum_DH),.cout(c5));
    
    wire [31:0] Ut; wire c6; // CSKA6 = Wt_Kt + H
    carry_skip_adder_32bit CSA326(.a(Wt_Kt),.b(H),.cin(1'b0),.sum(Ut),.cout(c6));
    
    wire [31:0] sel_DH; //MUX3 Output
    assign sel_DH = (round < 7'd3)? sum_DH : reg4 ;
    
    wire [31:0] Vt; wire c7; //CSKA7 = Kt_Wt + sumDH
    carry_skip_adder_32bit CSA327(.a(Wt_Kt),.b(sel_DH),.cin(1'b0),.sum(Vt),.cout(c7));
    
    wire [31:0] new_E; wire c8; //CSKA8 = Vt + SIG1_choose
    carry_skip_adder_32bit CSA328(.a(Vt),.b(SIG1_choose),.cin(1'b0),.sum(new_E),.cout(c8));
    
    wire [31:0] SIG1_choose_Ut; wire c9; //CSKA9 = SIG1_choose + Ut
    carry_skip_adder_32bit CSA329(.a(SIG1_choose),.b(Ut),.cin(1'b0),.sum(SIG1_choose_Ut),.cout(c9));
    
    wire [31:0] new_A; wire c10; // CSKA10 = SIG1_choose_Ut + temp2
    carry_skip_adder_32bit CSA3210(.a(SIG1_choose_Ut),.b(temp2),.cin(1'b0),.sum(new_A),.cout(c10));
    
    wire c11,c12,c13,c14,c15,c16,c17,c18 ; // reqired for port connection
    
    wire [31:0] H0_new,H1_new,H2_new,H3_new; //final hash values wire 
    wire [31:0] H4_new,H5_new,H6_new,H7_new; //final hash values wire 
    
    carry_skip_adder_32bit CSA3211(.a(A),.b(H0),.cin(1'b0),.sum(H0_new),.cout(c11));
    carry_skip_adder_32bit CSA3212(.a(B),.b(H1),.cin(1'b0),.sum(H1_new),.cout(c12));
    carry_skip_adder_32bit CSA3213(.a(C),.b(H2),.cin(1'b0),.sum(H2_new),.cout(c13));
    carry_skip_adder_32bit CSA3214(.a(D),.b(H3),.cin(1'b0),.sum(H3_new),.cout(c14));
    carry_skip_adder_32bit CSA3215(.a(E),.b(H4),.cin(1'b0),.sum(H4_new),.cout(c15));
    carry_skip_adder_32bit CSA3216(.a(F),.b(H5),.cin(1'b0),.sum(H5_new),.cout(c16));
    carry_skip_adder_32bit CSA3217(.a(G),.b(H6),.cin(1'b0),.sum(H6_new),.cout(c17));
    carry_skip_adder_32bit CSA3218(.a(H),.b(H7),.cin(1'b0),.sum(H7_new),.cout(c18));
     
     //sequential FSM 
    always @(posedge clk or posedge rst) begin
      if(rst) begin
         H0 <= H0_INIT; H1 <= H1_INIT;
         H2 <= H2_INIT; H3 <= H3_INIT;
         H4 <= H4_INIT; H5 <= H5_INIT;
         H6 <= H6_INIT; H7 <= H7_INIT;
         A <= 0; B <= 0; C <= 0; D <= 0;
         E <= 0; F <= 0; G <= 0; H <= 0;
         reg3 <= 32'd0;
         reg4 <= 32'd0;
         round <= 7'd127; // idle sentinel: 127 ≥ 64 so no branch fires until start resets it to 0
         hash_out <= 256'd0;
         hash_valid <= 1'b0;
      end else begin   
         hash_valid <= 1'b0; //by default 0 at every cycle
         
         if(start)
          begin
             A <= H0;
             B <= H1;
             C <= H2;
             D <= H3;
             E <= H4;
             F <= H5;
             G <= H6;
             H <= H7;
             reg3 <= 32'd0;
             reg4 <= 32'd0;
             round <= 7'd0;
         end else if(round < 7'd64) begin
              A <= new_A;
              B <= A;
              C <= B;
              D <= C;
              E <= new_E;
              F <= E;
              G <= F;
              H <= G;
              reg3 <= sum_BF;
              reg4 <= reg3;
              round <= round + 7'd1;
          end else if(round == 7'd64) begin
              if (last_block) begin
                 // Final block: output hash, then reset H0..H7 for the next message
                 hash_out   <= {H0_new,H1_new,H2_new,H3_new,H4_new,H5_new,H6_new,H7_new};
                 hash_valid <= 1'b1;
                 H0 <= H0_INIT; H1 <= H1_INIT;
                 H2 <= H2_INIT; H3 <= H3_INIT;
                 H4 <= H4_INIT; H5 <= H5_INIT;
                 H6 <= H6_INIT; H7 <= H7_INIT;
              end else begin
                 // Intermediate block: accumulate into H0..H7 for next block
                 H0 <= H0_new; H1 <= H1_new;
                 H2 <= H2_new; H3 <= H3_new;
                 H4 <= H4_new; H5 <= H5_new;
                 H6 <= H6_new; H7 <= H7_new;
              end
              // round stays at 65; only start resets it
              round <= 7'd65;
          end
          end  
        end  
endmodule

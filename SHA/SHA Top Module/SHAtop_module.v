module SHAtop_module(
    input  clk,
    input  rst,
    input  valid_input,
    input  [7:0] byte_in,
    input  last_byte,
    output busy,
    output [255:0] hash_out,
    output hash_valid
);

    // ALL REGISTER DECLARATIONS (must be before any always block
    reg [511:0] pending_block;   // Registered copy of the latest padded block
    reg         pending_last;    // Registered last_block_flag for pending_block
    reg         block_pending;   // 1 = pending_block holds unprocessed data

    reg         load_exp;        // 1-cycle pulse: tells expander to load pending_block
    reg         start_comp;      // 1-cycle pulse: tells compressor to initialise A..H
    reg         start_comp_d;    // 1-cycle delay register for start_comp
    reg         last_block_reg;  // Latched last_block for the current block
    reg         processing;      // 1 while compressor is running
    reg  [6:0]  cycle_count;     // Countdown: 67 -> 0

    // MESSAGE PADDING
    wire [511:0] padded_block;
    wire         block_valid;
    wire         last_block_flag;

    message_padding MESSAGE_BLOCK(
        .clk(clk),
        .rst(rst),
        .valid_input(valid_input),
        .byte_in(byte_in),
        .last_byte(last_byte),
        .block_out(padded_block),
        .block_valid(block_valid),
        .last_block (last_block_flag)
    );

    // EXPANDER BLOCK
    wire [31:0] Wt;

    expander_block EXPANDER_BLOCK(
        .clk(clk),
        .rst(rst),
        .load(load_exp),
        .message(pending_block),
        .wt(Wt)
    );

    // COMPRESSOR BLOCK
    compressor_block COMPRESSOR_BLOCK(
        .clk(clk),
        .rst(rst),
        .start(start_comp),
        .last_block(last_block_reg),
        .Wt(Wt),
        .hash_out(hash_out),
        .hash_valid(hash_valid)
    );

    // ---------------------------------------------------------------
    // BLOCK CAPTURE BUFFER
    //
    // Captures every block_valid pulse into pending_block so the
    // sequencer can process it later (even if the compressor is busy).
    //
    // Priority rules (both same always block, NB semantics):
    //   block_valid=1  : capture new block (takes priority over clear)
    //   load_exp=1     : expander is loading pending_block right now;
    //                    clear block_pending UNLESS a new block arrived
    //                    simultaneously (handled by if/else-if ordering).
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending_block <= 512'b0;
            pending_last  <= 1'b0;
            block_pending <= 1'b0;
        end else begin
            if (block_valid) begin
                // New block ready: always capture it.
                // If load_exp=1 simultaneously, this block is for the NEXT
                // processing slot; block_pending stays 1.
                pending_block <= padded_block;
                pending_last  <= last_block_flag;
                block_pending <= 1'b1;
            end else if (load_exp) begin
                // Expander is loading pending_block this very cycle.
                // Mark it as consumed (no new block arrived).
                block_pending <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------
    // SEQUENCER FSM
    //
    // Fires load_exp + start_comp_d when a block is pending and the
    // compressor is free.
    //
    // Timing (T = cycle sequencer fires):
    //   T   : load_exp<=1, start_comp_d<=1, processing<=1 (NB)
    //   T+1 : load_exp=1  -> expander latches pending_block (M[0..15])
    //         start_comp=1 -> compressor loads A..H = H0..H7, round<=0
    //         (load_exp branch clears block_pending if no new block_valid)
    //   T+2 : expander free-runs: wt=W[0]
    //         compressor: round=0, reads Wt=W[0]  CORRECT
    //   T+2..T+65 : rounds 0..63
    //   T+66: round 64 -> H0..H7 updated; hash_valid if last_block
    //   T+67: round 65 -> idle (cycle_count=0 seen, processing<=0)
    // ---------------------------------------------------------------
    assign busy = processing;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_exp       <= 1'b0;
            start_comp     <= 1'b0;
            start_comp_d   <= 1'b0;
            last_block_reg <= 1'b0;
            processing     <= 1'b0;
            cycle_count    <= 7'd0;
        end else begin
            // Default: deassert single-cycle pulses
            load_exp     <= 1'b0;
            start_comp   <= start_comp_d;
            start_comp_d <= 1'b0;

            if (!processing) begin
                if (block_pending) begin
                    // A registered block is ready: kick off the pipeline.
                    // pending_block and pending_last are stable (registered)
                    // so no combinational timing hazard.
                    load_exp       <= 1'b1;
                    start_comp_d   <= 1'b1;
                    last_block_reg <= pending_last;
                    processing     <= 1'b1;
                    cycle_count    <= 7'd67;
                end
            end else begin
                if (cycle_count == 7'd0)
                    processing <= 1'b0;
                else
                    cycle_count <= cycle_count - 7'd1;
            end
        end
    end

endmodule

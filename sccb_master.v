module sccb_master #(
    parameter CLK_FREQ = 50_000_000 // System clock (Matches your config module)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,        // Triggers the transmission
    input  wire [7:0] reg_addr,     // Address from ov7670_config
    input  wire [7:0] reg_data,     // Data from ov7670_config
    output reg        ready,        // Signals ov7670_config that transmission is done

    // Open Drain SCCB Physical Pins
    output wire       scl,          // SIO_C
    inout  wire       sda           // SIO_D
);

    // OV7670 SCCB Device Write Address
    localparam OV7670_ID = 8'h42; 

    // FSM State Encodings (Based on diagram: start/write/ack/stop)
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam WRITE = 3'd2;
    localparam ACK   = 3'd3;
    localparam STOP  = 3'd4;
    localparam DONE  = 3'd5;

    reg [2:0] state;

    // Clock Divider: 50MHz down to 100kHz SCCB Clock
    // To safely change SDA while SCL is low/high, we divide the 100kHz period into 4 phases (400kHz tick)
    localparam DIVIDER_MAX = (CLK_FREQ / 400_000) - 1; 
    reg [7:0] clk_div;
    reg [1:0] phase;
    wire      tick = (clk_div == DIVIDER_MAX);

    // Shift Register and Counters
    reg [7:0] shift_reg;
    reg [2:0] bit_count;
    reg [1:0] byte_count; // 0 = ID, 1 = Addr, 2 = Data

    // Open Drain Driver Registers
    reg scl_out;
    reg sda_out;

    // Hardware Open-Drain Assignment 
    // If output is 0, pull line to GND. If 1, let it float (Z) so external resistor pulls it high.
    assign scl = (scl_out == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0;
            phase   <= 0;
            state   <= IDLE;
            scl_out <= 1'b1;
            sda_out <= 1'b1;
            ready   <= 1'b1;
            byte_count <= 0;
            bit_count  <= 0;
            shift_reg  <= 0;
        end else begin
            // Clock Divider Logic
            if (state != IDLE) begin
                if (tick) begin
                    clk_div <= 0;
                    phase <= phase + 1;
                end else begin
                    clk_div <= clk_div + 1;
                end
            end

            // Main FSM
            case (state)
                IDLE: begin
                    scl_out <= 1'b1;
                    sda_out <= 1'b1;
                    phase   <= 0;
                    clk_div <= 0;
                    
                    if (start) begin
                        state      <= START;
                        ready      <= 1'b0;
                        byte_count <= 0;
                        shift_reg  <= OV7670_ID; // Load first byte to send
                    end
                end

                START: begin
                    if (tick) begin
                        case (phase)
                            2'b00: begin scl_out <= 1'b1; sda_out <= 1'b1; end // Idle state
                            2'b01: begin scl_out <= 1'b1; sda_out <= 1'b0; end // SDA drops while SCL is high
                            2'b10: begin scl_out <= 1'b0; sda_out <= 1'b0; end // SCL drops
                            2'b11: begin 
                                state     <= WRITE; 
                                bit_count <= 3'd7; 
                            end
                        endcase
                    end
                end

                WRITE: begin
                    if (tick) begin
                        case (phase)
                            // Phase 0: SCL is low, safely update SDA with next bit from shift register
                            2'b00: begin scl_out <= 1'b0; sda_out <= shift_reg[7]; end
                            // Phase 1: Pull SCL high
                            2'b01: begin scl_out <= 1'b1; end 
                            // Phase 2: SCL is high, camera reads the bit here
                            2'b10: begin scl_out <= 1'b1; end 
                            // Phase 3: Pull SCL low, shift the register, check if byte is done
                            2'b11: begin 
                                scl_out <= 1'b0;
                                if (bit_count == 0) begin
                                    state <= ACK;
                                end else begin
                                    bit_count <= bit_count - 1;
                                    shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left
                                end
                            end
                        endcase
                    end
                end

                ACK: begin
                    // SCCB uses a "Don't Care" bit instead of a strict I2C ACK, but we still clock it
                    if (tick) begin
                        case (phase)
                            2'b00: begin scl_out <= 1'b0; sda_out <= 1'b1; end // Release SDA (float)
                            2'b01: begin scl_out <= 1'b1; end                  // Clock high
                            2'b10: begin scl_out <= 1'b1; end                  // (Camera drives SDA here if it wants to)
                            2'b11: begin 
                                scl_out <= 1'b0;
                                if (byte_count == 2) begin
                                    state <= STOP; // All 3 bytes sent
                                end else begin
                                    byte_count <= byte_count + 1;
                                    state      <= WRITE;
                                    bit_count  <= 3'd7;
                                    // Load next byte into shift register
                                    if (byte_count == 0) shift_reg <= reg_addr;
                                    if (byte_count == 1) shift_reg <= reg_data;
                                end
                            end
                        endcase
                    end
                end

                STOP: begin
                    if (tick) begin
                        case (phase)
                            2'b00: begin scl_out <= 1'b0; sda_out <= 1'b0; end // SCL low, prep SDA low
                            2'b01: begin scl_out <= 1'b1; sda_out <= 1'b0; end // SCL goes high
                            2'b10: begin scl_out <= 1'b1; sda_out <= 1'b1; end // SDA goes high while SCL is high
                            2'b11: begin state <= DONE; end
                        endcase
                    end
                end

                DONE: begin
                    ready <= 1'b1; // Pulse ready high
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
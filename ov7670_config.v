module ov7670_config (
    input wire clk,             // System clock (e.g., 50 MHz)
    input wire rst_n,           // Active-low reset
    input wire sccb_ready,      // High when SCCB lower-level module is idle
    
    output reg sccb_start,      // Pulse high to tell SCCB to send data
    output reg [7:0] reg_addr,  // OV7670 Register Address to write
    output reg [7:0] reg_data,  // Data to write into the register
    output reg config_done      // High when all registers are configured
);

    // FSM State Encodings based on whiteboard diagram
    localparam S_DELAY      = 3'd0; // 10 ms for power up
    localparam S_FETCH      = 3'd1; // Grab next reg addr
    localparam S_SEND       = 3'd2; // Start signal for SCCB
    localparam S_WAIT       = 3'd3; // Wait if SCCB is ready
    localparam S_CHECK_DONE = 3'd4; // More regs or all regs sent?
    localparam S_DONE       = 3'd5; // Done state

    reg [2:0] state;
    
    // Register ROM tracking
    reg [7:0] rom_index;
    wire [15:0] current_reg_val;
    localparam TOTAL_REGS = 5; // Adjust this based on your ROM size

    // 10ms Delay counter (Assuming 50MHz Clock: 50,000,000 * 0.01 = 500,000 cycles)
    reg [18:0] delay_counter;
    localparam DELAY_MAX = 19'd500_000; 

    // Configuration ROM (Address + Data)
    // Format: {8-bit Address, 8-bit Data}
    reg [15:0] config_rom [0:TOTAL_REGS-1];
    
    initial begin
        // QQVGA & RGB565 Configuration values
        config_rom[0] = 16'h12_80; // COM7: Reset all registers
        config_rom[1] = 16'h12_04; // COM7: Enable RGB output, QQVGA format
        config_rom[2] = 16'h40_D0; // COM15: Set RGB565 format (00 to FF range)
        config_rom[3] = 16'h8C_00; // RGB444: Disable RGB444
        config_rom[4] = 16'h11_00; // CLKRC: Use internal clock directly
    end

    assign current_reg_val = config_rom[rom_index];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_DELAY;
            delay_counter <= 0;
            rom_index <= 0;
            sccb_start <= 0;
            config_done <= 0;
        end else begin
            case (state)
                S_DELAY: begin
                    // "10 ms for power up"
                    if (delay_counter < DELAY_MAX) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        state <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    // "grab next reg addr"
                    reg_addr <= current_reg_val[15:8];
                    reg_data <= current_reg_val[7:0];
                    state <= S_SEND;
                end

                S_SEND: begin
                    // "start signal from SCCB"
                    sccb_start <= 1'b1;
                    state <= S_WAIT;
                end

                S_WAIT: begin
                    // "(Busy) if sccb is ready"
                    sccb_start <= 1'b0; // Pull start down after 1 cycle
                    if (sccb_ready == 1'b1) begin
                        state <= S_CHECK_DONE;
                    end
                end

                S_CHECK_DONE: begin
                    // "more regs or All regs sent?"
                    if (rom_index == TOTAL_REGS - 1) begin
                        state <= S_DONE;
                    end else begin
                        rom_index <= rom_index + 1;
                        state <= S_FETCH;
                    end
                end

                S_DONE: begin
                    // "S_DONE"
                    config_done <= 1'b1;
                end
                
                default: state <= S_DELAY;
            endcase
        end
    end
endmodule
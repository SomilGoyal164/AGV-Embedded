module ov7670_capture (
    input  wire        pclk,          // Pixel clock from camera
    input  wire        rst_n,         // Active-low asynchronous reset
    input  wire        vsync,         // Vertical sync (frame marker)
    input  wire        href,          // Horizontal reference (row marker)
    input  wire [7:0]  d,             // 8-bit camera data bus
    output reg  [15:0] pixel_data,    // 16-bit assembled RGB565 pixel
    output reg         pixel_valid    // Strobe pulse when 16-bit pixel is ready
);

    // FSM State Encoding
    localparam IDLE         = 2'b00;
    localparam WAIT_HREF    = 2'b01;
    localparam CAPTURE_DATA = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] high_byte;
    reg       byte_toggle;          // Toggles 0/1 to assemble the 16-bit word

    // State Register & Datapath Execution (Synchronized to PCLK)
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            byte_toggle <= 1'b0;
            high_byte   <= 8'h00;
            pixel_data  <= 16'h0000;
            pixel_valid <= 1'b0;
        end else begin
            state       <= next_state;
            pixel_valid <= 1'b0; // Default pulse low

            case (state)
                CAPTURE_DATA: begin
                    if (href) begin
                        if (byte_toggle == 1'b0) begin
                            high_byte   <= d;           // Capture upper byte (Red + upper Green)
                            byte_toggle <= 1'b1;
                        end else begin
                            pixel_data  <= {high_byte, d}; // Combine with lower byte (lower Green + Blue)
                            pixel_valid <= 1'b1;          // Signal downstream FIFO/RAM that pixel is ready
                            byte_toggle <= 1'b0;
                        end
                    end else begin
                        byte_toggle <= 1'b0;            // Safety reset if HREF dips early
                    end
                end
                
                default: begin
                    byte_toggle <= 1'b0;
                end
            endcase
        end
    end

    // Next-State Combinational Logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                // Wait for VSYNC to drop, signaling active frame data is approaching
                if (!vsync) 
                    next_state = WAIT_HREF;
            end

            WAIT_HREF: begin
                if (vsync) 
                    next_state = IDLE;       // Frame reset safeguard
                else if (href) 
                    next_state = CAPTURE_DATA; // Valid row data starting
            end

            CAPTURE_DATA: begin
                if (vsync) 
                    next_state = IDLE;       // Frame finished
                else if (!href) 
                    next_state = WAIT_HREF;  // End of current row, wait for next HREF
            end

            default: 
                next_state = IDLE;
        endcase
    end

endmodule
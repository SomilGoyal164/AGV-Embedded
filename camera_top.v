module camera_top (
    input  wire clk,
    input  wire rst_n,
    output wire scl,
    inout  wire sda,
    output wire config_done
);

    // Internal connecting wires
    wire       sccb_start_wire;
    wire       sccb_ready_wire;
    wire [7:0] reg_addr_wire;
    wire [7:0] reg_data_wire;

    // Instantiate the Brains (Your config module)
    ov7670_config config_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .sccb_ready  (sccb_ready_wire),  // Input from Master
        .sccb_start  (sccb_start_wire),  // Output to Master
        .reg_addr    (reg_addr_wire),    // Output to Master
        .reg_data    (reg_data_wire),    // Output to Master
        .config_done (config_done)
    );

    // Instantiate the Brawn (The new SCCB Master)
    sccb_master master_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (sccb_start_wire),  // Input from Config
        .reg_addr    (reg_addr_wire),    // Input from Config
        .reg_data    (reg_data_wire),    // Input from Config
        .ready       (sccb_ready_wire),  // Output to Config
        .scl         (scl),              // To physical camera pin
        .sda         (sda)               // To physical camera pin
    );

endmodule
module BANDAI2003 (
    input CLK,
    output SO
    input RST,
    input[7:0] ADDR,
);

    wire LCK; // Lock

    reg [7:0] LS; // Lock State - Addressed unlock sequence

    localparam ADDR_ACK = 8'h5A;
    localparam ADDR_NAK = 8'hA5;
    localparam ADDR_NIL = 8'h00;

    localparam W = 20; // 20-bit wide buffer

    reg [W-1:0] SR; // Shift Register - Right

    localparam [W-1:0] BS = 20'b00010100010100000011; // Bit-stream - sets SYSTEM_CTRL1 (A0h) bit 8 high.

    assign LCK = LS != ADDR_NIL;

    assign SO = ~RST ? 1'bZ : SR[0];

    always @ (posedge CLK or negedge RST) begin
        if (!RST) begin
            SR <= {(W){1'b1}};
            LS <= ADDR_ACK;
        end else if (LS && ADDR == LS)
            case (ADDR)
                ADDR_ACK: LS <= ADDR_NAK;
                ADDR_NAK: begin
                    LS <= ADDR_NIL;
                    SR <= BS;
                end
            endcase
        else
            SR <= {1'b1, SR[W-1:1]};
    end

endmodule

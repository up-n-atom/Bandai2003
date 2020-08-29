module BANDAI2003 (
    input CLK,
    input CEn,
    input WEn,
    input OEn,
    input SSn,
    output SO, /* Synchronous out */
    input RSTn,
    input[7:0] ADDR, /* A-1 to A3 + A15 to A18 */
    inout[7:0] DQ /* Warning: Tri-state */
);

    reg [7:0] LS; // Lock State - Addressed unlock sequence

    localparam ADDR_ACK = 8'h5A;
    localparam ADDR_NAK = 8'hA5;
    localparam ADDR_NIH = 8'hFF;

    reg [17:0] SR; // Shift Register - Right

    localparam [17:0] BS = {1'b0, 16'h28A0, 1'b0};; // *Reversed* Bit-stream  - Sets SYSTEM_CTRL1 (A0h) bit 8 high.

    assign SO = ~RSTn ? 1'bZ : SR[0];

    always @ (posedge CLK or negedge RSTn) begin
        if (~RSTn) begin
            SR <= {(18){1'b1}};
            LS <= ADDR_ACK;
        end else if (LS && ADDR == LS)
            case (ADDR)
                ADDR_ACK: LS <= ADDR_NAK;
                ADDR_NAK: begin
                    LS <= ADDR_NIH;
                    SR <= BS;
                end
            endcase
        else
            SR <= {1'b1, SR[17:1]};
    end

    wire LCKn = LS != ADDR_NIH; // The end is nigh

    reg [7:0] BR [3:0]; // Bank Registers

    localparam ADDR_LAO = 8'hC0; // Linear Address Offset
    localparam ADDR_RAM = 8'hC1; // RAM Bank
    localparam ADDR_ROM0 = 8'hC2; // ROM Bank #0
    localparam ADDR_ROM1 = 8'hC3; // ROM Bank #1

    wire IBR = ~(SSn & CEn) && (ADDR >= ADDR_LAO && ADDR <= ADDR_ROM1);
    wire OBR = IBR && ~OEn && WEn;
    wire WBR = IBR && OEn && ~WEn;

    assign DQ = ~LCKn && OBR ? BR[ADDR & 8'h03] : 8'hZZ;

    always @ (RSTn or LCKn or WBR or ADDR or DQ) begin
        if (~RSTn)
            for (i = 0; i < 4; i = i + 1)
                BR[i] = 8'hFF;
        else if (~LCKn)
            if (WBR)
                BR[ADDR & 8'h03] = DQ;
    end

endmodule

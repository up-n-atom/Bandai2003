module BANDAI2003 (
    input CLK,
    input CEn,
    input WEn,
    input OEn,
    input SSn,
    output SO, /* Synchronous out */
    input RSTn,
    input[7:0] ADDR, /* A-1 to A3 + A15 to A18 */
    inout[7:0] DQ, /* Warning: Tri-state */
    output ROMCEn,
    output RAMCEn,
`ifdef EIGHTBITROM
    output reg BYTEn,
`endif
    output[6:0] RADDR /* ROM/RAM A15 to A21 */
);

    reg [7:0] lckS; // Lock State - Addressed unlock sequence

    localparam ADDR_ACK = 8'h5A;
    localparam ADDR_NAK = 8'hA5;
    localparam ADDR_NIH = 8'hFF;

    wire LCKn = lckS != ADDR_NIH; // The end is nigh

    reg [17:0] shR; // Shift Register - Right

    // ¯\______/¯\_/¯\___/¯\_/¯\___/¯
    // Bit-stream - Invokes SYSTEM_CTRL1 (A0h) bit 7 to 1.
    localparam [17:0] bitS = {1'b0, 16'h28A0, 1'b0};

    assign SO = ~RSTn ? 1'bZ : shR[0];

    always @ (posedge CLK or negedge RSTn) begin
        if (~RSTn) begin
            shR <= {(18){1'b1}};
            lckS <= ADDR_ACK;
        end else if (LCKn && ADDR == lckS)
            case (ADDR)
                ADDR_ACK: lckS <= ADDR_NAK;
                ADDR_NAK: begin
                    shR <= bitS;
                    lckS <= ADDR_NIH;
                end
            endcase
        else
            shR <= {1'b1, shR[17:1]};
    end

    reg [7:0] bnkR [3:0]; // Bank Registers

    localparam ADDR_LAO = 8'hC0; // Linear Address Offset
    localparam ADDR_RAMB = 8'hC1; // RAM Bank
    localparam ADDR_ROMB0 = 8'hC2; // ROM Bank #0
    localparam ADDR_ROMB1 = 8'hC3; // ROM Bank #1

    wire iBR = ~(SSn & CEn) && (ADDR >= ADDR_LAO && ADDR <= ADDR_ROMB1);
    wire oBR = iBR && ~OEn && WEn;

    assign DQ = ~LCKn && oBR ? bnkR[ADDR[1:0]] : 8'hZZ;
    wire[7:0] iDQ = DQ;

`ifdef EIGHTBITROM
    localparam ADDR_MCTRL = 8'hCE; // Memory Control
`endif

    function [7:0] fDQ;
        if (ADDR >= ADDR_LAO && ADDR <= ADDR_BROM1)
            fDQ = bnkR[ADDR[1:0] & 2'h3];
`ifdef EIGHTBITROM
        else if (ADDR == ADDR_MCTRL)
            fDQ = {7'b0, BYTEn};
`endif
        else
            fDQ = 8'hZZ;
    endfunction

    assign DQ = ~LCKn && ~(SSn & CEn) && ~OEn && WEn ? fDQ : 8'hZZ;

    integer i;

    always @(posedge WEn or negedge RSTn) begin
        if (~RSTn) begin
            for (i = 0; i < 4; i = i + 1)
                bnkR[i] = 8'hFF;
`ifdef EIGHTBITROM
            BYTEn = 1'b1;
`endif
        end else if (~LCKn && ~(SSn & CEn))
            if (ADDR >= ADDR_LAO && ADDR <= ADDR_ROMB1)
                bnkR[ADDR[1:0] & 2'h3] = iDQ;
`ifdef EIGHTBITROM
            else if (ADDR == ADDR_MCTRL)
                BYTEn = ~iDQ;
`endif
    end

    wire rCE = ~LCKn && SSn && ~CEn;

`ifdef EIGHTBITROM
    assign RAMCEn = ~(rCE && BYTEn && ADDR[7:4] == 4'h1);
    assign ROMCEn = ~(rCE && (~BYTEn || ADDR[7:4] > 4'h1));
`else
    assign RAMCEn = ~(rCE && ADDR[7:4] == 4'h1);
    assign ROMCEn = ~(rCE && ADDR[7:4] > 4'h1);
`endif

    assign RADDR = ~RAMCEn || ~ROMCEn ? ADDR[7:4] > 4'h3 ? {bnkR[0][2:0], ADDR[7:4]} : bnkR[ADDR[5:4]][6:0] : 7'b0;

endmodule

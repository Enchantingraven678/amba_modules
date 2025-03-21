`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2024 10:14:10
// Design Name: 
// Module Name: axi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AXI_master #(parameter WIDTH = 32) (
    input ACLK, 
    input ARESETn,
    // ADDRESS WRITE CHANNEL    
    input AWREADY,
    output reg AWVALID,
    output reg [WIDTH-1:0] AWADDR,    
    // DATA WRITE CHANNEL
    input WREADY,
    output reg WVALID,
    output reg [(WIDTH/8)-1:0] WSTRB,
    output reg [WIDTH-1:0] WDATA,
    // WRITE RESPONSE CHANNEL
    input [1:0] BRESP,
    input BVALID,
    output reg BREADY,
    // READ ADDRESS CHANNEL
    input ARREADY,
    output reg ARVALID,
    output reg [WIDTH-1:0] ARADDR,
    // READ DATA CHANNEL
    input [WIDTH-1:0] RDATA,
    input [1:0] RRESP,
    input RVALID,
    output reg RREADY,
    // Sending inputs to master which will be transferred through AXI protocol.
    input [WIDTH-1:0] awaddr,
    input [(WIDTH/8)-1:0] wstrb,
    input [WIDTH-1:0] wdata,
    input [WIDTH-1:0] araddr,
    output reg [31:0] data_out 
);

    // Internal RAM for read memory
    reg [7:0] read_mem [4095:0];

    // Write Transaction Queue
    reg [(WIDTH-1):0] awaddr_queue [7:0];
    reg [(WIDTH/8)-1:0] wstrb_queue [7:0];
    reg [(WIDTH-1):0] wdata_queue [7:0];
    reg [2:0] w_queue_head, w_queue_tail;
    reg [2:0] w_transaction_count;

    // Read Transaction Queue
    reg [(WIDTH-1):0] araddr_queue [7:0];
    reg [2:0] r_queue_head, r_queue_tail;
    reg [2:0] r_transaction_count;

    // Write Address Channel Master
    localparam [1:0] WA_IDLE_M = 2'b00, WA_VALID_M = 2'b01, WA_ADDR_M = 2'b10, WA_WAIT_M = 2'b11;
    reg [1:0] WAState_M, WANext_state_M;    

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) WAState_M <= WA_IDLE_M;
        else WAState_M <= WANext_state_M;
    end

    always @* begin
        case (WAState_M)
            WA_IDLE_M : WANext_state_M = (w_transaction_count > 0) ? WA_VALID_M : WA_IDLE_M;
            WA_VALID_M : WANext_state_M = (AWREADY) ? WA_ADDR_M : WA_VALID_M;
            WA_ADDR_M : WANext_state_M = WA_WAIT_M;
            WA_WAIT_M : WANext_state_M = (BVALID) ? WA_IDLE_M : WA_WAIT_M;
            default : WANext_state_M = WA_IDLE_M;
        endcase 
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) AWVALID <= 1'b0;
        else begin
            case (WANext_state_M)
                WA_IDLE_M : AWVALID <= 1'b0;
                WA_VALID_M : begin AWVALID <= 1'b1; AWADDR <= awaddr_queue[w_queue_head]; end
                default : AWVALID <= 1'b0;
            endcase
        end
    end

    // Write Data Channel Master
    localparam [1:0] W_IDLE_M = 2'b00, W_GET_M = 2'b01, W_WAIT_M = 2'b10, W_TRANS_M = 2'b11;
    reg [1:0] WState_M, WNext_state_M;                    

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) WState_M <= W_IDLE_M;
        else WState_M <= WNext_state_M;
    end

    always @* begin
        case (WState_M)
            W_IDLE_M : WNext_state_M = W_GET_M;
            W_GET_M : WNext_state_M = (AWREADY) ? W_WAIT_M : W_GET_M;
            W_WAIT_M : WNext_state_M = (WREADY) ? W_TRANS_M : W_WAIT_M;
            W_TRANS_M : WNext_state_M = W_IDLE_M;
            default : WNext_state_M = W_IDLE_M;
        endcase 
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) WVALID <= 1'b0;
        else begin
            case (WNext_state_M)
                W_IDLE_M : WVALID <= 1'b0;
                W_GET_M : begin WVALID <= 1'b1; WSTRB <= wstrb_queue[w_queue_head]; WDATA <= wdata_queue[w_queue_head]; end
                W_WAIT_M : WVALID <= 1'b1;
                default : WVALID <= 1'b0;
            endcase 
        end
    end

    // Write Response Channel Master
    localparam [1:0] B_IDLE_M = 2'b00, B_START_M = 2'b01, B_READY_M = 2'b10;
    reg [1:0] BState_M, BNext_state_M;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) BState_M <= B_IDLE_M;
        else BState_M <= BNext_state_M;
    end

    always @* begin
        case (BState_M)
            B_IDLE_M : BNext_state_M = (AWREADY) ? B_START_M : B_IDLE_M;
            B_START_M : BNext_state_M = (BVALID) ? B_READY_M : B_START_M;
            B_READY_M : BNext_state_M = B_IDLE_M;                                                                    
            default : BNext_state_M = B_IDLE_M;
        endcase 
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) BREADY <= 1'b0;
        else begin
            case (BNext_state_M)
                B_IDLE_M : BREADY <= 1'b0;
                B_START_M : BREADY <= 1'b1;
                B_READY_M : begin BREADY <= 1'b0; w_queue_head <= w_queue_head + 1; w_transaction_count <= w_transaction_count - 1; end
                default : BREADY <= 1'b0;
            endcase 
        end
    end

    // Read Address Channel Master
    localparam [1:0] AR_IDLE_M = 2'b00, AR_VALID_M = 2'b01, AR_ADDR_M = 2'b10, AR_WAIT_M = 2'b11;
    reg [1:0] ARState_M, ARNext_state_M;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) ARState_M <= AR_IDLE_M;
        else ARState_M <= ARNext_state_M;
    end

    always @* begin
        case (ARState_M)
            AR_IDLE_M : ARNext_state_M = (r_transaction_count > 0) ? AR_VALID_M : AR_IDLE_M;
            AR_VALID_M : ARNext_state_M = (ARREADY) ? AR_ADDR_M : AR_VALID_M;
            AR_ADDR_M : ARNext_state_M = AR_WAIT_M;
            AR_WAIT_M : ARNext_state_M = (RVALID) ? AR_IDLE_M : AR_WAIT_M;
            default : ARNext_state_M = AR_IDLE_M;
        endcase 
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) ARVALID <= 1'b0;
        else begin
            case (ARNext_state_M)
                AR_IDLE_M : ARVALID <= 1'b0;
                AR_VALID_M : begin ARVALID <= 1'b1; ARADDR <= araddr_queue[r_queue_head]; end
                default : ARVALID <= 1'b0;
            endcase
        end
    end

    // Read Data Channel Master
    localparam [1:0] R_IDLE_M = 2'b00, R_READY_M = 2'b01;
    reg [1:0] RState_M, RNext_state_M;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) RState_M <= R_IDLE_M;
        else RState_M <= RNext_state_M;
    end
    
    always @* begin
        case (RState_M)
            R_IDLE_M : RNext_state_M = (ARREADY && r_transaction_count > 0) ? R_READY_M : R_IDLE_M;
            R_READY_M : RNext_state_M = (RVALID) ? R_IDLE_M : R_READY_M;
            default : RNext_state_M = R_IDLE_M;
        endcase 
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) RREADY <= 1'b0;
        else begin
            case (RNext_state_M)
                R_IDLE_M : RREADY <= 1'b0;
                R_READY_M : begin RREADY <= 1'b1; data_out <= RDATA; r_queue_head <= r_queue_head + 1; r_transaction_count <= r_transaction_count - 1; end
                default : RREADY <= 1'b0;
            endcase
        end
    end

    // Load write transactions into the queue
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            w_queue_head <= 0;
            w_queue_tail <= 0;
            w_transaction_count <= 0;
        end else if (w_transaction_count < 8) begin
            awaddr_queue[w_queue_tail] <= awaddr;
            wstrb_queue[w_queue_tail] <= wstrb;
            wdata_queue[w_queue_tail] <= wdata;
            w_queue_tail <= w_queue_tail + 1;
            w_transaction_count <= w_transaction_count + 1;
        end
    end

    // Load read transactions into the queue
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            r_queue_head <= 0;
            r_queue_tail <= 0;
            r_transaction_count <= 0;
        end else if (r_transaction_count < 8) begin
            araddr_queue[r_queue_tail] <= araddr;
            r_queue_tail <= r_queue_tail + 1;
            r_transaction_count <= r_transaction_count + 1;
        end
    end

endmodule

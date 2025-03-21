`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2024 10:20:16
// Design Name: 
// Module Name: axi_slave
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

module AXI_slave  #(parameter WIDTH=32)
    (
        input   ACLK, ARESETn,
        // AXI_interface.slave AXI_S

        // ADDRESS WRITE CHANNEL
        output reg  AWREADY,
        input   AWVALID,
        input   [WIDTH-1:0] AWADDR,

        // DATA WRITE CHANNEL
        output reg  WREADY,
        input   WVALID,
        input   [(WIDTH/8)-1:0] WSTRB,
        input   [WIDTH-1:0] WDATA,

        // WRITE RESPONSE CHANNEL
        output reg [1:0]    BRESP,
        output reg  BVALID,
        input   BREADY,

        // READ ADDRESS CHANNEL
        output reg  ARREADY,
        input   [WIDTH-1:0] ARADDR,
        input   ARVALID,

        // READ DATA CHANNEL
        output reg  [WIDTH-1:0] RDATA,
        output reg  [1:0] RRESP,
        output reg  RVALID,
        input   RREADY,

        // External read input
        input [WIDTH-1:0] ext_read_data,

        // Output for write data
        output reg [WIDTH-1:0] WDATA_out
    );

    ////////////////////// CREATING SLAVE MEMORY  
    reg  [7:0] slave_mem[7:0];
    reg [31:0] AWADDR_reg;
    reg [31:0] ARADDR_reg;

    // FIFO for Write Transactions
    reg [WIDTH-1:0] write_addr_fifo [4:0]; // Adjusted to handle 5 transactions
    reg [(WIDTH/8)-1:0] write_strb_fifo [4:0]; // Adjusted to handle 5 transactions
    reg [WIDTH-1:0] write_data_fifo [4:0]; // Adjusted to handle 5 transactions
    reg [2:0] write_fifo_head;
    reg [2:0] write_fifo_tail;
    reg [2:0] write_fifo_count;

    // FIFO for Read Transactions
    reg [WIDTH-1:0] read_addr_fifo [4:0]; // Adjusted to handle 5 transactions
    reg [WIDTH-1:0] read_data_fifo [4:0]; // Adjusted to handle 5 transactions
    reg [2:0] read_fifo_head;
    reg [2:0] read_fifo_tail;
    reg [2:0] read_fifo_count;

    // Write Address Channel
    parameter [1:0] WA_IDLE_S = 2'b00,
                    WA_START_S= 2'b01,
                    WA_READY_S= 2'b10;

    reg [1:0] WAState_S, WANext_state_S;

    // Sequential Block
    always@(posedge ACLK or negedge ARESETn)
        if (!ARESETn)
            WAState_S <= WA_IDLE_S; 
        else
            WAState_S <= WANext_state_S;

    // Next State Determination Logic
    always @*
        case (WAState_S)
            WA_IDLE_S  : if (AWVALID && write_fifo_count < 5) WANext_state_S = WA_START_S; // Adjusted for 5 transactions
                         else WANext_state_S = WA_IDLE_S;
            WA_START_S : WANext_state_S = WA_READY_S;
            WA_READY_S : WANext_state_S = WA_IDLE_S;
            default    : WANext_state_S = WA_IDLE_S;
        endcase

    // Output Determination Logic
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) begin
            AWREADY <= 1'b0;
            write_fifo_head <= 0;
            write_fifo_tail <= 0;
            write_fifo_count <= 0;
        end
        else
            case (WANext_state_S)
                WA_IDLE_S : AWREADY <= 1'b0;
                WA_START_S: begin 
                                AWREADY <= 1'b1;
                                write_addr_fifo[write_fifo_tail] <= AWADDR;
                                write_fifo_tail <= write_fifo_tail + 1;
                                write_fifo_count <= write_fifo_count + 1;
                             end
                WA_READY_S: AWREADY <= 1'b0;
                default   : AWREADY <= 1'b0;
            endcase

    // Write Data Channel
    parameter [1:0] W_IDLE_S  = 2'b00,
                    W_START_S = 2'b01,
                    W_WAIT_S  = 2'b10,
                    W_TRAN_S  = 2'b11;

    reg [1:0] WState_S, WNext_state_S;

    // Sequential Block
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn)
            WState_S <= W_IDLE_S;
        else
            WState_S <= WNext_state_S;

    // Next State Determining Block
    always @*
        case (WState_S)
            W_IDLE_S  : WNext_state_S = W_START_S;
            W_START_S : if (write_fifo_count > 0) WNext_state_S = W_WAIT_S;
                        else WNext_state_S = W_START_S;
            W_WAIT_S  : if (WVALID) WNext_state_S = W_TRAN_S;
                        else WNext_state_S = W_WAIT_S;
            W_TRAN_S  : WNext_state_S = W_IDLE_S;
            default   : WNext_state_S = W_IDLE_S;
        endcase

    // Output Determining Block
    integer i;    always @(posedge ACLK or negedge ARESETn) begin
         // Declare i here
        if (!ARESETn) begin
            WREADY <= 1'b0;
            WDATA_out <= {WIDTH{1'b0}};
            for (i=0; i<8; i=i+1)
                slave_mem[i] <= 8'b0;
        end
        else
            case (WNext_state_S)
                W_IDLE_S  : WREADY <= 1'b0;    
                W_START_S : WREADY <= 1'b0;
                W_WAIT_S  : WREADY <= 1'b0;
                W_TRAN_S  : begin   
                                WREADY <= 1'b1;
                                WDATA_out <= WDATA; // Assign WDATA to WDATA_out
                                write_strb_fifo[write_fifo_head] <= WSTRB;
                                write_data_fifo[write_fifo_head] <= WDATA;
                                write_fifo_head <= write_fifo_head + 1;
                                write_fifo_count <= write_fifo_count - 1;
                                case (WSTRB)
                                    4'b0001: slave_mem[write_addr_fifo[write_fifo_head][4:2]] <= WDATA[7:0];
                                    4'b0010: slave_mem[write_addr_fifo[write_fifo_head][4:2]] <= WDATA[15:8];
                                    4'b0100: slave_mem[write_addr_fifo[write_fifo_head][4:2]] <= WDATA[23:16];
                                    4'b1000: slave_mem[write_addr_fifo[write_fifo_head][4:2]] <= WDATA[31:24];
                                    default: slave_mem[write_addr_fifo[write_fifo_head][4:2]] <= WDATA[7:0];
                                endcase
                             end
                default   : WREADY <= 1'b0;
            endcase
    end

    // Write Response Channel
    parameter [1:0] B_IDLE_S = 2'b00,
                    B_START_S= 2'b01,
                    B_READY_S= 2'b10;

    reg [1:0] BState_S, BNext_state_S;

    // Sequential Block
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn)
            BState_S <= B_IDLE_S;
        else
            BState_S <= BNext_state_S;

    // Next State Determining Logic
    always @*
        case (BState_S)
            B_IDLE_S  : if (WREADY) BNext_state_S = B_START_S;
                        else BNext_state_S = B_IDLE_S;
            B_START_S : BNext_state_S = B_READY_S;
            B_READY_S : BNext_state_S = B_IDLE_S;
            default   : BNext_state_S = B_IDLE_S;
        endcase

    // Output Determining Logic
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) begin
            BVALID <= 1'b0;
            BRESP  <= 2'b00;
        end
        else
            case (BNext_state_S)
                B_IDLE_S  : begin BVALID <= 1'b0; BRESP <= 2'b00; end
                B_START_S : begin BVALID <= 1'b1; BRESP <= 2'b00; end
                B_READY_S : begin BVALID <= 1'b0; BRESP <= 2'b00; end
                default   : begin BVALID <= 1'b0; BRESP <= 2'b00; end
            endcase

    // Read Address Channel
    parameter [1:0] AR_IDLE_S = 2'b00,
                    AR_READY_S = 2'b01;
    reg [1:0] ARState_S, ARNext_State_S;

    // Sequential Block
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn)
            ARState_S <= AR_IDLE_S;
        else
            ARState_S <= ARNext_State_S;

    // Next State Determining Logic
    always @*
        case (ARState_S)
            AR_IDLE_S : if (ARVALID && read_fifo_count < 5) ARNext_State_S = AR_READY_S; // Adjusted for 5 transactions
                        else ARNext_State_S = AR_IDLE_S;
            AR_READY_S: ARNext_State_S = AR_IDLE_S;
            default   : ARNext_State_S = AR_IDLE_S;
        endcase

    // Output Determining Logic
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) begin
            ARREADY <= 1'b0;
            read_fifo_head <= 0;
            read_fifo_tail <= 0;
            read_fifo_count <= 0;
        end
        else
            case (ARNext_State_S)
                AR_IDLE_S  : ARREADY <= 1'b0;
                AR_READY_S : begin 
                                ARREADY <= 1'b1; 
                                read_addr_fifo[read_fifo_tail] <= ARADDR; 
                                read_fifo_tail <= read_fifo_tail + 1;
                                read_fifo_count <= read_fifo_count + 1;
                             end
                default    : ARREADY <= 1'b0;
            endcase

    // Read Data Channel
    parameter [1:0] R_IDLE_S = 2'b00,
                    R_START_S = 2'b01,
                    R_VALID_S = 2'b10;
    reg [1:0] RState_S, RNext_state_S;

    // Sequential Block
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn)
            RState_S <= R_IDLE_S;
        else
            RState_S <= RNext_state_S;

    // Next State Determination
    always @*
        case (RState_S)
            R_IDLE_S  : if (read_fifo_count > 0) RNext_state_S = R_START_S;
                        else RNext_state_S = R_IDLE_S;
            R_START_S : RNext_state_S = R_VALID_S;
            R_VALID_S : if (RREADY) RNext_state_S = R_IDLE_S;
                        else RNext_state_S = R_VALID_S;
            default   : RNext_state_S = R_IDLE_S;
        endcase

    // Output Determining Logic
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) begin
            RVALID <= 1'b0;
            RDATA  <= 0;
            RRESP  <= 2'b00;
        end
        else
            case (RNext_state_S)
                R_IDLE_S  : RVALID <= 1'b0;
                R_START_S : begin 
                                RVALID <= 1'b0; 
                                RDATA  <= ext_read_data; // Assign data from external read input
                                read_data_fifo[read_fifo_head] <= ext_read_data;
                                read_fifo_head <= read_fifo_head + 1;
                                read_fifo_count <= read_fifo_count - 1;
                             end
                R_VALID_S : begin 
                                RVALID <= 1'b1; 
                                RRESP  <= 2'b00; // OKAY response
                             end
                default   : begin
                                RVALID <= 1'b0;
                                RRESP  <= 2'b00;
                             end
            endcase

endmodule

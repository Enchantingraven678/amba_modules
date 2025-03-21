`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2025 17:31:53
// Design Name: 
// Module Name: axi_top
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


module AXI_top #(parameter WIDTH=32) 
    (
        input  ACLK,
        input  ARESETn,
        input  [WIDTH-1:0] awaddr,
        input  [(WIDTH/8)-1:0] wstrb,
        input  [WIDTH-1:0] wdata,          // data input to master to write to slave
        input  [WIDTH-1:0] araddr,         // address for read operation
        input  [WIDTH-1:0] ext_read_data,  // External read data input applied to slave
        output [WIDTH-1:0] data_out,       // master output (external read data) coming from slave
        output [WIDTH-1:0] WDATA_out       // output from slave interface (this data must be WDATA)
    );

    // ADDRESS WRITE CHANNEL
    wire AWREADY;
    wire AWVALID;
    wire [WIDTH-1:0] AWADDR;

    // DATA WRITE CHANNEL
    wire WREADY;
    wire WVALID;
    wire [(WIDTH/8)-1:0] WSTRB;
    wire [WIDTH-1:0] WDATA;

    // WRITE RESPONSE CHANNEL
    wire [1:0] BRESP;
    wire BVALID;
    wire BREADY;

    // READ ADDRESS CHANNEL
    wire ARREADY;
    wire ARVALID;
    wire [WIDTH-1:0] ARADDR;

    // READ DATA CHANNEL
    wire [WIDTH-1:0] RDATA;
    wire [1:0] RRESP;
    wire RVALID;
    wire RREADY;

    // WDATA output from the slave
    wire [WIDTH-1:0] WDATA_out_slave;

    // AXI MASTER
    AXI_master #(
        .WIDTH(WIDTH)
    ) mstr (
        .awaddr(awaddr),
        .wstrb(wstrb),
        .wdata(wdata),
        .araddr(araddr),
        .data_out(data_out),      // Note: data_out is connected to RDATA
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // ADDRESS WRITE CHANNEL
        .AWREADY(AWREADY),
        .AWVALID(AWVALID),
        .AWADDR(AWADDR),
        
        // DATA WRITE CHANNEL
        .WREADY(WREADY),
        .WVALID(WVALID),
        .WSTRB(WSTRB),
        .WDATA(WDATA),
        
        // WRITE RESPONSE CHANNEL
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),

        // READ ADDRESS CHANNEL
        .ARREADY(ARREADY),
        .ARVALID(ARVALID),
        .ARADDR(ARADDR),
        
        // READ DATA CHANNEL
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );

    // AXI SLAVE
    AXI_slave #(
        .WIDTH(WIDTH)
    ) slv (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        // ADDRESS WRITE CHANNEL
        .AWREADY(AWREADY),
        .AWVALID(AWVALID),
        .AWADDR(AWADDR),
        
        // DATA WRITE CHANNEL
        .WREADY(WREADY),
        .WVALID(WVALID),
        .WSTRB(WSTRB),
        .WDATA(WDATA),
        
        // WRITE RESPONSE CHANNEL
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),

        // READ ADDRESS CHANNEL
        .ARREADY(ARREADY),
        .ARVALID(ARVALID),
        .ARADDR(ARADDR),
        
        // READ DATA CHANNEL
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),

        // External read data input
        .ext_read_data(ext_read_data),

        // Write data output
        .WDATA_out(WDATA_out_slave)
    );

    // Assign WDATA_out from the slave to WDATA_out
    assign WDATA_out = WDATA_out_slave;

    // Assign RDATA from the slave to data_out (updated to match new slave behavior)
    assign data_out = RDATA;

endmodule // AXI_top

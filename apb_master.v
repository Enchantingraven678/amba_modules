`timescale 1ns / 1ps
 module apb_master #(
   // Configurable Parameters
   parameter DW = 32 ,  // Data width
   parameter AW = 8  ,  // Address width; max. 32 as per APB spec

   // Derived Parameters
   localparam SW = int'($ceil(DW/8)),  // Strobe width
   localparam CW = 1 + SW + DW + AW ,  // Command width  {pwrite, pstrb, pwdata, paddr}  
   localparam RW = 1 + DW              // Response width {pslverr, prdata}
)
(
   // Clock and Reset
   input  logic pclk    ,  // Clock
   input  logic presetn ,  // Reset
   
   // Command & Response Interface
   input  logic [CW-1:0] i_cmd   ,  // Command
   input  logic          i_valid ,  // Valid
   output logic [RW-1:0] o_resp  ,  // Response
   output logic          o_ready ,  // Ready

   // APB Interface
   output logic [AW-1:0] o_paddr   ,  // Address 
   output logic          o_pwrite  ,  // Write enable
   output logic          o_psel    ,  // Select
   output logic          o_penable ,  // Enable
   output logic [DW-1:0] o_pwdata  ,  // Write data
   output logic [SW-1:0] o_pstrb   ,  // Write strobe
   input  logic [DW-1:0] i_prdata  ,  // Read data
   input  logic          i_pslverr ,  // Slave error
   input  logic          i_pready     // Ready
);

// State Encoding
typedef enum logic [1:0] {
   IDLE   = 2'b00,   
   SETUP  = 2'b01,
   ACCESS = 2'b10
} state_t;

// State Register
state_t state_ff, nxt_state;

// Internal registers to store command during setup
logic [AW-1:0] addr_reg;
logic [DW-1:0] wdata_reg;
logic [SW-1:0] pstrb_reg;
logic         pwrite_reg;

// State Machine
always_ff @(posedge pclk or negedge presetn) begin
   if (!presetn) begin
      state_ff <= IDLE;
   end else begin
      state_ff <= nxt_state;
   end
end

always_comb begin
   case (state_ff)
      IDLE    : nxt_state = (i_valid) ? SETUP : IDLE;
      SETUP   : nxt_state = ACCESS;
      ACCESS  : nxt_state = (i_pready) ? IDLE : ACCESS;
      default : nxt_state = IDLE;
   endcase
end

// Capture command during SETUP state
always_ff @(posedge pclk or negedge presetn) begin
   if (!presetn) begin
      addr_reg   <= 0;
      wdata_reg  <= 0;
      pstrb_reg  <= 0;
      pwrite_reg <= 0;
   end else if (state_ff == IDLE && i_valid) begin
      addr_reg   <= i_cmd[0+:AW];
      wdata_reg  <= i_cmd[AW+:DW];
      pstrb_reg  <= i_cmd[(CW-2)-:SW];
      pwrite_reg <= i_cmd[CW-1];
   end
end

// APB Interface Outputs
assign o_paddr   = addr_reg;
assign o_pwrite  = pwrite_reg;
assign o_pwdata  = wdata_reg;
assign o_pstrb   = pstrb_reg;
assign o_psel    = (state_ff == SETUP || state_ff == ACCESS);
assign o_penable = (state_ff == ACCESS);

// Outputs to Command Interface
assign o_resp  = {i_pslverr, i_prdata};
assign o_ready = (state_ff == ACCESS && i_pready);

endmodule

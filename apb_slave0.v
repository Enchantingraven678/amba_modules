`timescale 1ns / 1ps

module apb_slave #(
   parameter DW = 32 ,  // Data width
   parameter AW = 5     // Address width; max. 32 as per APB spec
)
(
   input  logic pclk,  
   input  logic presetn,  
   input  logic [AW-1:0] i_paddr,  
   input  logic i_pwrite,  
   input  logic i_psel,  
   input  logic i_penable,  
   input  logic [DW-1:0] i_pwdata,  
   input  logic [(DW/8)-1:0] i_pstrb,  // Strobe width derived
   output logic [DW-1:0] o_prdata,  
   output logic o_pslverr,  
   output logic o_pready,  
   output logic o_hw_ctl,   
   input  logic i_hw_sts    
);

// Local parameters
localparam SW = DW / 8;  // Strobe width
localparam ADDR_LSB = $clog2(DW/8);
localparam N_REG    = 2**(AW-ADDR_LSB);  

// State Encoding
typedef enum logic [1:0] { 
   IDLE     = 2'b00, 
   W_ACCESS = 2'b01, 
   R_ACCESS = 2'b10 
} state_t;

state_t state_ff, nxt_state;

// Address and Register Storage
logic [DW-1:0] apb_reg[3];   // Registers 0,1,2 are writeable
logic [AW-1-ADDR_LSB:0] paddr;
logic req_rd, req_wr;
logic [DW-1:0] read_data;

// Read-Only and HW-driven registers
logic [DW-1:0] ro_reg3, ro_reg4;
logic wr_err;

// Control Signals
assign req_rd = i_psel && ~i_pwrite;
assign req_wr = i_psel &&  i_pwrite;
assign paddr  = i_paddr [AW-1:ADDR_LSB];

// Read-Only Register Assignments
assign ro_reg3 = 32'hDEAD_BEEF;
assign ro_reg4 = i_hw_sts;

// HW control signal
assign o_hw_ctl = apb_reg[0];

// Error detection (Write protection for read-only registers)
assign wr_err = (req_wr && (paddr == 3 || paddr == 4));
assign o_pslverr = wr_err;

// Next State Logic
always_comb begin
   case (state_ff)
      IDLE: begin
         if (req_wr && i_penable) 
            nxt_state = W_ACCESS;
         else if (req_rd && i_penable) 
            nxt_state = R_ACCESS;
         else 
            nxt_state = IDLE;
      end
      W_ACCESS: nxt_state = IDLE;
      R_ACCESS: nxt_state = IDLE;
      default:  nxt_state = IDLE;
   endcase
end

// State Transition
always_ff @(posedge pclk or negedge presetn) begin   
   if (!presetn) begin      
      state_ff  <= IDLE;
   end   
   else begin       
      state_ff  <= nxt_state;
   end
end

// Read and Write Handling
always_ff @(posedge pclk or negedge presetn) begin   
   if (!presetn) begin      
      apb_reg[0] <= '0;
      apb_reg[1] <= '0;
      apb_reg[2] <= '0;
      read_data  <= '0;
   end   
   else if (req_wr && i_penable && !wr_err) begin
      case (paddr)
         0 : apb_reg[0] <= i_pwdata;
         1 : apb_reg[1] <= i_pwdata;
         2 : apb_reg[2] <= i_pwdata;
         default: ;
      endcase
   end
   else if (req_rd && i_penable) begin
      case (paddr)
         0 : read_data <= apb_reg[0];                     
         1 : read_data <= apb_reg[1];
         2 : read_data <= apb_reg[2];
         3 : read_data <= ro_reg3;
         4 : read_data <= ro_reg4;
         default : read_data <= '0;                
      endcase
   end
end

// APB Output Signals
always_ff @(posedge pclk or negedge presetn) begin
   if (!presetn) begin
      o_pready  <= 1'b0;
      o_prdata  <= '0;
   end
   else begin
      case (state_ff)
         IDLE: o_pready <= 1'b0;
         W_ACCESS: o_pready <= 1'b1;
         R_ACCESS: begin
            o_prdata <= read_data;
            o_pready <= 1'b1;
         end
         default: o_pready <= 1'b0;
      endcase
   end
end

endmodule

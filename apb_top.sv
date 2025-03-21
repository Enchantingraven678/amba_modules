`timescale 1ns / 1ps

module apb_top;

   // Parameters
   parameter DW = 32;  // Data width
   parameter AW = 5;   // Address width (fixed as per APB spec)
   parameter SW = (DW/8);  // Strobe width
   parameter CW = 1 + SW + DW + AW;  // Command width {pwrite, pstrb, pwdata, paddr}  
   parameter RW = 1 + DW;  // Response width {pslverr, prdata}

   // Clock and Reset
   logic pclk;
   logic presetn;

   // APB signals
   logic [AW-1:0] paddr;
   logic pwrite;
   logic psel;
   logic penable;
   logic [DW-1:0] pwdata;
   logic [SW-1:0] pstrb;
   logic [DW-1:0] prdata;
   logic pslverr;
   logic pready;

   // HW interface signals
   logic hw_ctl;
   logic hw_sts;

   // Command and Response signals
   logic [CW-1:0] cmd;
   logic valid;
   logic [RW-1:0] resp;
   logic ready;

   // Clock generation (50% duty cycle)
   always #5 pclk = ~pclk;

   // Reset initialization
   initial begin
      pclk = 0;
      presetn = 0;
      #15 presetn = 1;  // Ensuring proper reset time
   end

   // Instantiate APB Master
   apb_master #(
      .DW(DW),
      .AW(AW)
   ) u_apb_master (
      .pclk(pclk),
      .presetn(presetn),
      .i_cmd(cmd),
      .i_valid(valid),
      .o_resp(resp),
      .o_ready(ready),
      .o_paddr(paddr),
      .o_pwrite(pwrite),
      .o_psel(psel),
      .o_penable(penable),
      .o_pwdata(pwdata),
      .o_pstrb(pstrb),
      .i_prdata(prdata),
      .i_pslverr(pslverr),
      .i_pready(pready)
   );

   // Instantiate APB Slave
   apb_slave #(
      .DW(DW),
      .AW(AW)
   ) u_apb_slave (
      .pclk(pclk),
      .presetn(presetn),
      .i_paddr(paddr),
      .i_pwrite(pwrite),
      .i_psel(psel),
      .i_penable(penable),
      .i_pwdata(pwdata),
      .i_pstrb(pstrb),
      .o_prdata(prdata),
      .o_pslverr(pslverr),
      .o_pready(pready),
      .o_hw_ctl(hw_ctl),
      .i_hw_sts(hw_sts)
   );

   // Command and Response Handling
   initial begin
      valid = 0;
      cmd = '0;
      #20;
      
      // Write Command (Write to register 0)
      cmd = {1'b1, 4'b1111, 32'hA5A5A5A5, 5'b00000};  // {pwrite, pstrb, pwdata, paddr}
      valid = 1;
      #10;
      valid = 0;
      
      // Read Command (Read from register 0)
      #20;
      cmd = {1'b0, 4'b0000, 32'h00000000, 5'b00000};
      valid = 1;
      #10;
      valid = 0;
      
      // Wait and Observe
      #50;
      
      $stop;
   end

endmodule

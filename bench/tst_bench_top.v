module testbench();
  // simple_spi_top top0(32'h0);
   



//module simple_spi_top(input[31:0] index);


/* -----\/----- EXCLUDED -----\/-----
   import "DPI-C" function
     int pull_apb(output int _paddr, output int _pwrite,
		  output int _pwdata, input int index);
   import "DPI-C" function
     int resp_apb(input int index, input int _paddr, input int _pwrite,
		  input int _pwdata, input int _prdata);
 -----/\----- EXCLUDED -----/\----- */


   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [7:0] 		    prdata;			// From slave of apb_slave.v
   wire 		    pslaverr;                   // normal bus termination -- PSLAVERR
   wire 		    intr_0;                     // interrupt output

   //SPI port
   wire 		    sck_o; 		    // serial clock output
   wire 		    mosi_o; 		    //  MasterOut SlaveIN
  		    
   // End of automatics
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg 			    clk;			// To slave of apb_slave.v
   reg [7:0] 		    paddr;			// To slave of apb_slave.v
   reg 			    penable;		// To slave of apb_slave.v
   reg 			    psel;			// To slave of apb_slave.v
   reg [7:0] 		    pwdata;			// To slave of apb_slave.v
   reg 			    pwrite;			// To slave of apb_slave.v
   reg 			    presetn;			// To slave of apb_slave.v

   //SPI master inputs
    reg		    miso_i; 		    // MasterIn SlaveOut

   // End of automatics
    			    
  			    
   reg [7:0] 	    _paddr;
   reg [7:0] 	    _pwrite;
   reg [7:0] 	    _pdata;
   reg              _retval;

   simple_spi_top spi_top(/*AUTOINST*/
			  // Outputs
			  .PRDATA		(prdata[7:0]),
			  // Inputs
			  .PCLK			(clk),
			  .PRESETn		(presetn),
			  .PADDR		(paddr[7:0]),
			  .PWRITE		(pwrite),
			  .PSEL		(psel),
			  .PENABLE		(penable),
			  .PWDATA		(pwdata[7:0]),
			  .PSLAVERR            (pslaverr),
			  .INTR_0              (intr_0),
			  .sck_o               (sck_o),
			  .mosi_o              (mosi_o),
			  .miso_i              (miso_i));


   initial begin
      clk = 1'b0;
      forever begin
         #5 clk = 1'b1;
	 #5 clk = 1'b0;
      end
   end
   
   initial begin
       $dumpfile("apb.vcd");
       $dumpvars(0, testbench);
       $dumpon;
      presetn = 1'b0;
      psel = 0;
      penable = 0;
      #50 presetn = 1'b1;
   end

   task write_apb(input [7:0] addr,
	      input [7:0] data);
      begin
	 @(negedge clk);
	 paddr <= addr;
	 psel <= 1;
	 pwrite <= 1;
	 pwdata <= data;
	 @(negedge clk);
	 penable <= 1;
	 @(negedge clk);
	 psel <= 0;
	 penable <= 0;
      end
   endtask // write

    task read_apb(input [7:0] addr);
       begin
	  @(negedge clk);
	  paddr <= addr;
	  psel <= 1;
	  pwrite <= 0;
	  @(negedge clk);
	  penable <= 1;
	  @(negedge clk);
	  _pdata = prdata;
	  psel    <= 0;
	  penable <= 0;
       end
    endtask // read


   task read_spi(input sclk, input data);
      #10;
   endtask

   always @(sck_o)
     if ($mosi_put(sck_o, mosi_o));

   always @(sck_o)
     if ($miso_put(sck_o, miso_i));

   initial begin: bfm_apb
      // initEsdl();
      #100;	// let the reset settle
      forever begin
	 while (presetn == 1'b0) begin
	    @(posedge clk);
	 end // while (presetn == 1'b0)
	 
	 @(negedge clk);
	 case($apb_try_next_item(_paddr, _pdata, _pwrite))
	   0: begin: valid_transation
	      if(_pwrite == 1) begin
		 write_apb(_paddr, _pdata);
	      end // if (_pwrite ==1)
	      else begin
		 read_apb(_paddr);
	      end // else: !if(_pwrite ==1)
	      if ($apb_item_done(0) != 0) ; // $finish;
	      if ($apb_put(_paddr,_pdata,_pwrite,pslaverr));
	   end // block: valid_transation
	   default: begin: idle_transation
	   end // block: idle_transation
	 endcase // case ($apb_try_next_item(_paddr, _pdata, _pwrite))
	 
	 
	 /* -----\/----- EXCLUDED -----\/-----
          retval <= pull_apb(_paddr, _pwrite, _pwdata, INDEX);
	  @(negedge clk);
	  paddr <= _paddr;
	  psel <= 1;
	  pwrite <= _pwrite;
	  if(_pwrite) begin	// write
	  pwdata <= _pwdata;
	  @(negedge clk);
	  penable <= 1;
	  @(negedge clk);
	  psel <= 0;
	  penable <= 0;
	 end // if (_pwrite)
	  else begin
	  @(negedge clk);
	  penable <= '1;
	  @(negedge clk);
	  _prdata = prdata;
	  psel    <= '0;
	  penable <= '0;
	 end // else: !if(_pwrite)
	  retval <= resp_apb(INDEX, _paddr, _pwrite, _pwdata, _prdata);
	  -----/\----- EXCLUDED -----/\----- */
      end // forever begin
   end // block: bfm

   
   
endmodule

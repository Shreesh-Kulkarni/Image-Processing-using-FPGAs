//this module is for reading the image in hex format
`include "parameter.v" 						// Include definition file
module image_read
#(
    parameter WIDTH = 768, // Image width
    HEIGHT 	= 512, // Image height
    INPFILE  = "input.hex", // image file
    START_UP_DELAY = 100, // we provide initial delay during startup for calibration	
    HSYNC_DELAY = 150, //delay for two horizontal synchronous moving pulses for one iteration read				
    VALUE= 150, // value for brightness increment/decrement. i.e more the value more the brightness increason
    THRESH= 100, //value for thresholding the image			
    //BSIGN=0
    BSIGN=1				// this variable helps in determining whther the user wants to increase or decrease brightness. IF 0 brightness decreases, IF 1 brightness increasos
)
(
    input HCLK, // clock					
    input HRESETn, // Reset (active low)
    output VSYNC, // Vertical synchronous pulse
    output reg HSYNC, // Horizontal synchronous pulse
    // An HSYNC indicates that one line of the image is transmitted.
    output reg [7:0]  D_R0, // 8 bit Red data (even)
    output reg [7:0]  D_G0, // 8 bit Green data (even)
    output reg [7:0]  D_B0, // 8 bit Blue data (even)
    output reg [7:0]  D_R1, // 8 bit Red  data (odd)
    output reg [7:0]  D_G1, // 8 bit Green data (odd)
    output reg [7:0]  D_B1, // 8 bit Blue data (odd)
    output			  ctrl_done // Done flag
);
    parameter data_width = 8; // data width
    parameter image_length = 1179648; // image data : 1179648 bytes: 512 * 768 *3 
    // local parameters for FSM
    localparam		ST_IDLE 	= 2'b00, // idle state
    ST_VSYNC	= 2'b01, // state for creating vsync 
    ST_HSYNC	= 2'b10, // state for creating hsync 
    ST_DATA		= 2'b11; // state for data processing 
    reg [1:0] cur_state, // current state
    nxt_state; // next state			
    reg start; // start signal: trigger Finite state machine beginning to operate
    reg HRESETn_d; // delayed reset signal: use to create start signal
    reg 		ctrl_vsync_run; // control signal for vsync counter  
    reg [8:0]	ctrl_vsync_cnt; // counter for vsync
    reg 		ctrl_hsync_run; // control signal for hsync counter
    reg [8:0]	ctrl_hsync_cnt; // counter  for hsync
    reg 		ctrl_data_run; // control signal for data processing
    reg [31 : 0]  in_memory    [0 : image_length/4]; // memory to store  32-bit data image
    reg [7 : 0]   total_memory [0 : image_length-1]; // memory to store  8-bit data image
    // temporary memory to save image data : size will be WIDTH*HEIGHT*3
    integer temp_BMP   [0 : WIDTH*HEIGHT*3 - 1];
    integer org_R  [0 : WIDTH*HEIGHT - 1]; // temporary storage for R component
    integer org_G  [0 : WIDTH*HEIGHT - 1]; // temporary storage for G component
    integer org_B  [0 : WIDTH*HEIGHT - 1]; // temporary storage for B component
    // counting variables
    integer i, j;
    integer tempR0,tempR1,tempG0,tempG1,tempB0,tempB1; // temporary variables in contrast and brightness operation

    integer value,value1,value2,value4; // temporary variables in invert and threshold operation
    reg [ 9:0] row; // row index of the image
    reg [10:0] col; // column index of the image
    reg [18:0] d_count; // data counting for entire pixels of the image
    //the code for reading the image starts here pixel by pixel
    initial begin
        $readmemh(INPFILE,total_memory,0,image_length-1); // read file from INPFILE
    end
    // use 3 intermediate signals RGB to save image data
    always@(start) begin
        if(start == 1'b1) begin
            for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
                temp_BMP[i] = total_memory[i+0][7:0];
            end

            for(i=0; i<HEIGHT; i=i+1) begin
                for(j=0; j<WIDTH; j=j+1) begin
                    org_R[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+0]; // save Red component
                    org_G[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+1]; // save Green component
                    org_B[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+2]; // save Blue component
                end
            end
        end
    end
    //----------------------------------------------------//
    // ---Begin to read image file once reset was high ---//
    // ---by creating a starting pulse (start)------------//
    //----------------------------------------------------//
    always@(posedge HCLK, negedge HRESETn)
    begin
        if(!HRESETn) begin
            start <= 0;
            HRESETn_d <= 0;
        end
        else begin //        		______ 				
            HRESETn_d <= HRESETn; //       	|		|
            if(HRESETn == 1'b1 && HRESETn_d == 1'b0) // __0___|	1	|___0____	: starting pulse
                start <= 1'b1;
            else
                start <= 1'b0;
        end
    end

    //-----------------------------------------------------------------------------------------------//
    // Finite state machine for reading RGB888 data from memory and creating hsync and vsync pulses --//
    //-----------------------------------------------------------------------------------------------//
    always@(posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn) begin
            cur_state <= ST_IDLE;
        end
        else begin
            cur_state <= nxt_state; // update next state 
        end
    end
    //-----------------------------------------//
    //--------- State Transition --------------//
    //-----------------------------------------//
    // IDLE . VSYNC . HSYNC . DATA
    always @(*) begin
        case(cur_state)
            ST_IDLE: begin
                if(start)
                    nxt_state = ST_VSYNC;
                else
                    nxt_state = ST_IDLE;
            end
            ST_VSYNC: begin
                if(ctrl_vsync_cnt == START_UP_DELAY)
                    nxt_state = ST_HSYNC;
                else
                    nxt_state = ST_VSYNC;
            end
            ST_HSYNC: begin
                if(ctrl_hsync_cnt == HSYNC_DELAY)
                    nxt_state = ST_DATA;
                else
                    nxt_state = ST_HSYNC;
            end
            ST_DATA: begin
                if(ctrl_done)
                    nxt_state = ST_IDLE;
                else begin
                    if(col == WIDTH - 2)
                        nxt_state = ST_HSYNC;
                    else
                        nxt_state = ST_DATA;
                end
            end
        endcase
    end
    // ------------------------------------------------------------------- //
    // --- counting for time period of vsync, hsync, data processing ----  //
    // ------------------------------------------------------------------- //
    always @(*) begin
        ctrl_vsync_run = 0;
        ctrl_hsync_run = 0;
        ctrl_data_run  = 0;
        case(cur_state)
            ST_VSYNC: 	begin ctrl_vsync_run = 1; end // trigger counting for vsync
            ST_HSYNC: 	begin ctrl_hsync_run = 1; end // trigger counting for hsync
            ST_DATA: 	begin ctrl_data_run  = 1; end // trigger counting for data processing
        endcase
    end
    // counters for vsync, hsync
    always@(posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn) begin
            ctrl_vsync_cnt <= 0;
            ctrl_hsync_cnt <= 0;
        end
        else begin
            if(ctrl_vsync_run)
                ctrl_vsync_cnt <= ctrl_vsync_cnt + 1; // counting for vsync
            else
                ctrl_vsync_cnt <= 0;

            if(ctrl_hsync_run)
                ctrl_hsync_cnt <= ctrl_hsync_cnt + 1; // counting for hsync		
            else
                ctrl_hsync_cnt <= 0;
        end
    end
    // counting column and row index  for reading memory 
    always@(posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn) begin
            row <= 0;
            col <= 0;
        end
        else begin
            if(ctrl_data_run) begin
                if(col == WIDTH - 2) begin
                    row <= row + 1;
                end
                if(col == WIDTH - 2)
                    col <= 0;
                else
                    col <= col + 2; // reading 2 pixels in parallel
            end
        end
    end
    //-------------------------------------------------//
    //----------------Data counting---------- ---------//
    //-------------------------------------------------//
    always@(posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn) begin
            d_count <= 0;
        end
        else begin
            if(ctrl_data_run)
                d_count <= d_count + 1;
        end
    end
    assign VSYNC = ctrl_vsync_run;
    assign ctrl_done = (d_count == 196607)? 1'b1: 1'b0; // done flag
    //-------------------------------------------------//
    //-------------  Image processing   ---------------//
    //-------------------------------------------------//
    always @(*) begin

        HSYNC   = 1'b0;
        D_R0 = 0;
        D_G0 = 0;
        D_B0 = 0;
        D_R1 = 0;
        D_G1 = 0;
        D_B1 = 0;
        if(ctrl_data_run) begin

            HSYNC   = 1'b1;
		`ifdef BRIGHTNESS_OPERATION	
		//brightness addition
		if(BSIGN == 1) begin
		// R0
		tempR0 = org_R[WIDTH * row + col   ] + VALUE;//for red color
		if (tempR0 > 255)
			D_R0 = 255;
		else
			D_R0 = org_R[WIDTH * row + col   ] + VALUE;
		// R1	
		tempR1 = org_R[WIDTH * row + col+1   ] + VALUE;
		if (tempR1 > 255)
			D_R1 = 255;
		else
			D_R1 = org_R[WIDTH * row + col+1   ] + VALUE;	
		// G0	
		tempG0 = org_G[WIDTH * row + col   ] + VALUE;//for green color
		if (tempG0 > 255)
		D_G0 = 255;
		else
		D_G0 = org_G[WIDTH * row + col   ] + VALUE;
		tempG1 = org_G[WIDTH * row + col+1   ] + VALUE;
		if (tempG1 > 255)
			D_G1 = 255;
		else
			D_G1 = org_G[WIDTH * row + col+1   ] + VALUE;		
		// B
		tempB0 = org_B[WIDTH * row + col   ] + VALUE;//for blue colour
		if (tempB0 > 255)
			D_B0 = 255;
		else
			D_B0 = org_B[WIDTH * row + col   ] + VALUE;
		tempB1 = org_B[WIDTH * row + col+1   ] + VALUE;
		if (tempB1 > 255)
			D_B1 = 255;
		else
			D_B1 = org_B[WIDTH * row + col+1   ] + VALUE;
	end
	else begin
	//brightness subtraction
		// R0
		tempR0 = org_R[WIDTH * row + col   ] - VALUE;
		if (tempR0 < 0)
			D_R0 = 0;
		else
			D_R0 = org_R[WIDTH * row + col   ] - VALUE;
		// R1	
		tempR1 = org_R[WIDTH * row + col+1   ] - VALUE;
		if (tempR1 < 0)
			D_R1 = 0;
		else
			D_R1 = org_R[WIDTH * row + col+1   ] - VALUE;	
		// G0	
		tempG0 = org_G[WIDTH * row + col   ] - VALUE;
		if (tempG0 < 0)
		D_G0 = 0;
		else
		D_G0 = org_G[WIDTH * row + col   ] - VALUE;
		tempG1 = org_G[WIDTH * row + col+1   ] - VALUE;
		if (tempG1 < 0)
			D_G1 = 0;
		else
			D_G1 = org_G[WIDTH * row + col+1   ] - VALUE;		
		// B
		tempB0 = org_B[WIDTH * row + col   ] - VALUE;
		if (tempB0 < 0)
			D_B0 = 0;
		else
			D_B0 = org_B[WIDTH * row + col   ] - VALUE;
		tempB1 = org_B[WIDTH * row + col+1   ] - VALUE;
		if (tempB1 < 0)
			D_B1 = 0;
		else
			D_B1 = org_B[WIDTH * row + col+1   ] - VALUE;
	 end
		`endif
	
		//inverting the image( this replaces black with white and white with black)
		`ifdef INVERT_OPERATION	
			value2 = (org_B[WIDTH * row + col  ] + org_R[WIDTH * row + col  ] +org_G[WIDTH * row + col  ])/3;
            D_R0=255-value2;
           D_G0=255-value2;
            D_B0=255-value2;
            value4 = (org_B[WIDTH * row + col+1  ] + org_R[WIDTH * row + col+1  ] +org_G[WIDTH * row + col+1  ])/3;
            D_R1=255-value4;
            D_G1=255-value4;
            D_B1=255-value4;		
		`endif
		//threshold operation( divides image into B+W segments)
		`ifdef THRESHOLD_OPERATION

		value = (org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
		if(value > THRESH) begin
			D_R0=255;
		    D_G0=255;
			D_B0=255;
		end
		else begin
			D_R0=0;
		    D_G0=0;
			D_B0=0;
		end
		value1 = (org_R[WIDTH * row + col+1   ]+org_G[WIDTH * row + col+1   ]+org_B[WIDTH * row + col+1   ])/3;
		if(value1 > THRESH) begin
			D_R1=255;
			D_G1=255;
			D_B1=255;
		end
		else begin
			D_R1=0;
			D_G1=0;
			D_B1=0;
		end		
		`endif
		
	end
    end

endmodule


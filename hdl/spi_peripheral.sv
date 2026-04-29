`timescale 1ns / 1ps
`default_nettype none

module spi_peripheral
    #(parameter DATA_WIDTH = 8)
    (
        input wire   clk,           // system clock (100 MHz)
        input wire   rst,           // reset signal
        input wire   [DATA_WIDTH-1:0] data_in,  // data to send to controller
        output logic [DATA_WIDTH-1:0] data_out, // data received from controller
        output logic data_valid,    // high when output data is present
 
        input wire   copi,          // (Controller-Out-Peripheral-In)
        output logic cipo,          // (Controller-In-Peripheral-Out)
        input wire   dclk,          // (Data Clock) - from controller
        input wire   cs             // (Chip Select) - from controller
    );
    
    parameter MAX_IDX = $clog2(DATA_WIDTH) - 1;
    
    // Edge detection for dclk and cs (CDC - Clock Domain Crossing)
    logic [2:0] dclk_sync;
    logic [2:0] cs_sync;
    logic dclk_rising;
    logic dclk_falling;
    logic cs_falling;
    
    // Data registers
    logic [DATA_WIDTH-1:0] current_data_in;
    logic [DATA_WIDTH-1:0] current_data_out;
    logic [MAX_IDX:0] idx;
    
    // Synchronize external signals to system clock domain
    always_ff @(posedge clk) begin
        if (rst) begin
            dclk_sync <= 3'b000;
            cs_sync <= 3'b111;
        end else begin
            dclk_sync <= {dclk_sync[1:0], dclk};
            cs_sync <= {cs_sync[1:0], cs};
        end
    end
    
    // Edge detection
    assign dclk_rising = (dclk_sync[2:1] == 2'b01);
    assign dclk_falling = (dclk_sync[2:1] == 2'b10);
    assign cs_falling = (cs_sync[2:1] == 2'b10);
    
    // SPI peripheral state machine
    always_ff @(posedge clk) begin
        if (rst) begin
            cipo <= 1'b0;
            data_out <= '0;
            data_valid <= 1'b0;
            current_data_in <= '0;
            current_data_out <= '0;
            idx <= '0;
        end 
        else if (cs_sync[2]) begin
            // CS is high - idle state
            data_valid <= 1'b0;
            cipo <= 1'b0;
            idx <= '0;
        end
        else if (cs_falling) begin
            // CS just went low - start of transaction
            // Load data to transmit and setup FIRST BIT immediately
            current_data_in <= data_in;
            current_data_out <= '0;
            idx <= DATA_WIDTH - 1;
            data_valid <= 1'b0;
            
            //Set first bit immediately for CPHA=1
            cipo <= data_in[DATA_WIDTH-1];  // First bit ready NOW
        end
        else if (!cs_sync[2]) begin
            // CS is low - transaction in progress
            
            // CPHA=1: Data changes on leading edge (rising for CPOL=0)
            if (dclk_rising) begin
                // Sample COPI input on rising edge
                current_data_out <= (current_data_out << 1) | copi;
                
                // Decrement index after sampling
                if (idx != 0) begin
                    idx <= idx - 1;
                end else begin
                    // Last bit sampled - transaction complete
                    data_valid <= 1'b1;
                end
            end
            
            // CPHA=1: Output next bit on trailing edge (falling for CPOL=0)
            else if (dclk_falling) begin
                //FIX: Output bit selected by idx
                if (idx != 0) begin
                    cipo <= current_data_in[idx - 1];  // Next bit
                end else begin
                    cipo <= 1'b0;  // Transaction done
                end
            end
        end
    end
    
endmodule

`default_nettype wire



// //gemini's fix: 
// // SPI peripheral state machine
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             cipo <= 1'b0;
//             data_out <= '0;
//             data_valid <= 1'b0;
//             current_data_out <= '0;
//             idx <= '0;
//         end 
//         else if (cs_sync[2]) begin
//             // CS is high - idle state
//             data_valid <= 1'b0;
//             cipo <= 1'b0;
//             idx <= '0;
//         end
//         else if (cs_falling) begin
//             // CS just went low - start of transaction
//             current_data_out <= '0;
//             idx <= DATA_WIDTH - 1;
//             data_valid <= 1'b0;
            
//             // FIX: For Mode 1 (CPHA=1), do NOT output the first bit on CS falling. 
//             // It must be placed on the line on the first clock edge (leading edge).
//         end
//         else if (!cs_sync[2]) begin
//             // CS is low - transaction in progress
            
//             // FIX: Clear data_valid by default so it acts as a single 1-cycle pulse
//             data_valid <= 1'b0; 
            
//             // Mode 1 (CPOL=0, CPHA=1): Leading edge is RISING
//             if (dclk_rising) begin
//                 // FIX: SHIFT out data on leading edge
//                 cipo <= data_in[idx];
//             end
            
//             // Mode 1 (CPOL=0, CPHA=1): Trailing edge is FALLING
//             else if (dclk_falling) begin
//                 // FIX: SAMPLE data on trailing edge
//                 current_data_out <= (current_data_out << 1) | copi;
                
//                 if (idx != 0) begin
//                     idx <= idx - 1;
//                 end else begin
//                     // Last bit sampled - transaction complete for THIS byte
//                     data_out <= {current_data_out[DATA_WIDTH-2:0], copi};
//                     data_valid <= 1'b1;        // Trigger 1-cycle pulse
//                     idx <= DATA_WIDTH - 1;     // FIX: Wrap index to support multi-byte bursts!
//                 end
//             end
//         end
//     end
module data_buffer(
    input wire valid,
    input wire [63:0] data_in,
    input wire clk,
    input wire resetn,
    output logic [63:0] data_out,
    output logic out_valid,
    output logic t_last,
    output logic [5:0] t_keep
);

localparam FILL = 0, READ_LEN = 1, READ_DATA = 2;
//note: read and write pointers have an extra bit for wrap and full detection, but I did not implement
logic [255:0] buffer;       // 32 bytes, enough to buffer messages
logic [5:0] write_ptr;      // where to write next byte to (0-31)
logic [5:0] read_ptr;       // where to read next byte from (0-31)
logic [5:0] bytes_stored;   // how many bytes are currently in buffer
logic [1:0] state;
logic [15:0] msg_len;       // remaining message length (bytes)
logic first_cycle;

// write to buffer
task automatic write_byte(input logic [5:0] pos, input logic [7:0] data);
    buffer[pos*8 +: 8] = data;
endtask


// read from buffer
function automatic [7:0] read_byte(input [5:0] pos);
    read_byte = buffer[pos*8 +: 8];
endfunction

always @(posedge clk) begin
    if (~resetn) begin
        write_ptr <= 6'd0;
        read_ptr <= 6'd0;
        bytes_stored <= 6'd0;
        state <= FILL;
        msg_len <= 16'd0;
        out_valid <= 1'b0;
        data_out <= 64'b0;
        first_cycle <= 1'b1;
        buffer <= 256'd0;
        t_last <= 1'b0;
        t_keep <= 1'b0;
    end else begin
        out_valid <= 1'b0;
        t_keep <= 1'b0;
        
        case (state)
            FILL: begin
                if (valid) begin
                    state <= READ_LEN;
                end
            end

            READ_LEN: begin

                t_last <= 1'b0;
                // need at least 2 bytes to read length, and if length is 0 there is an issue
                if (bytes_stored >= 6'd2 && |({read_byte(read_ptr), read_byte((read_ptr + 6'd1) & 6'h1F)})) begin
                    // read length
                    msg_len <= {read_byte(read_ptr), read_byte((read_ptr + 6'd1) & 6'h1F)};
                    
                    // move read pointer
                    read_ptr <= (read_ptr + 6'd2) & 6'h1F;
                    bytes_stored <= bytes_stored - 6'd2;
                    
                    state <= READ_DATA;
                end
            end

            READ_DATA: begin
                // determine how many bytes to output this cycle
                logic can_output;
                logic [5:0] bytes_to_consume;
                
                can_output = 1'b0;
                bytes_to_consume = 6'd0;
                
                if (msg_len >= 16'd8 && bytes_stored >= 6'd8) begin
                    // full 8 byte output
                    can_output = 1'b1;
                    bytes_to_consume = 6'd8;
                end else if (msg_len < 16'd8 && bytes_stored >= msg_len[5:0]) begin
                    // remaining bytes (last cycle)
                    can_output = 1'b1;
                    bytes_to_consume = msg_len[5:0];
                end
                
                if (can_output) begin
                    // read 8 bytes for output (for last send, set t_keep to indicate garbage at end)
                    data_out <= {
                        read_byte(read_ptr),
                        read_byte((read_ptr + 6'd1) & 6'h1F),
                        read_byte((read_ptr + 6'd2) & 6'h1F),
                        read_byte((read_ptr + 6'd3) & 6'h1F),
                        read_byte((read_ptr + 6'd4) & 6'h1F),
                        read_byte((read_ptr + 6'd5) & 6'h1F),
                        read_byte((read_ptr + 6'd6) & 6'h1F),
                        read_byte((read_ptr + 6'd7) & 6'h1F)
                    };
                    out_valid <= 1'b1;
                    
                    // update pointers based on actual bytes consumed
                    read_ptr <= (read_ptr + bytes_to_consume) & 6'h1F;
                    bytes_stored <= bytes_stored - bytes_to_consume;
                    msg_len <= msg_len - {10'd0, bytes_to_consume};
                    
                    // check if message is complete, set last and keep
                    if (msg_len <= {10'd0, bytes_to_consume}) begin
                        state <= READ_LEN;
                        t_last <= 1'b1;
                        t_keep <= bytes_to_consume;
                    end
                end
            end

            default: state <= FILL;
        endcase
        
        // Write incoming data to buffer
        if (valid) begin
            if (first_cycle) begin
                // first time, we skip first 4 bytes (message count + padding)
                // Only store bytes 4-7 (bits [47:0] of data_in)
                write_byte(write_ptr, data_in[47:40]);
                write_byte((write_ptr + 6'd1) & 6'h1F, data_in[39:32]);
                write_byte((write_ptr + 6'd2) & 6'h1F, data_in[31:24]);
                write_byte((write_ptr + 6'd3) & 6'h1F, data_in[23:16]);
                write_byte((write_ptr + 6'd4) & 6'h1F, data_in[15:8]);
                write_byte((write_ptr + 6'd5) & 6'h1F, data_in[7:0]);
                write_ptr <= (write_ptr + 6'd6) & 6'h1F;
                bytes_stored <= bytes_stored + 6'd6;
                first_cycle <= 1'b0;
            end else begin
                //other cycles, store all 8 bytes
                write_byte(write_ptr, data_in[63:56]);
                write_byte((write_ptr + 6'd1) & 6'h1F, data_in[55:48]);
                write_byte((write_ptr + 6'd2) & 6'h1F, data_in[47:40]);
                write_byte((write_ptr + 6'd3) & 6'h1F, data_in[39:32]);
                write_byte((write_ptr + 6'd4) & 6'h1F, data_in[31:24]);
                write_byte((write_ptr + 6'd5) & 6'h1F, data_in[23:16]);
                write_byte((write_ptr + 6'd6) & 6'h1F, data_in[15:8]);
                write_byte((write_ptr + 6'd7) & 6'h1F, data_in[7:0]);
                write_ptr <= (write_ptr + 6'd8) & 6'h1F;
                bytes_stored <= bytes_stored + 6'd8;
            end
        end
    end
end

endmodule
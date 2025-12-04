module stream_in (input logic [63:0] data_in, 
                  input logic t_valid,
                  input logic clk,
                  input logic resetn,
                  output logic [63:0] data_out, 
                  output logic t_ready,
                  output logic valid);

assign t_ready = t_valid & resetn; //combinationally set t_ready as long as valid and not reset

// need 2 cycles of delay at the end to push message out
logic [2:0] delay;

always @(posedge clk) begin
    if(~resetn) begin
        data_out <= 64'b0;
        valid <= 1'b0;
        delay <= 2'b0;
    end else begin
        //if transmission is valid, set data_out to data_in and send valid signal down line
        if(t_valid) begin
            data_out <= data_in;
            valid <= 1'b1;
            if (delay != 2'd2) begin
                delay <= 2'd2;
            end
        end else begin
            //pad message with 2 cycles of 0 to make sure buffer flushes
            if(delay != 0) begin
                data_out <= 64'b0;
                valid <= 1'b1;
                delay <= delay -1;
            end
        end
    end
end


endmodule
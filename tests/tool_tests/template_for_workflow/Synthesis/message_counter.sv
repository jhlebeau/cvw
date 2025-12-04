module message_counter(input logic [15:0] msg_count,
                       input logic valid,
                       input logic msg_done,
                       input logic clk,
                       input logic resetn,
                       output logic enable);

logic [15:0] counter;
logic prev_valid;
logic get_msg_count;

assign enable = (counter != 0); //if we have more messages coming, enable throughput

assign get_msg_count = valid & ~prev_valid;

always @(posedge clk) begin
    if(~resetn) begin
        counter <= 16'b0;
        prev_valid <= 1'b0;
    end else begin
        prev_valid <= valid;
        //if we have a valid counter input, set our counter to hold the expected number of incoming messages
        if(get_msg_count) begin
            counter <= msg_count;
        //if we receive a message done signal, decrement counter
        end else if (msg_done) begin
            //assertion for verification
            assert(counter != 0) else $error("Assertion failed (message_counter). Sending message when no more messages to send.");
            counter <= counter - 1;
        end
    end
end



endmodule
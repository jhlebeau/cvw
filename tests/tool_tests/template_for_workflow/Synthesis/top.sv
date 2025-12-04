module top(input [63:0] data_in,
           input t_valid_in,
           input clk,
           input resetn,
           output logic t_ready,
           output logic [63:0] t_data,
           output logic t_valid,
           output logic t_last,
           output logic [5:0] t_keep);

    logic [63:0] buffer_in;
    logic enable, valid;
    logic [63:0] processed_data;
    logic internal_t_last;

    assign t_last = internal_t_last;

    stream_in my_stream_in(.data_in(data_in), 
                  .t_valid(t_valid_in),
                  .clk(clk),
                  .resetn(resetn),
                  .data_out(processed_data), 
                  .t_ready(t_ready),
                  .valid(valid));

    message_counter my_msg_counter(.msg_count(processed_data[63:48]),
                       .valid(valid),
                       .msg_done(internal_t_last),
                       .clk(clk),
                       .resetn(resetn),
                       .enable(enable));

    data_buffer my_data_buffer(.valid(enable),
                        .data_in(buffer_in),
                        .clk(clk),
                        .resetn(resetn),
                        .data_out(t_data),
                        .out_valid(t_valid),
                        .t_last(internal_t_last),
                        .t_keep(t_keep));

    always @(posedge clk) begin
        if (t_valid_in | valid) begin
            buffer_in <= processed_data;
        end 
    end


endmodule
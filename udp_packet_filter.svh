module udp_packet_filter(
    input logic clk, rst,

    //configuration.......
    input logic [15:0] udp_port_to_match,

    //Data stream interfaces ...........
    packet_if.DUT stream_in_if,
    packet_if.DUT stream_out_if

);

logic [7:0] data_out_internal;
logic valid_out_internal;

assign stream_out_if.data = data_out_internal;
assign stream_out_if.valid = valid_out_internal;

typedef enum logic [2:0] { S_IDLE,
                            S_PARSE_ETH_HEADER,
                            S_PARSE_IP_HEADER,
                            S_PARSE_UDP_HEADER,
                            S_STREAM_PAYLOAD,
                            S_DROP_PACKET  } state_r;

state_r current_state, next_state;
logic [5:0] byte_counter;

logic [15:0] captured_eth_type;//store this value

logic [7:0] captured_ip_type;//store this value
logic captured_ip_protocol_is_ip;
logic [15:0] captured_dest_port;//store this value


//local parameters for packet and protocol values
localparam ETHER_HDR_LEN = 14;
localparam IP_HDR_LEN = 20;
localparam UDP_HDR_LEN = 8;

localparam ETH_TYPE_H_OFFSET = 12; //MSB of ETH TYPE
localparam ETH_TYPE_L_OFFSET = 13;//LSB of ETH TYPE

localparam IP_PROTOCOL_OFFSET = 23; //Protocol field

localparam UDP_DEST_PORT_H_OFFSET = 36;
localparam UDP_DEST_PORT_L_OFFSET = 37;

localparam ETHERTYPE_IPV4 = 16'h0800;
localparam IP_PROTOCOL_UDP = 8'h11;





always_ff @(posedge clk) begin
    if(rst) begin
        byte_counter <= '0;
        captured_eth_type <= '0;
        captured_ip_type <= '0;
        current_state <= S_IDLE;
    end else begin 
        current_state <= next_state;

        if(stream_in_if.valid) begin
            byte_counter <= byte_counter + 1'b1;
        //else byte_counter <= 1'b0;
        

            case(next_state)
                S_IDLE: begin
                    if(stream_in_if.valid) begin
                        // byte_counter <= byte_counter + 1'b1;
                        //next_state = S_PARSE_ETH_HEADER;
                        byte_counter <= 1'b0;
                    end //next_state = S_IDLE;
                end
                S_PARSE_ETH_HEADER: begin
                    if(byte_counter == ETH_TYPE_H_OFFSET) begin
                        captured_eth_type[15:8] <= stream_in_if.data;//store this value
                        //next_state = S_PARSE_ETH_HEADER;
                    end else if(byte_counter == ETH_TYPE_L_OFFSET) begin
                        captured_eth_type[7:0] <= stream_in_if.data;//store this value
                    // next_state = S_PARSE_ETH_HEADER;
                    end //else if (byte_counter == ETHER_HDR_LEN) begin
                        //if(captured_eth_type <== ETHERTYPE_IPV4) begin
                            //next_state = S_PARSE_IP_HEADER;
                        //end else // next_state = S_DROP_PACKET;
                    //end
                end
                S_PARSE_IP_HEADER: begin
                    if(byte_counter == IP_PROTOCOL_OFFSET) begin
                        captured_ip_type <= stream_in_if.data;//store this value
                        //next_state = S_PARSE_IP_HEADER;
                    // end else if( byte_counter == IP_HDR_LEN + ETHER_HDR_LEN) begin
                    //     if(captured_ip_type == IP_PROTOCOL_UDP) begin
                    //         //next_state = S_PARSE_UDP_HEADER;
                    //     end //else //next_state = S_DROP_PACKET;
                    end
                    if(captured_ip_type == IP_PROTOCOL_UDP) begin
                        captured_ip_protocol_is_ip <= 1'b1;
                    end else captured_ip_protocol_is_ip <= 1'b0;

                end
                S_PARSE_UDP_HEADER: begin
                    captured_ip_protocol_is_ip <= 1'b0;
                    if(byte_counter == UDP_DEST_PORT_H_OFFSET) begin
                        captured_dest_port[15:8] <= stream_in_if.data;//store this value
                    end else if (byte_counter ==  UDP_DEST_PORT_L_OFFSET) begin
                        captured_dest_port[7:0] <= stream_in_if.data;//store this value
                    end // else if (captured_dest_port == udp_port_to_match) begin
                    //     //next_state = S_STREAM_PAYLOAD;
                    // end else //next_state = S_DROP_PACKET;

                end
                S_STREAM_PAYLOAD: begin
                    // valid_out_internal <= stream_in_if.valid;//store this value
                    // data_out_internal <= stream_in_if.data;//store this value
                    // if(!stream_in_if.valid) begin
                    //     //next_state = S_IDLE;
                    // end
                end
                S_DROP_PACKET: begin
                    // valid_out_internal <= 1'b0;//store this value
                    // data_out_internal <= 8'h00;//store this value
                    // if(!stream_in_if.valid) begin
                    //     //next_state = S_IDLE;
                    // end
                end
                //default: byte_counter <= '0; //current_state = S_IDLE;

            endcase
        end
        if(next_state == S_IDLE && !stream_in_if.valid) begin
            byte_counter <= 6'd0;
        end

    end
end

always_comb begin
    if(rst) begin
        next_state = S_IDLE;
        valid_out_internal = 1'b0;//store this value
        data_out_internal = 8'h00;//store this value
    end else begin
        next_state = current_state;
        valid_out_internal = 1'b0;//store this value
        data_out_internal = 8'h00;//store this value
        case(current_state)
            S_IDLE: begin
                if(stream_in_if.valid) next_state = S_PARSE_ETH_HEADER;
            end
            S_PARSE_ETH_HEADER: begin
                if(stream_in_if.valid) begin
                    if(byte_counter == ETHER_HDR_LEN) begin
                        if(captured_eth_type == ETHERTYPE_IPV4) begin
                            next_state = S_PARSE_IP_HEADER;
                        end else next_state = S_DROP_PACKET;
                    end
                end
            end
            S_PARSE_IP_HEADER: begin
                if(stream_in_if.valid) begin
                    if( byte_counter == IP_HDR_LEN + ETHER_HDR_LEN) begin
                        if(captured_ip_protocol_is_ip) begin
                            next_state = S_PARSE_UDP_HEADER;
                        end else next_state = S_DROP_PACKET;
                    end
                end 
            end
            S_PARSE_UDP_HEADER: begin
                if(stream_in_if.valid) begin
                    if( byte_counter == (ETHER_HDR_LEN + IP_HDR_LEN + UDP_HDR_LEN-1)) begin
                        if (captured_dest_port == udp_port_to_match) begin
                            next_state = S_STREAM_PAYLOAD;
                        end else next_state = S_DROP_PACKET;
                    end
                end
            end
            S_STREAM_PAYLOAD: begin
                valid_out_internal = stream_in_if.valid;//store this value
                data_out_internal = stream_in_if.data;//store this value
                if(!stream_in_if.valid) begin
                    next_state = S_IDLE;
                end
            end
            S_DROP_PACKET: begin
                valid_out_internal = 1'b0;//store this value
                data_out_internal = 8'h00;//store this value
                if(!stream_in_if.valid) begin
                    next_state = S_IDLE;
                end
            end
        endcase
    end
end

// always_comb begin
//     if(rst) begin
//         next_state = S_IDLE;
//     end else begin
//         next_state = current_state;
//         case(current_state)
//             S_IDLE: begin
//                 if(stream_in_if.valid) begin
//                     byte_counter = byte_counter + 1'b1;
//                     next_state = S_PARSE_ETH_HEADER;
//                 end else next_state = S_IDLE;
//             end
//             S_PARSE_ETH_HEADER: begin
//                 if(byte_counter == ETH_TYPE_H_OFFSET) begin
//                     captured_eth_type[15:8] = stream_in_if.data;//store this value
//                     next_state = S_PARSE_ETH_HEADER;
//                 end else if(byte_counter == ETH_TYPE_L_OFFSET) begin
//                     captured_eth_type[7:0] = stream_in_if.data;//store this value
//                     next_state = S_PARSE_ETH_HEADER;
//                 end else if (byte_counter == ETHER_HDR_LEN) begin
//                     if(captured_eth_type == ETHERTYPE_IPV4) begin
//                         next_state = S_PARSE_IP_HEADER;
//                     end else next_state = S_DROP_PACKET;
//                 end
//             end
//             S_PARSE_IP_HEADER: begin
//                 if(byte_counter == IP_PROTOCOL_OFFSET) begin
//                     captured_ip_type = stream_in_if.data;//store this value
//                     next_state = S_PARSE_IP_HEADER;
//                 end else if( byte_counter == IP_HDR_LEN + ETHER_HDR_LEN) begin
//                     if(captured_ip_type == IP_PROTOCOL_UDP) begin
//                         next_state = S_PARSE_UDP_HEADER;
//                     end else next_state = S_DROP_PACKET;
//                 end

//             end
//             S_PARSE_UDP_HEADER: begin
//                 if(byte_counter == UDP_DEST_PORT_H_OFFSET) begin
//                     captured_dest_port[15:8] = stream_in_if.data;//store this value
//                 end else if (byte_counter ==  UDP_DEST_PORT_L_OFFSET) begin
//                     captured_dest_port[7:0] = stream_in_if.data;//store this value
//                 end else if (captured_dest_port == udp_port_to_match) begin
//                     next_state = S_STREAM_PAYLOAD;
//                 end else next_state = S_DROP_PACKET;

//             end
//             S_STREAM_PAYLOAD: begin
//                 valid_out_internal = stream_in_if.valid;//store this value
//                 data_out_internal = stream_in_if.data;//store this value
//                 if(!stream_in_if.valid) begin
//                     next_state = S_IDLE;
//                 end
//             end
//             S_DROP_PACKET: begin
//                 valid_out_internal = 1'b0;//store this value
//                 data_out_internal = 8'h00;//store this value
//                 if(!stream_in_if.valid) begin
//                     next_state = S_IDLE;
//                 end
//             end
//             default: next_state = S_IDLE;

//         endcase
//     end

// end

endmodule

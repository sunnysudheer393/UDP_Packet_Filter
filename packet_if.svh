interface packet_if(
    input logic clk, rst
);
logic [7:0] data;
logic valid, ready; //valid == data is present, ready == backpressure to avoid overflow or not to send more packets

modport DUT (
    input data,
    input valid,
    output ready, //DUT asserts this when it can accept data
    input clk,
    input rst
);

modport TB (
    output data,
    output valid,
    input ready, //TB observes ready from DUT
    input clk,
    input rst
);

//local constants for structre of ( ETH + IPv4 packets + UDP )
localparam ETHER_HDR_LEN = 14;
localparam IP_HDR_LEN = 20;
localparam UDP_HDR_LEN = 8;

localparam ETH_TYPE_OFFSET = 12;
localparam IP_PROTOCOL_OFFSET = ETHER_HDR_LEN + 9;
localparam UDP_DEST_PORT_OFFSET = ETHER_HDR_LEN + IP_HDR_LEN + 2;

localparam ETHERTYPE_IPV4 = 16'h0800;
localparam IP_PROTOCOL_UDP = 8'h11;


endinterface

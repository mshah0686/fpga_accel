module mult_datapath #(
    parameter D_WIDTH = 8,
    parameter ACC_WIDTH = 24
)(
    input clk,

    // Control signals
    input load_values,
    input select_k,
    input enable,
    input clear,
    input load_outputs,

    // Data inputs
    input  [D_WIDTH-1:0] a00, a01, a10, a11,
    input  [D_WIDTH-1:0] b00, b01, b10, b11,

    // Data outputs
    output reg [ACC_WIDTH-1:0] c00, c01, c10, c11
);

    reg [D_WIDTH-1:0] a00_l, a01_l, a10_l, a11_l;
    reg [D_WIDTH-1:0] b00_l, b01_l, b10_l, b11_l;


    // MAC CONTROL SIGNALS
    wire [3:0] mac_valid;
    wire [3:0] mac_load;
    wire [3:0] mac_clear;
    reg [3:0][D_WIDTH-1:0] mac_a;
    reg [3:0][D_WIDTH-1:0] mac_b;
    wire [ACC_WIDTH-1:0] mac_c00, mac_c01, mac_c10, mac_c11;


    always @(posedge clk) begin
        if(load_values) begin
            {a00_l, a01_l, a10_l, a11_l} <= {a00, a01, a10, a11};
            {b00_l, b01_l, b10_l, b11_l} <= {b00, b01, b10, b11};
        end else if (load_outputs) begin
            {c00, c01, c10, c11} <= {mac_c00, mac_c01, mac_c10, mac_c11};
        end
    end

    assign mac_valid = {4{enable}};
    assign mac_clear = {4{clear}};

    always @(*) begin
        if(enable & ~select_k) begin
            mac_a[0] = a00_l;
            mac_b[0] = b00_l;
            mac_a[1] = a00_l;
            mac_b[1] = b01_l;
            mac_a[2] = a10_l;
            mac_b[2] = b00_l;
            mac_a[3] = a10_l;
            mac_b[3] = b01_l;
        end else if(enable) begin
            mac_a[0] = a01_l;
            mac_b[0] = b10_l;
            mac_a[1] = a01_l;
            mac_b[1] = b11_l;
            mac_a[2] = a11_l;
            mac_b[2] = b10_l;
            mac_a[3] = a11_l;
            mac_b[3] = b11_l;
        end else begin
            mac_a = 'd0;
            mac_b = 'd0;
        end
    end

    mac #(
        .ACC_WIDTH(ACC_WIDTH),
        .D_WIDTH(D_WIDTH)
    ) mac_u_0 (
        .clk     (clk),
        .valid   (mac_valid[0]),
        .clear   (mac_clear[0]),
        .A       (mac_a[0]),
        .B       (mac_b[0]),
        .acc_out (mac_c00)
    );

    mac #(
        .ACC_WIDTH(ACC_WIDTH),
        .D_WIDTH(D_WIDTH)
    ) mac_u_1 (
        .clk     (clk),
        .valid   (mac_valid[1]),
        .clear   (mac_clear[1]),
        .A       (mac_a[1]),
        .B       (mac_b[1]),
        .acc_out (mac_c01)
    );

    mac #(
        .ACC_WIDTH(ACC_WIDTH),
        .D_WIDTH(D_WIDTH)
    ) mac_u_2 (
        .clk     (clk),
        .valid   (mac_valid[2]),
        .clear   (mac_clear[2]),
        .A       (mac_a[2]),
        .B       (mac_b[2]),
        .acc_out (mac_c10)
    );

    mac #(
        .ACC_WIDTH(ACC_WIDTH),
        .D_WIDTH(D_WIDTH)
    ) mac_u_3 (
        .clk     (clk),
        .valid   (mac_valid[3]),
        .clear   (mac_clear[3]),
        .A       (mac_a[3]),
        .B       (mac_b[3]),
        .acc_out (mac_c11)
    );



endmodule 
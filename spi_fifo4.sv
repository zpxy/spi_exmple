`define DATA_W 8

module spi_fifo4(
    input clk,
    input rst,
    input [`DATA_W-1:0] din,
    input wr_en,
    output [`DATA_W-1:0] dout,
    input rd_en,
    input clr,
    output full,
    output empty
);

logic [`DATA_W-1:0] mem[0:3];
logic [1:0] wp;
logic [1:0] rp;
logic [1:0] wp_p1; 
logic [1:0] wp_p2;
logic [1:0] rp_p1;

logic gb;
logic fifo_full;
logic fifo_empty;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        wp <= 2'b00;
    end
    else begin
        if (clr) begin
            wp <= 2'b00;
        end
        else begin
            wp <= wp_p1;
        end
    end
end

assign wp_p1 = wp + 2'h1;
assign wp_p2 = wp + 2'h2;  

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        rp <= 2'b00;
    end
    else begin
        if (clr) begin
            rp <= 2'b00;
        end
        else begin
            rp <= rp_p1;
        end
    end
end
assign rp_p1 = rp + 2'h1;
assign dout = mem[rp];

always @(posedge clk ) begin
    if(wr_en) begin
        mem[wp] <= din;
    end
end

assign fifo_empty = (wp == rp) & !gb;
assign fifo_full  = (wp == rp) & gb;
assign empty = fifo_empty;
assign full  = fifo_full;

always @(posedge clk or negedge rst) begin
    if(rst) begin 
        gb <= '0;
    end
    else begin
        if(clr) begin
            gb <= '0;
        end
        else begin
            if( (wp_p1 == rp) & wr_en) begin
                gb <= '1;
            end 
            else begin
                if(rd_en)
                    gb <= '0;
            end
        end
    end
end

endmodule



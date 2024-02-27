module spi_master(
    input logic clk,
    input logic rst_n,

    input       start_trig,
    input       wr,
    input [7:0] len,
    input [7:0] wdat,
    
    output              wdat_req;
    output logic [7:0]  rdat,
    output logic        rdat_vld,
    output logic        trans_over,

    output logic scsn,
    output logic sclk,
    output logic mosi,
    input  logic miso
)

localparam wr_op = 8'h3c;
localparam rd_op = 8'h5b;

logic [31:0]    cnt;
logic [31:0]    final_num;
logic           wdat_req_mask; 
logic           cnt_end;
logic [7:0]     sending_tmp; 
logic [7:0]     rdat_tmp; 
logic           rdat_last_vld;
logic           rdat_last_r;
logic           wdat_req_r;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 32'h0;
    end
    else if (start_trig) begin
        cnt <= 32'd1;
    end
    else if (cnt_end) begin
        cnt <= 32'h0;
    end
    else if (~scsn) begin
        cnt <= cnt + 32'd1;
    end
end

// len is the data lenth, but we also put op + addr + data in a spi frame.
assign final_num     = ((len+8'd2)<<4) - 32'd1;
assign wdat_req_mask = (cnt == final_num);
assign cnt_end       = (cnt == (final_num+32'd2))

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        trans_over <= 1'b0;
    end else begin
        trans_over <= cnt_end;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scsn <= 1'b1;
    end else if (start_trig) begin
        scsn <= '0;
    end else if (cnt_end) begin
        scsn <= '1;
    end
end

always @(*) begin
    if (cnt == 32'd0) begin
        sclk = 1'h1;
    end
    else if (cnt[0] == '1) begin
        sclk = '0;
    end else begin
        sclk = '1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sending_tmp <= 8'hff;
    end else  begin
       if( (cnt == 32'd0) & start_trig) begin
         if(wr) begin 
            sending_tmp <= wr_op;
         end else begin
            sending_tmp <= rd_op;
         end
       end
       else if (wdat_req_r) begin
            sending_tmp <= wdat;
       end
       else if (cnt[0] == 1'b1) begin
            sending_tmp <= sending_tmp<<1;
       end
    end 
end


assign wdat_req = ( (cnt[3:0] == 4'hf) & wr &(~wdat_req_mask) ) | (cnt == 4'hf);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wdat_req_r <= 1'b0;
    end else  begin
        wdat_req_r <= wdat_req;
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mosi <= 1'b0;
    end else  begin
         if (cnt == 32'd0 ) begin
            mosi <=- 1'b1;
         end else if(cnt[0] == 1'b1) begin
            mosi <= sending_tmp[7];
         end
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdat_tmp <= 8'd0;
    end else  begin
         if (cnt == 32'd0 ) begin
            rdat_tmp <= 8'd0;
         end else if ((cnt[0] == 1'b1) & (cnt > 32'd16)& ~wr )begin
            rdat_tmp <= {rdat_tmp[6:0],miso};
         end
    end 
end
assign rdat_last_vld = (cnt[3:0] == 4'd0) & (cnt > 32'd32) & ~wr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdat_last_r <= 1'b0;
        rdat_vld    <= 1'b0; 
    end else  begin
        rdat_last_r <= rdat_last_vld;
        rdat_vld    <= rdat_last_r; 
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdat <= 8'hff;
    end else if(rdat_last_r) begin
        rdat <= rdat_tmp;
    end 
end

endmodule
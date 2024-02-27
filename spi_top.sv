// 同步串行通信接口
// csn
// sclk
// mosi
// miso

// mater --- slave
// sclk -->  sclk
// mosi -->  simo
// miso <--  somi

// cpol : 时钟极性
// 0 ___|---|___
// 1 ---|___|---

// cpha ：数据极性
// 0 out: 下降沿变化
//   in ：上升沿采集
// 1 out: 上升沿变化
//   in : 下降沿采集

module  spi_top(
    input  clk,
    input  rst,

    //control intreface as tilelink-tl-ul  
    output a_ready,
    input  a_valid,
    input [2:0] a_opcode,
    input [2:0] a_addr,
    input [7:0] a_data,

    input  d_ready,
    output d_valid,
    output [2:0] d_addr,
    output [7:0] d_data,
    
    //spi master
    output spi_int,

    output spi_sclk,
    output spi_csn0,
    output spi_mosi,
    input  spi_miso
);

// spi register
logic [7:0] spi_cr;
logic [7:0] spi_dr; // read and  write
logic [7:0] spi_sr;
logic [7:0] spi_er;
logic [7:0] tx_reg, rx_reg;

//register decode 
logic spie = spi_cr[7];// interrupe en
logic spe  = spi_cr[6];// modue en
logic mstr = spi_cr[4];// master mode 
logic cpol = spi_cr[3];// cpol 
logic cpha = spi_cr[2];// cpha
logic spr  = spi_cr[1:0]; // div rate of clock

// logic spif = spi_sr[7];
// logic wcol = spi_sr[6];
// logic wffull  = spi_cr[3];
// logic wfempty = spi_cr[2];
// logic rffull  = spi_cr[1];
// logic rfempty = spi_cr[0];

logic spif   ;
logic wcol   ;
logic wffull ;
logic wfempty;
logic rffull ;
logic rfempty;

assign spi_sr[7]= spif   ;
assign spi_sr[6]= wcol   ;
assign spi_cr[3]= wffull ;
assign spi_cr[2]= wfempty;
assign spi_cr[1]= rffull ;
assign spi_cr[0]= rfempty;

logic [1:0] icnt = spi_er[7:6];
logic [1:0] espr = spi_er[1:0];

//titelink state
logic wr_en;
logic rd_en;
logic [1:0] tilelink_state;
logic [1:0] tilelink_state_next;

assign a_ready = '1;
assign wr_en = (a_valid) & (a_opcode == 3'd0);
assign rd_en = (a_valid) & (a_opcode == 4'd4);

//fifo signal
logic fifo_clr;

logic [7:0] wf_in;
logic [7:0] wf_out;
logic wf_wr_en;
logic wf_rd_en;

logic [7:0] rf_in;
logic [7:0] rf_out; 
logic rf_wr_en;
logic rf_rd_en;


always @(posedge clk or negedge rst) begin
    if(rst) begin
        spi_cr <= 8'h0;
    end
    else if(wr_en) begin
        if( a_addr == 3'd0) begin
            spi_cr <= a_data | 8'h10;
        end
    end
end

always @(posedge clk or negedge rst) begin
    if(rst) begin
        spi_er <= 8'h0;
    end
    else if(wr_en) begin
        if( a_addr == 3'd1) begin
            spi_er <= a_data;
        end
    end
end
 
always @(posedge clk or negedge rst) begin
    if(rst) begin
        wf_in <= 8'h0;
        spi_dr <= 8'h0;
    end
    else if(wr_en) begin
        if( a_addr == 3'd3) begin
            wf_wr_en <= 1 ;
            wf_in <= a_data;
        end 
        else begin 
            wf_wr_en <= 0;
        end
    end
    else if (rd_en) begin
         if( a_addr == 3'd3) begin
            rf_rd_en <= 1;
            d_valid  <= 1;
            d_data   <= rf_out
        end
    end
end

//assign d_data = (rd_en) ? spi_dr

spi_fifo4 write_buffer(
    .clk  (clk),
    .rst  (rst),
    .din  (wf_in),
    .wr_en(wf_wr_en),
    .rd_en(wf_rd_en),
    .dout (wf_out),
    .clr  (fifo_clr),
    .full (wffull),
    .empty(wfempty)
);

spi_fifo4 read_buffer(
    .clk  (clk),
    .rst  (rst),
    .din  (rf_in),
    .wr_en(rf_wr_en),
    .rd_en(rf_rd_en),
    .dout (rf_out),
    .clr  (fifo_clr),
    .full (rffull),
    .empty(rfempty)
);

//SCLK  GEN 

logic sclk_en;

   

// spi tx 




// spi rx





    
endmodule
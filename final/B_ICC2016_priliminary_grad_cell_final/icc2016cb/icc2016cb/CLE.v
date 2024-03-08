`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset;
input  [7:0]  rom_q;
output [6:0]  rom_a;
input  [7:0]  sram_q;
output [9:0]  sram_a;
output [7:0]  sram_d;
output        sram_wen;
output        finish;

parameter WAIT = 3'b001;
parameter GETDATA = 3'b010;
parameter JUDGE = 3'b011;
parameter RESTORE = 3'b100;
parameter FINISH = 3'b101;
parameter ITERATION = 3'b110;

reg finishGetData, finishJudge, finish_all, writeTrigger, finishIteration;
reg [2:0] state, nextState;

reg [6:0] symbol;

reg [9:0] sram_addr;
reg [7:0] sram_data;
reg map [0:1023];
reg data [0:1023];
reg [4:0] stack_x [0:100];
reg [4:0] stack_y [0:100];
reg [6:0] stack_count;
reg [4:0] x,y,now_x, now_y;
wire [9:0] u, ru, r, rd, d, ld, l, lu;
reg [6:0] rom_position;
wire u_available, ru_available, r_available, rd_available, d_available, ld_available, l_available, lu_available;
//assign y = rom_position[2:0] * 4; 
assign finish = (state == FINISH);
assign rom_a = rom_position;
assign sram_wen = !writeTrigger;//!(state == JUDGE);
assign sram_a = sram_addr;
assign sram_d = sram_data;

assign available = map[x * 32 + y];

assign u = (now_x - 1) * 32 + now_y;
assign ru = (now_x - 1) * 32 + now_y + 1;
assign r = now_x * 32 + now_y + 1;
assign rd = (now_x + 1) * 32 + now_y + 1;
assign d = (now_x + 1) * 32 + now_y;
assign ld = (now_x + 1) * 32 + now_y - 1;
assign l = now_x * 32 + now_y - 1;
assign lu = (now_x - 1) * 32 + now_y - 1;

assign u_available = data[u] && map[u] && (x >= 1);
assign ru_available = data[ru] && map[ru] && (x >= 1) && (y <= 30);
assign r_available = data[r] && map[r] && (y <= 30);
assign rd_available = data[rd] && map[rd] && (y <= 30) && (x <= 30);
assign d_available = data[d] && map[d] && (x <= 30);
assign ld_available = data[ld] && map[ld] && (x <= 30) && (y >= 1);
assign l_available = data[l] && map[l] && (y >= 1);
assign lu_available = data[lu] && map[lu] && (y >= 1) && (x >= 1);
integer i;

always@(state, finishGetData, finishJudge, finish_all, finishIteration)begin
	case(state)
		WAIT:
			nextState <= GETDATA;
		GETDATA:
			if(finishGetData == 1)
				nextState <= JUDGE;
			else
				nextState <= GETDATA;
		JUDGE:begin
			if(finish_all == 1)
				nextState <= FINISH;
			else if(finishJudge == 1)
				nextState <= ITERATION;
			else
				nextState <= JUDGE;
		end
		ITERATION:begin
			if(finishIteration)
				nextState <= JUDGE;
			else
				nextState <= ITERATION;
		end
		default:
			nextState <= 0;
	endcase
end


always@(posedge clk)begin
	if(reset)
		state = 1;
	else	
		state = nextState;
end

always@(negedge clk)begin
	finish_all <= 1'b0;
	writeTrigger <= 1'b0;
	finishGetData <= 1'b0;
	finishJudge <= 1'b0;
	finishIteration <= 1'b0;
	
	if(reset)begin
		rom_position <= 7'b000_0000;
		x <= 0;
		y <= 0;
		symbol <= 7'b0000000;
		stack_count <= 0;
		for(i = 0;i < 1024 ; i=i+1)begin
			map[i] <= 1;
		end
		for(i = 0;i< 100;i=i+1)begin
			stack_x[i] <= 0;
			stack_y[i] <= 0;
		end
	end
	else
		case(state)
			GETDATA:begin
				//x in here means rom address
				data[rom_position * 8] <= rom_q[7];
				data[rom_position * 8 + 1] <= rom_q[6];
				data[rom_position * 8 + 2] <= rom_q[5];
				data[rom_position * 8 + 3] <= rom_q[4];
				data[rom_position * 8 + 4] <= rom_q[3];
				data[rom_position * 8 + 5] <= rom_q[2];
				data[rom_position * 8 + 6] <= rom_q[1];
				data[rom_position * 8 + 7] <= rom_q[0];
				if(rom_position == 127)
					finishGetData <= 1;
				else
					rom_position <= rom_position + 1;
				
			end
			JUDGE:begin
				map[x * 32 + y] <= 0;
				if((data[x * 32 + y] == 1) && available == 1)begin
					finishJudge <= 1;
					now_x <= x;
					now_y <= y;
					symbol <= symbol + 1;
				end
				else begin
					sram_addr <= x * 32 + y;
					sram_data <= 0;
					symbol <= symbol;
					if(data[x * 32 + y] == 0)
						writeTrigger <= 1;
					else
						writeTrigger <= 0;
	
				end
				if(y == 31)begin	
					y <= 0;
					if(x == 31)
						finish_all <= 1;
					else
						x <= x + 1;
				end
				else
					y <= y + 1;
			end
			
			ITERATION:begin
				if(u_available)begin
					now_x <= now_x - 1;
					now_y <= now_y;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(ru_available)begin
					now_x <= now_x - 1;
					now_y <= now_y + 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(r_available)begin
					now_x <= now_x;
					now_y <= now_y + 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(rd_available)begin
					now_x <= now_x + 1;
					now_y <= now_y + 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(d_available)begin
					now_x <= now_x + 1;
					now_y <= now_y;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(ld_available)begin
					now_x <= now_x + 1;
					now_y <= now_y - 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(l_available)begin
					now_x <= now_x;
					now_y <= now_y - 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else if(lu_available)begin
					now_x <= now_x - 1;
					now_y <= now_y - 1;
					stack_x[stack_count] <= now_x;
					stack_y[stack_count] <= now_y;
					stack_count <= stack_count + 1;
				end
				else begin
					if(stack_count == 0)
						finishIteration <= 1;
					else begin
						now_x <= stack_x[stack_count - 1];
						now_y <= stack_y[stack_count - 1];
						stack_count <= stack_count - 1;
					end
					
					sram_addr <= now_x * 32 + now_y;
					sram_data <= symbol;
					writeTrigger <= 1;
				end
				map[now_x * 32 + now_y] <= 0;
				
				
			end
			default:begin
				finish_all <= 0;
				writeTrigger <= 0;
				finishGetData <= 0;
				finishJudge <= 0;
				finishIteration <= 0;
			end
		endcase
end

endmodule
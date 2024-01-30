`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg [5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg [23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output reg mirror_done,		// semnaleaza terminarea actiuni de oglindire (activ pe 1)
	output reg gray_done,		// semnaleaza terminarea actiuni de transformare in grayscale (activ pe 1)
	output reg filter_done);	// semnaleaza terminarea actiuni de aplicare a filtrului de sharpness (activ pe 1)

// TODO add your finite state machines here
reg [8:0] current_state, next_state;
reg [6:0] i = 0, j = 0;
reg init=0;
reg [1:0] initial_cont;
reg [23:0] stoc_temp_1, stoc_temp_2, grayscale_minmax;
reg [7:0] a, b, c;
reg [23:0] cached [2:0][63:0];

//Mentiuni

//Este foarte posibil sa fi atribuit contorilor valori identice cu cele precedente pentru a ma asigura ca nu sunt probleme.

//Am incercat sa folosesc cat mai putine stari. Stiu ca tot sunt destul de multe, dar consider ca in cazul de fata ajuta sa putem observa fiecare operatie
//separat, mai ales la debugging pentru a vedea in ce loc am gresit ( m - a ajutat extrem de mult la sharpening acest lucru ).
//PS: de asemenea nu m-am descurcat cu minimizarile la SDED

always @(posedge clk) begin
	if (init == 0) begin
		init <= 1;
		current_state <= 0;
		mirror_done <= 0;
		gray_done <= 0;
		filter_done <= 0;
		out_we <= 0;
	end else begin 
		if(next_state == 8) begin
			current_state <= next_state;
			mirror_done <= 1;
		end
		else if(next_state == 16) begin
			current_state <= next_state;
			gray_done <= 1;
			mirror_done <= 0;
		end
		else if(next_state == 33) begin
			filter_done <= 1;
			gray_done <= 0;
			current_state <= next_state;
		end
		else begin
			current_state <= next_state;
		end
	end
end

always @(current_state) begin
	case (current_state)
		//case-urile 0->8 vor trata mirror-ul imaginii
		
		//verific daca am ajuns la jumatatea imaginii pe orizontala ( am pierdut aproape 2 ore incercand sa fac 
		//mirror-ul pe verticala, doar ca sa inteleg ca verticala liniilor se refera de fapt la orizontala). Daca
		//am ajuns atunci trec la urmatoarea coloana si verific din nou la cazul 0 daca am ajuns la ultima, daca nu
		//voi trece la pasul urmator
		0: begin
			if (i == 32) begin
				i = 0;
				j = j + 1;
				next_state = 1;
			end else begin
				next_state = 2;
			end
		end
		
		//parcurg matricea pe linie, apoi pe coloana, deci cand voi ajunge la coloana 64(care este 'dupa' ultima)
		//algoritmul se va opri, daca nu s-a ajuns la col=64 atunci pot sa continui parcurgerea pe linii
		1: begin	
			if (j == 64) begin
				next_state = 8;
			end else begin
			next_state = 0;
			end
		end
		
		//selectez rand si coloana pentru pasul urmator
		2: begin
			row = i;
			col = j;
			next_state = 3;
		end
		
		//citesc pixelul si pregatesc randul complementar pentru a citi celalalt pixel
		3: begin
			stoc_temp_1 = in_pix;
			row = 63 - i;
			next_state = 4;
		end
		
		//citesc pixelul complementar
		4: begin
			stoc_temp_2 = in_pix;
			next_state = 5;
		end
		
		//interschimb cei doi pixeli( realizarea mirror-ului )
		5: begin
			out_we = 1;
			row = i;
			col = j;
			out_pix = stoc_temp_2;
			next_state = 6;
		end
		
		6: begin
			out_we = 1;
			row = 63 - i;
			col = j;
			out_pix = stoc_temp_1;
			next_state = 7;
		end
		
		// trec la randul urmator si ma intorc la pasul 0 pentru a relua procedeul
		// pana cand ajung la ultima coloana
		7: begin
			out_we = 0;
			i = i + 1;
			next_state = 0;
		end
		
		//sfarsitul mirror-ului si trecerea la grayscale
		8: begin
			i = 0;
			j = 0;
			next_state = 9;
		end
		
		//selectez rand si coloana pentru grayscale si citesc pixelul ( starile 9->16 )
		9: begin
			row = i;
			col = j;
			next_state = 10;
		end
		
		10: begin
			stoc_temp_1 = in_pix;
			next_state = 11;
		end
		
		//impart pixelul citit in R G B si le stochez in variabilele a, b, c
		//pe care urmeaza sa le verific si sa adaug in grayscale_minmax suma dintre
		//minim si maxim, avand apoi sa fac media, sa concatenez la grayscale_minmax
		//2 valori de 8'b0 pentru a obtine un pixel doar cu valoare in G
		11: begin
			a = stoc_temp_1[23:16];
			b = stoc_temp_1[15:8];
			c = stoc_temp_1[7:0];
			if (a >= b && a >= c) begin
				grayscale_minmax = a;
			end else begin
				if (b >= a && b >= c) begin
				grayscale_minmax = b;
				end else begin
				grayscale_minmax = c;
				end
			end
			if (a <= b && a <= c) begin
				grayscale_minmax = grayscale_minmax + a;
			end	else begin
				if (b <= a && b <= c) begin
				grayscale_minmax = grayscale_minmax + b;
				end else begin
				grayscale_minmax = grayscale_minmax + c;
				end
			end
			grayscale_minmax = grayscale_minmax / 2;
			stoc_temp_2 = {grayscale_minmax, 8'b0 };
			next_state = 12;
		end
		
		//scriu pixel-ul si trec la pixelul de pe coloana urmatoare
		12: begin
			out_we = 1;
			out_pix = stoc_temp_2;
			next_state = 13;
		end
		
		13: begin
			out_we = 0;
			j = j + 1;
			next_state = 14;
		end
		
		//verific sa nu fi ajuns la final de rand, iar daca ajung voi verifica sa
		//nu fi terminat tot algoritmul ( ajungerea la randul '64' )
		14: begin
			if (j == 64) begin
				i = i + 1;
				j = 0;
				next_state = 15;
			end else begin
				next_state = 9;
			end
		end
		
		15: begin
			if (i == 64) begin
				next_state = 16;
			end else begin
				next_state = 9;
			end
		end
		
		//sfarsitul grayscale-ului si trecerea la sharpness ( starile 18->35 )
		16: begin
			next_state = 17;
		end
		
		//initializez indicii si pastrez un contor initial pentru a imi putea citi 3 randuri
		//pe post de cache ca sa pot aplica matricea de convolutie pe pixelii nemodificati
		//(cei de la pasul anterior).
		17: begin
			i = 0;
			j = 0;
			initial_cont = 0;
			next_state = 18;
		end
		
		//selectez pixelul care urmeaza sa fie salvat pe cele 3 linii initiale
		18: begin
			row=i;
			col=j;
			next_state=19;
		end
		
		19: begin
			cached[i][j]=in_pix[15:8];
			j=j+1;
			next_state = 20;
		end
		
		//ma asigur sa nu depasesc 3 linii citite initial si verific de fiecare data cand termin
		//linia pentru a putea trece la urmatoarea
		20: begin
			if(j == 64) begin
				j = 0;
				i = i + 1;
				initial_cont = initial_cont + 1;
				next_state = 21;
			end else begin
				next_state = 18;
			end
		end
		
		21: begin
			if(initial_cont == 3) begin
				initial_cont = 0;
				i=0;
				j=0;
				row=0;
				col=0;
				next_state = 22;
			end else begin
				next_state = 18;
			end
		end
		
		//in acest pas tratez separat prima linie pentru ca are elemente ce nu pot fi generalizate
		//(cele doua colturi si elementele dintre ele) si stochez pixelul generat de convolutia cu kernelul
		// -1 -1 -1 -1 9 -1 -1 -1 -1.
		
		//(stoc_temp_1 > 255 && stoc_temp_1[23] != 1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
		// aceasta instructiune verifica daca pixelul are G-ul mai mare de 255, caz in care il lasa la valoarea
		// 255 (mi-am dat seama din vmchecker ca asta este functionalitatea) si 0 in caz ca rezultatul este
		// o valoare negativa ( cand devine valoare negativa stiu sigur ca va avea primul bit = 1, deci verificand
		// asta pot decide daca trebuie sa o las 0 sau nu.
		22: begin 
			out_we = 1;
			if(i == 0 && j == 0) begin
				stoc_temp_1 = 9 * cached[0][0] - cached[0][1] - cached[1][0] - cached[1][1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23] != 1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 23;
			end else if (j < 63 ) begin
				stoc_temp_1= 9 * cached[0][j] - cached[0][j-1] - cached[0][j+1] - cached[1][j-1] - cached[1][j] - cached[1][j+1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 23;
			end else begin 
				stoc_temp_1 = 9*cached[0][63] - cached[0][62] - cached[1][63] - cached[1][62];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state=24;
			end
		end
		
		//trecerea la urmatoarea linie de unde voi putea generaliza (oarecum) pana cand se ajunge la
		//ultima linie
		24: begin
			j = 0;
			i = 1;
			row = i;
			col = j;
			next_state = 25;
		end	
		
		23: begin
			out_we = 0;
			j = j + 1;
			col = j;
			next_state = 22;
		end
		
		//aici tratez separat marginile (stanga/dreapta) si centrul, datorita lipsei elementelor 
		//de pe margini
		25: begin
			out_we = 1;
			if(j == 0) begin
				stoc_temp_1 = 9 * cached[1][j] - cached[1][j+1] - cached[0][j] - cached[0][j+1] - cached[2][j] - cached[2][j+1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 26;
			end else if( j == 63 ) begin
				stoc_temp_1 = 9 * cached[1][j] - cached[1][j-1] - cached[0][j] - cached[0][j-1] - cached[2][j] - cached[2][j-1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1)? 255:((stoc_temp_1[23] == 1)?0:stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				j = 0;
				i = i + 1;
				next_state = 27;
			end else begin
				stoc_temp_1 = 9 * cached[1][j] - cached[1][j+1] - cached[0][j] - cached[0][j+1] - cached[2][j] - cached[2][j+1] - cached[1][j-1] - cached[0][j-1] - cached[2][j-1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 26;
			end
		end
		
		//trec la urmatorul element de pe linie, il selectez si apelez din nou pasul anterior
		26: begin
			out_we = 0;
			j = j + 1;
			col = j;
			next_state = 25;
		end
		
		//in acest caz se trece la o linie noua, deci verificam daca este ultima linie. In caz ca da
		//atunci updatez cele 3 linii ce imi stocheaza pixelii prin shiftarea acestora cu o linie in sus
		//si adaugarea unei noi linii in locul ultimei. Dupa ce se updateaza liniile cache-uite se revine
		//la pasul 25 pentru a prelucra o linie noua
		27: begin
			out_we = 0;
			if(i != 63) begin 
				next_state = 28;
			end else begin
				j = 0;
				col = j;
				row = i;
				next_state = 31;
			end
		end
		
		28: begin
			row = i + 1;
			col = j;
			next_state = 29;
		end
		
		29: begin
			cached[0][j] = cached[1][j];
			cached[1][j] = cached[2][j];
			cached[2][j] = in_pix[15:8];
			j = j + 1;
			next_state = 30;
		end
		
		30: begin
			if(j == 64) begin
				j = 0;
				col = j;
				row = i;
				next_state = 25;
			end else begin
				col = j;
				next_state = 29;
			end
		end
		
		//ultima linie se trateaza la fel ca prima linie, doar ca in oglinda
		31: begin
			out_we = 1;
			if(j == 0) begin
				stoc_temp_1 = 9 * cached[2][j] - cached[1][j] - cached[1][j+1] - cached[2][j+1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 32;
			end else if (j == 63 ) begin
				stoc_temp_1 = 9 * cached[2][j] - cached[1][j] - cached[1][j-1] - cached[2][j-1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 33;
			end else begin
				stoc_temp_1 = 9 * cached[2][j] - cached[2][j-1] - cached[2][j+1] - cached[1][j-1] - cached[1][j] - cached[1][j+1];
				stoc_temp_1 = (stoc_temp_1 > 255 && stoc_temp_1[23]!=1) ? 255 : ((stoc_temp_1[23] == 1) ? 0 : stoc_temp_1);
				out_pix = {8'b0, stoc_temp_1[7:0], 8'b0};
				next_state = 32;
			end
		end
		
		32: begin
			j = j + 1;
			col = j;
			next_state = 31;
		end
		
		//sfarsitul temei
		33: begin
			next_state = 33;
		end

	endcase
end

endmodule
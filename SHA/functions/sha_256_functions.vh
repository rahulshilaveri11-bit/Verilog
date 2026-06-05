

// 1 ROTATE RIGHT FUNCTIION
function [31:0] ROTR;
input [31:0] x;
input [4:0] n;
begin
ROTR = (x>>n)|(x<<(32-n));
end
endfunction

//2 SHIFT RIGHT FUNCTION
function [31:0] SHR;
input [31:0] s;
input [4:0] n;
begin
SHR = s>>n ;
end
endfunction

//3 CHOOSE FUNCTION
function [31:0] choose;
input [31:0] e,f,g;
begin
choose = (e & f)^(~e & g) ;
end
endfunction

//4 MAJORITY FUNCTION
function [31:0] majority;
input [31:0] a,b,c;
begin
majority = (a&b)^(a&c)^(b&c);
end
endfunction

//5 SIGMA0 FUNCTION [ROTATING THE a VALUES]
function [31:0] SIG0;
input [31:0] a;
begin
SIG0 = ROTR(a,2)^ROTR(a,13)^ROTR(a,22);
end
endfunction

//6 SIGMA1 FUNCTION [ROTATING e VALUES]
function [31:0] SIG1;
input [31:0] e;
begin
SIG1 = ROTR(e,6)^ROTR(e,11)^ROTR(e,25);
end
endfunction

//9 sigma0 function [rotating the w values]
function [31:0] sig0;
input [31:0] w;
begin
sig0 = ROTR(w,7)^ROTR(w,18)^SHR(w,3);
end
endfunction

//10 sigma1 function rotating w values
function [31:0] sig1;
input [31:0] w;
begin
sig1 = ROTR(w,17)^ROTR(w,19)^SHR(w,10);
end
endfunction



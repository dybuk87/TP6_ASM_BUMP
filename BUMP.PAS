{$G+,N+}
program as;
 uses crt;


type
 TMEM = array[0..0] of byte;
 THandleBMP = RECORD { BMP structure }
   bfType          :Word;    {BMP file signature 4D42h ("BM")}
   bfSize          :LongInt; {file length}
   bfRes1          :Word;    { reserved => 0}
   bfRes2          :Word;    { reserved => 0}
   bfOffBits       :LongInt; { Image position in file (= header length + palette length )}
   biSize          :LongInt; { distance from this position to end of header usually 40, sometime less}
   biWidth         :LongInt; { Image width }
   biHeight        :LongInt; { image height }
   biPlanes        :Word;    { No of planes, must be 1}
   biBitCount      :Word;    { bit per pixel (1, 4, 8, 24)}
   biCompression   :LongInt; { Compression method : 0 = none, 1,2 = RLE}
   biSizeImage     :LongInt; { Size of image }
   biXPelsPerMeter :LongInt; { dpi X}
   biYPelsPerMeter :LongInt; { dpi Y}
   biClrUsed       :LongInt; { Colour count in palette }
   biClrImportant  :LongInt; { just set to 0 }
 END;

var
 BITMAP:^tmem;
 BUFOR :^tmem;
 segm :word;
 segmb:word;
 i,j:integer;
 light:^tmem;
 lightSeg:word;
 PozX,PozY:integer;
 arg1,arg2:real;

PROCEDURE SetCol(c,r,g,b:byte);
BEGIN
 port[$3c8]:=c; { color no i palette }
 port[$3c9]:=r; { RED}
 port[$3c9]:=g; { GREEN}
 port[$3c9]:=b; { BLUE}
END;

procedure LoadBmp; { this method load only 320x200 bitmap with 256 colours palette }
VAR
 PlikBmp   :FILE;       { File handler }
 Pal       :ARRAY[0..4*256-1] OF Byte; { tab contains palette definition, contains
                                          256 colours(for bytes for each colour ARGB ) }
 b         :Integer;    
 p         :Pointer;    
 HandleBmp :THandleBMP; { File header }
BEGIN
Assign(PlikBmp,'hmap.bmp');  
 Reset(PlikBmp,1);
  BlockRead(PlikBmp,HandleBMP,SizeOf(HandleBMP));  { load header }
   getMem(BITMAP,64000); 	            { alloc memory 320x200 => 64000 }
   BlockRead(PlikBmp,Pal,SizeOf(Pal));  { load full palette }
 FOR b:=0 TO 255 DO
   setCol(b,Pal[b*4+2] DIV 4,Pal[b*4+1] DIV 4,Pal[b*4+0] DIV 4);  { set palette }

   GetMem(p,320);   { alloc scanline  }
 FOR b:=199 DOWNTO 0 DO BEGIN   { image in bmp is stored upside down so position counter from up value to down }
  BlockRead(PlikBmp,p^,320);
  Move(p^, BITMAP^[b*320], 320);
 END;
FreeMem(p,320);
Close(PlikBmp);
END;

procedure GetLight;
var
   dist:word;
 begin
  for i:=0 to 127 do
  for j:=0 to 127 do
   begin
    dist:= round(4*sqrt(sqr(i-64)+sqr(j-64)));
    if dist>255 then dist:=255;
    dist:=255-dist;
    light^[j*128+i]:=byte(dist);
   end;
 end;

procedure plot(x,y:word; c:byte);
 begin
  asm
   mov ax,segmb
   mov es,ax
   mov di,x
   mov ax,y
   shl ax,6
   add di,ax
   shl ax,2
   add di,ax
   mov al,c
   stosb
  end;
 end;

procedure ClrScrVB;
 begin
  asm
   mov ax,segmb
   mov es,ax
   xor di,di
   mov cx,32000d
   xor ax,ax
   rep stosw
  end;
 end;

procedure BUMP;
var tx1,ty1:integer;
 adres:word;
 kolor:byte;
 begin
  adres:=321;
  for j:=1 to 198 do
  begin
   for i:=1 to 318 do
    begin
     tx1 := i+pozX-160;
     ty1 := j+pozY-100;
     asm
      mov di,adres
      mov ax,Segm
      mov es,ax
      xor ax,ax
      mov al,es:[di-1]
      xor bx,bx
      mov bl,es:[di+1]
      sub ax,bx
      mov bx,tx1
      add bx,ax
      mov tx1,bx

      xor ax,ax
      mov al,es:[di-320]
      xor bx,bx
      mov bl,es:[di+320]
      sub ax,bx
      mov bx,ty1
      add bx,ax
      mov ty1,bx
      inc adres

      mov ax,tx1
      cmp ax,64
      jg @nie_rys
      cmp ax,-64
      jl @nie_rys

      mov ax,ty1
      cmp ax,64
      jg @nie_rys
      cmp ax,-64
      jl @nie_rys

        mov ax,segmb
        mov es,ax
        mov di,adres
        mov ax,ty1
        add ax,64
        shl ax,7
        mov si,tx1
        add si,64
        add si,ax
        mov ax, lightSeg
        push ds
         mov ds,ax
         movsb
        pop ds
        @nie_rys:
       end;
    end;
    inc(adres,2);
   end;
 end;

procedure wait_f; assembler;
asm
	mov dx,03dah
@c1:
	in al,dx
	test al,8
	jz @c1
@c2:
	in al,dx
	test al,8
	jnz @c2
end;


begin
 asm
  mov ax,0013h
  int 10h
 end;
 GetMem(light, 128*128);
 GetMem(BUFOR,   64000);
 LoadBmp;
 Segm :=seg(BITMAP^[0]);
 Segmb:=seg(BUFOR ^[0]);
 lightSeg:=seg(light ^[0]);
 GetLight;
 arg2:=0;
 arg1:=0;
 repeat
  pozx:=round(159*sin(arg1));
  pozy:=round( 99*cos(arg2));    
  arg1:=arg1+0.014;
  arg2:=arg2+0.023;
    ClrScrVB;
    Bump;
   asm
    mov ax,0a000h
    mov es,ax
    mov ax,segmb
    xor si,si
    xor di,di
    push ds
     mov ds,ax
     mov cx,32000d
     rep movsw
    pop ds
   end;
 until keypressed;
 readln;
 asm
  mov ax,0003h
  int 10h
 end;
 FreeMem(BITMAP,64000);
 FreeMem(BUFOR ,64000);
 FreeMem(light,128*128);
end.
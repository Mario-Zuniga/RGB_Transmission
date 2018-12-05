%% Obtencion de imágenes

% Obtenemos la imagen JPG
imdata = imread('red.jpg');

% Cambiamos el tipo de valores a double
im = double(imdata);

% Guardaremos las secciones RGB en diferentes vectores
imagen_R = im(:,:,1);
imagen_G = im(:,:,2);
imagen_B = im(:,:,3);



%% Convertimos en bits la imagen R

% Transformamos la imagen R a bits
b_R = de2bi(imagen_R, 8, 'left-msb');

% Creamos el header
header = [de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb')]; 

% Concatenación de bits
b_R = [header;b_R]; 

% Header AAh
header_2 = [de2bi(170,8,'left-msb')]; 

%Concatenación de header
b_R = [header_2;b_R];   

% Matriz traspuesta
b_R = b_R'; 

% Concatena los bits para tenerlos en una sola trama para poder ser transmitido uno por uno
bits_R = b_R(:); 



%% Convertimos en bits la imagen G

% Transformamos la imagen G a bits
b_G = de2bi(imagen_G, 8, 'left-msb');

% Creamos el header
header = [de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb')]; 

% Concatenación de bits
b_G = [header;b_G]; 

% Header AAh
header_2 = [de2bi(170,8,'left-msb')];   

% Concatenación de header
b_G = [header_2;b_G];   

% Matriz traspuesta
b_G = b_G'; 

% Concatena los bits para tenerlos en una sola trama para poder ser transmitido uno por uno
bits_G = b_G(:); 



%% Convertimos en bits la imagen B

% Transformamos la imagen B a bits
b_B = de2bi(imagen_B, 8, 'left-msb');

% Creamos el header
header = [de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb');de2bi(129,8,'left-msb')]; 

% Concatenación de bits
b_B = [header;b_B]; 

% Header AAh
header_2 = [de2bi(170,8,'left-msb')];   

% Concatenación de header
b_B = [header_2;b_B];   

% Matriz traspuesta
b_B = b_B'; 

% Concatena los bits para tenerlos en una sola trama para poder ser transmitido uno por uno
bits_B = b_B(:); 



%% Generacion de pulso 

Fs = 48000;
r = 0.5;

Rb = 4000;
B = (Rb*(1+r))/2;

Tp = 1 / Rb;
Ts = 1 / Fs;
mp = Fs / Rb;
D = 6;

type = 'srrc';
e = Tp;
p = rcpulse(r, D, Tp, Ts, type, e);




%% Creacion de trama de bits R

% Cambiamos los bits 0 a 1 y los convertimos a vector
bits_R(bits_R == 0) = -1;
s_R = zeros(1, (numel(bits_R) - 1) * mp + 1); %Generar el vector
s_R(1:mp:end) = bits_R;


%% Creacion de trama de bits G

% Cambiamos los bits 0 a 1 y los convertimos a vector
bits_G(bits_G == 0) = -1;
s_G = zeros(1, (numel(bits_G) - 1) * mp + 1); %Generar el vector
s_G(1:mp:end) = bits_G;


%% Creacion de trama de bits B

% Cambiamos los bits 0 a 1 y los convertimos a vector
bits_B(bits_B == 0) = -1;
s_B = zeros(1, (numel(bits_B) - 1) * mp + 1); %Generar el vector
s_B(1:mp:end) = bits_B;


%% Hacemos la convolución

% Pasamos las tramas de bits con el coseno alzado
conv_srrc_R = conv(s_R, p);
conv_srrc_G = conv(s_G, p);
conv_srrc_B = conv(s_B, p);



%% Modulacion

% Frequency Carrier de las señales
F_carrier_R = 3800;
F_carrier_G = 11200;
F_carrier_B = 18100;

% Modulacion R
% Carrier Amplitude
carr_amp_R = max(abs(conv_srrc_R));

%Modulacion LC
signal_mod_LC_R = ammod(conv_srrc_R, F_carrier_R, Fs, 0, carr_amp_R);

m_R = (max(abs(signal_mod_LC_R)) - carr_amp_R) / carr_amp_R;


% Modulacion G
% Carrier Amplitude
carr_amp_G = max(abs(conv_srrc_G));

%Modulacion LC
signal_mod_LC_G = ammod(conv_srrc_G, F_carrier_G, Fs, 0, carr_amp_G);

m_G = (max(abs(signal_mod_LC_G)) - carr_amp_G) / carr_amp_G;


% Modulacion B
% Carrier Amplitude
carr_amp_B = max(abs(conv_srrc_B));

%Modulacion LC
signal_mod_LC_B = ammod(conv_srrc_B, F_carrier_B, Fs, 0, carr_amp_B);

m_B = (max(abs(signal_mod_LC_B)) - carr_amp_B) / carr_amp_B;

% Sumamos las 3 señales para poder ser enviadas
signal_send = signal_mod_LC_R + signal_mod_LC_G + signal_mod_LC_B;


%% Transmisión de Señal

% Mandamos la señal
soundsc([zeros(1, Fs) signal_send], Fs);


clear all
close all

bits = 16;
Fs = 48000;
duracion = 30;
audio = audiorecorder(Fs,bits,1);
recordblocking(audio,duracion);
signal_recording=getaudiodata(audio,'single');


% Durante las pruebas de la práctica, el grabar y leer un archivo se 
% hacían en códigos separados, fueron unidas en caso de requerir el archivo
% para pruebas posteriores
audiowrite('image_100_100_2.wav', signal_recording, Fs);

% Leemos la imagen guardada previamente
[signal_rec, fs] = audioread('image_100_100_2.wav');

% Encontrar los puntos donde comienza y termina la señal
first=find(abs(signal_rec)>0.2,1,'first');
last=find(abs(signal_rec)>0.2,1,'last');

% Recorte de tiempo de la señal
signal_rec_cut=signal_rec(first:last); 


%% Generacion de pulso 

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



%% Filtro Pasa Bajas para R

% Todos los filtros tendrán el mismo orden, la misma variable se usa en las
% siguientes 2 secciones
orden = 100;

% Variables para filtro pasa bajas
vc1 = [0 7200/(Fs/2) 7200/(Fs/2) 1];
m = [1 1 0 0];

% Creamos el filtro
f1 = fir2(orden, vc1, m);

% Pasamos la señal por el filtro
low_filter = conv(signal_rec_cut, f1);

% Calculamos el carrier del filtro
carrier_filter = (orden / 2) + (mp / 2) + 1;

% Eliminamos el carrier del resultado
low_filter = low_filter(carrier_filter : end);


%% Filtro Pasa Bandas para G

% Variables de filtro pasa banda
vc1 = [0 (8000/(Fs/2)) (8000/(Fs/2)) (14100/(Fs/2)) (14100/(Fs/2)) 1];
m = [0 0 1 1 0 0];

% Creacion del filtro
f2 = fir2(orden, vc1, m);

% Pasamos la señal por el filtro
band_filter = conv(signal_rec_cut, f2);

% Eliminamos el carrier de la señal
band_filter = band_filter(carrier_filter : end);

%% Filtro Pasa Altas para B

% Variables de filtro pasa alta
vc1 = [0 (15200/(Fs/2)) (15200/(Fs/2)) 1];
m = [0 0 1 1];

% Creacion de filtro pasa alta
f3 = fir2(orden, vc1, m);

% Pasamos la señal por el filtro
high_filter = conv(signal_rec_cut, f3);

% Eliminamos el carrier de la señal
high_filter = high_filter(carrier_filter:end);


%% Demodulacion de señales

% Demodulacion de señal R
% Aplicamos la demodulación de Hilbert
signal_demod_R = abs(hilbert(low_filter));

% Obtenemos la media con el tamaño máximo y mínimo de la señal
mean_R = (max(signal_demod_R) - min(signal_demod_R)) / 2;

% Restamos la media
signal_demod_mean_R = signal_demod_R - mean_R;


% Demodulacion de señal G
% Aplicamos la demodulación de Hilbert
signal_demod_G = abs(hilbert(band_filter));

% Obtenemos la media con el tamaño máximo y mínimo de la señal
mean_G = (max(signal_demod_G) - min(signal_demod_G)) / 2;

% Restamos la media
signal_demod_mean_G = signal_demod_G - mean_G;


% Demodulacion de señal B
% Aplicamos la demodulación de Hilbert
signal_demod_B = abs(hilbert(high_filter));

% Obtenemos la media con el tamaño máximo y mínimo de la señal
mean_B = (max(signal_demod_B) - min(signal_demod_B)) / 2;

% Restamos la media
signal_demod_mean_B = signal_demod_B - mean_B;



%% Match Filter de señales

% Pasamos la señal demodulada por el match filter
signal_match_R = conv(signal_demod_mean_R, p);
signal_match_G = conv(signal_demod_mean_G, p);
signal_match_B = conv(signal_demod_mean_B, p);



%% Normalizar

% Las señales son normalizadas para el momento de ejecución en el cluster
signal_match_R=signal_match_R./max(abs(signal_match_R(:)));
signal_match_G=signal_match_G./max(abs(signal_match_G(:)));
signal_match_B=signal_match_B./max(abs(signal_match_B(:)));



%% Cluster Variance

% Variables del cluster

% Contador para el ciclo while
i = 0;                

% Inicio de la señal, esto asegura que no se tome información no necesaria
index_R = 57;      

% Acotanodo la señal quitando headder, para saber el límite de la señal
size_R = numel(signal_match_R(index_R : end)) / mp; 

% Utilizamos un header más grande para tener más datos a procesar y sea más precisa la seleción de datos
size_R = size_R - 480;  

% Diseño de la ventana de 40 bits
bits = 5;
size_wind = (bits * 8 + 1);

% Bandera para posicion del index
index_save = 0;

% Ciclo de corrimiento del cluster variance
while i < size_R

    % Vamos recorriendo símbolo por símbolo en saltos de mp en cada color
    matriz_R = reshape(signal_match_R(index_R:index_R+mp*size_wind-1),mp,size_wind);     
    matriz_G = reshape(signal_match_G(index_R:index_R+mp*size_wind-1),mp,size_wind);    
    matriz_B = reshape(signal_match_B(index_R:index_R+mp*size_wind-1),mp,size_wind);    



    % El signo de la matriz R (color rojo) puede ser usada en el cluster para
    % la señal verde y azul, se eliminan esas variables para hacer mas
    % eficiente la ejecución del código

    % Obtenemos el signo para restarlo con la matriz de muestras
    q_R = sign(matriz_R);      

    % Obtenemos la varianza
    data_var_R = sum((q_R-matriz_R).^2,2);    
    
    % Obtenemos el índice de la matriz del valor más pequeño de la varianza obtenida
    [minimo_R, indice_R] = min(data_var_R);     

    
    if indice_R == 12
        index_save = 1;
    elseif indice_R == 1 && index_save == 1
        indice_R = indice_R + (mp / 2);
        index_save = 0;
    end
 
    % Incrementamos el index para avanzar en las posiciones del símbolo
    index_R=index_R+mp;     
    
    % Incrementamos el contador
    i=i+1;    
    
    % Guardamos el indice actual
    red_index(i) = indice_R;
    
    % Almacenamos el valor más óptimo de acuerdo a la varianza
    bits_recover_R(i)=matriz_R(indice_R,size_wind);     
    bits_recover_G(i)=matriz_G(indice_R,size_wind);    
    bits_recover_B(i)=matriz_B(indice_R,size_wind);   
    
    
    % Se limpia la bandera
    index_save = 0;
 
end


%% Recuperacion de imágenes

% Variable para el tamaño de la imagen
image_size = 100;


% Color rojo
% Obtenemos el signo de los bits recuperados
sym_RX_R = sign(bits_recover_R(1:end));     

% Generamos un vector de unos
bits_RX_R = ones(1,numel(sym_RX_R));     

% Condicional para generan pulsos bipolares
bits_RX_R(sym_RX_R == -1) = 0;              

% Convertimos el tren de puslsos en una matriz
br_R = vec2mat(bits_RX_R,8);                

% Convertimos de binario a decimal
ar_R = bi2de(br_R, 'left-msb');             

% Convertimos la matriz al tamaño de la imagen
ar_R = vec2mat(double(ar_R),image_size,image_size);      


% Color verde
% Obtenemos el signo de los bits recuperados
sym_RX_G = sign(bits_recover_G(1:end));     

% Generamos un vector de unos
bits_RX_G = ones(1,numel(sym_RX_G));        

% Condicional para generan pulsos bipolares
bits_RX_G(sym_RX_G == -1) = 0;              

% Convertimos el tren de pulsos en una matriz
br_G = vec2mat(bits_RX_G,8);                

% Convertimos de binario a decimal
ar_G = bi2de(br_G, 'left-msb');           

% Convertimos la matriz al tamaño de la imagen
ar_G = vec2mat(double(ar_G),image_size,image_size);       


% Color azul
% Obtenemos el signo de los bits recuperados
sym_RX_B = sign(bits_recover_B(1:end));     

% Generamos un vector de unos
bits_RX_B = ones(1,numel(sym_RX_B));        

% Condicional para generan pulsos bipolares
bits_RX_B(sym_RX_B == -1) = 0;              

% Convertimos el tren de puslso en una matriz
br_B = vec2mat(bits_RX_B,8);                

% Convertimos de binario a decimal
ar_B = bi2de(br_B, 'left-msb');

%Convertimos la matriz al tamaño de la imgaen
ar_B = vec2mat(double(ar_B),image_size,image_size);       

%Concatenamos la señal RGB
imagen_final(:,:,1) = ar_R';                
imagen_final(:,:,2) = ar_G';
imagen_final(:,:,3) = ar_B';

% Una vez concatenada, mostramos la imagen
imshow(uint8(imagen_final))                 



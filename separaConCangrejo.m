%Separo los tramos de señal que tienen cangrejos

%% Reseteo matlab
clear
close all
clc

%% Criterios
passBand = [2E3 19E3]; %Banda de paso de frecuencia en donde se encuentran los cangrejos
meanTime = 30E3; %30 mil muestras es el tiempo que duran las detecciones que vi a ojo
maxTime = 3*meanTime; %Lo máximo que puede medir una detección para que se guarde son tres cangrejos superpuestos
minTime = meanTime/3; %Lo mínimo para guardar un archivo es una detección corta de 10K muestras
win = 5E3; %Esta es la ventana del filtro promediador, lo tengo que usar porque aparecen muchos cruces por cero en la potencia instantánea. Hay una relación entre esta ventana y la frecuencia de paso del filtro pasabandas
weights = (1/win)*ones(1,win); %Pesos de la ventana de promediado
thr = 0.75; %Es el umbral para la detección

%% Carpetas
%Carpeta de datos

folderIn = '.\Sonidos positvos Cyrtograpsus angulatus\pruebas\';
fileList = dir([folderIn '*.wav']);  %Carga la lista de archivos .wav

%Arma carpeta para guardar datos
folderOutDet = [folderIn 'detectados\']; %Carpeta donde se guardan los audios con las detecciones
mkdir(folderOutDet)
folderOutRui = [folderIn 'ruido\']; %Carpeta donde se guardan los audios sin detección
mkdir(folderOutRui)

%% Carga los datos, calcula y guarda
for i = 1:length(fileList)
    fileIn = fileList(i).name;
    
    %Carga los datos
    newData = importdata([folderIn fileIn]);
    vars = fieldnames(newData);
    for j = 1:length(vars)
        assignin('base', vars{j}, newData.(vars{j}));
    end
    
    %Filtro en frecuencia para aislar a los cangrejos en el espectro
    data1 = bandpass(data,passBand,fs);
    
    % Hago detector de potencia
    data2 = data1.^2; %Potencia instantánea
    data3 = normalize(data2,"scale"); %Esto lo hago para independizarme de la amplitud de cada audio de muestra, estaría normalizando el piso de ruido
    data4 = filter(weights,1,data3); %Acá salen los datos del filtro promediador. Hago esto porque aparecen muchos cruces por cero para una detección.
    det = (data4 > thr); %Vector que contiene unos cada vez que se supera el umbral
    
    %------Para ver que pasaaaa------DEBUG
  
    %Guardo el archivo filtrado para verlo en audio
    fileOut = [folderOutDet fileIn(1:end-4) 'Filtrado' fileIn(end-3:end)];
    saveData = data1; %Ya estaba normalizado por "scale"
    audiowrite(fileOut,saveData,fs)
    
    %Guardo el archivo antes del umbralado para verlo en audio
    fileOut = [folderOutDet fileIn(1:end-4) 'PreUmral' fileIn(end-3:end)];
    saveData =  normalize(data4,"range"); %Lo normalizo para que no seescape de 1
    audiowrite(fileOut,saveData,fs)    
    
    %Hago el vector para ir escribiendo las detecciones
    dataExtr = zeros(length(data), 1);
    %-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0-0

   
    % Extraigo las porciones con detección
    count = 0; %Cuenta la cantidad de extracciones
    flag = 1; %Bandera que indica que la posición anterior no tiene detección
    for j = 1:length(det)
        if det(j) %detectó que supera el umbral, ya está recorriendo adentro de una detección
            if flag %Si es el primer punto de la detección
                ini = j;
                flag = 0;
            end
        else %Si está afuera de la detección
            if ~flag % Si el punto anterior pertenece a una detección
                fin = j-1;
                index = ini:fin; %
                flag = 1;
                if length(index) > minTime %Guarda el archivo si la detección es más larga que el tiempo mínimo
                    if length(index) < maxTime %Guarda el archivo si la detección es mas corta que el tiempo máximo
                        count = count + 1;
                        fileOut = [folderOutDet fileIn(1:end-4) '_' num2str(count) fileIn(end-3:end)];
                        audiowrite(fileOut,data(index),fs);
                        %%%DEBUGGG%%%%
                        %Escribo el vector con las detecciones
                        dataExtr(index) = data(index);
                        %%%%%%%%%%%%%%
                    end
                end
            end
        end
    end
    
    %%%DEBUGGGGG%%%%%
    %Guardo un el archivo que contiene solo las extracciones
    fileOut = [folderOutDet fileIn(1:end-4) 'Extrac' fileIn(end-3:end)];
    saveData =  dataExtr; %Lo normalizo para que no seescape de 1
    audiowrite(fileOut,saveData,fs)
    %%%%%%%%%%%%%%%%%%
    
    
    % Extraigo porciones sin cangrejos
    count = 0; %Cuenta la cantidad de extracciones
    flag = 1; %Bandera que indica que la posición anterior no tiene detección    
    for j = 1:length(det)
        if ~det(j)
            if flag
                ini = j;
                flag = 0;
            end
        else
            if ~flag
                fin = j-1;
                index = ini:fin;
                flag = 1;
                if length(index) > minTime %Guarda el archivo si la detección es más larga que el tiempo mínimo
                    if length(index) < maxTime %Guarda el archivo si la detección es mas corta que el tiempo máximo
                        count = count + 1;
                        fileOut = [folderOutRui fileIn(1:end-4) '_' num2str(count) fileIn(end-3:end)];
                        audiowrite(fileOut,data(index),fs)
                    end
                end
            end
        end
    end
end
%Separo los tramos de señal que tienen cangrejos
%Una mejora sería expresar meanTime en función del tiempo y no de la cantidad de muestras

%% Reseteo matlab
clear
close all
clc

%% Criterios
passBand = [3 20]*1E3;
antiPulseWeights = ones(20, 1); %Pesos de la ventana de promediado para que no salga la respuesta al impulso del filtro pasabanda uso 300K/15K = 20 muestras
meanTime = 50E3; %50 mil muestras es el tiempo que duran las detecciones que vi a ojo
maxTime = 3*meanTime; %Lo máximo que puede medir una detección para que se guarde son tres cangrejos superpuestos
minTime = floor(meanTime/3); %Lo mínimo para guardar un archivo es una detección corta de 10K muestras
margin = floor(meanTime/10); %El margen para la detección
win = minTime; %Esta es la ventana del filtro promediador, lo tengo que usar porque aparecen muchos cruces por cero en la potencia instantánea. Hay una relación entre esta ventana y la frecuencia de paso del filtro pasabandas
weights = ones(win, 1); %Pesos de la ventana de promediado
prodThr = 1.5; %El número que se le va a

%% Carpetas
%Carpeta de datos
folderIn = '.\Sonidos experimentos Neohelice granulata\B3Gm+m+fr\ch1\'; %Con barra \ al final
fileList = dir([folderIn '\*.wav']); %Carga la lista de archivos .wav

%Arma carpeta para guardar datos
folderOutDet = [folderIn 'detecciones\']; %Carpeta donde se guardan los audios con las detecciones
mkdir(folderOutDet)
folderOutRui = [folderIn 'ruido\']; %Carpeta donde se guardan los audios sin detección
mkdir(folderOutRui)
folderOutCont = [folderIn 'control\']; %Carpeta donde se guardan los audios recortados y el umbral
mkdir(folderOutCont)

%% Carga los datos, calcula y guarda
for i = 1:length(fileList)
    fileIn = fileList(i).name;

    %Carga los datos, ya me lo guarda en data
    newData = importdata([folderIn fileIn]);
    vars = fieldnames(newData);
    for j = 1:length(vars)
        assignin('base', vars{j}, newData.(vars{j}));
    end

    data1 = filter(antiPulseWeights,1,data); %Hago el promedio de ventana deslizante para que no salga la respuesta al impulso del filtro que sigue
    data2 = bandpass(data1,passBand,fs); %Aplico filtro pasabanda
    data3 = data2.^2; %Calculo potencia instantánea
    data4 = filter(weights,1,data3); %El resultado tiene muchos cruces por cero hago el promedio

    thr = prodThr*mean(data4); %Vector que contiene unos cada vez que se supera el umbral

    det = (data4 > thr); %Vector que contiene unos cada vez que se supera el umbral

    %------Para ver que pasaaaa------DEBUG

    %Guardo las detecciones para verlo en audio
    saveData = data.*det;
    fileOut = [folderOutCont fileIn(1:end-4) '_detecciones' fileIn(end-3:end)];
    audiowrite(fileOut,saveData,fs)

    %Guardo el archivo pre umbral
    saveData = (data4-thr)/(max(data4)-thr); %Lo normalizo para que no se escape de 1
    fileOut = [folderOutCont fileIn(1:end-4) '_preUmbral' fileIn(end-3:end)];
    audiowrite(fileOut,saveData,fs)

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
                if ini > margin %Este if previene el caso de comenzar con una detección
                    index = (ini-margin):fin; %Desplazo el primer índice para preservar el flanco
                else
                    index = 1:fin;
                end
                flag = 1;
                if length(index) > minTime %Guarda el archivo si la detección es más larga que el tiempo mínimo me proteje de detecciones cortas por algún sobrepico
                    if length(index) < maxTime %Guarda el archivo si la detección es mas corta que el tiempo máximo, me proteje de detecciones largas por intervalos con ruido
                        count = count + 1;
                        fileOut = [folderOutDet fileIn(1:end-4) '_' num2str(count) fileIn(end-3:end)];
                        audiowrite(fileOut,data(index),fs);
                    end
                end
            end
        end
    end

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
                if length(index) > minTime %Evita guardar intervalos de ruido muy cortos, estos intervalos pueden no ser representativos del ruido
                    count = count + 1;
                    fileOut = [folderOutRui fileIn(1:end-4) '_' num2str(count) fileIn(end-3:end)];
                    audiowrite(fileOut,data(index),fs)
                end
            end
        end
    end
end

msgbox('Listo', ''); % Mostrar ventana emergente al finalizar

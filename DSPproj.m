clear
clc
rng('shuffle')

%% read file and set parameters
%save all the audio suffix types MATLAB supports
fileSuffix={'.wav','.ogg','.flac','.au','.aiff','.aif','.aifc','.mp3','.m4a','.mp4'};
openName=input('Please enter the name of the audio file: ','s');    %input filename
path='/Users/zhaoyuanfang/Desktop/EE/DSP/';                         %specify the file path
foundfile=false;                                                    %file not found yet

%prompt the user to enter filename, until it is a legal one
while ~foundfile
    %loop through the suffix folder
    for it=1:length(fileSuffix)
        %update the temporary (test) file name
        tempname=[path,openName,char(fileSuffix(it))];
        if exist(tempname, 'file')      %check if this file exists
            fullname=tempname;          %if exists, set the fullname
            foundfile=true;             %the file has been found
        end
    end
    
    if ~foundfile
        disp('File not found!');        %display error message
        openName=input('Please choose another file: ','s'); %prompt for another input
    end
end

[x,fs]=audioread(fullname); %read the audio file, fs---sampling frequency
fN=fs/2;                    %Nyquist frequency
audioLen=length(x);         %record the length

playOri=input('Play the original file? Y/N: ','s');
while ~((playOri=='Y') || (playOri=='N'))
    playOri=disp('Please enter Y for yes or N for no: ','s');
end
if playOri=='Y'
    playChoice=true;
else
    playChoice=false;
end
if playChoice
    sound(x,fs);    %playback the original audio
end

%prompt the user to enter parameters, using representative variable names
%the while loops guarantee the inputs are usable for the program
%minimum length of silence
minLen=input('Lower bound: ');
while minLen<0
    minLen=input('Please enter a positive number');
end
%maximum length of silence
maxLen=input('Higher bound: ');
while maxLen<minLen
    disp('Higher bound must be larger than lower bound.');
    maxLen=input('Higher bound: ');
end
%maximum amplitude to be a silence
thresh=input('Silence threshold: ');
%replacement length
repSec=input('Replace these silences with silences of length: ');
while repSec<0
    repSec=input('Please enter a positive number');
end
%choice of replacement: safe noise/complete silence
safeinput=input('Replace silences with safe noise? Y/N: ','s');
while ~((safeinput=='Y') || (safeinput=='N'))
    safeinput=input('Please enter Y for yes or N for no: ','s');
end

%modify the inputs in the way the program wants
if safeinput=='Y'
    safenoise=true;
else
    safenoise=false;
end
repLen=repSec*fs;   %length of silences to insert
Tstep=minLen*fs/10; %set the step of the loop later
if mod(Tstep,2)==1  %make sure that Tstep is even, so that Tstep/2 can be used directly later
    Tstep=Tstep-1;
end

%% detect the silences
isSilence=true;             %flag for the silence
delete=zeros(1,audioLen);   %"bool" array
Nsi=0;                      %number of silences accumulated
front=1;                    %front array mark
rear=1;                     %rear array mark
Nright=0;
front_array=[];             %the starts of "delete" zones
rear_array=[];              %the ends of "delete" zones
eitCount=0;                 %the total number of noises
eitTot=0;                   %the total "energy" of noises

%loop through the audio
for it=1:Tstep:audioLen-Tstep   
    spec=fft(x(it:it+Tstep-1)); %use fft 
    mag=abs(spec);
    eit=sum(mag(1:Tstep/2).^2);
    
    %check whether it is silence and update the information
    if (eit>thresh)             
        isSilence=false; 
        %if there is no silence before, it's safe to update front mark
        if Nsi==0 
            front=it+Tstep; 
        end
    else
        eitCount=eitCount+1;
        eitTot=eitTot+sum(x(it:it+Tstep-1));
        Nsi=Nsi+1;          %extend the length of silence
        rear=it+Tstep-1;    %update rear mark
        isSilence=true;     %is still silence
    end
    
    %if the length of this silence meets all the requirements
    if (~isSilence) && ((Nsi*Tstep>=minLen*fs) && (Nsi*Tstep<=maxLen*fs))
        Nsi=0;                %this silence is over and processed, reset Nsi.
        delete(front:rear)=1; %mark these "qualified" silences as true in delete vector
        Nright=Nright+1;      %update the number of "qualified" silences
        
        if Nright==1          %if this is the first qualified period, no possiblity of repetition
            front_array(Nright)=front;
            rear_array(Nright)=rear;
        else
            if front~=front_array(Nright-1) %make sure that the front_array marks are unique
                front_array(Nright)=front;
                rear_array(Nright)=rear;
            else
                Nright=Nright-1;            %if not unique, go back
            end
        end
        front=it+Tstep;       %finished processing, update front mark
    end
    
    if (~isSilence) %after the condition above, now is safe to update front mark
        Nsi=0;
        front=it+Tstep;
    end
end

%% format the result & play the soun
index=1;                            %index of the output vector
Nprocessed=1;                       %number of qualified silences processed
repfinished=false;                  %whether the replacement has been finished
safeMin=0;                          %mininum of safe noise
safeMax=eitTot/(eitCount*Tstep/2);  %maximum of safe noise

if Nright==0
    disp(['No silences found!']);
else
    %if not replacing the silences, just copy the sounds without silence
    if repLen==0                                %loop & copy the sounds without silence
        for it=1:audioLen
            if ~delete(it)                      %if this frame is kept, copy it
                out(index)=x(it);
                index=index+1;
            end
        end
    else
        for it=1:audioLen                       %loop & copy the sounds without silence & replace the silences
            if ~repfinished                     %only insert when not finished
                if it==front_array(Nprocessed)  %if previous silence mark
                    if safenoise                %check if safe noise is needed
                        out(index:index+repLen-1)=(safeMax-safeMin).*rand(repLen,1)+safeMin; %generate random safe noise
                    else
                        out(index:index+repLen-1)=0;
                    end
                    index=index+repLen;
                    Nprocessed=Nprocessed+1;    %proceed to the next
                end
                if Nprocessed>Nright             %check if finished
                    repfinished=true;
                end
            end
            
            if ~delete(it)                      %if this frame is kept, copy it
                out(index)=x(it);
                index=index+1;
            end
        end
    end
    pause();
    sound(out,fs);  
end                            %playback the modified audio

%% export the modified audio file
%check if the user wants to save the file
dosavestr=input('Do you want to save the audio? Y/N: ','s');
while ~((dosavestr=='Y') || (dosavestr=='N'))
    dosavestr=input('Please enter Y for yes or N for no: ','s');
end
if dosavestr=='Y'
    dosave=true;
else
    dosave=false;
end

%if the user wants to save, ask for the file and export it.
if dosave
    filepath='/Users/zhaoyuanfang/Desktop/EE/DSP/';
    filename=input('Please enter the filename: ','s');
    filename=[filepath,filename,'.wav'];
    audiowrite(filename,out,fs);                      %write the file
    disp(['File saved as ',filename,', thank you!']); %report the information
%if the user does not want to save, give a thank message.
else
    disp('File not saved, thank you!');
end
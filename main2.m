%% main 2, more than one user per cell
clear all

M = 100; % number of antennas at the BS
K = 1; % Number of users per BS
N = 10; % Number of antennas per User
Radius = 500; % Radius of the cells (in m)
nrBS = 7; % Number of BS
beamform = 0; % if beamform = 0, w = [1; 1;], i.e., there is no beamforming at the user
% generate users (SystemPlot)
% generate one tier (7 BS) with one user per BS. The radius of the BS is
% 500 m
Distances = SystemPlot(nrBS,K,Radius);
betas = 1./(Distances.^(3.8)); % loss factor

% generate the channel realizations (7 cells, K user per cell, 2 antennas
% per user) 98 h (each user in the system, 7, vs each BS, 7, and every user
% has 2 antennas, 7*K*2)

% 1st matrix in h, BS1 vs UE1 antenna 1 and 2
% 2nd matrix in h, BS1 vs UE2 antenna 1 and 2 ...

for i=1:nrBS*K*nrBS
    h(:,:,i) = (sqrt(2)./2)*(randn(M,N)+1i*randn(M,N));
end

% for each h calculate the covariance matrix (each h is one antenna from
% the user to eacH BS)
angularSpread = 10; % 10�
R = zeros(M,M,nrBS*K*N*nrBS/N);
for n=1:nrBS*K*N*nrBS/N
    theta = rand*pi; % angle of arrival (uniformly distributed between 0 and pi)
    R(:,:,n) = functionOneRingModel(M,angularSpread,theta);
    % generate the g's
%     for i=1:antennasPerUser
%         g(:,:,antennasPerUser*(n-1)+i) = sqrt(R(:,:,n))*h(:,:,antennasPerUser*(n-1)+i);
%     end
    
    
end
%% Obtaining the beamforming vector
for n = 1:K*nrBS % for each user, one Ru
    theta = rand.*pi;

    Ru(:,:,n) = functionOneRingModel(N,angularSpread,theta);
    [eigenVect(:,:,n),eigenVal(:,:,n)] = eig(Ru(:,:,n));
    w(:,n) = eigenVect(:,end,n);
    if beamform == 0
        w(:,n) = ones(N,1);
    end
end

%%
count = 0;
a = 0;
for n=1:nrBS*K*nrBS
    
    
    user = mod(n,K*nrBS);
    if user == 0
        user = K*nrBS;
    end
    g(:,:,n) = sqrt(R(:,:,n))*h(:,:,n)*sqrt(Ru(:,:,user)); 
    
    
end

%% creating Rkk for each user Rkk = R*trace(Ru^(1/2)*w*w^(H)*Ru^(1/2)^H)
% u = 1;
% for t = 1:nrBS
%     for a = 1:K
%         Rk_ = sqrt(Ru(:,:,u))*w(:,u)*ctranspose(w(:,u))*sqrt(ctranspose(Ru(:,:,u)));
%         Rkk(:,:,u) =  R(:,:,(t-1)*K*nrBS+(t-1)*K+a)*trace(Rk_);
%         u = u+1;
%     end
%     
% end

for u = 1:nrBS*K % For all the users
    
    Rk_(:,:,u) = sqrt(Ru(:,:,u))*w(:,u)*ctranspose(w(:,u))*sqrt(ctranspose(Ru(:,:,u)));
 
    for t = 1:nrBS % For all users vs all BS
        
        Rkk(:,:,(t-1)*K*nrBS + u) = R(:,:,(t-1)*K*nrBS + u)*trace(Rk_(:,:,u));
       
    end
    
end

% THIS IS THE SAME AS DE LAST CODE ABOVE

% for t = 1:nrBS
%         Rk_ = sqrt(Ru(:,:,u))*w(:,u)*ctranspose(w(:,u))*sqrt(ctranspose(Ru(:,:,u)));
%     
%         Rkk2(:,:,(t-1)*K*nrBS + 1:(t-1)*K*nrBS + nrBS*K) = R(:,:,(t-1)*K*nrBS + 1:(t-1)*K*nrBS + nrBS*K)*trace(Rk_);
%  end


%%
% generate the receive signals y (7 receive signals, one for each BS)
% we have L base stations and K*L total users (number of BS times the
% number of users per BS)

p = Radius^(1.8); % power of the pilots (0 dB of received power at the cell edge)
p = linspace(1,Radius^(1.8),500);
%noisePower = linspace(20*p,0,500); The power of the noise is constant
%received = receivedSignal(p,nrBS,K,M,noisePower,g,antennasPerUser,betas);
realizations = 1;
for m=1:realizations
    for r=1:length(p) % I'm using the same system for all the different SNR, is it correct?
        received(:,:,r,m) = receivedSignal2(p(r),nrBS,K,M,1,g,N,betas);
    end
end
%%
% do the MMSE

GMMSE = zeros(nrBS,M,length(p),K,realizations);
for m=1:realizations
    if(mod(m,10) == 0)
        m
    end
    for r=1:length(p)% all the realizations (different SNR)

        for t=1:nrBS % for each BS, calculate the MMSE estimator of the channel

            Rsum = sum(Rkk(:,:,(t-1)*K*nrBS+1:(t-1)*K*nrBS+nrBS*K),3);
            
            % ATENTO AL 1 ANTES DE LA r Y DESPUES DE LA m!!
            % index = (t-1)*K*nrBS+K*(t-1)+a
            for a=1:K
                GMMSE(t,:,r,a,m) = received(t,:,r,m)*R(:,:,(t-1)*K*nrBS+(t-1)*K+a)*inv(p(r)*Rsum + eye(M));
                C(:,:,t,a) = Rkk(:,:,(t-1)*K*nrBS+K*(t-1)+a) - p(r)*Rkk(:,:,(t-1)*K*nrBS+K*(t-1)+a)*inv(p(r)*Rsum + eye(M))*Rkk(:,:,(t-1)*K*nrBS+K*(t-1)+a);
                gEff(:,(t-1)*K+a,r) = h(:,:,(t-1)*K*nrBS+K*(t-1)+a)*w(:,(t-1)*K+a);
%                 gEff2 = gEff(:,(t-1)*K+a,r);
%                 normFactor = ctranspose(gEff2)*gEff2;
                normFactor = trace(Rkk(:,:,(t-1)*K*nrBS+K*(t-1)+a));
                MSE(t,r,a) = trace(C(:,:,t,a))/normFactor;
            end
           
            %MSEH(t,r,m) = immse(GMMSE(t,:,r,1,m),h((t-1)*K*nrBS+t,:));
                        
            %C(:,:,t) = R(:,:,(t-1)*K*nrBS+t) - p(r)*R(:,:,(t-1)*K*nrBS+t)*inv(p(r)*Rsum + eye(M))*R(:,:,(t-1)*K*nrBS+t);
            
            
        
        end

    end

end
%MSEGmean = mean(MSEG,3);
%MSEHmean = mean(MSEH,3);
%MSEHmean = mean(MSEH,3);
%%
for t=1:nrBS
    for u=1:K
        plotMSE(MSE,t,u,p);
    end
end
%%
figure;
plot(abs(MSE(5,:,2)));


%% 
figure;
plot(MSEH(1,:))

figure;
plot(MSEH(2,:))
figure;
plot(MSEH(3,:))

figure;
plot(MSEH(4,:))

figure;
plot(MSEH(5,:))

figure;
plot(MSEH(6,:))

figure;
plot(MSEH(7,:))
%%
figure;
hold on
for i=1:size(MSEHmean,1)
   plot(MSEHmean(i,:)); 
end
legend('MSE in BS1','MSE in BS2','MSE in BS3','MSE in BS4','MSE in BS5','MSE in BS6','MSE in BS7')













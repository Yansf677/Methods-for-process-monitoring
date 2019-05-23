clc
clear
%% data preprocessing
load TEdata.mat; IDV = 1; 
X_train = data(:, [1:22,42:52], 22); Y_train = data(:, 35, 22);
X_test = data(:, [1:22,42:52], IDV); Y_test = data(:, 35, IDV);

[~, m] = size(X_train); [n, p] = size(Y_train);
[X_train, Xmean, Xstd] = zscore(X_train); [Y_train, Ymean, Ystd] = zscore(Y_train);
[N, ~] = size(X_test);
X_test = (X_test - repmat(Xmean, N, 1))./repmat(Xstd, N, 1); Y_test = (Y_test - repmat(Ymean, N, 1))./repmat(Ystd, N, 1);

%% offline training
% KPCA
options.KernelType = 'Gaussian'; options.t = sqrt(5000/2);
K = constructKernel(X_train,[],options);
s = ones(n,1); I = eye(n); Kc = (I - s*s'/n) * K * (I - s*s'/n); 
[W, L_W] = eig(Kc./n); W = W*(L_W^(-0.5)); T = Kc*W;

Latent = zeros(size(L_W, 1), 1);
for j = 1:size(L_W, 1)
    Latent(j) = L_W(j, j);
end
pc=0;
for i=1:n
    cpv = sum(Latent(1:i))/sum(Latent);
    if cpv >= 0.9
        pc = i; break;
    end
end
T = T(:, 1:pc); W = W(:, 1:pc);
% regression
Q = ((T' * T) \ T' * Y_train)'; Y_e = T * Q';
[Qy, Ty, Latent_y, Tsquare_y] = pca(Y_e);
Zy = eye(n) - Ty * pinv(Ty' * Ty) * Ty'; Ko = Zy * K * Zy';
[Wo, L_Wo] = eig(Ko./n); Wo = Wo * (L_Wo^(-0.5)); To = Kc * Wo;

Latento=zeros(size(L_Wo,1),1);
for j=1:size(L_Wo,1)
    Latento(j)=L_Wo(j,j);
end
pco=0;
for i=1:n
    cpv=sum(Latento(1:i))/sum(Latento);
    if cpv>=0.999
        pco=i;
        break;
    end
end
To = To(:, 1:pco); Wo = Wo(:, 1:pco);

% control limit
ALPHA=0.97;
Ty_ctrl = 1*(n-1)*(n+1) * finv(ALPHA,1,n-1) / (n*(n-1));
To_ctrl = pco*(n-1)*(n+1) * finv(ALPHA,pco,n-pco) / (n*(n-pco));

%% online testing
Ty2 = zeros(N, 1); To2 = zeros(N, 1);
for i=1:N
    k_test=constructKernel(X_test(i,:), X_train, options);kc_test=(k_test-s'*K/n)*(I-s*s'/n);
    t_test = kc_test * W;
    
    tynew = t_test * Q' * Qy; % row vector
    Ty2(i) = tynew * pinv(Ty' * Ty / (n-1)) * tynew';
    
    tonew = kc_test * Zy' * Wo - tynew * pinv(Ty'*Ty) * Ty' * Kc * Zy' * Wo;
    To2(i) = tonew * pinv(To'*To/(n-1)) * tonew';
end

% type I and type II errors
FAR_Ty = 0; FDR_Ty = 0;
FAR_To = 0; FDR_To = 0;
for i = 1:160
    if Ty2(i) > Ty_ctrl
       FAR_Ty = FAR_Ty + 1;
    end                     
    if To2(i) > To_ctrl
       FAR_To = FAR_To + 1;
    end                     
end
for i = 161:960
    if Ty2(i) > Ty_ctrl
       FDR_Ty = FDR_Ty + 1;
    end                     
    if To2(i) > To_ctrl
       FDR_To = FDR_To + 1;
    end                     
end
FAR_Ty = FAR_Ty / 160; FAR_To = FAR_To / 160;
FDR_Ty = FDR_Ty / 160; FDR_To = FDR_To / 160;

% ROC curves including f1-score
class_1 = Ty2(1:160); 
class_2 = Ty2(161:960);
figure;
roc_Ty = roc_curve(class_1, class_2);

class_1 = To2(1:160); 
class_2 = To2(161:960);
figure;
roc_To = roc_curve(class_1, class_2);

% statistics plot
figure;
subplot(2,1,1);plot(Ty2,'k');title('KPCR');hold on;plot(Ty_ctrl*ones(1,N),'k--');xlabel('sample');ylabel('Ty^2');hold off;
subplot(2,1,2);plot(To2,'k');title('KPCR');hold on;plot(To_ctrl*ones(1,N),'k--');xlabel('sample');ylabel('To^2');hold off;
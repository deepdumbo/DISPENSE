%==========DPsti-TSE nonrigid motion correction simulation============
cd('/home/qzhang/lood_storage/divi/Users/qzhang/SoSAD/SoSAD/simulations')
clear; close all; clc
load('test_data.mat')

%% reference
kx_dim = size(ima_k_spa_ideal,1);
ky_dim = max(TSE.ky_matched) * 2 + 1; %consider half scan
kz_dim = max(TSE.kz_matched) * 2 + 1; %consider half scan
ch_dim = TSE.ch_dim; 
kspa_ref = zeros(kx_dim, ky_dim, kz_dim, TSE.ch_dim);

for prof_idx = 1:size(ima_k_spa_ideal, 2)
    ky_idx = TSE.ky_matched(prof_idx) + max(TSE.ky_matched) + 1;
    kz_idx = TSE.kz_matched(prof_idx) + max(TSE.kz_matched) + 1;
    ch_idx = mod(prof_idx, ch_dim) + 1;
    kspa_ref(:,ky_idx,kz_idx,ch_idx) = ima_k_spa_ideal(:,prof_idx); 
end
size(kspa_ref)

% remove stupid checkerboard pattern
che=create_checkerboard([1,size(kspa_ref,2),size(kspa_ref,3)]);
kspa_ref=bsxfun(@times,kspa_ref,che);
kspa_ref=squeeze(kspa_ref);

ima_ref = bart('fft -i 7',kspa_ref);
ima_coil_combined = bart('rss 8', ima_ref);
figure(1); montage(permute(abs(ima_coil_combined),[1 2 4 3]),'displayrange',[]);


sense_map = bart('ecalib -S -m1', kspa_ref);
figure(2);  montage(angle(sense_map(:,:,25,:)),'displayrange',[]);
figure(3);  montage(abs(sense_map(:,:,25,:)),'displayrange',[]);
sense_map = normalize_sense_map(sense_map);

clear TSE_sens_map ima_coil_combined

%% simulated phase error data
kx_dim = size(ima_k_spa_ideal,1);
ky_dim = max(TSE.ky_matched) * 2 + 1; %consider half scan
kz_dim = max(TSE.kz_matched) * 2 + 1; %consider half scan
ch_dim = TSE.ch_dim; 
sh_dim = range(TSE.shot_matched)+1;
kspa = zeros(kx_dim, ky_dim, kz_dim, ch_dim, sh_dim);

for prof_idx = 1:size(ima_k_spa_ideal, 2)
    ky_idx = TSE.ky_matched(prof_idx) + max(TSE.ky_matched) + 1;
    kz_idx = TSE.kz_matched(prof_idx) + max(TSE.kz_matched) + 1;
    ch_idx = mod(prof_idx, ch_dim) + 1;
    sh_idx = TSE.shot_matched(prof_idx);
    kspa(:,ky_idx,kz_idx,ch_idx, sh_idx) = ima_k_spa_ideal(:,prof_idx); 
end
size(kspa)

% remove stupid checkerboard pattern
che=create_checkerboard([1,size(kspa,2),size(kspa,3)]);
kspa=bsxfun(@times,kspa,che);
kspa=squeeze(kspa);

%phase error for every shot
phase_error = exp(i .* zeros(kx_dim, ky_dim, kz_dim, 1, sh_dim));

%corrupted kspa
kspa = bsxfun(@times,kspa,phase_error);
%% recon

image_corrected = msDWIrecon(kspa, sense_map, phase_error);
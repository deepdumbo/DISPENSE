
clear;clc; close all;
cd('/home/qzhang/lood_storage/divi/Ima/parrec/Kerry/Data/2017_08_15_SND_signal_evaluation');
%% trajectory calculation
close all; clear; clc;
trj_save_fn = 'traj_Sc25_26_27_for_Sc14.mat';
trajectory_measure_distance = 15; %in mm
spira_3D_trjectory_calculation(trj_save_fn, trajectory_measure_distance);
disp('-finished- ');

%% SET path for all the following steps
clear; close all; clc

data_fn = 'sn_15082017_1958263_27_2_wip_sc18_dpsti_sosad_linearV4.raw';
sense_ref_fn = 'sn_15082017_2006058_1000_47_wip_senserefscanV4.raw';
coil_survey_fn  = 'sn_15082017_2004480_1000_40_wip_coilsurveyscanV4.raw';

data_mat_fn = 'data_Sc27_3D.mat';
trj_mat_fn = 'traj_for_Sc27.mat';

%% Spiral Nav. data loading
disp('spiral Nav. data loading...')
nav_kspa_data_read(data_fn, data_mat_fn);

disp('-finished- ');
%% Spiral NUFFT recon.
disp(' Spiral NUFFT recon...');
close all;

nav_im_recon_nufft = [];
for dyn = 3:3
    %=============== recon parameters =========================
    recon_par.ignore_kz = 1;
    recon_par.recon_dim  = [36 36 1];
    recon_par.dyn_nr = dyn;
    recon_par.skip_point = 0 ;
    recon_par.end_point = 2000; %[]; %or []: till the end;
    recon_par.interations = 20;
    recon_par.lamda = 0.1;
    recon_par.recon_all_shot = 1;
    recon_par.sense_map_recon = 1;
    recon_par.update_SENSE_map = 0;
    recon_par.sense_calc_method = 'external'; %'ecalib' or 'external'
    recon_par.data_fn = data_fn;
    recon_par.sense_ref = sense_ref_fn;
    recon_par.coil_survey = coil_survey_fn;
    %========================  END  =========================
    
    nav_im_recon_nufft = cat(6, nav_im_recon_nufft, NUFFT_3D_recon(data_mat_fn,trj_mat_fn,recon_par));
end
save(data_mat_fn, 'nav_im_recon_nufft','-append');
disp('-finished- ');
%% -----BART recon -------%
%{
disp(' Spiral NUFFT recon (BART)...')
data_fn = 'data_Sc14_3D.mat';
trj_fn = 'traj_Sc25_26_27_for_Sc14.mat';

%======recon parameters ======%
bart_recon.ignor_kz = 0;  % 1for yes. 0 for no
bart_recon.diffusion_nr = 1;
bart_recon.skip_point =0;
bart_recon.end_point = [];
bart_recon.recon_dim = [26 26 10];
bart_recon.trj_scale_dim = [16 16 5];
bart_recon.shot_nr = 1;
bart_recon.nsa_nr = 1;
bart_recon.data_fn = data_fn;
bart_recon.sense_ref = sense_ref_fn;
bart_recon.coil_survey = coil_survey_fn;
bart_recon.update_SENSE_map = 0;
bart_recon.PICS = true;
bart_recon.sense_calc_method = 'external'; %'ecalib' or 'external'
%========end==================%
[reco_pics, igrid, igrid_rss] = bart_nufft_recon(data_fn, trj_fn, bart_recon);
 
figure(204); montage(permute(abs(reco_pics),[1 2 4 3]),'displayrange',[])
figure(205); montage(permute(angle(reco_pics),[1 2 4 3]),'displayrange',[-pi pi]); colormap jet
save(data_fn, 'reco_pics','igrid','igrid_rss','-append');
%}
%% unwrap nav phase (2D) & fast rigid motion estimation
close all; clc
disp(' unwrap nav phase (2D) & fast rigid motion estimation...')

load(data_mat_fn);
clear PE_estimation

ref_shot_ix = 1;
valid_data_ratio = 0.4; % pixels with highest 40% intensity are used for processing

for dyn = 1:4;
    
    nav_im_to_unwrap = permute(nav_im_recon_nufft(:,:,1,:,:,dyn), [1 2 4 5 6 3]);  %[x,y,z,ch,shot,dyn] ->[x,y,shot,ch,dyn,z] this is 2D
    nav_ima_phase_unwrapped = spiral_nav_phase_unwrapping_2D(nav_im_to_unwrap, ref_shot_ix);
    
    [nav_ima_phase_unwrapped_diff, fitted_nav_ima_phase, linear_phase_xy,global_phase, global_phase_diff_initial] = ...
        rigidMotion_parameter_calculation(nav_im_to_unwrap, nav_ima_phase_unwrapped, ref_shot_ix, valid_data_ratio);  %nav_kspa_to_process  in kspace and with size of [kx ky ch shot]
    
    PE_estimation.linear_phase_xy_all(:,:,:,dyn) = (linear_phase_xy);
    PE_estimation.global_phase_all(:,:,dyn) = (global_phase);
    
end
PE_estimation.nav_kx_dim = size(nav_im_recon_nufft, 1);
PE_estimation.nav_ky_dim = size(nav_im_recon_nufft, 2);

save(data_mat_fn, 'PE_estimation','-append');
disp('-finished- ');
%% TSE data sorting and default recon
close all; clc
disp(' TSE data sorting and default recon...')

[ima_k_spa_data,TSE.ky_matched,TSE.kz_matched,TSE.shot_matched, TSE.ch_dim,ima_kspa_sorted, ima_defakult_recon, TSE_sense_map] = ...
    TSE_data_sortting(data_fn, sense_ref_fn, coil_survey_fn);
save(data_mat_fn, 'ima_k_spa_data', 'ima_default_recon', 'TSE','TSE_sense_map','-append');

figure(606); immontage4D(permute(abs(ima_default_recon(80:240,:,:,:)),[1 2 4 3]), [10 120]);
disp('-finished- ');

%% TSE data correction
% load(data_mat_fn);
correction_shot_range = 15:28;
im_recon_nufft_cor = Perform_2D_SN_DPsti_recon(ima_k_spa_data, TSE, PE_estimation, correction_shot_range, TSE_sense_map);

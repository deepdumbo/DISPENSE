
clear; clc; close all
cd('/home/qzhang/lood_storage/divi/Ima/parrec/Kerry/Data/2017_10_27_SND_brain')
%% trajectory calculation
close all; clear; clc;
trj_save_fn = 'traj_for_Sc2.mat';
trajectory_measure_distance = 15; %in mm
spira_3D_trjectory_calculation(trj_save_fn, trajectory_measure_distance);
disp('-finished- ');

%% SET path for all the following steps
clear; close all; clc

data_fn = 'sn_27102017_1656438_3_2_wip_sc4_3d_snd_brain_4bV4.raw';
sense_ref_fn = 'sn_27102017_1640319_1000_5_wip_senserefscanV4.raw';
coil_survey_fn  = 'sn_27102017_1638050_1000_2_wip_coilsurveyscanV4.raw';

trj_mat_fn = 'traj_for_Sc2_3.mat';


%% B0 mapping data loading

disp(' Loading B0 mapping data...');

dicom_path = '/home/qzhang/lood_storage/divi/Ima/parrec/Kerry/Data/2017_10_27_SND_brain/00501_B0_map';
b0_mapping_data = load_b0_mapping_dicom(dicom_path);
b0_maps = b0_mapping_data(:,:,:,2).*(b0_mapping_data(:,:,:,1)>1e6);


figure(19); montage(permute(squeeze(abs(b0_maps)),[1 2 4 3]),'displayrange',[]); colormap jet; colorbar
disp(' Finished');


%% Spiral Nav. data loading
disp('spiral Nav. data loading...')
[nav_k_spa_data, Nav_VirtualCoilMartix] = nav_kspa_data_read(data_fn);
% nav_k_spa_data = nav_kspa_data_read(data_fn);

disp('-finished- ');
%% Spiral NUFFT recon.
disp(' Spiral NUFFT recon...');
save_mat_fn = 'Sc03_testing.mat';
close all;
[kx_length ch_nr shot_nr, dyn_nr] = size(nav_k_spa_data);

offcenter_xy = [0 0]; 
FOV_xy = [250 167.9688];
% nav_im_recon_nufft = [];
dyn_recon = 1:1;
for d = 1:length(dyn_recon)
    tic
    %% parameter setting
    dyn  = dyn_recon(d);
    disp(['dynamic: ',num2str(dyn)]);
    %=============== recon parameters =========================
    recon_par = initial_spiral_recon_par;
    recon_par.ignore_kz = 0;
    recon_par.acq_dim = [42 42 26];  
    recon_par.recon_dim  = [42 42 26];
    recon_par.dyn_nr = dyn;
    recon_par.skip_point = 0 ;
    recon_par.end_point = []; %or []: till the end;
    recon_par.selected_point = [];  %overrule skip_point and end_point
    recon_par.interations = 10;
    recon_par.lamda = 0;
    recon_par.recon_all_shot = 0;
    recon_par.sense_map_recon =1; 
    recon_par.update_SENSE_map = 0;
    recon_par.sense_calc_method = 'external'; %'ecalib' or 'external'
    recon_par.sense_os = [1 FOV_xy(1)/FOV_xy(2)];  %oversampling in x and y: control sense FOV
    recon_par.data_fn = data_fn;
    recon_par.sense_ref = sense_ref_fn;
    recon_par.coil_survey = coil_survey_fn;
    
    recon_par.time_segmented_recon_for_B0_inhomo = 1; %time segmented recon to compensate B0 inhomongneity; !!!time consuming!!!  
    recon_par.time_segments.nr_segments = 20; %more time segments more acurate; but recon times increases by a factor of time_segments
    recon_par.time_segments.aq_interval = 0.00576;  %AQ time interval in ms
    
    
    recon_par.channel_by_channel = 1;
    recon_par.channel_by_channel = recon_par.channel_by_channel .* (1-recon_par.sense_map_recon );
    %========================  END  =========================
     if(~exist('nav_sense_map', 'var')&&recon_par.sense_map_recon)
        recon_par.update_SENSE_map = 1;
     end
    
     %% sense map
    if(recon_par.update_SENSE_map)
        [nav_sense_map, nav_sense_Psi] = calc_sense_map(recon_par.data_fn, recon_par.sense_ref,  recon_par.coil_survey, recon_par.recon_dim,recon_par.sense_calc_method, recon_par.sense_os);
        %compress sense map and sense_Psi
        if(exist('Nav_VirtualCoilMartix','var'))
            if(~isempty(Nav_VirtualCoilMartix))
                [nav_sense_map, nav_sense_Psi] = compress_sense_map_Psi(Nav_VirtualCoilMartix, nav_sense_map, nav_sense_Psi);
            end
        end
    end
    
    if(recon_par.sense_map_recon == 0)
        nav_sense_map = ones([recon_par.recon_dim ch_nr]);
    end
    nav_sense_map = normalize_sense_map(nav_sense_map);
    
    
    
    if(~exist('nav_sense_Psi','var'))
        nav_sense_Psi = [];
    end
    
    %% recon
    if(recon_par.time_segmented_recon_for_B0_inhomo)
        nav_im_recon_nufft_1dyn = NUFFT_3D_recon_time_segments(nav_k_spa_data,trj_mat_fn,recon_par, b0_maps, nav_sense_map, nav_sense_Psi,offcenter_xy, FOV_xy);
    else
        nav_im_recon_nufft_1dyn = NUFFT_3D_recon(nav_k_spa_data,trj_mat_fn,recon_par, nav_sense_map, nav_sense_Psi,offcenter_xy, FOV_xy);
    end
    
    %% save 
    nav_im_recon_nufft(:,:,:,:,:,dyn) = nav_im_recon_nufft_1dyn;
    save(save_mat_fn, 'nav_im_recon_nufft','-append'); 
    
    
    elaps_t=toc;
    msg = sprintf(['SoSNav recon finishted for {', data_fn,'} ; ...dynamic %d ; duration %f; s', 10, 'Saved as ', save_mat_fn],d, elaps_t);
    sendmail_from_yahoo('q.zhang@amc.nl','Matlab Message',msg);
end

% -----display------------

% nav_sense_map = circshift(nav_sense_map, round(17.26/115.00*size(nav_sense_map,1)));
% nav_im_recon_nufft = circshift(nav_im_recon_nufft, -1*round(17.26/115.00*size(nav_sense_map,1)));
dyn = 2;
figure(801); immontage4D(angle(squeeze(nav_im_recon_nufft(:,:,:,:,:,dyn))),[-pi pi]); colormap jet; 
figure(802); immontage4D(abs(squeeze(nav_im_recon_nufft(:,:,:,:,:,dyn))),[]); 
phase_diff = angle(squeeze(bsxfun(@times,  nav_im_recon_nufft, exp(-1i*angle(nav_im_recon_nufft(:,:,:,1,1,:))))));
figure(803); immontage4D(squeeze(phase_diff(:,:,:,:,dyn)),[-pi pi]); colormap jet;

if(recon_par.channel_by_channel)
    nav_im_ch_by_ch = nav_im_recon_nufft_1dyn;
end

if(exist('nav_sense_map','var')&&exist('nav_im_ch_by_ch','var'))
    figure(804); 
    slice1=ceil(size(nav_im_ch_by_ch,3)/2);
    slice2=ceil(size(nav_sense_map,3)/2);
    subplot(121); montage(abs(nav_im_ch_by_ch(:,:,slice1,:)),'displayrange',[]); title('Check if they are match!'); xlabel('channel-by-channel');
    subplot(122); montage(abs(nav_sense_map(:,:,slice2,:)),'displayrange',[]); xlabel('sense');
end


disp('-finished- ');

%% TSE data sorting and default recon
close all; clc
disp(' TSE data sorting and default recon...')

parameter2read.dyn = [];

[ima_k_spa_data,TSE.ky_matched,TSE.kz_matched,TSE.shot_matched, TSE.ch_dim,ima_kspa_sorted, ima_default_recon, TSE_sense_map, TSE.kxrange, TSE.kyrange, TSE.kzrange, TSE.VirtualCoilMartix] = ...
    TSE_data_sortting(data_fn, sense_ref_fn, coil_survey_fn,parameter2read);

figure(610); immontage4D(permute(abs(ima_default_recon(:,:,:,:)),[1 2 4 3]), []);

TSE
assert(length(TSE.ky_matched)==size(ima_k_spa_data,2),'Profile number does not match with data size!')
disp('-finished- ');

%% TSE data non-rigid phase error correction (iterative) CG_SENSE
save_mat_fn = 'Sc03.mat';

nav_data = reshape(nav_im_recon_nufft, size(nav_im_recon_nufft,1), size(nav_im_recon_nufft, 2), size(nav_im_recon_nufft, 3), max(TSE.shot_matched));

TSE.SENSE_kx =1;
TSE.SENSE_ky =2;
TSE.SENSE_kz =1;

% TSE.kxrange = [-352 -1]; %consider now the ima_k_spa_data is oversampled in kx; kx oversmapled by 2 + 
TSE.kxrange = [-512 -1]; %consider now the ima_k_spa_data is oversampled in kx; kx oversmapled by 2 + 


TSE.Ixrange = [ceil(TSE.kxrange(1).*TSE.SENSE_kx) -1];
TSE.Iyrange = [ceil(TSE.kyrange(1).*TSE.SENSE_ky) -1];
TSE.Izrange = [ceil(TSE.kzrange(1).*TSE.SENSE_kz) -1];
TSE.kyrange = TSE.Iyrange;
TSE.kzrange = TSE.Izrange;

TSE.dyn_dim = dyn_nr;


%parameters for DPsti_TSE_phase_error_cor

pars.sense_map = 'external';  % external or ecalib 
pars.data_fn = data_fn;
pars.sense_ref = sense_ref_fn;
pars.coil_survey = coil_survey_fn;
pars.nav_phase_sm_kernel = 3;  %3 or 5, 1:no soomthing
pars.recon_x_locs = 120:400; %80:270;
pars.enabled_ch = 1:TSE.ch_dim;
pars.b0_shots = []; %[] means first dynamic


%paraemter for msDWIrecon called by DPsti_TSE_phase_error_cor
pars.msDWIrecon = initial_msDWIrecon_Pars;
pars.msDWIrecon.CG_SENSE_I.lamda=1e-2;
pars.msDWIrecon.CG_SENSE_I.nit=15;
pars.msDWIrecon.CG_SENSE_I.tol = 1e-10;
pars.msDWIrecon.POCS.Wsize = [15 15];  %no point to be bigger than navigator area
pars.msDWIrecon.POCS.nit = 50;
pars.msDWIrecon.POCS.tol = 1e-10;
pars.msDWIrecon.POCS.lamda = 1;
pars.msDWIrecon.POCS.nufft = false;

pars.msDWIrecon.method='CG_SENSE_I'; %POCS_ICE CG_SENSE_I CG_SENSE_K LRT

%------------sense mask calc----------%
os = [1, 1, 1];
dim = [range(TSE.Ixrange), range(TSE.Iyrange), range(TSE.Izrange) ]+1;
[sense_map_temp, TSE.sense_Psi] = get_sense_map_external(pars.sense_ref, pars.data_fn, pars.coil_survey, [dim(1)/2 dim(2) dim(3)], os);
%----compress sense map and sense_Psi
if(isfield(TSE, 'VirtualCoilMartix'))
    if(~isempty(TSE.VirtualCoilMartix))
        [sense_map_temp, TSE.sense_Psi] = compress_sense_map_Psi(TSE.VirtualCoilMartix, sense_map_temp,  TSE.sense_Psi);
    end
end
        
rs_command = sprintf('resize -c 0 %d', dim(1));
sense_map_temp = bart(rs_command, sense_map_temp);

TSE.sense_mask = abs(sense_map_temp(:,:,:,1 ))>0;
TSE_sense_map = sense_map_temp; %[]; %calc again using get_sense_map_external
clear sense_map_temp;    
%-------------------end---------------%

clear mr nav_im_recon_nufft nav_im_recon_nufft_1dyn nav_k_spa_data ima_kspa_sorted ima_default_recon



pars.large_scale_recon = true; % Choose to use DPsti_TSE_phase_error_cor_large_scale.m or DPsti_TSE_phase_error_cor.m
shot_per_dyn = max(TSE.shot_matched) / TSE.dyn_dim;
for d = 1:dyn_nr
    tic
    d
    
    pars.nonb0_shots = [1:shot_per_dyn] + (d-1)*shot_per_dyn;
    
    if(pars.large_scale_recon)
        result = DPsti_TSE_phase_error_cor_large_scale(ima_k_spa_data, TSE, TSE_sense_map, (nav_data), pars);
    else
        result = DPsti_TSE_phase_error_cor(ima_k_spa_data, TSE, TSE_sense_map, (nav_data), pars);
    end

    image_corrected(:,:,:,d)  = result;
     save(save_mat_fn,'image_corrected','-append');
     
     
     elaps_t=toc;
     msg = sprintf(['Recon finishted for {', data_fn,'} ; dynamic %d ; duration %f; s', 10, 'Saved as ', save_mat_fn],d, elaps_t); 
     sendmail_from_yahoo('q.zhang@amc.nl','Matlab Message',msg);
end
% TODO make DPsti_TSE_phase_error_cor for POCS_ICE option


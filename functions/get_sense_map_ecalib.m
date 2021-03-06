 function sens_map = get_sense_map_ecalib(fn, recon_dim )
       
    MR_TSEDPima_data = MRecon(fn);

    MR_TSEDPima_data_recon1 = MR_TSEDPima_data.Copy;

    MR_TSEDPima_data_recon1.Parameter.Parameter2Read.typ = 1;
    MR_TSEDPima_data_recon1.Parameter.Parameter2Read.mix = 0;  %for DPnav Spirals
    MR_TSEDPima_data_recon1.Parameter.Parameter2Read.dyn = 0; 
    MR_TSEDPima_data_recon1.ReadData;
    MR_TSEDPima_data_recon1.RandomPhaseCorrection;
    MR_TSEDPima_data_recon1.RemoveOversampling;
    MR_TSEDPima_data_recon1.PDACorrection;
    MR_TSEDPima_data_recon1.DcOffsetCorrection;
    MR_TSEDPima_data_recon1.MeasPhaseCorrection;
    MR_TSEDPima_data_recon1.SortData;
%     kspa_sorted = double(squeeze(MR_TSEDPima_data_recon1.Data));
    kspa_sorted = double(MR_TSEDPima_data_recon1.Data(:,:,:,:,1,1,1,1,1,1,1,1,1,1,1));
    
    che=create_checkerboard([1,size(kspa_sorted,2),size(kspa_sorted,3)]);
    kspa_sorted=bsxfun(@times,kspa_sorted,che);

    bart_command_1 = sprintf('resize -c 0 %d 1 %d 2 %d',recon_dim(1),recon_dim(2),recon_dim(3) )
    kspa_TSE_resize = bart(bart_command_1, kspa_sorted);
    
    ima = bart( 'fft -i 7', kspa_TSE_resize); size(ima);
    ima_rss = bart('rss 8',ima);
    figure(700); montage(permute(squeeze(abs(ima_rss)),[1 2 4 3]), 'displayrange',[]); title('images - kspace used for ecalib ')
    
    %shift?
%     FOV = MR_TSEDPima_data_recon1.Parameter.Labels.FOV;
%     recon_size = size(ima_rss);
%     offset = MR_TSEDPima_data_recon1.Parameter.Labels.Offcentre;
%     
%     cirshift_pix = offset./(FOV/recon_size);
    %
    
    sens=bart('ecalib -m1  -c0.1',kspa_TSE_resize);
    sens_map =  sens;
    figure(701);  montage(permute(squeeze(abs(sens_map(:,:,:,1))),[1 2 4 3]), 'displayrange',[]); title('sense maps: all slices, 1 channel ')
    figure(702);  immontage4D(abs(sens_map),[]); xlabel( 'channels'); ylabel('slice'); title('all sense maps')
        
 end
%BASED ON POCS-ICE paper by Guo Hua
%
%
% INPUT
% 
% x:                  currect image estimation in [ky kz]
% sense_map:          cpx sense maps in [ky kz n_coil]
% kspa_1shot:         cpx phase inhoerent k space data for 1 shot in [ky kz n_coil], it contain navigator info
% trj:                trajectory for k_spa. TODO
% 
% OUTPUT
% 
% px:                 Updated image estimation [ky kz]
%
% (c) q.zhang 2017 Amsterdam

function px = POCS_projection(x, sense_map, kspa_1shot, trj)

sx = bsxfun(@times, x, sense_map);
fsx = fft2d(sx);
fsx_diff = kspa_1shot - fsx;
sx_diff = ifft2d(fsx_diff);
spx = sx + sx_diff;


px = sum(conj(sense_map).*spx, 3)./sum(conj(sense_map).*sense_map, 3);

%TODO make fft2d to nufft2d using trj

end
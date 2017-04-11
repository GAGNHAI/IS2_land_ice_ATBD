function [H, D, params]=read_sim_ATL03(filename, pairs)

if ~exist('pairs','var')
    pairs=1:3;
end

beams=sort([2*pairs(:)-1; 2*pairs(:)]);


GT={'1','2','3'};
LR={'l','r'};

out_struct.geolocation=struct(...
    'segment_dist_x',[],...
    'segment_id', [], ...
    'surf_type', [], ...
    'ph_index_beg', [], ...
    'delta_time', [], ...
    'segment_ph_cnt', [], ...
    'sigma_across', [], ...
    'sigma_along', []);
out_struct.heights=struct(...
    'delta_time', [], ...
    'dist_ph_across', [], ...
    'dist_ph_along', [], ...
    'h_ph', [], ...
    'lat_ph', [], ...
    'lon_ph', [], ...
    'pce_mframe_cnt', [], ...
    'ph_id_count', [], ...
    'ph_id_pulse', [], ...
    'ph_id_channel',[], ...
    'signal_conf_ph', []);
out_struct.bckgrd_atlas=struct('bckgrd_rate', [],'pce_mframe_cnt',[]);

D=repmat(out_struct, [max(beams),1]);

%fprintf(1,'%s\n beam\t N_ph \t N_signal_conf_ph\n', filename);
for kT=pairs(:)'%length(GT)
    for kB=1:length(LR)
        beam=(kT-1)*2+kB;
        GT_grp=sprintf('/gt%s%s', GT{kT}, LR{kB});
        F0=fieldnames(out_struct);
        for k0=1:length(F0)
            F1=fieldnames(out_struct.(F0{k0}));
            for k1=1:length(F1)
                fieldName=[GT_grp,'/',F0{k0},'/', F1{k1}]; 
                D(beam).(F0{k0}).(F1{k1})=h5read(filename, fieldName);
            end
        end  
        D(beam).geolocation=index_struct(D(beam).geolocation, D(beam).geolocation.ph_index_beg ~=0);
        
        
         if strcmp(deblank(h5readatt(filename, GT_grp,'atlas_beam_type')),'strong')
            params(beam).N_det=16;
        else
            params(beam).N_det=4;
        end
        params(beam).RGT=h5read(filename,'/ancillary_data/start_rgt');
        params(beam).orbit=h5read(filename,'/ancillary_data/start_orbit');
        params(beam).cycle=h5read(filename,'/ancillary_data/start_cycle');
        params(beam).GT=beam;
        params(beam).spot_number=str2double(deblank(h5readatt(filename, GT_grp,'atlas_spot_number')));
        params(beam).PT=str2double(kT);
    end
end




for k=1:length(D) 
    H(k)=D(k).heights;
end

for beam=beams(:)' %length(D)
    % extract the ice-sheet column for the signal confidence
    H(beam).signal_conf_ph=D(beam).heights.signal_conf_ph(4,:)';
    
    [H(beam).ph_seg_num, ...
        H(beam).x_RGT, ...
        H(beam).seg_dist_x, ...
        H(beam).ph_seg_num, ...
        H(beam).BGR, ...
        H(beam).sigma_across, ...
        H(beam).sigma_along]=deal(NaN(size(D(beam).heights.h_ph)));
    for k=1:length(D(beam).geolocation.ph_index_beg);
        ind_range=D(beam).geolocation.ph_index_beg(k)+int64([0 D(beam).geolocation.segment_ph_cnt(k)-1]);
        if all(ind_range~=0)
            H(beam).ph_seg_num(ind_range(1):ind_range(2))=k;
        end
    end
    these=isfinite(H(beam).ph_seg_num);
    H(beam).seg_dist_x(these)=D(beam).geolocation.segment_dist_x(H(beam).ph_seg_num(these));
    H(beam).sigma_across(these)=D(beam).geolocation.sigma_across(H(beam).ph_seg_num(these));
    H(beam).sigma_along(these)=D(beam).geolocation.sigma_along(H(beam).ph_seg_num(these));
        
    H(beam).x_RGT(these)=D(beam).geolocation.segment_dist_x(H(beam).ph_seg_num(these))+H(beam).dist_ph_along(these);
    good=isfinite(H(beam).x_RGT) & H(beam).pce_mframe_cnt>0 & H(beam).pce_mframe_cnt < length(D(beam).bckgrd_atlas.bckgrd_rate);
    H(beam).BGR(good)=D(beam).bckgrd_atlas.bckgrd_rate(H(beam).pce_mframe_cnt(good));
    H(beam).pulse_num=200*double(H(beam).pce_mframe_cnt)+double(H(beam).ph_id_pulse);
    H(beam).beam=zeros(size(H(beam).h_ph))+beam;
    H(beam).h_ph=double(H(beam).h_ph);
end


if nargout>1
    for k=1:length(D)
        params(k).WF.t=h5read(filename,'/atlas_impulse_response/tep/beam_3/histogram/tep_hist_time');
        params(k).WF.p=h5read(filename,'/atlas_impulse_response/tep/beam_3/histogram/tep_hist');
    end
end

% example plot:

if false
    filename='/Volumes/ice1/ben/sdt/KTL03/ATL03forATL06version1b.h5';
     D=read_sim_ATL03(filename);
     for kB=1:2
        temp=D(kB).heights;
        temp=index_struct(temp, 1:100:length(temp.h_ph));
        figure(kB); clf; hold on; 
        for val=0:4
            els=temp.signal_conf_ph==val;
            plot(temp.x_RGT(els), temp.h_ph(els),'.');
        end
     end
     
end


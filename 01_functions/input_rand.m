function [sys_id,data_id] = input_rand(sys,options,e)
%%==================================%%
%%%         RANDOM INPUT           %%%
%%==================================%%

MC = options.MC;
T = options.T;
Ts = options.Ts;
method = options.method.rand;
interval = options.interval;
estimation = options.estimation;
init_param = options.init_param;

init_sys = idtf([0 0 NaN],[1 NaN(1,2)],1);
init_sys.Structure.Numerator.Free = [0 0 1];

na = length(sys.A) - 1;
nb = length(sys.B) - 1;
if strcmp(estimation,'true')
    data_id = cell(MC,1);
    sys_id = zeros(floor(T/interval-50/interval)+1,na+nb+2,MC);
elseif strcmp(estimation,'recursive')
    data_id = cell(1,1);
    sys_id = zeros(1,na+nb+2);
end

t_eval = interval:interval:T; % time steps, where parameters get estimated/evaluated

if strcmp(method,'prbs')
    u = idinput(T);
elseif strcmp(method,'wnoise')
    u = randn(T,1);
elseif strcmp(method,'chirp')
    t = 0:1/Ts:T-1/Ts;
    f0 = 0; % starting frequency [Hz]
    f1 = 1/2; % end frequency [Hz]
    u = chirp(t,f0,T,f1)';
elseif strcmp(method,'all')
    u = [idinput(T) randn(T,1)];
end
y = zeros(T,size(u,2));

for i = 1:MC
    idx = 1;
    if strcmp(estimation,'true') == true
        for k = 1:size(u,2)
            for j = max(na,nb)+1:T
                y(j) = sim_system(sys,u(j-1:-1:j-nb,k),y(j-1:-1:j-na,k),e(j,i));
                if any(t_eval(:) == j) && j >= 50
                    data_id{i,1} = iddata(y(1:j,k),u(1:j,k),1);
                    id_struct = oe(data_id{i,1},init_sys);
                    sys_id(idx,:,i) = [id_struct.B id_struct.F];
                    idx = idx + 1;
                end
            end
        end
    elseif strcmp(estimation,'recursive') == true
        B0 = init_param.B;
        A0 = init_param.A;
        obj_oe = recursiveOE([nb na 1],B0,A0);
        theta = [B0(2:end) A0(2:end)];
        calc_covar = zeros(1,length(theta));
        calc_covar(theta == 0) = 10^(-7); % assumed known system structure
        calc_covar(theta ~= 0) = 0.1;
        obj_oe.InitialParameterCovariance = diag(calc_covar);

        % u = idinput(T); % always use PRBS for inital estimation
        for j = max(na,nb)+1:T
            y(j) = sim_system(sys,u(j-1:-1:j-nb),y(j-1:-1:j-na),e(j,i));
            [B_id, F_id, ~] = step(obj_oe,y(j),u(j));

            if any(t_eval(:) == j) && j >= 50
                data_id{i,1} = iddata(y(1:j),u(1:j),1);
                sys_id(idx,:,i) = [B_id F_id];
                idx = idx + 1;
            end
        end
        reset(obj_oe)
    end
end
end

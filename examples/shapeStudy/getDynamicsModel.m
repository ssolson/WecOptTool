function dynModel = getDynamicsModel(hydro, SS, interpMethod, wdes)
    
    % Restoring
    K = hydro.C(3,3) * hydro.g * hydro.rho;

    function result = interp_mass(hydro, dof1, dof2, w)
        result = interp1(hydro.w,                           ...
                         squeeze(hydro.A(dof1, dof2, :)),   ...
                         w,                                 ...
                         interpMethod,                          ...
                         0);
    end

    function result = interp_rad(hydro, dof1, dof2, w)
        result = interp1(hydro.w,                           ...
                         squeeze(hydro.B(dof1, dof2, :)),   ...
                         w,                                 ...
                         interpMethod,                          ...
                         0);
    end

    function result = interp_ex(hydro, dof, w)

        h = squeeze(hydro.ex(dof, 1, :));
        result = interp1(hydro.w, h ,w, interpMethod, 0);

    end
    
    w = hydro.w(:);
    dw = w(2) - w(1);
    
    % Calculate wave amplitude
    waveAmpSS = SS.getAmplitudeSpectrum;
    waveAmp = interp1(SS.w, waveAmpSS, w, interpMethod, 'extrap');

    % Row vector of random phases
    ph = rand(size(waveAmp))*2*pi;

    % Wave height in frequency domain
    eta_fd = waveAmp .* exp(1i * ph);
    eta_fd = eta_fd(:);

    % radiation damping FRF
    B = interp_rad(hydro, 3, 3, w) * hydro.rho .* w;
%   B(:,ii) = squeeze(hydro.B(3,3,:)).*w'*rho;

    % added mass FRF
    A = interp_mass(hydro, 3, 3, w) * hydro.rho;
    Ainf = hydro.Ainf(3,3)*hydro.rho;

    % friction
    Bf = max(B) * 0.1;      % TODO - make this adjustable 

    % Tune device mass to desired natural frequency
    m = hydro.Vo * hydro.rho;
    fun = @(m) tune_wdes(wdes,m,K,w',A);
    mass = fminsearch(fun,m);
    
    % intrinsic impedance
    Zi = B + Bf + 1i * (w .* (mass + A) - K ./ w);

    % Excitation Forces
    Hex = interp_ex(hydro, 3, w) * hydro.g * hydro.rho;
    F0 = Hex .* eta_fd;   
    
    dynModel.mass = mass;
    dynModel.K = K;
    dynModel.w = w;
    dynModel.eta_fd = eta_fd;
    dynModel.dw = dw;
    dynModel.wave_amp = waveAmp;
    dynModel.ph = ph;
    dynModel.B = B;
    dynModel.A = A;
    dynModel.Ainf = Ainf;
    dynModel.Bf = Bf;
    dynModel.Zi = Zi;
    dynModel.Hex = Hex;
    dynModel.F0 = F0;
    
    
end

function [err] = tune_wdes(wdes,m,k,w,A)
    fun1 = @(w1) w1.^2.*(m + interp1(w,A,w1)) - k;
    options = optimset('Display','off');
    w0 = fsolve(fun1,5, options);
    err = (w0 - wdes).^2;
end
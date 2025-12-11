function [I, Q, theta, err, lp] = costas_loop(signal, fr, Fs, t, Kp, Ki, Kd, Ftype, Fmath)
    % Array Setup
    theta = zeros(1, length(signal));
    I = fi(zeros(1, length(signal)), Ftype, Fmath);
    Q = fi(zeros(1, length(signal)), Ftype, Fmath);
    I_ = fi(zeros(1, length(signal)), Ftype, Fmath);
    Q_ = fi(zeros(1, length(signal)), Ftype, Fmath);
    err = zeros(1, length(signal));
    
    % Design low-pass filter
    M = 7;
    lp = fi(designfilt('lowpassfir', 'FilterOrder', M, 'CutoffFrequency', 1.25e6, 'SampleRate', Fs).Coefficients, Ftype, Fmath);

    % Iterate from index M + 1 to the end of the array
    for k = (M + 1):length(signal)

        % Mix the signal with the sines and cosines
        I_(k) = signal(k) * fi(1 * cos(2 * pi * fr * t(k) + theta(k)), Ftype, Fmath);
        Q_(k) = signal(k) * fi(-1 * sin(2 * pi * fr * t(k) + theta(k)), Ftype, Fmath);
     
        % Lowpass with the previous M samples
        I_lowpassed = conv(lp, I_(k-M:k));
        Q_lowpassed = conv(lp, Q_(k-M:k));
        
        I(k) = I_lowpassed(M + 1);
        Q(k) = Q_lowpassed(M + 1);
        
        % Calculate the error at this sample point
        err(k) = I(k) * Q(k);
        
        % Update theta for next sample point
        theta(k+1) = theta(k) + Kp*err(k) + Ki*sum(err) + Kd*(err(k)-err(k-1));
    
    end
    lp = lp.';
end
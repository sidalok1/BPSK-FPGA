function [signal,gain,err] = AGC(signal, kp, gain_kp, ref, win)
%Automatic Gain Control
    gain = zeros(1, length(signal));
    err = zeros(1, length(signal));
    
    %interpolate gain values

    target_gain = 0;
    gain_err = zeros(1, length(signal));
    for k=2:length(signal)
        % Automatic Gain Control
        signal(k) = signal(k) * gain(k-1);

        gain_err(k) = target_gain - gain(k-1);
        gain(k) = gain(k-1) + (gain_err(k) * gain_kp);

        if (mod(k, win) == 0)
            energy = max(abs(signal(k-win+1:k)));
            err(k) = ref - energy;
            target_gain = target_gain + (kp * err(k));
        else
            err(k) = err(k-1);
        end
        
    end
    gain = gain(1:length(signal));
end
function [signal,gain,err] = AGC(signal, kp, ki, kd, ref, M)
%Automatic Gain Control
    gain = zeros(1, length(signal));
    err = zeros(1, length(signal));

    for k=(M+1):length(signal)
        % Automatic Gain Control
        signal(k) = signal(k) * gain(k);

        % err(k) = ref - (mean(abs(signal(k-M:k))));
        err(k) = ref - abs(signal(k));
        gain(k+1) = gain(k) + (kp * err(k)) + (ki * sum(err(k-M:k))) + (kd * (err(k)-err(k-1)));
        
    end
    gain = gain(1:length(signal));
end
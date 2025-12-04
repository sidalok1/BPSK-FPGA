function [downsampled, tau] = my_downsample(input, sps, kp, ki, kd)
    %MY_DOWNSAMPLE Iterative downsampling
    %   Makes use of early-late timing error detection
    input_length = length(input);
    output_length = floor(input_length / sps);
    downsampled = zeros(1, output_length);
    tau = zeros(1, output_length);
    err = zeros(1, output_length);
    for i = 1:output_length
        prompt_i = 2 + floor((i - 1 + tau(i)) * sps);
        late_i = prompt_i + 1;
        early_i = prompt_i - 1;

        if late_i > input_length
            downsampled = downsampled(1:i-1);
            tau = tau(1:i-1);
            break
        end
        
        downsampled(i) = input(prompt_i);
        
        err(i) = sign(input(prompt_i)) * (input(late_i) - input(early_i));
        proportional = kp * err(i);
        integral = ki * sum(err(max(1, i-200):i));
        if i ~= 1
            derivative = kd * (err(i)-(err(i-1)));
        else
            derivative = 0;
        end
        tau(i+1) = tau(i) + proportional + integral + derivative;
    end
end
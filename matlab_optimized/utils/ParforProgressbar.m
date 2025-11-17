classdef ParforProgressbar < handle
    % PARFORPROGRESSBAR Progress bar for parfor loops
    %
    % Simple progress bar that works with parfor loops using DataQueue
    %
    % Usage:
    %   ppm = ParforProgressbar(N, 'Title', 'Processing');
    %   parfor i = 1:N
    %       % ... do work ...
    %       ppm.increment();
    %   end
    %   delete(ppm);
    %
    % Author: Optimized Golf Swing Analysis System
    % Date: 2025

    properties (Access = private)
        Queue
        Total
        Current
        StartTime
        Title
        UpdateInterval
        LastUpdate
    end

    methods
        function obj = ParforProgressbar(total, varargin)
            % Constructor
            p = inputParser;
            addRequired(p, 'total', @isnumeric);
            addParameter(p, 'Title', 'Progress', @ischar);
            addParameter(p, 'UpdateInterval', 0.1, @isnumeric);
            parse(p, total, varargin{:});

            obj.Total = total;
            obj.Current = 0;
            obj.Title = p.Results.Title;
            obj.UpdateInterval = p.Results.UpdateInterval;
            obj.StartTime = tic;
            obj.LastUpdate = 0;

            % Create DataQueue for parallel communication
            obj.Queue = parallel.pool.DataQueue;
            afterEach(obj.Queue, @(~) obj.updateProgress());

            % Display initial progress
            obj.displayProgress();
        end

        function increment(obj, ~)
            % Increment progress counter
            send(obj.Queue, true);
        end

        function delete(obj)
            % Destructor - display final progress
            obj.displayProgress();
            fprintf('\n');
        end
    end

    methods (Access = private)
        function updateProgress(obj)
            % Update progress counter and display
            obj.Current = obj.Current + 1;

            % Only update display at specified intervals
            elapsed = toc(obj.StartTime);
            if elapsed - obj.LastUpdate >= obj.UpdateInterval || ...
               obj.Current == obj.Total
                obj.displayProgress();
                obj.LastUpdate = elapsed;
            end
        end

        function displayProgress(obj)
            % Display progress bar
            percent = obj.Current / obj.Total * 100;
            elapsed = toc(obj.StartTime);

            % Estimate remaining time
            if obj.Current > 0
                rate = obj.Current / elapsed;
                remaining = (obj.Total - obj.Current) / rate;
                eta_str = sprintf('ETA: %s', obj.formatTime(remaining));
            else
                eta_str = 'ETA: --:--';
            end

            % Create progress bar
            bar_length = 40;
            filled = round(bar_length * obj.Current / obj.Total);
            bar = ['[' repmat('=', 1, filled) repmat(' ', 1, bar_length - filled) ']'];

            % Display
            fprintf('\r   %s %s %3.0f%% (%d/%d) | %s | Elapsed: %s', ...
                obj.Title, bar, percent, obj.Current, obj.Total, ...
                eta_str, obj.formatTime(elapsed));
        end

        function str = formatTime(~, seconds)
            % Format time duration as HH:MM:SS
            hours = floor(seconds / 3600);
            minutes = floor(mod(seconds, 3600) / 60);
            secs = floor(mod(seconds, 60));

            if hours > 0
                str = sprintf('%02d:%02d:%02d', hours, minutes, secs);
            else
                str = sprintf('%02d:%02d', minutes, secs);
            end
        end
    end
end

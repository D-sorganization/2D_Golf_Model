classdef checkpoint_manager < handle
    % CHECKPOINT_MANAGER - Manage checkpoints for long-running analyses
    %
    % This class provides checkpointing functionality to save and resume
    % analysis pipeline execution, preventing data loss from failures.
    %
    % Usage:
    %   cm = checkpoint_manager(config);
    %   cm.save('stage_name', data_struct);
    %   [success, data] = cm.load('stage_name');
    %   cm.clear_all();
    %
    % Author: Optimized Golf Swing Analysis System
    % Date: 2025

    properties (Access = private)
        config
        cache_dir
        enabled
    end

    methods
        function obj = checkpoint_manager(config)
            % Constructor
            obj.config = config;
            obj.cache_dir = config.cache_path;
            obj.enabled = config.enable_checkpoints;

            % Create cache directory if it doesn't exist
            if obj.enabled && ~exist(obj.cache_dir, 'dir')
                mkdir(obj.cache_dir);
            end
        end

        function save(obj, stage_name, data_struct)
            % Save checkpoint for a specific stage
            if ~obj.enabled
                return;
            end

            checkpoint_file = obj.get_checkpoint_path(stage_name);

            try
                save(checkpoint_file, '-struct', 'data_struct', '-v7.3');
                if obj.config.verbose
                    fprintf('   💾 Checkpoint saved: %s\n', stage_name);
                end
            catch ME
                warning('Failed to save checkpoint %s: %s', stage_name, ME.message);
            end
        end

        function [success, data] = load(obj, stage_name)
            % Load checkpoint for a specific stage
            success = false;
            data = struct();

            if ~obj.enabled
                return;
            end

            checkpoint_file = obj.get_checkpoint_path(stage_name);

            if exist(checkpoint_file, 'file')
                try
                    data = load(checkpoint_file);
                    success = true;
                    if obj.config.verbose
                        fprintf('   📂 Checkpoint loaded: %s\n', stage_name);
                    end
                catch ME
                    warning('Failed to load checkpoint %s: %s', stage_name, ME.message);
                end
            end
        end

        function exists = has_checkpoint(obj, stage_name)
            % Check if checkpoint exists for a stage
            if ~obj.enabled
                exists = false;
                return;
            end

            checkpoint_file = obj.get_checkpoint_path(stage_name);
            exists = exist(checkpoint_file, 'file') == 2;
        end

        function clear(obj, stage_name)
            % Clear a specific checkpoint
            if ~obj.enabled
                return;
            end

            checkpoint_file = obj.get_checkpoint_path(stage_name);
            if exist(checkpoint_file, 'file')
                delete(checkpoint_file);
                if obj.config.verbose
                    fprintf('   🗑️  Checkpoint cleared: %s\n', stage_name);
                end
            end
        end

        function clear_all(obj)
            % Clear all checkpoints
            if ~obj.enabled
                return;
            end

            checkpoint_files = dir(fullfile(obj.cache_dir, 'checkpoint_*.mat'));
            for i = 1:length(checkpoint_files)
                delete(fullfile(obj.cache_dir, checkpoint_files(i).name));
            end

            if obj.config.verbose
                fprintf('   🗑️  All checkpoints cleared\n');
            end
        end

        function list_checkpoints(obj)
            % List all available checkpoints
            if ~obj.enabled
                fprintf('Checkpointing is disabled\n');
                return;
            end

            checkpoint_files = dir(fullfile(obj.cache_dir, 'checkpoint_*.mat'));

            if isempty(checkpoint_files)
                fprintf('No checkpoints found\n');
            else
                fprintf('Available checkpoints:\n');
                for i = 1:length(checkpoint_files)
                    file_info = dir(fullfile(obj.cache_dir, checkpoint_files(i).name));
                    fprintf('  %s (%.2f MB, %s)\n', ...
                        checkpoint_files(i).name, ...
                        file_info.bytes / 1024 / 1024, ...
                        datestr(file_info.datenum));
                end
            end
        end
    end

    methods (Access = private)
        function filepath = get_checkpoint_path(obj, stage_name)
            % Get full path for checkpoint file
            filename = sprintf('checkpoint_%s.mat', stage_name);
            filepath = fullfile(obj.cache_dir, filename);
        end
    end
end

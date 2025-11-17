function [BASE, ZTCF, DELTA, BASEQ, ZTCFQ, DELTAQ] = process_data_tables(config, BaseData, ZTCFData)
% PROCESS_DATA_TABLES - Synchronize and process BASE, ZTCF, and DELTA tables
%
% Inputs:
%   config - Configuration structure from simulation_config()
%   BaseData - Raw baseline simulation data
%   ZTCFData - Raw ZTCF simulation data
%
% Returns:
%   BASE, ZTCF, DELTA - Processed tables at base sample time (0.0001s)
%   BASEQ, ZTCFQ, DELTAQ - Q-tables at coarser sample time (0.0025s) for plotting
%
% This function performs the critical data synchronization and processing:
%   1. Time synchronization via interpolation
%   2. DELTA calculation (BASE - ZTCF)
%   3. Resampling to uniform time grids
%   4. Generation of Q-tables for plotting
%
% The synchronization is necessary because ZTCF data is sparse (29 points)
% while BASE data is dense (thousands of points at 0.0001s intervals).
%
% Author: Optimized Golf Swing Analysis System
% Date: 2025

    if config.verbose
        fprintf('⚙️  Processing and synchronizing data tables...\n');
    end

    %% Step 1: Convert to timetables for interpolation
    if config.verbose
        fprintf('   Converting to timetables...\n');
    end

    % Generate duration times
    BaseDataTime = seconds(BaseData.Time);
    ZTCFTime = seconds(ZTCFData.Time);

    % Create temporary tables with duration column
    BaseDataTemp = BaseData;
    ZTCFTemp = ZTCFData;
    BaseDataTemp.t = BaseDataTime;
    ZTCFTemp.t = ZTCFTime;

    % Convert to timetables
    BaseDataTimetable = table2timetable(BaseDataTemp, 'RowTimes', 't');
    ZTCFTimetable = table2timetable(ZTCFTemp, 'RowTimes', 't');

    % Remove redundant Time variable
    BaseDataTimetable = removevars(BaseDataTimetable, 'Time');
    ZTCFTimetable = removevars(ZTCFTimetable, 'Time');

    %% Step 2: Interpolate BASE data to match ZTCF time points
    if config.verbose
        fprintf('   Interpolating BASE data to ZTCF time points...\n');
    end
    BaseDataMatched = retime(BaseDataTimetable, ZTCFTime, config.interpolation_method);

    %% Step 3: Calculate DELTA (BASE - ZTCF)
    if config.verbose
        fprintf('   Calculating DELTA (active component)...\n');
    end
    DELTATimetable = BaseDataMatched - ZTCFTimetable;

    %% Step 4: Resample all to uniform timesteps
    if config.verbose
        fprintf('   Resampling to uniform timestep (%.4f s)...\n', config.base_sample_time);
    end

    BASEUniform = retime(BaseDataMatched, 'regular', config.interpolation_method, ...
        'TimeStep', seconds(config.base_sample_time));
    ZTCFUniform = retime(ZTCFTimetable, 'regular', config.interpolation_method, ...
        'TimeStep', seconds(config.base_sample_time));
    DELTAUniform = retime(DELTATimetable, 'regular', config.interpolation_method, ...
        'TimeStep', seconds(config.base_sample_time));

    %% Step 5: Convert back to regular tables
    if config.verbose
        fprintf('   Converting back to regular tables...\n');
    end

    BASE = timetable2table(BASEUniform, 'ConvertRowTimes', true);
    BASE = renamevars(BASE, 't', 'Time');

    ZTCF = timetable2table(ZTCFUniform, 'ConvertRowTimes', true);
    ZTCF = renamevars(ZTCF, 't', 'Time');

    DELTA = timetable2table(DELTAUniform, 'ConvertRowTimes', true);
    DELTA = renamevars(DELTA, 't', 'Time');

    %% Step 6: Convert time back from duration to numeric
    BASE.Time = seconds(BASE.Time);
    ZTCF.Time = seconds(ZTCF.Time);
    DELTA.Time = seconds(DELTA.Time);

    %% Step 7: Create Q-tables for plotting (coarser time resolution)
    if config.verbose
        fprintf('   Creating Q-tables for plotting (%.4f s resolution)...\n', ...
            config.q_sample_time);
    end

    BASEQ = resample_table_to_q(BASE, config);
    ZTCFQ = resample_table_to_q(ZTCF, config);
    DELTAQ = resample_table_to_q(DELTA, config);

    if config.verbose
        fprintf('✅ Data tables processed successfully\n');
        fprintf('   BASE:  %d rows × %d variables\n', height(BASE), width(BASE));
        fprintf('   ZTCF:  %d rows × %d variables\n', height(ZTCF), width(ZTCF));
        fprintf('   DELTA: %d rows × %d variables\n', height(DELTA), width(DELTA));
        fprintf('   Q-tables: %d rows each\n', height(BASEQ));
    end

end

function Q_table = resample_table_to_q(input_table, config)
    % Resample table to Q resolution for plotting

    % Convert to timetable
    time_duration = seconds(input_table.Time);
    temp_table = input_table;
    temp_table.t = time_duration;
    tt = table2timetable(temp_table, 'RowTimes', 't');
    tt = removevars(tt, 'Time');

    % Resample to Q resolution
    tt_q = retime(tt, 'regular', config.interpolation_method, ...
        'TimeStep', seconds(config.q_sample_time));

    % Convert back to table
    Q_table = timetable2table(tt_q, 'ConvertRowTimes', true);
    Q_table = renamevars(Q_table, 't', 'Time');
    Q_table.Time = seconds(Q_table.Time);

end

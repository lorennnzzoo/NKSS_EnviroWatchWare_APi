--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-02-18 10:03:36

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 25175)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 296 (class 1255 OID 33518)
-- Name: GetAggregatedChannelDataWithIds(timestamp without time zone, timestamp without time zone, integer[], integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."GetAggregatedChannelDataWithIds"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) RETURNS TABLE(aggregation_time timestamp without time zone, dynamic_columns jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    channel_query TEXT;
BEGIN
    -- Construct the query to aggregate data based on the interval
    channel_query := '
        WITH 
        -- Generate time buckets based on the interval
        time_buckets AS (
            SELECT DISTINCT 
                generate_series(
                    date_trunc(''minute'', $2::timestamp), -- Start time truncated to minute
                    date_trunc(''minute'', $3::timestamp), -- End time truncated to minute
                    ($4 || '' minutes'')::interval         -- Interval in minutes
                ) AS bucket_start
        ),
        -- Get all channels in the specified list with their station and logging units
        channels AS (
            SELECT 
                c."Id", 
                c."Name", 
                c."LoggingUnits",
                s."Name" AS station_name
            FROM public."Channel" c
            INNER JOIN public."Station" s ON c."StationId" = s."Id"
            WHERE c."Id" = ANY($1)
        ),
        -- Join data and aggregate by the buckets
        aggregated_data AS (
            SELECT 
                t.bucket_start AS aggregation_time,
                ch."Id" AS channel_id,
                AVG(
                    COALESCE(
                        pgp_sym_decrypt(cd."ChannelValue"::bytea, ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'')::FLOAT, 
                        NULL
                    )
                ) AS avg_value
            FROM 
                time_buckets t
            CROSS JOIN channels ch
            LEFT JOIN public."ChannelData" cd 
                ON cd."ChannelDataLogTime" >= t.bucket_start 
                AND cd."ChannelDataLogTime" < t.bucket_start + ($4 || '' minutes'')::interval
                AND ch."Id" = cd."ChannelId"
            GROUP BY 
                t.bucket_start, ch."Id"
        )
        -- Format the aggregated data as JSONB
        SELECT 
            ad.aggregation_time,
            jsonb_object_agg(
                CONCAT(ch.station_name, ''-'', ch."Name", ''-'', ch."LoggingUnits"), -- Format: S.Name-C.Name-C.LoggingUnits
                COALESCE(ad.avg_value::TEXT, ''NA'')
            ) AS dynamic_columns
        FROM 
            aggregated_data ad
        INNER JOIN channels ch ON ad.channel_id = ch."Id"
        GROUP BY 
            ad.aggregation_time
        ORDER BY 
            ad.aggregation_time;
    ';

    -- Execute the query and return the result
    RETURN QUERY EXECUTE channel_query USING channel_ids, start_time, end_time, interval_minutes;
END;
$_$;


ALTER FUNCTION public."GetAggregatedChannelDataWithIds"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) OWNER TO postgres;

--
-- TOC entry 298 (class 1255 OID 33524)
-- Name: GetAvgChannelDataExceedanceReport(timestamp without time zone, timestamp without time zone, integer[], integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."GetAvgChannelDataExceedanceReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) RETURNS TABLE(channeldatalogtime timestamp without time zone, dynamic_columns jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    channel_query TEXT;
BEGIN
    -- Construct the query to aggregate data based on the interval and channel type logic
    channel_query := '
        WITH 
        -- Generate time buckets based on the interval
        time_buckets AS (
            SELECT DISTINCT 
                generate_series(
                    date_trunc(''hour'', $2::timestamp),  -- Truncate start time to the nearest hour
                    date_trunc(''hour'', $3::timestamp),  -- Truncate end time to the nearest hour
                    ($4 || '' minutes'')::interval        -- Interval in minutes
                ) AS bucket_start
        ),
        -- Get all channels in the specified list with their station and logging units
        channels AS (
            SELECT 
                c."Id", 
                c."Name", 
                c."LoggingUnits",
                s."Name" AS station_name,
                ct."ChannelTypeValue",
                o."Limit" AS oxide_limit
            FROM public."Channel" c
            INNER JOIN public."Station" s ON c."StationId" = s."Id"
            INNER JOIN public."ChannelType" ct ON c."ChannelTypeId" = ct."Id"
            LEFT JOIN public."Oxide" o ON c."OxideId" = o."Id"
            WHERE c."Id" = ANY($1)
        ),
        -- Aggregate data based on channel type and time buckets
        aggregated_data AS (
            SELECT 
                t.bucket_start AS ChannelDataLogTime,  -- Change to ChannelDataLogTime
                ch."Id" AS channel_id,
                -- Apply the specific aggregation based on ChannelTypeValue
                CASE 
                    WHEN UPPER(ch."ChannelTypeValue") = ''VECTOR'' THEN 
                        AVG(SIN(RADIANS(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                           ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)))) 
                    WHEN UPPER(ch."ChannelTypeValue") = ''VECTOR'' THEN 
                        AVG(COS(RADIANS(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                           ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)))) 
                    WHEN UPPER(ch."ChannelTypeValue") = ''TOTAL'' THEN 
                        ROUND(MAX(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)) - 
                                  MIN(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)), 2)
                    WHEN UPPER(ch."ChannelTypeValue") = ''FLOW'' THEN 
                        ROUND(SUM(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)), 2)
                    ELSE 
                        AVG(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                   ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)) 
                END AS avg_value,
                COUNT(*) AS record_count,
                ch.oxide_limit
            FROM 
                time_buckets t
            CROSS JOIN channels ch
            LEFT JOIN public."ChannelData" cd 
                ON cd."ChannelDataLogTime" >= t.bucket_start 
                AND cd."ChannelDataLogTime" < t.bucket_start + ($4 || '' minutes'')::interval
                AND ch."Id" = cd."ChannelId"
            GROUP BY 
                t.bucket_start, ch."Id", ch."ChannelTypeValue", ch.oxide_limit
        )
        -- Format the aggregated data as JSONB
        SELECT 
            ad.ChannelDataLogTime,  -- Change to ChannelDataLogTime
            jsonb_object_agg(
                CONCAT(ch.station_name, ''-'', ch."Name", ''-'', ch."LoggingUnits"), -- Format: S.Name-C.Name-C.LoggingUnits
                jsonb_build_object(
                    ''avg_value'', COALESCE(ad.avg_value::TEXT, ''NA''),
                    ''Exceeded'', 
                    CASE 
                        WHEN ad.avg_value > CAST(ad.oxide_limit AS numeric) THEN  -- Cast oxide_limit to numeric
                            true
                        ELSE 
                            false
                    END
                )
            ) AS dynamic_columns
        FROM 
            aggregated_data ad
        INNER JOIN channels ch ON ad.channel_id = ch."Id"
        GROUP BY 
            ad.ChannelDataLogTime  -- Change to ChannelDataLogTime
        ORDER BY 
            ad.ChannelDataLogTime;  -- Change to ChannelDataLogTime
    ';

    -- Execute the query and return the result
    RETURN QUERY EXECUTE channel_query USING channel_ids, start_time, end_time, interval_minutes;
END;
$_$;


ALTER FUNCTION public."GetAvgChannelDataExceedanceReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) OWNER TO postgres;

--
-- TOC entry 297 (class 1255 OID 33521)
-- Name: GetAvgChannelDataReport(timestamp without time zone, timestamp without time zone, integer[], integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."GetAvgChannelDataReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) RETURNS TABLE(channeldatalogtime timestamp without time zone, dynamic_columns jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    channel_query TEXT;
BEGIN
    -- Construct the query to aggregate data based on the interval and channel type logic
    channel_query := '
        WITH 
        -- Generate time buckets based on the interval
        time_buckets AS (
            SELECT DISTINCT 
                generate_series(
                    date_trunc(''hour'', $2::timestamp),  -- Truncate start time to the nearest hour
                    date_trunc(''hour'', $3::timestamp),  -- Truncate end time to the nearest hour
                    ($4 || '' minutes'')::interval        -- Interval in minutes
                ) AS bucket_start
        ),
        -- Get all channels in the specified list with their station and logging units
        channels AS (
            SELECT 
                c."Id", 
                c."Name", 
                c."LoggingUnits",
                s."Name" AS station_name,
                ct."ChannelTypeValue"
            FROM public."Channel" c
            INNER JOIN public."Station" s ON c."StationId" = s."Id"
            INNER JOIN public."ChannelType" ct ON c."ChannelTypeId" = ct."Id"
            WHERE c."Id" = ANY($1)
        ),
        -- Aggregate data based on channel type and time buckets
        aggregated_data AS (
            SELECT 
                t.bucket_start AS ChannelDataLogTime,  -- Change to ChannelDataLogTime
                ch."Id" AS channel_id,
                -- Apply the specific aggregation based on ChannelTypeValue
                CASE 
                    WHEN UPPER(ch."ChannelTypeValue") = ''VECTOR'' THEN 
                        AVG(SIN(RADIANS(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                           ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)))) 
                    WHEN UPPER(ch."ChannelTypeValue") = ''VECTOR'' THEN 
                        AVG(COS(RADIANS(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                           ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)))) 
                    WHEN UPPER(ch."ChannelTypeValue") = ''TOTAL'' THEN 
                        ROUND(MAX(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)) - 
                                  MIN(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)), 2)
                    WHEN UPPER(ch."ChannelTypeValue") = ''FLOW'' THEN 
                        ROUND(SUM(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                       ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)), 2)
                    ELSE 
                        AVG(CAST(pgp_sym_decrypt(cd."ChannelValue"::bytea, 
                                                   ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'') AS numeric)) 
                END AS avg_value,
                COUNT(*) AS record_count
            FROM 
                time_buckets t
            CROSS JOIN channels ch
            LEFT JOIN public."ChannelData" cd 
                ON cd."ChannelDataLogTime" >= t.bucket_start 
                AND cd."ChannelDataLogTime" < t.bucket_start + ($4 || '' minutes'')::interval
                AND ch."Id" = cd."ChannelId"
            GROUP BY 
                t.bucket_start, ch."Id", ch."ChannelTypeValue"
        )
        -- Format the aggregated data as JSONB
        SELECT 
            ad.ChannelDataLogTime,  -- Change to ChannelDataLogTime
            jsonb_object_agg(
                CONCAT(ch.station_name, ''-'', ch."Name", ''-'', ch."LoggingUnits"), -- Format: S.Name-C.Name-C.LoggingUnits
                COALESCE(ad.avg_value::TEXT, ''NA'')
            ) AS dynamic_columns
        FROM 
            aggregated_data ad
        INNER JOIN channels ch ON ad.channel_id = ch."Id"
        GROUP BY 
            ad.ChannelDataLogTime  -- Change to ChannelDataLogTime
        ORDER BY 
            ad.ChannelDataLogTime;  -- Change to ChannelDataLogTime
    ';

    -- Execute the query and return the result
    RETURN QUERY EXECUTE channel_query USING channel_ids, start_time, end_time, interval_minutes;
END;
$_$;


ALTER FUNCTION public."GetAvgChannelDataReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[], interval_minutes integer) OWNER TO postgres;

--
-- TOC entry 295 (class 1255 OID 33491)
-- Name: GetRawChannelDataReport(timestamp without time zone, timestamp without time zone, integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."GetRawChannelDataReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[]) RETURNS TABLE(channeldatalogtime timestamp without time zone, dynamic_columns jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    channel_query TEXT;
BEGIN
    -- Construct the query to generate a grid of timestamps and channels
    channel_query := '
        WITH 
        -- Get all distinct timestamps in the range
        timestamps AS (
            SELECT DISTINCT "ChannelDataLogTime"
            FROM public."ChannelData"
            WHERE "ChannelDataLogTime" >= $2
              AND "ChannelDataLogTime" <= $3
        ),
        -- Get all channels in the specified list with their station and logging units
        channels AS (
            SELECT 
                c."Id", 
                c."Name", 
                c."LoggingUnits",
                s."Name" AS station_name
            FROM public."Channel" c
            
            INNER JOIN public."Station" s ON c."StationId" = s."Id"
            WHERE c."Id" = ANY($1)
        )
        -- Cross join timestamps and channels to create a grid
        SELECT 
            t."ChannelDataLogTime",
            jsonb_object_agg(
                CONCAT(ch.station_name, ''-'', ch."Name", ''-'', ch."LoggingUnits"), -- Format: S.Name-C.Name-C.LoggingUnits
                COALESCE(
                    pgp_sym_decrypt(cd."ChannelValue"::bytea, ''abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_-+=<>?'')::FLOAT::TEXT, 
                    ''NA''
                )
            ) AS dynamic_columns
        FROM 
            timestamps t
            CROSS JOIN channels ch
            LEFT JOIN public."ChannelData" cd 
                ON t."ChannelDataLogTime" = cd."ChannelDataLogTime"
                AND ch."Id" = cd."ChannelId"
        GROUP BY 
            t."ChannelDataLogTime"
        ORDER BY 
            t."ChannelDataLogTime";
    ';

    -- Execute the query and return the result
    RETURN QUERY EXECUTE channel_query USING channel_ids, start_time, end_time;
END;
$_$;


ALTER FUNCTION public."GetRawChannelDataReport"(start_time timestamp without time zone, end_time timestamp without time zone, channel_ids integer[]) OWNER TO postgres;

--
-- TOC entry 294 (class 1255 OID 25212)
-- Name: InsertOrUpdateChannelDataFeed(integer, numeric, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."InsertOrUpdateChannelDataFeed"(p_channelid integer, p_channelvalue numeric, p_datetime timestamp without time zone, p_pass_phrase character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_channeldataid INTEGER;
    v_channelname character varying;
    v_chnlunits character varying;
    v_stationid integer;
    v_active boolean;
    v_min NUMERIC(10,2);
    v_max NUMERIC(10,2);
    v_avg NUMERIC(10,2);
    v_pcbstandard character varying;  
    v_outputtype character varying;  
    v_scalingfactorid integer;  
    v_mininput NUMERIC;
    v_maxinput NUMERIC;
    v_minoutput NUMERIC;
    v_maxoutput NUMERIC;
    v_conversionfactor NUMERIC;
    v_threshold NUMERIC;
    v_minrange NUMERIC;
    v_maxrange NUMERIC;
    v_finalvalue NUMERIC;
BEGIN
	p_datetime := date_trunc('minute', p_datetime);
    -- Get the Channel details (Name, Units, StationId, Active, OutputType, ScalingFactorId, ConversionFactor)
    SELECT 
        ch."Name", 
        ch."LoggingUnits", 
        ch."StationId", 
        ch."Active", 
        ch."OutputType", 
        ch."ScalingFactorId", 
        ch."ConversionFactor", 
        ch."Threshold", 
        ch."MinimumRange", 
        ch."MaximumRange",
        sf."MinInput", 
        sf."MaxInput", 
        sf."MinOutput", 
        sf."MaxOutput"
    INTO 
        v_channelname, v_chnlunits, v_stationid, v_active, 
        v_outputtype, v_scalingfactorid, v_conversionfactor, 
        v_threshold, v_minrange, v_maxrange, 
        v_mininput, v_maxinput, v_minoutput, v_maxoutput
    FROM "Channel" ch
    LEFT JOIN "ScalingFactor" sf ON ch."ScalingFactorId" = sf."Id"
    WHERE ch."Id" = p_channelid;

    -- Determine the final value based on OutputType
    IF v_outputtype = 'DIGITAL' THEN
        -- For Digital type, no scaling needed, just apply ConversionFactor
        v_finalvalue := p_channelvalue * v_conversionfactor;

        -- Threshold check for Digital value
        IF v_threshold IS NOT NULL AND v_finalvalue > v_threshold THEN
            -- Generate a random value between MinRange and MaxRange for Digital
            v_finalvalue := v_minrange + (random() * (v_maxrange - v_minrange));
        END IF;
        
    ELSIF v_outputtype = 'ANALOG' THEN
        -- For Analog type, apply linear scaling based on ScalingFactorId
        v_finalvalue := v_minoutput + ((p_channelvalue - v_mininput) * (v_maxoutput - v_minoutput) / (v_maxinput - v_mininput));


		 -- Ensure v_finalvalue is within min and max bounds
	    IF v_finalvalue < v_minoutput THEN
	        v_finalvalue := v_minoutput;
	    ELSIF v_finalvalue > v_maxoutput THEN
	        v_finalvalue := v_maxoutput;
	    END IF;


		-- Apply the conversion factor
        v_finalvalue := v_finalvalue * v_conversionfactor;

		
        -- Threshold check for Analog value (after scaling)
        IF v_threshold IS NOT NULL AND v_finalvalue > v_threshold THEN
            -- Generate a random value between MinRange and MaxRange for Analog
            v_finalvalue := v_minrange + (random() * (v_maxrange - v_minrange));
        END IF;
    END IF;
	v_finalvalue := ROUND(v_finalvalue, 2);
    -- Insert into ChannelData
    INSERT INTO "ChannelData"(
        "ChannelId", "ChannelValue", "ChannelDataLogTime", "Active", "Processed"
    ) 
    VALUES (
        p_channelid, 
        pgp_sym_encrypt(v_finalvalue::TEXT, p_pass_phrase),  -- Encryption
        p_datetime, 
        v_active, 
        FALSE
    ) RETURNING "Id" INTO v_channeldataid;
    
    IF v_channeldataid > 0 THEN
        -- Delete existing records in ContemporaryChannelData
        DELETE FROM "ChannelDataFeed" WHERE "ChannelId" = p_channelid;
        
        -- Calculate min, max, avg of the last hour's data
        SELECT 
            MIN(CAST(pgp_sym_decrypt("ChannelValue", p_pass_phrase) AS NUMERIC)) INTO v_min
        FROM "ChannelData"
        WHERE "ChannelId" = p_channelid 
          AND "ChannelDataLogTime" >= (p_datetime - INTERVAL '1 hour');
        
        SELECT 
            MAX(CAST(pgp_sym_decrypt("ChannelValue", p_pass_phrase) AS NUMERIC)) INTO v_max
        FROM "ChannelData"
        WHERE "ChannelId" = p_channelid 
          AND "ChannelDataLogTime" >= (p_datetime - INTERVAL '1 hour');
        
        SELECT 
            AVG(CAST(pgp_sym_decrypt("ChannelValue", p_pass_phrase) AS NUMERIC)) INTO v_avg
        FROM "ChannelData"
        WHERE "ChannelId" = p_channelid 
          AND "ChannelDataLogTime" >= (p_datetime - INTERVAL '1 hour');
        
        -- Retrieve PcbLimit (standard) from the Oxide table using the oxideid from the Channel table
        SELECT o."Limit" 
        INTO v_pcbstandard
        FROM "Channel" ch
        JOIN "Oxide" o ON ch."OxideId" = o."Id"
        WHERE ch."Id" = p_channelid;
        
        -- Insert into ContemporaryChannelData (ChannelDataFeed)
        INSERT INTO "ChannelDataFeed"(
            "ChannelDataId", "ChannelId", "ChannelName", "ChannelValue", "Units", 
            "ChannelDataLogTime", "PcbLimit", "StationId", "Active", 
            "Minimum", "Maximum", "Average"
        )
        VALUES (
            v_channeldataid,
            p_channelid,
            v_channelname,  -- ChannelName from Channel table
            v_finalvalue,  -- Final computed value
            v_chnlunits,  -- Units from Channel table
            p_datetime,
            v_pcbstandard,  -- PcbLimit (standard) from Oxide
            v_stationid,  -- StationId from Channel table
            v_active,  -- Active from Channel table
            v_min,
            v_max,
            v_avg
        );
    END IF;
END;
$$;


ALTER FUNCTION public."InsertOrUpdateChannelDataFeed"(p_channelid integer, p_channelvalue numeric, p_datetime timestamp without time zone, p_pass_phrase character varying) OWNER TO postgres;

--
-- TOC entry 293 (class 1255 OID 33490)
-- Name: create_partition_if_needed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_partition_if_needed() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_year INT := EXTRACT(YEAR FROM CURRENT_TIMESTAMP)::INT;
    current_month INT := EXTRACT(MONTH FROM CURRENT_TIMESTAMP)::INT;
    current_day INT := EXTRACT(DAY FROM CURRENT_TIMESTAMP)::INT;
    current_hour INT := EXTRACT(HOUR FROM CURRENT_TIMESTAMP)::INT;
    partition_name TEXT;
BEGIN
    -- Check if the year partition exists, if not, create it
    partition_name := format('ChannelData_%s', current_year);
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename = partition_name) THEN
        EXECUTE format('CREATE TABLE public."%s" PARTITION OF public."ChannelData" FOR VALUES FROM (%s) TO (%s)', partition_name, current_year, current_year + 1);
    END IF;

    -- Check if the month partition exists, if not, create it
    partition_name := format('ChannelData_%s_%s', current_year, lpad(current_month::text, 2, '0'));
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename = partition_name) THEN
        EXECUTE format('CREATE TABLE public."%s" PARTITION OF public."ChannelData_%s" FOR VALUES FROM (%s) TO (%s)', partition_name, current_year, current_month, current_month + 1);
    END IF;

    -- Check if the day partition exists, if not, create it
    partition_name := format('ChannelData_%s_%s_%s', current_year, lpad(current_month::text, 2, '0'), lpad(current_day::text, 2, '0'));
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename = partition_name) THEN
        EXECUTE format('CREATE TABLE public."%s" PARTITION OF public."ChannelData_%s_%s" FOR VALUES FROM (%s) TO (%s)', partition_name, current_year, lpad(current_month::text, 2, '0'), current_day, current_day + 1);
    END IF;

    -- Check if the hour partition exists, if not, create it
    partition_name := format('ChannelData_%s_%s_%s_%s', current_year, lpad(current_month::text, 2, '0'), lpad(current_day::text, 2, '0'), lpad(current_hour::text, 2, '0'));
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename = partition_name) THEN
        EXECUTE format('CREATE TABLE public."%s" PARTITION OF public."ChannelData_%s_%s_%s" FOR VALUES FROM (%s) TO (%s)', partition_name, current_year, lpad(current_month::text, 2, '0'), lpad(current_day::text, 2, '0'), current_hour, current_hour + 1);
    END IF;
END;
$$;


ALTER FUNCTION public.create_partition_if_needed() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 225 (class 1259 OID 25058)
-- Name: Analyzer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Analyzer" (
    "Id" integer NOT NULL,
    "ProtocolType" character varying(100) NOT NULL,
    "Command" character varying(500),
    "ComPort" character varying(50),
    "BaudRate" integer,
    "Parity" character varying(10),
    "DataBits" integer,
    "StopBits" character varying(10),
    "IpAddress" character varying(100),
    "Port" integer,
    "Manufacturer" character varying(200),
    "Model" character varying(200),
    "Active" boolean DEFAULT true NOT NULL,
    "CommunicationType" character varying(10)
);


ALTER TABLE public."Analyzer" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 25057)
-- Name: Analyzer_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Analyzer_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Analyzer_Id_seq" OWNER TO postgres;

--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 224
-- Name: Analyzer_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Analyzer_Id_seq" OWNED BY public."Analyzer"."Id";


--
-- TOC entry 227 (class 1259 OID 25068)
-- Name: Channel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Channel" (
    "Id" integer NOT NULL,
    "StationId" integer NOT NULL,
    "Name" character varying(200) NOT NULL,
    "LoggingUnits" character varying(100) NOT NULL,
    "ProtocolId" integer NOT NULL,
    "Active" boolean DEFAULT true NOT NULL,
    "ValuePosition" integer,
    "MaximumRange" numeric(10,2),
    "MinimumRange" numeric(10,2),
    "Threshold" numeric(10,2),
    "CpcbChannelName" character varying(200),
    "SpcbChannelName" character varying(200),
    "OxideId" integer NOT NULL,
    "Priority" integer,
    "IsSpcb" boolean DEFAULT false NOT NULL,
    "IsCpcb" boolean DEFAULT false NOT NULL,
    "ScalingFactorId" integer,
    "OutputType" character varying(10) NOT NULL,
    "ChannelTypeId" integer NOT NULL,
    "ConversionFactor" numeric(10,2) DEFAULT 1.00 NOT NULL,
    "CreatedOn" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Channel" OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 25143)
-- Name: ChannelData; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChannelData" (
    "Id" integer NOT NULL,
    "ChannelId" integer NOT NULL,
    "ChannelValue" bytea,
    "ChannelDataLogTime" timestamp without time zone NOT NULL,
    "Active" boolean,
    "Processed" boolean
);


ALTER TABLE public."ChannelData" OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 25157)
-- Name: ChannelDataFeed; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChannelDataFeed" (
    "Id" integer NOT NULL,
    "ChannelDataId" integer NOT NULL,
    "ChannelId" integer NOT NULL,
    "ChannelName" character varying(50),
    "ChannelValue" character varying(50),
    "Units" character varying(50),
    "ChannelDataLogTime" timestamp without time zone,
    "PcbLimit" character varying(50),
    "StationId" integer,
    "Active" boolean,
    "Minimum" numeric(10,2),
    "Maximum" numeric(10,2),
    "Average" numeric(10,2)
);


ALTER TABLE public."ChannelDataFeed" OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 25156)
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ChannelDataFeed_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."ChannelDataFeed_Id_seq" OWNER TO postgres;

--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 236
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ChannelDataFeed_Id_seq" OWNED BY public."ChannelDataFeed"."Id";


--
-- TOC entry 234 (class 1259 OID 25142)
-- Name: ChannelData_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ChannelData_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."ChannelData_Id_seq" OWNER TO postgres;

--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 234
-- Name: ChannelData_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ChannelData_Id_seq" OWNED BY public."ChannelData"."Id";


--
-- TOC entry 233 (class 1259 OID 25124)
-- Name: ChannelType; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChannelType" (
    "Id" integer NOT NULL,
    "ChannelTypeValue" character varying(15) NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."ChannelType" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 25067)
-- Name: Channel_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Channel_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Channel_Id_seq" OWNER TO postgres;

--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 226
-- Name: Channel_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Channel_Id_seq" OWNED BY public."Channel"."Id";


--
-- TOC entry 219 (class 1259 OID 25023)
-- Name: Company; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Company" (
    "Id" integer NOT NULL,
    "ShortName" character varying(100) NOT NULL,
    "LegalName" character varying(200) NOT NULL,
    "Address" character varying(500),
    "PinCode" character varying(50) NOT NULL,
    "Logo" bytea,
    "Active" boolean DEFAULT true NOT NULL,
    "Country" character varying(50) NOT NULL,
    "State" character varying(50) NOT NULL,
    "District" character varying(50) NOT NULL,
    "CreatedOn" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Company" OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 25022)
-- Name: Company_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Company_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Company_Id_seq" OWNER TO postgres;

--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 218
-- Name: Company_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Company_Id_seq" OWNED BY public."Company"."Id";


--
-- TOC entry 245 (class 1259 OID 33494)
-- Name: ConfigSetting; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ConfigSetting" (
    "Id" integer NOT NULL,
    "GroupName" character varying(100),
    "ContentName" character varying(100),
    "ContentValue" text,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."ConfigSetting" OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 25316)
-- Name: KeyGenerator; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."KeyGenerator" (
    "Id" integer NOT NULL,
    "KeyType" text NOT NULL,
    "KeyValue" integer NOT NULL,
    "LastUpdatedOn" timestamp without time zone
);


ALTER TABLE public."KeyGenerator" OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 25315)
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."KeyGenerator_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."KeyGenerator_Id_seq" OWNER TO postgres;

--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 242
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."KeyGenerator_Id_seq" OWNED BY public."KeyGenerator"."Id";


--
-- TOC entry 238 (class 1259 OID 25271)
-- Name: License; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."License" (
    "LicenseType" character varying(255) NOT NULL,
    "LicenseKey" text NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."License" OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 25098)
-- Name: MonitoringType; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."MonitoringType" (
    "Id" integer NOT NULL,
    "MonitoringTypeName" character varying(256) NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."MonitoringType" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 25033)
-- Name: Oxide; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Oxide" (
    "Id" integer NOT NULL,
    "OxideName" character varying(200) NOT NULL,
    "Limit" character varying(100),
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."Oxide" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 25032)
-- Name: Oxide_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Oxide_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Oxide_Id_seq" OWNER TO postgres;

--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 220
-- Name: Oxide_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Oxide_Id_seq" OWNED BY public."Oxide"."Id";


--
-- TOC entry 241 (class 1259 OID 25299)
-- Name: Roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Roles" (
    "Id" integer NOT NULL,
    "Name" character varying(100) NOT NULL,
    "Description" character varying(255),
    "Active" boolean DEFAULT true NOT NULL,
    "CreatedOn" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Roles" OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 25112)
-- Name: ScalingFactor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ScalingFactor" (
    "Id" integer NOT NULL,
    "MinInput" double precision NOT NULL,
    "MaxInput" double precision NOT NULL,
    "MinOutput" double precision NOT NULL,
    "MaxOutput" double precision NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."ScalingFactor" OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 25041)
-- Name: Station; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Station" (
    "Id" integer NOT NULL,
    "CompanyId" integer NOT NULL,
    "Name" character varying(200) NOT NULL,
    "IsSpcb" boolean DEFAULT false NOT NULL,
    "IsCpcb" boolean DEFAULT false NOT NULL,
    "Active" boolean DEFAULT true NOT NULL,
    "MonitoringTypeId" integer NOT NULL,
    "CreatedOn" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Station" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 25040)
-- Name: Station_Id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Station_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Station_Id_seq" OWNER TO postgres;

--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 222
-- Name: Station_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Station_Id_seq" OWNED BY public."Station"."Id";


--
-- TOC entry 239 (class 1259 OID 25278)
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    "Id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "Username" character varying(255) NOT NULL,
    "Password" character varying(255) NOT NULL,
    "PhoneNumber" character varying(20),
    "Email" character varying(255),
    "Active" boolean DEFAULT true,
    "CreatedOn" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "LastLoggedIn" timestamp without time zone,
    "RoleId" integer NOT NULL
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 25123)
-- Name: channeltype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.channeltype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.channeltype_id_seq OWNER TO postgres;

--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 232
-- Name: channeltype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.channeltype_id_seq OWNED BY public."ChannelType"."Id";


--
-- TOC entry 244 (class 1259 OID 33493)
-- Name: configsettings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configsettings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configsettings_id_seq OWNER TO postgres;

--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 244
-- Name: configsettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configsettings_id_seq OWNED BY public."ConfigSetting"."Id";


--
-- TOC entry 228 (class 1259 OID 25097)
-- Name: monitoringtype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.monitoringtype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.monitoringtype_id_seq OWNER TO postgres;

--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 228
-- Name: monitoringtype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.monitoringtype_id_seq OWNED BY public."MonitoringType"."Id";


--
-- TOC entry 240 (class 1259 OID 25298)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_id_seq OWNER TO postgres;

--
-- TOC entry 4991 (class 0 OID 0)
-- Dependencies: 240
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public."Roles"."Id";


--
-- TOC entry 230 (class 1259 OID 25111)
-- Name: scalingfactor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.scalingfactor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.scalingfactor_id_seq OWNER TO postgres;

--
-- TOC entry 4992 (class 0 OID 0)
-- Dependencies: 230
-- Name: scalingfactor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scalingfactor_id_seq OWNED BY public."ScalingFactor"."Id";


--
-- TOC entry 4762 (class 2604 OID 25061)
-- Name: Analyzer Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Analyzer" ALTER COLUMN "Id" SET DEFAULT nextval('public."Analyzer_Id_seq"'::regclass);


--
-- TOC entry 4764 (class 2604 OID 25071)
-- Name: Channel Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel" ALTER COLUMN "Id" SET DEFAULT nextval('public."Channel_Id_seq"'::regclass);


--
-- TOC entry 4776 (class 2604 OID 25146)
-- Name: ChannelData Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData" ALTER COLUMN "Id" SET DEFAULT nextval('public."ChannelData_Id_seq"'::regclass);


--
-- TOC entry 4777 (class 2604 OID 25160)
-- Name: ChannelDataFeed Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed" ALTER COLUMN "Id" SET DEFAULT nextval('public."ChannelDataFeed_Id_seq"'::regclass);


--
-- TOC entry 4774 (class 2604 OID 25127)
-- Name: ChannelType Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelType" ALTER COLUMN "Id" SET DEFAULT nextval('public.channeltype_id_seq'::regclass);


--
-- TOC entry 4752 (class 2604 OID 25026)
-- Name: Company Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Company" ALTER COLUMN "Id" SET DEFAULT nextval('public."Company_Id_seq"'::regclass);


--
-- TOC entry 4786 (class 2604 OID 33497)
-- Name: ConfigSetting Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConfigSetting" ALTER COLUMN "Id" SET DEFAULT nextval('public.configsettings_id_seq'::regclass);


--
-- TOC entry 4785 (class 2604 OID 25319)
-- Name: KeyGenerator Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."KeyGenerator" ALTER COLUMN "Id" SET DEFAULT nextval('public."KeyGenerator_Id_seq"'::regclass);


--
-- TOC entry 4770 (class 2604 OID 25101)
-- Name: MonitoringType Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MonitoringType" ALTER COLUMN "Id" SET DEFAULT nextval('public.monitoringtype_id_seq'::regclass);


--
-- TOC entry 4755 (class 2604 OID 25036)
-- Name: Oxide Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Oxide" ALTER COLUMN "Id" SET DEFAULT nextval('public."Oxide_Id_seq"'::regclass);


--
-- TOC entry 4782 (class 2604 OID 25302)
-- Name: Roles Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Roles" ALTER COLUMN "Id" SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 4772 (class 2604 OID 25115)
-- Name: ScalingFactor Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ScalingFactor" ALTER COLUMN "Id" SET DEFAULT nextval('public.scalingfactor_id_seq'::regclass);


--
-- TOC entry 4757 (class 2604 OID 25044)
-- Name: Station Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station" ALTER COLUMN "Id" SET DEFAULT nextval('public."Station_Id_seq"'::regclass);


--
-- TOC entry 4795 (class 2606 OID 25066)
-- Name: Analyzer Analyzer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Analyzer"
    ADD CONSTRAINT "Analyzer_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4807 (class 2606 OID 25162)
-- Name: ChannelDataFeed ChannelDataFeed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "ChannelDataFeed_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4805 (class 2606 OID 25150)
-- Name: ChannelData ChannelData_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData"
    ADD CONSTRAINT "ChannelData_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4797 (class 2606 OID 25081)
-- Name: Channel Channel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "Channel_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4789 (class 2606 OID 25031)
-- Name: Company Company_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Company"
    ADD CONSTRAINT "Company_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4815 (class 2606 OID 25323)
-- Name: KeyGenerator KeyGenerator_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."KeyGenerator"
    ADD CONSTRAINT "KeyGenerator_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4791 (class 2606 OID 25039)
-- Name: Oxide Oxide_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Oxide"
    ADD CONSTRAINT "Oxide_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4793 (class 2606 OID 25051)
-- Name: Station Station_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "Station_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4811 (class 2606 OID 25286)
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4803 (class 2606 OID 25129)
-- Name: ChannelType channeltype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelType"
    ADD CONSTRAINT channeltype_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4817 (class 2606 OID 33501)
-- Name: ConfigSetting configsettings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConfigSetting"
    ADD CONSTRAINT configsettings_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4809 (class 2606 OID 25296)
-- Name: License license_pKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."License"
    ADD CONSTRAINT "license_pKey" PRIMARY KEY ("LicenseType");


--
-- TOC entry 4799 (class 2606 OID 25103)
-- Name: MonitoringType monitoringtype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MonitoringType"
    ADD CONSTRAINT monitoringtype_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4813 (class 2606 OID 25306)
-- Name: Roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Roles"
    ADD CONSTRAINT roles_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4801 (class 2606 OID 25117)
-- Name: ScalingFactor scalingfactor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ScalingFactor"
    ADD CONSTRAINT scalingfactor_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4826 (class 2606 OID 25168)
-- Name: ChannelDataFeed FK_ChannelDataFeed_Channel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "FK_ChannelDataFeed_Channel" FOREIGN KEY ("ChannelId") REFERENCES public."Channel"("Id");


--
-- TOC entry 4827 (class 2606 OID 25163)
-- Name: ChannelDataFeed FK_ChannelDataFeed_ChannelData; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "FK_ChannelDataFeed_ChannelData" FOREIGN KEY ("ChannelDataId") REFERENCES public."ChannelData"("Id");


--
-- TOC entry 4825 (class 2606 OID 25151)
-- Name: ChannelData FK_ChannelData_Channel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData"
    ADD CONSTRAINT "FK_ChannelData_Channel" FOREIGN KEY ("ChannelId") REFERENCES public."Channel"("Id");


--
-- TOC entry 4820 (class 2606 OID 25082)
-- Name: Channel FK_Channel_Analyzer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Analyzer" FOREIGN KEY ("ProtocolId") REFERENCES public."Analyzer"("Id");


--
-- TOC entry 4821 (class 2606 OID 25130)
-- Name: Channel FK_Channel_ChannelType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_ChannelType" FOREIGN KEY ("ChannelTypeId") REFERENCES public."ChannelType"("Id") NOT VALID;


--
-- TOC entry 4822 (class 2606 OID 25087)
-- Name: Channel FK_Channel_Oxide; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Oxide" FOREIGN KEY ("OxideId") REFERENCES public."Oxide"("Id");


--
-- TOC entry 4823 (class 2606 OID 25118)
-- Name: Channel FK_Channel_ScalingFactor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_ScalingFactor" FOREIGN KEY ("ScalingFactorId") REFERENCES public."ScalingFactor"("Id") NOT VALID;


--
-- TOC entry 4824 (class 2606 OID 25092)
-- Name: Channel FK_Channel_Station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Station" FOREIGN KEY ("StationId") REFERENCES public."Station"("Id");


--
-- TOC entry 4818 (class 2606 OID 25052)
-- Name: Station FK_Station_Company; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "FK_Station_Company" FOREIGN KEY ("CompanyId") REFERENCES public."Company"("Id");


--
-- TOC entry 4819 (class 2606 OID 25104)
-- Name: Station FK_Station_MonitoringType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "FK_Station_MonitoringType" FOREIGN KEY ("MonitoringTypeId") REFERENCES public."MonitoringType"("Id") NOT VALID;


--
-- TOC entry 4828 (class 2606 OID 25307)
-- Name: User FK_User_Roles; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "FK_User_Roles" FOREIGN KEY ("RoleId") REFERENCES public."Roles"("Id") NOT VALID;


-- Completed on 2025-02-18 10:03:36

--
-- PostgreSQL database dump complete
--


--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-04-08 15:46:46

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
-- TOC entry 2 (class 3079 OID 37441)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 5027 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 3 (class 3079 OID 37478)
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- TOC entry 5028 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- TOC entry 302 (class 1255 OID 37499)
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
        pgp_sym_encrypt(v_finalvalue::TEXT, p_pass_phrase),  -- Store encrypted value
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
-- TOC entry 301 (class 1255 OID 37501)
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
-- TOC entry 222 (class 1259 OID 37502)
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
-- TOC entry 223 (class 1259 OID 37508)
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
-- TOC entry 5029 (class 0 OID 0)
-- Dependencies: 223
-- Name: Analyzer_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Analyzer_Id_seq" OWNED BY public."Analyzer"."Id";


--
-- TOC entry 224 (class 1259 OID 37509)
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
-- TOC entry 225 (class 1259 OID 37519)
-- Name: ChannelData; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChannelData" (
    "Id" integer NOT NULL,
    "ChannelId" integer NOT NULL,
    "ChannelDataLogTime" timestamp without time zone NOT NULL,
    "Active" boolean,
    "Processed" boolean,
    "ChannelValue" bytea
);


ALTER TABLE public."ChannelData" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 37522)
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
-- TOC entry 227 (class 1259 OID 37525)
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
-- TOC entry 5030 (class 0 OID 0)
-- Dependencies: 227
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ChannelDataFeed_Id_seq" OWNED BY public."ChannelDataFeed"."Id";


--
-- TOC entry 228 (class 1259 OID 37526)
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
-- TOC entry 5031 (class 0 OID 0)
-- Dependencies: 228
-- Name: ChannelData_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ChannelData_Id_seq" OWNED BY public."ChannelData"."Id";


--
-- TOC entry 229 (class 1259 OID 37527)
-- Name: ChannelType; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChannelType" (
    "Id" integer NOT NULL,
    "ChannelTypeValue" character varying(15) NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."ChannelType" OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 37531)
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
-- TOC entry 5032 (class 0 OID 0)
-- Dependencies: 230
-- Name: Channel_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Channel_Id_seq" OWNED BY public."Channel"."Id";


--
-- TOC entry 231 (class 1259 OID 37532)
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
-- TOC entry 232 (class 1259 OID 37539)
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
-- TOC entry 5033 (class 0 OID 0)
-- Dependencies: 232
-- Name: Company_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Company_Id_seq" OWNED BY public."Company"."Id";


--
-- TOC entry 233 (class 1259 OID 37540)
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
-- TOC entry 234 (class 1259 OID 37546)
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
-- TOC entry 235 (class 1259 OID 37551)
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
-- TOC entry 5034 (class 0 OID 0)
-- Dependencies: 235
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."KeyGenerator_Id_seq" OWNED BY public."KeyGenerator"."Id";


--
-- TOC entry 236 (class 1259 OID 37552)
-- Name: License; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."License" (
    "LicenseType" character varying(255) NOT NULL,
    "LicenseKey" text NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."License" OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 37558)
-- Name: MonitoringType; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."MonitoringType" (
    "Id" integer NOT NULL,
    "MonitoringTypeName" character varying(256) NOT NULL,
    "Active" boolean DEFAULT true NOT NULL
);


ALTER TABLE public."MonitoringType" OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 37972)
-- Name: NotificationHistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."NotificationHistory" (
    "Id" integer NOT NULL,
    "ChannelName" character varying(255) NOT NULL,
    "RaisedTime" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Message" text NOT NULL,
    "MetaData" text,
    "IsRead" boolean DEFAULT false NOT NULL,
    "ChannelId" integer NOT NULL,
    "ConditionId" uuid NOT NULL,
    "SentTime" timestamp without time zone
);


ALTER TABLE public."NotificationHistory" OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 37562)
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
-- TOC entry 239 (class 1259 OID 37566)
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
-- TOC entry 5035 (class 0 OID 0)
-- Dependencies: 239
-- Name: Oxide_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Oxide_Id_seq" OWNED BY public."Oxide"."Id";


--
-- TOC entry 240 (class 1259 OID 37567)
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
-- TOC entry 241 (class 1259 OID 37572)
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
-- TOC entry 242 (class 1259 OID 37576)
-- Name: ServiceLogs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ServiceLogs" (
    "LogId" integer NOT NULL,
    "LogType" character varying(10),
    "Message" text NOT NULL,
    "SoftwareType" character varying(50) NOT NULL,
    "Class" character varying(100) NOT NULL,
    "LogTimestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT servicelogs_logtype_check CHECK ((("LogType")::text = ANY (ARRAY[('INFO'::character varying)::text, ('WARN'::character varying)::text, ('ERROR'::character varying)::text])))
);


ALTER TABLE public."ServiceLogs" OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 37583)
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
-- TOC entry 244 (class 1259 OID 37590)
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
-- TOC entry 5036 (class 0 OID 0)
-- Dependencies: 244
-- Name: Station_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Station_Id_seq" OWNED BY public."Station"."Id";


--
-- TOC entry 245 (class 1259 OID 37591)
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
    "RoleId" integer NOT NULL,
    "IsEmailVerified" boolean DEFAULT false,
    "IsPhoneVerified" boolean DEFAULT false
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 37601)
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
-- TOC entry 5037 (class 0 OID 0)
-- Dependencies: 246
-- Name: channeltype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.channeltype_id_seq OWNED BY public."ChannelType"."Id";


--
-- TOC entry 247 (class 1259 OID 37602)
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
-- TOC entry 5038 (class 0 OID 0)
-- Dependencies: 247
-- Name: configsettings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configsettings_id_seq OWNED BY public."ConfigSetting"."Id";


--
-- TOC entry 248 (class 1259 OID 37603)
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
-- TOC entry 5039 (class 0 OID 0)
-- Dependencies: 248
-- Name: monitoringtype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.monitoringtype_id_seq OWNED BY public."MonitoringType"."Id";


--
-- TOC entry 252 (class 1259 OID 37971)
-- Name: notificationhistory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notificationhistory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notificationhistory_id_seq OWNER TO postgres;

--
-- TOC entry 5040 (class 0 OID 0)
-- Dependencies: 252
-- Name: notificationhistory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notificationhistory_id_seq OWNED BY public."NotificationHistory"."Id";


--
-- TOC entry 249 (class 1259 OID 37604)
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
-- TOC entry 5041 (class 0 OID 0)
-- Dependencies: 249
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public."Roles"."Id";


--
-- TOC entry 250 (class 1259 OID 37605)
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
-- TOC entry 5042 (class 0 OID 0)
-- Dependencies: 250
-- Name: scalingfactor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scalingfactor_id_seq OWNED BY public."ScalingFactor"."Id";


--
-- TOC entry 251 (class 1259 OID 37606)
-- Name: servicelogs_logid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.servicelogs_logid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.servicelogs_logid_seq OWNER TO postgres;

--
-- TOC entry 5043 (class 0 OID 0)
-- Dependencies: 251
-- Name: servicelogs_logid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.servicelogs_logid_seq OWNED BY public."ServiceLogs"."LogId";


--
-- TOC entry 4779 (class 2604 OID 37607)
-- Name: Analyzer Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Analyzer" ALTER COLUMN "Id" SET DEFAULT nextval('public."Analyzer_Id_seq"'::regclass);


--
-- TOC entry 4781 (class 2604 OID 37608)
-- Name: Channel Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel" ALTER COLUMN "Id" SET DEFAULT nextval('public."Channel_Id_seq"'::regclass);


--
-- TOC entry 4787 (class 2604 OID 37609)
-- Name: ChannelData Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData" ALTER COLUMN "Id" SET DEFAULT nextval('public."ChannelData_Id_seq"'::regclass);


--
-- TOC entry 4788 (class 2604 OID 37610)
-- Name: ChannelDataFeed Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed" ALTER COLUMN "Id" SET DEFAULT nextval('public."ChannelDataFeed_Id_seq"'::regclass);


--
-- TOC entry 4789 (class 2604 OID 37611)
-- Name: ChannelType Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelType" ALTER COLUMN "Id" SET DEFAULT nextval('public.channeltype_id_seq'::regclass);


--
-- TOC entry 4791 (class 2604 OID 37612)
-- Name: Company Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Company" ALTER COLUMN "Id" SET DEFAULT nextval('public."Company_Id_seq"'::regclass);


--
-- TOC entry 4794 (class 2604 OID 37613)
-- Name: ConfigSetting Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConfigSetting" ALTER COLUMN "Id" SET DEFAULT nextval('public.configsettings_id_seq'::regclass);


--
-- TOC entry 4796 (class 2604 OID 37614)
-- Name: KeyGenerator Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."KeyGenerator" ALTER COLUMN "Id" SET DEFAULT nextval('public."KeyGenerator_Id_seq"'::regclass);


--
-- TOC entry 4798 (class 2604 OID 37615)
-- Name: MonitoringType Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MonitoringType" ALTER COLUMN "Id" SET DEFAULT nextval('public.monitoringtype_id_seq'::regclass);


--
-- TOC entry 4819 (class 2604 OID 37975)
-- Name: NotificationHistory Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationHistory" ALTER COLUMN "Id" SET DEFAULT nextval('public.notificationhistory_id_seq'::regclass);


--
-- TOC entry 4800 (class 2604 OID 37616)
-- Name: Oxide Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Oxide" ALTER COLUMN "Id" SET DEFAULT nextval('public."Oxide_Id_seq"'::regclass);


--
-- TOC entry 4802 (class 2604 OID 37617)
-- Name: Roles Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Roles" ALTER COLUMN "Id" SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 4805 (class 2604 OID 37618)
-- Name: ScalingFactor Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ScalingFactor" ALTER COLUMN "Id" SET DEFAULT nextval('public.scalingfactor_id_seq'::regclass);


--
-- TOC entry 4807 (class 2604 OID 37619)
-- Name: ServiceLogs LogId; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ServiceLogs" ALTER COLUMN "LogId" SET DEFAULT nextval('public.servicelogs_logid_seq'::regclass);


--
-- TOC entry 4809 (class 2604 OID 37620)
-- Name: Station Id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station" ALTER COLUMN "Id" SET DEFAULT nextval('public."Station_Id_seq"'::regclass);


--
-- TOC entry 4824 (class 2606 OID 37622)
-- Name: Analyzer Analyzer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Analyzer"
    ADD CONSTRAINT "Analyzer_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4835 (class 2606 OID 37624)
-- Name: ChannelDataFeed ChannelDataFeed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "ChannelDataFeed_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4831 (class 2606 OID 37626)
-- Name: ChannelData ChannelData_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData"
    ADD CONSTRAINT "ChannelData_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4826 (class 2606 OID 37628)
-- Name: Channel Channel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "Channel_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4841 (class 2606 OID 37630)
-- Name: Company Company_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Company"
    ADD CONSTRAINT "Company_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4845 (class 2606 OID 37632)
-- Name: KeyGenerator KeyGenerator_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."KeyGenerator"
    ADD CONSTRAINT "KeyGenerator_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4851 (class 2606 OID 37634)
-- Name: Oxide Oxide_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Oxide"
    ADD CONSTRAINT "Oxide_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4860 (class 2606 OID 37636)
-- Name: Station Station_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "Station_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4862 (class 2606 OID 37638)
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY ("Id");


--
-- TOC entry 4839 (class 2606 OID 37640)
-- Name: ChannelType channeltype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelType"
    ADD CONSTRAINT channeltype_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4843 (class 2606 OID 37642)
-- Name: ConfigSetting configsettings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ConfigSetting"
    ADD CONSTRAINT configsettings_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4847 (class 2606 OID 37644)
-- Name: License license_pKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."License"
    ADD CONSTRAINT "license_pKey" PRIMARY KEY ("LicenseType");


--
-- TOC entry 4849 (class 2606 OID 37646)
-- Name: MonitoringType monitoringtype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."MonitoringType"
    ADD CONSTRAINT monitoringtype_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4864 (class 2606 OID 37980)
-- Name: NotificationHistory notificationhistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationHistory"
    ADD CONSTRAINT notificationhistory_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4853 (class 2606 OID 37648)
-- Name: Roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Roles"
    ADD CONSTRAINT roles_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4856 (class 2606 OID 37650)
-- Name: ScalingFactor scalingfactor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ScalingFactor"
    ADD CONSTRAINT scalingfactor_pkey PRIMARY KEY ("Id");


--
-- TOC entry 4858 (class 2606 OID 37652)
-- Name: ServiceLogs servicelogs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ServiceLogs"
    ADD CONSTRAINT servicelogs_pkey PRIMARY KEY ("LogId");


--
-- TOC entry 4827 (class 1259 OID 37653)
-- Name: idx_channel_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channel_id ON public."Channel" USING btree ("Id");


--
-- TOC entry 4828 (class 1259 OID 37654)
-- Name: idx_channel_oxideid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channel_oxideid ON public."Channel" USING btree ("OxideId");


--
-- TOC entry 4829 (class 1259 OID 37655)
-- Name: idx_channel_station; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channel_station ON public."Channel" USING btree ("StationId");


--
-- TOC entry 4832 (class 1259 OID 37656)
-- Name: idx_channeldata_channelid_logtime; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channeldata_channelid_logtime ON public."ChannelData" USING btree ("ChannelId", "ChannelDataLogTime");


--
-- TOC entry 4833 (class 1259 OID 37657)
-- Name: idx_channeldata_logtime; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channeldata_logtime ON public."ChannelData" USING btree ("ChannelDataLogTime");


--
-- TOC entry 4836 (class 1259 OID 37658)
-- Name: idx_channeldatafeed_channelid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channeldatafeed_channelid ON public."ChannelDataFeed" USING btree ("ChannelId");


--
-- TOC entry 4837 (class 1259 OID 37659)
-- Name: idx_channeldatafeed_station; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_channeldatafeed_station ON public."ChannelDataFeed" USING btree ("ChannelId", "StationId", "Active", "ChannelDataLogTime");


--
-- TOC entry 4854 (class 1259 OID 37660)
-- Name: idx_scalingfactor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scalingfactor_id ON public."ScalingFactor" USING btree ("Id");


--
-- TOC entry 4871 (class 2606 OID 37661)
-- Name: ChannelDataFeed FK_ChannelDataFeed_Channel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "FK_ChannelDataFeed_Channel" FOREIGN KEY ("ChannelId") REFERENCES public."Channel"("Id");


--
-- TOC entry 4872 (class 2606 OID 37666)
-- Name: ChannelDataFeed FK_ChannelDataFeed_ChannelData; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelDataFeed"
    ADD CONSTRAINT "FK_ChannelDataFeed_ChannelData" FOREIGN KEY ("ChannelDataId") REFERENCES public."ChannelData"("Id");


--
-- TOC entry 4870 (class 2606 OID 37671)
-- Name: ChannelData FK_ChannelData_Channel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChannelData"
    ADD CONSTRAINT "FK_ChannelData_Channel" FOREIGN KEY ("ChannelId") REFERENCES public."Channel"("Id");


--
-- TOC entry 4865 (class 2606 OID 37676)
-- Name: Channel FK_Channel_Analyzer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Analyzer" FOREIGN KEY ("ProtocolId") REFERENCES public."Analyzer"("Id");


--
-- TOC entry 4866 (class 2606 OID 37681)
-- Name: Channel FK_Channel_ChannelType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_ChannelType" FOREIGN KEY ("ChannelTypeId") REFERENCES public."ChannelType"("Id") NOT VALID;


--
-- TOC entry 4867 (class 2606 OID 37686)
-- Name: Channel FK_Channel_Oxide; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Oxide" FOREIGN KEY ("OxideId") REFERENCES public."Oxide"("Id");


--
-- TOC entry 4868 (class 2606 OID 37691)
-- Name: Channel FK_Channel_ScalingFactor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_ScalingFactor" FOREIGN KEY ("ScalingFactorId") REFERENCES public."ScalingFactor"("Id") NOT VALID;


--
-- TOC entry 4869 (class 2606 OID 37696)
-- Name: Channel FK_Channel_Station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Channel"
    ADD CONSTRAINT "FK_Channel_Station" FOREIGN KEY ("StationId") REFERENCES public."Station"("Id");


--
-- TOC entry 4876 (class 2606 OID 37981)
-- Name: NotificationHistory FK_NotificaitonHistory_Channel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationHistory"
    ADD CONSTRAINT "FK_NotificaitonHistory_Channel" FOREIGN KEY ("ChannelId") REFERENCES public."Channel"("Id") NOT VALID;


--
-- TOC entry 4873 (class 2606 OID 37701)
-- Name: Station FK_Station_Company; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "FK_Station_Company" FOREIGN KEY ("CompanyId") REFERENCES public."Company"("Id");


--
-- TOC entry 4874 (class 2606 OID 37706)
-- Name: Station FK_Station_MonitoringType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Station"
    ADD CONSTRAINT "FK_Station_MonitoringType" FOREIGN KEY ("MonitoringTypeId") REFERENCES public."MonitoringType"("Id") NOT VALID;


--
-- TOC entry 4875 (class 2606 OID 37711)
-- Name: User FK_User_Roles; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "FK_User_Roles" FOREIGN KEY ("RoleId") REFERENCES public."Roles"("Id") NOT VALID;


-- Completed on 2025-04-08 15:46:47

--
-- PostgreSQL database dump complete
--


--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-04-11 13:21:05

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
-- TOC entry 5060 (class 0 OID 0)
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
-- TOC entry 5061 (class 0 OID 0)
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
-- TOC entry 5062 (class 0 OID 0)
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
-- TOC entry 5063 (class 0 OID 0)
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
-- TOC entry 5064 (class 0 OID 0)
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
-- TOC entry 5065 (class 0 OID 0)
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
-- TOC entry 5066 (class 0 OID 0)
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
-- TOC entry 5067 (class 0 OID 0)
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
    "EmailSentTime" timestamp without time zone,
    "StationId" integer NOT NULL,
    "StationName" character varying NOT NULL,
    "MobileSentTime" timestamp without time zone,
    "SentEmailAddresses" character varying,
    "SentMobileAddresses" character varying,
    "ConditionType" character varying NOT NULL
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
-- TOC entry 5068 (class 0 OID 0)
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
-- TOC entry 5069 (class 0 OID 0)
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
-- TOC entry 5070 (class 0 OID 0)
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
-- TOC entry 5071 (class 0 OID 0)
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
-- TOC entry 5072 (class 0 OID 0)
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
-- TOC entry 5073 (class 0 OID 0)
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
-- TOC entry 5074 (class 0 OID 0)
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
-- TOC entry 5075 (class 0 OID 0)
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
-- TOC entry 5076 (class 0 OID 0)
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
-- TOC entry 5023 (class 0 OID 37502)
-- Dependencies: 222
-- Data for Name: Analyzer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Analyzer" ("Id", "ProtocolType", "Command", "ComPort", "BaudRate", "Parity", "DataBits", "StopBits", "IpAddress", "Port", "Manufacturer", "Model", "Active", "CommunicationType") FROM stdin;
1	RS485INTEGER	01 03 00 04 08 05 0c	COM3	9600	NONE	8	1	null	\N	Adam	Adam	t	C
\.


--
-- TOC entry 5025 (class 0 OID 37509)
-- Dependencies: 224
-- Data for Name: Channel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Channel" ("Id", "StationId", "Name", "LoggingUnits", "ProtocolId", "Active", "ValuePosition", "MaximumRange", "MinimumRange", "Threshold", "CpcbChannelName", "SpcbChannelName", "OxideId", "Priority", "IsSpcb", "IsCpcb", "ScalingFactorId", "OutputType", "ChannelTypeId", "ConversionFactor", "CreatedOn") FROM stdin;
1	1	PM10	mg/nm3	1	t	9	90.00	0.00	100.00	PM10	PM10	1	1	f	f	\N	DIGITAL	1	1.00	2025-04-04 11:44:00.122087
2	1	PM2.5	mg/nm3	1	t	9	50.00	0.00	60.00	PM2.5	PM2.5	2	2	f	f	\N	DIGITAL	1	1.00	2025-04-04 11:45:39.628523
3	2	Wind Speed	km/h	1	t	9	10.00	0.00	\N	Wind Speed	Wind Speed	3	3	f	f	\N	DIGITAL	1	1.00	2025-04-04 15:42:25.8995
4	2	Wind Direction	DegC	1	t	9	30.00	0.00	\N	Wind Direction	Wind Direction	4	4	f	f	\N	DIGITAL	2	1.00	2025-04-04 15:42:57.121207
5	1	SO2	mg/nm3	1	t	9	50.00	0.00	60.00	SO2	SO2	5	5	f	f	\N	DIGITAL	1	1.00	2025-04-08 10:38:53.813738
\.


--
-- TOC entry 5026 (class 0 OID 37519)
-- Dependencies: 225
-- Data for Name: ChannelData; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelData" ("Id", "ChannelId", "ChannelDataLogTime", "Active", "Processed", "ChannelValue") FROM stdin;
22	1	2020-01-01 00:00:00	t	f	\\xc30d04070302682340b5bd02f09b6cd236011c9aa152d6bf6a2cebff925bd979fcfaf50f10452abe388712d66dd1a1cfb220087776097ebea52e3e521b5a2ab32e163492fc876c
23	2	2020-01-01 00:00:00	t	f	\\xc30d04070302d7cb057c308ea65360d236012097629edc7f254157b1113a80350c7adf9718e2cd16f23c599484ed8fc0485a6c1546ba57ee749a3f5518b01eafaf8f0caa2d4449
24	3	2025-04-03 00:00:00	t	f	\\xc30d040703021124c345c22ff2ab7bd235013d9a8663f7b2a7226e2784f90349bc3c7153a09f5ccdc7089e1eec0f5538c287fc68666020b14e3c7a96a8d0c56c35fa5da5d1e3
25	4	2025-04-03 00:00:00	t	f	\\xc30d0407030246abfcf8f1b667b76ad23601079f9d1ff62504b5df7877c2417931f9dfda5343b04e214fb0df9ba491dc1e02229c69b219ba72c23287bc576f7bb3f8aea80a9cf4
26	3	2025-04-03 00:01:00	t	f	\\xc30d04070302cfe2a1dfb22454cd62d23501944fafa0c38e26928d1aa59bf4c659db9e9ec9a99ebbd8667213bc7a93186e77492a96081f9a05538949862c8e34a5141c935b13
27	4	2025-04-03 00:01:00	t	f	\\xc30d040703022858122709a85b5965d237018f04345927cff53331ecc9ca3bf6881809771e1540dd950879f8fb1c486f12661d333a23c69a04e0e03fb2ff7dc32024c03b203f94b3
28	3	2025-04-03 00:02:00	t	f	\\xc30d0407030204072c41bfefaa4f6ad23601a5b8aaacfd272463b77d310fe001f503a792a61941bee1a557d137895e8915d23cecc8c5c878745d6459d308ebeb510ed9632f47d8
29	4	2025-04-03 00:02:00	t	f	\\xc30d04070302d597b5890c7dd5037dd2370127f69292dd686b00b7959132d7a68ec9c026dada17f2efa4bb46a76fb31d5cefc2c42be4f4b66a7557b224c38b8be700aaaa4a82bbd2
30	3	2025-04-03 00:03:00	t	f	\\xc30d04070302b5020b20c84306cf63d23501645c5c099819a441540e771698a961ff6de1ff0aadf7e80d9538f5ddb097a2e8a235df9b240e75dea0d64872906e6dfeface298d
31	4	2025-04-03 00:03:00	t	f	\\xc30d040703029a2e90295e4564da72d2370163216874aa9edaff48c1bbbd8ff33b784cabc7d88ecfccfbdaff030e986b14d372030fa2ca2c12175fbec9a6d6730712d388843fd66a
32	3	2025-04-03 00:04:00	t	f	\\xc30d040703025abd9df4754c0fd960d2350185a6a7651872415aa8fcf2fecb11bab3a84096b7740cd1898a2299403e83839bd8dd7b57d99334e919f0e4fce0d65a735bcb733a
33	4	2025-04-03 00:04:00	t	f	\\xc30d04070302668dbeb8a46653ed79d2360102043cc2e1806afc9391a6b072811fe3f8c18578b83ae7bff07657796bdfa1a5eb456eec86f1d1523e83b16708d0263f7c743a807c
34	3	2025-04-03 00:05:00	t	f	\\xc30d040703022721a2f99ef2a80a76d236012ebbe10f25fb5f4a977c8b6d18b3c59f6315708905d2c89a75934676bc0f94ec88e75bbab2698f57dcc0400c4b64d1836e5256fa2b
35	4	2025-04-03 00:05:00	t	f	\\xc30d040703020c74905eb71014ac70d236011c3384f7f0844012af6e7dd614ed69d0e9bd9e4cdb090d531690475d30438a62620f374b60768bbe078a54eae75f8f64bd21b33b14
36	3	2025-04-03 00:06:00	t	f	\\xc30d0407030279acea32aaa588a765d235010114ed13550e7fcd28e62f805489b7d69dcc81769660aae6551338a3f47207faec11b8781b1d1af512f1896a340df0a377af13ff
37	4	2025-04-03 00:06:00	t	f	\\xc30d040703025b9858322a9dbb3175d23701a7e2d960ba54e4dfe8f5fc758f9a51e41a9ce899b91aec005c60ff7cbcfc8082f72c7d3bd0c7e6eec18e714096fa77a8c0f8cad0f8d6
38	3	2025-04-03 00:07:00	t	f	\\xc30d040703027fe0698e471d1a3173d2360147d820c5973d38a685cee73c81222594d062fc900236861cd9ca30cd4c6d245901180d9f8faeb6e583f29bd3664117e3bcb10494fb
39	4	2025-04-03 00:07:00	t	f	\\xc30d040703029be888e1fc0d98447ed2360131fa75c2824e686941ebe7706accdd76d9dd5fb39a46cfbd59cc49e6844f5517837e5f61acd30b7f57533764b5bab8377cd3a48c37
40	3	2025-04-03 00:08:00	t	f	\\xc30d04070302056318683862ec1b7cd23601113f99c892af56574dcafe5b25c56654d2533d16d972c41ee027c6e542ee6fa0a54d3c319f9f50637037b6c2d921f94c85a1f957d2
41	4	2025-04-03 00:08:00	t	f	\\xc30d04070302add422d19947942f67d237018f740f86d6db8f125437837f91675f9cf48f3beba5bd9a7a4b00a96e6fdd7399a2676def8a8796de543e9eb2bd286850978e87bdc6af
42	3	2025-04-03 00:09:00	t	f	\\xc30d04070302f78c9da516fb51787dd23501305ea12ffc62f4f76e841d92fff543bf505caf2aee025dfa32fc018364ff9d6a32777df8eb95eb497bec1c68ce1e9d133f77ae30
43	4	2025-04-03 00:09:00	t	f	\\xc30d04070302208056ff6df571c575d2370105f23b47a1fa7de3d4c3293e9778ec37600cc3777616c6799b154bfbb6364058efe83bb1530af2a880e96ea38f16ba9bff6b12945a14
44	3	2025-04-03 00:10:00	t	f	\\xc30d04070302c4ae8f66619efdad77d23601acfe039bda24219096598c0b503896691b9e856fa7f96cf3ea91327961c5dc185708cbdac5da3e56c3ef27d933fabf99c29e6db1ea
45	4	2025-04-03 00:10:00	t	f	\\xc30d04070302724904c8e9b8564366d2370114b6afab5888334535c3d88d85d081037a338819fefed8f61d431b363693e22ef36d063e0f285ede67bb2f833183363292ba6b1477a5
46	3	2025-04-03 00:11:00	t	f	\\xc30d04070302bd753d2acea42ac76ad23501ca4a17d79ca62c78f05ca86acffc4d295655d891f0148b1a6d2aee2ff9293b8413d3aba99d81127f6b882043173927f595d428d4
47	4	2025-04-03 00:11:00	t	f	\\xc30d040703021a5e564ba75c979575d237010f9bd94f48d32496c9c3b22430794c3e6b2ca7642ca3c9cb02b5aa4246e570ca6c8d647e19cf3b3c666a6acbd3b4fed6193f6e9d9b3a
48	3	2025-04-03 00:12:00	t	f	\\xc30d04070302ea32c035f11310237bd236017fc21701e55fd952dc5545e927d950ce50b328a14cccbc220b1e6499317bc823ec2b1ce676a89746855b368a8b3871abcfd0adb949
49	4	2025-04-03 00:12:00	t	f	\\xc30d04070302d1d827c72f98ae9261d23601a6a208db890c199524e1fe4c60b57e5219bdeedfb748bf3f223d95b4e78b707a82abec50753d2bae1d6d56f10e8b36f55ef226a5a9
50	3	2025-04-03 00:13:00	t	f	\\xc30d040703020ed84e35cd2d81e864d2350126c2b8d0b1dee5964e3c9a5859af66342fe11bd7af5996fabc33f66333e37b93fdad073be26b9bd87c4be18e902b29562f490669
51	4	2025-04-03 00:13:00	t	f	\\xc30d04070302dd7ebf064f567d147dd23701fae7c8fe24861a1b7ff9df1663757336c5f8bda4110ef6fc939939b7d7ca2cd10046e716bc56693d17599e1e23ac3420960b214438c5
52	3	2025-04-03 00:14:00	t	f	\\xc30d04070302faffa3c077ebb8d77fd23601d6d4052f5a265f953f0d38df2d20ab716e9e6b9e511a654efa7a4f03439ca8c638891eaa46075498887d07f6ad86a4d6b964192850
53	4	2025-04-03 00:14:00	t	f	\\xc30d040703022780392d7257945073d237010cb3bff36a4ec6abef66d7355bd39bc750cdfff215e5653c16f2147a13e0fb23cd78e4dbd66aacf4db56b21497ec57b6067482702465
54	3	2025-04-03 00:15:00	t	f	\\xc30d04070302166f3965305c7ee676d236013d14adf863d33c236b581c42f50a1ec6bdf67f509c71e85aed1a7883b3fec1d251daed17de61094087c9d5ec82c16f17834c83a443
55	4	2025-04-03 00:15:00	t	f	\\xc30d04070302f6463e9d95b4046562d23701d453654d1f66dda299b1624a8613822389903626ebdaee188c262772025f95f72e52a356daba0763270d5feb26a79f8940f7d26f030c
56	3	2025-04-03 00:16:00	t	f	\\xc30d04070302176b8004d75ea75162d23601c393b02b235e70260c5ad07c8d3eec2751a1fe68e1b27e04514679384b91073ae54cf2ff5f4a0c15d6aa5da821661bdaae5189eb15
57	4	2025-04-03 00:16:00	t	f	\\xc30d040703025a5041188a48a0ea61d23701300cd964fec7d80367cebd2fe3841b322bd7d1a588e6b0cc702959926fb37e527aacc861db84469b7d743cb1189effeb1f96d0e8d160
58	3	2025-04-03 00:17:00	t	f	\\xc30d04070302730f53f384d0889b7cd23601ac093d60b83a492d64096ccbfdf230b94899d7e0c44811d83ff5c7f1831018bc516c5415e52dd8f4026002c194424a09654943f564
59	4	2025-04-03 00:17:00	t	f	\\xc30d040703028418a11dd52f3d0b7bd2370145b1e45e7d8aa6c3428f1215bb75c09181b2ce826ff8bdcd84e90d265e428d312c3d8af2eb0f8c050ff78d9d8101361839abe03afc57
60	3	2025-04-03 00:18:00	t	f	\\xc30d040703022534ae777b6547d160d2360119b1503af8b53abcdd5d67f926e781fe990ff85abaf727464153b65de35479451a7520ca1f2521ade113f9b9c7cc0fe2068d5a5e66
61	4	2025-04-03 00:18:00	t	f	\\xc30d04070302ae3bdd3c5718b0b96cd2370179df8308444edd1f434cb2c80e0508a42958ac0796c85adafbd87b166b44565f4dc842f156a3bfc4d7e825e81861e18fc67b5b1a4937
62	3	2025-04-03 00:19:00	t	f	\\xc30d040703028279bf8c851db60076d23601013ce99ee566051c1bc3430fe8520ab1a4e31adecf431c260fbf127a34bf78d3b526aecb5bddc150a6dc182c3b6af650210701678a
63	4	2025-04-03 00:19:00	t	f	\\xc30d04070302050c15347206771265d237014fdd5a0d890bf6faab620e56604f86611ce2b46f559faf8601358fc22a1c1f622646bd30c81f099d7efd67cb54b734f487a1f4c06a6f
64	3	2025-04-03 00:20:00	t	f	\\xc30d0407030264192905f6c5db0f65d23501ec57cb806507cbf9382b1d6a777fb583a8f00ea59ae5fa799bf8356d7bec459294ddcbf988e79f6ff4797cbee7e3f2bbf520d7a9
65	4	2025-04-03 00:20:00	t	f	\\xc30d040703020a10bc32c7a7308664d2360106e6b758df750af823768042089cd2fc9545ad7c4704a4ef034345e555f684c49547ff94ef4464f7b2c951b76339f8cc88596eca16
66	3	2025-04-03 00:21:00	t	f	\\xc30d04070302448c0184e6f8943168d236018c6993b3d8a8ede1c6f15168fd2001571fad89962fca35035c821f44b5dcbbe3e0afdb1386a7f1f1381fa78e69b9e14f99aa4f3879
67	4	2025-04-03 00:21:00	t	f	\\xc30d0407030212814e1651824acf7fd23601e7daa22da8b142af7c25934947860e4f53864924ac6e7790b3d898f34170a7d2cc2436f3bed31dfde4b2f40135ace60adbc1abfd6f
68	3	2025-04-03 00:22:00	t	f	\\xc30d040703024b13c7c2dd79047960d235014deeef6750ccea1cad847cbb529617724d9f651502bb1b4811545e366acdce64820a26f4e14059649986cf4c531f69490d671b70
69	4	2025-04-03 00:22:00	t	f	\\xc30d04070302dbbc0d06a8c9db4f64d23601bb2e3a66cd01a11feae3cc8193b74e0260633fcc69bdf290db7c1f14cd28b610f70de5ad532e14a262c221bb1e291b19df8b0aa624
70	3	2025-04-03 00:23:00	t	f	\\xc30d0407030257ca3af032268dad75d23601a68b8948990d28f0e4bf761f7626a0865bc7207031500691c018c00bc2cade7055bcde18e0e32958b0480b9c6e271f2f2997f4672d
71	4	2025-04-03 00:23:00	t	f	\\xc30d040703029e12e263b04f722f78d2370131d332bdf252a10bc82e4dee092590d4f818f62c11983cee285b4a304535b3f7d4e76ad88273a6f9f3b389cf96a28e0bb7cd8bc60f54
72	3	2025-04-03 00:24:00	t	f	\\xc30d040703027c8ab205416b9e026ad236019caf4b0bb71aefd1f8d0ee4458f35ace38857f59c3854fc2d2a131b9f7241aab3d9c9c69d5ec7ef12827a19258c890c2679ee524f9
73	4	2025-04-03 00:24:00	t	f	\\xc30d040703020e19e27a9296ec267ed237018469f7de9ff6fc51968ac60444662039781fae7c706a9340099170e86d891c3e6201ac19d5031dcb29766b2fb9edbbdfe09cf6de86d7
74	3	2025-04-03 00:25:00	t	f	\\xc30d04070302738cdb31bf41ed187ad2350111f958752415820bbdb874e628ce5a1efe50d83d679e66038621a6ffb5cd0c4cef8aa5de77019919722440722782deb25c20928f
75	4	2025-04-03 00:25:00	t	f	\\xc30d040703026ddde1fb450986b76cd23601d165a288464a0fa8c40c4c6cef8092fa54fd256becb0df5b1b3c4cd4121cc4803df90995044503a5573a16fa48f4d5e2aa19aefeae
76	3	2025-04-03 00:26:00	t	f	\\xc30d0407030218063f57b1dde35561d23601615a127f57f17a8298ce4727eecbb37e5e23ac2d1d4d92ef4b2731134d0c2e15bd956e90a83ae06a5217f37978cc56782ba5f2664d
77	4	2025-04-03 00:26:00	t	f	\\xc30d04070302425a2f937824fe976dd23701b97dbbafb3278538b717aa647646f04e32e83acbff062914e59a5af0038b42b8700bc8a7599b4608858b14cf52cb831817ec9936d80a
78	3	2025-04-03 00:27:00	t	f	\\xc30d0407030213a0c06f1cf6f9bc70d236017747a8f0225bf7effb0bc2caba16385fdcaae021cc9110372cb13bdfcc7bb45325f9fcab36d7bf10b4618582e25cdeeb611bef9f07
79	4	2025-04-03 00:27:00	t	f	\\xc30d040703028a91dd4a880f5c3967d23601263d88fedf9b2380cd287f5f8b1db1afcf10868d5ccceb088257ef0ece74b73cf9e848c4abca22f853ae0367654babcf4908ffbaad
80	3	2025-04-03 00:28:00	t	f	\\xc30d04070302d3f04f23794de60875d2360186ea4dc155b16c43ad76608f1343c87b46d63fe728f672f86cdcc839f7163711a5c10650cea78a04ca8745039625fb600b1b55e0ad
81	4	2025-04-03 00:28:00	t	f	\\xc30d04070302568e7578bc4326666ad23601d37110af007029a9aac33bbf1e239603921e6be93988a4c446a560be3b16098a2c2de391d2801eb19f3d1f5e34d84f89b384919c6f
82	3	2025-04-03 00:29:00	t	f	\\xc30d0407030283c1d15365c46ab27dd23601aa503f7a87b749a21eed2dfaa32d4a51db5478cc8a80d3d5919f76e5c6a16b1dcb26ac54cfe99783bd137df8c93eba1b9ba18e92ed
83	4	2025-04-03 00:29:00	t	f	\\xc30d040703024495f0f7333ff04566d23701647754f84f1c0e806366e5bd6339743121d1aa403c235f521b744964d7de5b81dc97235e5b89afde53ca7fc65d50a3a380f3ecf190f8
84	3	2025-04-03 00:30:00	t	f	\\xc30d04070302e30b9d3bfda88f2c63d236010287d7cc5d861b160dd409bb561394e6c087ca8890acf5004c6240772b024ae1a1a1db2745b1f4db0df95eaa68717354ba2ba9695c
85	4	2025-04-03 00:30:00	t	f	\\xc30d040703029ba6ea64fc08b04f7fd2370115c9ac7fa26213f2393eb3325c3d3876ece0f911be73d7490d1d052d13f3329ac8eb48c541c9f0e817a4f4fe43aac88cf8a17279c198
86	3	2025-04-03 00:31:00	t	f	\\xc30d0407030237e10a22ff2ff19066d236013edac899aebfbd1c5aafec41880f972cd19eb9fc9b6977c371017d4615d227462ed4af8e7ddc362cd101e3847397742b0e7f86472e
87	4	2025-04-03 00:31:00	t	f	\\xc30d0407030202689a405c09813165d237016e337ed032b0ba2f89c28be6465461010c6f767eb76f56ff7f995811d062e14e809e137eb0a82f72911a3346be3b4d70a791a5881590
88	3	2025-04-03 00:32:00	t	f	\\xc30d040703021692746cccd0144673d236012546e22b8db49d57ca99e7d9d589d6367d9829b8386fed93b7ac7356eb57bbd878c46e2ead31ada279e8d8528ae2669c6408fa04f6
89	4	2025-04-03 00:32:00	t	f	\\xc30d04070302c671f703c089ce1f74d23601aaba9502c34f8271472c0492a1545b3d8388b50405de1061aeab95871633b706f267e1f8b61f918db49844773e1d5552ceadd4e2f6
90	3	2025-04-03 00:33:00	t	f	\\xc30d0407030270e29e2fdb8be50c7fd2350128296dbb31427735111281df1639ee0c8824958693905784a06f3bcb4869fbfd4f2150437729d46afb3a1210f86927bea11e4d9c
91	4	2025-04-03 00:33:00	t	f	\\xc30d04070302d040bcc756ef72b37ed237015dc3f1466f3b4fee3180c94267717fcd9bf256b6f60cf1a64d2d555f78ffaddc7a39888d519f2e9b83919bcc5a95db7d9f40ba1fc985
92	3	2025-04-03 00:34:00	t	f	\\xc30d04070302e4edd3a3816de59473d236013ba3ea8309961cb9d27e1a94e8369474b2cc51a229943f202c98dc945d5c899f3aa346d5cd37c59e69cb4187cf28258a67dc151310
93	4	2025-04-03 00:34:00	t	f	\\xc30d0407030202d9132ee37753fc63d236013cc325db03aee4b1b62f0355efe702e20f0ff82a902464fa56a164bc0029c7de0ca23c907f7b87ebd224960b076151934cb22d2aaf
94	3	2025-04-03 00:35:00	t	f	\\xc30d04070302965ef75aeda8654969d236010a64897f07ed18d3ebbd03ba8cfeeadedca2b85b8ea188c1785dfe9244f7f9891173ab0b60a904641461f7fda3a7ed51fb68fae642
95	4	2025-04-03 00:35:00	t	f	\\xc30d04070302d1e8e567ae88a63574d237014b759f2b47dd56ebc7db753e9f4632b26346abac0baefd43ff51442270fab10e5bcedd7bb4fda37ee73b84c4c404f744974854f72ee2
96	3	2025-04-03 00:36:00	t	f	\\xc30d0407030207a0baf56713b5a474d23601d656dd5dc6ab5068e09200d90d196d6afed70594d4ae89f93f5ff4e6d42e21824134e4150f8752bcf5058c295d0f4b23f5693c4b0a
97	4	2025-04-03 00:36:00	t	f	\\xc30d04070302ba7a9271883a1c5b76d237015cc7cee655acfa4b802fcef0f66fac3032407093411f10e4c24c24f4eff2413822e47b46325ffc95c878005513db93c14dfc6a2764d2
98	3	2025-04-03 00:37:00	t	f	\\xc30d040703024dee9886ac681b336fd236019df6191428b32cfd3aa48fa29e38c7768e596af957cb823b0d2bd30986a6f36fa79783c9f0522e79277aabb8411723570c1614a642
99	4	2025-04-03 00:37:00	t	f	\\xc30d040703021fe7336367cacd2166d237015f2fa9cc755950f08ec97f608064c25d761be87d9d0a6cc57ac6bf6659be4929aa89a14cc56e43bd6764e72e3b7260b447780730afbd
100	3	2025-04-03 00:38:00	t	f	\\xc30d0407030228afca7a9c5629526cd236013caf837d3fc28fe52785cabc05f4386d24d5797615ab9f149b551f5dc51b8ea3e18d051f3a5d070b715f341227d524b710d0cfda5c
101	4	2025-04-03 00:38:00	t	f	\\xc30d04070302021b0b48b42bb5f867d23601710ab7bf9cc02f47642c2e8c3efcb7498c11fc311b4eac1c6284e56e646d57f54f8c454a9d7d1326a589201c135aa7b17127db107b
102	3	2025-04-03 00:39:00	t	f	\\xc30d04070302f1b571df937b98fa68d23601a7477782b46451f22bbf2365458c6c91394f2123dc1beccdc9e0867b78bbf785c5c614804041965a9343305e888dd3e184a3ffcea4
103	4	2025-04-03 00:39:00	t	f	\\xc30d04070302f207dbd55fe22bcf7dd23701bb63183a785e261053aca08b7b0d2bc487b969f531cf45cbcbaa688e5d1f6fdc49a119b2739d09a185aa162baddfbf78298b421bfb53
104	3	2025-04-03 00:40:00	t	f	\\xc30d04070302e959e49076f2318179d23601ffdf6b77df31595fb3a0cb2833134ecb56078f4ce3d48bb119dfce92ee797ecf11436af3bf12cc427e7a907d8c189613932c0fd49d
105	4	2025-04-03 00:40:00	t	f	\\xc30d0407030242e100242b8b4ae56ed237010a62f98b4e987599454b8353e6b235fc351b1b157d39ad7ac014699bda92d9591d2242294d4b6fda9c5d97cd928a608b762e61253783
106	3	2025-04-03 00:41:00	t	f	\\xc30d0407030268ead4084f9506f876d23601f6720689fd7a4291cc08cf2e9b2ccae9206d1a601b73c49bc4320558831f3e26c3c219d04e204249faf18e0ba845be61be9e661152
107	4	2025-04-03 00:41:00	t	f	\\xc30d040703025f95761b552e5b1c7bd23701479f21353e1d296ec2d8f3bd76e1417eec730225776600c27c6e3d0beff051ece9c1ade79ea329900d5a00594aa06bc4c78db3d862ef
108	3	2025-04-03 00:42:00	t	f	\\xc30d0407030204e8c103eafbe32e6ed235013ce2196650554240839059daf0759496777e12bde18fc111d76e92797834f2586406478de763b247353eb9d1894feb7d10165cbb
109	4	2025-04-03 00:42:00	t	f	\\xc30d04070302aa6918510a896cc47fd23501ca013c276a35a9f30af5389f5cae5f970779ee7e0ed5358aba01c50220002cab51fc8c16223a2971112247c2d686f87c54fd36ee
110	3	2025-04-03 00:43:00	t	f	\\xc30d0407030224ddafbb0a53676862d236010c668760b1ab291512c5b1d1bcd357a6b5e6e53eff24b0148f028fb0e05d581cc201a8f3dd16b541a5afbda1d7edca2baaf1479ae6
111	4	2025-04-03 00:43:00	t	f	\\xc30d040703022f2e9044ad263b4073d23601ab74d853df1d550b88a4565ccb8843d0a06ae6e46a87cea989c862ad68eb559b10d8cef4ac0714a48dddf1e6a8dafe41409c213945
112	3	2025-04-03 00:44:00	t	f	\\xc30d0407030255b04ed19ff68ce270d235017d24bb6af1112e94da02f3cc860b368ae38e169f21cd74c9ccf39d69ddd8af4f02cce52025bea6468411225567b633b4d584939c
113	4	2025-04-03 00:44:00	t	f	\\xc30d040703027710f37baf7cabb961d236019437d09cef9201cca9968eda81f1cd9e59ff54651a5411db1af9d376b5a64c01b98f4ce0fb3a5fba06df601e8254a1b13b3f91ffc6
114	3	2025-04-03 00:45:00	t	f	\\xc30d04070302eb49bcd9bd479e237fd2360136e7dde98634e51f6a3eac390081b516979a811969f0c5f0d07d35dc6a5f7e46a84c01f56dfbf72050e8ec9dff145c16e41b1f325c
115	4	2025-04-03 00:45:00	t	f	\\xc30d0407030299ff177f7a1923976cd2370147c8650b83a18079474065659aaee903417aac8d80fb63bfd890c9140d6b78bdbbb2ae3dc006391a31622f0636db0a22c4294eae5f91
116	3	2025-04-03 00:46:00	t	f	\\xc30d040703029eee3b267a32d10c78d23601846986f449cd898e5e5bb77aa383447fb399885739134a063695d2495af8b0483ebb29cfc70764e33ffc4bf1befaa669e425ade545
117	4	2025-04-03 00:46:00	t	f	\\xc30d0407030276a400f67cc768677bd23601371a274e70b885b1f6149ad2fe4f9a893b03a532ef503c344bc3626b94e5e7c887a372d568467d235072ee6891b34b0dd8f698365b
118	3	2025-04-03 00:47:00	t	f	\\xc30d040703024babf31d20f5734f62d23601ba5ddd5edea3ca427d69f6020d635dc7c2699e8ad1f45c7ccd920ffbbcd512bae2afb19503cac28536434f05da8309a7290f943a2e
119	4	2025-04-03 00:47:00	t	f	\\xc30d040703028207e33503aca01f66d23501e756c5f9ae3ebbded16fec699972a28a1585d760ba540f427b80be56818de8548e35c60b87ee4f80de08a12adb4cd8f565eddd2d
120	3	2025-04-03 00:48:00	t	f	\\xc30d04070302629b13433b08bf7973d23601aa00edb1091f1239d5c5ce0efb280032c2c396b01b05e0adf6fd07f615a10c9d7549c9b8306f64b3712832d13f577c7c4a8f0c376e
121	4	2025-04-03 00:48:00	t	f	\\xc30d0407030266e5979bb13b7f5e76d2370111e65d4ba740e315ba75e8f21b1839ba3020fc6718e009970299fabaaa319aa9cc0eef1917c055bbe0f7eac008802a6b92cc3038f923
122	3	2025-04-03 00:49:00	t	f	\\xc30d04070302624bd88fcee3f9a66cd23601dfae77b388a71c1967bf62616e8ed170f389b9c19cbc8fc6510ef6794420dffec8080a957c8b4d4070adf0863ea3fd97608ef27e88
123	4	2025-04-03 00:49:00	t	f	\\xc30d040703023e9fd902509a944a75d23501b3d1c4655b6a8641aba2bbebadbd932726e463b224b33310cb29dabb409ba478eabe11c1fac8895e51c36e091e35b930f9d3e638
124	3	2025-04-03 00:50:00	t	f	\\xc30d04070302638965c1b98b650d61d23601b3778999f9f176d9d7721f6b7dc3c0c08c18851e5140f078639166712a7203397ca08fe3ee0f1561cb3e4735a03988eded1d87f799
125	4	2025-04-03 00:50:00	t	f	\\xc30d0407030282d938ff582604f972d23701edb9dded923cbdf0d4680cf16d95385b4fc63fc33a16d317cd1eb17828771c6423ad937a547b8d737d40a29d17d6c105dd0cf0b61702
126	3	2025-04-03 00:51:00	t	f	\\xc30d04070302e9ac0baaae417ae17bd23601cb9d57a662d19dd04a684895bbf17de7daa9fcfcb7df83d5d1d0239dc078584f3f5700b0b25429b697764cb2c57829753976ccc2fc
127	4	2025-04-03 00:51:00	t	f	\\xc30d04070302123930978132ca5576d23701319df677d484e66ed8837710c26c169fd91fc85bb7f96115d42c9abee87b1022e255a6a52dac01516a7a9a7a1ab7e84a9c4016efe129
128	3	2025-04-03 00:52:00	t	f	\\xc30d04070302b0e39eb64912f65f75d23601ed780c98dd34178aafdb00d19c71ad67bc79d529093c8d7b927fc27467c6c002522d7c2f7b7e55c146c6bcb76ea22d1af88dfe9971
129	4	2025-04-03 00:52:00	t	f	\\xc30d04070302abfc6b18e9d2760f61d236014bd94f319d5daec461b95122dac1ffed598d6d280f60aae41766fe8e4c83c6a2b1dd697cad6a4e3f2fb457b5ce78503de109f01c01
130	3	2025-04-03 00:53:00	t	f	\\xc30d04070302bf0a2f09e80b4d1a6ed2360140d9c3e59ee137518368bfe4b9be5cd1ddb853088d8ec425e8ddc7284a04cafd261a6ba38b7d22add7a2394a380adc54d4b685b84f
131	4	2025-04-03 00:53:00	t	f	\\xc30d0407030221708addff48eef16cd23701f42bad478b90b63e5053c094810de660892ee1af106862a1aec1f2a8e207badced58459018bb5f51873ecec7f9d693fd38ca7332d8bd
132	3	2025-04-03 00:54:00	t	f	\\xc30d04070302d3fef4befc9dff9f6bd2360144a73ab1f69cd27a924a31e62acfb1bacefa0352c3c83966c29ac065fe45216dc715cd6098c890d2fbd1d3a81f0f4dcd74c729202e
133	4	2025-04-03 00:54:00	t	f	\\xc30d04070302d332f4774d87a0987ad23701bbbf875eebda9532aab1b7654646689d4bbe99dbe67d48635c3f3b233ae7b2d77a97f567bf56f927c66c9276319befce3ae784f29f8b
134	3	2025-04-03 00:55:00	t	f	\\xc30d04070302b090dda71d24f81076d23601bd44c811cfd86147e263d1f1d5c90bd49a057a46dabdea6e0475d38c51611a6f179d785ae515bfa0ce7cfae9115306de809c6375ea
135	4	2025-04-03 00:55:00	t	f	\\xc30d04070302a4dcb382764425f570d237016bf5c2e1dd493b4f656d9cf7216ec6e65869715bbab031a3e97b16f5a0a24592cfb96f3d659c4f49c0802db6b1df4e4d35e076b32e30
136	3	2025-04-03 00:56:00	t	f	\\xc30d04070302749c766459c6587e62d235015316263b5b29578ea4fbc4a273b70c588193330721d2e76ae3d990d64f0fa41301ad27e76f1f95c03e07b9cc13de51bb46446285
137	4	2025-04-03 00:56:00	t	f	\\xc30d04070302b6df72629410368576d2370150e78424851d2d35d49608ee41693da08fb03ca0f9210350711bc02cfb2f7315e04e2b326de7944dfd74b18c6912bf0059e7797cefdc
138	3	2025-04-03 00:57:00	t	f	\\xc30d04070302e92fdda3673102cf7ed2360130dbdf45923358cfe815b3a735e94bbf733b783d1dd214939f8211bb64c999f080f43e40bbe44cbb43ea29980791b232a9f21647eb
139	4	2025-04-03 00:57:00	t	f	\\xc30d040703028bc44e44ec31365273d2370138dd17740971643c36a61a854e4a2556c49a64a2e118595a309e010e27edd7be7d913477375b6d203101923ff21b4d44eb30038be410
140	3	2025-04-03 00:58:00	t	f	\\xc30d0407030263426d559ebb16a460d23601ff6d8c2f63aa0705af468d07f988567e339ab09ab12e449a4c58033e336674e8a1e563cd7d62a4e073c5ba829e7195685b7544e2b0
141	4	2025-04-03 00:58:00	t	f	\\xc30d0407030238b4870dba0ea0f974d237011193b35dfa420af2dc8e7cccf147ff57dd8d8a15eb903c97ffb240cc1df6ced28929ccdc4135973f76712b13daaffb513a91def53066
142	3	2025-04-03 00:59:00	t	f	\\xc30d04070302d860102e38a7948164d23501f7592dfb3673cfe1a32c646a3d8bc4b0e896f9c422ad7b1fb77546f98183acc36c5355d427bad0a8d2cec527cf9496357d8e72b7
143	4	2025-04-03 00:59:00	t	f	\\xc30d04070302bf5c904e225833d869d23701b6902d5eaec4edae4e65e9519d7cb5bc0927e598d6cd7b187d930e1b9eb583410d313fbf585f9091e851cc0d19f43083bfb367030737
144	3	2025-04-03 01:00:00	t	f	\\xc30d040703023fc0074d388491877fd23601f4d46df844e4dd02642e22e881fe0623d28a9b5ef3d7cb4027e85fb75a0d20d2491b74b5d3d5d7b355214e68c79d62dbaa23e0fa40
145	4	2025-04-03 01:00:00	t	f	\\xc30d04070302aa4e96d2dcb6e8f576d23701703e47589493d32d52250b4ed32a9b4cfb35c413f991ef9cb077eecf75e0f785ce81bbda4c20f143d74596ffc9ccab69aa18a831ae6f
146	3	2025-04-03 01:01:00	t	f	\\xc30d04070302e3779dfef4cfa09a69d23601cd9bc0734dfec4853bb5cad7d9a0980e3eb88798230f7d92330ffa36fcd95c291f02f291925008cdf917f7502268a15430c363048b
147	4	2025-04-03 01:01:00	t	f	\\xc30d04070302b294948284e4c6ab74d235018cbbc6b6ea84b8c8df27e3a880f0c5a257f5936ea2aeaf25b7129b5cf3549f371b03a1e40a5957903ec71a14f52145583e3ebcf9
148	3	2025-04-03 01:02:00	t	f	\\xc30d04070302dd753e8e2fad8b3266d236016cb81eb5357e5f188f12f9fb4cf4ccb7beb3e574e9de7d2eb381375fc62fc0ddae7201036c346fe0de208b0dee7762f1a7dbc1c9d9
149	4	2025-04-03 01:02:00	t	f	\\xc30d0407030215ea21bdfd8f36ca65d236018f25ec3a10c4ace3fddb4ba0589e1ca0ab9b36f2104e4a60fb4f8ec3579f874416f84ebf28fe24f628dc330c0c2158681778579228
150	3	2025-04-03 01:03:00	t	f	\\xc30d04070302d16ccdc3e158dbe27bd2360172f63d332adb71bf93c50157b3ff7cb0322595f270d52983c6443debaf4def71172d2df63e0ae00b85c0cdcf798c6296502881e4ad
151	4	2025-04-03 01:03:00	t	f	\\xc30d04070302f37f9e29a31b406565d2370140ab710a847aa84c29f009d4ce740c93ae51ec6cfd5e3773cfd3a4a5b53dbd27786200dffa9dc5a90c20980302f3c10eec04104f28f2
152	3	2025-04-03 01:04:00	t	f	\\xc30d0407030280598ae3a2eb82e76ed23601b7609d48253f49630f89a1f6dbaf8e066eae3f4a2c24940c12a571bd1677cc53a802a6c5c9e5c6970a635b6d7898fcb41edb365984
153	4	2025-04-03 01:04:00	t	f	\\xc30d04070302615318753850ecc47cd237013b9c85512639ea7b857da4b86d30f31c5b2a3954e5485c7efbb1c02947b37f1d3e1b02287acfef2f1e2d07be4eb924b9319d61dfed76
154	3	2025-04-03 01:05:00	t	f	\\xc30d04070302d91b482e1f76430f60d2350125844009697e23a9294781e497947860ac7832077fcffaff25d15617f890cec5aa507481b9d4fc8440ff371987bb28499f87316c
155	4	2025-04-03 01:05:00	t	f	\\xc30d040703022a571363daa235457fd23701d31c4bac02dc4c2cd9e60b12f68cda25886d90fd8b4752b649713804ff06c7df2f7267d9a32317dc27398170bc3f8a2ff622d72d2bdc
156	3	2025-04-03 01:06:00	t	f	\\xc30d040703025a0029319da976297ed23601043fdf46fac9c870c07a200ddf11b879dedf6d4e7a11e7d7749b85fcd0ce94bef3b6ca7531a80043c28c8d03f5ee823db1179ced41
157	4	2025-04-03 01:06:00	t	f	\\xc30d04070302015fab0e9d2825af75d23601d8f79fc687924572770cee36557f7a56fe1112e5d68bc05baf98331287e3194f31a6deb541ff90ad1ca7fbb00124861e8820661115
158	3	2025-04-03 01:07:00	t	f	\\xc30d0407030226f5b8df288fc03d7dd236015aad27c88afd2a09e6bd432e041bdefc316b6d5f4b8fe88f327b78cca0d51a73a3c78849ab27d10ea294852fb5575dcf97cdd43994
159	4	2025-04-03 01:07:00	t	f	\\xc30d04070302a949d991b1ba87c179d236018d3e60b8d02506bf0c88078b53fd6ea1990f3e9339b208885e4c3ca56af1e0f4cee5a2e17688e1d237d10a009881d68dc8834b2f12
160	3	2025-04-03 01:08:00	t	f	\\xc30d04070302a7de5b0e988fe7697ed2360195f37a1cb9ff8a973fe328a6b8d70bc09cebf106ef3593c4b0455543acc8c4e34abf812d6dc1f80e28de0ad17a73f1a7bbe8c32fad
161	4	2025-04-03 01:08:00	t	f	\\xc30d040703026177a69b9d9891e379d2370175478d40105f7468cbb76acaaffe820af57391d40b2d651149eee936513d24ab5f73192ff291e67e64129b11bc8f9df8ae4e3ca083c2
162	3	2025-04-03 01:09:00	t	f	\\xc30d0407030298649c0ef127e2f577d2350175f6de044b8ede5ccf202c9d1411f6f1ee5d1202ed6faf707d24a77e4a8203bb7b741fd0eddf17cc6790817df48488a05cd5e0be
163	4	2025-04-03 01:09:00	t	f	\\xc30d04070302467613752924a1bf77d23701f2f0a3814a704aed1b33a758300f947bc1f1612f2aff6f8f450b0bd16285b652b1e40a030c3e7ceeaaea707ab82ab4f4f6ce8c793b07
164	3	2025-04-03 01:10:00	t	f	\\xc30d0407030299441e7287a5506c6ed23601efd0723dd2574e5c97c2c2ecf5e0110293f9ee2ce8148481f5b6fc273a3b0247b4d2adbe11e5b2217f22e586e60f4f86d04153c270
165	4	2025-04-03 01:10:00	t	f	\\xc30d040703025fef6ba1ec49b9486fd23701f801ca9eaab7fefe715209e71e923460089dd9ae6933fac464eec59b4b1a4e4a3d54297d3cdaf57de64ac9d367d0ff44b4a2e6fd3d8a
166	3	2025-04-03 01:11:00	t	f	\\xc30d04070302daa4cf48b289905279d23601498d6b1648bc7cd61b5a15c4bb4bcc7093f32c212ea9ed913dc7ab556371acb1602cd745be2795065f48f0d9a3ec543d8bc2beaf33
167	4	2025-04-03 01:11:00	t	f	\\xc30d04070302aaff069db9db5cc167d237011f6be1d711795166ba26c82a3cf7797854245a73ed2e67c282d78a4d27468fe95352f129c42d16386be7bdef2d25f27f9389730974fc
168	3	2025-04-03 01:12:00	t	f	\\xc30d04070302c52fb74d0a6c1dd470d23501f326cfd70f3724b523756b09c03c6404206a3dc50e042b81b972cce1f66d70d17cef438e400021f8ce0a9e245946c507859731e1
169	4	2025-04-03 01:12:00	t	f	\\xc30d0407030247cdc06d84cd16f277d237010869fe316cfc05a0573365372b2a86f3afce89b92c8952772fe8ba948531d451b6bb7a25722219c14fc1bdb9a7a5e3bcd5be27cc46ea
170	3	2025-04-03 01:13:00	t	f	\\xc30d0407030241e59a893475d1806dd2360126110738b811847e6098ad199dd97db75737c602a66a2b87b526cce4cd255cafc9b1aea0c71745001801a6bf2fbe7c00db5743e544
171	4	2025-04-03 01:13:00	t	f	\\xc30d0407030232cfdc21104b923d62d2360144d545c828ab07778ca087d1d682ba8860dfb1a19c8b67e3e1a2cce6ec6da91902d2a23a7d76f6b4f733ad75abf0eca22f0009a067
172	3	2025-04-03 01:14:00	t	f	\\xc30d0407030239390619073a60bc64d2360174d2bc4a0b33428ed3ac946921b9b7662995544c530b39188c2c83fb4ba9fa17ed91ea91ef20b25d7de36995d36577f25fd7465061
173	4	2025-04-03 01:14:00	t	f	\\xc30d04070302195ba1488224f40a74d235017078dc30b4c89cd9bd0cc634d3ab51f537d1af97260f7c661b68115bac5f78c443c12a1c52aba906b0b3afe808476ef6332401a9
174	3	2025-04-03 01:15:00	t	f	\\xc30d04070302f6a8b8a28e47121a7fd23601c65b0ca7c11332f93f394727285d1a93f7e138e9b4d329ab8d0e6c7972d4183119ab0a1f4c7373dd6426897f536ed6b8af99aa08b0
175	4	2025-04-03 01:15:00	t	f	\\xc30d04070302980267509177f04479d237018bdedb6aa515dbfeada336bc6dab002068b1d31eb8b71edd7a816955c0c1338c69276c0441562576d839cd71a331bb1874ceb9bd8087
176	3	2025-04-03 01:16:00	t	f	\\xc30d04070302faa9d9cf0a00600e71d23601de99b08414d42a376ea4c4517a002ffeffce93ed8bb5e5bac50291e10d6a735a876c27174377a805f7d325ea8a16d74d7e862345dd
177	4	2025-04-03 01:16:00	t	f	\\xc30d0407030241509252a57760e87ad236015a5eae83ce6ecde63ac63bfb41fdf8770853354db46d27075f81db133ade4220ff9bb79aa902511f76381005b93e83adf65911d14f
178	3	2025-04-03 01:17:00	t	f	\\xc30d0407030225ec640bb812635e6dd23601156687818d90f55b4bcb0dafc6e8d56d5a7818a73ad384a3f8dad970ee1514557bf365df61ba3da4017f8b40317c069c839af718d2
179	4	2025-04-03 01:17:00	t	f	\\xc30d04070302d10bb6f674ca273070d237017e7835b396bb5430552605d6c21898429ac9a4b8a7525c7f7f072f57c935b16de4c051fcff6bb4d42e31c920948c14f5bc14062b91d1
180	3	2025-04-03 01:18:00	t	f	\\xc30d04070302c3402461046f59ce61d236015894bcdf1411082037bb87c279082d8c842e3048908123a37d01bfa8922fde5b0b413587e28bc0ae312c6117fde8c7b02cd49afaa6
181	4	2025-04-03 01:18:00	t	f	\\xc30d040703028e5a2d22af08349365d2360170776e7dfde03c44ed9c6c119d2ee1b45bcf3bdcdb67b5cbb26f40fd2c5ee98784dacd845935ac101e5ef9ca4675f80fa1ee84fdd1
182	3	2025-04-03 01:19:00	t	f	\\xc30d0407030250a3275a7a66421967d236015fc172d5c94d7beef28af0b9d5709cc55d2fd9b454de9d2f8a3141534ef2ee7f1c768f94b6765b5f6a2dc4ec1c60d0a95bcec1a307
183	4	2025-04-03 01:19:00	t	f	\\xc30d0407030225ce68c779e3918b7cd236015429ee38986b10852510fc8337aba59427779bb8295b5022f96e575cec6dd704763197d6c25f549af1625df4786100accffe427a99
184	3	2025-04-03 01:20:00	t	f	\\xc30d04070302591aa26a2f1bcb437fd236013aaecd9a22a62f78e666fcc82a16032c90da5139864d6160afbacd9eb08cc6c1d177229542c835339fa6a8ed64f478c41d27cc3ddb
185	4	2025-04-03 01:20:00	t	f	\\xc30d040703028e112ec395e4886e6dd2360181fa243de655246aec335349880b48ada2d0c91ba906bc217c010c6b504dbd6b574dbf032b38a4aec5c0d177bc9438c71a44095914
186	3	2025-04-03 01:21:00	t	f	\\xc30d04070302839cefbc6cf993316ed23601b23a17b5452698993518062afff6cb78274bcbc013faae4a33ece11af0e8bddbf8e6e327bf28158cfb0dea2e934f85497e1f430d4e
187	4	2025-04-03 01:21:00	t	f	\\xc30d04070302ed6161e30a22876d62d23701f6420e294c4c710f6124ae63b093649d9c0dc1d64c1145008303284693db161e4ea61ff53fe488d1ca2cb36b8dba46189b67060bb604
188	3	2025-04-03 01:22:00	t	f	\\xc30d040703024498ebb4e810dc5574d235019a915326748a459ba795d695d37eefb3069f6e6d611c01648a777944de779733cac3e0572394ce843eb22000251d86936dbb65bb
189	4	2025-04-03 01:22:00	t	f	\\xc30d04070302253a198342dd9a307ad2360122ce8fc4c4e0e41e1ef43ab790e37c9f327cdbd117d6e150448114193b81b023bac69c6dd149d4e555f4e31196e551cd4a3261968d
190	3	2025-04-03 01:23:00	t	f	\\xc30d04070302aa8264fb281d468073d2360115868855fb34f72c5899554bf0e4495eca2b78189033285480b6cb507b4c376d5ec9f6087c36566fdcfc6287f18a1243c69fa41bd5
191	4	2025-04-03 01:23:00	t	f	\\xc30d040703023ea98e2921052d3479d236013b7fd6231c92fc4cfef2150b465689a6c605711c68295af2cff6f1d2cf94a232331336142b3ac0bc2d8c3ef55ce3cac88764efcfb5
192	3	2025-04-03 01:24:00	t	f	\\xc30d040703021986009d19ac7fb66ed23501cd7a4eb41c62af3ba35fd72cc970144b99910d04ce2c8dbd5e7aa8265e41695f29c2bf0f772a32bf797a2aa683c27b5760cf9bb1
193	4	2025-04-03 01:24:00	t	f	\\xc30d04070302bca70f910dab839a6cd23701c527bebe93e55ef0fed4ae3cbdcde94e54fd5f983e6b307e7f4b25e565d22a9b9fb58793282d1d63ca2c527c21954851a7d52670e813
194	3	2025-04-03 01:25:00	t	f	\\xc30d040703020f2efb5b1a6cd4f560d23601d9a5c9ff70e2a1f85ec32243fc5b091b518284eba2f60ebc565c455085fd4dc98070032f0c99cbc7bbc237815888a22aa9b1df95af
195	4	2025-04-03 01:25:00	t	f	\\xc30d04070302ebf5dc241cb7437d75d237014959d73df37e02e41a1590dfd1da11f7566ba4be19a8097b7bc732f087c7c879f527c0eb16807cfb262f2e4d1ceb5696316bba958ccb
196	3	2025-04-03 01:26:00	t	f	\\xc30d04070302b4ebb3e17f6c379361d23601199f118fb54542194b389448691d3a28dc347ba4e1b987e615cffd4577ad9df0224c0d88acca1294f58a7cb7cb2e01769ae90c72ce
197	4	2025-04-03 01:26:00	t	f	\\xc30d04070302d05ed1aa24fc65ee62d2370151e78ec67753c5cc6866cfdecda0ceba09eb7199d7b5fd2562c0c8024d05d33156e945b7b2ec60347e6af1fe03bd58e2582db970b2c6
198	3	2025-04-03 01:27:00	t	f	\\xc30d04070302d2839fce7095818b69d23501712ed39f5b22f3a895cde40ebfaae061eb7859ba26a696b81f464981d3f319ee97ae7cd8697394082061474789a213285e9ded9e
199	4	2025-04-03 01:27:00	t	f	\\xc30d0407030244a2d834c8fa9f9c79d236016553fad98b286138bec04483ffe1e12412552a0e81657402623092e697a8666e8a85bf467e8d7ea0013d15a85b763173e47520a2bf
200	3	2025-04-03 01:28:00	t	f	\\xc30d04070302e48764b5605d06467cd236017d64248427231006ad61d46f759a23f9b1b6949a42c4df0d9c2eaec3b950a156b849994664f8e966f6ce462b79cfc26046656c14bb
201	4	2025-04-03 01:28:00	t	f	\\xc30d040703026db25875e37832907bd237012e4aab98fd515fa2c493b7433daf8365dfa8a3421644df1830b6c121f9abfa8eb8c920108185ef2d8fdfbf3c1f80b70044f913ad0ac2
202	3	2025-04-03 01:29:00	t	f	\\xc30d04070302c80102a47932407275d23601f83aa2590420e7006e74423ab1bf760430e51b602eecfc3b7ea30c3f4ce51e835a10fade0ebbce8e57c9c77afb04aa6d7374507cff
203	4	2025-04-03 01:29:00	t	f	\\xc30d0407030252c84691eeb31c1862d237011fb9b301c029ac008a24b669b2e47bf3aa6a4720c3edffb687240ef3e79b51634e884eea72a25e0ddaee2a55de0feb400428477ea96b
204	3	2025-04-03 01:30:00	t	f	\\xc30d04070302da091b4c21ae46d373d23601255302a55529925fd0fe36d44d93861e1003cdf1ccd1ed7f3da9e66ee22fe64894ede0ffcd3619363f480f865c7f6ec7081b0bbd4f
205	4	2025-04-03 01:30:00	t	f	\\xc30d04070302dd7dba2dbbe7d85271d23501997e446a932ca3454743b6d05830484317363506d63b0b1842e3089032ca913290746c28ac86fc2d24087a65e969244662a50e0b
206	3	2025-04-03 01:31:00	t	f	\\xc30d040703027425d826455fdfba6fd235014bfefd3ace8dc813eae8bd0b1c51352ccd9a7396e798773e15a24b3c1fa9779dabca9b9f3b00666ed4c3d387cecfc7400159f88c
207	4	2025-04-03 01:31:00	t	f	\\xc30d040703025a0e9d5da004285c71d2370131a238cde2940374e19aa71d80249874a62040c132dfa0859aa5e39739f01fd41376bc6f03a93deed2e1d7cb904c34da3726468a7b97
208	3	2025-04-03 01:32:00	t	f	\\xc30d04070302dd345e038ba47a4d6dd23601b24cc69b82070a30eaf210ad26ded1c259ba5ff6eab6fc947e415dd4b9ec3dbe9ae69239d46d4fdf746ea91ea921a85c305245a3b0
209	4	2025-04-03 01:32:00	t	f	\\xc30d04070302e231757f306922e37fd23701f932c56f875910a475835da0dda74eb97f0ada66cd00d28408b38185a86eb9304b28ab7fe776270341014f35174b5af980fdad5ba092
210	3	2025-04-03 01:33:00	t	f	\\xc30d040703029af9bf25e2e3eb1663d23601d4a6266df80309d2d74a27ffd6ebb08890a1c9efbb989d54ff9a73443fb0fb055c9ca7b5315f6858795de19e6ed39eab81b166c3a3
211	4	2025-04-03 01:33:00	t	f	\\xc30d04070302bf4c2e4fd922c2126ad2360102c79987d99d9407e12d2f1f527f5b8ff80a244f34635bb5a76ac083f9e041db891e0fde7d0297f1f79083d084edd5ad533e7a67af
212	3	2025-04-03 01:34:00	t	f	\\xc30d04070302bff2b7deb867ee6471d23601d9661963714b2f2f42600aa674ee0368415f8d21891ce61769221d850013e1995139fb5c70bfd544d482673fb04682724d715fe106
213	4	2025-04-03 01:34:00	t	f	\\xc30d0407030288ff8985ba1bd6c374d23701eb4247ac2d39d78bfee16e8455184492c2a8ea0dc26c1c876a76c28083170fa1a374bfd02df37635c17f603a011ba9eba1962f434c24
214	3	2025-04-03 01:35:00	t	f	\\xc30d04070302ade8773303e5fbab6cd23601c6e1d3318c2edd0569a3c29efc400385a7e97654c95913648ff13883fd5e49ec9ca268b513eaaf7f004d827e102e6961772a62e25f
215	4	2025-04-03 01:35:00	t	f	\\xc30d04070302a2ad793988adbec166d23601f80fbbbefdf97ab592e9c12101b4040d33d5b3a63ced57f5af66ccf849b3b319909352c6059a54abebd3daa5512a32994d50ada203
216	3	2025-04-03 01:36:00	t	f	\\xc30d0407030258140dc1c773960274d236014409849a33eab80a8d3c829e4b8fc085be45a32fcfb01d82a595e176f727becf21fc793338efba5771dff1292be24df5db2b4daaf2
217	4	2025-04-03 01:36:00	t	f	\\xc30d04070302b88b6558059794e36ed237017301308014e9441bcd25c14e0231d03934f116849ae19475be905fad715111bcea901d53039273d4634d2e3cc35bc19bfe39a9ba4b0d
218	3	2025-04-03 01:37:00	t	f	\\xc30d04070302f7314d08131876c87bd23601de9ad00eb6507374c0de1bae8d905adb6cb2f2dc9ed7edf74f5b70431bc84567c16774ce428d3dd8b934fa1089bb433d25dfabab6b
219	4	2025-04-03 01:37:00	t	f	\\xc30d04070302d4a1654994ca1b9572d23701f0ab2394621abd765cad621ec70bfa39df329347bf89ae7fbbc49ef6271ec0cead42fa8b1c22fcdea1a42b89fa5785895b88e5be9d80
220	3	2025-04-03 01:38:00	t	f	\\xc30d0407030232c87998ce36784964d23501086293ddee55715e567a28bd64cb5e9ca631259645bc9fc58d0b79e0a56c0785ded0dba44f74c4d1d75ba96701b8d4ac55950334
221	4	2025-04-03 01:38:00	t	f	\\xc30d04070302350dbd91caff793c71d235012c01286e71be58f5577cfb2255bfb35efe30a3bbb7ac52237f54a0504820c9916359a0ab4e9162658a206b581bc7b6dd6bc14fd7
222	3	2025-04-03 01:39:00	t	f	\\xc30d0407030221acb46ed436fc1470d23601204a964ebf0e428e190f80e34e1945597debf18253fe90efca28945839b1a06a0bcef79f7ed0858303afea19299ce8f2958a66bf10
223	4	2025-04-03 01:39:00	t	f	\\xc30d04070302a45be7ecb3b5ad6e64d23701c8cb3e071481486bc61166e32e1bd6382cef42a5c407c605ca2159286bb1e8750f25a4483bc62998013c549a2aa9df8745aac2cc6e98
224	3	2025-04-03 01:40:00	t	f	\\xc30d04070302df695c380701d1ba79d236013605adadb2517e025deb7188d53259c524742bd5fecd53dd653bf78970c929dfa211f778c57136c95d511ca6b9188f92f875d8086c
225	4	2025-04-03 01:40:00	t	f	\\xc30d040703021be8b00031a3755e76d23701739dc3b60dcb415cbbad4663bedcaa4833c4ce4b5bab26d03730768d0b898212bef4fe46b702e2def2df5cd746291a13617906f09be4
226	3	2025-04-03 01:41:00	t	f	\\xc30d04070302975e90d98d635edb74d23501d3d231c1610a0cafe518a5d11a632fe2e49189cfd6248d27d4cc395f99c7332b99c274f6b7e874576949da4bab0139716fc6046b
227	4	2025-04-03 01:41:00	t	f	\\xc30d040703027e2440839b2daf4b7dd23701ccf7dd3cbe28bd7f8126b50c353ac2c2d19e20d50a3aeded98d96de22fddcedf75b87fe7a61e4f0f2733dee1a6bfbfba18fe68b9cdde
228	3	2025-04-03 01:42:00	t	f	\\xc30d040703023235f4c529dcec287ed236015fa222259961dae71d5dd8eaeaaa5ddf58ae5df589da3bb8472afc701f72e66b4b072415e8db87c4d1db3cc4fefc5a4a834c3ca46e
229	4	2025-04-03 01:42:00	t	f	\\xc30d04070302da44d4c054a38dd973d23701507f4ad22b170747cbbce95a6b00802f0633804ef1d0037a00edd5df5c238007752145a6476635f8ead6e3c48497a0a4a7a320c0a72f
230	3	2025-04-03 01:43:00	t	f	\\xc30d04070302d65de1c9144fee8c7ed2350125a4e38dfb8c0117d4a1a40403d6c079613577b4acb5a6f78b7ccd15765e0a67cc6b0b1cceda5fbe50c4cd6a6267659d7964b463
231	4	2025-04-03 01:43:00	t	f	\\xc30d04070302076110857802623a63d23701cfe162bd9c68a13c847a895d17bd5933d1820ccc143bd56af02e20bac90df2d92411e30fea48704773e5c849ea87a21f1decb349dfe6
232	3	2025-04-03 01:44:00	t	f	\\xc30d040703024e3ca4c9cb087a2775d23601d6eceaa79efe0c9829aa5c9ed1529d172227e02d0de7fdd080a95a918a566262424584ef58e78e9d7aa98c975b787e66bd8b5ee2d4
233	4	2025-04-03 01:44:00	t	f	\\xc30d04070302500a847422ffc15566d23701f2e3df2966ef08205bda6bdee93c4bd2e03c46733276655ffc50157b41b2d5a2a6701fb3e3095d8621561e42b6f07bf6e585ef76a8d7
234	3	2025-04-03 01:45:00	t	f	\\xc30d04070302bcd430d2d0c12ea375d236017d799ec18070c1b92820e98ad2152eaace11568a37ec55179de22d89d8e8ea6326625bc6e8e754841cd4889276d7cbd3b7c96656e4
235	4	2025-04-03 01:45:00	t	f	\\xc30d0407030235e322394863d64e7bd237014913fc44713a0ea02514b374e0514a76c2704c8d8ef2fec8c312a3d49d429ffea79b1f63d246228ac440bf03fd68886f74a113040cc3
236	3	2025-04-03 01:46:00	t	f	\\xc30d0407030235070406719acd6b7fd23601c551aeb87bb4390a6bebfdd26c858adab7458a9b3d85e96c3cfd86b469b1a3d6692ad94cb068ad307b7cd51be47f14b688111e82e2
237	4	2025-04-03 01:46:00	t	f	\\xc30d040703025c005263b54e731867d237014c57dade3048e27de8f09d7100e9ec282307ddb24263245724445f4f344b7525d752c0f767ce3417dc6b0f38e5f69e04841af84b335d
238	3	2025-04-03 01:47:00	t	f	\\xc30d040703024696f6c4fb12f45862d23601557fa3f80d80bd51bf5964730031f86ef4c48723c2c82730e607f875780b0b4b9966fc19fcfbb58e055dac1550c7615817562bf575
239	4	2025-04-03 01:47:00	t	f	\\xc30d040703029d7aba7d04b5bef77bd237011e7b7a5fbdaa9a2ee764221f9ae3969622b09f1642c58c15991962683b5fa385f6d39333280a9c990057ea5bf87792eccbd0ec71ae46
240	3	2025-04-03 01:48:00	t	f	\\xc30d0407030212029e7b4ba2394b70d23601bd9bb909a6014ff09750959f002d410aabac8d4249f5975f8340a7c2d46567bbb52e159b8fe3e5a8949c01c65e900ee819ea51e58f
241	4	2025-04-03 01:48:00	t	f	\\xc30d0407030290b1260374b5b21366d23601d8c0b536f837d4caaa543df90ef715642af34bda1c4cc64a08de6d05f842cab1844bda79fd70963bbf2babe28337c3779e50e9cebc
242	3	2025-04-03 01:49:00	t	f	\\xc30d04070302b1ed42f15a02d84e67d23601d3c6bfd2bc58f32df768754544c2bf63b9df44515e98225784cc084990f178b1ac640f44f6fb938a6a3c1db80cad12627ff7e576d8
243	4	2025-04-03 01:49:00	t	f	\\xc30d04070302c3d332d75aed6f1066d23701673889ad62056a1b11e30876959b7b003199fa3f03d88ce7e7da3f05d10c9aac422f78c56a586cf59a21349eab21f8fad7d49e530891
244	3	2025-04-03 01:50:00	t	f	\\xc30d0407030249808e23308b040168d23601b6c03cf67a93109c5e2a536f0e3e1927b23fa172b55d46f441d0c12cb030e4478351425f2a48b0cacaf4aa8dfa36c52ec87e7e4e2f
245	4	2025-04-03 01:50:00	t	f	\\xc30d04070302ab2d7fdc11e8e7f375d237011dfb71c44c810bbb5627a79a0daea8aff4a515745defb41dc7a3d63e31bec7b74aad605f575d14a5149dc80de2ebfede0e2dbb886504
246	3	2025-04-03 01:51:00	t	f	\\xc30d04070302c54045a69e5848016bd23601c72c606eb66a537b44bb45e43e77a8e9d7f323acf4b12606eebb498758d96bbb901e5193d4c95083a72d09fbb5c8da4a89595fddeb
247	4	2025-04-03 01:51:00	t	f	\\xc30d0407030278c05e74989be84f74d2360160d4b679aace0cc082da5530a220caee9939ced0fb959bdd89e9de656e5f12f844461ed9f23eeffd9f7ef8b6efc428280e38f21021
248	3	2025-04-03 01:52:00	t	f	\\xc30d04070302b2a195f4b58f3ef57fd236017b806a476e032a46297aedebc42ea7f806522d28a28f667137391443015190e9ce94886bbd36fef0499065cfe6234f25bf7efb2c03
249	4	2025-04-03 01:52:00	t	f	\\xc30d04070302e9391c0062b892626ed237018ab826573bf5e05a1369353e6e470a7acccf03d7a48db8b473930e2c73c7c12232cab78750ee6bbef58de542834dfd08bede7560aba6
250	3	2025-04-03 01:53:00	t	f	\\xc30d04070302d27cfb4b7992c54678d23601e60c3eaba53ee402bb94a384577ec6128902f142c8f2b31f50fcefac3587ef70227995fd9fe6ffc79af03d717030a5b19bdbea900c
251	4	2025-04-03 01:53:00	t	f	\\xc30d04070302cd51d34abdeca69b7ed2360197337cb05a6b916ecc27e87516c8408ca8e6731ef336b360ad2ecccc942a808f459bf8e048f219fd6e0613a2bd3f4e7f2cdc662e6f
252	3	2025-04-03 01:54:00	t	f	\\xc30d0407030243630284bc05b0f37ad23601b0259c291454a1691e0fd1d44a7313a9ad4490b552346fa5e3f930c01ea6dd47025f3256e143b0eee77df2fcc2c7a909f4791c396a
253	4	2025-04-03 01:54:00	t	f	\\xc30d040703026fbea4d93fbd19f667d23601bd1fcbbd0296e8f6e6bbf817b5c444ac2bba0abadee35b57a6a57ed997d18e4d89eb833d4d2d1b65ea5fc7670e8c7efbd89069633a
254	3	2025-04-03 01:55:00	t	f	\\xc30d04070302fbf2a8f8ae6e3b3965d2350124a431df024d48494da190490c642a3dacd15ea269dc0f58162fe6e6965c5d61e99546a8a2bda61b3237c61ca5bef83ec1ca3838
255	4	2025-04-03 01:55:00	t	f	\\xc30d0407030232d9d6d92542adab61d237013d15efdf79149ae06f41214239f3987855ee53c77ae1268449f2bf41cf553ca203d40deef89548249f4bac263ba6ca568e08810a4df2
256	3	2025-04-03 01:56:00	t	f	\\xc30d04070302306fe9239fe3bc5f7fd2360106556dd9d59decff030950890c6284aca66b1709239fb728e63a49731f1f7c130e37da4b90a73aba2eb6ac0b9a39cdc420f7a67a75
257	4	2025-04-03 01:56:00	t	f	\\xc30d0407030218d746f1ab2452a567d2360139784130f27551bf0916fa0a50ba9c303036c8bab95a075013351ad5749ae3ce4334aae1751f9e225c71144cdb3928f7a47c8d6fee
258	3	2025-04-03 01:57:00	t	f	\\xc30d040703028ce74908660e77db77d235016cc1a2b8a9020bbc8d20d49623a7172167bd867182cf75cfa7f6feffaa90c4812c6797fab661da61b7888d817f2d5196680d91c5
259	4	2025-04-03 01:57:00	t	f	\\xc30d04070302d488edf3d422de6c73d237012be275d57cd260fefd6dd78cba77a5a501d7b7c8b4a0ad2e5278bab24a0b7b496da2cc68f5cbb57f6d9eeee7dc6201fbe3732b1e9de0
260	3	2025-04-03 01:58:00	t	f	\\xc30d040703027c315b4cc0a5c5fd65d236018e07918b6327c50207aec90ffeb87f7ec553ff880f31666c94e3fdd488735e3055e6b4a7c45a0fd7cf6d296435f2c6950e5e963b08
261	4	2025-04-03 01:58:00	t	f	\\xc30d04070302ba74543fb92422196ad237017db96b5b11c05151f168ea1f66e1f8dec12db43264f812ec4ef42ca62e1f1975337e657eb4cb8311f8f7dbda1b9a40ff31dfc788a9e6
262	3	2025-04-03 01:59:00	t	f	\\xc30d04070302a839d858f0c9af186fd23601848bda1098b38c1effd5d8c638575a2c16dcef57d41aa9cb73218c5f0f23a5753fb2cabda684f02bb31ffa8bbca70acf43c55e3689
263	4	2025-04-03 01:59:00	t	f	\\xc30d04070302c1423a0287659d9a6fd237014ecd85903e1e19432fabec106382d5dd7a0fe7bb10da54d134c80c74113695327393af75d9749781941529353c2cf5aa56faa1e7cdbb
264	3	2025-04-03 02:00:00	t	f	\\xc30d04070302cdda181d47b0ebef7ed23601b0fff19e78e81cb370284796d94cb034e29ad97f3dd9cf5544674fd0346423e6fc240262f062eda586d90b8b833839bf4ae1e52550
265	4	2025-04-03 02:00:00	t	f	\\xc30d04070302a489b261f2cd7f6a63d2370134e47926cd9f41c9ce3c9455101678319b59383022ae9966eccc26a9cef5296bccd1c47b92c8c08a6a99327849e83a261e90f12efa6e
266	3	2025-04-03 02:01:00	t	f	\\xc30d0407030294411121b690e9d87fd236013d8be1e875141af6de3d8f723107b01745ddd54d29a0082f554bd732b818496d4cf2c8d837bcba0a45d3e0d322634d05a01688ce6c
267	4	2025-04-03 02:01:00	t	f	\\xc30d040703023985aa1967b6b02b6cd23601ed0fcd8db101c424b71d244985a014d2ba3e8a2c00f0175270c7c3365e7afa0ebefc46d0be5f4e974230e2df13137ae971b7286687
268	3	2025-04-03 02:02:00	t	f	\\xc30d04070302c65acc1117d37c9b6cd236013fac091ad43db7985d43b2e0bfb5656e137b7a7c53efa2a90f1596fd7986a8f5b1d3c283af81d6d3db256937b483158a9c70ad0cf3
269	4	2025-04-03 02:02:00	t	f	\\xc30d040703028ec41056ec7f59307ad23601aa5880d5a9d99298f26a7c427c415668486caae66d0c360d6decb97ab62de6974b398b1d6ae9ea572246dc939fd8a5b74563f9bd88
270	3	2025-04-03 02:03:00	t	f	\\xc30d040703020658ce870bf895276dd236012c341d724f1b1f79f6bf46e7a82a22c26eae56f7a8e09cc842da47accb92a07acf6f4c14bf79f1810653e1845302715ba3cf125ec1
271	4	2025-04-03 02:03:00	t	f	\\xc30d040703021184cc97c2ce05d560d237012d3cc13e26eab40bf806f2c31fa700bc433abac9b8db23136fb5df7390899100aa326d1bc0682463a30cdcb0bf112f9eaeae0db9e7fb
272	3	2025-04-03 02:04:00	t	f	\\xc30d04070302c6836ec1d77d70d967d236015160508915e8710553195cbeadb67e82c506f6ad406cd9bb084a448737d80d317bba8cdbc2d2f7f2866da3487652f5fa824401fea3
273	4	2025-04-03 02:04:00	t	f	\\xc30d0407030293bc0cb8695f80c864d237017619a4daa891a4ab7dd74b3a7b8a458436537fa510e55f9091119f1ff65edee34838e85dc1f332b130dae3e30b8b0e4535fef935bc65
274	3	2025-04-03 02:05:00	t	f	\\xc30d04070302754445eb33fb0d816cd236010da6ca1cd26ef908f15a909baebe105742ed333619753a5005973c75b8129d52a1edcec9cea62a5b6a9b088b2865683bddfe0d6c5e
275	4	2025-04-03 02:05:00	t	f	\\xc30d040703028cf932e29289f59677d236019f445e0ae4fc2ad82d30b1505008ea2d4969be8245f2f9e3d4b567c5849d5263301344b0d0cd22139a2116321ee52992a0c1aad79f
276	3	2025-04-03 02:06:00	t	f	\\xc30d04070302cac945227ecb0c286fd236013e553b8bd6efc38ffc5e7d820494e94920a1f45d466779c6af13b39a48647f38b29675a17eafc99c38431669653edd15184ebce795
277	4	2025-04-03 02:06:00	t	f	\\xc30d0407030226204ba33b22400269d2350180b1c565a671a7be06acd6e4167bfd8aa26fd3d5fa93928b900a985bc979c62d778c306ba41e4b33da568c9d380495da7b1ed14e
278	3	2025-04-03 02:07:00	t	f	\\xc30d0407030260a59c400c76933f6cd236017bad1c3ec3318719ba29c6120b04c7acb144ecf5a26166b64921bc520561d3c91ee7faeac29381e6703b701031eeefd4bb488c61a5
279	4	2025-04-03 02:07:00	t	f	\\xc30d04070302f82c1340f7418b0a7bd23601415505b548a94bfecf2f008323b54b354a7c5f6372ae08c8aef00122fd229ee1987f4f65f70a857ac866cc1be099ed5c50d0f5da2f
280	3	2025-04-03 02:08:00	t	f	\\xc30d04070302db9dfe337189ccbf60d236018a4c7ed25e68f92f6a287feb3bfd50e7a581b2c4fa54459ce08272db68636ce13b99922bc5192c39e4c75ffa531c3287552803349d
281	4	2025-04-03 02:08:00	t	f	\\xc30d04070302d8cf90ae1407a0b061d23701e1c465e7098f6abb9a02da55ee3901c5b3a417c3cb9a8cec06692b38da5e6046e100e0994733d7548bcea4c13e0836a57215f59e52bc
282	3	2025-04-03 02:09:00	t	f	\\xc30d04070302e04bc28d46a4f34279d23601022bc1f756a9adc544acb38b5c86c19998a89a57d510d5e6dd754f240096214eb3be93333be9e109f233d9fe1b0e468787d718e4e3
283	4	2025-04-03 02:09:00	t	f	\\xc30d04070302bb180bd570a2771566d23701406e70efd23f9079d5292f5182738b4f7658062b4472fa93d88f6cdb88260d5ed4ffa2aeaf4de4b2fc70cec2c9a0f620ada318a579c8
284	3	2025-04-03 02:10:00	t	f	\\xc30d04070302ae977efbc91cd1107fd2360164e8f7920ecb62996c4436e7e1384db8a7bddb59d5b2284fd4e369283a3a0a8832d9566152667cdf7fb05c00bf615f13b803becffb
285	4	2025-04-03 02:10:00	t	f	\\xc30d04070302cabaaf82df805e4a6dd23701f6655315c9e495e9bc33856d099d3c8e28c4d20e705b729da2490db86a6ceee6deb94ed3e600d50f52162190e3d3b40cd140c076b312
286	3	2025-04-03 02:11:00	t	f	\\xc30d04070302ca12f07a1162136a67d235019b1d2815b007b70ba4447c9f4b6f38f4d5c930a23fc4a027d5075ec348424c4335396b6fb789fee51bbec4722392dee4e9ce84f2
287	4	2025-04-03 02:11:00	t	f	\\xc30d04070302a20995993202983f71d23701179c936b1476a8c76e274aede9264eea0ed41d9a9b0ae9e7596f05faa9c686e1cce00f0419827aadfb6fd7daa61ac2d247e9e391f8c2
288	3	2025-04-03 02:12:00	t	f	\\xc30d04070302bc0d4118329818857dd23601a4dcd4618b10efe0915c445dd0a4be7b0824eaeeb2402de9ae31301c3b38194eaa96a0570dd47d2e01446c6e348799d4fc726f8fbe
289	4	2025-04-03 02:12:00	t	f	\\xc30d04070302043ca179446ba70564d237015cd6a76f3f4eb3ba87c38b7c15ef03512c4cf8ea785ec9af229ef42c463cd83b4cd1057fb49c5b8eddfbb6372ae8978299f32f6b2cdf
290	3	2025-04-03 02:13:00	t	f	\\xc30d040703025854eb9f7481c8a87ed23601a8fda080573bd78fb6c16ebac1b437225a508e400711c37bbdb9602d5f49614eec754a1c655d108126575550fa0b30692be81f61cc
291	4	2025-04-03 02:13:00	t	f	\\xc30d04070302af1a7719f3e1cba57fd23701b9a776ad69e04039d3acfc658a71e9ed3b0d5e2b0083e2d67d20f3445c787e7c85bc83dab3ad441159098665862a5b73df2cdbaa4d75
292	3	2025-04-03 02:14:00	t	f	\\xc30d04070302235f0bb89885f9a367d2350131f6f8b066e71d3f9dcfd64dabe226552bdb04e75b52f0fc71243dc440a0d7adc1fc42ef4e8a80d905bb1d73f60276503ce52688
293	4	2025-04-03 02:14:00	t	f	\\xc30d040703021e18ac5249d757db65d23701a5cc99fd463477f514359816ae69db6d15a366b3e9525537d8949aff72043204871696ea7f001991108332bd4357cbb726ee97f9b2c8
294	3	2025-04-03 02:15:00	t	f	\\xc30d04070302f0f19b039582e16c61d23601a25ccd78f35d09a039f5fa8c72a96242d29e297e3eaa618a1e04928bbdf9fb917f9f26f5ae75dba69b1f2242cc5c8a70ad4c010184
295	4	2025-04-03 02:15:00	t	f	\\xc30d0407030207ad2027dae812617bd23701c609409d4ab176334265bfa71f9c8ec821652d6ad6e88a8131d2e7b7e6bd7f042a468f5d59eb8c269ff2cce6bfe694e85b22aa873f6a
296	3	2025-04-03 02:16:00	t	f	\\xc30d04070302037907f9c865d5a27fd2360129cb020986634984acdc7312fa0d1bb4a5bbea088eddf820e121948d063d98fc48852cb4ab4afaa5f7123e9a79f10610dac297dd68
297	4	2025-04-03 02:16:00	t	f	\\xc30d04070302bddc119d506e0e0970d236014f061babc96ac998fbec4b53f86a357b5dc50eb872db3053c53ddeb89927dd41bbae1663e7779991335302f71ca89cb195df88ddb2
298	3	2025-04-03 02:17:00	t	f	\\xc30d040703022a7fc93eec25f33c76d2350131dee64236786ca334a32034227fa7e6c9a2bad1b52cfae38cb9b19138fff522739050d5c99de149d1816803b3ce377552fbae6b
299	4	2025-04-03 02:17:00	t	f	\\xc30d040703025aa789e99650720e7cd2360157642de07238b01440bf2d155f2c21f817060611d1c87bfc2b305469a7ef36cf0626eefac032e312f706955c47b3015f3fdd2bf91c
300	3	2025-04-03 02:18:00	t	f	\\xc30d04070302c87103b5c6b2a26a74d23601e706b19c7ed8e1dfd7850a7b14231cec5f59685bbe006c951deb307ab111eb443baf20a4deb263db0161924d06bd9bcf03ff8860b5
301	4	2025-04-03 02:18:00	t	f	\\xc30d04070302902dc666e0f714e565d237017f9f1682caf9e187d8d7b0a69f47e1cffc4477eb818fd705c3efe57d441907f22b01d6d881b691a025a6612da15b636fd16fc7ccdc93
302	3	2025-04-03 02:19:00	t	f	\\xc30d040703021368a53e535354f562d236017092cc49cd1aaa771bafb8e17878b3b1c45000ed01936fcb148354439c897e8f0faa64c1d2612ac2f01d16637c768f97155dd7406b
303	4	2025-04-03 02:19:00	t	f	\\xc30d040703023958f8e29e74786d6cd23701cc125ec14e4e13879797b86bfb8a15ca3aa749724346678ea7f2873b6c5636826cca50c7c8b1b7645dfba970a2c08f25dcca005d9ecc
304	3	2025-04-03 02:20:00	t	f	\\xc30d04070302cfca40d10ce545127fd236011f99ffa466c70610f12990c444b08b03f2040a4d9523f647cfee53bd67a4b2b2eaadf26cd2fe550e76d930980cab66df9cf9a0833a
305	4	2025-04-03 02:20:00	t	f	\\xc30d04070302d192b6ad5e15d45775d2370158c99f6fd65de1efaa6e90568befc4984bc57e3952f3e4efa913d83b5f01f8ee0b22cdc1097d74fc6d6bcce66b6340fd3874fe7a9d20
306	3	2025-04-03 02:21:00	t	f	\\xc30d04070302bf2052bfe0f7dc4362d2360141b8eda783b8e238ff740fa7bc4446adeabed23007c70d0459bbcd04c1acf0d384a04cb56e83b5615b6a484f39f4abbc0ec6d36a05
307	4	2025-04-03 02:21:00	t	f	\\xc30d04070302132037458ee84bb960d23701cc636a74943e991d087f8badd7268294b7d4c3b872b04a4fe506b5198fd4b7fc12400a1375e612d71ee0dd59baf4c4c934825424b942
308	3	2025-04-03 02:22:00	t	f	\\xc30d040703029bfb2f5d2e60633277d236018eb3eaef6ee97220fca01625b541a4f85f4e5449ca5c0120e2e42cb055c03e4198d24b2a3568a629ad18eb02f3a888b49026799ac0
309	4	2025-04-03 02:22:00	t	f	\\xc30d04070302d6dd7c31fddad3e362d23701f94cfe3708af8942cad6e3f4808661b37dca98d02745583bc70f2726a13ba557d72a730f7c72d68cf28b863a7fab1231f0394dc7a350
310	3	2025-04-03 02:23:00	t	f	\\xc30d0407030275c025c9ae02a11b72d23501dbb40acf20864dedf2bc45fd3326e56c7e46757218ffa318b1d1441fbe107747125fcaa172dc92d821981178b0ddb47005c50c1f
311	4	2025-04-03 02:23:00	t	f	\\xc30d04070302c4753141be55668468d23701b66d864a0ca1491c37ab782fed8826f882fc3d4b52960c6dc8a82d6a2b8c6c8ca91b3f67c48e1a0c616a3880d38a27c048a295e16c3e
312	3	2025-04-03 02:24:00	t	f	\\xc30d04070302f85666e08d59d8047fd2360161990324e8e9c048c9bb37956c1181be6963ce24406e832a1c5115c844a6f788a8c3bb9018e49866570e6fe2947ef6a258cbc8a20e
313	4	2025-04-03 02:24:00	t	f	\\xc30d04070302f5ec4d03cd0b061b6ad236010be8960a6fdaf372e612042b8caf33b2eec9e1806983cb8d496af7f2c2dc0774e712ac6bad8b1f6f817cb922330c14bd7dced3ccb2
314	3	2025-04-03 02:25:00	t	f	\\xc30d040703020a316f9dd52e938f6cd2360106bcc381cda11dff9b2562bb5d1d08140a4a6503022a6813e02d0c21f459118a0f5a82612eed50e5802de2beb200f9162b83b27271
315	4	2025-04-03 02:25:00	t	f	\\xc30d0407030251a4db426874409c6bd237013b6dddf7f65d2ea3eb00bb35d43bf98ea907b667c1f837b15541a7e4e301b0f498261daff2038c74f8cc106dbb8fd5bb090543021290
316	3	2025-04-03 02:26:00	t	f	\\xc30d04070302d68eda583faab5967ed23601d4209d126d1e5d96b2596046710fc33983cf7dd2cdffb1d5ec019840485c45ce88f6335a89ead21e6db3538074c57f3913467f60e4
317	4	2025-04-03 02:26:00	t	f	\\xc30d0407030221a35957396f081d7ed23701b9d48ed0b7b984232384ac37fc42b4c816f2c0c9f3898ef26f98536c22cc4dfc65fcb84ee428baa6875420581f5d53d16943606b6baa
318	3	2025-04-03 02:27:00	t	f	\\xc30d0407030240c585549d4cc85c70d2360129d4eb3d9309a829e4b9d67f3b68666ed62ac0744d5f7b5ebd733a0900e5b5ebf95d989efaca3d3360cdfb1c2f7a79e642cb085ab9
319	4	2025-04-03 02:27:00	t	f	\\xc30d0407030220c35d2bc669a6656bd23701f4102f0e081d5e6aedd3e901aa52a726bd679823fc23b2ccfd135440291c527d3f711156f889f6f0494ccaed808829b27377ca200913
320	3	2025-04-03 02:28:00	t	f	\\xc30d040703027e9c2353a394b6937bd2350157c8e6885937b7903a375e6877f3fd3649aa8957fe8231007005c7c6c0c5cd15656bcc03f77ed73e0a3994fa40cf4034e7724c2c
321	4	2025-04-03 02:28:00	t	f	\\xc30d04070302fec3b644d5bb498c74d236015b927a3d0ebe3d2af55707d6d506cbf9e8b4aca344c8c565c83018c7ae56221f0cbb32f06175fe0cc148e9ec3d0e292f234e2f2a8d
322	3	2025-04-03 02:29:00	t	f	\\xc30d04070302d27a80de6d3d1c2d61d23601486b762bdcd7a64bdf2d2a4b6938e3a31bdb0176382a1fadadf49195d1fafe81e1fb31c664fff03f13b28f151daa28f86e3fa234f7
323	4	2025-04-03 02:29:00	t	f	\\xc30d04070302e33968278d0fa00270d237014214520a06f2fd925297fa83b0ae02baf0e8cfe07d97aa418a5e1cef198cd091aa7b809e10458cb334f4940f5f24b4e3aaa8b5955a5c
324	3	2025-04-03 02:30:00	t	f	\\xc30d04070302cdc7a1dfa48795e871d236016886e52492c04b36660d92e81177555eccc8e077f59f66030f4e33508106274e4824029bc206034abb3eeb462091ad4323961b9c03
325	4	2025-04-03 02:30:00	t	f	\\xc30d0407030211b044403f0c293e6fd23701ecb03d2c9ad2c2de514f0f265a7b87f31bc1413492add47137c2aca03b7695dffc845a98551601acd2efa2ff5b5b626eeccda071d42f
326	3	2025-04-03 02:31:00	t	f	\\xc30d040703027024b9b1c665bfd663d23601b7d7176932171ae3c42833523dd73dbd1138cbc8693c2b080fc8e5bd46492267d8ac81d90b5dfbf75f69cf5d0810b25bc659a2f73c
327	4	2025-04-03 02:31:00	t	f	\\xc30d04070302e13929302825853878d236019f05373e57025884362b01318e6d8218bf99af2a7bf321df372ce487a110c439793d4bf0da4bdc70314ab1a7d9999f4a2a96383b00
328	3	2025-04-03 02:32:00	t	f	\\xc30d040703024d5acce9f4b9238d78d23501f67f0292af0c9474772f204a7662045d03d9245dda924e182cce1295912e1e9beb795fb321a9e2dee8e9cfe8737ef16fd14447bb
329	4	2025-04-03 02:32:00	t	f	\\xc30d04070302ecb46304afdabf187cd237017ed8336e4ba467da5f923beb8d1bf09cfbefafa038dd3836616bb08b4bd81683e02e4f7cc50d914adbe29228cf24b45de6b08327811f
330	3	2025-04-03 02:33:00	t	f	\\xc30d04070302350323104d362d0e79d2360193b75eb7231294e8360b46eae103ce73e1417ec46d28c6cadae213860b92f64e4afb7cab22b32108c059f43b7be30b3a86d4469631
331	4	2025-04-03 02:33:00	t	f	\\xc30d04070302aba9fc76b76f703d6fd23701a4a92a32283fb997d672ef2dfc126a530915597b01ccf4a9cc8649537d164a9401cfb44db3abb1dc35f7c40b266389e284984666e9e7
332	3	2025-04-03 02:34:00	t	f	\\xc30d0407030246da06e73196066a7ed23601b5c5282d9d35ce5ead038fe776327581a7a4ce5f284da1c91595b105374e24e02479326dbf5527812208fb14b81f257e0aaf9e059f
333	4	2025-04-03 02:34:00	t	f	\\xc30d04070302048bd5b49180c8b77fd23701385b83c62cc787838ddcc09d245b9907ce32a99b3cb5fab7588ae40a495bb8cfe58343a69c8af4e48dafc9c528f7aefc83e052c3945b
334	3	2025-04-03 02:35:00	t	f	\\xc30d040703028a27526d6858d8f46bd2360117508f6e8217a9db40cb4c2185f1392af4daf5ebce7edaa13f6408787c4a2baf24e0ecf1ea1b34c5a95deecdd8de6bbe570c1a791e
335	4	2025-04-03 02:35:00	t	f	\\xc30d040703025f072c2e4e8258e967d23601efee6d04e51c99321b279ab48870fbdbb24e9ab3821570970a735dd6eea003d082eeb2cb2a071c6784a1df98accd63f4f5d453fc91
336	3	2025-04-03 02:36:00	t	f	\\xc30d0407030220d9ea59a6d2269866d23501fbdfbbb192f8976bb2d33c60ad03cb3095e133b32195189f0c74f95a7d0e0ee7019702a0947fbe55210ec29b997a45900ddf9e7e
337	4	2025-04-03 02:36:00	t	f	\\xc30d04070302f75891501dfa30ea69d237011b34b633670cd3e7947a1070e4a8b5faee24e11d0fca412c3082bf493e1e14f6916c678ebef255c3cfc11a79ddd6de8e229240137419
338	3	2025-04-03 02:37:00	t	f	\\xc30d0407030298d025b6a2f3b11e66d23601e28bdf3a88c28b992ec10d088d60e558522f7cf1c22a95c186269d218795df09c615e05a2321697f7e0275591c1b391c7fb8dd84bb
339	4	2025-04-03 02:37:00	t	f	\\xc30d040703029cfe7991bcda01746bd23701967da9cea1f694ef0ebecc098da4c75eb77999898e8a2cef349d18af92512c496957c85c950b72f9d50b42f2721f05ab25f375a4d0ca
340	3	2025-04-03 02:38:00	t	f	\\xc30d04070302bd373eecc02d4bfe7bd23601cd57a18b4b062cbdd6682458a1e560a9bc681bfd53d03728fd3646cff9198e61c0ba1adcc27a18dcf0b8005f5cd50a2b29cae1c03f
341	4	2025-04-03 02:38:00	t	f	\\xc30d040703024ab8446e2719298277d236018cbe026defeaa3ff120db927cce6c9383818a237d36235e65952b9934a69de868a57b1d41ade216f23d221bc6d188de1de1af04797
342	3	2025-04-03 02:39:00	t	f	\\xc30d04070302c596a1f227098d327ed236010c58345794cc693b26f2bb675138e7c69658abb4d0e52fa10de558d2def1d2b6c3b0719c4e21e634b83be6bb53a61e9fa2b90a7cee
343	4	2025-04-03 02:39:00	t	f	\\xc30d04070302375ddd60c9acc7c07ed23701d2f5b879f05d429935b3b6b87e5c4cfbce6d3e5e5c71780f4c2f80f6c251992fa60ad9241fefe355076a0e0d29908e064db9a699bf78
344	3	2025-04-03 02:40:00	t	f	\\xc30d040703028b378bbf3a219fb56dd2360105233fdaf87a8f4de1394ffbbe2f516dd288bc87f25482629969404bd7d131be414fdec2fae722c759cb1a6fd6030df491a4239d1a
345	4	2025-04-03 02:40:00	t	f	\\xc30d040703029c8499adddc4256960d237017bdbd59d9f87671c3d588226b26181bc7ddf91c4b81d2dbbc8736666995e817ab9e18a1b1605ae77b56f8b1e25aec5e49dfedbee85a9
346	3	2025-04-03 02:41:00	t	f	\\xc30d040703020cc8d17e525f82f861d23601f3a5c20ac50c2e5d52fca4899cabad03e6bc2ad82b1a8e2f8780d2123982f4beb0e9b52dacdeb1b5b9ab9d1e7ecd8a31915660b661
347	4	2025-04-03 02:41:00	t	f	\\xc30d040703025b77d6f563bf274372d23601a3f15e0a2a7d3e39695fefe17d578d5cc53c04d8c2e627de94f473fb88cc989045d1dfee48dfe523b82473708f9815c3826a775af4
348	3	2025-04-03 02:42:00	t	f	\\xc30d04070302a95ba8e5578b659c6ed23601843904b70b817f78aa53b1c5cd455ed0dce6488300ed563705072823806c449a0e0b877c5f3b9c87e5e90b1e3079c709d2793d9e57
349	4	2025-04-03 02:42:00	t	f	\\xc30d0407030226fd833b0ce6712b62d237019a64a67e23ade4b560d9dabf0cc415a62e7d10f53f6d85f733a83344da748f01b89127c3a8af04070cc5f77a781147db28a5e4e0b47b
350	3	2025-04-03 02:43:00	t	f	\\xc30d040703025a6430b953a529cf7bd23601d74b0f6c414c4a55a296f975883040d0dc99cb4366c785577936f0055a3d9058d6f47de281256ae112fa0d111458ba0d5214a26ee1
351	4	2025-04-03 02:43:00	t	f	\\xc30d040703026ea48a48ee9ea8d861d237018cff18117ca10b31cc33f6c614c11e0c52848ac101319c533e008c35e08f977696539580a7521270ada278796ea56dda0a2da77669ea
352	3	2025-04-03 02:44:00	t	f	\\xc30d04070302608b89c8e8785a746cd23601680680d589d0e40335539d84c3b46448ac80684d55feb380b2952854b03dd2d795f375c2d346cd052a748c364d8a1467deeda2648c
353	4	2025-04-03 02:44:00	t	f	\\xc30d04070302e19a6d76125d1f9465d23701463fcc803f8723c6b27b9afb67f133a2ebd1a07e59dde0b402564e8178da3062e93d8319a514713434a79679cfcf857dafc71064f7e8
354	3	2025-04-03 02:45:00	t	f	\\xc30d04070302d388eb46ad74d3d868d23601fd57f7de852ed9512fbf6f626017c91a79798f1f1d4193632501a60a597dfc19cfbe88983293c2c69747020db27b5c09f733e0528c
355	4	2025-04-03 02:45:00	t	f	\\xc30d04070302c8c3e206718942dc61d237017feb9b3c89aab54330f12cd8a92ab1bbaca2f80fcad5fb69054430ebddadb822f30726113773ef117d18ba2a8adb6baa514f98866e45
356	3	2025-04-03 02:46:00	t	f	\\xc30d0407030272dccc3f85278f4563d23501f3130dde58e260133d5250c6272dab1f02ad96129d0ab1c9220f8c66455060a7d32d3749bb8e21a012df21401fa936c10de8f0a5
357	4	2025-04-03 02:46:00	t	f	\\xc30d040703022a1bea7edf3c252e74d23701ef68f2cf790b0e4619a23f393359508112674568c289e51ba7dd479d46a61df942819c64df91cc37319231ba83e619ab6bc6d622d59d
358	3	2025-04-03 02:47:00	t	f	\\xc30d04070302a74afddbea92c57260d23601280b4ed48729b9481427e7dbaa393292abdcff312436e207d0814b77c0e0ea528382684aac3205af3ac7ac623472cade1fcff0839e
359	4	2025-04-03 02:47:00	t	f	\\xc30d040703022e973ec8a2edf5286bd23601810f5874d2e847504abc70d54a90a59589095ce4789d28ce23662e5635fb76f70558e97b2b559f6fc0803cd2eabd6bf2bb39e3d8bf
360	3	2025-04-03 02:48:00	t	f	\\xc30d040703022e08da4531a2f3707bd23601c7b92fb98443287d75328fb4c45da365b636923dbe7e5264a0dc6a82e1a492f442e725b038181b916354d7b49a0440dc3df2101763
361	4	2025-04-03 02:48:00	t	f	\\xc30d04070302a6ef6093aa581a0f72d2370154a8a5d95af3e9dd496267ffb770d7951dfb31bc236360c914be1a5c8eff4e0b781bd9e53af1969429eb232ed4e5ea32bffa5ca3c6ff
362	3	2025-04-03 02:49:00	t	f	\\xc30d040703020e61cda46b0acd227cd23601d55eab56dd7b94191df2e489a8aaa8d01ee54844425b2a06a3a2da2b7f9b1dfced0a8ac6ea7f231926e22448b88028d7642eef4602
363	4	2025-04-03 02:49:00	t	f	\\xc30d040703022148251793fc296561d23701945ebfd38c404b2c5f7ae4577b5cab713cb1fe3406cdfe08bcda3afb6f8a3a1e50a2c90ee8d2b12710e0a34414b14e03eff58225c731
364	3	2025-04-03 02:50:00	t	f	\\xc30d04070302b63e9c09a753063169d2360130ade07f8d354421a7a9d6700b4a0882aa71085cf355accd93f853fec435a7b676534e8db2e10321bead0e0132d289200e33daa5e9
365	4	2025-04-03 02:50:00	t	f	\\xc30d04070302873591b9a0fedbe065d236016b35cdf541e66a92621ecc085c5dd2ea8a86771eca70ebd4db6c406978f9073c0730853f0351b0a3202ed62b9a15069ba0293da5ec
366	3	2025-04-03 02:51:00	t	f	\\xc30d04070302a9a11f3366eccc1777d236018083c97a7f6dc43e4260f6dc204f41cc94459b6838caea7378bfc0b546b78b9ad0d83ef1d2539fd210ed7309b98bf888d784be431a
367	4	2025-04-03 02:51:00	t	f	\\xc30d04070302ffe3e6537a81040d79d23701d8390c059d04686e35f3f71013a2f42aa7b6ff28d74e58950e4c39697148c3e4cf9ca4580687fa77c4dce84e8ee80a8fa91c16e42c7b
368	3	2025-04-03 02:52:00	t	f	\\xc30d040703026450a039a63513e767d23601dfd40c618a8447f6f850b43e52cd0cab115cf3ea6bd7808751fb1596f454f2c2d1536e92cfa23b13e618fa730494c1105cf3f90093
369	4	2025-04-03 02:52:00	t	f	\\xc30d0407030214ed3c2ed86073b87ad2370104648bb2d045a0992fd9149b7d40d7d26b3f37b09ae418ff07080836a27309c58c2208e11a0342b59d848f195a74d6d080369db6930d
370	3	2025-04-03 02:53:00	t	f	\\xc30d0407030262138c19345a513c6ad23601d873719aec41befcd64a54bc2e4131c6d275ae87913e346d71ee34186999af181fe0ce5457bd283b42e8edaf64a1f8383cd95ee4bc
371	4	2025-04-03 02:53:00	t	f	\\xc30d04070302aa8112e2b0cd96a77ed23701242cae405dce384fcdd948ac3d5d6df72268bfe79ad33636c4278d5765313054e272637cbe78628b191e7df97498e1c70db76e9572b9
372	3	2025-04-03 02:54:00	t	f	\\xc30d04070302e0118c64d1813f1c7dd23601f2edac96628c2be9d14b758ac9aa2b4d7446681f8c32f46ab68efc701082a5372f384ec82bc53a49cff7fcaa860dddf68696ad1203
373	4	2025-04-03 02:54:00	t	f	\\xc30d04070302714aabc17655385572d23501085dab7c48e7a3abf2fe408178d9cee351dc60d89cbecc735e6056fbb2896217761938d5a264bd1f9d2d7cdf3736fed090d3c0d8
374	3	2025-04-03 02:55:00	t	f	\\xc30d0407030208e9226bd192197f7fd23601d3f31710a04dbfbdee4a355b9605b3773e472c2091931987c5e7917af7feaa448ec747438cf8defa5d6056b8f1875c88a07f66291a
375	4	2025-04-03 02:55:00	t	f	\\xc30d04070302dac13efae8cec19969d23701427855864acaa0c25b947b398d6bf3badd27443b88b7118546c69a3fe3265050520d2b61f0ade1df81c7b13057ce1639181ab6354804
376	3	2025-04-03 02:56:00	t	f	\\xc30d040703020799b265521aacb46dd23501b4e9ad30c3cb2f3e93f973b01a1d5da773c5a10501dec2dbb383d6d1f8303c8e22030e99584e5b8faa88214e70965c31a493e460
377	4	2025-04-03 02:56:00	t	f	\\xc30d04070302c6f6edf0c52a07c37ad23701542bae6fd3465a35bd203ca18783d515e36a0824c47d7db1b752e8d44f5f60c5eff6e5797ce5ecca7a5bb923b512bddfa6fc4d69ac1c
378	3	2025-04-03 02:57:00	t	f	\\xc30d04070302b2741489cb61fc4d66d23501c72713cc8e10d3dbd4cc08b62d778e7b9bced1f148ab2b7dc3a1b6f02b238bec08f28360b29b6644ed04d71293bfd26287ff5080
379	4	2025-04-03 02:57:00	t	f	\\xc30d04070302d0d819f6efa9ce2663d2370179b61c624f78341699dc866398aff8e14c77068dc6ae4564822c9910a658f8251cfbfe637a7725495a345bc476616a0d204bb226c3cc
380	3	2025-04-03 02:58:00	t	f	\\xc30d04070302cebd06f07500b7fe62d23601fbc051bbdfd722718072fdf75a404c6e1d69e588699b03ad9ea509e4e40c95f94d43931deb883b31fee917668a0d5d7151ee46795f
381	4	2025-04-03 02:58:00	t	f	\\xc30d0407030295d16cbb1ba59fe37ed2360121cdd3ef7f4ae30c28e9722fa9fb0e914b97c99ddfd067329a24e8b4abe13fec6bac35d2f338f0419077bd03459c2a79b4f6b0793a
382	3	2025-04-03 02:59:00	t	f	\\xc30d04070302b2a0025d25c45fed6fd2360128c16b7623f40995e9b587f3082879c748e0e388e9f12987309f5085635b0caf3b9eacbd1e1ef0f6f288b7594119ebf499961d1a66
383	4	2025-04-03 02:59:00	t	f	\\xc30d0407030257bdca520a0271dc74d23701a47ea828b78cea13701f716946553b48465dc602f4f51484317744924e7218934ee0a76474d7d5ca5d9002b0336a93f6cfa88eb96ae8
384	3	2025-04-03 03:00:00	t	f	\\xc30d0407030252234b405eaca5c47cd2360106a8e2308fb8d2291bd1426fa73b97b4db8732c69e911da197857bd9167f6aaef64098fcab0085729dd176c0e5a79f3a63bba1450c
385	4	2025-04-03 03:00:00	t	f	\\xc30d04070302d531accf193a5e3c6bd237017b9590eca616a8702941e6225332236518bc815d9123e13ec223d2ce22f01ffd6a199a27ee5c08dfce2016598d84ea9ba1907ee09972
386	3	2025-04-03 03:01:00	t	f	\\xc30d04070302bad693031a9ea2f67cd2360116f4cab676d85e8016a937287876dfc1994a4c6703b1504d87366d98f343a4cdb36e4eab777ddc44a08022be5e831e95b3a2cdad8b
387	4	2025-04-03 03:01:00	t	f	\\xc30d04070302501d7e324047e26969d23701d6e984f040ef4a701d135d8b3d787570ceb3d27be48d12dc6c0d14a1f9983b908400fe1631b9000cf3c140b3d833f7564a301187a644
388	3	2025-04-03 03:02:00	t	f	\\xc30d04070302a5de3d9f7b95285867d23601a4841e982c909ba297a98a83e222694054768392308baec7255628c788b779f8b99716b0beb974402819481f10a48fe3fbff94ffbf
389	4	2025-04-03 03:02:00	t	f	\\xc30d04070302e18ccb48e846c2f673d237019dbceff2ce68542e993047c000fa2ef43fa80d32024639cb2378f0b28be4680554fea8d309e8d25f0f92aeaf475badbd4fc70b390a76
390	3	2025-04-03 03:03:00	t	f	\\xc30d04070302e4c52bba27c8336779d2360198c4774ce8ac5ee448796ecf25d68f73d85aeb7efdd22dde5c390420dc5ff19d6a0d7b329c968e2d55191e17b47541217bd1b24d0d
391	4	2025-04-03 03:03:00	t	f	\\xc30d0407030244826bf10d8e59f66cd2360159b68f2bdd1970095a04414dd6835d10eb8b86df7613f5a5611e526ebe2cb947c16309bf3f064f4d87dbe63031664f436f6d285cb6
392	3	2025-04-03 03:04:00	t	f	\\xc30d040703029e60440b4857715361d2360186f7632a98cd15bfe88c459f7855e14bb1346c95652aa9e85fcb5e6e4757f9e5af5260389f28bed5a4884d9d1bae9f56614f7d9e4c
393	4	2025-04-03 03:04:00	t	f	\\xc30d04070302faeaf7211e5246e671d237019011b3ada4a195566229f9ef982d326484db9375141fa9df4d5656610f7c18838a7a52d53517c8f590667effbfc617b98da0b8177150
394	3	2025-04-03 03:05:00	t	f	\\xc30d040703026151aded887823a96dd236018643535cf0c61acc8c430685faaea7b9e7c04921d4ba91ece110eedf73a5838a3bf1c10205da1237e9cd96927890eb1772d457e078
395	4	2025-04-03 03:05:00	t	f	\\xc30d04070302be60edf750faafa666d2370149fa906e9dd5e5decfb14f8be7d6846709d0a2e658bccd3dd776b097a8225ac75f9eadec2871568e08ed5a7aed51a782d1cdefd6bca8
396	3	2025-04-03 03:06:00	t	f	\\xc30d04070302efd8f1c36b200e7b68d23601e8b516460b9e959b0d7c7c23108a045c31b333fc340a60572ce01cf42e48081143c4e68c29d10219ac1fc6e69309f9845f75622921
397	4	2025-04-03 03:06:00	t	f	\\xc30d04070302a9cbe002ba03758b73d237011bc0738f73b81d3ebf8f6e596ff71b25684d191c095ea4f2cc57a9d317898bad230885c1eb73b86dc6c19f066b098b8e9519878203a8
398	3	2025-04-03 03:07:00	t	f	\\xc30d0407030297ecbcd3be1bc98b7fd23501fc604e44a1103e57496e61897bf72abffd4ff12ea62edef80703222926de87d416fe098f30bba0a94a7aa6a52026fc461f6f6918
399	4	2025-04-03 03:07:00	t	f	\\xc30d04070302f3c8d1e0e24e83ae79d23701e6b5a3da41ddd32542a03d2b81f3e068c98742502c16d18b779d54bdb2264e210fff3d9b64d2cb4aa30f9ebaae89ec169e49e82a35ba
400	3	2025-04-03 03:08:00	t	f	\\xc30d04070302f6aab2a8812098407fd2360140c5b23001cef5a826e3633871e7381d7daef5d083f138a7bdaa502e9b4e1c7c1c495897be7858a61ea43ed841397b5e79e1015913
401	4	2025-04-03 03:08:00	t	f	\\xc30d04070302db1fa1bf0d08cb806bd23701f36d50453759aa44d7a0ac24738e4710c19c00d8af836eccf495f83b42ef931ffe18221784e4c8c945925230e0c6e1a86cd9907c2c7a
402	3	2025-04-03 03:09:00	t	f	\\xc30d04070302e48f864d2b7a4bf871d23601413d7187427016eb21ae35b828329cb49538c0ef247e1a6e851d737ab2579e0c4f8f985bf18fb0594621d74d66faa9cb88a64a84bc
403	4	2025-04-03 03:09:00	t	f	\\xc30d040703028c32eb8000ecc55c76d2370134fb1864021864de127cbbd3b57f666dd58326bfeadb6f08bfb227c5754f693073a78f8bcf757321740c28a87478d84a6b9055e08612
404	3	2025-04-03 03:10:00	t	f	\\xc30d04070302611fb79feec5f13977d236011c940ee26201f9e5e0f2918b1f654fb715aecd3988ec45a04b88e3ddc82b05b0eecc2b4d15525e682aed51305b5b4fcf9056da6075
405	4	2025-04-03 03:10:00	t	f	\\xc30d0407030273a60f1a1959efad6ed237016fd80a7dcff67734dc2fed4e6c59e29f83d307e747352a8c18b72ff1ea338f452c0aaf529b2268a07d03a6148ce254d7ea6896e8c634
406	3	2025-04-03 03:11:00	t	f	\\xc30d04070302c91167183ce375fb66d23601f1d1be839a240bcfadbcc99dc040edd92619790f5c08c03737ad8ecb9d781dfd498819d0055df89850c63c5faf4ad2d4bad401f316
407	4	2025-04-03 03:11:00	t	f	\\xc30d0407030264d7494d93d1db397ad23701a7623a34973e3d75dc50c4a07fa56ae6dfd9e97df3bcc7708737619e50b2b62216be7ebbdf35f7ad00479a1ca227ab0a5ea2af24ed5f
408	3	2025-04-03 03:12:00	t	f	\\xc30d0407030269940d41fa0edb3075d23601fa80e118c5fddb2625479eea63d21699f9f88b61d2d1a54dd1da0af53ddbc049563217542b212a9bab8f5d91666bc1e83b6f01e894
409	4	2025-04-03 03:12:00	t	f	\\xc30d04070302d95acc50cbe1773a73d23601f2cbe1ef87328d6c1156ffa52c9827b18c2937f165942fe8b12af603d7c0c3e80f30818393a72deaee9755fb5ca047e6072e69444c
410	3	2025-04-03 03:13:00	t	f	\\xc30d040703020c16d4c7609c1cb279d23601203099a31e03e2f8f4b32d477bf31c948d77392df12b403227630460b1d753429ec5b3e5bb1c70be7840c86a2fc1882067c5d300f3
411	4	2025-04-03 03:13:00	t	f	\\xc30d04070302b58cd16c7b82267e72d237010e685c4e1ff671a905cbbc1b1d4bf9d079e4df8370f6e174f1c99b04678a21afbc6778819e6ab186b97c8b8941807eb0e327adec00be
412	3	2025-04-03 03:14:00	t	f	\\xc30d040703021bb943e481439bef73d23601d1587be2098b6cb17ea07d745dfbd51052881fe75d5f5c28fd92b93ff9e5ab2fa460f6b999dbc1e27f92525604fd1767c89978dd0b
413	4	2025-04-03 03:14:00	t	f	\\xc30d0407030254b8f0dc0a6f94b166d23701748d2f291ecd7fa5cca4c78fb77d2368c6111963e53e9d5fc54d61e02d161873e544b7a6eaacee887c5fec58276bc8d655cdb691f887
414	3	2025-04-03 03:15:00	t	f	\\xc30d04070302db2682c1307122d06dd236014427603d3bcaf307b06fa43b53cd1459919eea2740e49f233fc0ae6fdf93afcf475b514b60fa107e21e839ef4b956788ce60f22d4b
415	4	2025-04-03 03:15:00	t	f	\\xc30d040703023ef0e04ba156e2a971d237018bfa6568fe9d0dee023c02879aaa244c74971bb395b64ef78f59b90d31082e243f530f0e488094636d8493e720782df2feee2274a673
416	3	2025-04-03 03:16:00	t	f	\\xc30d040703021d99443a6abe4e7a6fd236013befb80995ede7f317d8598fa8ad8f98efd29ba1814092336792c79191d7b70b9b3c57438a97381cdfd9e38d5b4f7bea030d4d0e77
417	4	2025-04-03 03:16:00	t	f	\\xc30d040703023465fe26b28710da79d23601ad66c6c2ac869272c87f219550441f38275acae1be73fa2ab8544b5830560acc4ca1308763f2da8d77e43823791e8f354fc38c5f1f
418	3	2025-04-03 03:17:00	t	f	\\xc30d04070302285a181f83a99c5962d23601261c38ad7ffb338c34873690f04520b8d6711b2825de5d8b3921ddfb68eba103c7427c2d18a42b9eaf14460a69ce70bd4182edb99e
419	4	2025-04-03 03:17:00	t	f	\\xc30d040703026b8db15d793bcd9c65d237012b787299fe01c8abb9e60d3515683a9349dc33e8d71ecd09f2a16905deeec4780f06f32c7d5ccb931f13ccf335322f6d71f0d90e487f
420	3	2025-04-03 03:18:00	t	f	\\xc30d04070302d0903bf3f27214c870d23601c6cb0502cece134514834f27f934161b9c86867b1dbe28e7a260c8e988a0dfe4b224bebb3c84f74884a743850687ca107770148592
421	4	2025-04-03 03:18:00	t	f	\\xc30d04070302d8d2475dd75b1e2277d23701d714cfc96305c7f7b37ed242fb65aa1666b89f451b46a10e2430c691513cdba6fd4f799aaba920e6669b71ef6b9149b721e77d003adc
422	3	2025-04-03 03:19:00	t	f	\\xc30d040703021366f68ea152a0be60d2360139479c039e0be6182490221ab30a83847100725b438192ca122411faa7b68b0d05b920f60f29999572c8df2e82cee3d845be07dc78
423	4	2025-04-03 03:19:00	t	f	\\xc30d0407030203b92a98732d53e275d2370175ba5283eb9e3f0a95c80c93d0bee5bdc8131cf24e9514578e2320cde6d5360123789de3abaabf02a6e21264845f40f7b904227cb15c
424	3	2025-04-03 03:20:00	t	f	\\xc30d040703026b43ea051e904fd077d2360198a509695f937f4a17376466b848d15b8fbaca7c494f53c2f1da29d4c741e2ac9fe6d0cb5fa7231b9591161105b83ce14564a5526d
425	4	2025-04-03 03:20:00	t	f	\\xc30d04070302cd0adeb96e6d7f5e6fd23701f462489cceb08c70dca348a40d10c6daee975bb4ea1d6a52a8aa29f518b848b0c21a32ff58d5c321d6a3a19b3dd708b96d137dc89d52
426	3	2025-04-03 03:21:00	t	f	\\xc30d040703024d61f110a9fc82a867d236017d5f2189d3e38e821195578572922dd1995a5aecf26db506a9c5276edc02132960192491e860c9eb8036139af5b8aa2067d2170065
427	4	2025-04-03 03:21:00	t	f	\\xc30d0407030287ced7591f160b9c6fd2370133510ed22720275ab0f735e0fad0413533535216dbe0e06e7c7297ac762c9093d14b0e72a4d980539ce8cbc7a64c6e25c57064ed7ce5
428	3	2025-04-03 03:22:00	t	f	\\xc30d040703024132ffd55c4a0e9964d2350133ea0fdba71deb607925a3fb5ff0cd5923255316c08ce702956355aa5d841fe6cb1815a34010a8ed8ed695814b5bfe67e40e4e5b
429	4	2025-04-03 03:22:00	t	f	\\xc30d04070302272dde678a822e1f6fd23601a6b1a9872505206ee9ee712c6992b1393d5a54c551177c9a738f032af4c0cc8550c9e1733a98f10dea2a02e4c182eba5b8527632fd
430	3	2025-04-03 03:23:00	t	f	\\xc30d04070302b81774538694feb070d23601d6dcd468d7528f5c250d6d12000e56d43abe6aea34507bdf17c674ff7c5eac7f4a8a15b828b4b63912621cebb791cde7dc6af1aa48
431	4	2025-04-03 03:23:00	t	f	\\xc30d0407030253bebfb5a894a13661d23701a2c262fb8f2300091a0c9deb2e334a91712831b7a1718e978ff995c0171d16d03f033bcb19c64da030d0a5180e8f2363175df42f6cb3
432	3	2025-04-03 03:24:00	t	f	\\xc30d04070302e3483fe78a1823cc71d23601cb98726815c74c75e9f78bcd628627fdebf961aa5fb286d714df4b05b4b6388fae76e693bbf147afc3c8663faa292fc27105a86e97
433	4	2025-04-03 03:24:00	t	f	\\xc30d04070302adc2c0af8df0183f75d23701c8771b32ffc02b069301b39fe6e971a52e2a9cbb06f9b6fecbebc209561aff9273116539206badda61043b32f1217ab8f9eb962205ad
434	3	2025-04-03 03:25:00	t	f	\\xc30d04070302be718cb9bde9b8df71d23601bba6ccb76cb54d2469e1cb5440c00c487558529b16406f77ac97ad63ea41bf4e46382151b1c6c664eaacc64917cb94011fd770e68a
435	4	2025-04-03 03:25:00	t	f	\\xc30d040703029a5b0ea3e80d9bc56ed237010306ee660e1e8e23d2bfc66584b9931c32bb638dae4087451eda7bda770a0f822f276e8fc55ceb9adcd2826e4d6b2e4594a69ff53b89
436	3	2025-04-03 03:26:00	t	f	\\xc30d0407030201c82394a1cca34c74d236011ebff38749638d88adc3826244aedd500ca000874072fb02fcceb34760a6ea1f884bdd8e6cfd7de0bb4c1f6dfbce8a7e5e49a4609f
437	4	2025-04-03 03:26:00	t	f	\\xc30d0407030269e8bc72b79fc9c169d23601745f78c84378cc8c0d059d0df5301c8101a67d7290a0ac67f8a9ae773e22f681c2562b7ee80fd51fbcd99b25d02ff927fd32384250
438	3	2025-04-03 03:27:00	t	f	\\xc30d040703028abe26d2aefd129a62d23501d9399d135fe59decbbbae58ab0fe047b01b6862b8b9abe8f19d8d53ec8c20faa99227c1a8db672f6e64487c23f6818481c4a56d7
439	4	2025-04-03 03:27:00	t	f	\\xc30d040703024b123f99cd47b17278d23601ad9c27d79007faac576cca7d0926d62c56222fc8e8fc6190b185ef9477aff9f266351dc05704b75b0ca523a7e4bdbf3f64a3979595
440	3	2025-04-03 03:28:00	t	f	\\xc30d040703025e5485468a985ce074d23601118c96a460e45d062ae41a98bb8907bee617f06284e2385b5c5e4bb4de9b3d5971ae30dbcad9508bab9acf85b8211e12cf95dbcf42
441	4	2025-04-03 03:28:00	t	f	\\xc30d04070302ec5e2bbbc95d84897ed23701df54c88646a5810fd2c291c392b6c34df5ffc35fe34d809db82d239179ac142bc8fc33f0c377f619e9c38f0b74b1cdfad5d1200b8594
442	3	2025-04-03 03:29:00	t	f	\\xc30d0407030265b76cd0b085755672d23501ac1f5978053188fe6781ba33ff04523112a93d0e40a5d2944253e173afc7f0e6d3c3c4bb7fb3ac838b719085e94a20c18c7891c6
443	4	2025-04-03 03:29:00	t	f	\\xc30d040703028ccb25e3bfd7cd5b64d237010d997d0f7624582a5b2d9f865e17c3e35e4ae0611ee0c381ecaae991d9335837fa2e4c9510894c6b6693c4e6868709d98cd4bce3112e
444	3	2025-04-03 03:30:00	t	f	\\xc30d0407030203dec26306aebcc679d236011a81438d047202a7d1232760a165d0e2332e8e4520a19f23e380e33749b0eeb788927fec7e1acec0ad4716d9fdc58e6a95411c3b46
445	4	2025-04-03 03:30:00	t	f	\\xc30d040703026a0ada214f676fef69d236013f6da707146febb394663b356b6ee43ba221cb0ec0e0c710207820b1e65f85ce47fe0c3d941364c8baa0c67634bab1574b21df1c80
446	3	2025-04-03 03:31:00	t	f	\\xc30d04070302d27aaafd20592ad87fd23601b00580c4e94bd7351936010b5d9e8fbd2a5679524906dcf006a8c7c18e12ab2bdb35fbdb7e8754b6ead6dd0039091133b01c2ac607
447	4	2025-04-03 03:31:00	t	f	\\xc30d040703023d0f3300338917fc6bd237015791de0153274c6f52e34415f52a2185dfaa08c5ebe0075bd911e33c5e53f578316f01f4d3696d76dc56855e74b6a82cffd0680170b3
448	3	2025-04-03 03:32:00	t	f	\\xc30d04070302b2d13f0d57c6e4ae63d23601fd0aab397dc7fa0bbcfb0aa4f8b33af48dba4067b4701bb20a150adcbba399e4d4e6b3a901d5f195a64b33ec830e6e7e49092d30ad
449	4	2025-04-03 03:32:00	t	f	\\xc30d040703027713f45a02e1ff5f64d2370174334b9349c3dbadec522ab92971b4d54bc937c076eeee039c67c97afcb0853e7031f730052a229096842a68e6b6a786630a5aa9acf4
450	3	2025-04-03 03:33:00	t	f	\\xc30d04070302bd90f17a541253477dd235018e7a099eb99f22afc5ae9e277fd36044d36b4cc7890fdc1b432119c411e67781ca487b545a42198c45e16fc2cc715cf6faeb50ae
451	4	2025-04-03 03:33:00	t	f	\\xc30d04070302b822f0e7f5d1e40076d237014d35b23ff84f553acc78f923c52b818820b5e38336cedf3031b4346cfabe2b58d1ade9d1a47c60f4d5208eb9b5ea0cb953efe4736ccb
452	3	2025-04-03 03:34:00	t	f	\\xc30d04070302ad0e7875ec1783d475d23601c54b243b80c50a5f54bf12b0dd27da453189e56e526dd14e87e31774a8d3022719a809c403224cf5b6b18c0122778abafdd981d8be
453	4	2025-04-03 03:34:00	t	f	\\xc30d040703027ef4e408969caa8e69d23601424988c45bfaaafde0d3e83b1e7ef849340dc338ae65e84df0795f24516cf99b572af069166d1714e800143343f8333352d34ce2b6
454	3	2025-04-03 03:35:00	t	f	\\xc30d040703029d3b9402362b51206ed236016e1204275cb0b5a69ef8336f7980682785471eff802f94351448e83ae9f29eef41190eb84effbd6c3166d4bd6d53c9ab30195a6f0f
455	4	2025-04-03 03:35:00	t	f	\\xc30d0407030250f985bd73e47ca460d23601f284866aef0f2c59ea4872aec22b9a5baeca487e53ac2edcd09595c39dbba7c8276b8e2b99bae9bfa54a375ed5bba8b47e9100474a
456	3	2025-04-03 03:36:00	t	f	\\xc30d04070302ec464d25e2e5f46c7fd23601e701fd5574b77f4c708d5d614fc52be34420b2a64c7d9468469b8271b3255a6f3365ec9ef869cf816c685190ac1d9cfc4649718c65
457	4	2025-04-03 03:36:00	t	f	\\xc30d04070302335692c12bbbd00771d23701fd591cd28808b1ad073fc92cfd500d38225d56a8145a9731c5cf1bbac41a834c34c6bee28e4115ba88391f908254aac9d93c665e6b41
458	3	2025-04-03 03:37:00	t	f	\\xc30d04070302d0edcd150553832f6bd23501b22230736cb618aba6258476beba0f57628c39791e8344629718a9dbc737b0ba3edbacc5de1807a899a27542acb65d37df728e60
459	4	2025-04-03 03:37:00	t	f	\\xc30d040703020a01b77e0f99535b70d23601829d41afb36fe11707e5b490a45b45434291988f671d91d5eb528ba128de15080c3bd2c97e228b606be0f349859459543fb4fe38de
460	3	2025-04-03 03:38:00	t	f	\\xc30d040703028450fcae5bd9d26f71d236019759dedc29ac6c14ef367ca26c163fceb84e2001d369855b272983fadfa617a1412d67ee92bdb8a917c723ccfb5429742ea64e1a92
461	4	2025-04-03 03:38:00	t	f	\\xc30d04070302908efaaed49c30987cd237012d9333b8115168bd698525863de15118fe320f08b7e6a3c64efb35842970b56381b41334ecbe8412a366e30c2ef2af18100414fb6072
462	3	2025-04-03 03:39:00	t	f	\\xc30d04070302382c81b64d83bc9b74d236010ccb320f4bb715d233e5ff874d4813bc843418ec0e111dc3b16d8510b6b191a85b11452c29e6278d45d418a2bb1a4281f79236f5ff
463	4	2025-04-03 03:39:00	t	f	\\xc30d040703025df58b9afa9a301c63d2370105a1e19128c6fd6edecc8a1c46cfd4fc8bf84d9b5553b063619d73007be59742f0a4ddf86884c65fc68e3674343ff303dbf133cb5fd8
464	3	2025-04-03 03:40:00	t	f	\\xc30d040703022c46e87c649d08f17fd236016af80f8bfe51505a3bfd3b8c8c330a5883d56b1f8d067cf6c1a43589b9af3361ed37bcb5f9b4c78db8322bd2e38869ed6b112e99bf
465	4	2025-04-03 03:40:00	t	f	\\xc30d040703025b016e6009de502768d2370130248ffe2a576a5c425bbcc750b3ddf8f91ddd4e34472af094677b589a88f2c5e79b4235ba84897cd033a750a5dc5b6db568a424bcb4
466	3	2025-04-03 03:41:00	t	f	\\xc30d040703027ae03dadd7a303b97ad2360161cbdf5097387ae686e57e98ba279bcc291c0b29a22921de4ac569d14efe72d940540e4ab34d1d240c51ac54d054d3695bdfbd2410
467	4	2025-04-03 03:41:00	t	f	\\xc30d04070302e5902eaf0845af5a6bd237011d6131feff4b7461fe1ce0600a6b04848fdca823ee4ea11c954d97e8f6dffa795511dcd8492a6f38152921319de52697f24f8567fc51
468	3	2025-04-03 03:42:00	t	f	\\xc30d04070302a790557d46721dc270d23601719ee2d69a1c997615d1700bf555f4a36baed331b193ccd733f126c5e770dd1827dc88268d0f08a664c63d76df3d082ebeefeb76d2
469	4	2025-04-03 03:42:00	t	f	\\xc30d040703028947c88db703b5ce7fd237010b37331ae3da98274e1e13ab6736ce3e87a621cd82f1779f51902ef6388042d30f6a97446bfe35b9414821a6472ecebda9ffa250fefe
470	3	2025-04-03 03:43:00	t	f	\\xc30d04070302d5ba5ed77a2d683f63d23601675f7c9680c1c37a9c79c8a57dfa43948c32c20f87d71e44ad6ffd2661eab0536077ed26e9b3f624ff97d1934f91299478513b39a5
471	4	2025-04-03 03:43:00	t	f	\\xc30d04070302aced5f9a20ff108e66d237015d65003a2d760063d13c03c55b6424943bfd90336884252f587b6005fccabd54049fda0a2aefc1a99301a3a6937e7c1e700a4017cf00
472	3	2025-04-03 03:44:00	t	f	\\xc30d04070302bbea077b54e3fcea65d236016cedf5afd677fb8e31f020bdef9bfad6f0fa046e6a37216fa49db1b225b44086c3e2532286f6bd1ab3a98edf47f3947f24bb1bb2d3
473	4	2025-04-03 03:44:00	t	f	\\xc30d0407030230168dab461bc67a7bd237019c9fb91aec9126c46a5a34af0ab7471ad58158a56fc8bd2e0b186e0485090eae18b44aa73b3ced479ef53bbbc7d948f6007a3423bfd5
474	3	2025-04-03 03:45:00	t	f	\\xc30d040703029a102824c9ee0a6c69d23601d1063545c51912f6494c0378d854bc3e8f20c020b3882e86ac6b1e52327789c0a1a899218d98799e7fa13cbeab944fe5ce1b2f0d9f
475	4	2025-04-03 03:45:00	t	f	\\xc30d04070302e42b48a9329266b46cd2370123845fbbf236c593a9050d8c3931be442c274dbc1233a4273280eb1d955886f2ccf77db6f4f903af95a3336d818bd1959adf83a688e0
476	3	2025-04-03 03:46:00	t	f	\\xc30d04070302eeb60f04de3c50fb66d23601afc01164521c7b97f195e5205bff33457984323adc50e436fdeb54fc1f4fa3c648f5e70c0c10de047ebc7e6654cde9af78201c2006
477	4	2025-04-03 03:46:00	t	f	\\xc30d0407030295430d5ebff2270570d236015db320f2a2f2adffc36efa1e09ab2e89dcbfe2bc5f3dfed331e23254c9d90a3a53ccfbe8cc5aaed026f6297e525d8078f7511c3e6d
478	3	2025-04-03 03:47:00	t	f	\\xc30d04070302d3252e8c23c8266f7bd236019e4a9453ec0bbcdedb26317c4dd1facf793e1706316a483d87813b7e72d289fcc4af8e85cd186168d262f783302f0433776a68538b
479	4	2025-04-03 03:47:00	t	f	\\xc30d04070302ad28b3824a11451768d23701df43b0510c9e277628614b6a2464c265270c6e27da4253264700168dcc3c3ce55d5859d07592646dc6d4da4acd94efc40fa52c0f0e2c
480	3	2025-04-03 03:48:00	t	f	\\xc30d04070302f9a96167448a2a6c6ed23601a6f12d68fd2d0a35b023303d52a1a140fcdf8c07a6a96db293ede5c5ce6c4391e7c71f1a1cf55d48dd5d487a84ad1abc12e875973f
481	4	2025-04-03 03:48:00	t	f	\\xc30d040703025eb8ffb372d8dfea78d23701344be2ffdf567699e80adaeea27646109b6975b8543bdcd7fda043d93b945010f4eccee5669d51c03b8c9eaafac869bb7e688649728b
482	3	2025-04-03 03:49:00	t	f	\\xc30d0407030233d76ef5c63c7d177ed23601720251eec80fff9de433e439cca59f8e9473cd57f049ab2715ae3be7031bb4f370da244c2112eef4e0ea04fff4de268052c62fd6c2
483	4	2025-04-03 03:49:00	t	f	\\xc30d04070302016a9d3cba96a0016fd236019b9f97148a177ba3f9915bab4668d8677498d97b3066c6b2f74b98b8e58cfeacdfd19a530eae33724887e66184e37b22c817ab2fbd
484	3	2025-04-03 03:50:00	t	f	\\xc30d040703023b880b4a4a1d648560d23601caa16026664125cd7094496b36a1c3a22fd138481ee6904088998279c166c3ad5456abaab7dee4bc1022709145baef1084781d94fb
485	4	2025-04-03 03:50:00	t	f	\\xc30d04070302f37be1bb5d2d8ce876d237010b4798cc0cb84a15ce94b853d06e679db5ef3754d337141ae6aef142a856bbc235c1cc9de98dce4ecab781338e31847ed024be562a31
486	3	2025-04-03 03:51:00	t	f	\\xc30d040703025426655671a43df067d23601f8d39b41864d259c99fed144730ff09b05ff4b2ba3d4bbfc9df8097852aae71ce4a4793eedd382931b20aa14bf5398639004084b56
487	4	2025-04-03 03:51:00	t	f	\\xc30d040703021c36761581f3d85e68d237019888825b8f59de8fa258971472eef3f63cba91ba4dd6d2c4b5468097ee2cda03ccb0ceaadfe283e33855a721f81be0e65d3e82c05547
488	3	2025-04-03 03:52:00	t	f	\\xc30d04070302a353ca82ee2751747dd23501fcb59f664a78014baace828af13c7219a04e1cff5d841e7d221f8591e63236d8aa8b6c3eba47d49eb27197e34ed1b7443ad0d4e0
489	4	2025-04-03 03:52:00	t	f	\\xc30d040703024917b72800d69e937bd236012144337cad55cf4413797a45a944ea5d2ab094f2277f29bb3542a79984a97411e711f5a438f31f584e685ce4f165ca09aa489b8709
490	3	2025-04-03 03:53:00	t	f	\\xc30d0407030254ed2720a72d38f17fd236012a7a6d254da71780c6e48b37a3f56dcd39ad0465e993816f56e7640896e36ddcecdcaf9e0b3425cc7bdd35fc2df643ab20d14344bf
491	4	2025-04-03 03:53:00	t	f	\\xc30d04070302942bf95d070df76476d237011c06a35482b12ea1c4dfd2322091c550c4c1cf7ead8f9a282cb16570425daae9936ab035620dcce276e2d24a75fac2c9f75f9f3d740b
492	3	2025-04-03 03:54:00	t	f	\\xc30d040703028566ae596e9631957ed23501ff8a8b56e51b956c0588fc5dff586d0e683a56b3fab44f687963646e2fe8f513f519f24bcd1f448f71170592ee0dd39b305b096a
493	4	2025-04-03 03:54:00	t	f	\\xc30d0407030238d9aa95578fd0207ed2370117cfed891890a4782179d4a9e47054ad34c8f9149c95d7672c4e4bc61b3ece095f213ee7a2fd85671e5189f6d0d29dc32d8467404615
494	3	2025-04-03 03:55:00	t	f	\\xc30d040703029aa454f81ddcd2046ad236018a713810f41192f2bea7dd6f53f52aa10820f7a85fdc6bf5174ccf561edea17c97cafb703302f5aa3fac0e855c2e9f7022dca42b1a
495	4	2025-04-03 03:55:00	t	f	\\xc30d040703025da4b0f7253c5fc075d237013b222d70d58d6d9c6eb21a5aa23f8ca7fe8e987d619ca959c4030235f8e3fb6e32fc43668113fa44ef43b130b8c0ce1ae3812e9bf410
496	3	2025-04-03 03:56:00	t	f	\\xc30d040703028aa31710dc00c3cc61d23601db165acd46e622ae9f8e6f47ead56e055304be3441ccd41ab88920069daaaf28d3f1d4151bf5bf8096fe708fd6657059ee72b60eeb
497	4	2025-04-03 03:56:00	t	f	\\xc30d04070302f6e4b9aee976903b65d2370156945b4fd56c6b7b987437953785186cc2054fcd88a5e1c6d81763cfef809cda1b7064e03ba1cf425c3bc6072139abddb3507eeac102
498	3	2025-04-03 03:57:00	t	f	\\xc30d0407030261c4c80febc0924a7dd23601e90d07233880197ea22c747f9d961d4c59cbd0218f51694340e403ec80b5f30ec7bdb980609bf93fed09c366c620630065d2103077
499	4	2025-04-03 03:57:00	t	f	\\xc30d04070302b4a44fcc01f2be807ad237015217ab5d4ab95f8a58fc303b5887e2f45ce8a65c7f85ee50dcbeaf5da8d1ed515d01c0a3a7f05fcc5200e8f364bafbbfa6930b557b7a
500	3	2025-04-03 03:58:00	t	f	\\xc30d04070302656048961e7a9a7c75d2360118fef0fb574e78b19f5378022c655d1ce49dde9093677da3b2d53a48b17bc9a6c4bfeafea27436aa7e9be0502b3a12f0e96687155d
501	4	2025-04-03 03:58:00	t	f	\\xc30d04070302659882f80569beb86bd237010aab80df3a349bfdafc6373c51bdb33a310ccb4efe47f5b6a30da38d5324feb8c18958ba2bd0f310ce48d2290070c122e978db439e65
502	3	2025-04-03 03:59:00	t	f	\\xc30d04070302ee1426c8b8f2b90965d23601ecaeb616cd1132a39aa94234e4ed58d9a9735eb81d77ced53c92db985c3f99fa23f8d3af541834383b1195e744df8feaece3f81e6b
503	4	2025-04-03 03:59:00	t	f	\\xc30d04070302b31d2df63270d65e76d237013c40d03c7b1ccc3a089d50eac3ad1d8ea5e4fbea402dba93bf2d4c794774bbe786f6d11fce19937f5487bd194cb52f780d2752b485d3
504	3	2025-04-03 04:00:00	t	f	\\xc30d04070302bcfefc2f7abc9d5079d235011fdcba0ee22848e801e4c728cb555c94ab60e74cb286f922819dff8a90a20b60e89c61b40880b8795cfce578c10146b0f128e9fe
505	4	2025-04-03 04:00:00	t	f	\\xc30d04070302b07c11883405607464d2370120382e0a9ab1b50eb053c98895b078ada7bb49b6d2455a65091fd935034916ae3560829de98b294ff683a8e8fc5fe44a964befdbb3ff
506	3	2025-04-03 04:01:00	t	f	\\xc30d040703023320cb1cf62cc7a67cd236014c6fb599f1b09d0eb3d8a1c21117b55433da0f8b9b5657ee62c08bc932eb6f375602e34fb23dd8cf118ecaee85f2820b723c85af88
507	4	2025-04-03 04:01:00	t	f	\\xc30d040703020f6636323d4e8d937bd23701fcc829c490f6cb0a44b35d0579ce15ba8676edd678f9ae2f2316901c973082d13e7289511098200373e75a8c0244e5ec5357bce70a52
508	3	2025-04-03 04:02:00	t	f	\\xc30d0407030217286931d1ba813e7bd2360117497e2e097fae0b5d1688c9ee83821ba15725e0631d49bd1a657b7781d6d5e9ffcb5643912f1c0b0e5cc3bc3cbc349b03a1c1858e
509	4	2025-04-03 04:02:00	t	f	\\xc30d04070302e0583ce30b2dea1876d23701e6bfd0b68c541afb7626594b43dc0bdb6883da04ce5f99f27a1c81ada72ba6755ab2a876b36623d0b9a1b45f39a49abded9171d98142
510	3	2025-04-03 04:03:00	t	f	\\xc30d0407030279148eb61cc3a3317fd2360178e645e3ae4dbb3f814c7dd9b5c6146d1e7fcd0a808585bedbdc765e313c616485cf5348bf227e3b337619c6654e759d03e4effe01
511	4	2025-04-03 04:03:00	t	f	\\xc30d04070302c82cee360c2f769a73d23701a21987a5632c043e44e67061f49a28003ca893491ad688b76fba8ea06ff51fdab3461d2aa77f8e6e9749271f21fd267472557e2baf63
512	3	2025-04-03 04:04:00	t	f	\\xc30d0407030220d7068603b0515c76d236013d1f411aef2160663a07c8a2d361a2b6b965d5cdb1a0a9661c67c2ccdf56e41f638b6fc0da8ffc6f5e38f98f071f4b6a24afdeaf23
513	4	2025-04-03 04:04:00	t	f	\\xc30d0407030259223d5fce579de767d23601b6d751073b8dfcb88ec56c6b3619e08f1ceadef74a913733f1afc7ac72cebb642a8e2c04fc972d6f445b8543eb7e311604e3c06180
514	3	2025-04-03 04:05:00	t	f	\\xc30d040703025dd1a807c444fa3771d2360108078aaf23157e07839cc14c31704880f42a6916213bb85b06d345a0894aa6aebff8b6191fd6b72d65ea90f0dc406b7bf9f9dc08f8
515	4	2025-04-03 04:05:00	t	f	\\xc30d040703022c2e8d58e4ace7557ed2370138f01f0adb527ba5c9ca645c2b60d8f4cdc72b0db535bd8cdeedb799bf527a934b26409369b4b2204a440b9619f2a3c65ab982cbd643
516	3	2025-04-03 04:06:00	t	f	\\xc30d0407030260c47c979143ee567ad235017d6898bf1a660f82e8647b4a5b67202ce1e1dff20cbdba5ade91b980d73ac154c65fe17475f9692717c77e681771c4de510e8b90
517	4	2025-04-03 04:06:00	t	f	\\xc30d04070302bb8503903be84c7a7fd2370143e090c2ad41e26b40f777d00227ef182df2647091346e761e86c041c2c565489a35c29179172043c35c0ee459f83c597dd2bdeee87c
518	3	2025-04-03 04:07:00	t	f	\\xc30d04070302cc358750d9e478df7dd236017cc139ce91c081914efdc6f07a561a960f723f8400c4a6cb5f3a68acb022a01f72dcb30c27b5f93908e9d12af07f3b2ca1129499d9
519	4	2025-04-03 04:07:00	t	f	\\xc30d0407030255c1c6e82c0c34487ed237013bdc08b58d7f6503514d18d55bbdf4ac87e6d86c988f05585e25a31080323141a2093a64e92d4e04f9f68cb4ebf12cc9f553b384eb28
520	3	2025-04-03 04:08:00	t	f	\\xc30d0407030256036250121ecf006dd2360144a7f83f549df279d787d20e0d83c5da980909c7e9f9e1f97f9a8f9a8f21f97ea9aa4f48b0797b3952e28a2edb342b963c48334167
521	4	2025-04-03 04:08:00	t	f	\\xc30d04070302b20bbbc78e4653e97ad23701a33203c256e9b7bad2464fd2b1b5b9416145a0eefbb7a7621d0f26126f515e1287ed9917a6a16f34b74c36ac0fdbb192986e10ea9a2a
522	3	2025-04-03 04:09:00	t	f	\\xc30d04070302053f897243edf6b86ad235018498fa681fbb4131f4aae7c0466b6266a1fcf79caf23a2d150f7088e8a7d9a1426c0fee5bdd4164160ac0c6b93cb7ee1626e42cd
523	4	2025-04-03 04:09:00	t	f	\\xc30d040703028a6d4b6908de9c627bd237014cf8f39edc51bbfc5e6c9d768b3bf89f8a25d65077125dd46f672305f97efc94bdb5f1875b8e5ad6032e29ed71499cb40a5663fa9d50
524	3	2025-04-03 04:10:00	t	f	\\xc30d040703023e9b8781a72624717fd235013eee5b5010ba6a87d28d982f036d549ac8c7569912b9f5d048860fd798611b416c82721795dedbf2a058700851bd03a0534178e2
525	4	2025-04-03 04:10:00	t	f	\\xc30d040703028387e7479888dc116ad23701a19fb260b5c3e64af03e2bc75afb0b2ab4892e7b7fb480c408f55c511d7d5340f2155b3727a0763eec69d483cf7717417f973c88895b
526	3	2025-04-03 04:11:00	t	f	\\xc30d040703025870f7eeb46fc95470d236013fa38968752fec86971fc425cb5da2c69adb42e93320a5c668f88e38e20e570e28d89191570f7a8ccc075cb71e3abf820643640ea7
527	4	2025-04-03 04:11:00	t	f	\\xc30d04070302ee47cafe35f8265674d23601c43e7a8bfcb3aabe5157dafeb76f8823b3ace7263cfe05a7aaa298bf42a148cfde0952c9429f62803bb3fb2bdd679604f5612e21e1
528	3	2025-04-03 04:12:00	t	f	\\xc30d040703021a866bfd20f2954f76d2360181609432e14a4043adde47a4432f4a26ce346a0ca410db772f53a319bdeb9e074e38dd5f8b676b5b165b4e9a1c425b93b20e928049
529	4	2025-04-03 04:12:00	t	f	\\xc30d04070302d022295e29f40c3b6cd23601a665818265ab20122c5dc3364c55706d65903046ba0f0b866f93b98db730fed548d204241051c38bc96ad4a0271d5ee010892f35dc
530	3	2025-04-03 04:13:00	t	f	\\xc30d0407030271fe3d20750c4a8266d236010278b72f786bd6e13b3e96dae4ed648758123c718c8f73e7de70add43195a1cb7230afeb3bc911f951019abf0535bf4e3d3d66d0ef
531	4	2025-04-03 04:13:00	t	f	\\xc30d04070302e7602bba7ca116627dd236019d89745cff17cec675f638ca0084c9ef0b5b524f4e908c197d44f6e84a706c9476eeeabf46d01f0b36e5fddd0fbf592a2cabf2628f
532	3	2025-04-03 04:14:00	t	f	\\xc30d04070302a269ae626fc5fe236dd23601810f25927ca65423421b85249776952ca2f912507003a23a4b574c0c75a1a58e24218208abfe83f05411bdd456c6329bd665a57eba
533	4	2025-04-03 04:14:00	t	f	\\xc30d04070302386ccaca412cd7856ed2360194eea92c2af80b12ced3928c7cac3ddbfae1e93d44a7223659c71c0460a0dfe2f96f664ba0e261ea7628296c1233b58f637e4d6326
534	3	2025-04-03 04:15:00	t	f	\\xc30d04070302a1a6c8b6b08b324869d236013c49be0e729699c208663980a80874829e02fec04055ca51cf33ed864c642d2045c054ff2ce1c19abc43d9f6df9808199ad66b49d7
535	4	2025-04-03 04:15:00	t	f	\\xc30d040703022739d8a356c6023172d237013488928d87389ef55cee00b19d32d62f6b916d532bebe4db832e4d1b2663a4a46f692d535daccde6f570238295e7b7ade65a8256c838
536	3	2025-04-03 04:16:00	t	f	\\xc30d0407030286ba96722b34468c65d23601de657063e4e9c0e69aed3fc007022ad5ee53e8e5adf0f0b791c11efebbf8c621a24b61115f4607d3fef04a0dda4e2e351d1fd38339
537	4	2025-04-03 04:16:00	t	f	\\xc30d04070302dfa866462e4c1ae663d23701ea32a29f8e4260fbb1fdbbba9510b0bf610859892fa04e0b4ad442e7e1ade13ab4b19ac46636472f18740f11806e85ff1787c1567b5d
538	3	2025-04-03 04:17:00	t	f	\\xc30d04070302c6ac87112255612061d236017b15dd1c41ae2b71d6a1794eb3625fe43c123baa76d37ee24b7bbcdb1d7f29517443da2c4d346e136b82a0cc1ab242991e0b73e931
539	4	2025-04-03 04:17:00	t	f	\\xc30d040703029de244a24d516a7876d2360191fbe5ddeea4bec31965bd36b6f1d6bf8843e501bd17bd98657ad731831bc20731417b980e11728ba8a2ba2d41c605bcbbac212f4e
540	3	2025-04-03 04:18:00	t	f	\\xc30d0407030262eaab4602974e3d67d23501a58094f6cd4fd237e8dbc51577d579033e63af9072581027abb0400d530cbeb3f777de4f50673d8c3bdd63568c7f8a2ac78c0b65
541	4	2025-04-03 04:18:00	t	f	\\xc30d04070302778d66c778019f6b63d2360147b20268b706df733f6a5abcfc8ba3c18bba078ee3aee9c3d9fb95c7dd9959cbacd2568185385ba79e47250efc23720421e8aabe2e
542	3	2025-04-03 04:19:00	t	f	\\xc30d040703021b3a560415c59ad471d236015851bda184581472835adf042d05bdd5b8b9974d92884fb680743d1309fe82cd3bbcdeb764857db58537b1e185c1248246152be55d
543	4	2025-04-03 04:19:00	t	f	\\xc30d040703020761008352745ec07bd23501dca2adabd1d5b2dd4122647832b101438188518d8fa6fa61382873288733ae14f2c76576d865e5f0a216a7b35bbc7b4cbf200b4a
544	3	2025-04-03 04:20:00	t	f	\\xc30d04070302106bfb31d85f30846bd23601d1a2436248c9029b054379e69ac822e6ec52ef65e18a7a2d76e1a150f29609bd1d5790769ab7b62f2449ca73512a7d3a82fad86664
545	4	2025-04-03 04:20:00	t	f	\\xc30d0407030282ac8669537fe07664d2370122daaae17b0da52069bf4b1a12dab696f1c383b853e97a074cc7c510491f4882cab4ded6ddca210ff726061ad91f431ef6cf61b486f1
546	3	2025-04-03 04:21:00	t	f	\\xc30d040703027be211f0836f71567dd23601bfcd4a12a72dbf48829c493a3eca76e4d3260dc34955df9b40ef1f304b696778af574b33e076edb1f2dcb910b1e9e4e053be338a70
547	4	2025-04-03 04:21:00	t	f	\\xc30d04070302919bdc7e040a1c5f6ed237010db684ec092053fd94cffb03121c5ccbe36bbe714de9f2a72717b0649d45708ae02a912e54e94db43e3d3a812ddcf2a9ceb918eb53a3
548	3	2025-04-03 04:22:00	t	f	\\xc30d04070302b58908a64f3ac9017fd2360147495a2897668b8b639bbcae89773180cc7e42ffadff5fe7f2f9860ed743237ce15931176fd5273c6239be94699f7e5f20c8002e82
549	4	2025-04-03 04:22:00	t	f	\\xc30d040703025df65399ef2dc0f274d237014573fc2eaada91587838af88c581fb1b29a51ec1b9387711825785d4bef86cb796bd1e71f9ddb48fcc102ad032625d6f363de26ee463
550	3	2025-04-03 04:23:00	t	f	\\xc30d04070302943a3ae0664d579b60d23601c0cfd8490f32dbfda04809a7dcc2fc69778be69e86467ae23849fb378b7135dff0b887205dda6b01a127559a00a544efc9e06ff40c
551	4	2025-04-03 04:23:00	t	f	\\xc30d04070302ec97333f3073c8e575d23601795b3344cc8878a2e3533d1245a11f8d7f59ec59b763267af4ddbb263dd9ececa078b5aff9138d7cfbcf3b6c16ca3b79e71468b063
552	3	2025-04-03 04:24:00	t	f	\\xc30d0407030285a0482348e72a7b7bd23501083384b452cad2efd4aa44387a16850f821e3346b779a26c1621bcd590213863e4a69fab99cb9da86c08474c2b396e6d35dfbaa2
553	4	2025-04-03 04:24:00	t	f	\\xc30d04070302f31eb7db8a9e61786cd2360167dbdb790a235fc9a79e1a7d9df7af02d913ca3150bbb4501f1ba1c8d01106f0bb9a61444547356b725650aebede2b61b62e1fc10f
554	3	2025-04-03 04:25:00	t	f	\\xc30d04070302409404c70ed2d1f770d236018710198ee9a2deb2a908766b34278362d56919cf11964ab589632f17eda23856849b49397c681e91e889e40ad5d0feafb6138b057f
555	4	2025-04-03 04:25:00	t	f	\\xc30d0407030201a94668ba6967c260d2370186df4fff99ad253e49ea4a544edb15125b50d634132870b466e7b40fa005f6045bd7c693f48279d30a9740e9af2ee355fb438713d067
556	3	2025-04-03 04:26:00	t	f	\\xc30d0407030280646b41cfaebdb477d236011cc9ee6d04df1c0e6d362caf13951233481b0f7fa0bc8f199b24953fdad97a530b2fa2dcee625640a9cb49efd00379620f42b95832
557	4	2025-04-03 04:26:00	t	f	\\xc30d04070302a4ba1bde2fabed1069d237010f4a569c074828df738d0254e1c9ca7fec4673557aab881ee6043b075dc83eabbd50cfe64faef3169776da5dd6071cba6cecc93e3411
558	3	2025-04-03 04:27:00	t	f	\\xc30d04070302d4d226576f8cc0c76fd23601a1521c68079fcc42ac2f30e4137703eb5eb8bd4abeaeb3ab6bff89da28af5713c3a173133143e815f8dee1df28cf720693c964e3a1
559	4	2025-04-03 04:27:00	t	f	\\xc30d0407030238137d7ff359de1d62d236011043fbccf0ee2b4b9d1b6da1de718ee54e5736905884575f3a57fcce5acdf89bf5f4c65994ee755326bd126bb22a423a6b53e3f4e4
560	3	2025-04-03 04:28:00	t	f	\\xc30d0407030202ee36d2ac355aef71d236015c8ae11502aed3360e1da72cc3ce594b91129acd2a3c2056309c97b1021032ed543a69a8d5027527993fccac453e4aea1928e8a333
561	4	2025-04-03 04:28:00	t	f	\\xc30d04070302928bf2835b7a27726bd237016f70ace398b65077fb5925483f0680f34606902488be024d13d8af7ced3d0c39f47eb216869866940705dbfabee866f11149f0485b52
562	3	2025-04-03 04:29:00	t	f	\\xc30d0407030261ae3526ebedcada63d2350129d3660222f147a0984dec97eafb002b812dc10bdbc3446a6337a525e797625e7e09cbd6d0140106d75523c7d28e567a7c7b1651
563	4	2025-04-03 04:29:00	t	f	\\xc30d04070302e00a1fe51d15e5b36dd23701dbdcce9a4cc88db55c7f316e82eb01423a9d561a2a9be3a6e3b9c2829da3f02d9fedd7d09788f6298f52735c2c4078138c9b8ee38d2d
564	3	2025-04-03 04:30:00	t	f	\\xc30d04070302237202aa46c7404674d236018498731d11b633c0a561dbcb7a77f615635cd97fa8d2d1a3e19d93816852e08fa06f72db60b1da55a0679cc28e82849129312fe57a
565	4	2025-04-03 04:30:00	t	f	\\xc30d04070302767b3d5b29a8ac716ed23601e45a11af0dd7af227f0f194286e3e0faba4a04d1bf9edce92523e50361c7276c8b71bfcd1cdb5fffe7f1b3d1f3544fe73e4b02227c
566	3	2025-04-03 04:31:00	t	f	\\xc30d0407030279a29c519ad45c2372d23501337b5d60485be6c34b5789c2010c0cb4507ed646bfda5a6ecd00fc757c7e0816281cae7b30903dde1a03615a6c03b1d1aa7186be
567	4	2025-04-03 04:31:00	t	f	\\xc30d04070302c970fe1487efa02f77d23701cccb803282054b1012d6687a16e98c1fffe19578c9ba0c70cd0e3c660a231ed443237927b86d804aac3ffc8ea4dc5d1ed353e8c0c69f
568	3	2025-04-03 04:32:00	t	f	\\xc30d040703027db01d4b5dfbead87fd23601fab7ce4e23dee41eaf0a16ebc4e01801ec3bf709f689a09b12f9d727166fb71015aea7c366416c10732aa2ac41c6a14f46de3483a1
569	4	2025-04-03 04:32:00	t	f	\\xc30d0407030253c6d872c5f8656767d23701e80c5557c206d0ec3121005858b1a6af2e1077eb15db87899645b9f368b4e276165f457f3f9faf81176dc86eb394ae488ecd71d18964
570	3	2025-04-03 04:33:00	t	f	\\xc30d040703022b4ca8c0f1676a366cd23601e2def3e72bd68733c2079aad494bef5e17bbf9059456fda5405fb10d3716ff80fd21887339ca2ee599c336f9d7cec291063934ad4b
571	4	2025-04-03 04:33:00	t	f	\\xc30d04070302b51f4bd6eab1a3ea65d23701a5e17d75efe486979cb1dbf5bf16deaaff8e32362a42c93b07dcb615fb6a55447a07a8e542cf31d732876c9697433354b8a8e353c4d0
572	3	2025-04-03 04:34:00	t	f	\\xc30d04070302d07d15442dac6cdf7ad2350117176ecbb7fb4ff9b89b127a0e6ba0f7a8b95fee0b19befde5f1d5fef11fc089d050faec0fcf936dc414fbb6fe3f1fb6193ed432
573	4	2025-04-03 04:34:00	t	f	\\xc30d040703027c28b0b041b4b52a7fd23701aa4da5ee76ec4fe22f51d0a17ead70df72ca72112c83818cc38e6d9049aea67baea831fb4b78ef45043be226e6fe587bf97fbb166c9d
574	3	2025-04-03 04:35:00	t	f	\\xc30d04070302972c8916ce790deb7cd236010e9718fd5d7f3af52da48cd0bb80d8d78dd6743e551e26fedeb71cbf3aa7d02d0684f54e0288004550c96b9abe53b44312029e5c41
575	4	2025-04-03 04:35:00	t	f	\\xc30d040703020649d16abb8cef8c60d23601e018d956027518099fb3ff16e3e7cfd37547b7063880ca6031e9e22962caadafe08228536a23fd50a95473798e1aebf74341cc4b7f
576	3	2025-04-03 04:36:00	t	f	\\xc30d04070302df42a93e5908157661d23601cbf7d1acc1613138e7be6ff71115283c912d08b7a8d52f5f0b6443e42d7f2fb0093a76dc2dbe752b7eee98ada2216a82b7ae919846
577	4	2025-04-03 04:36:00	t	f	\\xc30d0407030242fbedbc71f97f9076d237018144bd56c63c2fa861bd90e48244f354d01d87ec4fea65c69cf11242380935583185b2afdf0c6ac121adc8682011005d55e7ce8451d8
578	3	2025-04-03 04:37:00	t	f	\\xc30d04070302678c3cadb9bf305264d236014f75911e978b82af9491988eb09ce090a8077aa4a9c06b7034bb57604b3a20b9dfb7e118ff24e9676d1f45c778ae7a6eef08e54553
579	4	2025-04-03 04:37:00	t	f	\\xc30d04070302a866417c5fa678e779d236015c89502616aab17c89e3f1f6541ff407fd6c860e3696c7f7b51c9463c04ddc98b3f1ecc3305ed42f61281dd3853d09cabefc8614ce
580	3	2025-04-03 04:38:00	t	f	\\xc30d040703024174beb55627b7d47ed23601182b3bac95050e7984ce81435add7a440d969acb524eab3200a051ea881c5854f9a852950a35a330a529c2c3f53671177d36a9a406
581	4	2025-04-03 04:38:00	t	f	\\xc30d04070302e7756a6105e15b7368d23701d7cd2c6a7fef992fa018641390c28d0f0015bade4d586732da4a968a389bac0204aa23724a33e9d110828a1b312e8c82bf8b28b71d30
582	3	2025-04-03 04:39:00	t	f	\\xc30d040703020db28e88af8b931b6dd2360135d39ae6bdf0635b90d8476d0da2120a224b028ba5f6bdbea5421be6218b969cc8061a777d1c1c0a063dd0c119547ff2cc15018b2f
583	4	2025-04-03 04:39:00	t	f	\\xc30d040703024d6c0d02f9945fa76ed23701a251b7031434e5bed6f0f7d1488ed059c25016eed308ab6e382aa674174ebc42f23dd086acdcedcb06ba6c06fac56344d8a126821602
584	3	2025-04-03 04:40:00	t	f	\\xc30d04070302188a45f95900bd2b66d23601bea411d09ab9ba6c41d5fc9be2cb958b169a0e7fda3cef3257d56bd2db1681660ce324c3b1410ea5fed1725d6b8ee3ef1cd03dc04f
585	4	2025-04-03 04:40:00	t	f	\\xc30d04070302790e4312cdc39a5f6fd237010188e37bc8b8fc32bd1d11dc60672099a9aa0f066b45155ab0203c4f3e973898d5be1cf9f9a815b74942225c0bf2ecc3eacce2d50e16
586	3	2025-04-03 04:41:00	t	f	\\xc30d0407030216d58b591927f50966d23601d9d670192d94719e1250034704f95a94907038539f3a7be1b44990005736602b3dcbbbcd024b548e44293f421c298310326da3b219
587	4	2025-04-03 04:41:00	t	f	\\xc30d04070302da10a5a6a1160f707ad23701d80d440164c03f33e7433babd818152471f6326ff9d36be4726069b1ed2774b2e7dec4498e527de18dbf9fb6d1a21ae5c84dd52c56d0
588	3	2025-04-03 04:42:00	t	f	\\xc30d040703025fe340561f3c84cc67d2360189a97926c95d06eff6cc645ebdaa2588692e51a1a8d48bc94b6331abe6dd251fcb3158069826a5e6ab910529ccd0d4918072859f6a
589	4	2025-04-03 04:42:00	t	f	\\xc30d040703023ecb6aa2d7cf986a6ed23601b31f1bfd65896f641805fc8b7e310ef71ad0b0c261df242556bc9c38fc9b39553e409fdc7c612a24fb008559782c87b8e6a268b109
590	3	2025-04-03 04:43:00	t	f	\\xc30d04070302fe16fa98a772c53e72d2360169ee2c1492fb6094b046675b428e2b8b6c825657712c3e4b764fa8ebd2eac804b95afa423620ef9454063a0544d00ae2c150e67ea5
591	4	2025-04-03 04:43:00	t	f	\\xc30d0407030234a303250e7ba2b971d237011d880f196d70d9c6752b2cb8df642b46412940bc3283da7e15b5b83efb24256d14fa1f8a86f094d709ecae448f6c0e8e7e470b433e1d
592	3	2025-04-03 04:44:00	t	f	\\xc30d040703023140ca5d6b58f33f73d236013303a76044c9831ea93a1939b0c26c4315ed4138225206e5f869bd94fbc84dc9bff12657188586d94c31c25d95415b9dde5261c07b
593	4	2025-04-03 04:44:00	t	f	\\xc30d040703023f040698b22618c363d237011a3d1b39e803e261f689450d3286a4cc62e071b848f4777248e545c860afcb62bb4afac36b7e30a37541ef00b2ff2f1c8d20fffc5b33
594	3	2025-04-03 04:45:00	t	f	\\xc30d040703021097e192d7cf3c727ed23601216170818d6375904f4aeba79e200e7a639520f20dc2521973a097d022585261f087fc3b81bb06fba882712bb9f3cdbc4a102856f0
595	4	2025-04-03 04:45:00	t	f	\\xc30d04070302f5ff804456dfc0036bd23701b3f27a2ac63c7295b06bdb989ba3553707ff09d6f3243c7665320944a820f3c7e0409cecf47aaf4fd38723775afcb281691c394f9ddc
596	3	2025-04-03 04:46:00	t	f	\\xc30d0407030269121942dfb9d81c66d23601cfac9e67cb17930377b144cd2b5c3069dc1eea72bdca4165844e42b4796f02fb032f58f6ae4fd333821199d691e4758aa6c7594784
597	4	2025-04-03 04:46:00	t	f	\\xc30d04070302053008450794f9677fd23701ddc148c9f1a1e507e9148c1a7461a1ee063dd6f0bd3b9b846a1c09edf108f171722a9f1e63dc62673d858191ff14e45b0994f700bef0
598	3	2025-04-03 04:47:00	t	f	\\xc30d04070302b5d3b0ad8ab6d2ec73d23601627760d7d4d0905ec367fbd1a6453deacf85b5215fe53ce3a256d9678a6a9c8968ba8d3a388c84f33725d5f5093c7f44f8055c59de
599	4	2025-04-03 04:47:00	t	f	\\xc30d04070302ff61d457d33796bd7dd23701474d8ffb74c803038cada70033fc55be8a785c90bcf44e60a6577881bc5675e2fc84e439ee650ed6966646e5642b634fa02f28c1d48e
600	3	2025-04-03 04:48:00	t	f	\\xc30d040703027fe4822ef45668e378d23601516881cb30e90c98a5766316593f9fcc2f5ab4107d4828982179e57e6f5a2f59b5dc38b40fe2f8d3956158462afea4f7f04c83d423
601	4	2025-04-03 04:48:00	t	f	\\xc30d040703024e5df5a70d6dc0a97cd23701151ae0074dfd0830b0ffcf7734e4edb4377a556c5a4c1ee7a4bcf403c77cf74e6341d43f892542ccb018c0df28f0d6dec185eef4d1d2
602	3	2025-04-03 04:49:00	t	f	\\xc30d040703026c2b106721f83e5677d23601603e19499c49c84b11177eb59b1fdb8e9bc20e74b7037ccd0fdd6965898bbc2f0a140915c7b117c21368eb4003b55c5255b45c1238
603	4	2025-04-03 04:49:00	t	f	\\xc30d04070302bb92b45808a05cf270d237012e59e465860450b47214f10db8c14244cf2b5152f828ddec43c1a25639bc6cbc52319001190d56a063affb966f4c08b5b0346a5c6354
604	3	2025-04-03 04:50:00	t	f	\\xc30d04070302ddf4538737ac4e476bd236019dd8e1ab6c512be19b873f34bb78ffd13a9c4c055929937ecfe70c9ca02fe2c66e8763fe89757bca6e86853eb25414108c712f0a37
605	4	2025-04-03 04:50:00	t	f	\\xc30d040703028adc0de73ffb21e37ad23701f38da54eaafee949c1e234be6d4d41e7de84a7b0978837d6814272d4422fc1ac6b7f40fdcdc37de8d5642de5261e6567ccf4c876fb21
606	3	2025-04-03 04:51:00	t	f	\\xc30d0407030200cb57942ac573b473d2350197864fb479b5280b681d4446599c65a42e41839c91bdee4d227d9fe906e21bccea8374bf22c18003005f07e6aea4a5477e301484
607	4	2025-04-03 04:51:00	t	f	\\xc30d04070302f5f41b2168bb1ba765d23701d4fea2f1e7ec68f92581ab44ab24023f5f317e3073518550e301fe70b98e37a3f543346bedbe5c1eb336d60c10d9986db106ea0c4369
608	3	2025-04-03 04:52:00	t	f	\\xc30d040703020464fed77de02dba78d2360145892c3c153037ce86625e263b7a8af608886e878fa0c285c4d6b63af5af3db09045bd3204309296ffadbb3f25976339bf34c4acee
609	4	2025-04-03 04:52:00	t	f	\\xc30d0407030240097346662b6b106fd23701c6859cf083520fdbaa8398c0de336796f8c491febd3c33cab9eab6324e251f8c93130eb5176f5677f981605da451df0ad5ddd5bd8a66
610	3	2025-04-03 04:53:00	t	f	\\xc30d0407030293638c726dab97ed70d23601db3c72fb39826fad9f154241f7b3ee2ffd5fa6440ceb15412cb2a0fd38914e38cabca868198ea6c10eec39e86bdc12472fbfc1ee71
611	4	2025-04-03 04:53:00	t	f	\\xc30d04070302ad6d8e882d85729b65d23701d6494fb87dc86399324abfdbfee3e6fbe8132d3ba7f4ea09fdb4ddb19f55493d16f05e88cead18c8764186ba47e3d63046f8f2e7ade3
612	3	2025-04-03 04:54:00	t	f	\\xc30d0407030238d0b61dcc7c2fe878d23501fc190456ba4ea05a3a17b082fd45a6ac53057c53fb6305390e129f3f275a7c89fc7890e8b5ce2519fb7a7b27d307c0f2f610bcfe
613	4	2025-04-03 04:54:00	t	f	\\xc30d040703021617c1b56ac369476ad237018f04ca831115693990f717a9b51bdb12057d491f209b71c4ecaf502cc7c931a29041c7d71e3af98e68ba3c3250d640b2dfa39b81ffd8
614	3	2025-04-03 04:55:00	t	f	\\xc30d04070302abee75023afe2da776d23601be1604b2008a977cdb4ad94a980e2f7fc00425f0597474863ede455170032f1b88218719bccd2849d416dfbdb863e2ee8f117a0042
615	4	2025-04-03 04:55:00	t	f	\\xc30d040703020fdec3d4394fd56963d236018f040719b400474cb0b61869f9bd304503eb52f1f614ddcf538bce99f9986ce2d1dd9fab424c20eb945f9246a5a503851116e9b884
616	3	2025-04-03 04:56:00	t	f	\\xc30d040703028cdf0971ee4c1a6b6cd23601ea3bd062b6e40c43c983d98d48485fbe7892dabb1e05edd4fecdcceb7c9c251264548efede350bd96a4c1a9945fb3e6e62f2319ecf
617	4	2025-04-03 04:56:00	t	f	\\xc30d04070302720779bc0e49888167d23701c6f255922c8dc71b96dc596514170591d89a23f2c3f5885f25175fab99cb81396dbda75544564d82d1009f5a658d9bae5e7e41b0fd8b
618	3	2025-04-03 04:57:00	t	f	\\xc30d040703024500c567808007977cd2360166acf536ca0bd408c9b918c891fe01d87a2c5024b78df0c856f5fb5bbdd914a6861c9b4e832485af352304e46421bd8db3b2f518be
619	4	2025-04-03 04:57:00	t	f	\\xc30d040703022102fb8e910096b762d23701a1eb9c1fb118b86770abacafd525fc0811a7b77457b14132e78c068ae1561e2ef96de570345aa9c8078eeacd5dced5ff549ee5020481
620	3	2025-04-03 04:58:00	t	f	\\xc30d040703021dfba5ce64ac3ab871d236017a7782bfbe64e9e31fc904b7608cd7b92a950c6f21badb06c3593937b4dabbc450138f664bab572c6ed66189184021c87d69d7f61a
621	4	2025-04-03 04:58:00	t	f	\\xc30d04070302566005972138559868d235013c51cdf5d0c365f5c40016fad4afc95945939754da987415fb0cef0015148d52acbd09024c91fdbd3617c3b2ffc0cd4c2ca627f3
622	3	2025-04-03 04:59:00	t	f	\\xc30d040703020a230f21e9f4da837ad2360196622f65e0120f1dd3776fff2a19f9072f31f72e14b3b86d885b589d4e708ee3bc36fa1f2fac76711c7110b5c450b8991c03ebf7ee
623	4	2025-04-03 04:59:00	t	f	\\xc30d04070302f5a09ea63c3abe126ed23601780d276697c9dee123adbaf3e8d5a5fce9ea9fc644dbabb8a5c465ccc5d291b9c46418f6f5d22c9dcd92629c39361fb419b8bb4eed
624	3	2025-04-03 05:00:00	t	f	\\xc30d0407030272a311c5a3142e617ad236019ca9edda11bb67c07c630d44eba303fce678bab55ccf6cfa5dd4ffb037f07012f4ffa45d41aa90bd983e3b2978b1c81a1f50b049c3
625	4	2025-04-03 05:00:00	t	f	\\xc30d04070302a770eb71da04ff7771d237016f890d6b741f4de58e2177c279bdcfbd9d6e270503ea409c8ebc7fb4cde8548e89e2cf29d3b6c827a723aafb6c5a6bc6bee3e6922a5c
626	3	2025-04-03 05:01:00	t	f	\\xc30d04070302b37cdf8cb69277317ed23601b89e0c2638b0ff463539c4a9186ca53f27105a521e43ced4690277453a2b67f68447cd313af8872d46c6f6b865b578b75022f5d07e
627	4	2025-04-03 05:01:00	t	f	\\xc30d04070302e60063e58d34599567d23701d3d61c268db524801ae58d1b155b8a62c1cc32a8eeb377fef30a45e78bccecc9e72be762c1cffdf2bea35989d32cfe8a2454a9a958b2
628	3	2025-04-03 05:02:00	t	f	\\xc30d040703023a5c61a2791d4bf66bd23601f122aaa4a00a8d4fc7fd8f86eb9988172c8f65bfaf7ade06e3a603d7bde88366923349c472de1f01a1329d1146696b6cdb4f1030b5
629	4	2025-04-03 05:02:00	t	f	\\xc30d040703023c255eb64ac6872060d23701314e8fab99cd08d480ed3b8ced0d9490031e4ed49fa5a9240910db575000d6e6f4591852576ff75d9e32aa0db3ef2a222b23fcd6d374
630	3	2025-04-03 05:03:00	t	f	\\xc30d04070302df929c3726a792b37ed23601d77fe84e7740e0c0b0adbb39fa16bbff2b664aa806db333f125baab94039860a24f744007054d3adc7cac2f9b48fcaa4e9f1a64a8a
631	4	2025-04-03 05:03:00	t	f	\\xc30d04070302d9e61539f70dc83877d236019789e7d072fded076311409eb31cbe8cc489c87e76d001d048910b6514c2b603a97f50d52bfc138e33d6f00f5e6453d42fafc5ac3b
632	3	2025-04-03 05:04:00	t	f	\\xc30d0407030284d66ad6c8357ee46dd236018040c46cf587a14c558f95e61a217b7c075d830fe3a067388cb7635b201d7a25e06208ba4493dd70e6d0abe1f482badc72b9db8335
633	4	2025-04-03 05:04:00	t	f	\\xc30d04070302240ab788cab45ceb76d237013819cb6aafb7e8188b1201be097526b9eb67265d029ad34957c14a03b6922f42562ad9a1b0bf552810d4ba185a44858b1c215354630e
634	3	2025-04-03 05:05:00	t	f	\\xc30d04070302fad13aaa48b1304a73d23601ae5a6c82c5962f52f95afe471eee11a32407cf0baeab47e3b557bf6f2dd00e3d8528fa5aa3f979d14f81151561c42d32a7a705e228
635	4	2025-04-03 05:05:00	t	f	\\xc30d040703023f3d526e5d02928579d2370111890b43f7b6797dc9a953a08ace446d0a7ef023b6572dd598ba6e79990f3110f7780dab381db1c57ec04ae87c194f35779b86246d15
636	3	2025-04-03 05:06:00	t	f	\\xc30d040703025b8e6a7ed58416687cd236012aadef04b1083d643f522b6a92b849b0aab6fb120167ae490987464b3b47bcd02d9dedc3a09bc27557259f1f0c1c968469d044db36
637	4	2025-04-03 05:06:00	t	f	\\xc30d0407030218f52ecf8c5072676fd23701e85b8ff21ef7368affc48933924d3e8f61f9e717e1bb9462d555586f7dcf8f4cbe740edf669bdc8d3661c4aa18fcb6c6c09ebf8f4d7f
638	3	2025-04-03 05:07:00	t	f	\\xc30d04070302027b55fd5a3e3c4b7cd23601e73fec6d857eb6627742128803167128857c55770fe5b1cf0173334df821c10afc73d880452e72f95eb9ea903e749b22525e451732
639	4	2025-04-03 05:07:00	t	f	\\xc30d04070302c79bfef02f43962f68d23701e1253991ca9ab07472d3eb2ebe554b07b61becd9e8d225537471c665df89b16bcd3d107048842743c2f23f16891e9c163721e31e1688
640	3	2025-04-03 05:08:00	t	f	\\xc30d040703029e4c5dcb0247ce4574d23601e9bc756452f8443f3ef2701c7a39cc7fb8b67675e1ec6c626b793a08708d5f699cfc76772470ed52e8f29b07af91b85ee92dafc167
641	4	2025-04-03 05:08:00	t	f	\\xc30d040703021f5e48fd349d293468d23701ceab86ddc06f3d806e4b716c4fc4d17a339b5cce547e9f855b92c1c18c51bc531e8c4c2f9e74c223fb4b2aaa2577e585bd78a376c279
642	3	2025-04-03 05:09:00	t	f	\\xc30d04070302f5b3f8ef7057431172d236013a4d4b443c89d3ce42eec0c8d73d06aa4c0d44cd508953c7718cc4335cfcdc8ef9845332589a8132ee8819234b3d9d474db09bdcdc
643	4	2025-04-03 05:09:00	t	f	\\xc30d04070302cae6c6710ec87c2969d23601748759578b7bf32237117a2d8b75c570272ba11bfef8868a9fd567aaeb47ea422eab407e9855c512ea24835da5b67bda3fe6fdd623
644	3	2025-04-03 05:10:00	t	f	\\xc30d04070302ec787635ffc546ea70d23501d06e70f0f809496d965966df57508a09e969f7c1a262eaef4b13cd626e027a63cf9a4602daef2d6e8cccc1341927ec679d1512d9
645	4	2025-04-03 05:10:00	t	f	\\xc30d040703028aa105ed4f8115c079d236016316aca6b2172947b51d5424a059dbbdcdaa791a1c1aa50fd5e42e0bddb965be0a4a8a48282e0bb6c1a0b8f1bbfb3d3b28c6807459
646	3	2025-04-03 05:11:00	t	f	\\xc30d04070302a02988ef49418e2562d23501b2723f516693576570a7a06fe8783c8e7ba664a190aa6539399150b5a458cf83868e0e786d7605f9a804989b6e632cc528ac6c32
647	4	2025-04-03 05:11:00	t	f	\\xc30d040703020cdba5f51bae9f897cd23701412b4324f7fe328cdbd601baec78fb6661362cbad7a0c52a0c70dade615b9bdaa12bd0070e0f890049c4377730f9ff81a92c2129b57c
648	3	2025-04-03 05:12:00	t	f	\\xc30d04070302b8343f2e55dcc08266d23601080f013f2952cc19f088e4c300da48d583ae4c1a406530fdaacd3b5159a394f79e9390cd4107d1b5126f61a3fab93f0880034785fe
649	4	2025-04-03 05:12:00	t	f	\\xc30d040703027287cc8912fa0c6d72d23601b40bb9f0d5c6a0cb7b521f348c175ac4623e9dbd5eaa288e53b2583cbb5b65ae6da6fd4204388f64b098ce5688da77d42e1f351ff7
650	3	2025-04-03 05:13:00	t	f	\\xc30d0407030231517bc2f1b51af278d236019744b14adb88667599a8934cce3a5dc3f6018f28302478a040be1c181ceed72cb70cc69455244d3c1a5696c8550455f9e99e5d31d7
651	4	2025-04-03 05:13:00	t	f	\\xc30d04070302badf56b0758f4f1c78d23701f4a829bb0675abcb8c169f40ca94dad22a674c3722a752d178415cb893760f1513ed26c3d50957c23f787100b2e7e98203789840be26
652	3	2025-04-03 05:14:00	t	f	\\xc30d04070302c6d5ac847f9e244e73d23601776a05363e518693c1555dc1eb3d9164fac25d6017f4cfd329ca132444b371ddb0754b9678f595c0f0be338354e06730ccad070862
653	4	2025-04-03 05:14:00	t	f	\\xc30d04070302a67eaab4afb4272a77d23701759c0e8961944c47aabd3826d52fc79716ee05e0641415258999517e0ae105da5317d4e5c2d7fc53b2a7999dd0a55f1e464249be9ccc
654	3	2025-04-03 05:15:00	t	f	\\xc30d04070302310cc177b84828fd6dd2360192f726f3213c8c8c0b2584c53e192d6732b1097b781bec39e21fe33371fcc6f488ba81dc480638ed42884d97d3b4e22f7c7b3a3a46
655	4	2025-04-03 05:15:00	t	f	\\xc30d040703022b7d3520d98523bd64d23701eb77b0ef544c4132812d5e93430457eb8f513cffed7a710527b66155673c52fdb114c896e328b814d68618174a08609b0c3d60fdf262
656	3	2025-04-03 05:16:00	t	f	\\xc30d04070302f33925f3fff674ab63d2350127ca7891a5588d1a505dbbd8411a3c68df4d1c2944531fe0785015e39a9d8d02c9b64040a07c15242a6f0b9fcc4d50dbd924dc5c
657	4	2025-04-03 05:16:00	t	f	\\xc30d04070302108f8a10165af9df7fd23601ae0ab2c8711fce4df079ffe1dfcb314f7bfc294a4c328a2616c4e597e72b5de9cc1f3ac2746e81145b3578d129b5e501ffe7219467
658	3	2025-04-03 05:17:00	t	f	\\xc30d04070302b8bfcbd0d6fe6c0e72d2360170c143eee5a6cce52cf07f15b3c190daac6eedf73e55ea6e52cf8db1826e6d2a5cb29bbae6b306da4c64c7128f7c8da3a06e6184e5
659	4	2025-04-03 05:17:00	t	f	\\xc30d04070302bf2d967dc1d17b0264d23601ed6e464c1f96fa656f3ef7b4542c61c94c361401e812e27d74996072ae777dd0666a2cd7c504c0b7e55111136f87226c4792afd2ec
660	3	2025-04-03 05:18:00	t	f	\\xc30d040703025527343b9ece243475d2350162e1fccb2f2578c84a6381399759bf1fcfdfdebfdf6a79284c9198cf220b3cec89ea6fbe6400d9ef68a24e18b8c72331d730018a
661	4	2025-04-03 05:18:00	t	f	\\xc30d04070302a7b5ecc5879ae63565d237016ad4328bf5425e41f59e4db9611e164e324c06ca781ce61bcfe7dc48de5d429548667711d6eb861fd2abb43a7c0496dea9c962e17a13
662	3	2025-04-03 05:19:00	t	f	\\xc30d04070302bc4eacb98e9d882962d236014f0403324e202c0503ea319ee4bcba37fc53c9d9d6bbfe87efb20b6181b4909c1dee945a435a09c179851920e43e03d1a3ee35ecaa
663	4	2025-04-03 05:19:00	t	f	\\xc30d04070302e9fe6e9041880ab961d23701b72bb2f5ad8bea6a30812b46a3b9f6a79910e77b0696b82bd7f9b6ea459bd78f310b4ce5657a07846b8e2da56eeba769fbd89ca083e5
664	3	2025-04-03 05:20:00	t	f	\\xc30d040703023d943f1717fd9ca460d23601bf0e79acfc233dd4447a75183acc11308259ad4d30bcaa51727f268ee04cdf275d1f4c1e465c255427552d353655eeddcc9993a9c6
665	4	2025-04-03 05:20:00	t	f	\\xc30d04070302c96b0d793021b61869d23701baab7fa08328133555f44bc476a8f737771c57d86db444ae0b1eea3dbedf6b245a7a99b279fd84ff70278a1484c8b6a2ca4391a0620a
666	3	2025-04-03 05:21:00	t	f	\\xc30d04070302ab9e2722601b96347ad23501a8081db1ae80629baf3e40c74393ce8cd8605e0d4d259c3a470965fa3130b6f22d218470b712d6b688c04312ea4b6d6be3583f16
667	4	2025-04-03 05:21:00	t	f	\\xc30d04070302268ce19e3d7b12097ad23701821a22e5ceda48834a7317c4c679c719d50d96e4ea76f207975c7f70a3fa862d72641e177e24d7675296b9e231f6f20014098384b05a
668	3	2025-04-03 05:22:00	t	f	\\xc30d04070302d228e526bb7141bf63d236016464e048bd114e26c99a1432bfb47d4f7704375d078aff601e46e9c1232d92861093dfc38f9d06e0f3f2e6d95ebcee62346f0f1165
669	4	2025-04-03 05:22:00	t	f	\\xc30d04070302413f1291d2a788f769d23701bb2b77c7f099504c2ffadbc3a8f703a024cf896ae637a4bb456bb9a4ae23a615643bf2718db1a193a5811bcbe9261b434ff76738e494
670	3	2025-04-03 05:23:00	t	f	\\xc30d04070302bf13316e0d67f5e77fd23601931c2985820e62f36d5a1e4b61d217df2d0d5e96ca41ee72e63fb87d568c91e4be0ff1820ab8bc25c4f1faf12eb2c20feed8d2d023
671	4	2025-04-03 05:23:00	t	f	\\xc30d04070302bec08b00143bf42179d237013cf845d1c6c1b2d2303fbe1c2088d902004fa07a249cae2e0c7faeefbc8ab60f923d9692d3c31fd00cbb8516f44ba0ed0d9fab610cbd
672	3	2025-04-03 05:24:00	t	f	\\xc30d0407030268812348c4fac92f63d23601163d552cb741e382e538637d9a5cc1474cb734a0d9f2c0cc638b650ccb20c983d0bf64f004a9e6d6c54fc3c1c3a6b6d67926c08412
673	4	2025-04-03 05:24:00	t	f	\\xc30d040703021c07f14b54e83c1c68d236015ada825c9e07b49bfc34dd44ead2708b6cf7317b7cd71adac8739966fcc6eb5eac4fa53e45679474abc106e994b64592c2bb9bcbf8
674	3	2025-04-03 05:25:00	t	f	\\xc30d04070302cd2e9eca26f74c0f6ad235010bc8ce96dc19221c2a5b00a0d71dae66426332aff4ebfeac58c2485f270b2366397b500ff441cbaba17846b979dff6d3943dde8f
675	4	2025-04-03 05:25:00	t	f	\\xc30d040703025f294830170011d47dd23701691bf0cfc7308c202dd17ef9a1939cb36e85818e95fd00711ff4c953dbb099f03b7d21cd4f866b2bc89e41c668f94990cfe7225e7b1e
676	3	2025-04-03 05:26:00	t	f	\\xc30d040703027b19513ce8484b4e73d236015af568f31668697ccf50bf255457d2c1bf45c2fcec2a049b840a87c5dd985fd84ac700d1d052d104c0bb51a96fb51f202615b4184c
677	4	2025-04-03 05:26:00	t	f	\\xc30d04070302bd8e467b0ff7588d73d23701e4886d5c06d689b9afcb0308f77f8124cc4c7a7cb2b24d1c4c443bb3923e1242b01cbb3a1613d987f8a8f5a0be4bdc9f15476e33acac
678	3	2025-04-03 05:27:00	t	f	\\xc30d040703026b513ec0c55adbcd68d23601f27ae7c061b9f403a3c4c60d9fca2b3a9d3b095c69e32565dcb0a17317aaffd685fdb6cde8ceb1f393a0862b403e5d16f1cc5b9d3b
679	4	2025-04-03 05:27:00	t	f	\\xc30d040703022fe4e812d0a00b136ad23601c269d86356a555f145f79d9ad39ef44eeddf1448da83ee81d8db57ff22bbd45425fa72b2590beecdccc41d530fd3331f6bac033ebc
680	3	2025-04-03 05:28:00	t	f	\\xc30d04070302805759117fdef97b64d236012031dee21007db1a704edca206f8f5527fbe32a5d78909fc2e3f667cb7b2ce8619d063359064cefe0bb43a1bf6a3ef5fb0865c76eb
681	4	2025-04-03 05:28:00	t	f	\\xc30d040703029e3157bf06a660ca78d23601571e7958f8c58ef92000e0b00f7cb577c51ead5dcad2bfb8bc03da93ad19bf64ca60dccf74be84a8ee99827e09f0feab33e9793738
682	3	2025-04-03 05:29:00	t	f	\\xc30d04070302c62f4a0fbd6efca274d235010714f0ff7d12d371ac40fd722eba308116312943271892ed146727a3f46b0fbd1ca019100f4f5d7a8349fc317d0fcadbb3e69424
683	4	2025-04-03 05:29:00	t	f	\\xc30d04070302f833993190f9135d67d23701a1b09f53c56e44b1aa2159e65f97e5c55e0244ef45a5b5286db8da9dde827b6f50120d3a5f3566bc09d1ab18eeb03458896c40173e6c
684	3	2025-04-03 05:30:00	t	f	\\xc30d04070302e000dcf73014d0cd7ed23601d228f0bf1c0c04c950ddb926716b615bed09c45ccf7a85de7946d235765c012772569e5c3ccb4c40885c7eac6e4cc255dce4857a93
685	4	2025-04-03 05:30:00	t	f	\\xc30d040703026e7001844fd32c1f6fd235019b64d208af33fcdb3b0d041471236748deb31feeacca446479e9995f798c3f448a7f4f66c9113ffa881b0d7ec290da601142f5d1
686	3	2025-04-03 05:31:00	t	f	\\xc30d04070302f4ae9ec2a2670f647dd235016dd84d55824a5de8247f906ee2f26069ed57e193cd3b102fbe2cd8dfaab6461f97aa3f2f04b32e57a6554a6f4dc15aed5005be52
687	4	2025-04-03 05:31:00	t	f	\\xc30d04070302e0cd6f6f37caa3b76dd2370104e5fe79153f1912dd1656a80c4eaeb8c911387a3baf871ea78be2b98c0eb20ca37a9518ddf053b8949d8cca28131b4d4204d26bf3ad
688	3	2025-04-03 05:32:00	t	f	\\xc30d04070302970f6a500f8d8a7361d236011e7b950ccdf5fca63ccf98e496d0d9f4102ebbdf41000d8481fa5d45fc1b4c3e8792a06887886d5cf478367bdaee9df8fb2486b3d9
689	4	2025-04-03 05:32:00	t	f	\\xc30d04070302a55603f212f09ff976d2370145e203e750d43ce6a5194fda8808118d482e22b4b75da83c13daf5baac24c49a1628a2ceb80d39feb5b69d0a699717b8a46d5398d6d8
690	3	2025-04-03 05:33:00	t	f	\\xc30d04070302e4ff18e9f7b7efbd7ed2360180c81b27f8b0f95cfb27a5aba0751e3846ee83c72d862019373013b010e246b1ef6f532ca1a016f064a49c29218f75cf168992d889
691	4	2025-04-03 05:33:00	t	f	\\xc30d040703022ca90414e83ef27069d2370115e41ab3b7cf490f5dcdecbbe8305edc4c7772b35afe2e5c6caea737faab1203f54206cf7bd0a52443158447cf003784e128ce45cd38
692	3	2025-04-03 05:34:00	t	f	\\xc30d040703025a8c1a514d040c5e7fd23601861b694479721a4a1133a19160b112d2e42573b978f223728e5e1d96c68f0263781ba704b2bfb4319d7b968695497205305ffed18d
693	4	2025-04-03 05:34:00	t	f	\\xc30d04070302afeea98e8a539dbe76d23701693820d6c3f0e7ddb92f7dd24d749364fe54d115ee50605fd3a59f13f64d6ffa5e5a005ab074624b617e0d1c87a594ab25e9e3deb171
694	3	2025-04-03 05:35:00	t	f	\\xc30d040703026b8f75c2039a055671d236010ce29f555c108767a7f696d07d4f783a845687bcfe08585321ffb2891def317484f7278e7fbef960b3b78427f0c3cdec59bb0d75cf
695	4	2025-04-03 05:35:00	t	f	\\xc30d040703020aff14be037234fe7bd23701a44a4fcd1b575ffe60cd51a6db4a9a7dc533998e96a3b82ff5ea0daa4082d4ac6c30c5189dbe68db9baa1b4f03dd31a9c3ea1340ff0a
696	3	2025-04-03 05:36:00	t	f	\\xc30d04070302626b2347c2bb9ddf73d23601e593a3ba6b3e36a30c86acecbd82e12af21ac4155292f6e99b4d730f409441972159b1f8d7af9cdda1e3f32edfd332e36cc591183a
697	4	2025-04-03 05:36:00	t	f	\\xc30d04070302a179c06926b656f778d237011c9dbb19b325bd389f3797a19451068c796cdc6da3e5a2c88ca907873193a12d6bf894446dfb6eb8fe5f62e194cd0b66de49a6b765c3
698	3	2025-04-03 05:37:00	t	f	\\xc30d040703028d2f18fb91b72b636cd23601fa88e1f6ad50293f5fa300fc58a6b4e0a851224df0e69d06332da16510bfa83da302d30c312d130bd44c2d4b8a42ab68f51a223424
699	4	2025-04-03 05:37:00	t	f	\\xc30d04070302cf51ac15e7c74abd7bd23701b17840c707aa3de5cd10304b128535036da8c6a1dc2d3eff9f008554bad78a52c987426dbc7aa7f24b2faf6fe74f9aa7e9b828addede
700	3	2025-04-03 05:38:00	t	f	\\xc30d04070302b64edbcf797a4a6d65d2360145f95f68c28c3d68b28f221495258be9de449b0893d2f1cbe0d484dffe7ee76681d19252d19410edb37a1d5d0d9b15b7b02dae075e
701	4	2025-04-03 05:38:00	t	f	\\xc30d04070302d244ed5550908c687fd23601eed066a4569620a3844a5c41174cc167a065d0b3d2ac82ef5866b09b5195ef999fbdae8377d047bd929c7d1b296248e945950fb33e
702	3	2025-04-03 05:39:00	t	f	\\xc30d040703027f01683c557c32917ad23601eb66c374980a69adc6a8e31e2fd289daf97c2818625e3b87f8a57e530e5801429eeac83e9f30a869dd5ca1e7cd67eaac562cc00eb9
703	4	2025-04-03 05:39:00	t	f	\\xc30d04070302597edee3d66a147f7fd23701a12e1bf4e3a2fafbae1d9327ebd5fa6d7360873eef159f0212f1abfeb372a6a925bc234769692d4c3d417209bbad689f0dc28f8d9a43
704	3	2025-04-03 05:40:00	t	f	\\xc30d04070302a6d7a58b0fd050ba61d23601c256f7d67d8ac7e0de26641c494a0f2d3b7231bef6394386ebc1d6798c5500016423f809c7087d9ef69fb284ee51de73992edadd1f
705	4	2025-04-03 05:40:00	t	f	\\xc30d040703026cab601be14be73269d236019a7c79cb91f04b8fa8afe4a78cb80cf790dcd49d96dc6b40873e8fd611ecd59ffdffa7977fa1d7ab27c482e419fc890a043b2ab16f
706	3	2025-04-03 05:41:00	t	f	\\xc30d0407030286e27a580d8f9ca57cd23501bfe2bd590a2af2a4e7129ce243be427d5212ab43f295adc8029053cf532215c6e08724fe8a2f3c3841a3bc3ce766cd14d8968b7e
707	4	2025-04-03 05:41:00	t	f	\\xc30d040703028e01c2e2901b8ba06bd23501e36a80bba915fa205ab8d63ef21f4b683a60b230eea163be8abee0c27e228387c7d091ef9f53f6eb682bc1d5838ea1c14074ad50
708	3	2025-04-03 05:42:00	t	f	\\xc30d040703028b6233ab7638680764d236013c84d6889325a4030f172ed52405de80497ff6038070394c75020776395203b2c5f237c37a1ed741de19e36bcf02f6abc845fffaee
709	4	2025-04-03 05:42:00	t	f	\\xc30d04070302f03ed386880f5fe06ad237010f15afc7e4ea5f97d37a588739d3a157286a865f808ea1a463b194fd5942edd53f2fbd9f158d783d3356ac3379fb50d46c67cba88a01
710	3	2025-04-03 05:43:00	t	f	\\xc30d040703020921572ab6c17eaf6ed23601df19acbdb35fe6e24fe8500c5d6427cc03bcf1c872e85c57f3d89433f2077904667ca3731b1c1c4eafad8c4470a8468efa2b550d20
711	4	2025-04-03 05:43:00	t	f	\\xc30d04070302e59dd2ebb55cd2a76dd23601f6bff939cd8ac6cc45b1b23dfd2da70dea8d2869047f17b41a66f6176f65b727924c54f575dc970e528018dfd9c171eb596111cd0e
712	3	2025-04-03 05:44:00	t	f	\\xc30d04070302240eb670b0fca88472d236016c6cb8c2545399f6e4f754da68c742135dd5adb91b45fbaf3f22e25a8a9c6bcd09f3579400ac614dd3df8113d5f9ac61c2de9f4075
713	4	2025-04-03 05:44:00	t	f	\\xc30d04070302416751d0296ef59e65d237010a0b91a813791c67b6620385b05324ecb50bdf27036290260682ded365696bbca68d2035b9ff8907ebc8d5ce2127c0e4b8002769c4ef
714	3	2025-04-03 05:45:00	t	f	\\xc30d04070302090b02bc5a12a11e63d2360171d4643eb3995a3efdda767b6f8f952b3c4d643cb9e1fd03dcb18f9282e378a33cdfdc3449a54eb3f97fe89ff29221de45e3dc3eec
715	4	2025-04-03 05:45:00	t	f	\\xc30d04070302e0c748c97b82add679d23701473860255baa85b841995f5b0a0ddb6936349da559fed59b23d6127317dc303dcdee16d3682e643115fda0e9a2fd6c8f3f3d1b07d105
716	3	2025-04-03 05:46:00	t	f	\\xc30d0407030291b1146de18c99e67dd23601c889555b19abb4921624bc20b1be7a0b79972b08b43a2a511249d9774e7ae64564a85a03f3f60cd8f68433a5e8aca92535179e6817
717	4	2025-04-03 05:46:00	t	f	\\xc30d0407030213fcee15caf8edcb62d237011f99b6fd4f53d8b3608d6f72df413fa6adf9070a4f088d84262cfcb2b2735c9ade42d73bb48f0087ab3f9733faad76740737fde6d374
718	3	2025-04-03 05:47:00	t	f	\\xc30d040703020e6d0ad05dfa6a847fd236014a312adb1c8148504b9f2646f82ca7ec92864e50beffad5b09bacb1a8e9c251d8c4c2e2f39f2fa19faf0a3e7d10b0e38393cc70b1a
719	4	2025-04-03 05:47:00	t	f	\\xc30d04070302c86f31f13fbf978270d237014c90e9b47a9cea91a2f47da3c96907f567122e8b5a0197bf5f1eb6dfbabd56bb7d97ef43ede670e266bea67f5a8fc20627acae08dd0e
720	3	2025-04-03 05:48:00	t	f	\\xc30d04070302c4d13f0e42da74f169d2360160f6883c2e9f97a5038f2cbe4053979ad6e8059f4f885712319c9f65b67adcc3f1f462dff8b07aed1b477db4e4019e4e92f1c65193
721	4	2025-04-03 05:48:00	t	f	\\xc30d04070302b305bdbc0d4370e775d23701d7c0c34c73d9c4e6dff9d9dce78b1bbc14e0d7ef4dbd1409ad14b1599b218fdd363404ffa81aa69d7be002d86496759187c12b911de2
722	3	2025-04-03 05:49:00	t	f	\\xc30d04070302414f30472e1aeda17ad2360161487fc280c32b5e1dd3d3e0de17dd922f58e0aceb7bb48985373d4da730fa4d8c613b2894cf20d490875901a62a40f86f4ad3d23a
723	4	2025-04-03 05:49:00	t	f	\\xc30d04070302add6677eb74db1766ed237010ebf5f2de4b06867848994cc424ff84523ea4d37c87ab114a95d33a0260fdba63a48ea3efe5352e490bd13c74797c0201115bc0c5c2d
724	3	2025-04-03 05:50:00	t	f	\\xc30d04070302d79101a5900f2f2464d23601d281fcecf06f5dbc7a29dafce9e5f706f0887a914e6c7333dee9b6c244909b34a47b67d94fda0504213bf6e38f7d62705d07e45826
725	4	2025-04-03 05:50:00	t	f	\\xc30d04070302548c265a401efa266dd23701fd9177e9b39a8b395132919b8bc917b6de095c34dda7db8c96308d825dea83744296404f168037705b29d63dc1598e7e0e46bf939795
726	3	2025-04-03 05:51:00	t	f	\\xc30d04070302c11f04b94552a1f16bd235013757a0cdd42096bd26b8c6e001308a79eda9b2bf80cb7b90ea55df95f0369f7f67b3076384d5fb77473e50bbe64d90352e87c157
727	4	2025-04-03 05:51:00	t	f	\\xc30d04070302abe4aeda188b9ee268d236012bac2947f69ad0d3bf7059b316f4d9f499221ec9ed5d32cfcbc6ce3aba5e4f8a6d39f7123c3afce8f667855ce11f43a2881bc4dd0b
728	3	2025-04-03 05:52:00	t	f	\\xc30d0407030226a2d651347ca09270d23601ba0aebe3df3f4bfa630f302834a937f356de0bdc5d8425d75b28989b1ffbd90ec62f8dcecc63c7f515c1d2b7bbeeecd616b90cfec5
729	4	2025-04-03 05:52:00	t	f	\\xc30d040703024484f0e907a2b29060d23701f40087beb27cd067182703118d3c6fa57557ee9b4a98172498c0902d33fabbef314bed4c0bdc4c3f2a0f86d7c4f58228760d203a49fb
730	3	2025-04-03 05:53:00	t	f	\\xc30d04070302a422061384ad8f8563d236016947697540b80379cfd8c6748510a8d9890f360b71342a929a39b4e47d2f85d582d777c469ae433ab25d459a126f76d931b88f842f
731	4	2025-04-03 05:53:00	t	f	\\xc30d040703021f90d88e0552e09d7fd23701c4eadb622ca7cda1b40c5497b4bc7d10f83316da99a1f2c0f86a8eca15dadeb49630afb1ea8f2e53bb4fb9d6ce3d536ff355f05ce234
732	3	2025-04-03 05:54:00	t	f	\\xc30d04070302fb5d9ef301fe8f396dd23501157197f58cbdf901fa7e825eb4be78ee3dff39de92659d84b2e714f86959b5badc83148d0c0cd8822bcf6a2098b80a13233eb380
733	4	2025-04-03 05:54:00	t	f	\\xc30d040703021a05bb351f539a927ad237017981fc0c0e30f51fad14fa425ba87cbfc13abc7fd785de925989fca58ce0922993833359b7a01a4fea3593864042664709923102faea
734	3	2025-04-03 05:55:00	t	f	\\xc30d04070302b35ac089f52c669976d2360122fd157df4e319b7ea55404a4eb9e6522275603ce585017da1fa65acfc1a3d8812cfd2cd8906069b1337e740b75f86516181e4d3ed
735	4	2025-04-03 05:55:00	t	f	\\xc30d04070302e3564813eb80070665d23701a73880281b5a260646642561de00a666e6013f721189d1046a47cf5f69bcf7796d16ec21ceaa4d2c2e1fa77a948d6ba29dbeb2317bb7
736	3	2025-04-03 05:56:00	t	f	\\xc30d0407030284510fa1e3f0ee5f7ad23601bc40abdaba16c5782a20a0fd1a11e4b6c4b4050e1eb5ff220442e5683b53c1bb9faca3bfb4f71f6ee71617c98fdea7bb3b8716f82d
737	4	2025-04-03 05:56:00	t	f	\\xc30d04070302e8d858362486249b74d23701a6370282bb4c5c11b3cdc16b1ba05b038373ad5d3d9a7d7e4f15637da88e1e5718f6ea7b4e26299f9fc2926553a08733c27af7bdac30
738	3	2025-04-03 05:57:00	t	f	\\xc30d0407030259181aef0ded67e478d2350198fc863c0bd77759d5344c42a3ed03de45b253850f04ac7de6108c28eb635372cd153d77306c444fa80e577dd9bd066d3e169fde
739	4	2025-04-03 05:57:00	t	f	\\xc30d0407030291d030e0b1d3e48462d2360144444c516a7a7c9bfa47958071fc5f9ba09526e1f4f060b5f58dc6ee72044be40c650cfaace9e5da7208f9318452744f4af14f188a
740	3	2025-04-03 05:58:00	t	f	\\xc30d04070302ed6b9f8fd643d59b72d23601ebc3faa872f9efa43035c8e0f9a16baaca7aba67034b956cda4c58792241b7e72394dafb0cefd45692e9006afaa3b15c2085de504e
741	4	2025-04-03 05:58:00	t	f	\\xc30d04070302094a45478f762eac6ed23701189db7ac49ff9aeec2e406107dece9aa16a1794063ecd442c0fa49fc2c305bd3b72829e8a2450f6e92ec6e1fbbfc171440e79838dcef
742	3	2025-04-03 05:59:00	t	f	\\xc30d040703026aae1561b5d42a8e7dd236011f6a66d193525e6bb9eebf8a02066fb669f425fbc7247e69e1a167f023faee36e850282bd13b03f90ce3255f54352990c57ef3338b
743	4	2025-04-03 05:59:00	t	f	\\xc30d04070302e36c60471eaba7b97bd2360103d1aa50749f884a6850dab5faf44478efb9e3f8780f1831941ceaf02e5e2a7d936a39ad82403ba607f22c7a0ead76336e801d74c1
744	3	2025-04-03 06:00:00	t	f	\\xc30d0407030238c9265b7ac1cc816ed236014d92d6efa7038415a3ba1997029e361fc3f3e0697f797697f1f68e3bc47e5e877180aa253e16101f890c8a4cefd4ea732e70a71c47
745	4	2025-04-03 06:00:00	t	f	\\xc30d04070302e3154cc47cc4023765d2370128fb15047e37ac77b77f7d18438b1e347636c78c7be06ba42ca4903127510543b68d700bf0aa0f0f7ce9f25fa455ee01f5f3a52189cf
746	3	2025-04-03 06:01:00	t	f	\\xc30d04070302c03bbb1f8213c0cf68d23601c555a677dc3a8a2292f987022d051d113ba04347508fe8d9954bd090ebc0bcd0bfbc452126e600ed32a378969f0578156cb42d4833
747	4	2025-04-03 06:01:00	t	f	\\xc30d040703021b57447d8c3f3c6a68d237017b9d91ffd88d0a78730e0e7913e125f895674bc8914cdb1429d114b3a62f9774dbd5661af104b9a21d18a5a1e6c767adef112c8c1c9e
748	3	2025-04-03 06:02:00	t	f	\\xc30d040703029b2b60f1c4f8550b62d236016c7740f5af1f2034313ced88f66916eacc6cecd68c2af7dde913fe962c11740229a72ead03b3e34f204c41dfd812a116789b63d16c
749	4	2025-04-03 06:02:00	t	f	\\xc30d040703028918896928a064d361d23701a63c6189c7d115d5ebc4021778e85417ba959ee9f0e140afb6f85b58d1e00b796c1ba04eab757c595bb80d58c24a37bb14481dd290f4
750	3	2025-04-03 06:03:00	t	f	\\xc30d0407030220bca71402cfd9b270d23601e5986eb4df5ede88bc272e01d2a87cfbb9ab303886113a5917fda197dbc9fa1427aef661bce602593b25b6c36f80cc84918b064679
751	4	2025-04-03 06:03:00	t	f	\\xc30d040703024893899ef88a13346fd23601a2b68d00afe5613237a4d85fd286b8b10cb116fbfd79e0329c8798a4d6b1baced2bcb2ec5b7029a1d853a9b1eb3ceee312db9a4d32
752	3	2025-04-03 06:04:00	t	f	\\xc30d0407030278c906b454937b5070d236018f5db3c5b3fdb2f1c08695cba2e769879f0b438b929e15e48501f8c160e70809b81684d2f01ca90f1a60179560fe15ee2d3b8f28e2
753	4	2025-04-03 06:04:00	t	f	\\xc30d0407030293aea378df5736177ad23701b437b522036c3cdb22cfb0978f5111e085520a5bb0ed26343dd5210c48fd4e4f364fb3743290245d53aded596177cfc3290248566dfc
754	3	2025-04-03 06:05:00	t	f	\\xc30d0407030281515010bd31861460d236012a7ac7eef1d383d11a8e400a9d5d2be402b2aed8c9dc61e3d0d047095cd43016aefa137e320514e834584e399292ae20ea7c84aa03
755	4	2025-04-03 06:05:00	t	f	\\xc30d04070302dd346eebae5a628276d237017306b3e98ae5e04c02b95cfa256c5558c013820bed5bf8f645c48833d496de318e11467c0bc2fc2c3b4ff46fbb7e9816b5238172c16a
756	3	2025-04-03 06:06:00	t	f	\\xc30d04070302523e1f883651b1fe6fd236016fb4c199deef4e6723dfc40c2d3368d724c79cff3bf7133d0b31530a1e92a907070047c03ea8b5be46de472b826e8129016d3de6c8
757	4	2025-04-03 06:06:00	t	f	\\xc30d04070302531db4822c67acda67d23701ad69d6890366e2d3b182bf811373d9d232acb935d7e73e2dda2d412d4875fb66629b5ff8ce0e6c568eb147b4c6d0ae7cf87450871cba
758	3	2025-04-03 06:07:00	t	f	\\xc30d0407030247da067488e9d48f6ed236014ef5ecbb620d2796604994c86d29725a63e50de097497632a7acf74631e4c06f8dcc0c968b910f2775ef3b65e9c1e91033b2795957
759	4	2025-04-03 06:07:00	t	f	\\xc30d04070302a88b4fbc68da0ec46ed237013ab655e6a61fbe7369062f21786fe6c2191b9d35229e460f3b994ef3edc6af1a816ef4521f7bbf6cfbbbcb976d590599ce4268b733de
760	3	2025-04-03 06:08:00	t	f	\\xc30d04070302f5d240937a3b460276d235011f5f947838e51976b9540557b752fd633fb29ed37470059fa5f9da82733ab71d3a122fd3f7e086d860088bca17a8197ed4faa919
761	4	2025-04-03 06:08:00	t	f	\\xc30d0407030205aabee4d6fa329f70d237014b07b52db66028cf27bd4fe2130138120cc7bded6a59f5655fc23b8ebc1535a7c964addfe424450fe459bd3f2988f03065fbfa0561f7
762	3	2025-04-03 06:09:00	t	f	\\xc30d040703020b4f1b96e47a14347ed236014da18455e51e52e3c72bfd4394872b4d05381e888a189ed57ceeb1eb8ba33ee720733194bf4da9a5a2fb7d9bf9e1f56109ffb9d015
763	4	2025-04-03 06:09:00	t	f	\\xc30d04070302604c5213ffe61c2f6bd23701dc0c76cee5b5aa194d026cd3b5304525169b21ab60b5a93f2065b5be410262841af75fd79fa7e1a031988327558db5474db8a66990cc
764	3	2025-04-03 06:10:00	t	f	\\xc30d04070302f3268c750c57f77372d23601c292c7f0ee8d33ab885037a4cefbd086116a4a5afac2cde9a966fba142dfe396f26564829fa4be049727fb6b883691a481ab0ce907
765	4	2025-04-03 06:10:00	t	f	\\xc30d0407030297382e356100b8bc70d237011b9d0ce2752e7f72cddf41630cd35a0296099547074cd2529fb138ca14119ab61fe33160a7865f20a7853153d8be791f5af3a27c856c
766	3	2025-04-03 06:11:00	t	f	\\xc30d040703029599c05b08de030a61d23601ae7ada3a0ab90a2688ef8fcd798762713276578e8a21008366b549aba2504c04cff48a141712ae623ddc93874ddaff0293c76c50d3
767	4	2025-04-03 06:11:00	t	f	\\xc30d0407030202247a47a9af266965d2370134cd9f6fe8b47e95d6cdb821df6438d6fc92b06571df50c73eca4bb0dfcb75085b18e5075dbda5eca141b2bee0e534071c11831a636b
768	3	2025-04-03 06:12:00	t	f	\\xc30d040703026113a7a65278549172d23601b2ca98316334e72452eadabdbadc0ac1bb0dbba676537f74743161d25f16a06dea8b930890ce9c104330e08ed275a595ef03b5ac68
769	4	2025-04-03 06:12:00	t	f	\\xc30d0407030270d2853a51c3827d6ed23701ad1ba8147043b033f4cba6453484e54b61994bf9be7d99b9ab3f61b627f6e81d82f5670ff63f7f02a27bf53e810b1031560375ccf4d9
770	3	2025-04-03 06:13:00	t	f	\\xc30d040703022b701946759849bb77d23601884b995c7ddb7393c3fab6c377e75fffcbb22f2833161efceeb6269727770776441493ea3378adeb133189f0e710773782f593b15f
771	4	2025-04-03 06:13:00	t	f	\\xc30d04070302cdac00a0e54fd0eb65d237013bbef451293a3c09aeae50de8e46db4c5746694802a85317f392c8bf2a739ff7cac8471d21c219bdf06c983650b7c47c943fa3253b58
772	3	2025-04-03 06:14:00	t	f	\\xc30d0407030282572b270375970c60d23601204841a5b3a18985d8ae3d9703378328137908e6d30829f35adda4d8915dec2a1c747ebdbbb8a3ced93549c234f89b4a04336381c0
773	4	2025-04-03 06:14:00	t	f	\\xc30d04070302e4946392289591bd69d2370172825df7123110602da34d215b2fbcb0c64292eab293d880ba550238a2b128d9d31133e710d31d0c1669a120195d53a97c1e2df5eae0
774	3	2025-04-03 06:15:00	t	f	\\xc30d040703023942136d9ad1d3706cd236016c0cdbc6cfb87ef1b60c899c70a2b579c72def72829c5872c696d3d0a04b3f1fd81f7e77db1a5e1308cd0de3cfc0f955b3dec0000a
775	4	2025-04-03 06:15:00	t	f	\\xc30d04070302fbc00eb40b860a657dd237011bab6cc9ae6a9dc8059c7fd738f682bea25ef237bb40e4ddcfb4e1b94b566b24960095cb74efca332aea71a298035f900d5dba0804ac
776	3	2025-04-03 06:16:00	t	f	\\xc30d04070302ca192b294cf902846dd23601074fc08acfaa7e4f3d8190c6983cdd9386c9d1df71b7b75f9b3ad94d97628e55ab2c60641fef82b1698fc8be2549b4e9f408cad15e
777	4	2025-04-03 06:16:00	t	f	\\xc30d04070302290fbb2caa7e67d969d2370122ced5b3f1cacfd2394c9310796dae1b5a3aa3229a66d4e2f2e9fee59b989d47a6767092dbcf08f4ac9e44817c22bd7503c725d5d466
778	3	2025-04-03 06:17:00	t	f	\\xc30d0407030267da512bbfcedf3b6bd236013e2fa1777ce27713a673afd7cd52b7987bfabd8aa8a07b5b2209ad20a8a11461a155912501faaffd857458f7442ea4dcfcddd86289
779	4	2025-04-03 06:17:00	t	f	\\xc30d0407030294a603e31bf0b0bd7dd23701c16db1c1ad6fdf1400b2f2582c103c6882f145ab5fc2794819dbbf028934bb650effe37fa570a96bb8d6c45fa3c05b2abb3552e833ba
780	3	2025-04-03 06:18:00	t	f	\\xc30d040703025ee555e7bbe1e44375d236015c88cf84da0779b92aa04b6c4b99d35bf972e1a444cc449a206c316e1eb99c61e3ec708982c958a881ba87f09a322a2e58c90ae910
781	4	2025-04-03 06:18:00	t	f	\\xc30d040703027df64450a14d37e779d23601630d067872b892e795d228f6e2c7312c5c9f96ae1a1c7fb359d58e8db6d6af903f2ba39a92c3202840126a5fb39404a38bb6663353
782	3	2025-04-03 06:19:00	t	f	\\xc30d0407030283cd067a040496807ed23601854a18b18edcc5e0903225ac44ff59e1441da66a5081accb1e14d6d13067d70aff80be93cbead94646b4ef62975681495f0c137591
783	4	2025-04-03 06:19:00	t	f	\\xc30d04070302a327cfa3a9285e1870d237010014d3aa9414b328f2569325d182f223aa765e943dcffae81d10ecfd0ca88385814ceee55220f56ae19ee6a0c253b3d3e861d3de330e
784	3	2025-04-03 06:20:00	t	f	\\xc30d04070302b0481dfca71faaad64d236017b509aa14ace911ceee05b634d6253d142b764fb4d188f8d9cf48359e66b8f48f6fc3c2c15ebddb6a71d80ad40ea820944663deca1
785	4	2025-04-03 06:20:00	t	f	\\xc30d040703028e318d5b7076570672d237019abeaebadecb79e53498b3449eb90d0d718c25358d51479be57c7627b2522c5a78724f977e9b2e450de6ac759fce35d640e36715a13f
786	3	2025-04-03 06:21:00	t	f	\\xc30d040703027b6b25847a178e3269d2360133b1cb8ee5b71594e15a1cb9ec022f2459937d38e29a8dd16497fd98ea25ae9d3d4102efc220dad514d9c5a0539812c4e2461c1b31
787	4	2025-04-03 06:21:00	t	f	\\xc30d04070302adeac0a35cb04bad7ed2370141df474a1a308c18742175d281880cd1da91e3ee3c43a7c5d4b183f30eeafc11dea4665c5dfd8556437524cc09c029566694db36a656
788	3	2025-04-03 06:22:00	t	f	\\xc30d04070302a3f24500786dfa706bd23601273eebea0e8489761a55b033b6fafe3b5d29f4e7afdf812f589878917d7264ac1e0ac95b2f65cd906eb25b9aa50c77d4e614b8ab73
789	4	2025-04-03 06:22:00	t	f	\\xc30d04070302c231cdc49bec6b4064d23701b9ad57c4e6ef63aa96fb6f13e19853594144c0681dc47e67bbb19730423cd12f3f858869b80f3f0a160ea28718ecc9803f137ac57e7a
790	3	2025-04-03 06:23:00	t	f	\\xc30d04070302ea0d0cbbe27a421769d236019eac87b1a6aff90ffdf6b422685d558cfabee2b3c9965f68731538160d1796cf37494eb3630d240120872bf0551ce38ac700914d5f
791	4	2025-04-03 06:23:00	t	f	\\xc30d0407030259ab0c5294d9067770d23601fa7382157ed4862fdfcd96460f8b503964d20fb60b159e62c03c50378f3a78da225326d83092f7dc4c4f0cf08f7d35c3e0fe9728a0
792	3	2025-04-03 06:24:00	t	f	\\xc30d0407030227d322a2afd031f87bd23601d83c621966ef166a8515ca40af038ca4c57957c0daddf1b01c5982628f008b7bc828b9acc4e2a4f5eb474635fbffc32b12d78c8fe6
793	4	2025-04-03 06:24:00	t	f	\\xc30d040703025093fec61656cb4d7bd237010004efa4946148ee6dffcea67543f73a5fd5367ce898348b4ed138faae7e9da1175e66b48d80b8d6791f87796bf3dadaa0ae404dfce5
794	3	2025-04-03 06:25:00	t	f	\\xc30d04070302a135d6ed064ccca564d2360103f20e0178ffe30f6cddbe25af11ba2c25ccd08ddd6632793a42ea8a9117068575c54ea53857da3e6aefd614fe2d321868b29828e8
795	4	2025-04-03 06:25:00	t	f	\\xc30d04070302e225fd2e4d5b2a126cd2360185e87e135e43b0c8b05b1035f76bf105e5c8d4afb18299d9adbd9b691f85d5164940b12fbc76af04bc0ad7d5e42514d729db87fc5d
796	3	2025-04-03 06:26:00	t	f	\\xc30d040703021eaa0b82487ef3c07cd23601743094892ecb06c47f4c71ff6e2c2b757250ff0be42da89040a677b8dafbc4c43fadbad5a8906de23e61dcacd56486ae4bd3033b53
797	4	2025-04-03 06:26:00	t	f	\\xc30d0407030209a703256050e3176fd23701d932d7f0f1d67a8f390a91c9c33cb996a6c94e9e252966840ae692db1399a5b43caf86610ffc9187c8efdc42239ab52ee0d340f8be1a
798	3	2025-04-03 06:27:00	t	f	\\xc30d04070302e768e6626dc332d664d23501d7cdf9e48239001380b045106af82083e4f6098d97d96e3db38b028e688abe35e605a477cf28ce9b42d76a3cfc4ec883fdff7434
799	4	2025-04-03 06:27:00	t	f	\\xc30d04070302b88f986b8a3dfbc961d237011a5995668dc799913614bf3266ffdaf36aeeeab976415c0cd3ee42afa60f8b1f4d5b105bfbd93bfdee8aaa2287075a5bfb5f6dce22ff
800	3	2025-04-03 06:28:00	t	f	\\xc30d0407030237a4b57c2e4d26df6dd236016c626198f6ff28285f04ae50aa44bbb9c8a649d438e41b204a7396fd95a3376760802e6448031c58256d68cba4a959bea133334f2d
801	4	2025-04-03 06:28:00	t	f	\\xc30d040703023f5b5a5f881be07e6ed2370134993f4a49020396ce6c461d0665655419b9cc676d20ab25fc06f4a5ff1b39259ab7e75cbf1d06a07f4f2011441d9f92935618a2d687
802	3	2025-04-03 06:29:00	t	f	\\xc30d04070302deae5e230cf00e106fd23501fba7391b8fe2129705159b974be788b4d94a7240571450013c0860538f03f6e6ef7a26281c270360661cd4127b3a5650a62b102a
803	4	2025-04-03 06:29:00	t	f	\\xc30d04070302d844e6e590c7b60c78d2370111debe5ca7fba0ff663d5477a24d3d7ef0d32ef24853d3f2736221d524b84086eb614d090716fa4546395f8d39a0ad8b72beb4f3637b
804	3	2025-04-03 06:30:00	t	f	\\xc30d04070302e78d0e89663b6e7c7bd2360197053ec47b3f204725a163e9080c7839649ecbbb716aca559a47f0b41c200f7d0e70318f4c84168906cdfb52fdb1af8ce5ed6dbd10
805	4	2025-04-03 06:30:00	t	f	\\xc30d040703028af9197bb420608f70d23701e1a249cb31c46772be0b7761b67c415894a450dda2492dfb22a4602324e7af26817887249925c3687ebf2fbf315f36b5a042f6ffabe5
806	3	2025-04-03 06:31:00	t	f	\\xc30d0407030230434f314269686e65d23601e34a7ee6fa94a0d27d2a0dd88aa5832aceca87b469f97847eecde3fb9ce90b57aae805c0852c089b4c10e36c9d948da3d8d460ca4d
807	4	2025-04-03 06:31:00	t	f	\\xc30d040703022c2f46b535cd5b436fd23601793540083e27f8e83224ab24fc12b4f8f8b52d4ef24919802249302e3649ac5970a5c8b726954b76933f4608e69457e57e494e33fe
808	3	2025-04-03 06:32:00	t	f	\\xc30d040703024bc6c1612043f7af6ad23601c3c9feaabc9950e98393ac78a374ed18f7c568cd7476f075101f72ce51b04e99a08c08bd1cca4e3ef44c54303ecad2e182f1c586e3
809	4	2025-04-03 06:32:00	t	f	\\xc30d040703024e4c862bf6b7f63a75d23701ac528fc58cf51fe359523588a1694a3bdd9c3b5766cef8f7881ed3ac56a2ebbf8a565a3b8e33aaea637e647fa849f31d94f76be20417
810	3	2025-04-03 06:33:00	t	f	\\xc30d0407030237b0b5a521ea99b367d2360130e77059ed4655fe3c987f4943efa6043e019af44b670a9ec13c1b9d565c30690f4530ce864e810d09a01d04b5de5fc3badc5503b5
811	4	2025-04-03 06:33:00	t	f	\\xc30d0407030212fd5af80256ba706cd23701226c24a1eb6ee510e18fa7b27feea7ea4dd88f344372d1b1f0fc53a06841f536838c63cfce0407561d662041e37a2d274dbf10f000a8
812	3	2025-04-03 06:34:00	t	f	\\xc30d04070302061f7d1992518c5877d23601f66bb26bc102ce46c186b27f0577101763aea0cfe368c5fd6ecb1695c99eeea236f1b0420f214593ae0589b98f42398b1db2590251
813	4	2025-04-03 06:34:00	t	f	\\xc30d040703021f357dac8c19289863d237016a3ea2c5913860ef09a1ee227beb9ef8fc3540eb1f2876133c976052a2efee02e2927881490ba627ef60e6624d526f6ac38812e158a7
814	3	2025-04-03 06:35:00	t	f	\\xc30d0407030258d33fa990bf95bc76d2360104115cd9c6516fb49b0ac8a1719071f69f1bfa3000220ea1dbe0d57ec548f68ab559a71cb4429f766ee8b40bd40c88a33a5f605af3
815	4	2025-04-03 06:35:00	t	f	\\xc30d04070302331f843e74bd19b578d23701746505def69928715f2bda08a38942830fe69ddc28b503ad7a52eb3f547e1bc025112c75948361a41df5eaf36c21f1f05f88500f9b83
816	3	2025-04-03 06:36:00	t	f	\\xc30d04070302a5acceba2e5768bf79d236016e4c1fbe9f1d6bdf29778d901f39cb943fca4da996365946be2d95ae57c70a24114c34544fb77081025d7fa736072334b968912014
817	4	2025-04-03 06:36:00	t	f	\\xc30d04070302978677ecbee5750374d23601a186dcf90fc7ae00bce431bbae1cd00c73286746704199d523dc5468edba2a5748464b19872e91c563738dbd892958319ed665eefb
818	3	2025-04-03 06:37:00	t	f	\\xc30d04070302af22ce87d66b190d7fd2360197fa2ed8157cdb6744438f31d34ea2ec60d1903b19f6c0fb45a0d3d69f247ff89d83549a8e39cc31adea6e03a2fc4f11bef6d0d8e9
819	4	2025-04-03 06:37:00	t	f	\\xc30d04070302cb6c9100c2cd433462d23701abea439602155271bb21885bddaa7b1d7f3f4867de30f38a46aedc92eefe530e0ac3f699820aa411e18cf76e8691b200a18246f404a2
820	3	2025-04-03 06:38:00	t	f	\\xc30d040703022225da748ed3de4e78d236012e18984729fd7c7b3f01c763f65398d1a12a56aaee3984deabff6e3c967da03594a6b5cad2e4e354c7e4eec686b0558b0e842a4abf
821	4	2025-04-03 06:38:00	t	f	\\xc30d04070302f96f80c4711dc03468d23701ccc3d4329e1ebb84d3881bfdf46edffb9acdd01211f1d83de9825859cb04deeafc22e162f403f36cf92b9876428c50bbba202645b195
822	3	2025-04-03 06:39:00	t	f	\\xc30d04070302f8145d5b960cc8e768d2360115dca5bfabe065ae745e430048744afa382ce8782006d889392a66ee34ffdecd57d95e7205461beb1a656b0ed477709638339aab2b
823	4	2025-04-03 06:39:00	t	f	\\xc30d04070302ff6dafec721c775777d2360192178879b3c40ba47992ee65aaaac13d24801158d7286cea19d5d71982682e60212d1da74b09ad590600527d199b1a6127ef2f8808
824	3	2025-04-03 06:40:00	t	f	\\xc30d04070302a3a2f343755b75f071d2360113f59f716a46741d3be95c2b6d5d598a72ff3843fe576e43ac66df22b4c3ba6d02f04c7ea036980f76d7dcbf926b9c3c9126557ce5
825	4	2025-04-03 06:40:00	t	f	\\xc30d0407030297d336256b29eb0969d237017c13bc2ecff6def936ca9546e229bd3ed9e8dcaa9e4b8e79e47a8505603a20100e0818e3fefae44d573701689922cec98bd06ab0cc80
826	3	2025-04-03 06:41:00	t	f	\\xc30d04070302464c47d3bec3086d6ad236019ade7927b257a4538d99533669dfd22186ca127366a574783e26a6a5c1938c445411b113ffb90d55eb75556a65bcfd5f6afaac9b30
827	4	2025-04-03 06:41:00	t	f	\\xc30d040703020252f46b32b664d170d23701ec5e7df2a12be3cf4ee9055ab99568f83ede7c291857fb723a6ea9f86df71468edd396768ab8550a63ba933b89edfc5672c98781f01d
828	3	2025-04-03 06:42:00	t	f	\\xc30d04070302739e4b1dc6c6a3977dd235018a895a604f08e7941691ce093e7e97efdb5e82baababfb56904c1e3e703e4c37d0324f4f1bc87472eec365f2ccd12a1b837b43be
829	4	2025-04-03 06:42:00	t	f	\\xc30d0407030237ce11fdb110d43e7dd23701baea39e242c68a5f8d634a2a980cb54997dc64d4ad5e8d1476f94eceaac55330214901fc70c3142ddcfc27fd9565283a5a74084a2fc5
830	3	2025-04-03 06:43:00	t	f	\\xc30d04070302fb97cf43d45770906dd2360141409e63802e9cbfe5aa41023d7e4b228a4188f717688cd3c78f45f6a3ecebc6257630133cf5bc2704b5efb03f4e9158cca0bb264f
831	4	2025-04-03 06:43:00	t	f	\\xc30d040703025c7f9542d488911f7bd237011853edd98b49a138dcde684e0207a172f238048a52aed39efab92681dbfb510d0d98b0d4e2c4159d5ec93d51158a5566ccad5f778895
832	3	2025-04-03 06:44:00	t	f	\\xc30d04070302c514694ce8a0fa5172d23601292d4ddae5cccdfed52299364daa1a5c8ffc09cac6eb770ecbd72ed455c07bb0b5f8c5c23cb6b744573d2c9e209c199cc0e7a08b50
833	4	2025-04-03 06:44:00	t	f	\\xc30d04070302be7487a424975ed77dd237010977dadb9bc235bd2023b034f1dac0a4a6c055f39a546d08bbdaab9e1861615f4036df3593f1f4d5cca10a5f3b0dabb783a6359f44ee
834	3	2025-04-03 06:45:00	t	f	\\xc30d040703020c44c6109ceb90e279d23601e2f3956a24e182c43ef6c88c126955087062daa5aa28e8d333c31913bd3971ff1cfa50a2e8666075fa7401e74c85b016053dc57ddf
835	4	2025-04-03 06:45:00	t	f	\\xc30d040703022570eb1e8342f1ed79d2360150d3eb21518bdc0463c0859a4c66ab4ba0cd3d471482840e27819c1db91dbccb3bfaac6b4dc7cf9b3c71350a6d4aba574e3db554cc
836	3	2025-04-03 06:46:00	t	f	\\xc30d0407030237de3829582429a366d23601df87abef300f36717b4ab88c8973cee75fa161e0f92c3e201cb29f526140f13313a89671e9185759fbdf660ebe03d04fce57424905
837	4	2025-04-03 06:46:00	t	f	\\xc30d04070302929cfb23df95051b73d23701cc9f0ee27df686dd587b041f257244f7f5dcfaa81661cfb8022b33df4373ffb5361408b7394b09bec3ffa1a819d381be5b21c3b246d8
838	3	2025-04-03 06:47:00	t	f	\\xc30d040703025436bb32703ab4817ed23601b1454f0cc8d10cf2599cbf74740061a09054c3160543a987582133325858c6ab51659dee9bf415342ef1ca8a4619a061449c30220a
839	4	2025-04-03 06:47:00	t	f	\\xc30d040703022d5aa5347537fd0a70d237017bfcc9498023c844ebd7d1b38581b3415f9b85bb5f0b231d5c2339cf466cd7a2a1d2d25996105d13c9ec5341593f3d7c2b248d04c966
840	3	2025-04-03 06:48:00	t	f	\\xc30d0407030247c26a05a7f1013272d235011012895539f4229fbde225b52ebd02d82baff5e343bb06ddd9539b9d0d32f3c001d4384182087db3f046432bfde3d9e878d92347
841	4	2025-04-03 06:48:00	t	f	\\xc30d04070302459b54012f6b69f171d237010f0c8cdffe98065e29ff3f2daa4ebd818ec47006c22b878d15a4a2fd2fc3ab3268450039a42325426b494e4824b2456be000762abf9f
842	3	2025-04-03 06:49:00	t	f	\\xc30d0407030267ea1f64efac752767d2360159a8c375db4f7b89e868b7319ced2a25c861ddcb7ae28919b0b04267523287760f96fb5bd78b353556fd5f5d8912fdfc54ed413123
843	4	2025-04-03 06:49:00	t	f	\\xc30d04070302d477e2ba6d5a0de87bd2370153a5db7014614f90d98008ff732de4a5bae6f14c52c808d2221c9526c2c940c1200dbfa8d92908044501da62e657df2659e98038fc2f
844	3	2025-04-03 06:50:00	t	f	\\xc30d04070302123101867dfaa4af68d23601858bc1c4a393713b18289f70165c2d9ed0ec3a138fd7ac4fe40350e01623d774fdebceb55771dd3d6798a333691b99e94fd005b467
845	4	2025-04-03 06:50:00	t	f	\\xc30d040703024f300c4db02e217a76d23701c7bfc5c50158ba442898349d1b675426a86ff71e8cdca761e10e35db2f37d7bbdefa58c3c8eb4fffbccd727a17adc489da2e4b971704
846	3	2025-04-03 06:51:00	t	f	\\xc30d0407030280e1569319af06af63d23601b9970da9811241a9cce03c2af527b1d5258d000b3846a0904fba9a739116aedb6f1806f353ed7c67293063d70d39ffa4f939c5f4bb
847	4	2025-04-03 06:51:00	t	f	\\xc30d0407030294cf0b010c3cfb016ed23701439c0f9aa5ae621abb805523ae1ec107de4169e57047c1742d90e709c5edb72621fa3bb91c6c87194a75b0852ba9181c93cddd35b928
848	3	2025-04-03 06:52:00	t	f	\\xc30d040703028a70baf9184f58cd68d23601ecf584bb812e75fa6484c7b4c42e486b19fc6c43d442c69166735e3345651880ad55cb2b866bb3b5cf94f1f3435b04575379525f44
849	4	2025-04-03 06:52:00	t	f	\\xc30d0407030212591010f9f3fb3e69d23501c4a57ec7de67646d211abe918839b33a23ac95cbe46f526248680d6968c1fccd5b4e9c25932838535924ae8188a1fc98a6a37d84
850	3	2025-04-03 06:53:00	t	f	\\xc30d040703026122b4a2600c27357ad2360184a47ae4d30e6999e2cd3fe85ea1c2a408b6f47a7ff8d428a79c82920571447a42c9b493ecbbc1bba28f899386fe7018bb643698c7
851	4	2025-04-03 06:53:00	t	f	\\xc30d04070302b86e249fda29622775d237010e7a500f56d9ce639a67bc198b65d45770af6ee09758ec1b89cb5e30a0867a7354803707425e0e133b1dc5e87feb4431671b04d9ebf8
852	3	2025-04-03 06:54:00	t	f	\\xc30d04070302848979b35a2e8d5973d23601864300f64d4a6062b9d0b7ca4ce7b060ce040fa88cac3467fc35b8657584719c29b061fecf6f276dd65c20752e6da64fd998a93c13
853	4	2025-04-03 06:54:00	t	f	\\xc30d040703025a09b8c72e2b7dea75d2370188facd496c6bb22c8a6ceac9ada31988b3cff9e90dd3b4c6ea2b2207ed3b7ed1c66bb32e8df6be3e8ea269409739971a39d62b30737d
854	3	2025-04-03 06:55:00	t	f	\\xc30d04070302b1fd418e9f2dd66279d2360189040b7740d350759ef9c16a3261dbb4a80a7266bca61ce718a572af09e3cd1442d17e1258615a4756e16704713a275a7a2ee5cd98
855	4	2025-04-03 06:55:00	t	f	\\xc30d04070302c308027c2ba4d0937fd23701bff1d706575ab2f1bda71a1d787edeabc6f50d5a16e70ba75fe816e70ad11bfbb1b604c2d73db18cbe28be5941d062a3f7a758237077
856	3	2025-04-03 06:56:00	t	f	\\xc30d040703020e722b9698d926f171d23601ae9aed3441ad760700bf8e3d79ac3354e7be7257de2293c1aec988998dc4a438d228ebfcc4d40397c6c1629fc18093288482e22abf
857	4	2025-04-03 06:56:00	t	f	\\xc30d04070302b279839d5e71b35d70d237015ac42f60c436b20d077c0d789ec4a3a4e15587519a67939ff2c1a9bc102db517c06f3645cafb02172e086f64680374b3c7cfae78c69f
858	3	2025-04-03 06:57:00	t	f	\\xc30d04070302c7e954c8cea297f460d236012a41c610a2c30dbcdcccaeb4e61d82867bda53711de0a811d34fb37e39feebd9e2422544e1e2212793bb56fa5daad76051d08afe79
859	4	2025-04-03 06:57:00	t	f	\\xc30d040703027e2f61991ba21b0a67d23701e4cca21b1186ac9724771f48f042bcde2e62041b3ddcb25ae284c51a67c3a5ce340c0474dab6603102f278123daf8a7b13f7d07bf393
860	3	2025-04-03 06:58:00	t	f	\\xc30d0407030290cda5be0c7b325b73d236018adee90157a204179705dd4f75e65e0a38045e07c9d7c5f1325ce0a10f76aa33c445f6e33f137ab9f7240e23d2fdac53b991c56cbe
861	4	2025-04-03 06:58:00	t	f	\\xc30d0407030210694fa5ead16d4e7fd237017fed72c2f0df99c6e2732a43e2171ca1be67d7914252fb186c45a3d662d12e183d439eb4845d58e975ff72528ce7bd6a5a4ba62f9e6d
862	3	2025-04-03 06:59:00	t	f	\\xc30d04070302db22774d83a68dff7bd23601f01ea737e0615913eb29987dc49a2fc014c97db8d4b45fa291bb5c35b4529139b0e258da7cbca21befe56ada49c6e2e57c211c8694
863	4	2025-04-03 06:59:00	t	f	\\xc30d04070302eb2b0e39dadc382576d237016513feef0f8edeb2de80ab4da3bdb1c60412a95d0c1809ca7e5480eb40a4a8dc721a83d663a4c7c724c553bfdb484cbcb654b1dba30e
864	3	2025-04-03 07:00:00	t	f	\\xc30d040703020c05922c509da21f61d2360145ca2f434b94eb8ca484296907f9935deb56e72d6cb1681376555f2ee334c5488b4c3a56f12f6d0d3c5e1c14419f2821b1805df803
865	4	2025-04-03 07:00:00	t	f	\\xc30d0407030292c653466296a6ad66d2370105f83c5b396a3c36f75992b8c0626ed37830465eada880e22c5088384e32aa076b0edcdc096d1a81ca98abc8c4f96a2ed2d4a0671c96
866	3	2025-04-03 07:01:00	t	f	\\xc30d04070302402d65a86273b18f6cd23601eb2cf94b1a30480e85e205f9cab8654abdd73035a028dc51a1a52a1a66db89cbac018520fd0f87f95c2d503be7f091465e85a26c28
867	4	2025-04-03 07:01:00	t	f	\\xc30d04070302c13680a453b058fd6dd237015244eaa8ff58e4053935f5614f4c66cd6bb4a31c4009e1e0544696278e3260a11918279b27a3adc3416054140427f4dc97fddcd02764
868	3	2025-04-03 07:02:00	t	f	\\xc30d0407030238ef7e0cab0fdfbd6ad23601988eed419b118cdd460a49455fa140a2cd424fbd4868fe9494b94b1cbf2d6161218df8d6fe9cfff6d755d9b4dc92f87f8e7cdf3076
869	4	2025-04-03 07:02:00	t	f	\\xc30d0407030225dd8337e5c2b2e47bd237014777d30aedeafc4e749c1b14b74b66d6ee04ac4081b1ebcb75088b600409b72da7f06e9b1e2a726ed324cfd824e4f7e5bcf254f7fa47
870	3	2025-04-03 07:03:00	t	f	\\xc30d040703022914e0260e9bd8757fd2360186d674383ea4678752152125175e07f1188c26b24fc5ad67737727ce19a22f7a81bd205c65b46bd3f158d5680f43605355db6965b0
871	4	2025-04-03 07:03:00	t	f	\\xc30d04070302e9e237bd3383150570d23701a5a3d7c0202ec6360a0e0c3517c69082609f8b158f13c8a66229a653eac323b87f47bfe2be3a609eccfee666a0f9afad5f76bf25934d
872	3	2025-04-03 07:04:00	t	f	\\xc30d04070302fec49f639899408c66d236016e24f1571625ad83ecabfbd8ffcb694d8d6800e92893ed81ed797a2fa8eb901ce6e0f4ad80f03aafec1a5cb20c31a7a2d39a352437
873	4	2025-04-03 07:04:00	t	f	\\xc30d0407030291c81516caa2b76165d237016d31ed94440f8e6e722c4fa0286246e7626e2174cfcf79f6e88386c5291a604ec88d63778ae020dabdec2bb767bd28832c7411bedd8b
874	3	2025-04-03 07:05:00	t	f	\\xc30d040703021f61decc53463f5e7dd235010d295805067a7a04482635c0cbe2672e24f1c2f3e8afb6d07e2f01dbcf2ec21549d7846617c5797d582dbfcbe78fb2fc06b47d9c
875	4	2025-04-03 07:05:00	t	f	\\xc30d04070302d543e28a2e47497e6dd236019dc7cb27dfa739ae7f7f32a67fc2d521bc5cb49dbb6dc1c89afa6de7cad60144ba4aad0c8a10de6966c423f32f0cb9273586933abb
876	3	2025-04-03 07:06:00	t	f	\\xc30d04070302872152e3d841579b6fd23601e59da0f2fff6921e8d119281c5ae796acb178067aa59bdc90fc21f3e23644fe7f9ab3aa3cdc406d888f0e3834577ef934c48ab75ce
877	4	2025-04-03 07:06:00	t	f	\\xc30d040703022ffa1a8e66741a0d61d237019fcd763815ca4706cdbbc9854a07600c6ac7fd33cad9d0a602fe2d0cb8f4ecdbb683cdc4d7e2379781d5e2839ab86e2fd5d2d475988d
878	3	2025-04-03 07:07:00	t	f	\\xc30d040703022af51c216a9f1b156ed23601ecb6039e59e05d73afb0b3488e87ba1beedc47b75388a43cc9b2ed73e97cc06825b36b9711a0015e6fac45c85d77a2dba7f0a45093
879	4	2025-04-03 07:07:00	t	f	\\xc30d0407030288265ee9452a4cbe78d237013b7cfcb106a1ecccd09aa31cb1c8b2a97b0e7716c990db4490d732b88e9fd033cb7dcf64c44d861306b45d8e66e57fbad25e11b83ae5
880	3	2025-04-03 07:08:00	t	f	\\xc30d04070302f7df1655001a565360d23601895af04126553b893ce9017f211314bcf87a065a268d02b1208e16cf66c764d770c0ad094906af6d6a93bdd9c34ba6db375168a245
881	4	2025-04-03 07:08:00	t	f	\\xc30d0407030203fdd395967950dc76d236017dc6c161895319c917031125a8dc7553064a817464dc85a1365617c4c562d2c70c1a52cb0852593e70ddff19b0485d827aaf84205b
882	3	2025-04-03 07:09:00	t	f	\\xc30d040703021b2ed0815f1a4dbe67d23601f1b9225ec437b800f319d99a0d390d12f23ad56171b02b7e48d5b09b9bbb0af5c59dbe507c1eb009ec7d04e6a036d89807b8ef1144
883	4	2025-04-03 07:09:00	t	f	\\xc30d04070302aee936ac97c848e861d23701e68ba6e7af56934986d217e3342d76903a91e57b180d99ffc189bc1be4fd9f221e2252386ba937744b503dbe8852e954fbe47b35519e
884	3	2025-04-03 07:10:00	t	f	\\xc30d04070302a60753fe829137a060d23601dc94ef325c7b1eea94f4b26506d56b35a4b53e884e46a55b334614bbf4c4965e7fb3c997b20c566f2c41f05f7650860931c25bd7d6
885	4	2025-04-03 07:10:00	t	f	\\xc30d04070302a3967c0549411d696ed23701b727f24c98cf84e0379cdffbe59708aa9939a40e93995a1d90bcaf3401be890d841a55f70b3efbf90db211c3c1888dca2ac197fd1d2b
886	3	2025-04-03 07:11:00	t	f	\\xc30d040703020b624ce85eba117270d23601107b87b98b53465bd88efb5b9fabbe9b2a00549958d193df533e2dfc35a074f108cf8b799a4c75ec1ee7974316e0d937c201912444
887	4	2025-04-03 07:11:00	t	f	\\xc30d0407030219295d2089fbc2566bd236017359ac31635f333f3a134c2077ea4cb0cf21ccf656a73af8e3e3cecdaa9e37a421cc91ee85cf900fa704633f4dd5bdf526ba6d075f
888	3	2025-04-03 07:12:00	t	f	\\xc30d04070302baede0cc37506dfb6dd23601c21dbd05dfa1ce2d2b299f2a8ca111a08fe40c16e066f4686066264a824f4a7957dabf01d9d44e4a9eb02ae858937622b2df02b8cd
889	4	2025-04-03 07:12:00	t	f	\\xc30d04070302705fd9b34c51521f7bd236012713f20d35f217b9793fa242c12de9a1d446c832b7556a2251614cf48138d075a81834b73294cc85cc570e825a4f028abf2ddf5918
890	3	2025-04-03 07:13:00	t	f	\\xc30d0407030241c11e0ea75a819a69d2360106cdb8b724e6625aa7f0b48e4f8b197cf911984e4b2c27338a444b53efca20b8e317cdfc89306c2b16517c57f20bc008abccc2442e
891	4	2025-04-03 07:13:00	t	f	\\xc30d040703024882c45b4cd7d26361d23601caff3eb669a7957c70c737726838283a9e1e40be7f8a44938a324e7b75d8d57f96ad819832500de820541815273f7fa82b4b294fca
892	3	2025-04-03 07:14:00	t	f	\\xc30d040703021528c46a900c5bdc78d23601ef88f0540dba1a7e2236fa0e523e9bed61f2c75a4ac0e39c10e6955d632f2d2d43f1dfb432b02c7eb3dd35260ea11a402cd82530b6
893	4	2025-04-03 07:14:00	t	f	\\xc30d040703021a7106544c14cdda7ad23701b01461e8b2dff15200e486845293c44cf52c444aaa5f5e0094193984faccc4c7257f6b37c07b9e7af309b1b9936655712aa14c8631e1
894	3	2025-04-03 07:15:00	t	f	\\xc30d04070302c31461a8b67abed26cd2360199bfb7a4d0bca88ee79a6108e5e6f6c7e24e109ab073a02848822a63f99c729b251751b6db238579e3698dde9f05df7b5c6bd4cca6
895	4	2025-04-03 07:15:00	t	f	\\xc30d04070302383f41371eb642ad6fd23601ca494495cbb33d2a4582ee941326881f32f9d956e45566167e1ad144305efce5366ee1a21170a19603270f6ddd8ef514cc102369eb
896	3	2025-04-03 07:16:00	t	f	\\xc30d0407030247c7f045cc0523e97bd23501dc0d30099e35cabf3a46089ff90d00e448bb0103d9c687c5a200345ad761623f3bb7e86433a83ebd738f201318556614bf5af3e3
897	4	2025-04-03 07:16:00	t	f	\\xc30d04070302d51cc86deafb81f46dd23701bb976edf25073b15d0b9e84cf9045eb71be77a25776a8a777a890b9220cb16f8f7d0478a91674ae7a3b1f6c1ddc83d1d6cecf9174174
898	3	2025-04-03 07:17:00	t	f	\\xc30d04070302d643f6fe0fd073ff7bd2360199b7de4a3513d600d29439b883b119b9228336057742f08fd9faabb65d510a7b17c5ee809d7b9a3c7c66ef79b05fdc4a6e5d6a8549
899	4	2025-04-03 07:17:00	t	f	\\xc30d0407030239103c2ce899901e77d23601bed2bb2d932ba7e468610f8ae31dcbc9260013b86bbe94ac14c732f179a2f7915918fae5ddd8c417aa0cfb0a278271b22a70456bc2
900	3	2025-04-03 07:18:00	t	f	\\xc30d040703027b2b5d05ac96deee62d23601e352b7b76ecfb79ebe498a6ab139dacb8d60b29b98730b4037d2c1286238da037602d23926d3cd1018fcdd4d2ba802a3a80b34408b
901	4	2025-04-03 07:18:00	t	f	\\xc30d04070302a5fdf3360932a11078d236013a1a18dce4a98d043728dc26e224137fe19918e6211321f3a1fedc0c44ea634e878abcb8a835c5d620784a6c31ddeb8522888f2574
902	3	2025-04-03 07:19:00	t	f	\\xc30d04070302e06fda6990cf22537ad23601840d2909f252e04b35a23a95b55d7ce31030f89b4670567c4ec52a9cbde2a195dbeaa9114e2a79d0cd5a2c719dea1e8546057a97fc
903	4	2025-04-03 07:19:00	t	f	\\xc30d040703028d1eca762d127e1e73d23601bb44a19252dbf1d3a87d6f78e3109d26cbcf3ddaee61eebcc932ccf07df8973e8a125164c4f4980176341e3b097253882953a68529
904	3	2025-04-03 07:20:00	t	f	\\xc30d0407030296efe063a116a7657dd236015e6fa266975cd91680cc7a1ccf3dd4fb0390c64c0f27d5c6f7a4d42974afe26df72fc42608ea651d1d9c5b388da75e59cc2ef8f0b4
905	4	2025-04-03 07:20:00	t	f	\\xc30d040703028a3efb047dc630e463d237015db471b20bd1454026dc28449c4326222fcee87ffcfd05c5ffc231a994c0f066e6ed25ce62a273cf0d8b2d08cb0d3a7955e93ff2445e
906	3	2025-04-03 07:21:00	t	f	\\xc30d04070302f109c0888aa8d3ce70d236011b7a2f54624d678f6ae6293163ab88c9f9e56a5534c7d1e42e22d68c1f907fcdd7e3f525e16d21c7342795c502a4b0218b126b75fc
907	4	2025-04-03 07:21:00	t	f	\\xc30d040703029677fb39d9deb0fa67d2370129ad7264b2db1b2214266d6ee686c24468f85f602dbdcbe2ef72a9cfed3470a6bf6470977a0142609a3c6a4fc88d1e743d8c9116ff47
908	3	2025-04-03 07:22:00	t	f	\\xc30d040703027994342c790a1f8c6ad23601bea4c9ff05efc0b86393c2b26d57b589de92054d5f5c5c1a56d48bdd543e6ea5c646779c0e4a773504ea55513a7499197c20a0c175
909	4	2025-04-03 07:22:00	t	f	\\xc30d04070302b5db8d1402c82ed170d23601c6b3ef31534e6740a7890921e8840387c67cb74a41c0583f9bf118ec20718173a474d1481f8dc54aa0a9be4c51cb501c24dcd81da5
910	3	2025-04-03 07:23:00	t	f	\\xc30d04070302b22fbdbfb81c79e066d2360143b139b855ead448d89d3660b0df7125c480535bc25df845fe293b2ce11a1baa72e5bbbbad7180c28139f2e231daaeae50df3e3a2e
911	4	2025-04-03 07:23:00	t	f	\\xc30d04070302ac44e260fd3832a871d23701d8e79e9c2ec1b5cb26e94fd334a63b305d3aa636b9e4208c0a46471b72ba34d955dd4e85a222446e11ba9b53efd1db6df40fbe0f47e6
912	3	2025-04-03 07:24:00	t	f	\\xc30d040703025184da0d41d666a17fd2360135dca0097d7b6fc69a2d5d14f0eca56adf80b1e4d33662c1a6bfeed76a1be84930d89d5bd582cc8661d5fb7f439f24d25a535a13b1
913	4	2025-04-03 07:24:00	t	f	\\xc30d0407030235de19ca28c03f3d63d237017d4e9a79c52ce22a7ce9e4db3e7eec01afbbbbcba6a7f3ac4623b47675784c7b88edcb384b32c52cce7572e64dee0c1a368b0f2918fe
914	3	2025-04-03 07:25:00	t	f	\\xc30d04070302d0536630af53c2137cd23601e9fed47204858823b67637738eb7b87eddbf5e186d42d5642d4be79c1215c2333b5a7160221151a97063aeba1dc4db5ac1698d61a2
915	4	2025-04-03 07:25:00	t	f	\\xc30d04070302f3f5ca89db94ce8e7bd23601f5d04cca5699ccd30412bc31ada02cff780e5a31fad758ab4cce2dccb20277710cfd00d97ce0ee912f73338ef2527370a2b69b8209
916	3	2025-04-03 07:26:00	t	f	\\xc30d0407030276926fc2a5d4656c66d2360188e30a1b3a61ff9919c5ca94b48cb30c080cd99b545fecdec895987515fe496d6d42b6f396d5c22cf792db6ed1856f92c94fe71d3f
917	4	2025-04-03 07:26:00	t	f	\\xc30d040703021092cf6e4083572d74d236017cd28b77093d56315aed11cf3caf70fdc1f8227cb48e15ef9e404b432fc81450f32a32baa7632650d1687fe4c1ae3fbf000de54a13
918	3	2025-04-03 07:27:00	t	f	\\xc30d040703020c5baeeffed4081664d236017bacac2cc85fcde76162cf10a60d9c44125d1ac20190a149ac49e36530daec4acb58ec687fca5b68d89fdae0ea9371ba757f3c4213
919	4	2025-04-03 07:27:00	t	f	\\xc30d040703024ed709c00166b44d68d23701c81ab2446cd35747d36ca90fa79bc4ff0f73d5d246ed10d9bed268f49418a8e80c814e33499ef41bcd0ddd119a663123b81ab2e25437
920	3	2025-04-03 07:28:00	t	f	\\xc30d04070302c7fa33a0bfcd754b67d236014383e3dc5a599c159d5967f4a017e4b00034ec528ed14895ff5e63af44c31a3e4bbd0885d9f3f6fbc37114c4905fda8a5033d8775a
921	4	2025-04-03 07:28:00	t	f	\\xc30d04070302a08b33467d656de06ed23701d6ea60c5d42b37ebc1a0e9c6f70a90078094f0f1fb72529f8fabe18b08f57077b3039ae31016131e4af79010f73cf91044168ba58db1
922	3	2025-04-03 07:29:00	t	f	\\xc30d040703029090fd9065bcdf867cd2360143abaee96f6b2a1c1fe7542054b2954e977fd4a1ed821c29d026dc0e3b8ea276dcceac02d14fd01dea9b2d2fbec83bac58212e10db
923	4	2025-04-03 07:29:00	t	f	\\xc30d04070302a12ca6c6679c680e75d23701fbea786d90f633925a0774f348375100546155f371a7308f2b86d169b6704532e41d749c86c992b87cc1366601cd91465854ee317bfa
924	3	2025-04-03 07:30:00	t	f	\\xc30d0407030218a485a4ff43e7ca79d2360169eab4c6c71ec3bcd139e6b3cc256844d7c4ee2e64ecdccd555fa751609e1b38b9446d7f23d8fd6cad0e45053b12223a7f8185f51d
925	4	2025-04-03 07:30:00	t	f	\\xc30d0407030258a2efabe05cfed260d2370180363454e963427f6a3448ad562e6767a35ec964d8127afd382462a3c9742dd04a2184bb7b2ab43a4884f662ec4c3e9ae8f73f018286
926	3	2025-04-03 07:31:00	t	f	\\xc30d04070302bef233eba82b49d968d23601d4b76abac4ae654c1da8515a47572d6e87d681a6f3dc79c3f57b4bf52c3986114bf87a9054e6566f9a2c1379abd2d03aec57d114c4
927	4	2025-04-03 07:31:00	t	f	\\xc30d04070302f92ce89c9ed5d5ae62d236013ec837faac35c34e3e269d98e9840fbce108682c6fa9eaa9fb313704553a8ecbbce31856b7dc553ca85ee0352db28396a16f6fe893
928	3	2025-04-03 07:32:00	t	f	\\xc30d04070302030ec23d21bf17a871d2360132830be4e274c2a3fa3b7a1723c8fe9cb9d9dbcea678e644592cc0e2694995adacfb3b9f4d93e61d5d2e87a5cab436f4d3897bbf11
929	4	2025-04-03 07:32:00	t	f	\\xc30d04070302d49ca3cc8ce3062373d23701256d995e60676cc0748d6937d3c9f4ee12831f22917621f01a6a8b488caf7387dedb9f31422b7c4070b692975f8347aaf85cb0ecaeaf
930	3	2025-04-03 07:33:00	t	f	\\xc30d0407030292f377b6d91128ee68d236017424e5105015615c2df8bf526be5f17fadf618141ee2b14e5230fc31859fc562ea16be8add35529bb4bc068798d3889f4ffce40351
931	4	2025-04-03 07:33:00	t	f	\\xc30d040703026f261db68ad59a3f77d23601983aa440acef99caab8d7beac258ad7ff3bcaaa19f20464e7c5a7ca0cd38b87d0d606e203cdb79b050b629adff55964c255688a360
932	3	2025-04-03 07:34:00	t	f	\\xc30d04070302ebaa4533307adc646ad23601f8e0979cefbcb1dc1ccd55fb1ed8cf05c46fcc04de3d363e3cd15bc7f0e8a6871bd022fc533b9d673a9b5e806bb57707db1b82e406
933	4	2025-04-03 07:34:00	t	f	\\xc30d04070302ef8fa97297590af57bd23701f2980b10dff5d08a2f377c81cac7791cd5171ee6f0b1a3567de89572a17f5a492b6d663d3c5a10d6a031008351ec5746c95eaa11af31
934	3	2025-04-03 07:35:00	t	f	\\xc30d040703023cd0a5093fac646e6fd236010c2317af7a9ca758747149f3ed1bfc903eec2eb995235e11c85610712d6ff01c2c4db4d5a21ec06999439c74eab735c6ef0083301f
935	4	2025-04-03 07:35:00	t	f	\\xc30d04070302d31b17ea32729eca7fd236019d233598415426e29a7e1ba36e1517c1b16fd61e3528f02fd9123be7e4745dcc185218be314d50608b0e784edfdd7cd57ace2f2c19
936	3	2025-04-03 07:36:00	t	f	\\xc30d040703026a1f3423fbcda9087bd23601455a5ad210304c346ad0f0670fca19adf4d0647c4c509f637c6157c1f46b80d384522f061ba653840ac0674c21d529b069a92f4ad1
937	4	2025-04-03 07:36:00	t	f	\\xc30d04070302189c365c8d1e325c7fd237013bc00fc0e0373f2bc37a72cdab18be448b80fd741cf5de6fb4e87616ad70066a7393e6e53df3aa8275c6991d2a38676247164d532efc
938	3	2025-04-03 07:37:00	t	f	\\xc30d040703027f0d2c6f5acf5cce7cd2360168fc287736cb6bfece6ed4b9040b919034c5abdb2b6d4821e44054a775eed5025ca7541bae581d0b0f9e8505ae49a173e8352edb0e
939	4	2025-04-03 07:37:00	t	f	\\xc30d04070302bb13b74f42516dc67dd237011ce2d8694c1c19c253e08b7c6b3fa084404b35a693b66b59b3dcfc804ac79f384abea84d7c7b89df48f1a3bf757c924eb6621f835e1a
940	3	2025-04-03 07:38:00	t	f	\\xc30d04070302bb25aa9cd6d3051d65d236010f089e80233b2087d27228fea8f2444d9a3c47c1e2136b18502a3ed19854a540aad9f58b28a8da6a106cdc6b4e6e54e90b1d12ae1b
941	4	2025-04-03 07:38:00	t	f	\\xc30d04070302eb911e5328b833eb79d2370195969ea6664c7eeb062ef83da5085b29d97bd5c9c4ebf5198b46084bd972ef5382ab022bac8224a008c48b130e1da87a72687fae8b8f
942	3	2025-04-03 07:39:00	t	f	\\xc30d0407030237cf969772c9a11a69d23601a8a73d57149bcfa84b6400697a844598ba9cda06c155e3569bda8e2a7bdad9e8335d65a35eb9d1eaac110bbd7702e9f8914a57f917
943	4	2025-04-03 07:39:00	t	f	\\xc30d04070302cbdb5cde7a7df01079d2370171c309b0e09c6f95786f524d1bbe07eaa2c4a3c4c47c51c8b7a4f3db1a86181471c11628df717b0fe4d9558b5a1729e0e581499fd1ed
944	3	2025-04-03 07:40:00	t	f	\\xc30d04070302b661cbd1669a95e578d2360114dc46519a9b5bd3e381324532e87d7d7d2dec043c963ab53e8efb537981897a6c26d0735e4c3c74ada19a96862201660a79227a06
945	4	2025-04-03 07:40:00	t	f	\\xc30d040703024f8351be3fb6fa2275d23701336b010774f96908f88bb9db08e6d0b17b671a73f6d8ecc732e2988a3951c5161fe7f0925b4423bc25536e42f7f081a4059a03c4ca2e
946	3	2025-04-03 07:41:00	t	f	\\xc30d0407030228e43906ca5bafe17ed23601003f9aea45b9e7b6cbc36289fbe0c4f2515a7d7c39869c35e1a7d6b5945a20652c0c291662b92c5283d52fafc8605c7f8f0e8f5a7b
947	4	2025-04-03 07:41:00	t	f	\\xc30d04070302a2a66282c19ab11478d237011e4f187f55d021d8d6beff3980e2a935b4c1cac2d9b038584f97cdf269a3994d5f8e55641a34fa3cbf60c67d5027909efb64725463e7
948	3	2025-04-03 07:42:00	t	f	\\xc30d04070302369525a5faa93a4d7dd23601d119df2c9df3d65d73eb8ab18804c40120346304c81653558b473dcfcde325dc35024224284cd14fda061697221c40d8a82331d9af
949	4	2025-04-03 07:42:00	t	f	\\xc30d04070302153a420f7097ffb16dd23701a6ccde31f69250c30d884da1149d65c0c65df0f6b02e3b4df497c7c6e063a43d3abd7619f9e62871637dca81a14d1054ccd141088fd2
950	3	2025-04-03 07:43:00	t	f	\\xc30d040703023633696c915928ba66d236010f5892cfb1a94c68af3f222f9eab06a05eca66f869dee8860acf4671f2270b0103f36fcef84bdc65e94e70bcd445f23c1c9f526c8d
951	4	2025-04-03 07:43:00	t	f	\\xc30d040703020d66c327e72a54447ad2370192402789a7e2d2423e5660f06f215f48bee3d385bc21c490ea0a366b92ae6892a6486c178f903ef12ff1602e261621f84c9dbba642ee
952	3	2025-04-03 07:44:00	t	f	\\xc30d04070302d02bf86e19042b1e73d23501a50f44089939f912c0282654067bf1f79758a3ead95b9c96cef7ea98fc7c93e371796019f8a6bb9569a57f7a1920a3d073ac60aa
953	4	2025-04-03 07:44:00	t	f	\\xc30d040703026a42e5e35d7300be68d23601e688fed4364049df3c1f4ead2fad3606bb2b23e148b27c5a56e7c84187552bbd563bb7865d53e991bb95585e3e7130cf9f79842306
954	3	2025-04-03 07:45:00	t	f	\\xc30d0407030295f4e3bf86208c3c69d236015f33c38d9450720139759f94c70b8a34a8f3fbdf14495d69dbf7870726d227b1ec1b3ab4cfc24ef3bfb4aca9dfa022bb6b40669db9
955	4	2025-04-03 07:45:00	t	f	\\xc30d040703020b1e5ce613d421c56ad23601b21b77470db0adb120cbfba7999e87ae62d31a7d0e66b258e59ba7cd905163cf72c1ac09614cd5fb5968925f99afb5e6783d281f2a
956	3	2025-04-03 07:46:00	t	f	\\xc30d040703026dde5f26eac8374378d235018dfbd2966d8f71f24e1bf54328de418c55718ea19950f5b43af0d2fc45d8220b239f0914ab981901583e469e1e0d7d1bef19d968
957	4	2025-04-03 07:46:00	t	f	\\xc30d040703027b8ab26771e6add07fd23701b29c4e44d8608763bf0146bf1f7262ad3365049e94a1be59b512b0657ed6d8883109792f9a1bd909175fda776d088c6d7fc2a2f05303
958	3	2025-04-03 07:47:00	t	f	\\xc30d040703022520d8b3a21b97ad60d236019ce501ebc63abb1894f4a2cc49f601c639ff0d58b02400ffeb439dbd8bdc65ae8f6171bc218c596c07f5722c56c106668441f09bee
959	4	2025-04-03 07:47:00	t	f	\\xc30d04070302b311ef5dd98b304e68d23701c2581e7c82d674190cf6f79c5f5c7e01bbb20783e120e1278670e913e325b00ad339935230e916c81a583d833dd3627fe7fbcbf1f618
960	3	2025-04-03 07:48:00	t	f	\\xc30d0407030203e312fe9eedd80b6bd23601063ad202693eab29963af5ad3a1435d6bfb4712ea36347bf23f5f0671224b59b7540fd90b95d01afac75c7f331c91152c79029905b
961	4	2025-04-03 07:48:00	t	f	\\xc30d04070302e0bb5f7b00b97afd7cd2370115dea8a013601a5558da6d9e9592b91b2b7eb3b8d67e452dd70b8bed4770b12b39273a27ce59655c9c52d875bd8377fdaabc023eae20
962	3	2025-04-03 07:49:00	t	f	\\xc30d040703022b57d05692010f3e6bd236010eb53556ec27f6d30f8bcd629fca8cb4a4da23895227f05d8aa0f7c3f24d224ce459dd88adaae59245bfe465fe603bc00cf308ce75
963	4	2025-04-03 07:49:00	t	f	\\xc30d040703023e4b22a267b2da9f73d237014d22a4ce8785f200943e3629a0336f00aae569b320d4574002e8ea0b01d09f3ae85144eb0372cb0092ed16e9794634afb7da0a6bc066
964	3	2025-04-03 07:50:00	t	f	\\xc30d0407030200b99048cc4a7c2f72d2360178b83ad2ded85016da10b4cb1b8b7d807553316bea77953f91e5282cd3107f9bbbcb4ba20769ea25cf376e12d9e1465b9d89ca18f5
965	4	2025-04-03 07:50:00	t	f	\\xc30d04070302fe7a493a71895f2965d237016dc2b678911eace7379ef2aab95b600c5290e22f85314e6a0cc28642f138a90b1fd07c1bead955ef32594b23be9c78b4e2e00f8abb14
966	3	2025-04-03 07:51:00	t	f	\\xc30d04070302a1b197ee9851c5ce78d236010adf1f08a094b4f9815f52243d08a2ca622fa760c1de77e9eab1ad5debfc6de631ef306727404fd5483436d994cbf91e241dfb9611
967	4	2025-04-03 07:51:00	t	f	\\xc30d0407030210b35e0d6f94ef7c7bd23701d97a0a76f1a9e9b76982ced6ebe15701dc8bcd8095cc439eb4ad85423ddc2cdda2aa21dfda1fe5ffb4607c1ff31221a17712c321cd38
968	3	2025-04-03 07:52:00	t	f	\\xc30d04070302970dbfdc35dec4fd79d2350156e2a139435b7187e4a8872af1fa473b867db647bd211c0c031ea89cb5a1cd5a842ea776ece5f9218883084b380c1774696add0f
969	4	2025-04-03 07:52:00	t	f	\\xc30d040703021ed70e24257cbdce72d23701c6cc11c0ce87b1b6790f0fd7bed7d88fee5aa2e8afe4988329d85108af26701abb02d4b749434aa3ca8376e18801fb5499cb80177df4
970	3	2025-04-03 07:53:00	t	f	\\xc30d0407030275734d93842a85c57bd23501b928072d856c7eddec59ce948812fd3e87ca62cc4f12f77e656b8dedafc87bf57fdf97185096f1e0a166ebd8a5785fe8a40b34c0
971	4	2025-04-03 07:53:00	t	f	\\xc30d04070302a13a8311e313f83267d23701d4f37bf594f751ac5cf00863c9e7f8c0abd76a2c8f4bc7fb12ce3ec6d4c3a8c279dce017ca9dc15e5584ab30b21ff3b8093fee1287c2
972	3	2025-04-03 07:54:00	t	f	\\xc30d040703023e1e97dd508f75e174d23601a50e3b97bd8a6ad0bdd3b12a39dbe31c93dc26e0175e179454c99fec60d1c300c2087d267307e7ae6adf28fa16d319e28c983e18db
973	4	2025-04-03 07:54:00	t	f	\\xc30d04070302ee7e2055c3829c287bd23701ce17ef2d3452dd7a72838c132cd665bc9094c9025db4c985d6f7ef95310cd54ffae47b5d379edbbe62f6fd87b404f3dd88af3ec77c84
974	3	2025-04-03 07:55:00	t	f	\\xc30d0407030254ca0ac240e807c77bd2360171269e0604d9587b1cc5b5fa0d263b975b9c1c61b9ba755998988a3c3856d3a46ebf3061d35be0a7212c11fc5268fdd8d0ad020a3b
975	4	2025-04-03 07:55:00	t	f	\\xc30d04070302843694c91ade638376d237019dc4663fa5eb6a472e61a5e8f42f6c1eb39c2971c18b2638a2e569c572c5d80cb1509dd183c8771069ed5b47f8f041cd12d798d6ba47
976	3	2025-04-03 07:56:00	t	f	\\xc30d04070302955694310662e6f364d236017343902e5a71a42ba25ab114b0415938d01f792583905f5d81ca5c1a6f6a7c6a8b0fe4f3b22742a53111233956230f472aed5d9b69
977	4	2025-04-03 07:56:00	t	f	\\xc30d04070302ad61f2ea0d6531d26dd237013a066b747f42e558617c8d0324a16fd13c8910cd644207afa866fd4477a00c43bab95ff7193c575c73f91ad5ee87fdbb7c8bad7f9715
978	3	2025-04-03 07:57:00	t	f	\\xc30d0407030216bb77c6422c348b71d23601a933626923a7d467ee7bc593c7f0fab063c1d46e801fd6131452df071103beb3ea3c5e932f3f17337bca4c42a742b9833a08a6b2f5
979	4	2025-04-03 07:57:00	t	f	\\xc30d0407030245b318259df51d8072d23701f8a69d00b5405f331739752822281e49b2662264922f340d1e17193a938c38a3b71fc54ad78df697e42806dc16a4842499b9cb8d2713
980	3	2025-04-03 07:58:00	t	f	\\xc30d04070302cd5fc5d41884579863d236013144aa62c19911fe007e4f600479184cd58ab042e735c6d18fd5650d86a6647a8fb8b949672d0d5c358957b06870c48e730f805dff
981	4	2025-04-03 07:58:00	t	f	\\xc30d04070302ccbb05722ca6d3d97bd2370146c72aee7a2bcbd1bc9718567b89cbb7b938758609b4018d8afe6f5b95b22de21ebb6456e6dd52d0947adbc7c2494fe29ebb53077a0a
982	3	2025-04-03 07:59:00	t	f	\\xc30d04070302fdfddc6e150e7f5164d2360148000931a0a75599e6b2d1408105740835daa2e6ebd8062411b745c651087bb2309e53872c9e5782b21c05ed15861416e61fe34722
983	4	2025-04-03 07:59:00	t	f	\\xc30d04070302f9ce00904aa3f2a568d2370137601d6d72af48ca9baef71adc7ba376d3d6ab5dc54b174d67398d4d7b25807cea49d814218d57dce32d2126638207a52f2522822ef2
984	3	2025-04-03 08:00:00	t	f	\\xc30d04070302e7642f6f9136f4e376d2360138f037f24ffb2f52f682a09e7d8c6c63f7e192c2f87bfdb11645debb9386f37e9e1f3e20d5c27fbad89bb8f0d4f063153ac5e72bb3
985	4	2025-04-03 08:00:00	t	f	\\xc30d040703020ded4c343d3ec2ed7cd23701a41e074335939a4652e6852bf6e6a8cd5e549163f4ac362e22aa4f38de513169d65bd0731f5f1537861b98eb613097d09d2f00cd9b10
986	3	2025-04-03 08:01:00	t	f	\\xc30d04070302dd3fe63a131936e378d23601535fb8161692f7f2b6d20bd808d2d1f8beb51b01adc9bb999ccdc3217f30e875af7f9c2846391ef78851dd97a6b111588f0864801b
987	4	2025-04-03 08:01:00	t	f	\\xc30d040703023d64b7b10b8ed2f860d23601c93d36388976db34c3bc9076109a60f0a20725d5da83ea443feff43073f52b2308f8b07e399cddf03d1563d446214e00123c144e62
988	3	2025-04-03 08:02:00	t	f	\\xc30d040703029ab372d13d90dcf761d236011b98a0020da38ce14fc73e711638e3d1f3019dd4b116c5a48397a80c21ed92852a2dcb3c0c896e3eb675205454736ad45820a31222
989	4	2025-04-03 08:02:00	t	f	\\xc30d040703023e35ac3ef5a6d3177dd2350175d1388cd27a606c00442dd5a376e0445587fd2637dafb76b7069126f56c5492c565c8a24f409cbb9a4e9b16b9cb9e3965fed806
990	3	2025-04-03 08:03:00	t	f	\\xc30d04070302f9b2dff5c27ae9c274d23601dae0bd65a21ec6a2527ea8ea46cd64864a670f892926105b8c92f9bfcb62102851588423a69fe507d61caedc41aa0940a8e3ca6185
991	4	2025-04-03 08:03:00	t	f	\\xc30d0407030247fba90d6153ce7d66d2370123f8d9d816b9f114f89cb6697c6185f0c6db20a79ac7113b56106307fbc51780cebed4dd1adb4fc7510ff568967577af0a4c2b67840e
992	3	2025-04-03 08:04:00	t	f	\\xc30d040703026f667edf488ec95b7ad236011cc3243c44f15042b74470103deee875942f4bd7d179cfcb0aed2e38ae04e006b411d97ed24ad054433febd5456d2afeaccd462c06
993	4	2025-04-03 08:04:00	t	f	\\xc30d040703028b5149450399cee970d23601b6f84c195549f6a11c66cb499239845c3a7b781d7da4941b07fef659ffa154f65c725186b7b589dd4d4776142cf6f6a96fed7d8d33
994	3	2025-04-03 08:05:00	t	f	\\xc30d04070302a502dd0a390a83bb69d23501ef039599989dcaafc865fcec4e9ca0bea72f5a7f22bd87d628e85dd87c7e89ea28180ee4f6437b163e18ac1776a24440d5bc1f78
995	4	2025-04-03 08:05:00	t	f	\\xc30d040703028f6cd01d72ca46b268d237018897bab6f2cbd3ee793ca1521e98ae78b10f8a88915648a30b4b5c1fee10bb8aa35ac4a11e62dfdd970d5305eb4bed6a74e41d484178
996	3	2025-04-03 08:06:00	t	f	\\xc30d040703027374adbac831d7bd64d236011a78c7a4a8cde6d566822e059a7e877a17aff690d52c2753205d699660483022811b2f9744d31ea26509a05f2c389f61b13408b0ef
997	4	2025-04-03 08:06:00	t	f	\\xc30d040703028ec8b4e802dccf9269d23601a55c127bfb87681aa8cad07a456e37abc8be602157797a8b670102daecf110a294d03166a01c1708a0dd47cc0f2a03f33e61ca9de1
998	3	2025-04-03 08:07:00	t	f	\\xc30d0407030221a126fa2137ee8d6bd23601f5a8f1e6fa281080eeffcdc9ee60b1c7971677712dadb2f2a92115b341f59870edfd7898011b271dec82e9e1123b731f1716de9406
999	4	2025-04-03 08:07:00	t	f	\\xc30d04070302cca91bc966f7aa2762d23601ae6722b112e40cdff38444aef08b0649d7eb36e196f008609d9e454b92ddb33c3b78d06b14cb75c16c97ba8ebb235f86a5294997ca
1000	3	2025-04-03 08:08:00	t	f	\\xc30d04070302840e8e70585e657775d23601ecb92e2541e07ee87dfc75b9ae92f8506f1145e36ec222f7859e64fe89bb6b6a646c55b38d336ce4a5a02576d43799c0f20682d693
1001	4	2025-04-03 08:08:00	t	f	\\xc30d0407030236afa69117d8de0e6fd23701e5e14a5690d4923fa1771b4036a8ba787e17b48f79e7423b532c99e1b84ea25e6c66063497acf92c43a6ab48660a793b04dde011fa1b
1002	3	2025-04-03 08:09:00	t	f	\\xc30d04070302ca31d1568f9423c779d23601485f7374c65a972b5f1f8b3df3a484039c13da85865041bef35abac91ab7bf9bd7e842718706622b8387a23f3397b759f742d4a76c
1003	4	2025-04-03 08:09:00	t	f	\\xc30d04070302b04a3bef96f5d85665d23601adbd5b0ff8cf85c385bb4697f1547ee0d3d3145a6eb1e7720ce36f131c60ee0e066c9139f0954eee1f11ffe9346edb0d520a3f1324
1004	3	2025-04-03 08:10:00	t	f	\\xc30d04070302267fba50d8e37d667fd23601bf85fa97046f628b699e8490a0e2b859fc723c3415a64c59e644b484ce9c75f0a03e1b2d78a4e2fba123aefe98b77b3bc99efe1f5e
1005	4	2025-04-03 08:10:00	t	f	\\xc30d0407030297dff3b98a31bead6fd236018507d0fdebadf5bade7ed38814a0643cf499fec794c3e3d12be9995253ec177d3467bf414b04c4a7cc99236f4eba6574b2332e0261
1006	3	2025-04-03 08:11:00	t	f	\\xc30d040703026668cce509a28cb27bd23601fc26abc4db2f514b85c386bbcd3466ce23d99cc0904774bdfded01402a16133a83659655a88796e09ca67a703450711b0901a8a146
1007	4	2025-04-03 08:11:00	t	f	\\xc30d04070302551dc633b55ed42a65d23701568a2e662dc5bf30ef04b5063f07aec1d854904db061c991439c6c97621e7ee326567ee47ce718927815d614d034eba3030f4b175355
1008	3	2025-04-03 08:12:00	t	f	\\xc30d04070302f18200184c1ce5436ed23601c120d4e348d550e19fe43d323a755b69d7a3faba2a14ccbb677f8761d271ce797ae6101233a4514ee645185a3f8f5ed1792aee4379
1009	4	2025-04-03 08:12:00	t	f	\\xc30d04070302e3e64beb6ac0d3856fd237012bebc544d652c1b94aacfb82a8a827781f5b33ac737cfe6228f782422f284835d3c7ba9a5ce910fd81e7e96030519e7053ef7d31157a
1010	3	2025-04-03 08:13:00	t	f	\\xc30d0407030221533c0878240dd17bd2360123a06aabd9bb597284ef4f974d20ea9dba4fa106915243079b7df408f3558fcc3875b308950cb2bf31ac12844c9beb73775912a17b
1011	4	2025-04-03 08:13:00	t	f	\\xc30d0407030257a651ba1a94174e67d237010e1cb047cb47fe33eb98afad4fc7831b605453d75961603d6a8e91c0de7123b8122d6ae3e8e374417ce5f94334b1de590945e28a97ba
1012	3	2025-04-03 08:14:00	t	f	\\xc30d040703027d01d59bf998344a66d235012605523ce869616e59622ddb3f1dbca3567f9f7b0c11ea1d689e63f398dd61c5996777440c7c8ed2fa880edf7845939520b3f06b
1013	4	2025-04-03 08:14:00	t	f	\\xc30d040703020e7d63e796c2904573d237010d46373c96aac381a4452fe3348c1d043d1d6b688512c054a4060f978bc87468d9b2e2b17c6c84a32f47528b0670b8b550989f8b85b3
1014	3	2025-04-03 08:15:00	t	f	\\xc30d040703021da344384dfabf287ed23501153171ce9cf083258f3c9c190681caf27704955532fae7b4995a58ce845c65cb9e489df3f0646696d6c4788ee65c1e45108dc4d0
1015	4	2025-04-03 08:15:00	t	f	\\xc30d04070302b06093616a0c93e66fd2370138092b9da2bdc1fd2b0ac5d47f8eb15d62b61ca719be259d277be2dc0bbad6813d6c08933fe428fd3b4b1dd935efbd94c1e083b11d3c
1016	3	2025-04-03 08:16:00	t	f	\\xc30d04070302adbd7b29a521430460d23601f3566ddc696e3ffa7ecc1cad59133c25cee9d5ba80e4b347554b4d1a9678c08a02637c692980d44f90b2f2a88300ffdb47922d2f87
1017	4	2025-04-03 08:16:00	t	f	\\xc30d04070302e437f1919ef01e5b70d237014ac9505066945ea9feac605abd5918a8e979e33aab34cd045aa12d85371de106fea4144b11519b26ee0a1dae827768af05b919f757f8
1018	3	2025-04-03 08:17:00	t	f	\\xc30d040703027f565549e1fad15471d2350137a012f3aeace26685bf23b16118e5c93622e4abdf4621355b777e2cc5cc6d9894f13f2fd3599263587e65090a8c6385f8d5f0df
1019	4	2025-04-03 08:17:00	t	f	\\xc30d040703020ac57be4fa42249974d2370111f18a0071d180d0d7013a3fc0d4e158be62a9878feccfbc62d9cee00d04609079b546df97095525c65ab2fb8dbf76c13d198ac6c6d4
1020	3	2025-04-03 08:18:00	t	f	\\xc30d04070302e99ecff96efc019c7dd236016172c5b26fe86512ed3cf203da223850ee8b1dcbf1c5a13e1483e3b25ec55e5724da4c09dfe0269e26c0d8c86824251e45124090fa
1021	4	2025-04-03 08:18:00	t	f	\\xc30d04070302ae6eb4d879c0ac9c7dd23701cdae11f22631baa9880476b5af63ce74a4ad1e717fec2c1325bf9511f6bdf2d7313b64c93c69ae2f2432aeebc198d1accf9ca5c14342
1022	3	2025-04-03 08:19:00	t	f	\\xc30d04070302fda1db96733a18627ed23601c5c22343caaa97f9ee4eb5a2fe8ab1d165823aeb9a3857a6558a30bc540cf37fe380026ca8ba1f609c79be565d79e8b8dc2ad6e390
1023	4	2025-04-03 08:19:00	t	f	\\xc30d0407030277d2190cd950a38e73d23601f38b75c8402ef2284e371fc9e1d68bf19d770f251f0dbbf382624dc77a5db6492a95e3a5fcfee371526ce067a2f7b03bb77005eefd
1024	3	2025-04-03 08:20:00	t	f	\\xc30d0407030208bc9bf49dde0ee07bd236017bba8a7849fe79a95cbe1ace2e749ce954fabe37823bd2ca6f05c5dd23bbc4338826fb2debc3bb46db48a3c99c7014b5a9cfd1579f
1025	4	2025-04-03 08:20:00	t	f	\\xc30d040703027c9c32d0e0e25ebe68d237018579180e0acf655a697e08b8495ec9c9e0b37f36fdbc0db861435cbb82b77f57bc93015b6adb67eebf56426d4224c23dd8029016d120
1026	3	2025-04-03 08:21:00	t	f	\\xc30d040703029c0aa49140f4d08c64d236013b067f38fc060c46ca78376316744a283c1f1236ba391d28da02be229ee1aed46ae2591e38948bb8719e1ef21fe8d004f0ee0b3765
1027	4	2025-04-03 08:21:00	t	f	\\xc30d040703029c793b17a2e9225872d23701144e41230fabd7b73c2f0c446a9a2a5bdc31e0ae3fa0ded09d2891f16e0bce8c49fd02c33c16388be68e9978c2514918abd97059f125
1028	3	2025-04-03 08:22:00	t	f	\\xc30d04070302318bd2be4e0329fc7ad236016d0e3484ad46d137eb500bc23f50317a8aa54b635e4936c9a83722195ba586a7ee90cc6daf963c9d13bf8f36cc08772b93dbcf345b
1029	4	2025-04-03 08:22:00	t	f	\\xc30d04070302e7b0714b47bf7b647ad23601464322772159310a6da048cd69a949e07682bea0f329a991fa099afbdd108bcf561df6d6d057a0f96411e753611ae8b6e11fc34641
1030	3	2025-04-03 08:23:00	t	f	\\xc30d0407030282d8a312ce3806ce74d235019006324ee8a046556f501568afa51a6b19d7c08c0fdcfcf28ce9c280ac88e29611374743b5381dc92e433a11d0355be70b8cf9da
1031	4	2025-04-03 08:23:00	t	f	\\xc30d040703024c6ff9716a8c179f77d2370122b4aad760bd6ca113554515ad5f0fbc7fcdc1b06d8b4a1093f5187db8c6ce3e2470ba897d5b67d1805e731b2f7661eec9cb55458f3f
1032	3	2025-04-03 08:24:00	t	f	\\xc30d040703025b05390a63a425af62d2360131e8fa6751bd650ee9f752f879ec75760aace4044b0be6be461352c0fff1735c993ab40cd4c4d9dddb164ace434356a94cc5c5d358
1033	4	2025-04-03 08:24:00	t	f	\\xc30d04070302d7bf635044fb0c4d74d23701ab703f87e87c688903171ffeb0f33035307c2a42823f1b6bffd0d692b7ec2d4c884a05f0d64838d42013a190a7c478a0c9403859fe65
1034	3	2025-04-03 08:25:00	t	f	\\xc30d04070302cf159d5f693e16a57cd23601320c00f1e64dfbef8296ea90d1f44474cb6c85ef96cb4ee47b728f8446396e8ef9e478243ef64228cf64fd5bf749a097104b791043
1035	4	2025-04-03 08:25:00	t	f	\\xc30d040703024fa94c203da7ff036cd237010b54ef23a144672b64d5adc1d3b6f66fe820b26312762e9fd565c109ed4690e1348d05478d7acf720990f2284c35206e0946d9ff0897
1036	3	2025-04-03 08:26:00	t	f	\\xc30d04070302eef7ed6f900506c167d23501b8d0ffcb1324c79bce0994b8b1e1e1e3f9f8f1f989e94c6af3d7132c4cc500314aa2ea0c470cee016400f0c10feb74583990df3e
1037	4	2025-04-03 08:26:00	t	f	\\xc30d04070302aae0d425546fb3f771d23701fb838ca6277c31c6b8c218438ce38192c0da7a3aae9f17d85a558d5bb26b11046961ae01f158495c06a5c505e9e1ecfd27ad78ed17f0
1038	3	2025-04-03 08:27:00	t	f	\\xc30d0407030219ebcf1397846e5971d2360133d9c1088f75bc895d86f7cd5ade13a0120cf78ce83d92433c03cb39a6d75b2ad23aab300e5d9555dd867e58f0b3776ff6bd57fe08
1039	4	2025-04-03 08:27:00	t	f	\\xc30d0407030281aa6978835632856bd23601dd3cea38bbe2ac54b2fb5516c926924d3eed84190775b0b1697ecb00b5094431dfc19895270a6918c9f8d011b195ede534a83903ee
1040	3	2025-04-03 08:28:00	t	f	\\xc30d04070302771fe408c854797f7ed2360101c31ad79da246cee3c707ddd6267bd1933763c70036b758b45cfed2fe739ca946d5e3bb4c9bea94811a62ce60f1228acbbad10950
1041	4	2025-04-03 08:28:00	t	f	\\xc30d0407030200cac20022b8990e7cd23601c51be9ac8660b51d3a493751a4a1434fedca39361fca6ef0305f77a16ea210a4f628d21653f53cd2933808eded5d949bf78013f577
1042	3	2025-04-03 08:29:00	t	f	\\xc30d0407030235647fbb9342d4626ed236016696deb27d62e9112781b6d16fdcc3de578f265e8bb32434b95fa01d7584ff44cf120708df7b229fe5c20b3b5d110061a5ba3beb6f
1043	4	2025-04-03 08:29:00	t	f	\\xc30d04070302e67420e1c897c52166d23601bfa81fce670bd6c58ae0445199a6a1b415e9602799668a66d4f24f8e09b428cb700690330723c2fd3175021ffa29f1c75f77aea77b
1044	3	2025-04-03 08:30:00	t	f	\\xc30d04070302db3d6c34b12a822f77d236013498076e173bd01fb43de2045f8432c8d37243df8c64639a9428d3e16f48def4595587dd4f0c33a56dfb40e51ea3ed5c03f5ae0b8e
1045	4	2025-04-03 08:30:00	t	f	\\xc30d04070302908682357de817ee7bd237011d6b6dee5aab03bce350ac06f3e0971abcfc680129fb08c41f51f0d3f162f3a0f91d3d44ba173a66b13db2c6acd6e97865540075a2e3
1046	3	2025-04-03 08:31:00	t	f	\\xc30d040703029ca40efcc43f75f070d23601a69a5920571a8174d4e4f52e1689d6f3c8c9a8d4c832bf6a8684a8e62ce904ac797d9a038447633ca37085a24149cb98dbb469d9d2
1047	4	2025-04-03 08:31:00	t	f	\\xc30d04070302322aae005487e3fe7cd23601e0ea746f947ce9f96ebd321d87f240f016cd500aaf3bd9e7280c97d6728422a41a3ab8fe252b6f72d70807bfa6590d4e00ecbc22a6
1048	3	2025-04-03 08:32:00	t	f	\\xc30d04070302e6751e185947d88d76d236013d6b2b2f9b42d518500385edc4bfaada4c39b3b2d743bf6122cc81e9d922538d0c944ad9fe4fa1ce63f8dd13daeae05c2680340bfa
1049	4	2025-04-03 08:32:00	t	f	\\xc30d04070302e806c5299e936ccd6ad2370146e54884b36f74ef18659fe7aa52aaa36ac525836efcf879d85c7f66786ea228c5887ef8379ec67f08ebda8529302f6f80508167aa5b
1050	3	2025-04-03 08:33:00	t	f	\\xc30d04070302d361611985ea27ee62d23601a16fe22c4b6766235dce0a392001eb41a8677ddd5c0fc17d45be4e6fa75184bf7021c108e465ee65af244692366bddf1cdbb031990
1051	4	2025-04-03 08:33:00	t	f	\\xc30d0407030229f7350f6e79016569d23601ab1a908f3779c43a8f32b6ec3bd26e93358b646bab7114ab970b1466143d013edde5681405cb6772a148b908315c2b5bf404fdebed
1052	3	2025-04-03 08:34:00	t	f	\\xc30d040703028bf09299f855274579d23501e3c3ecdf77825644c59e99d96080904ee4f351d0b2d85c0c12a6938d18228a0f80301e6402117329074f99eff0c50dae22b9b7da
1053	4	2025-04-03 08:34:00	t	f	\\xc30d0407030214497d7b4c5351457bd236012571e1c8f4493eab39e4947b74971140405a7dd81f0b7e58636085aa3d90c6b0d2db4f97ccc01e3004834dfeaded869c30339ff4ea
1054	3	2025-04-03 08:35:00	t	f	\\xc30d04070302d985d703a47df40978d23601b3e68794addccb5ff1496f13fd89338e6882c4cfaa0368b4d9934604a98feac8491707ea3fb68dde529d42a396ef17516bc5688455
1055	4	2025-04-03 08:35:00	t	f	\\xc30d04070302cbf37175d2eccfcc74d23701a4a068a12b05c73c1d6c1b644b45fc85b3b83abec56dbad4c2929b1dd3537e7670966317da724792d6af929f1d6cfab4b5b71d06ba57
1056	3	2025-04-03 08:36:00	t	f	\\xc30d040703023ae78fb5fa37474b67d23501fbb21eece8ee8b67c02d2fa48a4a87933eb32d26e963452f3b7922a45cafbe640a0bdf777b6162bdbf2c440fc8b01f745f8c3b8a
1057	4	2025-04-03 08:36:00	t	f	\\xc30d040703025f7b4fb4186dd2616cd2370182c58b53cf630a7ac1cca0dd5b64a25ff87654ba17bc805db9a87492e3647d737d10f3ed2d7e87a95195c30e75c8e895659dd522ec72
1058	3	2025-04-03 08:37:00	t	f	\\xc30d04070302a60980f7c0aaf2da7ed236013867a7a17bacd76209fa3c6e518bd382e1a4667762f3c8a7cbd24517a32533350825e4a7aafb4be763190f25a7927494d72510b92d
1059	4	2025-04-03 08:37:00	t	f	\\xc30d04070302ef4817e94b797f946ed23601f58ac9a67a13271af67b3946ad424353ff45dbabf6854b9005173e10c6f196c033b67acdeadbc0472fcdb9c3b29979eb4dcc719f13
1060	3	2025-04-03 08:38:00	t	f	\\xc30d040703025432626eb9f2e19a78d23601ead17295a0f8b35cc31b6f666ee96c96c39548e06b7f8c07114d4ba9c2ac015b7ec606f5188ca1b4d69c819997a146820843e7fe77
1061	4	2025-04-03 08:38:00	t	f	\\xc30d0407030281b3967cc5d0b81a77d23601fb36ae3f4874ae4f6cbf88c52bb693996eb1c418222861b899099c61b979172657c2f1fbcde9fdde262684f2d773dd5edbab1aef43
1062	3	2025-04-03 08:39:00	t	f	\\xc30d0407030222690aa073cc037e72d23501218cc7cd624f884b386cee5ffb3db0ee4b851b5cedf0c5d20a4c6350ae08991117336bdb6f907b98875d79a9d67b7ff237f1f60c
1063	4	2025-04-03 08:39:00	t	f	\\xc30d0407030242e23f1f0f066e6768d237018cb458d3439b7e633f8c3cdfb58c01facf73cec4ba041f2c0f682f738bfcb89dc3650086ca5d928eb6ea10dbde192946f4c1d0a3291d
1064	3	2025-04-03 08:40:00	t	f	\\xc30d0407030210f1d00b72c7d3bd6bd2360149c5c2dc6d1d01da084de935b2f7fad8e32375fd35419713f95fb7ce18db8db20d11552ba2f9bdc2e107d0dd7001d2b4778754bbf2
1065	4	2025-04-03 08:40:00	t	f	\\xc30d04070302b1158dbc1b9998ca7fd23701e9a4972f6057c2735ebf9e4eddb84d38b99383d049bfddf89a850d961c8ebff9fa92af98fc76948cda359bc552f5b808835509017ddf
1066	3	2025-04-03 08:41:00	t	f	\\xc30d04070302995ac20238169b6e65d23601542c153e9e9be509798139ba7022cc157860ab658455e423f40b80b0ae147a0cb028a9e844800efb7ebe526d6d6ee65e25ac146d64
1067	4	2025-04-03 08:41:00	t	f	\\xc30d040703029d8525534bf4881468d2370162a81b7b69f57fead6c383d34bcf168ca64af98286ac93c62e66abac3639a1de461fee1ad6786307a83fdb1d22bf62c5bfc16eb09484
1068	3	2025-04-03 08:42:00	t	f	\\xc30d04070302e296b90a4587c5d47fd2360197e69b7ceec3b8898e9c10836d963d829078fc29e67e0e82bac1c2aa4640c2250f2bc9dff9b288fc3e685b05031123a86fbe3fd2d7
1069	4	2025-04-03 08:42:00	t	f	\\xc30d04070302dacfdbb4b7439c4c60d2360100bdf21f76aa0357b2809aaf8bd8461a54c68da705fddde3679b469512ddc00b33a5c7bd1cdce3af903e8508bc356aa4eb3c1e9b75
1070	3	2025-04-03 08:43:00	t	f	\\xc30d0407030284ed8e388525601b7cd23601b88694f88a267e92c3b938a13fe738b7a904b5fd01abfd3156cdf9b3b5ee45d3cb0b4b5de45ca33c25f0c2dcb2eb8c50927bb0df6b
1071	4	2025-04-03 08:43:00	t	f	\\xc30d04070302511b2609ee73a7bc7dd237010b80d2f91d4c70917c1310b4fa26e67e4fcc3c363c33b79712330d7857b0a07f96624d3ea53d64bba1a6d6f750883cf1cb72a39d33c8
1072	3	2025-04-03 08:44:00	t	f	\\xc30d040703026bf46c77ff2b596078d235015956f9a0678d628168ce65898edff31bc875dd9fa0d5ebe82fdfce76016c54a8d46e33c9d6b8f7fe68b17de507f3d43aab76eeb9
1073	4	2025-04-03 08:44:00	t	f	\\xc30d04070302d4a927584b3b32116ad23701042e08b52cb4bf65c17408627a1409f7366b8f3fb45e03224fffff58224f972695284c82409eb08d5312c1d6c0a4ce629e00af0852ac
1074	3	2025-04-03 08:45:00	t	f	\\xc30d04070302b436ba2bd62f5b546ad23601cee94180be078052e4de6b26cfcc770b24b968659234ec51d925a81e19d685b12d5be061e61e70e2c620029e8677dcfb1b59dadd7f
1075	4	2025-04-03 08:45:00	t	f	\\xc30d04070302362a47b23fbb38ec75d237011abfdd8f5c7280ff06d27bce3523b21d3a4ab75e1ad51927671172e559b74cdedc10d2568b81806e67c8e5af0149987f49eeaf2b769c
1076	3	2025-04-03 08:46:00	t	f	\\xc30d04070302f536b09e8f41e54e75d23601b1480278d977f3eac9c059a61d86d813b9c339f4224a18e399c1135d5a72060346701fb6c55279bd27b384ecd09682e996ad0a3505
1077	4	2025-04-03 08:46:00	t	f	\\xc30d04070302656d191d358bd41b67d23701456bc7046e311fa5edc03ff1e297e3a25ed11c18fe8e207bda1c07aa433b7a0b0a5636fb577a5143b5c7350c02ae411cc987809fc2a1
1078	3	2025-04-03 08:47:00	t	f	\\xc30d04070302046208d1841ed9ab6fd23501ca9edbc5bc9b9596bf4e18ccbe6d4d53fda4712532b2977e671bfc399a9fd25c1ac48151ff8c0b7231eef26029fd907f7a98e512
1079	4	2025-04-03 08:47:00	t	f	\\xc30d04070302309e84f1c4c5116068d2370187d3e88fb8e2ddc4fe052b0684bf9c133c00c97402fd3bbf1ac310bfa4b32207b975009a49bb186257f74d2cd41c1b3f080cc11149a9
1080	3	2025-04-03 08:48:00	t	f	\\xc30d0407030219e1ff8380c3fea465d23601adaed4683a9f63fa08b6d9d587961f6ade5d98ab4a65cb56864c6e1abc7ec38eb76d47edd359cc0676a0518856dc2644ade904b565
1081	4	2025-04-03 08:48:00	t	f	\\xc30d04070302e9be1ac31d64748e60d23701c92b47347f68abb4b91efa45b6f6127a4c998b6a63f791fae8f286941e4f3f869d8fb622256da1d28f43a711c6f7215ff0e1b208904f
1082	3	2025-04-03 08:49:00	t	f	\\xc30d04070302c2ed418e8bc82e8b6dd2360133855b53adf2acc3adb78e0788056bd9a94f99570a1b39b9f5b994146caa130c870ef341d09e727b8b29ea929df09533dae32aeaa4
1083	4	2025-04-03 08:49:00	t	f	\\xc30d04070302692701022fa54f0879d23701b1df534cfde09945ce9fba83cbc7a32864271a4d380c262c7418558bb3ca8eb4ee2ecb04b8f58b2dcb7061875011c5dcda5bc621fd0a
1084	3	2025-04-03 08:50:00	t	f	\\xc30d04070302e1644e77bbc2ae1268d235014470e1cad27c4ebbc9cc85fd7664b44fe2956e4968edc62e71d9ca38573c2609b1c2959157704b4ab5aacc4612cf15274f158b57
1085	4	2025-04-03 08:50:00	t	f	\\xc30d0407030224264f15cb8caa806dd236015c16222ed3ede1c6d94cf55982091e0aa1506cc04975f9d0ae03ff97c416b254b7d14f08f6e5fcd15fc9a1bb094e633696285db866
1086	3	2025-04-03 08:51:00	t	f	\\xc30d040703026257a0d31f9c740275d23601007423471166e0f00ba44f5111e01723b812c5f618e14519b22e9868d542468478d71c040062ff7232392498ec265f6a5ade9e8ee3
1087	4	2025-04-03 08:51:00	t	f	\\xc30d0407030266d4091034cd90b973d236012cabae37866cfff1842d745293d8f6c7557cae076b29cc55c7841cc890ae829883ce0473646ef6c1ede115f48abae660e348ae54b0
1088	3	2025-04-03 08:52:00	t	f	\\xc30d040703029057ce992990cafe6ad23601dfb21ff91f51856b30507bd7b014463e26cc1b0374d7940d68ea475e093d166140938a15d30ba49e3487630e0115b07b864559e63b
1089	4	2025-04-03 08:52:00	t	f	\\xc30d0407030222bd024e515d135862d23701c3a7db42ef3f2a5ebb5a685bd1b0a28b83e2286aca39c9a96756b108f536183b23ccba2dc6407591e509d12760c7b553f095b494ab4d
1090	3	2025-04-03 08:53:00	t	f	\\xc30d04070302e836c81ed03c6b7e7fd2360164a64e6c4c98b698ffdf6d262f5fbf7e7d58cd972c6dbb6c9803abe6a15c445c1f39a949fd89358805f4bde6dc0ab9bf76aeaff286
1091	4	2025-04-03 08:53:00	t	f	\\xc30d0407030287d07660104ebc1176d2370177ee0878ae4dd230d72c372ef6453f5a27c61682d5cdd1fb10ea9fb4cd3a5695b15f82db2bf56b9244bda9f4ce5b5e204306ca28745e
1092	3	2025-04-03 08:54:00	t	f	\\xc30d0407030266cd8317ed0b1f0f66d23601b5ca8d28cf743690f69c46e857f3bd6dffd9dc7c8af44ed454cd672a009881ab2f23c0da825edb5651f538152e10c220e09cc8beb7
1093	4	2025-04-03 08:54:00	t	f	\\xc30d0407030206facfb63e1cf22676d237013950d68c790ae98a32d88a356d64017af15be398a3bef154d247c807657d00ca6111cb566e35e90d9eaca03adcde40edf64bcbc81086
1094	3	2025-04-03 08:55:00	t	f	\\xc30d04070302c51df602de056eef64d236010bfebdcf099fb7b7fe75dddf15f28eed2fdefa995adcdd68096c994dfad932e0caaaeb83399673e761a185c16622ed4dee4622a114
1095	4	2025-04-03 08:55:00	t	f	\\xc30d04070302f795328674016e1762d237013848c273c3b56b8b2a3de6ac9175b6abcc090fafa1dba99efd03d2b31cbedd86de6468be9af244649d64610c41ffd7b8063e17a2dae5
1096	3	2025-04-03 08:56:00	t	f	\\xc30d0407030221df712860d373716bd23501cb2213bb20233c147bdb60742c2405b8ae754f6ca5a67a25366853545aa2b44a25ef8fbfad3e3bf5fd0fc8f0f33470152740a420
1097	4	2025-04-03 08:56:00	t	f	\\xc30d04070302ec7530f8f52d90746bd23701775ede3dd70d98bb50fc10322e132546e23e572b2bea4879a65c4307337e294d378d3f2735e2a83ba7d5d4096624ba0deabe7bed7fbf
1098	3	2025-04-03 08:57:00	t	f	\\xc30d04070302177ea2d9d4638c5563d236012f5b29dbf46f111ddad56a94db35473f3b6ebf628ec76cbeb908c402767ea024a46864a8844844892a7fa1d4c65540b011253089f4
1099	4	2025-04-03 08:57:00	t	f	\\xc30d04070302d0f154b41693c66472d2370133078dff2615e25cdbdaf2a4776c8f0efcab4d37ebcfc3c5432d5938ba2ef1ac8419987b4852247dfd72a5642abe1254420c74675863
1100	3	2025-04-03 08:58:00	t	f	\\xc30d0407030273a91ea1af6f97a479d23601a0ea6f7f92529dcaf5b3f510724591804428e77466193d7b6e2d890151580b26dd1db5410cce6b94a38d3effd034729200d55928b7
1101	4	2025-04-03 08:58:00	t	f	\\xc30d040703029be464508f77bd2b7fd23701805624c7750875fce7835dba38553703fda5ca301fbdd2ff16d9a4ecb3f45397fb082f730e80ecbf9c9d27f4f1a0e9135be82b225916
1102	3	2025-04-03 08:59:00	t	f	\\xc30d04070302a53debbaaad7ab3f7dd2360106642533c6103624b474b7c7f9b950da33c98877d88d419f133f2f25b13af16f7e89c9169400bb67a612eb07b3f9bbf3b6a25f2262
1103	4	2025-04-03 08:59:00	t	f	\\xc30d04070302427419f56deb50f07dd23701dbb9a7562e75ab42df7813295ca31e308be171d226e374a77f8c912f30845f686673308b078dfe722ebb06fb80d2e78a07e6c56339d1
1104	3	2025-04-03 09:00:00	t	f	\\xc30d04070302c0a1e5eff473253678d23601b4fa2aeef928d722803d2a720ee288d46c3899879b635c3a73174c5e82ec5d8bacd5b5ea6be06d2139f04d854fc2c4d5931b45e303
1105	4	2025-04-03 09:00:00	t	f	\\xc30d04070302009dfdd94f44922371d23701dc4a9b0e85fb7eed16b7d6831354a1d8a89dffd5e2b585ed412af7624d37de807267b030c12000a8173bf4cbb3fb2a4baf32eb76b17b
1106	3	2025-04-03 09:01:00	t	f	\\xc30d04070302c0fb49ce58a3a31661d23601cdb4b43e97e09dd41f0ca4c09a17f6f6a65f630aaff62a1df3ee7561b9f16f287cf6e69873f48f2b75e2c35e97bdbf69f6bdc379a4
1107	4	2025-04-03 09:01:00	t	f	\\xc30d040703021a3cb78eaa017f347dd23701d06db1686c7c437c843027db524d7e68a16fb2d495bff68d6ecc5ad5dca383ff01f0d5007b5d2a37a788bc5cf911a7fd5cf38a3bd701
1108	3	2025-04-03 09:02:00	t	f	\\xc30d0407030265fad48a81b683d564d23501e23cdcf33682a8411ffd00722d45e37bbf043be419c8f419321b56931881f836d296b8fbd70fa4743e2d22249b8170150e4dedda
1109	4	2025-04-03 09:02:00	t	f	\\xc30d040703023122bee8acfddff56bd2370144b4c6a7576af0fc932d13c3b16bb9becec92f4bea81c08b461c70fe246a4e7e5abcf191f5cfeb146cb5dda411a2b0424c21670a2b12
1110	3	2025-04-03 09:03:00	t	f	\\xc30d04070302ac84b5cfcb4ae0406fd23601dcd350dfedd059cce96de6890a831513ec05862f32bf7f46c74f561ea37915bc24a8cab58faf92f910abec820fedbb2a4f538049ff
1111	4	2025-04-03 09:03:00	t	f	\\xc30d04070302dd58588d0e6965dd71d237019af0ed43503254b54f0d6d67437da88d389583ebb439f01c11ee6a58e6d068223cb8e8065186ed3b5d743fdbe2f6bc369fc0b9dd5b44
1112	3	2025-04-03 09:04:00	t	f	\\xc30d04070302148c00013fd35b0977d23501042e5b592c8585afe342085a7a2ed9587078e26267b466e2cf4388e523a1370f39f42d08aa012d07eba0437c6b8d6e95873e1c06
1113	4	2025-04-03 09:04:00	t	f	\\xc30d04070302bc3e8fa73b0b11d37fd2370157d9db4f917e2958f4cb867bb97d481d70cedb58284ead870e4f7d200e207a82707f8dd96e98dfd1d6ff0a8d27f6e1006ebfa5afe25c
1114	3	2025-04-03 09:05:00	t	f	\\xc30d040703020071eb69d8da91ea70d23501827e0bfe72d101dbbffa24eaae63050f2b6a92a7704710eff34ad2e9bcda9920be682f100ba0fcecb2c2ee6a64f20bddbee76105
1115	4	2025-04-03 09:05:00	t	f	\\xc30d04070302c907b0e606b4d47674d23701f6253eaf48e6be1dffcc0ec55e6b4ebb89a5cbc3c3d56cb55f4d4dfbf93295b5c471d94a799bac674b2549ef17a60560cadbd5519993
1116	3	2025-04-03 09:06:00	t	f	\\xc30d04070302f6133c33be72e96f60d235010cde4f865671038272d5af22c9ae30af17692b58b0672cbc84a6e91eeeb35f49e74585dd2b233344ec8c642f32e0ca3a630e5916
1117	4	2025-04-03 09:06:00	t	f	\\xc30d04070302a8b710083cf7cc227bd236018c081a38bc9dc62a427001d8e0f6ff88937891ef6f4ef685b520b01cdc79b1ef1df9c48cd648c2a1d5e592e3d3ab137971ad924f73
1118	3	2025-04-03 09:07:00	t	f	\\xc30d04070302ca73cf89e163495b65d23601db3e17a5ecfd2cc0872d13cdedbcee7c00a8238cd519034e7d4e8d91c5422e2eed71b05a8bbf7bfdc8c769dd3281ed47f45ad9bcc9
1119	4	2025-04-03 09:07:00	t	f	\\xc30d04070302787ab624635e42f767d23701d67af6615936e9c00e1407a53804c46393873f5200ce548409970ebb10df42e7762c4173218a131b57a90bbba29f7c3ddb9d88581813
1120	3	2025-04-03 09:08:00	t	f	\\xc30d0407030235a4ae84f9ae7d6d6ed23601743585823e1989f7da9667ec2808fe56d27185b43b8e293d50cf21a7552778f53e2e97012f27bac17e4fad5a70e217b61740a17b24
1121	4	2025-04-03 09:08:00	t	f	\\xc30d04070302b4dae2a206ab572164d23701edd1f0b274bc84e79f14b2cc66990e4c15cb0eac5d4df0e10975dedafa1ab6822d2fa929faa726eec86ea8aa4e0108c5438a2db4a894
1122	3	2025-04-03 09:09:00	t	f	\\xc30d04070302f8272ad48f1edb8a7bd23601c758ccecc28feb6087431b04b09710bb08c64429572bf57faff3ebc08132f01fa0c8b33e9a1ee1b3b4196ed045683b671734ded6b2
1123	4	2025-04-03 09:09:00	t	f	\\xc30d040703020555b2e6336b38446fd23701ad3893ab90c9b6a382e89dcc61739b727d5d7a33911d72de6d8986bdcb3cd7226434bf37f247964b872ded9964b4550df8205956ac01
1124	3	2025-04-03 09:10:00	t	f	\\xc30d040703020443e9b671ac6ad96ed2350196c126491e654480bc24154311a4d00ce4d168f9eb0fb2e5f711b3f62ba2ce1d82fc15ef1028be55b99a5490b95a9f62850f80b1
1125	4	2025-04-03 09:10:00	t	f	\\xc30d04070302bdc57fcaa149baa773d237016a7b94dd27674fabb290c773d0ec5c76c68b86b69aa12329a72fa06849af0fc1fd43090c56864251e6b0c1b2fc117e5c700a4890e5fa
1126	3	2025-04-03 09:11:00	t	f	\\xc30d04070302a69e758a15c9e8887dd2360122856fa51f8c56c1be53263f80c36fa0985ceb15d5a68304d2183c96fcd223b08600775565fdbf7e95a1ce2a77a96290e00283b858
1127	4	2025-04-03 09:11:00	t	f	\\xc30d040703029f242b598a5a48037cd2370198a08e690da20667283c2ed2a27e27896334806d5ddeefe0b98a56ed7166106fd235a17ed6976ada9b696078c875144ded7f8c0e11de
1128	3	2025-04-03 09:12:00	t	f	\\xc30d040703028b491ef6e2b253de7dd23601f9326ca76a83c3832332a4f5adbfeadbfce1f3a90a501117476b9bdb2a27dfb5155e3015032c2656840c2f0667773be2659657fd75
1129	4	2025-04-03 09:12:00	t	f	\\xc30d04070302c61b4390a0589d677ed2370141ed6f95a36e43e264fb9e9ad508a8cc5cf899a28ea96b96157a0929b31edde30aad02f1bc4da229a04ee9d160ee901268144f67ac86
1130	3	2025-04-03 09:13:00	t	f	\\xc30d04070302a6fcd0317aba68cd71d236011bee52ab1065c5d904953ffd6e38d3e80ec2366417d0bf0584639070c9d5a8703e370cf8aac9ad643bbb27e3a5d027ef99d8c3e9e0
1131	4	2025-04-03 09:13:00	t	f	\\xc30d04070302b616b7fef725681578d23701685f79aed14b2c61c8cba5826594f4a6282636df7397dc9e8195743cd2158b0d4ae6419eee0c8a5581e231082cb99961138fc35505ab
1132	3	2025-04-03 09:14:00	t	f	\\xc30d04070302e3dc87b767cf3fa877d23601e2a54c39d008c1de66bef18b33cbb1c8759c2b75b91d3931a31cea35085098edbb06c390d054fa969fb3fc8c08aa7e01593611f8d7
1133	4	2025-04-03 09:14:00	t	f	\\xc30d040703029faf71637522816879d2370119245831dfbc8a70dc15774b475865275fe73571207004c15c8bf17a08f66d41c8bd77add81763271ec90f1f6d0690507bcb72d60908
1134	3	2025-04-03 09:15:00	t	f	\\xc30d04070302a057c632c95ab46b61d23601e4a07dfcd42f1b56e9d81db4babe89526f7d3d3795eaad0316f0fef85bcbef2666e5b0523e9a4532e6416105d01071ca630d833918
1135	4	2025-04-03 09:15:00	t	f	\\xc30d040703020af425cea2fc7f6165d237012272725d14eb0a989830b3d3e457bb408de49080b18a809c851b05adfe2cbda31914878a2b7457ebc8349c653ceb805ee4a2e85fb6e7
1136	3	2025-04-03 09:16:00	t	f	\\xc30d0407030226d0dce87dc1ed546ed23601e7625098d2192c2a1198ecd0fe427a4eac643336e1a4ef459c5bddc0d94abcaa2345a6ff2fd189dd5ab178c21b7183c94d23efc5a5
1137	4	2025-04-03 09:16:00	t	f	\\xc30d04070302d2d0607cd67104bf7ed23601ae9cb738bee9009052a61e58cc25d8e4ed4389b3a66085c98c6591aa31f0abdc3149cf2592ab6354af86a618c5e368033dc143a887
1138	3	2025-04-03 09:17:00	t	f	\\xc30d0407030244c3fe9a6b85f84468d236018b23c52215528e69d41018239fea5059c79344cf2df3c8f8480acab412764c69c1932c280b8a48e314c9c8a9beff672805491d296f
1139	4	2025-04-03 09:17:00	t	f	\\xc30d04070302ec69bb4dc70cd4b56ed237019dcaa97c69c690a3a24a5d9bbf86d597045cf4d501992aa23ab8ab6003f036d095404749db84fa84b49b0916bebbafe67608df43d116
1140	3	2025-04-03 09:18:00	t	f	\\xc30d0407030255d633bc1ac11cd66bd236013b9050a9d894a03d8280a76ed7599e345e529fa4ba9c398a65f4a9e9e24cdf9b579cb3ab363b02ad704c19f6266817a30100572a2b
1141	4	2025-04-03 09:18:00	t	f	\\xc30d0407030223d90b98fc4af81173d23701ef934ccb47bf32339b70bfd8badfb46b0f3a03f51b724d660e2e863fbd803f03c0537c695afb49c66de0dfd5a9f4d497c882d001206f
1142	3	2025-04-03 09:19:00	t	f	\\xc30d04070302b9c242ee98e46c9b71d236012493c00206eb1b848b26c2bf27d586511b284e2ac924ad0d1235da3eca189d5b5670b8f2755985317589d6bc09a5635d02afa8dfa2
1143	4	2025-04-03 09:19:00	t	f	\\xc30d040703022bc94777067e289f68d23701d07a0afe01055988e404526af28685378ed9574197914c4241b57f1519b41d7b0cad6f555fa44f3a7626a7eb0e99e57fc52663040566
1144	3	2025-04-03 09:20:00	t	f	\\xc30d0407030267b0144aa1823ef77dd2360104bb0bf96b0240ba3f9f0888aa5665d704afd55d5ab31f8720354e06c3d538507cbb64c367383e1818efe84c17d61f27ed311916a9
1145	4	2025-04-03 09:20:00	t	f	\\xc30d0407030204d107f8265e577f6fd23701b8415e41ce04c1963dba33751445b6df7c55403cc0823a232b9ff5f0725ba2125da56fee086205e4bac3965d420de5207fb6567ec5bb
1146	3	2025-04-03 09:21:00	t	f	\\xc30d040703026c8ea15a53741ae174d236011e80fd8de76cb5a67dd709ec9526b86dcbfff4e1cb2bb5ab2f6217ee2d92169949ccf359a5fe4a76985688690ee91dae08744bcb26
1147	4	2025-04-03 09:21:00	t	f	\\xc30d040703029a0cbee252a9c81b7ad237010f7d5247280565f12bf4732890f018dad7839efd337d0ccb70aedc9f5cb341a26ade78c8668f1a9afbb733d34d802d0445c8852e2479
1148	3	2025-04-03 09:22:00	t	f	\\xc30d040703026ade49cb42aa30907fd23501ff9b416b52f756b3e94a0f6badff80c2335113534c5be90f9053bfc89104088bf2bd2f5a281d9bc4e5d76d3a5906d4a9f56ed396
1149	4	2025-04-03 09:22:00	t	f	\\xc30d040703021ebdbbd466acec1d6fd2370195a807a0166aab111c2dcfe5b20a7813d571724627dd6490493a8b524cd6166c6368301e558e2323c5021fe443050f6fd6d2efd39e23
1150	3	2025-04-03 09:23:00	t	f	\\xc30d04070302edc4ae9ab0bc010972d23601db862eeea0775d55877a5369b6f4bba51fb9dcfaf7dd1659743497dd6132777f552fe1bba063cdb881607fa7f17658663b6b9fca4c
1151	4	2025-04-03 09:23:00	t	f	\\xc30d04070302043bc678c98c326b7cd23601cbfc933f4b3b208e6867ac9ef6705c3d9c9ff7b5c3362a671d4a6880d9103861385884131895370cb9f2b0031f1bd691f0eca21aec
1152	3	2025-04-03 09:24:00	t	f	\\xc30d04070302f45e39fd41aca57c76d23501cbb3f8c1a90ceda04e244a594863042a649fecb82275fc71784db05e32626b591d8812d3c9781255e167d1ef1f2fedd7ef627ac6
1153	4	2025-04-03 09:24:00	t	f	\\xc30d0407030242fc628076ea31ce63d2370198172bbab381b0d45b930dde29f298ff8756770845fd2a64ba0d7b3ca562eec6e1f7b437befc956497f0d02d4f7af572a58e73651903
1154	3	2025-04-03 09:25:00	t	f	\\xc30d04070302765169d8c44054237dd2360121b75fbd4ed56f0e731be483758ef8315dc3378f96ec6be5f083d65d6ccbd4a43110b884edbdd2eee4cd32e3fd6922a40c35c08e03
1155	4	2025-04-03 09:25:00	t	f	\\xc30d0407030203d1f33d8381e40e7cd2370117bb18ae295ad6d79dbaa054ddc5c134f5051870e95c8281a7c0086e18526c9d98f510934ee27280b328781dfd0583de3d403611f90e
1156	3	2025-04-03 09:26:00	t	f	\\xc30d040703021c07452b1ca25fd57bd23501bf1dd7fbec9d6bb35cc4caff3e8f8c4c7d64af704b7e0ed6ef943f699fafdef411391995b7393a7f9c41752e8da0f41add698c41
1157	4	2025-04-03 09:26:00	t	f	\\xc30d0407030286b0e58f0ac90c4563d2370109de3558accd85e7f839ffe033e537c5a045f82b3aef6156cd80812bad901db9e9846f97a7008b519b4d58e202344db16d95ee1a3135
1158	3	2025-04-03 09:27:00	t	f	\\xc30d040703020e79cb737fc427486fd2360175d939e4a76233ce105a11edd466c0066a07745cf523180074cd2e708b6147813dd39f54e2ff3495039bea557088a0eee11958898f
1159	4	2025-04-03 09:27:00	t	f	\\xc30d04070302f6d427f3b8b6f3ad73d2370124d3bfebf070ad3d6732c8e195f3b46a50382ac6373aa91ad307952b5abe842974d026579e158361eb05c1add37f39ad5b8e34f702a4
1160	3	2025-04-03 09:28:00	t	f	\\xc30d0407030237073b072523a1cd7dd23501898f170bc8d87b21d70b6e2a0c8c7a09d6b096f527b986a9d2cc1dafe172c8de4aeaca2ac3f271c17909e12e5cf260bf30fafdbf
1161	4	2025-04-03 09:28:00	t	f	\\xc30d04070302015ee470b07a0f136bd2370156b649ac474c178d4f3c97c63977aa3226ae98754e58a207c5093ec66c59c0f98554ecc8130d363014c91b202755635a3dd0b4af2ba4
1162	3	2025-04-03 09:29:00	t	f	\\xc30d04070302751f2f408ba9809967d23501a78d31febd86da6126c462dc4dd09318cacd9fa58cea4ab07c095160bb2130939b8f6676b8e3932c37afe2a62355ca06716a87f9
1163	4	2025-04-03 09:29:00	t	f	\\xc30d04070302aed84734f1cdff8469d23701ff4a9c5fefd7a8df3da388e324f1d96f9aff60433e92717b079d258af6b1c814323b6dd539c290fb24512400abf7e451140bb71e0d89
1164	3	2025-04-03 09:30:00	t	f	\\xc30d04070302bfd168c679a2217e6ad23601bc5e8a6bae37f833f3650b582fc4ee7150a47d1ed895754780c493f1db663b34a8ce656825aceed4eb29d42165e10c87830e68d365
1165	4	2025-04-03 09:30:00	t	f	\\xc30d040703029e1b32e590b362976bd23701563ee9f66cf25e2ba7d8c78fe73e1358c46dec16f965aa7f963ad093cfe408ec1aa5eb5aa5bc29d1568259a70b3fd8feb80944e391b7
1166	3	2025-04-03 09:31:00	t	f	\\xc30d040703026d7df5f963dd21fb6cd23601f5da8cf2c0d1a0bcc3c28c484f67b66886fd61a3a3554ce3b080599651750523bbf81b7948bd3b03701107be71640fa5542043b36b
1167	4	2025-04-03 09:31:00	t	f	\\xc30d040703025fb5dbc98da047b47bd237014f582cc676310ca8dd70ea80e3a72981ceac5acb322959c3871cf8f3c28623337198a8a31412dc188150a67b5b74ea9d59e8551f3b09
1168	3	2025-04-03 09:32:00	t	f	\\xc30d04070302930c6e58b75f0dc079d2360131d303433f82c7312f44b2ec616dff13bc3ff17d7253e9de8b4fdefd5985a1a5902d0560d73568e97438be3508a48d20610d99cbf1
1169	4	2025-04-03 09:32:00	t	f	\\xc30d04070302551b8740af9ab61577d23701a79e12c0d2c2af41acd99fa0e2b41a9874f7ea414ca01d0b8f52f03af1a1f1c0349bd1a21840011a3203c256422cbcdaa433957a1e33
1170	3	2025-04-03 09:33:00	t	f	\\xc30d04070302b0e031a004dece6966d236016833f8c7ba46d0d5d402c836dd9a3f15612039b054c747c714baa54ab6940faceb164f3ab26a427b7104db119cb81c7f56deeab418
1171	4	2025-04-03 09:33:00	t	f	\\xc30d04070302fe278df3f421308a79d236014146e8bc3560a698475381d9a64c4c705064058ac7b6d528a2b9ac0e1eb15de94bfe5a9f1fbdb9b71834bb5890f8ac0e7bf7afdbec
1172	3	2025-04-03 09:34:00	t	f	\\xc30d040703023763616e49552cce63d23501a37c516cbd7bc8b71bc4c962e213095d3651b77b662fa388cac1b59f54b797dc711b3ff9d08b61430b780cf21f59443dad5c5035
1173	4	2025-04-03 09:34:00	t	f	\\xc30d04070302aadf843d3b7c5c3568d236013bd174746f4d450f66b0c04905734206a94d1a08d204eadcd8e29d21d6a78112bc0cd63195fd5f51b4da03e76bfe0f767d277993af
1174	3	2025-04-03 09:35:00	t	f	\\xc30d040703024a883c4fbec78d396fd2360110795567d58d5f242ad29dcc54f05bff49bfff92358bd0b297f3b54c37dc95ca0be4a5c6ed4a1ce6b1345d54a0478ac6b365062536
1175	4	2025-04-03 09:35:00	t	f	\\xc30d04070302eceb2cd1618370637dd237014dd775bde07a9537b0c92797c171ea4a413910809f56bbbd902528b02729e2580ef9c9acab7aeb5b272809274fe846ad5092254aeb12
1176	3	2025-04-03 09:36:00	t	f	\\xc30d04070302e36947b88ede69116dd23601be92b60ce4a88563885eae89668dfdf09d7d5b3964e1e237beaa6593e40608be5dfb2782ec6f0cc5ea4906c4609b5bff7931927fc1
1177	4	2025-04-03 09:36:00	t	f	\\xc30d040703028b4e8e4e14ccd3f273d2370134011f643c48862d12db758cac06a1cab5cac3b359c7d1d7494fe66bd9907f8138d4efdd3a5395f3f6a3a750464eb5706c327599973b
1178	3	2025-04-03 09:37:00	t	f	\\xc30d04070302fb763c65f009cd9b69d23601216d620394a59202d787470d8c0fed39eb4c75292417b1866826e476441581c2fbeb4c09e8728f4ddb28eb8ae1acfbf817fecb02ed
1179	4	2025-04-03 09:37:00	t	f	\\xc30d0407030272b95069e38f7cfb62d2370147f3edcb475b8e68e113b1ded5f81ae97c904ac90b40e305dbeb8ac344f9be8d258a478799597e9dc285433d5c16e3aa063443ac32af
1180	3	2025-04-03 09:38:00	t	f	\\xc30d040703029822e5f2ffabf25a75d2360115811f501729a46c5f8859c910bc7d57f19e0c51f39bdb0d60b12125cb82bc9807b7b3c7cf28862ff19611ec7b11d92d97b203256c
1181	4	2025-04-03 09:38:00	t	f	\\xc30d04070302bca373f1ac4d71cc7ed23701a1119147061963e9536a58d4679761ba8f4ffbb2e0480581c146019140a7446a240f14ac20aec0aa2e98da82cdbcf9612a08eb01aa13
1182	3	2025-04-03 09:39:00	t	f	\\xc30d0407030240019bfb4b1c4a0a7ed23501241dc6948517ad9a2bf20dd3e14d30fe6c73aaf07258322c1eb4b82e7c941262110e0aa4a1b136a58065d8f9082a3ffae08a2473
1183	4	2025-04-03 09:39:00	t	f	\\xc30d040703020c7c8e8d00fe144b70d23701a634027f175fe56fc619cd040d2a08f731b6e05e7e2f8603272f11391a34c0fb0ebdcac5f041afec6f2d88cd4f99ff224e61a90a5e16
1184	3	2025-04-03 09:40:00	t	f	\\xc30d04070302c3961702c334d89d7fd23601a91466e8a127ae486851254e0839624c2042e4a60d0513e961c4e0b8213664af26425ab29944e2c831bd5addb7703e76e0314a9601
1185	4	2025-04-03 09:40:00	t	f	\\xc30d040703022da2fcaada4c5a1c72d23701ab5e3561089452b0ebb841738542f58ee52ee52512a2eedf6ae2521fac6d72f2af859cf462415be8a0d86d59c5ae7d4eb764025969df
1186	3	2025-04-03 09:41:00	t	f	\\xc30d040703026c0289f307ba48fa72d2360136fe17d4fb1045cc40edfe0e8799a5d3b8f8abbabb07c08ed99fea94e447796a7c5b8ed878ab5e609bcf2b800061a79c057d0046cd
1187	4	2025-04-03 09:41:00	t	f	\\xc30d040703024f1852f3f825907060d237019ec1d3bda3d78a89a1cbbafa6ce1e482dbff48202ddcd9fe3dcb8a64dc4ca662a5df2b7f98554457433890514c0704dbe32ae3e48c2d
1188	3	2025-04-03 09:42:00	t	f	\\xc30d0407030207b877c24b8cfda675d23501dc9b1094ebbcffd7a855de47302ee0fab459f6e266ac7d3047515a21c92cc989066e20d066a2eb47a777ec30ed6267d7bf7dfb57
1189	4	2025-04-03 09:42:00	t	f	\\xc30d040703027c81d89a18117a686cd23701efb2effc8d7501f38761913a05b547dd25cbe599963f42d7c847f9f6021faf6c00c3a7bb6e83d7e0f5c9acf856def999dc857daf440c
1190	3	2025-04-03 09:43:00	t	f	\\xc30d040703020decd38d557cab097ad23601ace298fd7bbd4797ec0a8582d2b0944f23d07351cf1341c7fc3ff6dabef198c614458b8ef85e286055d5a511f3bbdc89f70fcb1792
1191	4	2025-04-03 09:43:00	t	f	\\xc30d040703021bf15fb7715aa3db71d237010230e0492ee58c5fdb717e7b82b73c6125fb579a4321b13375fe60238e55c522a77662439fa0ce8bd33ebf01fc7278c1d765007bc254
1192	3	2025-04-03 09:44:00	t	f	\\xc30d040703025ee8df9a8213474669d236013279119edca76c92bc35e92bdc520539ec2a24613996f2a1c2deaf9f34acc10caeff78875806d372bf5f90628ccec29ecc4373d5c5
1193	4	2025-04-03 09:44:00	t	f	\\xc30d040703029a6a620281842b4777d236014c950797db12fc201dd4247ca3dfe782a04f8abc03aaf5e950b1084c2bbe86388f73aa8c2b47072affeeb1315f7a7703913e0539f7
1194	3	2025-04-03 09:45:00	t	f	\\xc30d0407030278728e1aa90ad67168d23501559184a45cd32cf86910c90314367578ef5846037cbaa00f27561fcefb9fd1c3dcec547e127a2d678630d2fd268785eb6e154210
1195	4	2025-04-03 09:45:00	t	f	\\xc30d0407030295abb4a1421b5b3f6ad236014860cd0b01070c7b2b61c2e29454467f85518fb6836b87e5799d5c0c3f0741708668990a51726db9658e24bb0a5d1278509ef3b4f9
1196	3	2025-04-03 09:46:00	t	f	\\xc30d04070302bbc588ff13df139161d23601f30592f43ec423269068c54493fcd789186291744390a1e739783a7cd276af9aaf9670d90337640e60afa3811da6aa67b7880ce87b
1197	4	2025-04-03 09:46:00	t	f	\\xc30d040703029209ad245610b9b36fd23701e21ec3a60706decfe2f914ad0a07466d17bf067626bdc03277c5ecab03530f2b9145f97317755c0ac255ce57c365a88d0268e3187b77
1198	3	2025-04-03 09:47:00	t	f	\\xc30d04070302b41f2ab55a8f516964d236016a11e1e8b3ebc5ed56b00b6a16c73682d66baee1f466f0fc4b4857d7128f0f3cfc80fca462b5affc8b880ec57b5822cdb7d4cc7615
1199	4	2025-04-03 09:47:00	t	f	\\xc30d0407030205cd3d616324f21d67d2360155c3d28452ea202137a08f46f362e6274b6f0518587af94324fae8da395e326fd31fe29ade9e826bb9ee7ff6f167715f2109918eea
1200	3	2025-04-03 09:48:00	t	f	\\xc30d04070302dec597cd03ef0ac87fd236014f98d6f88fdb492ac4cb1d3e2c53d048b10d170b63c09e1c1e6d7317ba791cdcbde0842464b4770608a2d0034aea8dad3589c5bb77
1201	4	2025-04-03 09:48:00	t	f	\\xc30d04070302a13217cd0ab754a566d23701b36ce8938c2973a62fb3b8d986f5b6da1c8dca65e37cd971bba4541995fd7304622a30968a21cb9e868e8737443b4ec83da781ac9a20
1202	3	2025-04-03 09:49:00	t	f	\\xc30d040703022a73f0c26cb7643776d236011dfb84f36e5a85922dda3b85236a18323e7a89564c1ec79661921701dbc75623262bf31e88d4d812afa87fc49b5614388b6fdee5d3
1203	4	2025-04-03 09:49:00	t	f	\\xc30d040703024a18ae5e6265698261d2370123b34ed84e0df6b0aec1e140661fbe3c49cbec30427fd4b9881c6c93b424e8073a91cc5ac2f2c7ad48be7ea9e465fa412b752694cedc
1204	3	2025-04-03 09:50:00	t	f	\\xc30d0407030240df4aa5791525a269d23601cf77c5c21af3a6917d75064234af97c7e61fab7eb7c2bcdc30c5ffbcdae1ae5a7d748b5a870c6052cb5c084231726e2f3e611f13f0
1205	4	2025-04-03 09:50:00	t	f	\\xc30d040703020cc8794c7a2f1d017dd236014ab1b5727e4110719acbe3a653479eed1a40f2bf68584b0299a964745990c09c59ff1c664f98a5860cd56599a6cb2c39a463b28d2e
1206	3	2025-04-03 09:51:00	t	f	\\xc30d04070302bf33ed350fe0738f73d23601fa42360c3aecf356686a9e26614fea568b44724ae5127857d970bfda5881bebc60fd66eee9fecfaee8f865d203a856f120f2e00d3e
1207	4	2025-04-03 09:51:00	t	f	\\xc30d040703028704938c973457ee69d23501585047414368d5ce95f6c35b044fd447679f5e2ad31dfff7d7b30c716e2a162ebb8609ad1ee79f3d2f478882d09c77635e9f3ab4
1208	3	2025-04-03 09:52:00	t	f	\\xc30d0407030218eaf74004942aed67d23501f472401c504e6b0263b73a47e7822b8f856c9ee6cfe2b4c85dc1f89e2be90527ed377f4c68d05da0d02953f20682e70da7351864
1209	4	2025-04-03 09:52:00	t	f	\\xc30d04070302b5055ef6c87edcb067d23701253acfa2e1cc2a5deced64bf0f90f8b5c5827862a12199e11530c8ac2f54175f38bd70d63c90e09a9fe96d00f528dcb1be092e20a02c
1210	3	2025-04-03 09:53:00	t	f	\\xc30d040703028dc035f85f40245672d2360129fbc28599d153174fdb77aac7ef43bfbb754be83a762800e14f574e348191d6bd12a3b1b5b28f88e7c22bf67d9b486383a94a7c99
1211	4	2025-04-03 09:53:00	t	f	\\xc30d04070302232324b39a2488a461d23701d4f654623d887a658a866d14ae29ce5092d9f22c19ae2ddbc37a8cc987fcee9f287c2f43d048feb3c30ae752c098749903dda9eb05cc
1212	3	2025-04-03 09:54:00	t	f	\\xc30d04070302f4f65aef62ad161765d2360116cb30a2b5fef5b6c611982ed55ff590dd7586f33d5558752cab03549268ba0b6d6647bb180ec542dca637309c52a55dac4331939f
1213	4	2025-04-03 09:54:00	t	f	\\xc30d040703027d28915cf86a70e768d23701d9ca68f9d0049adf8c829dbb8b5be9dfc3f550277d18151a10f89036424337b39a2c51ed567e6031b80a0e3dda50da3be513997f2450
1214	3	2025-04-03 09:55:00	t	f	\\xc30d04070302cb9049806e28f2d16fd23601f5cdda482d7310668d19842237a6a298f06b5eb5e315aaf3f9121cac6f8d2e9aec4d04035cf3cf3b4bf8df8f3ba95ac7ac4298c0ae
1215	4	2025-04-03 09:55:00	t	f	\\xc30d04070302f7888b7a651f35ab72d236018a00dbcb0372ebc11c8bbe22e803ae3c8c09272504ed1cc54d77e8b2cad5973c33f494ea507d7e2fff4bdfe3aff0cb517838b0f3b1
1216	3	2025-04-03 09:56:00	t	f	\\xc30d0407030251cae00f03a64b0a61d23501ee3f0c0b747e9fa5e13992a5d9c25150e8c29e65289601d46751a52f666028acf25e811537f728ae215ff762e7f99fe6c0b13ff7
1217	4	2025-04-03 09:56:00	t	f	\\xc30d040703027674c2acc40b4df27ad23701ed2eb196a52c722fe4ff7586d9288f58e3a85311c266ee6a848f38015acd59ffee7dbaf73e42f594d39014db9f0660869f930225a181
1218	3	2025-04-03 09:57:00	t	f	\\xc30d04070302511f9ac7e99440b56fd23601148213c48e512840dc528819a66b5467650228e5ffcaeb4ebef2e0ea69a74f488083446d22530d67f5940b6a1e0383f0f680e7caef
1219	4	2025-04-03 09:57:00	t	f	\\xc30d040703026f3b5532ec2dbe426cd23701fab6605d97ddfca52e10784e4c1db7498691546fb16432996eede996a28be052146422ba6656635897fb489b02cf091076cf40a2e24e
1220	3	2025-04-03 09:58:00	t	f	\\xc30d04070302e3a2670c50ec827060d23601b5d4dae37efb4c68f4a70c4beae4cad3671e82d2c52145c2ac477a8d7abae889f8d2cc51027e91cd5c659e4e99333c80e9a944d351
1221	4	2025-04-03 09:58:00	t	f	\\xc30d04070302415e3d09dc6f70356bd23701ec917452e30ba128c521928ad6b37d5b620760b94b3152ba6cf0e138243349823bc72416962c25fd5ca21db802f0d3879138ea8571e9
1222	3	2025-04-03 09:59:00	t	f	\\xc30d04070302c052b5cc93a8fb636fd23501e8b1271a89a3ada1adae4f26bf4e0ffe39e47672aeaf12c903fb07be5a40c4098a04012bd3fc9d67adb5583440c38dfc7be59513
1223	4	2025-04-03 09:59:00	t	f	\\xc30d04070302d51f65a9ba2d6e4674d237011b713378d6f8d925b22e035723bfe9223e315f81e31c76df9e917e6ecb3bc19ca0f0687e494b0c3a2918006930e2f0734952001f986a
1224	3	2025-04-03 10:00:00	t	f	\\xc30d04070302fab161d22539292979d236010198448d75377c678dad35517b15004fa2ccc6a60c46cc641b52b3b7499e7d965a7dd90c0bbae1198bd769645c6f1dce9650f87d5e
1225	4	2025-04-03 10:00:00	t	f	\\xc30d04070302bdb7b5c16c65a0fb67d23701bc5c352dcd44e0524147b4834032b4d14ef9b75adb0a0a1d57e6abc3d66f75dda138ed3b8f19ad5a98aed6a1a1eb275a8041c24edd74
1226	3	2025-04-03 10:01:00	t	f	\\xc30d04070302ed70eacd509ba26062d23601d22e33aa3dc77236d2534e4ed9350d621222944cc0da283e292e3a8ef30d08d276daa2ad212e80ae1c1eb6f08409c40ef1d621f9f0
1227	4	2025-04-03 10:01:00	t	f	\\xc30d040703029c41bfb4fbbc77ba6ed23701cb60fafa5c4fc61ba875a4dba2cacba53ed0017bfb53b4a008fa2a38192ce53c0e898ce76c2614148c5329100add7629f94ff6fcd85e
1228	3	2025-04-03 10:02:00	t	f	\\xc30d04070302cbb09f58e1928b656cd23601fc31c3fece734406afd1a155b14883135f07488ff853c29ce8321b1291f0dcf9ced5dc901e576ae55ec2961c7b9218d4dee600366a
1229	4	2025-04-03 10:02:00	t	f	\\xc30d040703024b02c022e59dab8478d23701a8c7a2db35dd57622afbefa0b480013003baebf6f6581a624a6905e973fcc6c9a6e1a7ce547b1b92fc8e156d2fc46be56666f95585a9
1230	3	2025-04-03 10:03:00	t	f	\\xc30d04070302037c66207fb2b4446cd2360146b0202f332a84d5e43fdf19502e89c9896f34394e583f5dce44eb72cc8da9fd1925b403dfbb55d5148dd7900f84c902e74d836242
1231	4	2025-04-03 10:03:00	t	f	\\xc30d040703026c8d9b67ce8d92b76fd23601246a19365f640aa45e63351a274f0a87aafe48a8932bbdea000fc25e3a85ec3d3b7dba79d6880dd3d60c7a0856f1e4e7eed0cfba57
1232	3	2025-04-03 10:04:00	t	f	\\xc30d0407030250c2f8589b806dcf69d236019fad1c6774c0fd54739de92aab0ae090a9cf9f4b06f5d589227d426c02c08cf806709523b28bd637b1a528a6bd351aa678655f41d3
1233	4	2025-04-03 10:04:00	t	f	\\xc30d04070302e584f827b1fdb52d7bd2360148d63ead2f44df41407585a7b9fbabb37d3cb7926324c83d58176e7c99a061595269986ce2c5ab2833a5545ea3bfcafb9d5a1b4328
1234	3	2025-04-03 10:05:00	t	f	\\xc30d04070302dbb1b0f21a32325f66d23601e9ce942ff8437a9bbe0aafe6c7c85f0e58263db9d2dc731a51486041266b8db042aa182425b67dfa873b27e6e4a8b43e9a9a3e2cdc
1235	4	2025-04-03 10:05:00	t	f	\\xc30d04070302a46dbb6a9a3351077cd23701c35b7affc4f5c50243c5e24d84141388e664afc0763519c4b51046fa4bce6d4b674eb48ed9f9e25d710603096db25a43e6f945ee76fb
1236	3	2025-04-03 10:06:00	t	f	\\xc30d04070302250a03c16b2c547c6bd2360151f03cf9a5d9398b742ae11ed8c9dc36a9c456e6f69664cf0e812d3781a8254e3dd8e6127f5af54cefb3376080b7269ee9cee20282
1237	4	2025-04-03 10:06:00	t	f	\\xc30d04070302094b1dfed57f234d7ed237014e10f86d65d4901ef6822541e1912c4cb92e22383e6c501496ea6820b4be6ece35bf3a4958c588ea0ccf42d9bc2082d23c3611aaf474
1238	3	2025-04-03 10:07:00	t	f	\\xc30d040703025028935cef655f9469d23601437f52aa6c47cbc013cd7d420e44506fdba295913e1bb0ca6281b7462e790305f5c86b56bcfd116646857da1921a8076fa6f9c9108
1239	4	2025-04-03 10:07:00	t	f	\\xc30d04070302c7a092ecfd17250e77d23701c4df728e7ff0d62f950ea3324279e25738c00a72af33d607f491cf5a9790996d825896b62611ed0e932437c3c62232816056d3a6e75d
1240	3	2025-04-03 10:08:00	t	f	\\xc30d040703028b6acc0197e79fe968d23601ebc49691e4fc6c25ac42fa8b58c2782528bdcb29d2dc8f17b013a4e28bd147a3f4e8d8dd7f9a18dd731ed4189dd39bf25794955d4e
1241	4	2025-04-03 10:08:00	t	f	\\xc30d04070302f75d6b8e0663206462d236011488768ae600a91eb7b31dccaf715b2aa65b5fd07545077a397b7543995260b140e35c4a3330843755051dadaaa2b9edbb65138eab
1242	3	2025-04-03 10:09:00	t	f	\\xc30d0407030296a7ac80864974d578d2350146afb4d53769b169a4bfb7b92b679386e0fd14bd1d93b1ab3f3272ce8d350ce850c705b4621ecd13d227a4d46ffd7e295187e4ab
1243	4	2025-04-03 10:09:00	t	f	\\xc30d040703023c60988d90ef675264d23701e68198ad3ab8ca1ce6e2814a66689fe33a296e39b4994ff23c3f550970caa4809f1854aeeb32c597b0ae9885ca525b6dfb3af916f458
1244	3	2025-04-03 10:10:00	t	f	\\xc30d04070302372d9431449bdac679d236010167d64bf0ad844ead6eca59e8b36d651e505d924359fe2ff2c4505c1cc84c54a95434e256c80c2676866bee11e1498466535fc150
1245	4	2025-04-03 10:10:00	t	f	\\xc30d04070302e53eaf8fce4b8fc07ad2370145a08de52c6fb2c5061b64e654a2f09c3a9f9e359698695e2948c36e8720af0fac9fbb115987b5375ea49faf56c5c018f5b0a7d367d7
1246	3	2025-04-03 10:11:00	t	f	\\xc30d04070302101456140b9eec027dd23501878799fc4320ee796bdb9f983e031af5e9747b9505f4a9424d99b0918fe6b73f4cb4ae16a7f801ef87f28d5b9fb0db7177fff491
1247	4	2025-04-03 10:11:00	t	f	\\xc30d040703023600f09d3709d3656fd237014cc79ea53e9338abe2e099777d63aa8e57d9373073ebca53b5645bb497af5d4d31203206dfb6b4ce419565d5ce77e8635ef59915269d
1248	3	2025-04-03 10:12:00	t	f	\\xc30d0407030204a2d893bc0d98cb70d236016f4fdc679b9ba1c92252034a23a79d9cc068d98d55479070cc3632e6cb32d6d75976f6b98679d517636f91f2c0a2c7d61e1574d959
1249	4	2025-04-03 10:12:00	t	f	\\xc30d04070302c70d1e5489904a637dd23701886e2f996c8f5333c3475b314a1c136bb841f9ba67b2f393fac27550ef49d53eba28b4ebf8bbac7883b6e09e2af4f6c5f5a489afa1b8
1250	3	2025-04-03 10:13:00	t	f	\\xc30d0407030257d11059e4cda2ac74d23601ad7447b2dcf88a107023fd46af2c039b708570f235c430113eb43e7f76a27834284ae0f949bd0b37befd04bd128795f35579fb4d5f
1251	4	2025-04-03 10:13:00	t	f	\\xc30d04070302435a612acc268e6c6fd237014193f42e069ef07bec3d70a5d4a703a9293cccb74c3af65feb6d64e5228ca4a70d4efb7124455be1267948cb540912a2e561dcbb68df
1252	3	2025-04-03 10:14:00	t	f	\\xc30d04070302f52d12053a0512fc61d2360151f7f969d86f97bc397bd0ba757418fef150fda243fd1cfccc05f32b15029f350170b5b7e05ea94cd42420886396e4bdbc67b4e24f
1253	4	2025-04-03 10:14:00	t	f	\\xc30d0407030248495dd278316d7578d23701650224a7fd350461597dd671616ff4756954879ea119764783cbde40bbbf070e2453d5f637d86f677d60aba35b6db216b63b575ab00f
1254	3	2025-04-03 10:15:00	t	f	\\xc30d040703020513dd2f9e0b8f997cd23601713483eff0c3f1baabf39600802bc4ef75545628ee5263aaa95288af69849a4a8564012480790c2668871c4e6d62c538f995e54e2e
1255	4	2025-04-03 10:15:00	t	f	\\xc30d04070302d8b0a923af05b85b63d237014e755b46ee8c89b1b56e8cae598897269f7053c535ecd4e9868a6e33bf8adae5b1d5ecda3786799f5b5682009cf4b7336a84414b03c5
1256	3	2025-04-03 10:16:00	t	f	\\xc30d04070302dea81e84a307034e73d2360191d3768e7bbacf34db4277e056daf60299cbfa4b44ae5bdfd23a20eb26f9752c1ce6aea06db385a280672f080d1bf9be2428dde066
1257	4	2025-04-03 10:16:00	t	f	\\xc30d0407030216c04528a11c673079d237014129bb6ff53c2cb198f0c5b1265a3083c6633a76fec258df52b3481004bc4b41b53fdb483232660762ca3c0fd2baafe0b0cf3886d2b2
1258	3	2025-04-03 10:17:00	t	f	\\xc30d04070302610ce18e1a94574276d23501393e522554149d8f18150ea6070a74a586551439d82f750fdad875cad7ec5704fb48cbc4e17abb62300d09f291c579c089abaace
1259	4	2025-04-03 10:17:00	t	f	\\xc30d04070302d51ef8d23d5a9c507fd23601a41fdbfb61154dd59fde3799926726997fb0e66a19297e27dd3ce6e41ca2ebbeed45455a6f4e38ce29ac3112ef1688f4c9b5488d96
1260	3	2025-04-03 10:18:00	t	f	\\xc30d0407030205e91b1279c86b1575d236012f091eb53546bfb3c57343c26e3c95548cdb49df98ed56a2c32db05246e198bd06d166928f3303f42b43e3906258fcfd9afede029f
1261	4	2025-04-03 10:18:00	t	f	\\xc30d04070302d39af9949392adfe6ed2370186c456a854a1c980f4136a2337db32992ce12cf584d82e75e1b78f7a569ae2fda9494831f20298d320006471a218736d396be4251e52
1262	3	2025-04-03 10:19:00	t	f	\\xc30d04070302b08a59c215ada8ae6ad23601313b2f0127fdfd1745efa71cfeb7269f57c0dea1104b1b6bf4f2ff3364d2a5a78b2f71fe29ba2b7837550029f09d0e9d73190e4970
1263	4	2025-04-03 10:19:00	t	f	\\xc30d04070302502bad62d1c0cc3f7cd2360184848e3c043d6d0ca583b98959144ff21c65821edd68a8c11d0c544f5e533cf30c87bf9bda99ecc78b3563838c389924c647f57821
1264	3	2025-04-03 10:20:00	t	f	\\xc30d04070302317e05279cca1b166dd23601ce7695fc92ced9cf6aade6e48a09c978b18a0bc8bf908ab32a2e6e40aea7b444dc78478b20522984d12dc31801c6eb86a6aea7e15e
1265	4	2025-04-03 10:20:00	t	f	\\xc30d04070302df94793dc20b901a63d237015aef3d2947fede2fa0414d35321bfff1e4a9e57287d86d8fc8e28a7fa70d1021721afa99596c022b6ca2a7eec289e09e01f6c4ff623e
1266	3	2025-04-03 10:21:00	t	f	\\xc30d040703023db6cac0973acb0572d23601fff8f26405434ba690431dc9983fd14efa038684553887baa89749461bd4eca55f865b785e46e25959911681c0c4b7cc5425a289a0
1267	4	2025-04-03 10:21:00	t	f	\\xc30d04070302d8f476bf6ad863147ed236011f279fef990863f1c9398e043099f3133514066e26f61902f612501ef9a88e9b101bbeaa054523aa33fd899cd84f0afdae2f8bf97d
1268	3	2025-04-03 10:22:00	t	f	\\xc30d0407030220bca1be07dfe7df62d2360190bfdfed680e595d7813825136d4296b01ddb9065f6e86ea216cf0d77a7239de92f5c51e408b350c4c0787079c27347935a37d4fad
1269	4	2025-04-03 10:22:00	t	f	\\xc30d04070302cccef369be83db3b7fd23601087e92eb9788323b875ddd17a76ffb373c194ef397be7a4784f8afd1049edcf60b4654fa65e7f48ea97d164848703a7656d6f1627b
1270	3	2025-04-03 10:23:00	t	f	\\xc30d0407030258b739e881bbd42566d236015d3f38404bd1884f47e5191c1dd12a572311406f8611ed40f3f661d0153752ba9f5bdfad7b9023c70959931d4f929923e09286ea3b
1271	4	2025-04-03 10:23:00	t	f	\\xc30d0407030268b09b210ce6b8dc63d237016f1457c737f5855f538c8c40d35412240bf02107aabc699a0e4f361319c7f64beccc83daf509343a540e23eb6d1bac7d136fa9bba252
1272	3	2025-04-03 10:24:00	t	f	\\xc30d04070302cf2bdd7e448215ec6bd236014531a40e868829d6968ef73bc550196c0c253ca168729a74fa3829223e387f53e10a6e951e0082b6a6ee7c8ce1d8e32583a9387936
1273	4	2025-04-03 10:24:00	t	f	\\xc30d04070302a7a4a26c2ea2e36178d237016d4cddcb424ba8468960f332a3f1d21f743aa5155c4055cc9d2a0c9c30250ce5e78605b8e22abb892208c2f715209310b8c3626ef845
1274	3	2025-04-03 10:25:00	t	f	\\xc30d040703020c00eba254c94a9466d23601d9ad2f2fc78c8d7a4e4d838d7b177a35bdc32761f6ace965d90db8440cb5187cf2e01e96cd16952f5043e649f1707d0d1f042aa314
1275	4	2025-04-03 10:25:00	t	f	\\xc30d04070302dee96dd7e406423b60d23701ac016c5f87de757f25deed6613d8eed60570e365d3894a746fb20ce0449e13d6340be68569347f5c6f1ef560c45950b431a2e76c30d1
1276	3	2025-04-03 10:26:00	t	f	\\xc30d04070302702bc31c6665590e6cd23601e05403569747d82c81852364eb55418e92f9709f766ba3eb5749ad43ac3bb2bd97dc5f78989ef87182ed0ae3c74cedbd9fd55df056
1277	4	2025-04-03 10:26:00	t	f	\\xc30d04070302ca708a8bcad79ede61d23701498161bd70b84840a50adfd6b860d1147d3da341bf46d0071cd01724936c14afd5d9835d6ade5569e73fcd57daa9687f473378a85d01
1278	3	2025-04-03 10:27:00	t	f	\\xc30d04070302b30b6e2c45c1c05e7fd236016f761ae956c61ae8ad6419877f1a65b29d9608b186b359048c7eea427617121fa84b3f73bee68f3cbcdf2bf3416113b20ebb114628
1279	4	2025-04-03 10:27:00	t	f	\\xc30d04070302b738126846a2b6f369d237019d689bb9deedd35dcef69405be92ff219cbc69a26aee9479ce14adec237ec412192a9c6240f824e5716a41fc776f9733a0867c6d446c
1280	3	2025-04-03 10:28:00	t	f	\\xc30d0407030279f4d2baaa2cef4d72d236012bdb2ddff22a76441f5e798b6302947626070ca291226013590cefaa74e40a53046f8dd8783c1bad228a17b580cf573a33e41bb278
1281	4	2025-04-03 10:28:00	t	f	\\xc30d04070302301ab41c744b177063d23701d06b26fefae9fe3c8d59495a22fa3d9fb8e93eaa3a5b96e501c585f33aaaa36187c9b8006f27eb408205ad603eff03f124114b3fb6e3
1282	3	2025-04-03 10:29:00	t	f	\\xc30d04070302212b9bf86ef1a29c6cd23601e59932d928680907a32cdf7ee20eea6cc5ff7b127019ddc6204c87f03a1da176da7e4cf3512dc25dbbbc7743dd61a55be8be6ee351
1283	4	2025-04-03 10:29:00	t	f	\\xc30d0407030291d3368dc1e8023373d23601e7646ca1e1dc66faa39d147c1b11575ceff76fe4c9055d23f570b6fd7e835575813b2c74f26e124a2d675114e528ab3cd64ae2bd34
1284	3	2025-04-03 10:30:00	t	f	\\xc30d04070302ec372431e7bb021274d235014feab4b0fc48d5a0e3141b1b5d6ff0a46e803b87ce3533e0aa25509716a492ed6d430dd8c1dac4580a465d7583b574f112382da3
1285	4	2025-04-03 10:30:00	t	f	\\xc30d040703029990930c2442b44067d2360167592cf9796043a195e7868fdf5b942dba729f65e73598d19eb75464a4e048ca5f492d8724090335383002af09fc8ce4975b7a92e6
1286	3	2025-04-03 10:31:00	t	f	\\xc30d04070302cb19aa36133492aa6dd23601a99e9ddac82eaeaa073e616750fce06aa3529c5cea8a7cc19eb4d989d0ca8875927b6420a248d3f66c529de36d95b92a413f0a6000
1287	4	2025-04-03 10:31:00	t	f	\\xc30d0407030267747b498d81aeb47cd23701201975146a20b8d54b3c5de08a4f36143d702c6e245d2e884f66068d95cedd46cef0af4cc953559b5c547aadea480f18c2541c42a096
1288	3	2025-04-03 10:32:00	t	f	\\xc30d04070302a15b67c1c75dc0e17ed23601b8bbcb62da0a9c7d9be8fa64b122a476792077590bf3c18b3490379ff1c5ea64992fccee50dadfbfddcb6bb2abd3d5421533db3ccd
1289	4	2025-04-03 10:32:00	t	f	\\xc30d04070302f2d7fac5e8c03cb36bd23701cefc06ecd53f55c83fb32e0cc878174d12313348bcb7559f7423eb9f704da61db551eb36eb9f6436f0e4e1ace571972e93d8c36c1021
1290	3	2025-04-03 10:33:00	t	f	\\xc30d040703024871ed4c4010e37b75d235019641c5eec9fb58815b30e363069ab4ba61e8fe867ef0b6d533670cfdba64a375fd4292dff75f4ab64c925c1942b936845126bbae
1291	4	2025-04-03 10:33:00	t	f	\\xc30d04070302e5510b76c75e9ce474d2360118754937b8c2bc501e3255310f3ecb11b36b2d45c7496e067a3a8142a6357f12889a635841eca6c87e22f71e4b915b8537a4d590eb
1292	3	2025-04-03 10:34:00	t	f	\\xc30d04070302451ab739c30db3ae62d23601ac9854353d888be7e2e3e8b31a89876ba3f1bb770ee094bb38a233ae767f678f60d97a2ccf1e4caa5aa90ab9ef246b6c9d2a0db911
1293	4	2025-04-03 10:34:00	t	f	\\xc30d04070302985c0c0db86d958866d2370124a721e5517279eab7d4e37af42d19441f4f66785d974e2ecb8cb3f692e695be81e121b526f99a2deaf44f2fc805e02d87f74cfb25a7
1294	3	2025-04-03 10:35:00	t	f	\\xc30d04070302058bde7964d86cf062d236012d4576895ea9d6ee05502268ea3c1774aa1e269a813a4a21ffb97b4fda46957ad42bf85690be8cba1995cebfb3d6860ce2b523d10c
1295	4	2025-04-03 10:35:00	t	f	\\xc30d0407030268cc7d9d1f6ad0aa67d23601ef64db284a0d4c09c2375533f1381c0625f4df099e7b2511df44a98db2d12b44bdf09c0f779504f83e249383c7d083dc1d9db458e0
1296	3	2025-04-03 10:36:00	t	f	\\xc30d04070302a8cae0807eaf3c247fd2360156e7d64e921e2cd020903ecb67f57905350d10db7519b68c9e897208df5c30b19197eebf0cec469a88afeaed43945ea17f2e11d524
1297	4	2025-04-03 10:36:00	t	f	\\xc30d040703021021748023089fc266d236015c4717e57682be05726b9b1729d51542a437294343e59bd53534c25138953260ab688919ea09b7e925dcc8c2ba9f513c79f724fa02
1298	3	2025-04-03 10:37:00	t	f	\\xc30d04070302935bf9d0ea1a3a9179d23601b1f8dc347abfccb2ee8593efdbdd46a08f94e7c737d3fedc4972c047e4a8eeb621f4f859564509d5188a470e93c92962e289205962
1299	4	2025-04-03 10:37:00	t	f	\\xc30d0407030222389d51d23759f36fd23701bf363710062fdce2393723f2844fb3c65d1c64b65444a8c4c0a17a97237b3ee7df425a54475c2da2d715914b98fb5c18fb147ff9d989
1300	3	2025-04-03 10:38:00	t	f	\\xc30d040703028155915d6860465776d23601bb7729b13029ee76aa0f1c17553132c2bd7c44cd28cb5f00dafa8f5de9e0cf8a982ae7e11684385b2be8e53faad51bd37c909686ab
1301	4	2025-04-03 10:38:00	t	f	\\xc30d04070302469fe9fbbbad35c175d237013a6605646021774e25a3d3a5e7dd91a4f44de4f27aa00cbd447803938f3296bfee0109f6211df2a60eed49599b9588facd24299d7b76
1302	3	2025-04-03 10:39:00	t	f	\\xc30d04070302abec7b1dca85c8277ed236016c064cf35f0bfa004ddb8068be5657e2a90be752fdfe47d04a134fe21e14049ddb3fa8c1ae083ef140284deb24e6bcb400f1527e0d
1303	4	2025-04-03 10:39:00	t	f	\\xc30d040703029f8ea0222ce23e1169d23601c79838165a515d87f84b62d3ab5e778a6e3472cc972faed0c6eb544dfc24c8ddf81ad7a57669b6805fe899cac5b36f1ced6fe96f01
1304	3	2025-04-03 10:40:00	t	f	\\xc30d0407030227f84091e2f3f96475d23501094d985c9ab1efc48e524dda2b4d27883dc9b1f2ac7a9947ff06a10c2751b1cef737d31c1d5909f74a2ae7ffeb2c8243d84cbfd4
1305	4	2025-04-03 10:40:00	t	f	\\xc30d0407030218bc95b778a5ccbc6ed2370116755405d80db078c0462414ddd87dbc36630f8796d506a4208636a38b2e5b421f6f3f8b1191b33e2ce7d223a4c8a15111ec92c19ed2
1306	3	2025-04-03 10:41:00	t	f	\\xc30d040703024555c2cf72b874c273d236011f33233e268b899acee62fb9e348bfadd5ad561e02645e3e6a05ad49418c24b2a3e9697ad13f7c77fc03dc2bf698fd17f53ccb7a19
1307	4	2025-04-03 10:41:00	t	f	\\xc30d0407030244f745db141386d67dd23701ae5895f8d8fd71d0ddfc7150ffa8db95fda5c5384d09ee26b4c0f7f7207a50608f5fbbb6e78bfee3ee07f4a16e425e643a4fd7a0a61f
1308	3	2025-04-03 10:42:00	t	f	\\xc30d04070302b6b3d603a7dc457268d236014630119fea8e99d0df16a014a7d2a5a3d6de7bda71f6e85c3db07d49aa8b1544d213a27c366165a2c0821c43e7e7aaf74cf1281398
1309	4	2025-04-03 10:42:00	t	f	\\xc30d04070302d94a47bb4a2a219f63d23701517818d23f60158ac30fc6e30ca89e8d5f126001f0b2f98d216417a8990d4e7ad354d2d52fd720e21c77c2a565d8fdd871e5230b24ae
1310	3	2025-04-03 10:43:00	t	f	\\xc30d04070302e55b42b3ec2665947ad236011666eab993329dea9ca4bc025713a57ea2ae2ee261a1e54030e3f429b71c29f3e629b34a56a277efb986a71ce4d139bb121bd9f515
1311	4	2025-04-03 10:43:00	t	f	\\xc30d04070302d01520be9620130678d237018ef58d15175c6b99122f06ba7b09369d8bb0cf727062f9c5fe7579f8ea13db12fe54f901274c0a7dc823eb6f06a9ecfc81db52536bec
1312	3	2025-04-03 10:44:00	t	f	\\xc30d04070302748bbb81cc0596337bd236017cf7be6341a579e59e5010cd83d496d7d9799589be859cd6b65a801ba6d3aacd6cbe1c49598aca636fb70976104cf26a91f4d89f36
1313	4	2025-04-03 10:44:00	t	f	\\xc30d0407030207037a0bd9dad9b874d236019d86b5f9085929077359211cc6505791fa3424a4506ecda5175f079d94352f915f280bacc6c5c9a7ce81cea791788d5a7b61a95a53
1314	3	2025-04-03 10:45:00	t	f	\\xc30d0407030240c6935d3e6054cf69d23601a9ff059b871472a44a480daf415a19573c2b9a2c0b32111f1d7b8634dd324880ae6ca6002a470d2eceec45216b3ac0e2e9c617163e
1315	4	2025-04-03 10:45:00	t	f	\\xc30d04070302b8a26b6d0f6145ee7cd237014fb951ff05e28eb3c5fb74ed345128ad0a36f086ce404fb917143ea3e5a1141a41b9ec5ee42d25333c02663ee812a327a5609dec2e8b
1316	3	2025-04-03 10:46:00	t	f	\\xc30d04070302a2eb8c2f0943797d7bd23601e2c2b79444c4c8d2e88cd911aa52c4918ab5f9e26908c9beae3a02e5b118fca320df936185095727587358f3a5626428cee91ec1c9
1317	4	2025-04-03 10:46:00	t	f	\\xc30d040703026b5025d841e8af0162d23701397273f6cf353b90ba86f69bb46fa70414aedb4101d59a6f3a8b4129558edf3868c7394c1204384f8eeb07f3007c98d5d623c7d37b82
1318	3	2025-04-03 10:47:00	t	f	\\xc30d0407030237228b0f6ef246aa69d23601dc98bf8f601e09fe11c0d7f816c2dd6f112f3c8a531d72bd082cd2691e7e36797dc2232e96898cc8cb404847645cbae6d3a05396ff
1319	4	2025-04-03 10:47:00	t	f	\\xc30d04070302dd10a9925f6a6d786ad23701c85cbcd600183347a75f202225684a8387add5eaecbfe2fc8a67fb170476c151de3452c074d2156dde690411d31075351cd9dd859736
1320	3	2025-04-03 10:48:00	t	f	\\xc30d04070302c22206a31d9d41887ad23601ae7a18b0ca09d2460f94c6ab91aec7d64cce4073319254595de8a10ed6a3a3f861ea8ad8d191a2cc30200327f0b6e5db1eb4fb38ff
1321	4	2025-04-03 10:48:00	t	f	\\xc30d04070302a1db2981b17e10ab7cd237015032e57230d58bebedde8c22cca8fe03a6164958eb5090329f0e41bd4cae3e71f60bba700bb7e84d298144211347dfd8983986dae6ad
1322	3	2025-04-03 10:49:00	t	f	\\xc30d04070302b69bee23e3631b1e6cd236012d9b1726358289222b55cc5a29c43d50036834ef484a0fd623dba80b8e58881d2f374c6fd48ae407729dcc94d85e156db86232cb4f
1323	4	2025-04-03 10:49:00	t	f	\\xc30d04070302145a840c6befb1f967d237019e985ae2afbd0c51db287a4f04d7520af0357cd9eed16bcff9662361949d3d6293d77310d43e8b51d7fea39f7e717b8468c218debf4a
1324	3	2025-04-03 10:50:00	t	f	\\xc30d040703025f346f8dec6d8c9061d2360165b652e6e5a0ccf701dfdd88bdfc5230d057657d05d1dd985a4e4bfa803979c6ba073d25fecdddb40e8f9b74daf3745794cf3f2545
1325	4	2025-04-03 10:50:00	t	f	\\xc30d04070302c2a73f77468524aa7ad23701ae70ab346f7f83de46a681b35673bed08654b83dd4108f2a58de36285025b0bc41e2b710a811918660c85f52e230d1a57172c2465eff
1326	3	2025-04-03 10:51:00	t	f	\\xc30d04070302d0a1c75ac010d51061d23601736a7aa7ff9254408a508f06f325f60924af01ad6d397e2f3d4a9b4bfa81a78dfad64c1f19ecf4f46664fb0b3ae7e961b7e573df0b
1327	4	2025-04-03 10:51:00	t	f	\\xc30d04070302e3fc3865a8779ed577d2370173ff6491e2dd6e75ebd1902a8f9bdf5a591b0ec170e2259577b978d1b4095309ca9048ad143e690e31df7723897edca37bd727df8094
1328	3	2025-04-03 10:52:00	t	f	\\xc30d04070302bf1e32bbd958799678d23601c31b75b74a7b11e9619539ebd3750222c0c6502517fe3407483ee249769dfd4631bd6f690f2008cc3080eda762c3471937d0cf7185
1329	4	2025-04-03 10:52:00	t	f	\\xc30d0407030242feb163de2a4b5d7ad237014d02e63dff91ba34585b8b014c3092c77dea0fade25838dd9d147928338c7dd1caef236f8926f3064a5ef165b46fd57182d9a4f99c39
1330	3	2025-04-03 10:53:00	t	f	\\xc30d040703023e787a9b58b307816fd236018f7cf4bc7c665b17a077e3b205969f286100130cda2da26cb52ac152c953c1f5bba59a2c121929a8fa8c41b18ee74708968d6fa54e
1331	4	2025-04-03 10:53:00	t	f	\\xc30d040703021dc003cb4fd2d17f76d23701c93b26383438670ffe801c6364ff250cef2ce24d337c1c476875308014e6729d3d11d3b51c2fcbac0bca74d3e671d600dab32cbea65d
1332	3	2025-04-03 10:54:00	t	f	\\xc30d04070302e7d090b389022d466dd23601ba55448701b3fa2528a4a444175830fa0eb7912d629bd769e7452513f2a996bc62706c24f1f20e224323bd8c1c4d6370e4fd2ba5ad
1333	4	2025-04-03 10:54:00	t	f	\\xc30d04070302b3ade5dc86843fed68d236013a8588c8ad06ca8770ad39c6eb0ecc7ddd3ed90ca7df9c89c00470e55b856374a2c107014fbee6b3797c2403159dd43850d1e0f297
1334	3	2025-04-03 10:55:00	t	f	\\xc30d0407030207cd375c5123f66e77d23501b6383ac8895662a578977f4c58092ce454341d7129ad7df1c7ac3f7b630b87eb4f2422bd2e32ea99741dbe65eca5feb1a0c32887
1335	4	2025-04-03 10:55:00	t	f	\\xc30d04070302d5dde6714a3d10f567d23701bbe705a58e856f867b6f1de3ffa868aa7966e13e587ffdd658f9210cdc7078d29f9ab71df5c5312ea389c0155ee4c8fcd33c03564ef8
1336	3	2025-04-03 10:56:00	t	f	\\xc30d0407030283225b301b73423d71d2360131d56eeef68f22469c56d92b30be8fcb32194707d90c8cfa33d1639eaf4c0f3cc30e4d7100ea8d4631c067da777cc4f423667b2991
1337	4	2025-04-03 10:56:00	t	f	\\xc30d04070302ad3d3c7ca68b78cc69d236011e63b4074f9a6358e49190d2252f457a38b8fa2a731b8f64f62c1dce06789b5ae8a76021ff6afe3b79872076e56abbe2551e73897f
1338	3	2025-04-03 10:57:00	t	f	\\xc30d04070302400de8fe01bf92d165d23501c15f66d12ba85bd59443cc00892ab106f7df5d31c5dbc979484b33556617eba47e426a16a4c420bc488a345d0ec92c4f549ec34e
1339	4	2025-04-03 10:57:00	t	f	\\xc30d04070302d14d1186a78b5e2b67d23601bba907e800a6cf6d29995565efa9c96de336f59104f84118c3de794ead1a7ce2184fad9f142534a6cad891d5a793a44eb28ac71eff
1340	3	2025-04-03 10:58:00	t	f	\\xc30d0407030295fef7b1a56381ff78d23601e8053dc66cf1f633af1e097086f82c34e3d656a960e2c6531ebf9272bddfec9d1a33b78337f5c5902d40213910106c30b6026872e7
1341	4	2025-04-03 10:58:00	t	f	\\xc30d04070302cd01838d4f35ce9c7fd236010138a1e62fec6df1414da4297260ac17a36b71cfd83d3306cbd4b2f650d49bdc9489256175dabd798297372e5bd7b54a8b6e845b58
1342	3	2025-04-03 10:59:00	t	f	\\xc30d04070302aca96cec5e75bd3671d236010b0b28fbb16c0a8014482801501f9e530080e376175bd29cb53adfdcefacb1c3a3e4ee8924dfbaed086e1e54e4f793a76f95a09afa
1343	4	2025-04-03 10:59:00	t	f	\\xc30d040703028970a337dc2ff6737dd23701572e08ea406cdca35d1046f587c22e27db0b21eff709ce47f8ac7cf421569947350e4fa6d88b4b5175870cb78b7a44cb5eadb5f95d72
1344	3	2025-04-03 11:00:00	t	f	\\xc30d0407030244bf09a0fcb070f86fd236016a406dc56dbe191dc84381fa4935f00d7ee02ec6e912767159036c78659c117ddfc491cef675d0d73396fde87e71afc19173821d4b
1345	4	2025-04-03 11:00:00	t	f	\\xc30d04070302d72cfa1cb529421365d2350176f2d8daac9f360eb18e03b62fee3fdcef10f0648be3a73497f2effeee39a99276fd3614c3963a8dacd22feaeb492d14a1dd422d
1346	3	2025-04-03 11:01:00	t	f	\\xc30d040703026cd6070be61d6dba79d2360182b3db3b519ae4e259a557591aae47f9043e7eb3f1c8de3300e321e7666b194373f44307f88a6e85353bb8ec1f665f8afd07e1950b
1347	4	2025-04-03 11:01:00	t	f	\\xc30d040703027a879976d1a86fcd65d23701e6bc997566af794043748a7c869ba1d0b71ab97162eed8d70e329ecb0f10e5fca9e490b6823858e39add3c9a25a19b2c7cebb4dcb6d2
1348	3	2025-04-03 11:02:00	t	f	\\xc30d04070302495a39cd4f597c9e60d2350174acc2ca8186c5726fca5190144d347dcee35ecdc45a4745d897e2130459b22b08ce11487517ab4f5cdd99cdaeddb4f0371fc795
1349	4	2025-04-03 11:02:00	t	f	\\xc30d040703028a3ddfde4f8058837ad23701c6546f82b4cc701740f04929d914fad73953fc0206c3a03d19daf4176a5503ee8a463a9f17a5db29fa01c82cf46a12cc83ec5b2335e2
1350	3	2025-04-03 11:03:00	t	f	\\xc30d04070302e08e6799014d853d63d235018c621c31f07253c000ab2fe568939b6a88ed960960680cd4f55dcdb7a164302a086ec4e54fcf6c4387f54b8b4e9fc2092a387ce7
1351	4	2025-04-03 11:03:00	t	f	\\xc30d040703020ca5e4560941807768d23701b6a547c09fa83789f604507f79ed71b7177fc358a8c2560b8e357532967e4eeee243ad978b0be7255772fdedd6796ce1534d8e1cad2e
1352	3	2025-04-03 11:04:00	t	f	\\xc30d040703023ac99503d903bb7769d236017b2f964c02a38982fe174bc7fc4305c0be5654d694cec995fa3bdcde413fcef77c96c5d6587bbd7b02eec38964509983ee5efbdc36
1353	4	2025-04-03 11:04:00	t	f	\\xc30d040703020352e0a6a1d85ada7bd23701038887e5dbd5f8e8d511ff8f52a7badfcfde1ea39f6564bb356a48c2e13060471d5d5c97f87e57f710db91322ee4dce8b988f44b1d39
1354	3	2025-04-03 11:05:00	t	f	\\xc30d040703021995522a089c291961d235017c8cc9643558a7ea045f3c350a9461fa7795c9bd58f87ff2fcd8edc7cd79f9867080d817fdeb5b666fccdfab7c21100ca3183659
1355	4	2025-04-03 11:05:00	t	f	\\xc30d04070302148e693422ee9f7f71d237017ba8e9e30fe146ca72f77d0c5c3d3b3290e12ebf16a42281b42795c52d0c452b7272083a5c9d82614df0c1693f6992d45856f2e29eda
1356	3	2025-04-03 11:06:00	t	f	\\xc30d04070302b46cb5201b02099868d2360179d7cd7dbe915845645c2125c392eb000d34e8942a74087edd3b0bc349123d8e6072df822092dd4d4ef40d3ca48523e6e3417b6386
1357	4	2025-04-03 11:06:00	t	f	\\xc30d040703029c07d4c5decaf08a6fd23701e3ed0a9b4813aef8fe80c826049af5483d4cedac076865a4918635509839d8c1c52d9fa0285f460a8cbe667f5c8df9fe2a90a3a61113
1358	3	2025-04-03 11:07:00	t	f	\\xc30d0407030240491a98c36153b96ed236019e6ffcb9a181f6ca0a73b54a776e7d6626e5c33a82bae55c176140e6dac2d7c0f38f7f4ead1436f2a0978d8b297b06eafd4b88e9c2
1359	4	2025-04-03 11:07:00	t	f	\\xc30d04070302879192803bda97da7fd237010958356e6a21cef7f268639ab4732f6c6da9b81c15cff5240c30889bbbd3e19ae57a3f71d68ce32caf6d3a57fffcea77ac49ef5843f5
1360	3	2025-04-03 11:08:00	t	f	\\xc30d04070302aeacfd557f1cc93e69d23601b853012f29c606bf81a9962e44b42525a211b60b56cb635b1cbc1662497f43b2b8748decebbc3217add332f2b1526970aa0a23ae07
1361	4	2025-04-03 11:08:00	t	f	\\xc30d04070302a7e746cf43d141f363d23701f9d7bc2b42741126e2ceaf9fe24c8eec587c01bad82ade334a10660b5c86dd393c9a4d5344f01290b8e4f323fb3010a7f3d936a1836b
1362	3	2025-04-03 11:09:00	t	f	\\xc30d04070302d3c4b2909eba5d027fd236012a7b341442a23bb6da10121fda54cee1dce3c222213cbb7eade86e47a359bbf741f2e5e05782865ecd07bdb778add72d205363af07
1363	4	2025-04-03 11:09:00	t	f	\\xc30d0407030298a46ccae899cf6d7fd237017ecec483e5a6952a576d9615801b1a3547c94f71673e8569cb89267ee2490b0fe94606be2528c27208ea2208d5b97e19e4cea4d16387
1364	3	2025-04-03 11:10:00	t	f	\\xc30d04070302b0298485a9c7ea2461d236018f93665113c9e6cef124e9bc66176ef12fe3d553e092605fba845fcb93dabc606884015b87bd66db9a722d946bd965ba1856831605
1365	4	2025-04-03 11:10:00	t	f	\\xc30d04070302131b1f3347a4f2966ad237013c941954388f04b78f2f73df279b9305049f25ac060554c8aaa04a5b015f0d605820186aa4f7df7a7e381111daff243fc387c34a49bf
1366	3	2025-04-03 11:11:00	t	f	\\xc30d04070302168b9a4566b1315265d23601d0292fc8ad21e70cecb9309f4dcf4bc38dbc3c876a052d2db73f852ae2ef2311852f9532443ee42939421b89153433be9a3d076f83
1367	4	2025-04-03 11:11:00	t	f	\\xc30d040703029cbeb395a7dc85fa7ed23701db376aeada6f9de608c26b8d0a210743c02446f2032209b8f235c2f7dfdeab5ec1dcf50862630e3e63f33bd7e0239c206a4e67b25dad
1368	3	2025-04-03 11:12:00	t	f	\\xc30d04070302b17e85a55025e8257cd2360139d92f32eaa8f393c563c3092888ac913d1129a3c79045e1176d8a600262c4230959e4a1429b91a1024f6be48998c86908cb9a5a94
1369	4	2025-04-03 11:12:00	t	f	\\xc30d040703020aa916c741718e8f7cd23701156c743b4ceb126c39693479ef883cc5983e6bec97285c76fdb9ad93964d6945341fc75a4beaa86e6883c5aaa052357e700133fa3725
1370	3	2025-04-03 11:13:00	t	f	\\xc30d04070302528b8012374f7c5e60d2360197ad3384f6b222d02ef3bb66bf2bd8c2b50a12d01b995f39ce17632c898bcd50653c9a616d9183afa470e3e94c5a517c01e808983e
1371	4	2025-04-03 11:13:00	t	f	\\xc30d0407030240b0500806e1493d6bd23701589897166a89d82279baab372fbdd2268c1efeff5704520c323ef0981a8e7a77a5b916c3b11a1c65bd07e274e55027cf4b83375b5b3b
1372	3	2025-04-03 11:14:00	t	f	\\xc30d040703021c195a743899007871d23601ec1cdcc5c67f619b66c730243febb90a3c75b3ec4e0fc565e99c815f5ff71922fff9d537720d145e08c93b101ff31b2f9713bbaba6
1373	4	2025-04-03 11:14:00	t	f	\\xc30d04070302d6e6350a55338cb966d2370175df36eaf60fed7722d1580697068a92188e3259a7a53ec49db9bc40ed6d085fb92d54176c7190b0f035a6f150f619c4ad469b4a4102
1374	3	2025-04-03 11:15:00	t	f	\\xc30d0407030243331176ce535d9071d23601da52457b491b66bc65a916691762c2cd4544159e171303d497464ce26a1bd1b514b51043fce5c781b14b9d2b282050bf12a94cc4e1
1375	4	2025-04-03 11:15:00	t	f	\\xc30d04070302c17d4c384e5b83536ed237019eb4cb8c4133530726edb57d1a33cb6791ce7f1671076e439fe350b1bad336bca56b4cde4a51f243c381cd59d5897106895093af9320
1376	3	2025-04-03 11:16:00	t	f	\\xc30d04070302ce9c0eb61df68e7e6bd2360128884cc0fb6b034c086864d376fac5cbe0ab3444f24000720fb89e3bae6fc3783b419709644bcd23d1bab140e142509894ac81a1f3
1377	4	2025-04-03 11:16:00	t	f	\\xc30d040703022d12425f4e66afde74d23701903d671a863c55fa1d31fb0f5686d7cbdcc84000ea1d5f3635de23cb8dd2a8ea2b45b8780a232c81b2cd26a438012c1d95a82d73338e
1378	3	2025-04-03 11:17:00	t	f	\\xc30d04070302993c5605684caf2b66d23501327daa7a87ae142f77901c3d0b377ff41d654d10d1e285865f3658fc752ef0cbbbdc2ff5e05717ac78827f4a67450d3461a627c3
1379	4	2025-04-03 11:17:00	t	f	\\xc30d0407030262884933d161ff0663d2360108fe55c1749dee3ffe2b9750b6beca0758672edf55975a6117f380eaddc4255f8c432a3df24e7b90394ea531a472c331a8d7e4faf3
1380	3	2025-04-03 11:18:00	t	f	\\xc30d040703021e37f4dbb0a6917f62d23601c155477bb413350466b59ac4ae37fab54c9a280bd6d167e217823d003f8ed5a824c3a9f31067576d88fed1506ac7c4b02b3311475d
1381	4	2025-04-03 11:18:00	t	f	\\xc30d04070302828d009ac2aaa72f67d237014a32a6a428524dec0cf2365475fdfe9e004b49f69857d0b045f0d87c6c07dd328ed0052bc4faca664445fe73f06b2c4105815e6b0e2d
1382	3	2025-04-03 11:19:00	t	f	\\xc30d04070302fa810b26fe61085f70d23601305f14e013a0591e4dc4d706d9b009c0053d5edf4b06525a9934161b9a0cc874fa1c0902070933bf88275bf5e0aa173a50b40e2417
1383	4	2025-04-03 11:19:00	t	f	\\xc30d04070302da966834ff37d60469d23601b6f8a87b402cb41521cf07655347b22d915459e3ab7cc8f4dd62479889764012d2f008b458a1fe940ce2cf6c032fc6ce3e9dd06e45
1384	3	2025-04-03 11:20:00	t	f	\\xc30d0407030279d9db9b2c5d9a4a72d2360141d9707ec06e62259dee6cd2953bfef99c9e16b1d7bdce685989fb411bcbf68850adc3fe851a3f6c9f661a87758434eb081128c19e
1385	4	2025-04-03 11:20:00	t	f	\\xc30d04070302f34f290b75a37aa360d23701ef57a340689b0591a6fe3ba64c3943d21c2ccd0f6956916cf25cbc5998003e309952706069cf7c77db67bf12433366270af35022c6aa
1386	3	2025-04-03 11:21:00	t	f	\\xc30d04070302b101d4cbcc33a37862d236010a86d6d5c0d6efe8f658182608fae31868f40203be64447be2d15a0a1e99ca9cc3a0aea5bd9ff928a5540a99c2aee1ede312064a39
1387	4	2025-04-03 11:21:00	t	f	\\xc30d0407030294e2828d380b11266dd23701182f862ee3592e4d8e212a5aac3fcb8413a601e6f76f1d9eea5f30baa81129b7cb1a0c2d9ede77d9e2aa67594b18d81c4e40947cfcc1
1388	3	2025-04-03 11:22:00	t	f	\\xc30d040703025b9a6c204f39d8f970d23601ce414369e00d2a6f6654e195813dc02523b8049480a4adb814cbc5ed5363672b210d3a51f99aa47fc59fde4ffc0c8b7c6c86aff719
1389	4	2025-04-03 11:22:00	t	f	\\xc30d04070302ee0dccad115c35047ed237013a1302c16f0b5208fbeb3db8e1406b8a08072b7da2bf47d33224f222d3a0fc6c35755c2a16e7a365e67a174dc9e174313320429e3db1
1390	3	2025-04-03 11:23:00	t	f	\\xc30d040703025d46d0304571e6247ad23501a194c42e8797c34b51ea668fd756f5fa5def02d3a0422f23f7a7b84faa91717dcefae54b2486f0a82e009f3ebbf2e8c563c90b45
1391	4	2025-04-03 11:23:00	t	f	\\xc30d04070302d048f4b31bf7581c68d23701fa662fb14b87b715c56731456eef4a4fc2e15eda53c100715ac2a81054d4830cf0ad649aefb9acc88b70a85664a369ab71413f0930d7
1392	3	2025-04-03 11:24:00	t	f	\\xc30d040703021351e88047f9bbeb7bd23601358845a7eca1d24b7065bd845133df61196f80625aa70301f3546a7c91687c618118a247e38617dc762f74bb22de879f182c2cfe14
1393	4	2025-04-03 11:24:00	t	f	\\xc30d04070302dcb9965ecb107f4863d236015c1beaf22345121b395c7d841ea43ebb07f02674ae914a361c67be4ef828e6cbee6287372a394548c91168eb5e1563239a514ec2a3
1394	3	2025-04-03 11:25:00	t	f	\\xc30d040703020f49fd73449d27e260d23601f7d531e9df7d365e9ad28aadb5fd8f321a30dab116ff50591d0e61dbf531c2837ef740a6f038347e775e038e057c038412013d213b
1395	4	2025-04-03 11:25:00	t	f	\\xc30d04070302c3fc8c3817e421187fd23701d9154cb4cf6905e1dc2270558b09bf7ea3dc7002e3ffdfbafa997195fa46db5317c5ac152c4f16daef938cfd02f8a68b4d81bea5439a
1396	3	2025-04-03 11:26:00	t	f	\\xc30d0407030295fae2719e85825074d23501d50e8c9c7083f78e75006639c63c00a61a7470dbd9a1ec8b4d5e75405461e360881f4cda979cb48fd7916b146c4111ca72bfc397
1397	4	2025-04-03 11:26:00	t	f	\\xc30d04070302cafea316b18fb2bd76d236016cfd1f6579b89749958f1048237e555ce41e62fae040ae562018259fd270ce017a68039968c49336eb13895d5c55510046f1485942
1398	3	2025-04-03 11:27:00	t	f	\\xc30d04070302e8d266d2ab24f2f273d23601755e769c9244261841b6594f5ab371b3c0715a3a1c123cb5c308458a3aa6294ffd4d646aeccfd524c6e5aea259395411c06c224334
1399	4	2025-04-03 11:27:00	t	f	\\xc30d04070302c713e0d177efd39a70d23601c1492baaef831fc73a00725dd1ae4bd8dff915e1578897416b95a24bf841f46932fa70a232c4744c4dfc6c4d935d5c5faa0f3330ac
1400	3	2025-04-03 11:28:00	t	f	\\xc30d0407030251258f687d1bf93a7ed23601761dd5aff38b00956a4ea58fd70d25a189f90603f701dfe36a4b415f0552869970d68e26e5e07f284da2b359a5734e59354ff51962
1401	4	2025-04-03 11:28:00	t	f	\\xc30d040703023c094a07c72b20736ad23701ecdeb104789f4cb9d463dbec9f9c803569d0d03c8d2315de39b76b83c93c4c073b85088b3d19c395d743b7c51c0a9b7bc0dd46352875
1402	3	2025-04-03 11:29:00	t	f	\\xc30d04070302d958a1a223411bf967d23501a7cf4f7ff90b35b13541c9d7b2b3a1705b8d0f204f97e8b1735cae6f41701612306aa3fb7e1f69d70835f82939cb32f0f46d98c2
1403	4	2025-04-03 11:29:00	t	f	\\xc30d040703023bc9ff8c1d5fc3f37fd237012732bbb8378204b3e97b09961105de184cecf8c740467c52b8d529be43f63f8948c9431496ee3e7f002f3c0790fad86a32277861bbf5
1404	3	2025-04-03 11:30:00	t	f	\\xc30d04070302954e8b99dd88bdfd7dd2360152dbf8e444ea77aa1138dc47ab0f4fc48e1c2e420a820af54b450cc12a470e20c5adc2504d86c44e5f5f75c5d8d13c22b40b987036
1405	4	2025-04-03 11:30:00	t	f	\\xc30d0407030287aefa62897e69486bd23701c79160e04b5230f75467310687ff583d5e8b3f6d8d006d9f5f5430847699f777fc45c85a0c189f7f4e46b862f398f03ef98aed148cd8
1406	3	2025-04-03 11:31:00	t	f	\\xc30d04070302d103de50e7cd8a9161d236018df70990b262c938805ba023c1f72c0e0dffaf89b423fa02d185f506df0ebf49859bb7ca3b6bde12bd3671870192613879c4bf78ed
1407	4	2025-04-03 11:31:00	t	f	\\xc30d0407030237e74196e760c97b6ed23601f56fbab10fb74967deeadb50d8adcbc8e79f0fd44ebf290fc5c47108e356a09302b13e3c4ec7ec6b36688662702580d19d16a8ef33
1408	3	2025-04-03 11:32:00	t	f	\\xc30d040703029ff9c76eb0daefae7ed23601759b8b6159ab5ab16f778650f7f7b0ca50e9554773b361f55d1a5094650c48a0f660b8af925b569bf72b66b5d90276d2d2e8510eea
1409	4	2025-04-03 11:32:00	t	f	\\xc30d04070302883d1aed7df33e256fd237014163971b15ec4226c2e4fb1d3e61e74c30b0bdb1fa173cd0fd706083f34b656a63a6bcdbcf16f87ee52ae3aee206881a21ae5915cbc9
1410	3	2025-04-03 11:33:00	t	f	\\xc30d0407030255aed9a3e9b9701e70d23601e2330f0c1066d13c4110b0e06cdb0d5e93061b23c136c8eeaaa9d6abfa50f017b6910d307e50d515ae86bb266aad0b3dc22f8564f1
1411	4	2025-04-03 11:33:00	t	f	\\xc30d0407030230d113606d2d320973d2360151001cad2cee98d110d6625de5f0d1cf122b6b236bf26929c29e7a3d04df82553a31b321fca7445709a915fd485021e84c295a89bd
1412	3	2025-04-03 11:34:00	t	f	\\xc30d040703022b12aff00229b9e66cd23601c946be7d5ed75bd97bb3aff9810f0f9a4c286db1f448a33bfb857ce367f0b7366ed90f410830da940ee1209581034db0cf3b729b39
1413	4	2025-04-03 11:34:00	t	f	\\xc30d04070302b7a459301d214daf69d237019e6e472e7ecde99616f4c61e9ea61681c16c02f3d726d879bbaf721991d1d31bbebf46f7c8a1203e2b225504f8672f5b7aca3169a173
1414	3	2025-04-03 11:35:00	t	f	\\xc30d040703029cf6c83ef4cfddca6dd23501655cc3377124bd43cd54610c8793debf9ce6d76221aefb0b19987951bf5f94489c122e1f479ec392954dd60231b79928c6784fc1
1415	4	2025-04-03 11:35:00	t	f	\\xc30d0407030202505e0a03f05bad76d236018f9956a403c8d0efdc671e6198085f9fbcaa661ae621c43e2be0767a019e11ac4e440016e1b47354ffe8ec3836e5f8e649f84a45d4
1416	3	2025-04-03 11:36:00	t	f	\\xc30d04070302dc64729fff0030e87bd2360106cf4f9ba9ee34cc919eaed8b83065139df933959d2de88ba2939f55c42fa47b4da5ed013fcdb3f072d822503ae3ddc2dae2c07eef
1417	4	2025-04-03 11:36:00	t	f	\\xc30d0407030261252d81903d228871d237012462466e1f77a3a3d8a8be98216e647970dba9bc8405a28e89c340294e813106981189ebcfdad7a74533fac63f02169702c66a629d4b
1418	3	2025-04-03 11:37:00	t	f	\\xc30d0407030270bd302c38c20d9873d23601194d4bc7dece20fd632cce9a8a71c662234c764c23763370f3266008693725656b88db0e43ed0c108b952e4ab3fa4d4135d2dd15ce
1419	4	2025-04-03 11:37:00	t	f	\\xc30d0407030243d3f7776976962068d2370120669be61406835c4743ec7b57597977d6391b47e10a74dd4c7d2fab72128f0f672e2cdb2e92af49e014425d4bdae529accc9399c23f
1420	3	2025-04-03 11:38:00	t	f	\\xc30d04070302e2258d270163b7ea62d2360186858a90663d9c55c615b0bb5edf4358d387f7f59516ec815f40b048ef4fc9b4b0e9ecf32c5e2a8b93d9ecdcda8c5d54fa3edb94f1
1421	4	2025-04-03 11:38:00	t	f	\\xc30d0407030277991b445005cf4f6ad23601fde57751e05017e5f7cfe6d3775308a4cfeab46b10a808f22338ff519f334a0645e69ea231e4670be5f5504841c18f20ebab5fcdbb
1422	3	2025-04-03 11:39:00	t	f	\\xc30d040703026e6d2d09b4a7e09c73d2360173ec00c73a4d3b6a6d247d1344f29f41449c4bd71c8dc806a9c61c6d825776515706542642fd047482673a2f6587f870e22dd6fdc6
1423	4	2025-04-03 11:39:00	t	f	\\xc30d04070302b663372f2518de1878d23701cf337c6cfacb5eaade2de6083334e6ba705964ac9bec15de990c9e4c096a482a6c0f7f616c8937cae39f037b806e4e3caeff4490dd01
1424	3	2025-04-03 11:40:00	t	f	\\xc30d040703028782cbe32f7936bd6bd23501a00f5648d4a9c89973c5f08dc4f54959e09801ef15907845920eaaf41986575a70620bd3edeae161818a5dcadf238caa8c0d53bb
1425	4	2025-04-03 11:40:00	t	f	\\xc30d04070302ddd2553b315746257ed23701266a91d28904c1beb137fb37a9176bd937a26e1854890fa21637eef6869cc1a9a8533f3e018b66879d601bdcdd2847df05d8fde7ad8f
1426	3	2025-04-03 11:41:00	t	f	\\xc30d04070302614293ed66e335f47cd236017d6ff9dee8e1553d2fa4c9a67f24ec0ecbe040b702d1bd796daa6c886167ede18042f27033a21cc54051a4d432d27880bbd1055c3d
1427	4	2025-04-03 11:41:00	t	f	\\xc30d04070302aac671d1c4785ea56dd23701c8ee2b9b49624315e32afe06174552d2576469a1370977e3e357e3a81bfb09509cb5851d24a0230012702cf534b580e69c24e885e1b9
1428	3	2025-04-03 11:42:00	t	f	\\xc30d040703024cc5bd584aec9a907bd23501feff0c90122c2a6f8d665622de56a2b6142552c197531b4178ae90ea4eab74014e130b9954044327c458c482fe58d34e2bd28e3f
1429	4	2025-04-03 11:42:00	t	f	\\xc30d04070302da364c30ac4413896ad23701ef2cc319846fb0057d597e0857cbe8d6b3902010d325fdf699eb00f38a508e2099dad4f5cadf9129e7bd53733f1d48d028e948a32b70
1430	3	2025-04-03 11:43:00	t	f	\\xc30d0407030209b089522a594afa76d23601d108d0ed4d58c9017e5e319d483758ef24baa2546b564ed62da85d8fb22281acfd5499dd33da0b751904ffe85c11801f935122c450
1431	4	2025-04-03 11:43:00	t	f	\\xc30d04070302968bbb024a9eb40f60d23501e7d019bcb837063a3b704275b84f20076954dc319a651e41ade0831f6b52fb97c3a1339c03032904b9069d30bacba471958d96e0
1432	3	2025-04-03 11:44:00	t	f	\\xc30d040703028fa4076df33440ea69d23601d0b9f269b256f4bde49a210ed3baf5c4ae9847d97ba4d7f5106664d42ca5e3d5680182a28284142164975bc9b6a121f0fe4a3542ff
1433	4	2025-04-03 11:44:00	t	f	\\xc30d04070302229aef04967326ad63d236018068a62d29689bdfc3a851af276ac75c1c1e5a8d7c98f463581425041ff549d1ba987878cd7bba00f8c36ee36ef57d1a7ef4e63d13
1434	3	2025-04-03 11:45:00	t	f	\\xc30d04070302488ff463c681ca2c60d23501f5170ffe252a153d89eacc9061f769f41be490506154601fbfdb0e1b964d299a1617090162851f0afb90dadebd2b42afafdcc08c
1435	4	2025-04-03 11:45:00	t	f	\\xc30d04070302ca97be41edf236d574d237017b43d43b6ee042a134419718672689b25ca552c224ea4f687d19329496e7b22e9597031f8bd3fe6029f1988b9c978303ad2031a70017
1436	3	2025-04-03 11:46:00	t	f	\\xc30d0407030200acfad0a7ba05077dd236011712d44d3235727f7baa9d7530830486f2f98d1d238affe6c8e97c6804a675c1b2f35b9cd18e4b5a702981fc117a9ca9236a909a54
1437	4	2025-04-03 11:46:00	t	f	\\xc30d04070302ee3fea2a2f7aaaea72d236016b412cb156a0ae31fff4734f92af1c2cc3e3b87d8dc746753be6a3241d6e9f490b51d8fdea35cee62cafd90e57e2f45815a7a08779
1438	3	2025-04-03 11:47:00	t	f	\\xc30d04070302ec9f4f609f3477ad72d236016c4f653eaaa0e0ee071b5d81970b49c6882ebf32ab3f00ab816f85d535d75695f867ef92e697b871b8677d24ccd9d8b50af3e21b30
1439	4	2025-04-03 11:47:00	t	f	\\xc30d0407030247fdce76ab288fcc60d23701d9f8c033f6c907b0c1eebf9482f9a020732446bc24d1d6fdd50cc4a679d040504653e06d89f0f6f4a37ac46fd904e5c553d9c116f2a0
1440	3	2025-04-03 11:48:00	t	f	\\xc30d04070302e4fa6983241d28787ad23501f433b4a7705637037073d4b5d0bdf21f810bddfcd0a253e1bf45a89bcda21d99e2ee4a2daf0684890d7d752c90aa007edd17a258
1441	4	2025-04-03 11:48:00	t	f	\\xc30d04070302b6d0670eebbd8f7e7fd237019e13659583948c24b17d9b228c77780515615da4c6da84557bd16cc7ec67deb82298ff147270e642053eb5092be18c137ea476b2e9f9
1442	3	2025-04-03 11:49:00	t	f	\\xc30d0407030214f29bf4c03285c066d235019894b892b63e235aa8998340937dd566330d856d75a96acc2a7a7f0b83d67515727573037fcc1cde33ee17d4d38263dabf567b1d
1443	4	2025-04-03 11:49:00	t	f	\\xc30d0407030243c35d4f9a92399378d237019cf9a33f690d2072070ed1dffba781e2ef239039afc4d3d762949e3a92bc0142aafb2a414c351991fd56f810cbd39aeead99e7f198c7
1444	3	2025-04-03 11:50:00	t	f	\\xc30d0407030236f62809236fb4876cd2360172b374ebece227d0897e7c06f06c14f5c018b8a34ea6dc216e77eebb5dd9f8a5e942099afb1286610ab47122577d8961a5807cf376
1445	4	2025-04-03 11:50:00	t	f	\\xc30d04070302a809f3c40f7f001f6ad23701c68c25b825314456060f3ab4817a8649dd4941ecc0c363d2dce88425222cff2a76713f59a817bbe769611b428fc4d39a0494e001e778
1446	3	2025-04-03 11:51:00	t	f	\\xc30d04070302b7da46d2cb9e85aa64d236015652644dcafb3d89420b56d4792f91805a369c3d693781eec09a7c58d6ea5692811bc226071cb0f449cc6bc6ab3e5219d7540fe052
1447	4	2025-04-03 11:51:00	t	f	\\xc30d04070302f7e33b57e705898164d237010fee46f0716f4d3606c9279973035827f8e80487a36efc66e4ea3cb3a27e866766e96c42867cab943be9c27928e64c8969cbb631fe06
1448	3	2025-04-03 11:52:00	t	f	\\xc30d04070302bac030c9338c97026ed236017a8234d0740325447c8053fd5766640189c3462eb7d72232580052998659092364de559994a2ee302676bebbee73b1ca663eab9fbc
1449	4	2025-04-03 11:52:00	t	f	\\xc30d04070302a31083f0cb1efa1e67d23701bf7c8f42e6d1bbec93804624a599f61590565435ae6f6cc2b65720cbe7dd3d985113c456e21c9d12871a2e2aa8a6034a4d2e04af709c
1450	3	2025-04-03 11:53:00	t	f	\\xc30d0407030208d463a0aba3cbc971d236017936b6c9a5007aeaaa9b6aecf1ba4bd0744dbf200f7a77da71786ebbafc0914293f276c5082d82983b76820de1541eb3928debfb19
1451	4	2025-04-03 11:53:00	t	f	\\xc30d0407030242a3a129a1aeb4bf69d23601bd449b86874b3a5c3109cd3a32ed3fee19feb5ff3902f9f0aa8ed42e34111042888d7becfdf86b142c21ffd513d0fd4705cce69436
1452	3	2025-04-03 11:54:00	t	f	\\xc30d04070302d39690cef8839c6e7fd235012855f482b2c5802f7710fe5936490524eb5207ed6f1759585a545d37591ecb87c928db967ba0b3431b278ce893c4d6c018454e07
1453	4	2025-04-03 11:54:00	t	f	\\xc30d0407030258e152e74f8edea17fd2370187ee3f10f0f4e73e6c8607b292b8f37a10d456cecc51186bf73f2c801668a766352d09f79951489b409587cc5ec3c238ff37acf28db7
1454	3	2025-04-03 11:55:00	t	f	\\xc30d040703027f5f4821b5737d716cd23601e89a28d9d059a18baf9fed1e674f38f2440cc433b74d592ef20c042253e85d2e6beb6ffc13afce7957187c79dc105b8ad242368fe5
1455	4	2025-04-03 11:55:00	t	f	\\xc30d040703027c757b7d11bc15f261d2370120ec3d044f781c4e2c5b906344ef87b4c02da15abb12609181570f1bba995bc8215e3d8fe6b16fb2d888d39c3ddb802fb1b47c05e51e
1456	3	2025-04-03 11:56:00	t	f	\\xc30d040703026ed1f9d6132b681274d23601cdd16eef49485a3fa78a2b1870cfe3e51ba0392e99a58344140be6bcfab7f6fa264f7d30512cdc9d6971f7b6e1a1c0589e5ae2cd01
1457	4	2025-04-03 11:56:00	t	f	\\xc30d04070302652871d503d3349861d23701fa66df735332ce807179329af2b1e235ea7d9d3e5d956d8ae7f6ce75b0a000dc9a95a43d39beefa2116d8c679e638418dcd198315112
1458	3	2025-04-03 11:57:00	t	f	\\xc30d0407030249963ae837a4c1fe60d236013a60e41fb4197be4210ae731ad4d7d9943d88acca8190cd8f93bb9259c9fb8b7a233bfc5af2a40ddc5556877067c9bb2e67026b5c3
1459	4	2025-04-03 11:57:00	t	f	\\xc30d04070302c98168a0b5fbde6a63d23701169d832ec08e07347c0dcf822bb3158f2aadc13763ea497f6911339acf1d97d51b1ad57dde98078acea81f737cc06c33e56ce89644bf
1460	3	2025-04-03 11:58:00	t	f	\\xc30d0407030223c0df49d92b28f862d235012a4bc9fd30fa341b6ce829834c5f7ed06ba3f06e2f73f8db4763ad3e0b962100774c63f0864f05d3f3a16c94ade7076d8f254c72
1461	4	2025-04-03 11:58:00	t	f	\\xc30d040703025d20d0a4ec0847ce6cd23701647d8f62c79cebce4c3ad9722ee55cb9ae050bae7bfee9388e27bf7efe010146199536f5d3db15994125c49b5c4296aee953766c9b77
1462	3	2025-04-03 11:59:00	t	f	\\xc30d04070302e9dcfc03ed8fd7e16ad236016c98b2f00b42ee12f6005e8abb2159f268437a9c60bd2b87f6991b8773d4ebfe4fe4f7828a235cefc0ba5517e06e571ad9b58fbd47
1463	4	2025-04-03 11:59:00	t	f	\\xc30d04070302b1ee67f23942899a73d2360134ef82f464374efc7b9b6a39db06c4bd1681a495c7b3140934e4469d36e4bc0af6d7fd0dd8dedc619da16a1bcddfac5bbb9e01a399
1464	3	2025-04-03 12:00:00	t	f	\\xc30d040703024d66efbdd59f1c7f6fd23601061bead9e8633c74c8073722fd312b030d30ac36dc501a48e93bfc7f10fb8b935185360c7b992d8a89f31e5450b8410b44e6afb09d
1465	4	2025-04-03 12:00:00	t	f	\\xc30d04070302c36eb25777720bf964d23701bbae7661c73ab1db48763a78cddeb42c8572a3bf6bb82743e4676d07d892cfecd50069dabc3db59fc1e67b8841ecb5a8bf732547c842
1466	3	2025-04-03 12:01:00	t	f	\\xc30d04070302c9f43b370bc6cd2d79d236017dbe3724b62dd4420aeed8c1723ff4be656ed028787fd9cc576f921e711c5170584a4c266434a151d5e229fdb782f522cffa112e65
1467	4	2025-04-03 12:01:00	t	f	\\xc30d040703028dd8598b98873f6776d237014fc02a1cecf3f9d895d00b7ea8003b0cef75366abd40e5d382cd005a8fa842bb0501cb8506a1eb4a5f9e937c4980a4ad546efc7ca618
1468	3	2025-04-03 12:02:00	t	f	\\xc30d040703024d81f7d0fd0227ef70d23601496a130067cc172ba699eb81b48824afd02a0648be92792e6b82729cb7b579577ad62c4c283f20802d6811492bab6644e5cd352f30
1469	4	2025-04-03 12:02:00	t	f	\\xc30d040703020b2884c606f490a87ed2360193d9d07ddc5d0dcfe3e3acaa131733062ef585ba98adfae5ca2df31051de33f7e3f8abf6a4131cbedf7e573fa88f561468eb415f1a
1470	3	2025-04-03 12:03:00	t	f	\\xc30d04070302a7ca19f3ec1d47247fd236017aea74970c9cbc87997367f2499b6af546bb81026fa67257dcc8996a219f069e6beb0ea4b86601b3fcdd80fd10b433a3095e1c1c80
1471	4	2025-04-03 12:03:00	t	f	\\xc30d040703022fc714ea7369bf2070d23701843568049a7c7e23273cc5084e19af16f22a3c4e60b0cca3f90cd49d67b0d8522d897b54d27d8f51c6e188c0051cff7d92fe3a8c2eea
1472	3	2025-04-03 12:04:00	t	f	\\xc30d04070302fe086454d144396e7bd23601201e81f93dcd545a63780200432ece636978cc364eebaf9ac8996bfcc8c1b0115de3a33b781b888a9f07157319d8caad9b1661afb3
1473	4	2025-04-03 12:04:00	t	f	\\xc30d04070302df300023a0f81dfe68d236014c1b6af1557b36d7d22bcee3062c76c9d6f4c081de0e3a2ff1345ad28a714f1f963152016c91465e302a8bf19276981f50d29e9c3c
1474	3	2025-04-03 12:05:00	t	f	\\xc30d0407030219d17914f8cce3e168d2350190eb1f422c9ac814eac6e4d9f6cda7d5ece4de20bb98b9c43bab47bd944f5fc5fd2d183bf2e29122baa928205932a73925a25db3
1475	4	2025-04-03 12:05:00	t	f	\\xc30d040703024c3832f9ac0512dd6bd23601ed4cb38a08b5205287851ddad00a95acc433b323428041d1d824229d864c86beff7103f052265b5a5f24b84dbc29714c16347f1a8e
1476	3	2025-04-03 12:06:00	t	f	\\xc30d0407030277a27f1f38d5da366ad23601b8852ee4e81a11174aae90a8ffe79c3c62296b76cfac87f8449826ec7e900cc2130ccd9dfb9aed1e27a89fe780f8fba4d86667d90c
1477	4	2025-04-03 12:06:00	t	f	\\xc30d04070302aa23c2393ebb784f65d23701594853211e4f9ac9fdd12abef4b51f40d953c9037768d5c5aabcb2dbb1c6ee17ef085d5462113334106211301c0424747eba69f31ae0
1478	3	2025-04-03 12:07:00	t	f	\\xc30d04070302c49c47e995581b4465d236010582c43152b7cefd2b108720ece07f57247f082463df14d31abb48769064973653ba5121ed71f9732d11d994f30e8ff5a0b3f97417
1479	4	2025-04-03 12:07:00	t	f	\\xc30d04070302a3594eed935771f56ed23701dee0db578e7cdfce04c3abef592c66456e8b0d5031ba08cab447551b62faf2c62286ac8eedb6cc4a08c197b283fe468ec2c86378a42e
1480	3	2025-04-03 12:08:00	t	f	\\xc30d04070302110822d05cebea6e63d23601af214020dbe439393a5ff37e5770d2b038fa1f59c6d883d2c1395cf6fb736a78a2425bb6e72a18f4cd5b5b57422b9e340950da3ec9
1481	4	2025-04-03 12:08:00	t	f	\\xc30d040703023bbf1350d05695556bd23701f75034fbfddcd480a796f4c73ba129b4bd76c75200eb16b290dca63c09f3be5dd8a2ca4e73ad97bb04146765084af3aaa238d3779ab0
1482	3	2025-04-03 12:09:00	t	f	\\xc30d0407030211bd0b3c6f944dd666d235010dbd0f511f0e6dd3cc40aa0f5eef262ec3a6ce5ccdb6c91c50dafb6386826587e53139bb839c80102208c8faec3287e803fbcbbf
1483	4	2025-04-03 12:09:00	t	f	\\xc30d0407030280c80e9ca8cd609e78d2370189da31fb829f0488650f04e7614a1c60fadbce64e264db30e2df94f8407f9b1d6245d6fa748a972372cfded4ec423fb47bd6283d0754
1484	3	2025-04-03 12:10:00	t	f	\\xc30d0407030272d5f20a9182f3b86bd23601f71089eeb7e2e1abee4743ce533873aeb7be5fd945c28a83f5627d89556f00f08db557062a27a2cf224938138cd8051f2da4d18c79
1485	4	2025-04-03 12:10:00	t	f	\\xc30d040703021fad50dfe9e7071465d237017de1a26b949b090017f8ab49fe299f1e4b3962caf02b552c30ffae5123650968f3a93a2fa2ac37ed444549ac1ea7f1382c90438a7d09
1486	3	2025-04-03 12:11:00	t	f	\\xc30d0407030214200894a9cd5ec06dd23601c33ca2dc376bdd8750e1029eb8d6dbc5a1436071b0824e1095e855ee76b9ea7e5be396b3b6b7b79b96e0c9426a4f9c50a35e4c0772
1487	4	2025-04-03 12:11:00	t	f	\\xc30d04070302540b8638aaa004c37bd236016fc95d38d7101b0710a0781ab9cd4e006fa6333e462d6bcae2eff5f1fb8bf090bd2fd24f41a91ee97f03fd5a5804f1d471f8330c47
1488	3	2025-04-03 12:12:00	t	f	\\xc30d04070302355ed82d0977631561d236013b301c7e32cc0eeadabef69fe2a2825bbd92b7723b79beba1d716d925b17cdba308d67c9591c46dbe49c440e7be7da505f75af3834
1489	4	2025-04-03 12:12:00	t	f	\\xc30d0407030299165e3cd2ef985d73d23701ff9699b6fbda08facd63e7145a0a7d89763e17c51806266719a0f034a034ae4a5057289ac6ef698704ec5394d14139b620ddcbf1aa42
1490	3	2025-04-03 12:13:00	t	f	\\xc30d04070302cbd1cd172d94ba5564d236019bc87215d70a1b5a176d5aaf6146802d7bb0930f7c9c9a3b193b0d01221fd3138a6ed8fe79356409677b810dc5fb62599d26929f50
1491	4	2025-04-03 12:13:00	t	f	\\xc30d040703023baaaab1285717c97fd23701587ccbf4e0bee2da2908df4a7717e66b29c5cbe2437fd1bd798e208371e4d07514b9734d01e8cfd5051680669b9e031ca5124f3d72b9
1492	3	2025-04-03 12:14:00	t	f	\\xc30d0407030269578ef049307b8863d23601f2c4a6d334c6f3d08583c5825dfc51600026babc469ddafd8a2a0593d0be34677fdbd57c976a2366fa843d736524f817709d1fceb5
1493	4	2025-04-03 12:14:00	t	f	\\xc30d040703027bcb93b4eabf34c67cd23701d7ee7b25eafc10e2818218c3c5a77c1ef84a4c27064fb2cbc8978a7aef4f5ba60e0d95f63fd77b44f37f93bee8220259bd41153d8e44
1494	3	2025-04-03 12:15:00	t	f	\\xc30d04070302832ca20ab6fbea4471d23601461c0f5dd3ba62a1830fb9db31a48c914be9b7977900f1f34c9fa722409bebbeae4fcc34e67ecd2d3b6adc70fcb6ba65e90a36b65f
1495	4	2025-04-03 12:15:00	t	f	\\xc30d04070302644dc6e5702fd9b676d23701d2e598a5b1ae3cca0719e26be2c726486293281392910142f77ca6b28dc04fdfd7da309995d28ccfed8c4665fa16e6a5667e92cf35bc
1496	3	2025-04-03 12:16:00	t	f	\\xc30d040703021e0a551d34d30a8f66d23601970acc07b586a609410e12c771a861e65c37ece85b42b8bd1df654e1412e5dad7e526af8dccc9ce772b825a91f72aa89f6a1e816c1
1497	4	2025-04-03 12:16:00	t	f	\\xc30d040703020a7edcc8a7102e5568d2370180f7fead43d9104c0284c128a81281af0ccdd6708365232024a651629e303fd43837c0873af6691b2c552553b196c6e2ca9b4ce24d66
1498	3	2025-04-03 12:17:00	t	f	\\xc30d04070302a3ef18406491e71064d236017d41346721ccf205e08b0dc7dc7ca3cc48abe906793c73d0b77dfda5d95d79f1e4240bf949a1a95d70d4b92363d2d8fe5f418b0deb
1499	4	2025-04-03 12:17:00	t	f	\\xc30d04070302045ec1f486c50b0e73d237018cc19bf1ff5732921f7b3847dce48804106cca8c627e9147742b94c399acc8ba1e327086b0512b9d2c8f70923e5515d6fc7a2de59c47
1500	3	2025-04-03 12:18:00	t	f	\\xc30d0407030258455130f55e7db46fd235011794aef107f2d35a70d0be514fbf74042b209fd786d15edb1c3e83a4109d4a744e195a2c322335fe511f8486efd2230257954e14
1501	4	2025-04-03 12:18:00	t	f	\\xc30d04070302e0009ef2e4408cb565d237014cbe4adfb8f399e86476f05450404275620783697ab92b40dd0b978e9bbfb09e5665f329784419f215a0898aa62fa8f8ee6680dcd10d
1502	3	2025-04-03 12:19:00	t	f	\\xc30d040703022439377271d3fcc079d236012e73e91fe4237090b2e33810673cb03e32ef7191760663a5bb305c990712f74827ffe77b9189064604d4ba687411208e81960063c4
1503	4	2025-04-03 12:19:00	t	f	\\xc30d04070302c61b200813b79cc679d2370164a30102fb10d477995918f33eea82cce21165331399e506510f26563c6605d5e551e06635ca18c4015b2f3b287e94cd0a83091845a4
1504	3	2025-04-03 12:20:00	t	f	\\xc30d0407030296170a79883f4ac76bd236017c3c1a6e9f867cdd5e123e48238110358eb078084579aba498984457c957e215685f34be25adc497cb25b4110297c53e9510415ff5
1505	4	2025-04-03 12:20:00	t	f	\\xc30d04070302c7fff841bd76d77360d23601d80f105005915a3a4d29d56ecf4f331edf0042bdef39df1936914780d94f94c3dc2167970567c763105e8067802429a7742328f2be
1506	3	2025-04-03 12:21:00	t	f	\\xc30d04070302aa17349f63245c6161d23601988bec70bab600afea6590a1e8f6002fd62530a25e522ba581b8299d80d829bad766cfc0c4c6d9eec20b95faafd65715175e1c2f07
1507	4	2025-04-03 12:21:00	t	f	\\xc30d04070302153b3c8bfe6c90bd7bd237010aad981a1997660dccd2285225c83b4099bbb1c2c5061aa19fa5e61a74f980c74980f77c1806fcd3cd6062d1a569ce69936928570703
1508	3	2025-04-03 12:22:00	t	f	\\xc30d040703028c45551078a161d264d23601c1080a8fe20f68189fe3cf0d91d72e5478eb2afb6cad585542e5673dd5ca0311135b9b7a9155fef771996f77fceea96ccbf9d4289e
1509	4	2025-04-03 12:22:00	t	f	\\xc30d040703023bc80c6d7a5aa4eb70d237016b1d23bff57bfdca02543fdd8237997946e4e4317db12e29cbc0b9901075eaea06821796dadd1a205e47f742f22b689bc2f28568aa27
1510	3	2025-04-03 12:23:00	t	f	\\xc30d040703020c36d3310f98dd7069d23601961cd8ade24078fba04705357e9b97edae226b2a4281547f24e2548c9684dc5bffaa9992ada67c3e842cc78aa7954cf474cde37235
1511	4	2025-04-03 12:23:00	t	f	\\xc30d040703022594b7b200ab78367ed2370187ce8487cf3e43d78996bef9f3f9d24346f112ae0773b7c7af5e2294defa8d5d34d4c9a992dcf678e68a7573d4a5889b3ff11773bdf5
1512	3	2025-04-03 12:24:00	t	f	\\xc30d040703027412a7bec88185256bd235015725184a21946a859b804e0182863e939bb7674b2b317a0f8ffc2f72bc08ad024db476b92d779d1e4be4f2f86d72f6f0ec89b034
1513	4	2025-04-03 12:24:00	t	f	\\xc30d0407030226a6be9258ac0bc672d23701e15513f3500d2db70171a4f323fd6452b959641bf2d494c358c2d760fa3fc1e4d78c353b49a89ed2501d6e6a5c2cae9c9c7bb320d9d0
1514	3	2025-04-03 12:25:00	t	f	\\xc30d04070302d0ad7ab001afadb777d23601ab32caa9463f2bb03d3c275c1f62fdd58524f52ce4b3b6fb52889a04082889ad1d01b1ba57d6a53f6eb09f58f893c56629bf409fbd
1515	4	2025-04-03 12:25:00	t	f	\\xc30d040703020ac9598346eb69ed66d235012b5d6f8451c95fb47c2073306ec5e30e926cc684768d20e0600aac1ddd1df385a4e51b8a1423128ba7d9bee3bff30d2927d49cc0
1516	3	2025-04-03 12:26:00	t	f	\\xc30d04070302eb48e465d9b7301060d2360153864e5e91d51fc362014d3059213975736f928dfbbe67b05d1a35632add9bece7cf7a4c1ecad0def82e8fa153b2c40496dfe8355c
1517	4	2025-04-03 12:26:00	t	f	\\xc30d040703023ad1020e522a08c57ed23701e87577b02d62588812f4925bd06584614cfa83462fcbe1810dcef8533d1ba10d2fcaf00ca38b9b15a1b246320ece261f12c2196f1547
1518	3	2025-04-03 12:27:00	t	f	\\xc30d040703024e3529b3908541f66ad2360164933fbb7f7a1a9bfcc2d1dff1aa5deeeea90dc1150207c6ee43c2d06174384fca0a5c1b9666824d93236d4760b1ea3f7e3212ce41
1519	4	2025-04-03 12:27:00	t	f	\\xc30d0407030249e627b5eb51abdf60d23601a33e3df55655d0e14b0745615d8b493e987a26887cd561bf3d6fb27b794dbee78fb2eba9a91865aa9b6bff1ef7a8e5c7582addd072
1520	3	2025-04-03 12:28:00	t	f	\\xc30d04070302e68ef7515d47deb569d23601393d2b5e6600ed39085a805d255cf88ff0cacee9accbe5ba7f0ab9f5479637ae76072b74db05f824e8b9ceeebd0e0faf3fe7144aa4
1521	4	2025-04-03 12:28:00	t	f	\\xc30d04070302d9456a447e2b2cf367d23701f9c95faef664ae002b425071db0fb0ada9513ba76c4331438f2d31354b39670fb4d5e5f723b9d89ec69b8b56dd296ed8012f5bd1cac9
1522	3	2025-04-03 12:29:00	t	f	\\xc30d04070302d1a91819fa15378661d236018c29b514915f8585cc2359b15277a3a92ffeeafb205d6bfa5d935290c527d9d8398e9a7466b574a919f4fd7a0a7a5cfd5f72b748e9
1523	4	2025-04-03 12:29:00	t	f	\\xc30d04070302dad8f13bf1501e677bd237016b87676d596f96fcf834c29d245b6ebec02a90d830ee087de37b11ce4c6373c655d0ad16e74473c600608173f6339ca270023972fed4
1524	3	2025-04-03 12:30:00	t	f	\\xc30d040703025bc9435da8490af671d236013d7b236369a24845b1fd5c2e4cdcad0cadc949dac82afdae3e3062dc286eb4dcf013eb5a17d4796b05d7389580cf92c354e88f6996
1525	4	2025-04-03 12:30:00	t	f	\\xc30d04070302adcfc7d4eb805d4571d23601b0780a33fb360de685fe07a54ff55ddaec627d9b396bf8d5b648b59815bd8e9c8f73ec17224003dc6d60b0df94024304ac25ebe9d5
1526	3	2025-04-03 12:31:00	t	f	\\xc30d040703026ca3b976e4891ab57ed23601af55ba2e2b2c76b82d7536621527bd91d33afcdd39a53de91c70ee979b51b7e6430ac59f802956dfcfe6e4fc0020a123570b0e441b
1527	4	2025-04-03 12:31:00	t	f	\\xc30d04070302703a5c18b16f9e2768d2370147487b45566e315582938b1494951aae2bd6d994bf479db2ee9836698e7636b47e087a527b02d5ffe4b6e866bad983c3c1383551c785
1528	3	2025-04-03 12:32:00	t	f	\\xc30d040703026fc496c11811459871d2350179c1bf4cdfa16e75c28ee835066d9b4f071f75b459d3072a4685f6edba7d613a7eaaeff44b35686694e41f783eebb402e837453f
1529	4	2025-04-03 12:32:00	t	f	\\xc30d040703021e335138dbbd5e1b7ed236014d83fe59c8a3a85eeca07d97fd261f68a76c647c9e9e1bc6b7e663e603e995ecbf505b5094bbd4adc2252b59a32ddfd95ae1712183
1530	3	2025-04-03 12:33:00	t	f	\\xc30d04070302a34a3c2897395abc70d236011d5d054be03b0516f74c6cee4c2b03f28d0aebb07e927b55dae1c44c48873911505381a7d17d26f17bb0b253e9d741f957a3ff9097
1531	4	2025-04-03 12:33:00	t	f	\\xc30d04070302d7ca6b994278d8b67ad23701c292104abe23a3935579dc8f2e162692ce609299b93f0efe6d901dbd7664276d8ca41d6b5d4c07df02c2d657b5e7e15c7ecff4cb9866
1532	3	2025-04-03 12:34:00	t	f	\\xc30d04070302450cde792c28e13574d23601ffe42fc60996069151a05ddd16194131dbf6ea90829e0c084ac3e81ad34ff0548c57a6a5cffa0b3b0db789f8b030c96bef01a1f245
1533	4	2025-04-03 12:34:00	t	f	\\xc30d04070302a5fc5dd0b547a40f63d237017a516248581c3151bda2ad65daaea1359708865bbdb9423f40f3ea4bc644c59acc03981e9c9257cf6cbf34b0d08a2df69bc06d550252
1534	3	2025-04-03 12:35:00	t	f	\\xc30d040703026a838a0a571b945b70d23601ce8633d3dc170a0e66b8ddb9ee31fec485dce315ff4224118d3bed31a0ba08174bc0f1d05464c756a0486aada35431a160e383661d
1535	4	2025-04-03 12:35:00	t	f	\\xc30d040703027edcd219fbfc7e1e7bd237010394fdd15dc2b76c5347595f295862f41eb130e0e4584840644feb4c46dbded4a7f459cac5f175de70ee76bf0ca1aba689b51244ecaf
1536	3	2025-04-03 12:36:00	t	f	\\xc30d04070302b1b3ff6563eaa20179d23601ab19d7647744bc87d1d59d0388db2efdccf32278fae80219456f801894097f39069eb8a7e7b5c18f97384f7af6351ad3bc8c97c724
1537	4	2025-04-03 12:36:00	t	f	\\xc30d04070302bfe2311ffad4bbee66d23701ad06627cd3e21bed98b83fab5676099269ab24f7937114d37a0e4b1403b496ac4ccaf64a0a112a7f6b8631c4824110802b2e532f7dce
1538	3	2025-04-03 12:37:00	t	f	\\xc30d0407030203c08dfedad211ca7ad2360171242f22db7248bdaefa9e6d40569f3d3e2091cf3f5642e30e9314a83506de371d7cadf79a914c2fef48317ff25e23facc378965fd
1539	4	2025-04-03 12:37:00	t	f	\\xc30d04070302e029c7d2448625176cd23701fc3357e28739e476a10be44a559bddf17cc9e3333c9d545e495744537a2e0fdf04de8283c74b98bcec3942926e03ee77907ea526214e
1540	3	2025-04-03 12:38:00	t	f	\\xc30d04070302ed417aef252bf9fb7dd23601039ec13c57386f2a331178ca1027aad11a10b036d4c0be1160000e9c122f93a189e212c33c24a0842f1ed7c861a2e8426e33c42aae
1541	4	2025-04-03 12:38:00	t	f	\\xc30d040703025d4e65a66d1e560d6ad23701b47e2d15bb7523ae6cad3fd6172eb24fe40ccc3838d4688a5db9a38494816d41fce82d8ca5285c084c9487393206c61abda3fc0b77e9
1542	3	2025-04-03 12:39:00	t	f	\\xc30d0407030285585320de1104ed63d23601c2d8c7a56591b230cfdaaf10ad3a7ac98348b13c32cde783ac105b5339baa11419e6d2b59723304cc92774a556a9a5bd9d8925d578
1543	4	2025-04-03 12:39:00	t	f	\\xc30d0407030217bae68abf4ce6d173d23601a4f62e3d18410e59c088655b7d2c1557ff659b60e97b2c075c673a55f0f7baecd304d8a0a03d4a30a9b08866696c035ff5ba886a15
1544	3	2025-04-03 12:40:00	t	f	\\xc30d04070302d0676e42797a2ac96bd235014176c44d43b9f50ad8326b457a3448144e7ee233b1d7dd70a4f44d7ad07f9e6396346bb75089231db7e91da7c8152de56d971000
1545	4	2025-04-03 12:40:00	t	f	\\xc30d04070302b5307ee3f3810a5d62d2370118bd9be0defbdb398b2544eed613f58ae724bc5f07b34289ee45a3aeed52eec6b2124112c354a7564b4585cf809dc37e29f7e290371a
1546	3	2025-04-03 12:41:00	t	f	\\xc30d040703021dc3cb61d82e3c6c62d23601881f64d2197cb8b640aff363a691fb43276ba2bdde8ff944f00809e99a542150d7d55bf3926839eb8e622b9cedc4235389ddece23e
1547	4	2025-04-03 12:41:00	t	f	\\xc30d04070302bc119d1494d2381864d2370150eec96b2ebec3be8316031799599c6e5ebe36eadebddab6b5f5adabd9fb438089a671ca75776bd7b4607506cfa9a83163f883c1e051
1548	3	2025-04-03 12:42:00	t	f	\\xc30d04070302e5d3cf442e78887476d236012feeb030498815160b7752e62fd2082d1cab49977104b129d78c699986fa3acf6b37e83991ff1c62471892cfab78c279b227b38f98
1549	4	2025-04-03 12:42:00	t	f	\\xc30d0407030275c52936659abc3d7fd2360183ec4f7646d322e8df780b8c800f3b71535fa563008fb1ad191e6338b26272679e776eea027c427063ce77235029bd6b08948fbb1b
1550	3	2025-04-03 12:43:00	t	f	\\xc30d0407030220ca43f54c0fe45961d23501dd3cfd21d16736ca445726c2c9b89df3422488f33a0a6a3a30643391ed1431446f903590f8e86a6abb98df1909b97b0f73544332
1551	4	2025-04-03 12:43:00	t	f	\\xc30d040703021141d9f9899834f87ad237011d42d46f852db9c0bef7042a9b4c35cd639771d118b43ef6adcbbf807fb5fd5c47f96e5bb08a93f3c546105af3a74a74c7d100f6e93a
1552	3	2025-04-03 12:44:00	t	f	\\xc30d04070302375ca63f46e7200069d236012fa73009d9241bcbf47b06a1949b02f66bef72117b09eaf2d641d39e6477ae0ed25a901a7cadb71c6a21e360f2680d40dd7c80569d
1553	4	2025-04-03 12:44:00	t	f	\\xc30d04070302426ffab91f655e7474d237018fa758b8f8e1fc421ca016b5734c1f474ae3c68343464c5d6e37700ac878bd154ff5dbca7bafa2820dfed26b7db827d469c1eeaa9ea6
1554	3	2025-04-03 12:45:00	t	f	\\xc30d04070302c2f52026fcc8611575d2360147a4f3c56d806326861363cef249ddb9c41a997a889f621787b937bcb6ae48816ecaddcf965bb860bf257f643fb993f517eea298b6
1555	4	2025-04-03 12:45:00	t	f	\\xc30d04070302ef9e6b738da6455c67d237019aebf9fcb63f89ada7b43ee1d6c93972d2185f315f8ee74522b4516effebbf7e78b97077998d00dab13ea178533cc90781f676fb89d7
1556	3	2025-04-03 12:46:00	t	f	\\xc30d0407030297eb85627cc17e8160d23501abcdf5d737be000f66c3c629bc9991a1acf1aa01ed48bd32f335c55d2c41585bde1f91d2dd69d43b5b419ce5314463d8606ddc8d
1557	4	2025-04-03 12:46:00	t	f	\\xc30d04070302c4ed25bb7ab051877ed23701fc1ed6fb13c2dcbc1b207f5d4f18ee9a953f5840c56a704b3aa72b2163e70df646470905a43a0ee6d267ae00a187a99587095ad7892d
1558	3	2025-04-03 12:47:00	t	f	\\xc30d04070302191efb38ca7aa5196fd2360119c6e90a61bdef8b8d4927e0dd0ba12206db2fc3701ca47593ab611043c6efc965f8f9f399ffac0d354398b358bf0f6b7dadeaa544
1559	4	2025-04-03 12:47:00	t	f	\\xc30d0407030223f7e79f66d83d5f7dd23701c0c6327519acec556f35d72e2f5dfa5f71a057d150dc9b9b28ca757c8f28e1ebb209bdee3d0a783fa7854fb07172c66a0128df069262
1560	3	2025-04-03 12:48:00	t	f	\\xc30d040703023f322faafc23cadf64d23601a5198e84902f734836b120148d09919e0c87147d0058c38f53ed554752d127c27c925c396d9e16306e783c62373c9f6b59cc102d05
1561	4	2025-04-03 12:48:00	t	f	\\xc30d04070302f92465be6a419ec07ed23601ab96a431d2c88a0881e4ddca58396271e85114eaf8c4c58dc2661ad97fe300632abf05fc08fa0adbce19880546170e0e07dd5ccf9e
1562	3	2025-04-03 12:49:00	t	f	\\xc30d04070302efad71a9271a72a77bd23601777efca5a74d0c1b47ca3e0f70cc6bd8543c616a668479848ee433621bd1dc611c19b551d47321707611f926d4f00815205517fedb
1563	4	2025-04-03 12:49:00	t	f	\\xc30d0407030211af1fa76cbf40b072d23701a15dbdd745a3d1039820b17b8dedf362ee8091fbbdd62b6a48c0fac61f5ccccaec6edc298692fb9a89de1d8b59a206e1dd23d0c97d54
1564	3	2025-04-03 12:50:00	t	f	\\xc30d0407030202c23d4f4b00f95c7cd2360169d12b8571d83b5eeab4a0b827584036d73aa5fc72074892671a818da8f7b41110afe5c0dc0d95842e9b72a9d771c54327507942d7
1565	4	2025-04-03 12:50:00	t	f	\\xc30d0407030217b203446a9dd55f72d237017b081e8898ef06056a6040ea60971eb701bdc6f0b40abe7d3054bcdb70785ae45466b5073c920cf09bb53e5dbfa5ef76745a702e66ab
1566	3	2025-04-03 12:51:00	t	f	\\xc30d0407030296d9b187b384362b78d235010996208e3a71d722a9829693d8d825aafd691a33fb0fa8ba6b0a50092813357a8b7aa416edfddbaa0574a76d88a70193f53bff95
1567	4	2025-04-03 12:51:00	t	f	\\xc30d040703024025faca989bbf947bd23701d6a2e084287c51d3e2283191cb2347ca015646893d93e844dcdbc42ecb1db07e9dfa5f90b4e45b8431b9858ad7e54d063b8c3780a5ed
1568	3	2025-04-03 12:52:00	t	f	\\xc30d04070302655a439ebfbdc7ea66d23601580b4b51ea8c1d2daf56042dcb9d328745412b94646a291f0c5de7054e974c3868b7f2bdaebab6cb9c5b492218bae329445ccc83bb
1569	4	2025-04-03 12:52:00	t	f	\\xc30d040703024a18b81a5f1f44aa73d2370130a2ba953449d1c211c596fc0eba8e116b6bf0dc97f0d87c3c6436358ce55407b9d3dda38662399965a72909a62db3d672564f422f37
1570	3	2025-04-03 12:53:00	t	f	\\xc30d040703027e1e369025f025f872d23601f0ab917041ab9c391d1caffa13e6c4c648568edf935f40c9b251e7016e3a72ceaa82fea90b05d1584dc6c87d05480e2ee384fcde2f
1571	4	2025-04-03 12:53:00	t	f	\\xc30d0407030200313afce85d1b5173d23701dec845e0eb4fe8d6ab9055acacf9555268cd0a52ac71e9c325fa1cd6baa49c1ea526e8c47bbc94665b8108d60fb7a87afab0a4f183b1
1572	3	2025-04-03 12:54:00	t	f	\\xc30d040703020b37fa50a77e12146fd23601d48836e8f2fa3328295e3e715cc9b92a168b1592bb3efad8781afa01a04e2df039e437befe88d7494e0c5c26e70f47940ad9afdee3
1573	4	2025-04-03 12:54:00	t	f	\\xc30d04070302334267fb4d3bc3af60d237011ed54056a7fb274e69347b9bea9882f20fcaec3899715a936f41e3dbdbc998d1664d21b8bbcbbdeeaa7bf93e3af5d70a5ba9980d2a70
1574	3	2025-04-03 12:55:00	t	f	\\xc30d040703028c69c4919e0b988678d23601d6d67bd3a9915ae6afd475b0bf057f69893f0328a6dab95d104cc09550ec36f8f3638751cc2125ce95916536ad16a50e60bb0e3606
1575	4	2025-04-03 12:55:00	t	f	\\xc30d04070302e94fe6f12e03384265d2360165f4d38e873602e34ef04fbe505dea8f3cb6c5367951b6cf3878e12a93f047db4c9006ed3a1b8f8c56da6a7762a39c20c6d5a9421b
1576	3	2025-04-03 12:56:00	t	f	\\xc30d040703025f1d108ad17ba6ef6dd23501d61918ff18f17819fc1d7e4f4badc61b71ebd9c6fbc5846f1b2e07bba79ce205000c4e041a397519e0329428b0ad62a97ded5875
1577	4	2025-04-03 12:56:00	t	f	\\xc30d040703025e99e5b306c86aa572d236019de796ced8749c888a00d1f4e174fbdea5f309d84f1a824b118badf130f9bb50b1c48af6be78468419694328e376e7cacf596cf9f4
1578	3	2025-04-03 12:57:00	t	f	\\xc30d04070302b7cd32797566ee1963d236014b5a7b458f8970b00c0b048519b52eaa1ba70fbb3d0d0364945971353be6b9d118d409f180d09695f7317de94242d3b543aa14a9f0
1579	4	2025-04-03 12:57:00	t	f	\\xc30d0407030296bdbca00c7e04fe63d23601b92d65184c1cbb7d65f2c7eed8bbe00005181f74c886ced0f4617bd11f0c57454161770c829ac5e2075338a85cbad840092f69cd5f
1580	3	2025-04-03 12:58:00	t	f	\\xc30d04070302a8aaa798466a345067d236010d8f2ab86cf9e9347d8a31ee320fcb23f6558c55f523fe79950fc1d3deccbd5d56cff2ad6dec9fabe247657dad56dae20fe3b87309
1581	4	2025-04-03 12:58:00	t	f	\\xc30d0407030222701d9120f0bad172d237015e47e944ab62ea974cf2a2caa0ecb08cd9bde8d84cfc2fe32c6d8b09f6c814b833b1b16926a4aa28ec95b81dd849cc808521ba984cad
1582	3	2025-04-03 12:59:00	t	f	\\xc30d04070302c9c66e91018763b070d236017f84adc9f2cf683f7b239fd7300373dad28ea6c7d9ef0ac636cb475e762b1af1e58da183b63e2793b357429e379930367c88661dc1
1583	4	2025-04-03 12:59:00	t	f	\\xc30d040703020aabd31e23d8f95b61d2370198008d078f1b7f94af1457842b11867f826a6f664bb045d0e294d2f9da8d846952cc853c206ce665f35c5087b1de19e7fb5494bbbd72
1584	3	2025-04-03 13:00:00	t	f	\\xc30d04070302f30a17ecdbad58216fd236017a5a29b8a942906fd310f4dec6eee59e009360fe734d9aa3cb53cc5cb30672908912a808e2fea68fb998c8585e96ff0616de07c8e8
1585	4	2025-04-03 13:00:00	t	f	\\xc30d040703023b5d445aed41d47965d23601aa7dd04da6aa90faec78c29590df50fa8d7fe7086df29a5938e6c695e6365da9f9c2d4c737353d99a2e4da5ae1a5372496114ba1c7
1586	3	2025-04-03 13:01:00	t	f	\\xc30d0407030231d7f70682770f9379d23601ff4df5e8df7f35ca2116181e7245652d4f837286c7c39912e7e2ce2d57576edf4f2cd734fca08476b99d3b54e4f73419abc4616f12
1587	4	2025-04-03 13:01:00	t	f	\\xc30d04070302773f491ea0cedd377ad23501321b585ff4d9fa8bd992981f27383c91d2dcb83cb08b825c34e024b565e1bdf5fec570d1cd569a57443208db6572fe3cfeb388b6
1588	3	2025-04-03 13:02:00	t	f	\\xc30d04070302290e296b7c1a7b4e7dd23601683641fabc41007f5986bfb5bd13d6aec017fd68e2a50c4b17ffc99e04b6558fca0178658cbaec40e81bc6ef43b167db3128d4d685
1589	4	2025-04-03 13:02:00	t	f	\\xc30d04070302588c549bbf0ff7736ad23701b5ecd37b1c983fb7378f3a33c2bfcee3fdcd2dd16f8db1c9f3afbfe338e09e06d8bf8cdee69b8a425aa205bc2b598639c11699cf71f0
1590	3	2025-04-03 13:03:00	t	f	\\xc30d04070302b92e07b4cc4a15b076d23601b872e0f558c496e3cfccc0753b9b2d9708742fdd82c06b71a04824c54a595f93757dffe3733af366841b270a0e47f9dcf4e9486a17
1591	4	2025-04-03 13:03:00	t	f	\\xc30d040703028717a50294601d896dd237016bad2e4375d7f66ed58c9f185ecabb7728184bf7fc70d85710afadf6d288a13c24c194a8fbec5c398ba2cbbc53c6905cffe128bfceae
1592	3	2025-04-03 13:04:00	t	f	\\xc30d04070302194fe4533845cb1e7fd2350129116d89a4e235bf679b42aadf2c5bb8cf77d4df9c7f071729654eeba724a661576f1aac02d89dba3077537afc100d53dddcc666
1593	4	2025-04-03 13:04:00	t	f	\\xc30d040703020e5c304333a991ac62d237016affee4ab5ead3083d0dcc4256e4dcbe94b50eb768106fee119e746a545ee0b08892a5b65791197980fdf8a86b37841fc9ee192042db
1594	3	2025-04-03 13:05:00	t	f	\\xc30d04070302076ce41ae5a1efc560d23601c6bab9663d700b4a5beab436d477e9863ba69cfe4604539ced470887d44f0975ebe478e3fd5f4da4d963bde867d28cc90fe187a24a
1595	4	2025-04-03 13:05:00	t	f	\\xc30d04070302b23e4ae615a4a1cd76d23701e2accffc0098af869eaf93133c527d6b4513f36ec7c7318993d77f595d53b4336918a112ffdd227fd55148df2bd3da423ff1ddba2413
1596	3	2025-04-03 13:06:00	t	f	\\xc30d0407030252b332d221c78e0178d2360149ad78599f689ccff58654c07ff7f1602bbba6243e6d799e7f92f74f791aee0d14cea7a17854591a7589118732a16203d4815b313d
1597	4	2025-04-03 13:06:00	t	f	\\xc30d0407030268ba61f012c459fa75d23701ffb6eaf033a68a842fd3edded2416bd29ff50d19dbf183f3f1da06b35821393c5de6b358ae0524bfb35779858deef421e75933d5f449
1598	3	2025-04-03 13:07:00	t	f	\\xc30d04070302f6c605bc4a68635d7bd236016cf5747d6db8cebbc19bdfc4900083bba3183ca31639d72f96f5203c6ac92d9eb0c8483fcadefee708bf9369936330b7a4478454c8
1599	4	2025-04-03 13:07:00	t	f	\\xc30d04070302dddffe3d607ea19166d23701221da82852dc9d6b5c1385a154e98526bfac8d0e2c48c70c7829e48c0acf61494953805c6dc1330fdffe1b8a1ffc9632b35fe18e50a4
1600	3	2025-04-03 13:08:00	t	f	\\xc30d040703021f68200f0ea3c03b7dd236010ff9091d14ca65839078747ae8f82b0546608f2ce822b7014b151aeb9a1567993a9a5df9cc0a214348f92d3e655e3595bcfeccb79e
1601	4	2025-04-03 13:08:00	t	f	\\xc30d040703028ba4adb44850dc5474d2360172623c120620f3b0ce35978ef39c5cdcf17bce3e7bd4e35d27c0c573131c2349accc43a6226995675962c2d0ab9a8682cf958b175d
1602	3	2025-04-03 13:09:00	t	f	\\xc30d04070302ef2fa20919d4c88660d23601dfde902ccf1a21047a6ecaf051a1389ab814bec43175770ca2298b22a36fdb6a1fd87d3a50a614e1b0e14f319e732408a5b14d9da8
1603	4	2025-04-03 13:09:00	t	f	\\xc30d0407030218b918e7f6da93a671d2370197d07f6701bf9af368d9995aadc6a8aab35a2bc23fd182a34cac3d4455104ffed09815992bdd82290cb07bc0643485329732f96a9aca
1604	3	2025-04-03 13:10:00	t	f	\\xc30d04070302108f4188a3693a646dd23601d1aed31895b8335e945f017c7ff8569943b78512cc444f4256db0aae5790a564a16826bc9290701e3028b65ba45c00d11b06b16bd9
1605	4	2025-04-03 13:10:00	t	f	\\xc30d040703023ab32fc0fa94803669d23601b2e0995b5f924cddcab7d2c341f98c98b64f2fac7b8bfab1337d6338a417d465d7747245645a78098d5224e269593ab2155502d450
1606	3	2025-04-03 13:11:00	t	f	\\xc30d0407030227cd29f2b1beb05265d23501fab8de5331a77ab3fe6fb98956f47368a907b9699ac213fbc7ad7f3408c61994ca20a09c8703f49eb7183c81422ec6a403a854c9
1607	4	2025-04-03 13:11:00	t	f	\\xc30d04070302386b44da524d296f6cd2360165b944e5620d2bfd9ac015611d99f82c916fe9383e055ae2d57a33ba53c38c2de6344647fc368485b5adf40e81c87a91e08aca00e5
1608	3	2025-04-03 13:12:00	t	f	\\xc30d0407030271140cddd557b2b569d235010d2a9d53b49508615ea948ac51743b9398a54b3fccf954fb0efecd43056553bdd6670c85c5c84711736a799bcf1e542fe1cb2965
1609	4	2025-04-03 13:12:00	t	f	\\xc30d040703021e655106815d0efe6bd2370188cea50f5bd6c1d969a2fa717c568ba5f85dfeedf2e6604d646d28d0d94ee726f59177f02b1802191f9cfbfb7d199fe53f0b588d3691
1610	3	2025-04-03 13:13:00	t	f	\\xc30d040703023d89b3bd920257e160d23601557cbe53d719ab1aead6324f71169e1951dfa3083b71be4cf8a85f69667956e12b9253ea3fe46018a279099695dca5ea850997382d
1611	4	2025-04-03 13:13:00	t	f	\\xc30d040703022d419099d0dc9a6b72d23701e1772dfad08e82e7d32d9a613a8339c23b8f9efdb12bed6da4b834057180692cd1ff66f9939affe791fa59c0ea79dfd988991a6773a5
1612	3	2025-04-03 13:14:00	t	f	\\xc30d04070302e61863427a5fdb7675d2360155092e9b607a04f98b1e3008090cadf6048aaf21afa55d0bef90d20d08e9ef181784e8d5fa0de8ad3c569985e927b9c7e2f0b08faf
1613	4	2025-04-03 13:14:00	t	f	\\xc30d04070302c8f3364ce377892d79d237014296596a95dc799f08cfc6e4ad0924efb45c7980322a260c4aa47ca9a6a70f0c8c9f73c2dece5ddb2611120d533af268a0b0652a10d2
1614	3	2025-04-03 13:15:00	t	f	\\xc30d04070302228806159640d44e65d2360147786ad730b100dd39fad7c8721afab54ef67692abf74f20e188429b8c7ef2cb68378ad0163e9d5634cc2cbd7fa740fdb989f40a7c
1615	4	2025-04-03 13:15:00	t	f	\\xc30d04070302c6201e9bedf9021268d23601bc0cd3e89ad339dd612d49dc5980d228c0e136d2539e64f9137df1b3e56aabc114448df4885eabeb8a6a442c74f40a018e963f81cd
1616	3	2025-04-03 13:16:00	t	f	\\xc30d04070302cd4c7eab9563ee3d77d23601a9ad7291412c9263f58187ac29003b9c430faebe9c76c112280e8bd3080d4bb2cb510e29df445db58f64ad09cad50023215dc61efa
1617	4	2025-04-03 13:16:00	t	f	\\xc30d04070302cfc2c5dbbfa3339578d23701cef6b49532851564a452cd68b37944fe35a032116a5f4baa9e1eb0b4322121d85824c7c17871e396839d3985fac3d76f368fc26686f1
1618	3	2025-04-03 13:17:00	t	f	\\xc30d040703024a1c9d0b39e107e36cd23501e9a0cdca471bbfb55eeac2a1e4db23d1182836939a4267c86b54f0b2f6ed652bc823b8f6319389678b6cf99923ef09b43527258b
1619	4	2025-04-03 13:17:00	t	f	\\xc30d0407030256e36473030503007ed23701e4ad2bade8c03ed068d926f08528e579b6b0ab56deffe536f802679b774172002408fa4712b4592327c2f24b40531a8cea61e7fe940a
1620	3	2025-04-03 13:18:00	t	f	\\xc30d040703023565c55836c626d669d23601df66ea28eb7457ac611fa5a15b462cfbf45e748b1547d8645bfa2056fb51706dfc68d76785bae73563e7cd85e4f7e4c8e42cb1595a
1621	4	2025-04-03 13:18:00	t	f	\\xc30d04070302d6eb71486e013e1f63d23701b0ac26462d9de4ff743d8d5cd569b411128d32f5333356ad4ef98a78fdbac362a1e760518e5265ea8d668372f46dda6633fd93ec1856
1622	3	2025-04-03 13:19:00	t	f	\\xc30d04070302d58f823ceb737c2c72d23501f8e3edc8f35c7bdde30c86259dc6e95cb93bb7c076f15f8822929540466c58e01e487865336a0f9eb14f4d85bc25c9f32b4fa4bc
1623	4	2025-04-03 13:19:00	t	f	\\xc30d040703022a0d8bfae68b490669d23701d6699135612a9c15a11432aec05484454118dd9c428ac14e3dd3b1c1fefb1fba0e64f4cf79a232c631c46e36c939996e297aed8f44d1
1624	3	2025-04-03 13:20:00	t	f	\\xc30d04070302e557b1199834c54b67d23501ad546f1c27a66d598e6a5003279f068a27c72659dfcae9a9f4f852c8d802323bf149fa167bf29a0097e28b0698eb88cee5f6e4f0
1625	4	2025-04-03 13:20:00	t	f	\\xc30d040703028dd528b4209b132f64d23701ce1a8bf1f9243a6d7bb2421b502c2368d8b6bd6268fc60604a6778c7adb6d0fe80e95809bc93077f8e727986d4086e119fad8ad19776
1626	3	2025-04-03 13:21:00	t	f	\\xc30d040703023e185a70e2683d2b68d23601ec6df56bb2dd03c3f7b9ccde504fc1c1815b90a2345f6c558d73a31039ff3022d9eee987d222151004e56fe87bcad7f8d75c2984c8
1627	4	2025-04-03 13:21:00	t	f	\\xc30d04070302457c7d2116faff9c65d23701c645d5e2caefdc6fc751bcc5786bcf564b6a156ed17c77202c622739d815d7e95e49007c6615b8ebc76254fa68bffd8f4329dce811fe
1628	3	2025-04-03 13:22:00	t	f	\\xc30d04070302725a7145f532ab0378d23601d597555642f4a575033cdf795e4948d7e7d80bbcc412b4c3bfd5565e7f5f08c113b63ed9a99bbc7a3ad3fbc7159c3617e64a7e3817
1629	4	2025-04-03 13:22:00	t	f	\\xc30d040703024f10ac4875f8efc26cd237012f0e885159603cacba43a347a6a4f6af954488670198c30bfe9812c12cce85b3629eabf9e50b205727e7dd01042f21266a2e1c31b95d
1630	3	2025-04-03 13:23:00	t	f	\\xc30d04070302991c99259647a59478d2360133193949c998262f7f774b7d3e2d226dfe5d0d3a5786a0d28b14a953b5ac587fe2766b713a56e14c8e2af2d2f425d059a0d1640029
1631	4	2025-04-03 13:23:00	t	f	\\xc30d0407030288b616d2d9337e246dd236016176ad46e6e6e9f47e35d632c576b2bd229703a2060ed8251b61f805c3aefb3f7c99991cd5d3117af5c15e53d534be54f9d09b4423
1632	3	2025-04-03 13:24:00	t	f	\\xc30d040703024376a76dbc8c1c1c62d23501d9580a060e6c12a6a8a270c5db2106de534b261302d3437cd2c0e7642edc2ed025a43578e0a1f2c7a7b1a80279697ad7b5380d5c
1633	4	2025-04-03 13:24:00	t	f	\\xc30d040703022cab097d5924bb9361d2370192724aa78fe3f55902bd0187ed62bf036d6ba45bb6046e2f911c3e562d03796d8164ae7c9ffb099cff93233af7a55d7a5daa42c5c31e
1634	3	2025-04-03 13:25:00	t	f	\\xc30d040703023e16f36567a2a26974d2360156e67be2b1d51b23429c99a7ca440a4570924a3955ff5221400b09e45fbe0c18797d35f4fd2a03f198a4d9cd1bf8a9c6f5104c0a72
1635	4	2025-04-03 13:25:00	t	f	\\xc30d0407030295ec48f9eebc299860d23701ef7e49598bcf9ca5d66671dc1046a49c58f3086b459c637736cb56ba463ec2066a3c9dfbf3584a4b25414692e9c9158b31be1c33edb7
1636	3	2025-04-03 13:26:00	t	f	\\xc30d04070302a73f6ffe9918803a6dd236018f4c34b4c77329f88ce923edaf94de703e1d3e141e2641e0c66077b10e10129addd9f2502e07ff7630d8373690d12e65ff925e28b0
1637	4	2025-04-03 13:26:00	t	f	\\xc30d040703020ec0cec4af27f6b365d237019c91b9f0f63077d1da28ed357489dddfd33c19227a3579986c6c5646c031bdaa55c0d0229be7caa33f42738a9c988b3cab3a1c6f5c43
1638	3	2025-04-03 13:27:00	t	f	\\xc30d040703029dc90a1a90124bd270d23601ab8958fd569b3a321891a3e294e11a38e88d16f4572d8728d5867bb43a8f1cac969866385f740bd3ecbc221fe44d83ebd03dab12a1
1639	4	2025-04-03 13:27:00	t	f	\\xc30d0407030214472f2b8f9acc5f67d237011a6948aa0060d7c0acf50de894b4b45936ccc0fcb243eae66c01db1370280115854e2f3405f5d41b1a628138d72745cb5b5d432fe3a7
1640	3	2025-04-03 13:28:00	t	f	\\xc30d0407030239b206d0efaa11af63d2360132ffae6776834bed8ff0a09ac23624c00f41bbb47ae29b159b8da068eb71ffa161063b6880e2b1ff1292d2008c298a630f57a5a950
1641	4	2025-04-03 13:28:00	t	f	\\xc30d04070302933789d55563d7547dd2370180070eabede7857368cf9142fa393ee51af2cd2a323969f6825ca347dfbcc26c862408dbf85d46423755b2c84342dbb90636eabec44b
1642	3	2025-04-03 13:29:00	t	f	\\xc30d04070302fd4ef8c7186450fa75d2360146ed63554fd59a76b9e76d83de02128e930ebd623ed6a81f09612bbad8c892cb2787a27c341fe0803b0dbef88d631467c3febbcc0d
1643	4	2025-04-03 13:29:00	t	f	\\xc30d04070302395374d9df4944e87bd23701811db28fa35c7c389bdb416eb970c9b22bd69fe44b6d08f58ddf70a49d1cdc450b284036f53e7c258f3ff0d74ef693748da936fc1e03
1644	3	2025-04-03 13:30:00	t	f	\\xc30d04070302cac653b90de6fcd16ed2360139c5b84ea7d768c20373cd59259089fe63fed01adad9a70213ab12bbee1c173d2054aca363fe84828c4f95dd45c0aaba0341775a8f
1645	4	2025-04-03 13:30:00	t	f	\\xc30d0407030244a7ab1be1d0d5cc65d23701760c3068697021ffbc3821d76238ee98bee02ab9edad4964517670516cc4451899d2a20d1517cfb4c57db97cd4ad96a7075a06dbbad9
1646	3	2025-04-03 13:31:00	t	f	\\xc30d04070302bb45f929857d93a567d23601443874c470bc75f0a31124ea9a96fd85c47deebbf9265122c64b2720d1fbdc94023827b5fee75a427cbe88b89b5d78ad90b944726b
1647	4	2025-04-03 13:31:00	t	f	\\xc30d04070302d3fe3973dfeeabd163d23601af97719ff1df5a26d8fb3e9ac2b45cc942a99478d7a0ca1fdad28dd5adfa809611290a8622d95a1b1d22fa71354800cc4d2dd629e0
1648	3	2025-04-03 13:32:00	t	f	\\xc30d0407030206fcab66f061f9d960d235018ebc7a14c379d1a10c7ed64842a0fe948ea6ef5b0d340e1f1f8b7838cbb6e46cf4b1610e6c08ec75ef22d36f57977da359aa42be
1649	4	2025-04-03 13:32:00	t	f	\\xc30d0407030255db9b5fd9e5c4fc6fd23701427ea5d95a2507cac527038643c27e100c2607f1441df65dac7014829f0b2262b1a70feda50aee1b98ad6eeb591cd133887577a8317e
1650	3	2025-04-03 13:33:00	t	f	\\xc30d0407030269c9f3efe1930d5274d2360176928acd1d60ef59dc5f3765d807bc9fbc61af219c311f6486f05bf84599fdb1d43f41be38ab6004385460b1270aac811a823b090b
1651	4	2025-04-03 13:33:00	t	f	\\xc30d040703023f860f8998bbd59a6cd23601cada96c123a6c7eec96787e744b6253ea5843d2fe1c9671fa3bf8adcd2fd5769713ab0a30bd71d107bf16618d1bd9dfe9eaf9afe3d
1652	3	2025-04-03 13:34:00	t	f	\\xc30d0407030246eab2def90a739a61d236016aeeeac8a29bb08046c79b7b013cf4043cb1b1acb10a675f499728442389792738d8408f9a96535fca85904f25a819a6ad386ac864
1653	4	2025-04-03 13:34:00	t	f	\\xc30d04070302cd721e286f4248767dd23701e4cd328f2a227739e49b527ad8c4a4f00be970bf4c8a0354b72f3d1f6d0aa9d53e277dbb73d965c60ba62a25ec5aa7e2774a23fc1f29
1654	3	2025-04-03 13:35:00	t	f	\\xc30d040703025d8befd3ea59a00476d236018d09fdaff4bd963b74388dd7c19984504fb94dd254039506739ce636ea09aae6e63a313408cf234eb2e222938b9ff7c19cd41c8ba7
1655	4	2025-04-03 13:35:00	t	f	\\xc30d0407030214bcb9e3fabd2d1464d23701f51665ad669f7b3df7b4bc681f459b2e9df8b60bba3add6a1cd03f5c900d9c818d8e2a1272e3491f7ebe768471909a73e3c71ca3fba2
1656	3	2025-04-03 13:36:00	t	f	\\xc30d04070302041560a05a36f1fd6dd23601d8ba3437642dac3f20703f9d06ef77377049ae3a964f15a1a43313af2783304b777467a4ed670a454eff527c66bdf95065ab5d35b2
1657	4	2025-04-03 13:36:00	t	f	\\xc30d0407030252cc3e7f9dfec2f777d23701d3c2cab7335adc32f36eb79b45a1eb52e5984ea1942922f054c6939734b21702e228484bb396fe2f645778bca0b570d8d941aa0ec8d1
1658	3	2025-04-03 13:37:00	t	f	\\xc30d04070302def5353fdcb977bc6ad23501f299f95706ea73d143d943974610d8bf6a599adf54c0757b672dbc0d46893a9eb3f1b1f36a7092712afb4141935adb78c94d9102
1659	4	2025-04-03 13:37:00	t	f	\\xc30d0407030266b2f4de7d82092d67d23701569472c74b7250eb44d9c014ca952c5442cc590eca515fb1c61b65c1f3903c14825ed71c6870d0888b0b75b1b37ef31bc33991b6e0f6
1660	3	2025-04-03 13:38:00	t	f	\\xc30d040703020e3e58993d04d2c572d2360143ccd42f8d55eec6b4c3fb41ecde65f8e837240db78982ccf17f80650d53cfe005c1c6a49ea994ff18052ac9275c22a37c992e286f
1661	4	2025-04-03 13:38:00	t	f	\\xc30d04070302d899aee2a23e24536dd23701f347b74f37714a334aca3b43fcd79fe611ede61e0c15b8fa7ed8773e10a3272e911395186d09018d8eef226bf048f869b7ca30a21b33
1662	3	2025-04-03 13:39:00	t	f	\\xc30d04070302e9370ccc2d25b2447fd23601693ca2ab431a76e1fe105e7db1a89fa71b83d19eff0645a3bb3313aa62f5db731dd3835f14bd8ced8a9489e93193d027470ccc5493
1663	4	2025-04-03 13:39:00	t	f	\\xc30d0407030238b63a7d793fe3c56fd237019558de05836a39353ab6c0630730765b57f4eeaec774611d885684ec6232d46c7e21786b5d722f283358aa2f14b83fa6814007d6199d
1664	3	2025-04-03 13:40:00	t	f	\\xc30d04070302420d7515851ecb5868d23501527ce126428e175ef004ae5df0f8ff8623b9dea5cd32dd4477395a2b7fb0343cbfd118f793835e502dbbc6b820c5aa9930181dd8
1665	4	2025-04-03 13:40:00	t	f	\\xc30d040703028c61b82d6495265371d23601f2ee976aaa6991b5462fc7ced307106d4400a9403cf75356b8a84260ec451a8462e1ed4b8b14f0d6c872062fe64b19bf97d4087904
1666	3	2025-04-03 13:41:00	t	f	\\xc30d040703025aae7519e4b9c5fb62d235013da3ef4e761733690985be369515e2def19e7bb6371affa0043354f3e2506ab5aee9a9d464b487e7ef09ebd4a1b2f21428bce13c
1667	4	2025-04-03 13:41:00	t	f	\\xc30d0407030232731698734624fe6cd237012d3e585c4db8f0c1a8ebeab30f19381d99904cad0009874e765e05246bb2541d60ff4d629f6e97704d6f75e9ac6ca88cbfeb86dba1b5
1668	3	2025-04-03 13:42:00	t	f	\\xc30d0407030214525fda6217e54263d236013014fe16a5585198682465e7730cf24b238ba3b70abbd445f0a0b96f71d0e6feefe89209b3489fb89218231a3f56bc620957a0ddbe
1669	4	2025-04-03 13:42:00	t	f	\\xc30d0407030201fbdc65a8efc7256cd23601d19b8614a5f8af7ee9aff9a69a2659e2d09a7cdc048633b9810488c76e554b6fda773f289b067564df8fba08e4b4476dd09ff1dda8
1670	3	2025-04-03 13:43:00	t	f	\\xc30d040703027ab8a48df0d4b73071d23601782c0eb6140d70d4cf1f802c903b6c6aac56163bbf81c7895d19db57a8504a60b87ebd6808ee0b9e346601c0a87cc56e1fdf44b600
1671	4	2025-04-03 13:43:00	t	f	\\xc30d04070302da35899e53b63ef773d236017719d4f4b5ce3dcde83e4db89aa27cf08e1ff355ceb1be60288eb306e3db349bacecf9a910b909ca3aec14094748268a30429c4e15
1672	3	2025-04-03 13:44:00	t	f	\\xc30d04070302d2e90f870d1a825566d2360199780159d23cbabd00bd87af72d36448e62e9a8405cabedbfddafcde09fe981a68d517e777585e47923efbb4fef4c5adbc1c62032b
1673	4	2025-04-03 13:44:00	t	f	\\xc30d04070302aed88b95877b383474d23701b84dd884cacacccc0b4baecfc17472f6810d0ee4bc7ab69331b9c27ab1d05d796eea8787dba9520c66784f0c84aa425b44c70b0bd023
1674	3	2025-04-03 13:45:00	t	f	\\xc30d0407030259230865d80f3cb772d23601d8a6df684a794dad0398148dd399f5c19890f41031eefeddb4e51a0d35b7f31d1877c11c0f15bd3e74eb61964eb8d8bbcf40e5b368
1675	4	2025-04-03 13:45:00	t	f	\\xc30d040703027aa64e592f13790a77d237015b957c5d7efa0dc8b90369c731512cf6f3a874e3d8e9edfb329282b1a0f39029771e23a724cc7a60e9de6d98d5e23ee0cc9167c80561
1676	3	2025-04-03 13:46:00	t	f	\\xc30d040703025298603ad8e350b375d236018980befd3e2663029349e64e270aab526d7e44ef785aec940fe01995832d2aef8fa915d1b01d0cce289a48868135262f845d491339
1677	4	2025-04-03 13:46:00	t	f	\\xc30d040703024853647c66bf93a771d237016247f56a33986bca33da02311d49162da5e411a2d53b5a0d1992b116cc3152658dc05cf20c9bbbebfcdb7a30ea432503177ca243b306
1678	3	2025-04-03 13:47:00	t	f	\\xc30d04070302052191be1b4f669472d2360175142d08c79b4114a1facce3c6bee099a83b076efd541a41a1c0ef52d2c13fb408a73473ba862163f48cf26da0002d1648224d4a21
1679	4	2025-04-03 13:47:00	t	f	\\xc30d04070302cd641878ddcfbdd173d23701e1ab36a7f928981069fc6bcde05023c814adf129169b4dff5480d72f6c96883e140956ec5a6103fcdbbf3713802ed030c2d5259156ed
1680	3	2025-04-03 13:48:00	t	f	\\xc30d04070302866b7b40b976474470d23501a7a7aa827698d85fdd9e40892fbcd7116c9a1e339d516fc3279872e0b3a7a91cc1061152f35ff0d2995a151a72c5b1c9118f2f26
1681	4	2025-04-03 13:48:00	t	f	\\xc30d0407030225deb197cba7c6406bd23701350a8081ce25a8905e6789e8468b7a96cfe76eb1c204e673d0c9021be1f9ed53ca1fed6cbf044c72852e53dd6bc8b05a0ba79653af2f
1682	3	2025-04-03 13:49:00	t	f	\\xc30d04070302b1ea5ce80de1778068d23601aa78ddcb3fd09b8542539998ed3cda25122efd7508a020831843fdbdc9320325e46abb1321ee64644f04ebb5aaef72dc8b2fd0c57c
1683	4	2025-04-03 13:49:00	t	f	\\xc30d040703027ad7964cf21ed72c6ad237012c6250cb5fcb37ad88f1c86c76f24da5596e7ae495a2be7df406931b26519b5fe897bcb979e23c4d4bca6dad50a1c443a45c499eb425
1684	3	2025-04-03 13:50:00	t	f	\\xc30d040703025790a3c2cb8cb77072d23501621846cb2fa4ae7eac891f743ed44f3b8eb0a997cbb40abab0884cba22783298ad6be99cbf5382ec193a3df2693d02880d42e120
1685	4	2025-04-03 13:50:00	t	f	\\xc30d040703025895e366b5b91fc267d2370198f201e8bb8cb59179b41043e6ec7b401aac2e95db5abd13b058279a5b873a59bc8e327cadec8c6a487e17d84d9fb1a35b5431c1ae5e
1686	3	2025-04-03 13:51:00	t	f	\\xc30d04070302fd17c878890c21f661d2350139d447ff000024f359e26abfcf8c44d9043114081db65da19ca0e94f0d69f8437fcdbe8bd100e1194f2b1d4ec2f457316578a9ec
1687	4	2025-04-03 13:51:00	t	f	\\xc30d04070302cdb3e0bb23c566f573d237015244fd2e4e00dca47658e892c549ee674f8514110e0bd37656e471c9f20e68868cbebdfd42c36f2e5b74b6db334064c1dd9bf48391a3
1688	3	2025-04-03 13:52:00	t	f	\\xc30d04070302e848aa433809f0a560d23601e0eb17d971ffae90a8231b640fd39785c40939fcb2b010d2bca91f85cb065ebb1cf5066b5e5087a2c2a555a88710796acc9a14c32d
1689	4	2025-04-03 13:52:00	t	f	\\xc30d04070302affb6d147cb72a417ad23701a9381f0e211f7adf3db5fc7ad7a9a409c33cb52b3a97c0fdcc46e1e9d8fc54a88e687b6100ad3ef8543be5c1e4df987ce188b0203fa0
1690	3	2025-04-03 13:53:00	t	f	\\xc30d040703026fde0969ad371be97ed236011c7766e3a2c31040be685a7bf1344e7673a794cc715a0416f77deeadbaa7e427ea5cf43a65d5c54630956fb81d7d331510dfbc0be0
1691	4	2025-04-03 13:53:00	t	f	\\xc30d04070302c8752b818b7d464160d237014de357c89b34c8fa84dc47e284ece27df2525de5a11034d83463e6085c97b2267d3b75992f745717fc0fd95b4a71fa2893e68c7bef94
1692	3	2025-04-03 13:54:00	t	f	\\xc30d040703021676136a3e78ba0b76d2360173518b0f89b15b2afc904ebc0d52974176e046199af7ffc6d9c5864de44c69e0b21086a51648daff65523402e7b2550f6dd30f4d91
1693	4	2025-04-03 13:54:00	t	f	\\xc30d040703029190bb6491a94b6e66d23701fc4abddeb711bfa528064bf0e822d00e37a4e4d45951f9a85004c3ab69b9598f2a7fb3fb2568d2872783ae01158ad6122660d4851c79
1694	3	2025-04-03 13:55:00	t	f	\\xc30d040703025337357ae5ea023977d23601974366da7889b35692b52fe2fd4b36cc26886d07ba66fa15b02cdc3ca9b1b9bc3937650f83351effdb70f3a3d53a73808b5bc2dec2
1695	4	2025-04-03 13:55:00	t	f	\\xc30d04070302d3ffe4221c837be26bd23701f8954ec79ae27e7edc3c0b8ef5eed3d540d70a9d935b516577e5bcd6d4127a81133dbffd22ddba93aa4d280511b98075ebe9602e5801
1696	3	2025-04-03 13:56:00	t	f	\\xc30d040703024de5a34f5cd4017f7cd236017e735232d8c7f35674a31a2feb1bf549620f6b3349d9d13c3e54d7fa4cc9cfe089c870cac10652041843f6b3db7b9b09ef14b81ff4
1697	4	2025-04-03 13:56:00	t	f	\\xc30d0407030290039c2b492545c07bd237010c4356c49964f75ea6a2cb3ae166d74405119de19753589cb627c53b720fa74b47603fc3c6d4440f05832b21fad891c3320c153f7067
1698	3	2025-04-03 13:57:00	t	f	\\xc30d0407030295bb7507fbf8e36f79d236014f717ad06d00b29b06b4b5ac1236c09ab3f96eb7d94ce05269f1ad09e4e8f08d3a7980baf8129e9b01eb99f160307d1416d12921bf
1699	4	2025-04-03 13:57:00	t	f	\\xc30d04070302e56169f5abbc9be163d237019e1cec1ea16aae5e2e5cd4e9ea5b2c4c9c6fa97cf50085bfc80251ab70521ac34fac8aa0a92c217468c82fe8a990669e0399ab07441f
1700	3	2025-04-03 13:58:00	t	f	\\xc30d04070302a288443adb1c403360d235010e5efe2b6449963e3a5672f15746bbfe9d4a4b68a043c14e1c57d35fc9c39db2381da80ce418b5b6951ef6ca25e4e75cba2fd175
1701	4	2025-04-03 13:58:00	t	f	\\xc30d04070302001bca2af9d4a73c7dd237017807536121a3203559ff87aa19f4d50f24cd18357487c5048251fdce9d54420a166740b044ea18f7efb0c8ee3521916d529c1acd08a9
1702	3	2025-04-03 13:59:00	t	f	\\xc30d04070302b533582afd8ecfb074d2350186e2b9cc0a6d9d0785d9768344cd5df7826f4be9023a9c31ad999abcf29db0eaf1342ccf4bbdf87df36687b83e1b42de8b8446d0
1703	4	2025-04-03 13:59:00	t	f	\\xc30d04070302e01d7b0f1f95cc577dd23701979281c994a63e16cd9608ddfab3a5640036a0dcfa753d5cc969691d28ab2f5f05787a5b9c911e67c0c06cc4b297215bd22f0fd68e84
1704	3	2025-04-03 14:00:00	t	f	\\xc30d040703026a132e22d0a07a5766d2360152701246d6148fef40f21e422b3d1753f084cb0e862954e9bd91f55377089c5392da5007d171014866388789f0869da1f6289ab735
1705	4	2025-04-03 14:00:00	t	f	\\xc30d04070302d4a4de88d9f423da66d23701e74a22970fb3d918d74f3086c26993044e3fe47be542afb6a3d8a98d9e6add05147053b036fc0e82cf78fc77270ceb348b60ecef2949
1706	3	2025-04-03 14:01:00	t	f	\\xc30d0407030234148700e41084377fd23601df9832e8902d4758c9e4cedcfe0998bcdbfb20940e119d74cf1d8e62a533f4722f3c8c9984e31f68b88cfd35168b0413f10b2fc0f7
1707	4	2025-04-03 14:01:00	t	f	\\xc30d040703022d7160d73afcd2de70d2370199c67505a78182e02eba83c36004a2bea71423398c94aae3a25f3e3ba651d70c12c0bf13f5cfba707aeb99750ab03b79aec6fedda82a
1708	3	2025-04-03 14:02:00	t	f	\\xc30d0407030212e2c8c801126dbd69d235012990f67acd7a6c49d4c86abfe54c9ce1d1435385daffcf03d605cd0eba53a3eb0c613796fc90de4e7db0d948ff7a8640965a1685
1709	4	2025-04-03 14:02:00	t	f	\\xc30d0407030235a79bd53812b7cd60d2370174ec0752b63be2f58d171a7b91071b5fa3756baba42c5229aa54141e681dd5050455c844ce136e7ce41dbe6b4efe905f13d015959e51
1710	3	2025-04-03 14:03:00	t	f	\\xc30d04070302e8eab32a4d20684272d236010b9c9010bbddd812567bd173f1dd254957fa4020a87e28a69b252496642899afa1e110764ebe7ce11fb02f2637d28295ae65959d20
1711	4	2025-04-03 14:03:00	t	f	\\xc30d0407030230dd657dc2619cce77d23701f8ef52ec0f842a074c1aa2d9dd84aeae4b67dd58474e04a906225d5533a679a261efdfbdc86716090213eb55ebffa67fd4c7caea6dff
1712	3	2025-04-03 14:04:00	t	f	\\xc30d04070302de97cac9ec5cf7b761d236012751257cfb72b8b55b0d4facbecc7f32b9d9acc286e5478335adf141ad8961e577764257cdf8d6df3276734dab16d1d7e57d955736
1713	4	2025-04-03 14:04:00	t	f	\\xc30d040703027ad95e4bdfa7471174d237010b8c883e36ac19701695dfdf40a9f9b865a6ccaed16dff2ccf141c151d2ebb57f0f98a3f521bef0cfb1366d2ac333f42178b4dc3ba54
1714	3	2025-04-03 14:05:00	t	f	\\xc30d040703023c5960a5b3edcd9d74d236011314591cba9ca51470359495aea939bddc60c00893948fe45dd4fd49b9aade5b42d9bdc0fa37f25f10eb4b185ece0ee58cdeba1ef5
1715	4	2025-04-03 14:05:00	t	f	\\xc30d04070302eb81198351cf0c5a7dd23601fc7bdd9377a4d966ee8c123f31ef3f41342901dab46ceca28bd0b90e2fa86b9327e2d1f43a5b548fc05ab53555d715422d290f7d77
1716	3	2025-04-03 14:06:00	t	f	\\xc30d04070302354220ddd3842cdd72d236016d01c76ce220f2b8d9ff77e907a63ad4fc1922b98466fa439070d366c71cf493986f6a3910435851fec2637aa1257ee8ad29141693
1717	4	2025-04-03 14:06:00	t	f	\\xc30d0407030295db5862e78dd3387ed2370100eb105061409383d1b7413a6c269c5018fc867b79383193dd2ba91ad8898b7b1dc766e840d0bc5e5e9c66c134223eed548cc42a6491
1718	3	2025-04-03 14:07:00	t	f	\\xc30d04070302d09075a29751a14d68d235015aa36aed384fe0c08b62e9080279b6cc4eb157009d141d5ecdf1163693c67d43988df4a97ba6d2f8391e7e59cd7260fb76e630fe
1719	4	2025-04-03 14:07:00	t	f	\\xc30d04070302bbaacc4ac0e7697a7cd23601c1a99ca653ff9ae9784b2f075136a13b06ba85bb55fe7bc8d4dff491808ec43609418701d00c3c1100f683056b4a1caf85debb7b9a
1720	3	2025-04-03 14:08:00	t	f	\\xc30d040703027e16abb4cf9d670174d23601b14602fcd0514688a7c09d25eb491abedf9fa5a81a7d4f3bbe7789d865513ec7cc50c475bf326df316ec6e64bb6c68d8635dae260c
1721	4	2025-04-03 14:08:00	t	f	\\xc30d04070302e3d09408954874c86cd23701cb635a739948dcb7ac997bc2cd2a11f8826043bc63e87b93967540ee734f696475a1c9aaeb0fed5f6d6cfdd5848722dc40de74edc9d2
1722	3	2025-04-03 14:09:00	t	f	\\xc30d040703027036092b8007549e63d2360160dbe20e1539f2d9d1ed404143d7ca163142fc07d316c97a055ccb2b5344e00e1d81386affc26d676f3644c966b4040843642ea1ca
1723	4	2025-04-03 14:09:00	t	f	\\xc30d04070302289b98f7f2d660e87ad2370161150ec009569e7d6fccb47c34c5ddde91c424e8d2b82245b3d8fc0258efe5b9dca10ba23f5bbc46bc2a812e8f4340fbb1533e0126ef
1724	3	2025-04-03 14:10:00	t	f	\\xc30d040703021c55cd0223c8357f61d2360179d1abce2509b5711c64d6432845ecb95ed530d008fac3de869254bd3de04641a52d3f48fd9c53b19e20597d6985acbc1647607f86
1725	4	2025-04-03 14:10:00	t	f	\\xc30d0407030259c5fbfbb503a92560d237017fe2afb4319d51b03b8927c2248a3a322ba8cc44192979db60da7ab58c3b6f005db51e06d0cd014bfb01b84faad602f8d665a0477ebc
1726	3	2025-04-03 14:11:00	t	f	\\xc30d04070302ee23db4d12bac54d61d236011fd5683f3f7fbe1c089168a9989c8cefd139da4967e995b9a1c19d2a5c53e9d3a558cf996841d7f2b17d7b10ccd78e461fc57f83f4
1727	4	2025-04-03 14:11:00	t	f	\\xc30d040703023ca21813b339c19267d236011e7b5db8d8ac4ce5c1206a3aef423170f5d66a30e68c5ee67fe911b5b70bf41885660d8dc36eda5e9adb93c34ff3a132f6a34660bc
1728	3	2025-04-03 14:12:00	t	f	\\xc30d0407030216591022cf42e65d70d236014e5a2d82f1b7ea09a415e40608478bc72eea543d4bf7228764d66f3365eb7c66e4511438ecc3765b9ed525466a1dffc3cc06a66195
1729	4	2025-04-03 14:12:00	t	f	\\xc30d04070302e716483fc10e48ad63d23701378a0540187da5638fc50ce390dbca5bfaefec07d13c2a21fe13f11795e2a4a4558c0b1293717c1db0ce38c0adc4ef2cedb2cd9334a9
1730	3	2025-04-03 14:13:00	t	f	\\xc30d0407030265113f6f1473f3326bd23501d459137c871a5e1a141302ed2c079c4dc6a71b44c1a762658366726eca3e9b8df507d124ed2c911af477b25fb636b4f4ecc2e658
1731	4	2025-04-03 14:13:00	t	f	\\xc30d040703026df6e1ca6f791c787ed2370126f3f4d7f9e3d88acfd5d0c5f6d7296dff3924acbb2315ea44f6e90c7eebebeb540db7f7a12cb655167526d0d9a7ebe479a8e9fb9b79
1732	3	2025-04-03 14:14:00	t	f	\\xc30d0407030207ccc58368b23f0773d2360106b1cb278e3f26a3b8d7b2608f8736ceb5f6d64ff3ae6b4ca2c323001c9d5d8bcee0c1092e573e7a6fa298a261d6dd8e559b74b749
1733	4	2025-04-03 14:14:00	t	f	\\xc30d0407030236b1bf947301ddd06cd2370199add46157de95f92d8bfd00b88913e8608a172d907e3230cb2a4ed18a019494ba35969c1af3069c7abcf5292103bd80611bbebea9aa
1734	3	2025-04-03 14:15:00	t	f	\\xc30d040703020825853f26cdfdda61d2360125fd6b9e293073a354b2806cf5740fe28f2d5ee5c2995a2bf0cf0d15421239504121eb3a872da86cb61bae477dd9b83030734e6060
1735	4	2025-04-03 14:15:00	t	f	\\xc30d040703029ac6bf09bc899b8575d23701f0892fa3897a30fcd3af44dededb671dcff0020e517d3619d87a78a639fcf3c001f2b1c4d7b14bb423e2aa49bebf9f689bcc5007b8fd
1736	3	2025-04-03 14:16:00	t	f	\\xc30d040703021dfe9e3e5c7e11f374d23601ad516b2aa171d2d0bbb13ce782f5f56d18fc94c163c3d37c352fe8397a8b3e541957aa87904e83119015981a248fec152ce72c8a66
1737	4	2025-04-03 14:16:00	t	f	\\xc30d04070302ca8bd010d614330671d237012de1da17e935aa5137b7046e6daaa9eaf599b76b593b1d67e744aa7124a443963133533849d24322146cb88da2d12edfd24a3652c203
1738	3	2025-04-03 14:17:00	t	f	\\xc30d04070302e90337b28d28b24c70d236013118efbbfc8c06ac8e93493ef150d206d92bd732d9286390b172a18bfbc8db5d4a288dc8694bfe13d4c5e6ce1bb5fe87b709d27aa8
1739	4	2025-04-03 14:17:00	t	f	\\xc30d04070302e50f115ac6a230c178d23501ddec84ac438dcabdfa925e2e116435f361f534519960abd413f116517037c5bb5375d2ee0023a70577c86287daddd8b871369407
1740	3	2025-04-03 14:18:00	t	f	\\xc30d040703026fd150365a45946362d23601641d4108aaad997c8efd7508d2d9e3376204d906301995eecfa8007c40b33956348e17e64269153b552f50bff95674c60935ba74b2
1741	4	2025-04-03 14:18:00	t	f	\\xc30d0407030218612af1330b2dd27cd237019b56f92fd62bbf5c294aa4b70fbd24cb23e733dba183b5677ca62b6b51db9fd4d9370fc7a42a84c8775d363079bb69c76cbb484a7f1d
1742	3	2025-04-03 14:19:00	t	f	\\xc30d04070302a770095b3aca2d4a74d23601c2457868b155d9eeeb17276ad897f128ee51c81cdff831fcc70714a29d28da0c38c3a2342d27052766a2048bffc3cde21b49629f2f
1743	4	2025-04-03 14:19:00	t	f	\\xc30d040703029aaf0308d0c737a06cd237014ad086a8c47fb509caf8fead5c7d96f3e9a4772eb59837d95c1225dae3bb9cda7babfc443d5351122ecbeee1951ccef5ca8a55b18cbd
1744	3	2025-04-03 14:20:00	t	f	\\xc30d040703028d0db9c9beb0319265d2350178f77c9673875a95daea387b6745ae522e64d462043be132815c9255c8a971c1bae33dd260cf9f8e0d403a9647c52725a0fc3e68
1745	4	2025-04-03 14:20:00	t	f	\\xc30d04070302dfe99617b2753f076dd237016ee8b5233fe70140e582a721833373bcb9daea1ce56acb39726771989629c9b7a72150e156d60ae102c56d65099ef7d1f386154ebe12
1746	3	2025-04-03 14:21:00	t	f	\\xc30d04070302a49e327465cb1fbe64d23601f33928d8f25d21183b97be837a931568220e31e933786cac33a822f13c2a2f6fc11bc2ad18e77c37367468af5d4157f40a171d7952
1747	4	2025-04-03 14:21:00	t	f	\\xc30d04070302135a6db158e1760261d23701411425b9f1efe7d99f8057f637cbe7e73294025d87ab5c75ae0b3aa27a1a4ca00b1d9d93281410593fae635268547b5deb83a05ecf6a
1748	3	2025-04-03 14:22:00	t	f	\\xc30d04070302b7f2c31acb37fe7b61d236015b7f3ceac84b02b0386dedc6f8f165a82ac1db8fa82bde6cb2b37a7a52c6d4307a6ace08c38f7159de7e638f1a1928456d4b778975
1749	4	2025-04-03 14:22:00	t	f	\\xc30d0407030246f8266770ad14536ed23701c73dd740b75704c1399d46dbf5bf9fb753b25564f401a757946763adb8e054b1b16aa579cdeb15cee0c7d17ff98c7bc683a40264c373
1750	3	2025-04-03 14:23:00	t	f	\\xc30d0407030225d3bc1d29b9af927cd236016a911f81221e2f3f3af6faf9d726177baa9f8faf612405e6b9fd3e2507bd84673fe5e6d5db3c4e90407f025caddecf5daf705d99ff
1751	4	2025-04-03 14:23:00	t	f	\\xc30d040703020cc1cb3ba45aba3d6ed23701e5cf65943b035ce71eb87f0d7d76983d2422d648b4cc2840b5bbb5d39762bfd6bc8ab1668afc288b600572d80cb16d951ca1a21d1f1e
1752	3	2025-04-03 14:24:00	t	f	\\xc30d04070302b6016d936a62b81067d235014a94147755bcbbc407a5e5a111b0d08e1bc8f7aba0b1b0916e2df4b74f7346807ef3ae190b4278cdb7e1fa9c7eea92dc7e54b337
1753	4	2025-04-03 14:24:00	t	f	\\xc30d04070302c1627c76c2faace364d237016dd7c09167d5b4101641627275ce743375622060d18aed0d4530bd000ad95107ee2ed3d4b6ba056f7d4d04caa6efe7caeb6d00078801
1754	3	2025-04-03 14:25:00	t	f	\\xc30d04070302f97901119115082060d2360152e9c3b60b9c03ac956a76c3414fe3a98bddcd979e40367550337188e2abe6bca86da05987326c10e9018db8b9b114b36fb460082c
1755	4	2025-04-03 14:25:00	t	f	\\xc30d04070302162b9c5fd30763d97cd237018f3502b0a506b55e61243ea7e3ed9b777e38e8197f4d9aa9ba7c99f5c0669d71723b3a2d6005ee89d5a8b6a7cc37ea59c3f300c73273
1756	3	2025-04-03 14:26:00	t	f	\\xc30d04070302a6b299790a61059f75d235017628cebf05ecdcf752b2980766d1bf909b291fd31c3630cf6c5610ff0634e313814f6deee4a07a87b15a0fa0f973fa777d408711
1757	4	2025-04-03 14:26:00	t	f	\\xc30d04070302152f2110fff05e9c6ad23701a1dcc6cb439d90a07b95d401b6cd92e6ee01f5356a283047dfa7b581073a6a2b91e088b4bb63a4620abb99a4befa70f489b46c2c2c4c
1758	3	2025-04-03 14:27:00	t	f	\\xc30d04070302e5698faf8fdb15fc7bd2350149e6220ee1054f58b13502872895854fb85e7619281692413803f1da53938be0d59434fa823a01e4153eb5302813007f41b554ad
1759	4	2025-04-03 14:27:00	t	f	\\xc30d04070302d7bb5e7d0b932a9179d23701f14ab2f7dc71a9a4a3060ff68f4dbf0da2b9a1c2f8bbec2b5bedf799d2317d82c1a191439b2f79af5516d070fa67e4762ef7b82148fc
1760	3	2025-04-03 14:28:00	t	f	\\xc30d0407030298421cc676cb340079d23501bc862a20fdc885842c953d6076acfa650a3f7f3e5089f91c9e0768bf4ecd3f7c7ca75f0175bcac72e35a9cbcd46613163e9497f0
1761	4	2025-04-03 14:28:00	t	f	\\xc30d040703029ce992a25b00125179d236019620b0c1cf3e83f5bef2b1351447b1ea7fc9486e69d89e31eb03159d0dd354ee097049e974a667b670ffec704296514ec1262aa944
1762	3	2025-04-03 14:29:00	t	f	\\xc30d040703025e107bada45acc6264d23601e05464f16bea2d90f9d0d28731036c51d29ec6b660ba18f89dc2ca5dcce0fc61ffd7665f2882d48c4e981c6a55c39c020904e4e8e2
1763	4	2025-04-03 14:29:00	t	f	\\xc30d0407030228b2efc2764537db6bd236019c59717c9a24b7a528a11aafe8abe594bcfbfcd4459783873de06ab2db9885e508e6d7cefa921b96147f02b49359a77ccab24c7591
1764	3	2025-04-03 14:30:00	t	f	\\xc30d0407030281a51abe485dd66164d236014e4c2e7655f7aac72f00abc6fddb2efb21403702b09badb39913e47bd1c69d9b7e3f190695069d4ee3110b7c4a5325544d0f3852d6
1765	4	2025-04-03 14:30:00	t	f	\\xc30d0407030230eb99175d248b2278d23701f0f4c27dd04e1e8d20bcc07f42888417aa618bad4348191cb8083ea89bac7da8c39f7c25a612268873999de6d8e5a2cb173e6fe236b5
1766	3	2025-04-03 14:31:00	t	f	\\xc30d040703023a7d40fc090f6cda76d23601766e52e7dc4ceeb2e0f27ed7a668083fca8b87cd3b5010a3d887946fc48de94a06e8e0e768fd2885771079e0a3f428fc801ae81d36
1767	4	2025-04-03 14:31:00	t	f	\\xc30d0407030277bdc50ad16e6a0163d237018f61094a6a8aa44186e462dffc56cc96bea54581660274415e0873e31526aea74f7627ce0b7698fbf17284cf00e9f2475ebcbd7fa821
1768	3	2025-04-03 14:32:00	t	f	\\xc30d040703029c40fb59b22fbdd97ed23601f0344d4c6b8417205328968caa98b26d51f329a6bf0663af669558c9579881144c2f4f714ae03861a66df0f3f783784dcec1659591
1769	4	2025-04-03 14:32:00	t	f	\\xc30d04070302222e75b0121db39570d237012fa4f986294786a01f4aa8e5eba0750e295000e8bd327bf7a77ad8cfd0788f8ae3a554a8a9fd16125d6ba4440dcb240b75ec8659cf0c
1770	3	2025-04-03 14:33:00	t	f	\\xc30d04070302ac9cfc063a0625d060d235016bc1b0767069a1664baef2d55acd9a740cf94324dca484c93a2d8e9f8721916a8fc27c21add9afd1891d0a4f8e2da8b9ae9fd970
1771	4	2025-04-03 14:33:00	t	f	\\xc30d040703024beca82232a4b17067d23601ec527db2d49ecb575d762f06e17000088a5f49975f4b1f39a99f417a6e155cf60606a8c7f67a2d7c270fe09e2ac114ff0fb90e3f30
1772	3	2025-04-03 14:34:00	t	f	\\xc30d040703027648adfd53df067d66d23501cc6136ce86694ff370ba2d2950e40702e87ee97a93f95bf0ffe7d6a2e234baa2c59426739a1be2e9bc7d2752176157f6ce857623
1773	4	2025-04-03 14:34:00	t	f	\\xc30d04070302bbf846387ddd046370d237018796610e1a32cae9b30b10277a659fc3f6955de135d93933793b7314f05859f5daf2a24cde6869091f78349fb56b149968a83da2da24
1774	3	2025-04-03 14:35:00	t	f	\\xc30d04070302ba66116ea5e10a3463d23601ca59931fcd1791c2578b54821de348088b2b3c94d4dbd3159cac2134f90d05fafb52fcd5232bf60866abd44f47e456fa4edcc286ad
1775	4	2025-04-03 14:35:00	t	f	\\xc30d04070302b8a426419c314ca877d2370156703d896b53cb73acee7895c8d43c96353fd70b4b1f5c84e9c4b519b6dc31fcb01278055745e86ed691f2c9983142b9bce6d140e138
1776	3	2025-04-03 14:36:00	t	f	\\xc30d04070302735fbef252b066dc79d23601e6dd22d9bc74f9c5c04904e5762bf87aea76f8b5f6594647875741e03c7dd1baaa2de4319b59568733218a38808beaba7d81dade80
1777	4	2025-04-03 14:36:00	t	f	\\xc30d04070302f69955beaec913f473d23601738fd83f8ceeea1111e75968349331ae8fbcf3a9a04c9ae823a455d83a9060d5432f7433958d86a7e46fe06a85c1c64f4d2e001880
1778	3	2025-04-03 14:37:00	t	f	\\xc30d040703020ac878c8ab305e9b6ad2360153dc8e8299daa0a9b1bc3c1628ae3161f4b0d4a34bf951344e821dd18fcc99fdafc54a9494879e05e9673b3c75b69ac93b4d613531
1779	4	2025-04-03 14:37:00	t	f	\\xc30d0407030211bce76ebb4cb6476cd23701f137a404d5b030818c55d875b818103f729bd14850c2d0901ed6bfa13f27ac54bd54cfb7a56c7415e4885d9684f7a5684140bc3c1b4b
1780	3	2025-04-03 14:38:00	t	f	\\xc30d04070302b4e6999ae62a35796fd236018b4e7b29917654901384c20a7555b482ff3f722cb148ed0d3567ca63d5eb954d6d6e9e31d604eb51c975bba009de8333547954a0d9
1781	4	2025-04-03 14:38:00	t	f	\\xc30d04070302621af7d47aac704f6ed237012ef654e37692c48e841f9db8874d18ebfcc85e2aa83129c667d3cc69c8b149f56723310903f43782548743916263242aa082daffaa31
1782	3	2025-04-03 14:39:00	t	f	\\xc30d04070302b65850a0955044f863d2360145a64fcf58ebec95abedd61d98266376f32dda7520b6051d6f5558762715ba18e5a1c7e6ace9797b63dc73ca3778d516b4078f9d0b
1783	4	2025-04-03 14:39:00	t	f	\\xc30d04070302581e89961dba76bb70d23701a14489acb458e3fef78e37f8fc3e57671c99b95ef675335e7031fcbf70a80ee91dc64a8eb415c23f990689ac80bfab760acf4fb5f33b
1784	3	2025-04-03 14:40:00	t	f	\\xc30d04070302bfe4aed83b09804563d236019383aaa68e19c5abe301c5d3421fb9e255a77a087835f70eeb98e7eb5f60912da8dcd5730b034b273cdc675d761b1d0e0f5c7e098b
1785	4	2025-04-03 14:40:00	t	f	\\xc30d040703023445c0e3c551791179d2370112d2c1bcc2b7b609c9a6649ad69841b870693e46953d6065124d0b5e15c21f43f60b0fd80e9a0dd32c0ad4170c8428e2619ebca99786
1786	3	2025-04-03 14:41:00	t	f	\\xc30d040703022f23a20bea64216f6cd23501a90d41f30de94cbb23492801f41ef139a87da95ab720fc380671bcae50c34bf694894ca5f21dc275eea6204aa1450c2b4a515ff9
1787	4	2025-04-03 14:41:00	t	f	\\xc30d0407030201a5227cfcb1ac4678d23601f7e4b18e7f96aa3c0265ff771731776c88274cc5e8c199a8809f86736dec2b237c3e12c51a3e424e58d14c741dbcc23cf034315175
1788	3	2025-04-03 14:42:00	t	f	\\xc30d04070302c600a3318b22b5797fd23601d090a2101e0bb89d63c3e747d392b05e50efb82edd60408ab2fda66ea64d036a23d85aa3f3f2ca4381f5fd79395238b2a3444cc9b4
1789	4	2025-04-03 14:42:00	t	f	\\xc30d0407030288fdddc0882fce0b6dd23601c949ad81b3226f0a265af2c6b2d07302745ad28850ec19e8496672cafcf2b84f8f64c50a84ea27dfd4446a5547d6a1bdaf1c4bdfa5
1790	3	2025-04-03 14:43:00	t	f	\\xc30d04070302470c5cf4b6dfc0fe62d23601b1bdf04db4ae8e0bd38c086dd1f1e8e3b7a9109c0d7081517d6b4b9c82af464582bbdaf178fc688832a0139b21f808c706dc3b8012
1791	4	2025-04-03 14:43:00	t	f	\\xc30d04070302df4d41eff8b8f7a26fd2370153aa943ea0bfcb4ddea4d2993962208271cd02be1f7e05f5145685ae48fe2d4ade0fff8fa065f673ea398a414f4ac2369ece68065adf
1792	3	2025-04-03 14:44:00	t	f	\\xc30d04070302c7da0629d2c4150266d23501ca458ba3056cb826c36841eb84435d503d1642bb5e72c7b49cbdc1d3a045c1d9c84f5e92b89d5fe8608f4c8a0fb3f5bfa0057f05
1793	4	2025-04-03 14:44:00	t	f	\\xc30d040703022ee585be9f9a49ba68d236018e2c3534917a95fcb2dbf8b22edb567077e848f1ae76cf5a7b4feae6bdad565d1f8381e7fb7d802f0605784fd4612d70d73bcebc02
1794	3	2025-04-03 14:45:00	t	f	\\xc30d0407030266a6fa1dc62bb0906cd236011734056c2863ff90b74ed071edaf0c6563988497beb1fa644d101157f232dd529667973a1cd87a21eecdad2d6f2dc904565c9832c3
1795	4	2025-04-03 14:45:00	t	f	\\xc30d04070302986b6e43af8fc68468d23701b0b4af144476c2d22d07d9c3e89354df71a099ef7059929f8fb7a26d2a50770b6f84f23c0170af9d50d2811816db3e4faabe46f048bf
1796	3	2025-04-03 14:46:00	t	f	\\xc30d04070302103ba1aa6c82a34b6bd23601326ae257a4dac8cc44219d6b16f896ba7e75df9abd67186b435fca15dd0cb9ed64744df97c1a6f2b84d32c0d05f99a922bb8b41c4c
1797	4	2025-04-03 14:46:00	t	f	\\xc30d040703022164112880a648d36dd23701bd821b264f302cb5d8b246822303241007d4254d989c15578c9ace978747835751bd044549e9f49dc5093beee336402f6aa67275cb5a
1798	3	2025-04-03 14:47:00	t	f	\\xc30d04070302a60698b7d973514d7fd23601c50cfe6a8c589c42a884a08da11becf2202a5bdcb53290d333a1b8e0010892b8dcf883a9c06020982ef38bf4863d42f069ba52fd71
1799	4	2025-04-03 14:47:00	t	f	\\xc30d04070302880bff7ff4947e4b74d237011baa5c328274562fb84b17dc13cd17684c3a17cce8f0eaeacd60fa3fb32ea976f878ebc5291c6240a1917a7977109a1bf3fadd290f85
1800	3	2025-04-03 14:48:00	t	f	\\xc30d04070302d3341d9a9c081a9c66d23501c3bce4798e9336b3cf5ff956d60ce561245035d017b9abe7cba3e80363b2f71612dc054e8b7981313a49115c834d7484e0688d13
1801	4	2025-04-03 14:48:00	t	f	\\xc30d040703025ff1a75cdfd6aeab7fd23701f7e158a7b4b642b03c40c150553b06a3aa8a49e82149b9c1646644102c04c4a98b3f69368b947f7481f9b70634d05207b02647f7bd43
1802	3	2025-04-03 14:49:00	t	f	\\xc30d0407030228432a5dbb804cfb60d23601d672beb449387b619897c575a73b5b7a3f5d6b68e2ff5532bd4ee99f8ee097eeda5134f1e99d570d8ca0187832652c8e0b77312bdb
1803	4	2025-04-03 14:49:00	t	f	\\xc30d040703026c92b7614c95f19f70d23501b363fbd39093392542ec5d100ad4ebefd5831b74110d32a4fa306e670211e20cd934c00f06b87416e6ab30d668c064d3ab7a0c8f
1804	3	2025-04-03 14:50:00	t	f	\\xc30d04070302a8b6e09d66a9c4e768d236017c1f215b551fcf569b87e76f115f0ad1785a8c997ffabd4fec3e5bf8466684173054683ca129a32280263d69898101558f5f963dd0
1805	4	2025-04-03 14:50:00	t	f	\\xc30d04070302e541bbfa7c69dd956cd237016fc8e0233aa58d043d527d163117e6f8b0c6f27dcb4ca07897846856a53eb9ed5314647fd1ad9cb7240b817c20a8869a10f85e83a5d8
1806	3	2025-04-03 14:51:00	t	f	\\xc30d040703022cd35bade87df52a64d236016dc7e14a8f592ca12e84f3887d1626f9d40785f61f295705bb07bc7df464db225f91e1605f713f640313b110ff062a1dfbd05b2cfe
1807	4	2025-04-03 14:51:00	t	f	\\xc30d040703026ee5343a4390b0786fd2370175dd2981aad78064440a0f21a6a1133dd2510856eb84bcee89c9d29f1d15721624e1ad19e8606f8d51cdf3c2918b14bca0bf0bd04bee
1808	3	2025-04-03 14:52:00	t	f	\\xc30d0407030218f6997da8d8521273d23501c95610f7c3b9bd1903ee9ceaba3352e7608c3a6feaec9206768e70fea6f1154e046110f0d0cc3a4a74a41142d7cb2b628286baf9
1809	4	2025-04-03 14:52:00	t	f	\\xc30d04070302be15014008ca0cf27dd23701c7d75d949c4c5ad366dda2bd507a7c3379a4da1a70f3e98b22013e4e9165b1c2c10c5d034542544759f5637627c627dea704ed8d23b3
1810	3	2025-04-03 14:53:00	t	f	\\xc30d0407030207d51a9f83010f1c77d2360150ef29e0e35ef551f50359545ce1aa713a16d29c5021217a5c294671de3b4280e19d4c9849fb1c7a1ad71d4d122e1227a520e113ae
1811	4	2025-04-03 14:53:00	t	f	\\xc30d0407030274432b23675b84926bd23701b3f5f6f74c0489980108da3973ad22f705f65262020c47c8358fcd6cdc20879b01af7ff47183a861ea2262c134391961393e433caa60
1812	3	2025-04-03 14:54:00	t	f	\\xc30d04070302c1f6c6fa0a841fdc66d2350127b49c022d3bfc292e8e9f5b2c19456230cd91315b475be167f452e4dd4ef9f69e0a044c00ba94f2249249718bd1e4033db69d24
1813	4	2025-04-03 14:54:00	t	f	\\xc30d04070302d17d7e715b3c315d6ed23701e93a25ecf27c3dfe2b68ba4ac052e70eaab213869c2dd575d1f801fc57815c6a151717a413034a71a0511578aaff31e20291ae81d9b0
1814	3	2025-04-03 14:55:00	t	f	\\xc30d040703021273c70c4fc6fcff65d2350187567d716794eb213a5a2a8ab25054f8474845738a0323ba5cdaf7ab4498c3445f8bc4da6923b3b9da96e3a396dde8d7593117b3
1815	4	2025-04-03 14:55:00	t	f	\\xc30d040703027e753fd33a2c308e71d23701815d66ff1e7f690a5a39d282a3e6fadde8ea5f5e5c87ad254b4ee3bcf52894a305b8052c1f3c8119f1b77b3917817edfb5d38f8572d5
1816	3	2025-04-03 14:56:00	t	f	\\xc30d0407030265e92a852155bdb57ed236010e3944ec956560fc8c1ed50ef1593c3ac4e8a68ef763bab6d2dddac8ef06bb3a7cb05676b8ea168f882d9b5d8722b5fcdf0bbea176
1817	4	2025-04-03 14:56:00	t	f	\\xc30d040703028a2c6a8b56b9023e6cd237019fd541192a568615e4fd1817fa4c7f03259f0cb0d7d4a369982200ee38e12fff67a6d34285b0f930058288611a9694698d453986e23a
1818	3	2025-04-03 14:57:00	t	f	\\xc30d04070302b2191292232422e87bd235014f65cfdfb37a92c9ee849629c2166f4b087e69a6a584488f9a97fde66f7d6991fe0b651c04edd44e73ff504c2b3a869e912f2199
1819	4	2025-04-03 14:57:00	t	f	\\xc30d0407030263fe6bef7b636d9268d23701a79d8de9200982bc88eea9c008eec0ec45ea6602587de52a0e74cf970986bf21d408bf41a217eb4a62196c03796e6a868c6b7022a2fb
1820	3	2025-04-03 14:58:00	t	f	\\xc30d0407030220235ae988d6deef75d23601c753a0db1231743608b4bd1dd563166242ea79d976217ca3066c96d3040099d3471ca20240b22b4491e5e075b97167b560292fc243
1821	4	2025-04-03 14:58:00	t	f	\\xc30d040703022152701ef10e470c7cd23601151503ab6e78a63df614e64f96dc0ae9c894089228cd7544e0d5864a74c5544570a36408b80031365a5967666a804a8a26562433bb
1822	3	2025-04-03 14:59:00	t	f	\\xc30d040703020e0f70177662097079d23601f578ccdc33b38651497c561f7fd0d67298dc029764ba6a6630d55ed076812d3f1ddf1018871b4fdf2f4c1f60d3093f05cfe05ea98c
1823	4	2025-04-03 14:59:00	t	f	\\xc30d0407030292d8cf9c18f3bea977d23701e00ee270b83425842af15bbab84fb73b36d4e81683d755471591712641bcaab01d06238e7ab840a2d60382d1c58d4f49690286798f0d
1824	3	2025-04-03 15:00:00	t	f	\\xc30d04070302d5606d4f25cf90b46ad23601f1c9c881ad026849d5fef4a032ca2260ce01f3ab52228e8747f0f70380ccc7756ec448019ea65201916f3cca1f2c7a67ae43fe1827
1825	4	2025-04-03 15:00:00	t	f	\\xc30d04070302b60259605281774677d23601a37907636fa4fc1b695cde19ba52ce4ae478d13f047af74f135ad6e37a06b3090433e226583f1ba09af949cd76afe1d52c64043c7b
1826	3	2025-04-03 15:01:00	t	f	\\xc30d04070302be4aaf94a29174db72d23601f8b1132fd7abbea287ad3ae5952cae865a817088cbad0fef42984ae19f2cb3b0450ab8a7c00a0b5298067b7983de244879aa5a940c
1827	4	2025-04-03 15:01:00	t	f	\\xc30d04070302969518974c5dc27574d2370169ff75c5efbc6d997e19e69078841b0882593a932978ca3ba4b4df90ac10b8e4faa7f743ad94483ceb5afccafd102378a4fee4a02897
1828	3	2025-04-03 15:02:00	t	f	\\xc30d04070302d57ded38bceaeb3b7dd2350155d2a296368235c9b80409fbcfb5532890b56796cff308297d43a707e516d263c4057ace775a466fd36620a4db5a9c1321f8f73f
1829	4	2025-04-03 15:02:00	t	f	\\xc30d04070302f1d81c0b97f0d07d61d23701c1f6827f4cfa20d0d4f1238b74260b91b455425619c93dbc9da132b8a5ad75f7e2b31ff807cf16bb1c192d2f21f16dd5a45d529ff936
1830	3	2025-04-03 15:03:00	t	f	\\xc30d040703024b7542840f9c717068d23501fd400140e426c589e03a3f38aaf3aefeba40e66927d5040c6cf9b0b373ea40cbe5cb01b9ea6ff673f1fbe20220b3f01e921f6a6d
1831	4	2025-04-03 15:03:00	t	f	\\xc30d04070302072828f101bebb296bd237019231f2541331a40d00b69d3496bb77d272475d234c43c13d63c7f2ecca3902c0b38a6f2043e773046c05c22c08a20ed5362e54ea3f96
1832	3	2025-04-03 15:04:00	t	f	\\xc30d040703025dd65a071025aa596bd236014a3a24004c2f0df2f0591880c3e480b5d40392dd2b6deeb79790962fb6a616e3a1bfb0abb537e7c14a621fabbeef81cf687d46202b
1833	4	2025-04-03 15:04:00	t	f	\\xc30d04070302dc9e32184d239dab7ad237019ae8fc3f484382e92de8b0320c90964145711a2f089a76e923ce51a7ee552691246261374a56a4a669e831f63a8b9cc31ca2a422c04c
1834	3	2025-04-03 15:05:00	t	f	\\xc30d040703024c04e42cb18391ad77d2360144073bb76240fb5ef77b0e7c175dff9411703ac551eff06f72f4b1aad9404e9d078403ca852d87e57e850bc8be3569840c1ba3569a
1835	4	2025-04-03 15:05:00	t	f	\\xc30d04070302c8c5d07027f9b59464d237017527189767dca18e195b1c595796f3d837954a38ef3f333813e68a92e454203fe8ea51d77177a40ce410b08284b236283f88d4112751
1836	3	2025-04-03 15:06:00	t	f	\\xc30d0407030204b804f53e5c7b3372d23601e71b3a11c737b3866749bc4709ff758d3ce9a74dec944f051a1e559d4300e147f422d3b3c1b68508738db13419eb1124169f57f954
1837	4	2025-04-03 15:06:00	t	f	\\xc30d04070302197dc889adf6765a7ed2360100c6c94896a3d78de49667376de13659c3ba62ee0fc48c885b949bd88e25dbe9f68712fed6341c5fc6905da0747c1356a070801021
1838	3	2025-04-03 15:07:00	t	f	\\xc30d040703021adaaeaded1ce9c170d236018c8ab185b59b7e539a4545739207e66679057e69a044707a6c2be1e43905e079dacbe42ad7b54dd6128abd6018f7f9ccf1014e1d36
1839	4	2025-04-03 15:07:00	t	f	\\xc30d0407030244212920f859ad1a62d237011100451eb71ccbf97fb8e32b0fc818c85dbeefd82a9f4b8a3a36c2be2cfed67c982c5591492ade83f36c132664a778f04e3598d24876
1840	3	2025-04-03 15:08:00	t	f	\\xc30d04070302c7040d64fb7c128a71d23601aeba5ec16254d348cecbf5d2d30f2c19aff049495c07ccd5e0245d4d6af18669233ed79e8bf1f147aae7dd91c11702764fb8b0152e
1841	4	2025-04-03 15:08:00	t	f	\\xc30d0407030234fbf3818662c4046dd23701ec04cb956170fc010051b6c68b8a1d862ab284b9f281b090b1acbbec0d041841e8d86c96e3fae40efdab8e1f12a28960d163203519bc
1842	3	2025-04-03 15:09:00	t	f	\\xc30d0407030291742fd235b1411c63d23501692050e59d7b3a19075e0cad6d21438e215eec0791ad9a81f865f47a59d063ecbc6ceed6f16b86c4f6b6ca4248633eb0a906bb96
1843	4	2025-04-03 15:09:00	t	f	\\xc30d040703020b94886d8d1152f87bd237017212b524912a63e3fcaa293cb72785995249e8425f43ec11192ebf815a1070b7542b9db87ef161046e9eee87329a4f07a11f63d600ac
1844	3	2025-04-03 15:10:00	t	f	\\xc30d0407030212d45b14f39b4d447fd236014cfbc54d65d36f928e695fd7f8692ef5ecfca6e27d2a9adf880be78dfcf62375c8e69ef54d39f81ecd4e0a5b9d552fcb892c0c485b
1845	4	2025-04-03 15:10:00	t	f	\\xc30d0407030294bcc29a7c17fb8a69d2370107d820df0827707e306928f8ee14922a9dea5b2f79101eb08e73c3963b1567da17df33e6dd0c86a647e29275de5d676a26fcf8000d6d
1846	3	2025-04-03 15:11:00	t	f	\\xc30d04070302f288be9df1d0372d7cd23601ca4f41332a1ce792064c034d12f7a1540fe35b819896d363542d54c3265abdc0c84819db6d5a35545ea6b7f539225d470ddf7a4e75
1847	4	2025-04-03 15:11:00	t	f	\\xc30d0407030255b22bba78c2eb1462d237014b20797ce9eb84c4d37a0e5aabcdb872a33d6f1042f9ee12d4a17633081ec2e94878bec0c85055a2fae36a06a8aea8709d18db248824
1848	3	2025-04-03 15:12:00	t	f	\\xc30d04070302e7a555bd132f09e974d235012d4d9068b64efc22eeb2cc587c2b42a1c4c11ce8e1df7c980de0c922bdd4c4b33e3174278f3e43ca87bc1d8ab13e5499d96a9430
1849	4	2025-04-03 15:12:00	t	f	\\xc30d040703029ed3c41f58b8ee5c63d23701e66254d8f6ae63637308f5be8f4759ad7758874be3ee816a6955f41129b69d52621e55cd23fa73f9852cea01a5dc36914c25d8126fcb
1850	3	2025-04-03 15:13:00	t	f	\\xc30d04070302d2604e16c7587e516dd2350119a423999d93f49fc3f19a275936e7ccc423854996d3aad6f311dbfe0974bd2c811a33456ff9209fea8f86e0c02bfcca46a6a140
1851	4	2025-04-03 15:13:00	t	f	\\xc30d0407030240dbe017e0ea48677cd2370167af88351864b79565b8ff1466a0635076424d9c0650ca3cd6bb326b928a91c35357a32c4a07537e19f84e0bb0d5e397ccdc2cb070d6
1852	3	2025-04-03 15:14:00	t	f	\\xc30d04070302dd902da8a80e1ac660d2360187e252b801e18510d7360e9197035fadf1eb1463bd052cd2d0e92b7ba3f1ef856840237b82ce9674dcbfa5b86a6e9284c641afdce6
1853	4	2025-04-03 15:14:00	t	f	\\xc30d040703022d623db6c572292c7fd237012465b14de0e6748d9e83dd097d6e965f80f90b0ec21f37c74a4eaa9929ad5036ca2754a0bfd4d5cf5f396deb91fde28cc20db976fb6f
1854	3	2025-04-03 15:15:00	t	f	\\xc30d0407030280d00b0eb96c924868d23601c6f5cb518351d3ecd4c66a8e11095de77ec25ff87efe3335e079606e5d3fc0ed59f99a8125aee1db6961561eb71f805240a84803bb
1855	4	2025-04-03 15:15:00	t	f	\\xc30d04070302e20359994b8954a66cd23701c50cc438f3c0f5b937b563bb0d449bd8bc5d7676196224e0ee50e142c642b57abf03d7b6b9862a2b0853784b972a95edfc39a535b5c2
1856	3	2025-04-03 15:16:00	t	f	\\xc30d040703026d4dc77fd3fdae3660d236010ada4752a1e18f2771d298170482a3c8b943b02e4c6797f49d7dee87bebf65b7c521efbc4b3f90d0b953140026821aef67ce6b4af3
1857	4	2025-04-03 15:16:00	t	f	\\xc30d04070302acef669abe4b013d61d237010735996feff3cad2e4d3c002d3e46835b883731e3a75a6108a5a0eab6fcce76cd8d8760ed5bf028c0c2b0a71b164beb2c402ef2ef94c
1858	3	2025-04-03 15:17:00	t	f	\\xc30d0407030289e503ec85d24a4977d23601c56840d8483ce0ea99de900ab8e0a11febd730ed3896d3abefd5ffcfec77de00ed24ac9d14e85d0338f5a48bcdc1578bfb8d47f5da
1859	4	2025-04-03 15:17:00	t	f	\\xc30d04070302351ab8fb8c958c8f7dd23601a4b9a07206aa3ba949343095b55c79f9a696dbd5e0c0200125829dee4199689e54a30b2995e17d92564476314776b4d7e6c5f9724d
1860	3	2025-04-03 15:18:00	t	f	\\xc30d04070302736ae4e274d2063379d23601faa311680538fa1d690ef3b5b7fa51492d3f40d33eaefd0783904ba062610ab5f913614f17a7c96cd55482f2c44d9fef64f5e7df5e
1861	4	2025-04-03 15:18:00	t	f	\\xc30d04070302fcb9d9a71b84d0df74d23601c040fccaf1f08f3f31103537ed155f150b47871a1484216d335699d6f277e15761f234e55d90e836770e98ed8aae77dc57b15fdb9c
1862	3	2025-04-03 15:19:00	t	f	\\xc30d04070302f3d4cfdfe7cd53377dd23601fbe1b0b527e09828a3394d112b64b2e03214b33daf623b10713ceaed7265e9320755e852791b82bf95b9b9a366eca9577d13a86174
1863	4	2025-04-03 15:19:00	t	f	\\xc30d04070302b42d2dcc1b746a6274d237018d1cb8426d6eff7a8c5692d154eed4594e87f84df145471585ba3fc3f0601a1c3a30fe577c179a18672b8d649af422def61beae8afcb
1864	3	2025-04-03 15:20:00	t	f	\\xc30d04070302040c57de4a86208174d236018aa5318d755d1aced3ea81e8796344732d3f7e4a3f42b433747c6b63faf13bb3bbd0c6d47c6c2d4be8ce72a8e3201bd062b2b3b7a6
1865	4	2025-04-03 15:20:00	t	f	\\xc30d04070302441874fb8b0a7f4d7dd23701b84b1a9a0a8954c02ceb46e107b52fb43b199b75833f24cbf318d0ea621594998e4ecc5613e25242ac123655295382e6605ca27e7c92
1866	3	2025-04-03 15:21:00	t	f	\\xc30d04070302505366a4d759f4ba77d23601dbde0dfb58ac9d3bc6735eb0556531c17b7cf2303149d1d1665417d14b2594e9a4b2bd1c469cf372fb85fb90ea6f803d2ef014a407
1867	4	2025-04-03 15:21:00	t	f	\\xc30d040703024a2373dc8377f90471d237014fd530dfcfa8306009b7b5a4f57a1dd01f158c1b9217ee1cf546c853a0172e3f151b27adf9feeafb81c2eb1b0d1cdab3469eefaea7ba
1868	3	2025-04-03 15:22:00	t	f	\\xc30d04070302ffc71b7d9156bb9c7ed2360103a19e00b098d62a8e2f7b307a5bc674ee273b577ae56d51392768e6b204ffae2ef5ba8b4738f88332b81760f84b4c07facc841417
1869	4	2025-04-03 15:22:00	t	f	\\xc30d040703022112bf1dbd6bf3ca6ed23701f93738cdb9d525119b8b71caf4eb95e000697f7d41f56c65616c84914fb56d4c80f510e4bf53a4242cd256c305154aa1d905e51aaa94
1870	3	2025-04-03 15:23:00	t	f	\\xc30d04070302508a3ee1cdbfcd8069d235010c606d9221abf9b9a1b88d4d75376e22e2f999fed9b0dbc3ac991dc937724d87efa520f45ee70d388e6e3ee67b4be8751ccd7552
1871	4	2025-04-03 15:23:00	t	f	\\xc30d040703020749dfe23180f0c972d23601e406cb4a790e75f0b22dc4dd2b29616155b6a99ea7f09d73fe21accaf042400da58d5babfd8ed8c0e304f06da5725eda127c487ee7
1872	3	2025-04-03 15:24:00	t	f	\\xc30d04070302510eb90ffe9becf170d235013cef5b9988b837ceb41176b2a12f1685ebd7028b589abb5bdba7bdf6836201ea5f917fbe6cfcff5229a0f5709461bd463800d558
1873	4	2025-04-03 15:24:00	t	f	\\xc30d0407030223e9b15283f3b7146fd23701b96a93dbfa59420132153ead70d0a80aea02eee7687cd7d7b90fb2b4f96143ef308d6823425d386322aff1ac841fe97565f23fe75fbe
1874	3	2025-04-03 15:25:00	t	f	\\xc30d040703022894220766a35fe56ad2350133f2a7eba2ce14eeedaa5cd6be5e92ca4d9370f155b190845fd876d899c2328d232bfc399bc20e9f012724cbab472dac7e456023
1875	4	2025-04-03 15:25:00	t	f	\\xc30d040703026c60f49aaeb04b137bd2360108afcbfbb7e49148980c772c71797eab2738e889c2e03bebb45f2fab8a85f93b92a3ce8e1554b51acf19ff8b90af4141a452138b67
1876	3	2025-04-03 15:26:00	t	f	\\xc30d04070302f98c6ecfdce0469274d2360124878d8369d233882f0ba1a6ddc905a359936c8283f77cc6e21aa4486c052b982972ebdaf1a084d1dacba4273f08d6a848f87a9c00
1877	4	2025-04-03 15:26:00	t	f	\\xc30d0407030212f2cb32b71a1a1a68d237018afa74ac4cd23a7567b6d629701a02678033a622ffeb59f9d3bdb3152b3a5c331cb45b6437ee4b3ac32c604dcf52d7d85a85db99ebe1
1878	3	2025-04-03 15:27:00	t	f	\\xc30d04070302d11be10d99d6de7a79d236017bc5aee8ea81d8b097110eb538f753e08d615b4e2c38470ce0d77528ee047173e9c7bda273d6db9a412462e7b197a6facadc74e4cd
1879	4	2025-04-03 15:27:00	t	f	\\xc30d0407030292cea3a8c957f15b6ed23701b9b26dbb345d59dd08de7ed5c0b311938ec5bbe19130cdf906c3c064091a28fffd800f5a4e43a10dc5faffd3355d4df8d7e39a748bb4
1880	3	2025-04-03 15:28:00	t	f	\\xc30d0407030231f8e8bd1328d52c7ed235017d788c3fac61e3225d8b5a10b07eb372e23eedf045cca51bd544b83650a6e1617f4f34e060eabefbff3d590f5acddfed7dcda347
1881	4	2025-04-03 15:28:00	t	f	\\xc30d04070302f3c4b7a2296aed6975d237014bddd7ff2f8a28bb4b0514be4c2d73e23f543d098708cffdde7a56a77af6dd8e4aea40f4e9c4896b8654e1500ed180bf8a35dd9d1cc2
1882	3	2025-04-03 15:29:00	t	f	\\xc30d04070302b39a387bbe190b7e71d236011f95787fd0383a9193526b68fb6e021a39520caae981e6134828cdc4fb8bb675efb56c739e1e0265ca2eb169f4bb7bc47a9c7f3820
1883	4	2025-04-03 15:29:00	t	f	\\xc30d04070302f803feb3cfcf9f7b6ed23701d34cb10fecd188be09db4523bdba31ff294fb47b3c9cf2a2339642617109f117117f18a02d4f422704d0423195f36500a10e0176cc7f
1884	3	2025-04-03 15:30:00	t	f	\\xc30d0407030257b54de1d54a99446bd236012d697d716e57edb1cfe5fc06970bd5a21ccce24f5e135eec4165f729472e3224a54c80a2a615d89aa38e4cfe816536ebbb7005abd5
1885	4	2025-04-03 15:30:00	t	f	\\xc30d04070302a78ea7d13f803a1069d2360119109b3780fee1d82fca3327c789852b04c40fe0bd45c12f10c89d9903a5a846875173ea7c0b36a7fbdaa312e59dfafa28d79cc34b
1886	3	2025-04-03 15:31:00	t	f	\\xc30d040703026e8df4277bba6acc7cd236010bb48a9afcafc754dfce0019286682321a5ba825063507028b007281aa41d42313182e5f6519b34c89ddbf18a99b759a431ad7d82a
1887	4	2025-04-03 15:31:00	t	f	\\xc30d04070302a2889e4976a41bc873d23601057abfed23cead79625646bcc8138082862397663cbcc014cd84e0b6eb734211eb5639bd2b82724cdd03498162ec5efe05f9ccf487
1888	3	2025-04-03 15:32:00	t	f	\\xc30d04070302c707fb5fd0e16c7d62d23501756040e383a2c8eb1e2948f45cac4562865e8dd8bcc8008c5ddbca840a9978e4d0cc37d0a67e9764732549a280a3caa6aaf83c13
1889	4	2025-04-03 15:32:00	t	f	\\xc30d04070302fa76c00b11de656177d23701bfec82c2c88b335cfac59902a9964bca8acc2f087752010c929f1165bd483f23da8aee450b368357ce5de1fb5ceca0c884a40f399b53
1890	3	2025-04-03 15:33:00	t	f	\\xc30d04070302e7dac579da34558b65d2350109965c5baa22535d50f1de269a2dddcb3b680480c4d75fd3238ded063aea8d20804ee8f74628623aed16ad5bc9030ab02b24910a
1891	4	2025-04-03 15:33:00	t	f	\\xc30d0407030260aae0b97428d5ef6cd237013c361353ab4726e29d54c91454fa63717880945060ee933fc893149b2abd64160d6f7ce3d06af59ae1a80bbdb40bff233df9cdca7ec0
1892	3	2025-04-03 15:34:00	t	f	\\xc30d04070302a380bbb146731bc679d23501f9fa6fb34f06d09817cf940a3b899baa7620ac331875e05e5776cb0ef3ce501b25e755be5158152c875387adf4f6e71e7aa7544f
1893	4	2025-04-03 15:34:00	t	f	\\xc30d04070302f5b2351e6c3118546bd23701cdfa96c35a70c668dac1a31bed69774beb88c4abe08249cd8a5773f80ba2987768ed6f925195b4988289c3dad73d9061d5e73a97e5b8
1894	3	2025-04-03 15:35:00	t	f	\\xc30d040703021013fa0a7a4947537fd2360101d8c949d2a80822a1767454da5356fdc21462367358c7cef38f0c5260f4389986f4f343b15d585124fb667fbef71bb178a235815f
1895	4	2025-04-03 15:35:00	t	f	\\xc30d040703024b6b5219150c223077d2370192ef34ba5a855ecdbe10bff8f0b1cdcd73c083588df648d5909058e79ea3f06f73552180394358592479dffd85c173008191cfadb599
1896	3	2025-04-03 15:36:00	t	f	\\xc30d040703022c7c0ea1779af5307ad236011ddecee43dc715630241184a0fc7606fe21b8eef6d13f2a9928473073ab35c9de54922f87efed3737f3c404f30971c8000e701b9b5
1897	4	2025-04-03 15:36:00	t	f	\\xc30d04070302ef74500619155ef26fd23601510c37bac9cf9887671b2c441f09e2390eff611dda2b3bdca42b11f47131e4fe3f165cd7156651a0798b8b00cea54117fbc4ee33a2
1898	3	2025-04-03 15:37:00	t	f	\\xc30d0407030221001f4ebfa056b56ed2360116ef70b5e0318a62e9633c6985b7a6fffe29b6a62838bc5f66d684c7e33869e8efeca80bc1170f8512b6e9810df942929425309a93
1899	4	2025-04-03 15:37:00	t	f	\\xc30d04070302759bd0ebd1fda5136cd23701d9ba9504db779dfb3c2459c94099dd8505c636529de0c3ed21860f4c6bae5915c999a5780aeb7b385279787c4edecd19f792155ec894
1900	3	2025-04-03 15:38:00	t	f	\\xc30d04070302c2ab404a8f45f9e76fd23501923a6bbc390a735d315f41387808e38e127ad5a37545acddc6dadcf9c8e6d25b06211e77b3efd3bbb73178605c681a43ce774601
1901	4	2025-04-03 15:38:00	t	f	\\xc30d04070302f953b7ed97d844d66dd23601d9e74bee7dc11c7342f176f39e28c4b1f9cef1a078c3514c82c3c87b1a844aee48a180577989755ba6f39261ebe1676a34f0edd212
1902	3	2025-04-03 15:39:00	t	f	\\xc30d040703029f177edecbce501c62d23501b163c94fef8208f0e26163164db6332fc0436e1c0bd87ad59ad39b0b35f0d70f327f6591fb7fc6693672e8c8f63ae809bd72c82e
1903	4	2025-04-03 15:39:00	t	f	\\xc30d04070302f5c5674ad2ef6e847ad23701f3dff06ceeef94aff29ecea865b8838bb2ac8e4e4abdaa6cebef87e7ef4f45f4ec0eb07ae43d96c9a67227a978a13b8e56ba94cdc492
1904	3	2025-04-03 15:40:00	t	f	\\xc30d04070302bfa21898b9de295a7ed236017926fc8c4fd3712a3da4f116b4f01b102cf74cfaeac50afd6eda5d3a1025d08e2fef00dde79fc2948de878f93ced5057ff2eb61258
1905	4	2025-04-03 15:40:00	t	f	\\xc30d040703021488e2c0404a1ccf65d23701e6c870e7ee90de77b9bd4cffa715bffff6ee0dd11c00f22963c14f16af80c7ede21310c95271e5c4756ed2f4676f85c21e999db19f1b
1906	3	2025-04-03 15:41:00	t	f	\\xc30d0407030218fb037e23f3a8c665d23601621fcf15315340dd7fc529aacdc09e7267e01a3d0d0cff9b1036a5f949329094b3163f97e22c474904f21c3c38ace55f9035d4bb79
1907	4	2025-04-03 15:41:00	t	f	\\xc30d04070302f904235b0ebceee566d237016fc627c64d0eeea018cd24aba26e8283de97fec0f3ad17ab0d227cb8051ed7c0b5c2be8ba7a1ff48a316b06e4d20b4fdb3407aae909b
1908	3	2025-04-03 15:42:00	t	f	\\xc30d0407030281b633d9d71d28d962d235012ab2863c460618ca8becc27fd980e6d41bcc160ee81ea9f1842e059bb718e09671ff3d2aa00204eb5d45d9d0e62d5e0a0f49df94
1909	4	2025-04-03 15:42:00	t	f	\\xc30d04070302e503dee610b7419a66d23701d83a75cb2ef46dad3013086d1099908531dcfeed3c996e4bf424ff697a714bdbe7efb487255aa4a3cbaa81e97ebe9264ace6fb8c0423
1910	3	2025-04-03 15:43:00	t	f	\\xc30d040703028d5adae7c34237be7fd23501f11336ee5745cbae51fefbda23291291f8d92a9e0966e484a7cb98b291f874e2f3f3d2e868a2e78a6791067eafa65cb8e5573ef9
1911	4	2025-04-03 15:43:00	t	f	\\xc30d04070302a6f91659964bffdb7fd23701078123b8de55230f59bfaeb8f9375ce124e4d65140174d2eb4e7e564497c380268f019a4b5c58e530db5c5b60c61304b11d5af684cc2
1912	3	2025-04-03 15:44:00	t	f	\\xc30d0407030218fdbff7d74539536dd23501216afb2042033f0fa212a1843834e3612209bc281e51c50353d1de54e055adeb0833653ac52a4a07e970da8f2acb6a185bb2ebc9
1913	4	2025-04-03 15:44:00	t	f	\\xc30d04070302b1442a9958e35edf7dd23601c00192ed51031906a083a57479f46378496d62be90d71a009f15a407390f5121c08af48cef957dbfb249b130143354ef8cec29b231
1914	3	2025-04-03 15:45:00	t	f	\\xc30d04070302165243ea373e33147fd23501630f5f5ce7bcfd32a05af197c3a2501eff6ffbfc59d3a2a0bd312ddeb5a8a70632f16e0dd2cd940e82b9dec1fe536c7d16cfeb0f
1915	4	2025-04-03 15:45:00	t	f	\\xc30d04070302ce2c367ffc75ef737bd2370163f444e10893da7d12591196392fac85cea41951cc9e18df64baae40725bc64f40f90f33a8fca332a968f3436bbc0e80cd53bff4f2d2
1916	3	2025-04-03 15:46:00	t	f	\\xc30d04070302d9fd0b65ecb48ffb70d23601624d09d1f4b2108bdd3353d8dafcd88ed4fab06a227bf66a988b1bd57b4e5931fe54afdde535cb19f567ddd2d88a4e74da2ecbf913
1917	4	2025-04-03 15:46:00	t	f	\\xc30d04070302fea5a100e135299d70d2370135f625bf05fde6c3b73ed70610a3f20d3013b18272b0f57407c26eadecda4fdc4026c5b2b4a5b33306bae5c100a317c818a63cc9a8f2
1918	3	2025-04-03 15:47:00	t	f	\\xc30d04070302c1863cc5fe40d73960d236014a46022d7876cae874d7e43b9f9a8e72a01a8216d3d375cf7690385a6deb27e371ba29ffbdd9bd79b1ff1589fb8c2adfe30fe89a09
1919	4	2025-04-03 15:47:00	t	f	\\xc30d04070302e4fcc1a6703c8e9163d23701319a995e591ecdc6706b4a404b202c94cf16472882bcdb22bab674032365d20e6dcdf133d177004c0752b4c9721bb0d34af3c676e420
1920	3	2025-04-03 15:48:00	t	f	\\xc30d04070302c1ab3c015fa2ab357bd23601bfac0025679d648562e308b7562d5d5a644734c4231d8b9c04d708fa315c2873fe9d399a88768a84c9010be15727169ce65733b622
1921	4	2025-04-03 15:48:00	t	f	\\xc30d04070302450cf8ac5389856e76d237018790d1d8c51262d5a252e72e6183bbfd16ca5dac18d31e9fdc375c6f159c186db1674a9fe1c50ef7aa8efe159fb91b0414ed3b25fc6e
1922	3	2025-04-03 15:49:00	t	f	\\xc30d040703029e5e55ac3e4c8f4c64d235012eb193068a90497743a6e6db849e82c0a7a972bfa5ad903f5006a82c363115b89a50bb5c461bfe3225336e70d229a86e57d358f2
1923	4	2025-04-03 15:49:00	t	f	\\xc30d04070302f83022c701fdc89969d23601b9696a17d79c424aba6e838565750d5bbc7fb2692a058217b440b94075e46d70cb8e1157bda4df0ded681bd29cf0b996d33ddb763a
1924	3	2025-04-03 15:50:00	t	f	\\xc30d04070302bd291c6451c0446660d236018fcde7ea0aa3dd708b5b62a1551c2838915a3b9233e125e145e664f987ef0556ad85cb798e65c20818f09b543e3a84c00eda5f56c4
1925	4	2025-04-03 15:50:00	t	f	\\xc30d04070302fabbd58d1514162463d23701504387b54875caec43a0ff141671459dcf4eea3eeba1d6602a76d9f7b26de5f214e3f1f10ad4b72d3fdfaffbaee3e1b86fa8b4e770a0
1926	3	2025-04-03 15:51:00	t	f	\\xc30d0407030268fc67820845c8b969d235010859639e651a1a64ce90f2f014c9ca4122128589ef126d174e83c0a84197e3afb86bf3fcac2168a6c5d713146060bcbf01ec46fa
1927	4	2025-04-03 15:51:00	t	f	\\xc30d040703022334cb24ee5024e365d237017814b4e55e55daf40f63531f05b8ad89aad9ecc68e3dd08ef27a6c514a73d7ad497c864c6fa9d12934104d76e7a944853204adff4687
1928	3	2025-04-03 15:52:00	t	f	\\xc30d040703026f55d7ec4bf9e7707bd2360104c9dac890c0635f05b73d7e779664a7e5092fe6af338f83003c7c6c388c827592e1a3045e6a3425ad789776f74894957dc25f92fa
1929	4	2025-04-03 15:52:00	t	f	\\xc30d04070302741f532a046c47147bd23601e1a97aab9bb7ff9b948f4ea35221b4feddf0f8ead607c652c7352dadac7df2c7a1bb814108ee3caf2326b777b0a48c69481964ec3f
1930	3	2025-04-03 15:53:00	t	f	\\xc30d04070302b8034eeb0b975f367ed236010a9b18f45d6119c3c0d125b12b8a31e7a4bbc1bff523cf4b82ec2b0e69694fb6d102e237ebef19a016fbba12cb433889e07fd50dcb
1931	4	2025-04-03 15:53:00	t	f	\\xc30d040703028fa6bfd6aeb7196675d23601c652fb9f937029f0a881a1f8cd506ec60dd09880364c969c42caa7a05f890d4de4289d3d80b21ff4c781bec88ab566438355c1f69a
1932	3	2025-04-03 15:54:00	t	f	\\xc30d04070302d2664cf20849b25769d236018210339de81067d01d3e7f1f38661b6afe3f33745f41b32ebfbedc5900fbf0820f529ff3958ab1ed90c84956dd12a1fe0f096a2b94
1933	4	2025-04-03 15:54:00	t	f	\\xc30d040703021e0778acd499e19d77d23701d496af03d765438bbfc3c744908cb2b4d1b29714b5748e7dbb449d6cab55bba6b79fc3c4c74fa43c69b919278d52eafa3ec7a7caf0b3
1934	3	2025-04-03 15:55:00	t	f	\\xc30d04070302119accd783d4f3027fd2360175956c1a1e1e75692712e421a9afe51fc30c4fe4a1601c9f6c55c016c86a257a969ead4eaf627f8b124045a6c1b1342c2d94ecca24
1935	4	2025-04-03 15:55:00	t	f	\\xc30d0407030277ce58338ba0282f74d23601b9c9bd2cb3965de2581fa40fea7149d0d046c535bb2b03e310314347362fbd611b92d7689f9fa02a7e51629eac43865730b0220472
1936	3	2025-04-03 15:56:00	t	f	\\xc30d0407030273269f4190a0952671d2350161ec43ad600a301c6ed2cb21a114094bee19be3415a48af2aa4ad35b53f97eb07eb4ce762cc212ce0a2307f1763364373fced8be
1937	4	2025-04-03 15:56:00	t	f	\\xc30d04070302ca441393fade3b1677d237015d222af879a6d5238b9b33dee48e84acada4465ca5e9cb430ddd8c21ca69054593eb24729469e306940845b1d4ef0adc540c65e2ce0c
1938	3	2025-04-03 15:57:00	t	f	\\xc30d04070302e47b97e8dc8ed78666d23501a283c785ee98d082838af1aacbeb5aba669a2b221fabefeea74a79093a8df31c0661388afa82939f1ed7a65889756169c5824025
1939	4	2025-04-03 15:57:00	t	f	\\xc30d04070302ad3a38775ff00fe477d23601ebf929531ed04f57a1636140a194d1f8dcdc0428364eb2a468c91751cfd7d463360a89880a9d7a0f9ce14881caa89380a590166d6f
1940	3	2025-04-03 15:58:00	t	f	\\xc30d0407030220a9cb8a17d500b66bd23601308ef3987411993b73fb0b3ed80ed87b2772e3c003b65d8e75cec7b42141654988b5c793db750dcad45a9511f3f539a443507af3e1
1941	4	2025-04-03 15:58:00	t	f	\\xc30d0407030258cd50c653545c1d6cd23601a9b0f09eddaa979e6430d5e5dc6c4caa2edbe4c830c565a848ea30fc714e64658f3b3ac89aac7f83f81fb8c116457d63f9f73b6f98
1942	3	2025-04-03 15:59:00	t	f	\\xc30d0407030297c34763b31a3f2565d236015e3152b21c64e44f55bbb9c73ea928c1b4ad300ec73990fa0f2039849830a116568adf8e56f4aa75797d8dd8944a0c86422f484169
1943	4	2025-04-03 15:59:00	t	f	\\xc30d04070302df56c07074da4a4c77d23701f77eb8399c12ea4308a3e2135aa4ea890cfafba777d8f8e85e9a879f398af28c01739f47aee59be7398e0a506f96aa42ccf3d01bed05
1944	3	2025-04-03 16:00:00	t	f	\\xc30d04070302b56cc9327742ad6663d23601a4ffc969abe31ed4f2882d3c902fd4b90fd03f2c190352840d3a9238cd524f43156e18adf7e3eb5f71c4d7c1f06c29b431905931d9
1945	4	2025-04-03 16:00:00	t	f	\\xc30d0407030261ca355a7694873879d2370135739f0c5d075f15e2aa283f717d5f03e5bfaac75806f0304077ec382c5b647d44f23428bc7083c403e879957ce4c55f08ad7d21b788
1946	3	2025-04-03 16:01:00	t	f	\\xc30d040703020c94fb020eac632363d23601baeb2b4e298c34904b1ae784216de47e79eb9960acc9ac867c923c1a1e1f93f72f0e0bac1aa318a1b66f377ca70af65d94fabe6d82
1947	4	2025-04-03 16:01:00	t	f	\\xc30d04070302e12bd8c2b2eb7b347ed23601a65f860af47d13440e8a2700a4dddacdbd2b2024e84cea3aa2d62ce1688dbe4a25c28b09d4996588e04a8f4f6e0693b991ac9618b5
1948	3	2025-04-03 16:02:00	t	f	\\xc30d0407030250247f4b8886c2537ed2360141095a947ae85b937d862336e788715a585bd4f5d2ab2fd020ff479715fd859ae9486a2cb552aace6eff2c8760c67183cd05fb6430
1949	4	2025-04-03 16:02:00	t	f	\\xc30d04070302438f9d79001767d360d2370136a8372459ad652236b20b4459f133ccd7e5386458be8b713b69dca484691ae7efc7b27adf685ff0b9af4b888e740a8f0397423ffc57
1950	3	2025-04-03 16:03:00	t	f	\\xc30d04070302df6d3d2c7795817d72d23601fbf09e0ceae547c60c912f7396bd52ba7c6c3c73fd2b62eef7791964cbefe91299076a5cee21761b23a2d50a595a8353046a012c86
1951	4	2025-04-03 16:03:00	t	f	\\xc30d04070302b901e95b9496ff1d69d23701a4615f9f436f7ed67dbd4b30ffde4163ba3734bfdffecb135db98aa6ec17dc241cdacfd2eabee5a7416573220bdf93aee8c2c7e2bdfd
1952	3	2025-04-03 16:04:00	t	f	\\xc30d0407030287297d93084cf81c73d23601a2c82d8cbd5cc9f5ea03a5c5b343248b1108a8f416066adec98d3c9acd0d2e6d89ce85dc5e4fecaf578d3e32f3a8b04c1c64e83271
1953	4	2025-04-03 16:04:00	t	f	\\xc30d0407030272486a440327558378d237015744c6d12e4d4602e8674c949b4ccede35fe8c5987bb3cd018829a72127a2e3898e3e52c4544062a89b4659d0ba45501826713d9322b
1954	3	2025-04-03 16:05:00	t	f	\\xc30d0407030281b5a41c08b157876ed23601163550643e02193d69af889b477f49207c5bc57189f5655a46e34a333bc989b62db51ef045e9d765b2046dff6a26cd3ebbe9c74580
1955	4	2025-04-03 16:05:00	t	f	\\xc30d04070302a3267c46b341edbb6bd23601fe5a15afbaaea0b5ed75467c1472dd512ae15e40db8a70b246bedc2de710934510364b6b68736bc7339eaba50c0c7649fd6dbf3747
1956	3	2025-04-03 16:06:00	t	f	\\xc30d04070302ec5ad1b256f3c2ca62d2360148bca5ca8c38fd0b5ffe4c4b11b23f18dcb01491ada86b469eddd260772614fabb82bc9b632966d08880e2e79a3ff7ee046c717b0c
1957	4	2025-04-03 16:06:00	t	f	\\xc30d04070302a88f2682ed5a3e787ad23601bcf164a6178566168c184cb5b0165d8e63c865efc428b32615ab5bc72ce5043fd7d27f6f0a4485628fa51a96190470364decafee93
1958	3	2025-04-03 16:07:00	t	f	\\xc30d04070302526ede63e7f6960476d236013826de755332f742361fd7380e8544aaf324ca05eadee59d51fffb5192ab81d1f633f9405985d4eb4338bfb959e03ee96bf568ad6e
1959	4	2025-04-03 16:07:00	t	f	\\xc30d04070302c3f523cbbb300a0a71d23701cab9e66b20aa35aae31d3dec2f19dde4790f2705feabb9516e913d336b1e30d628aaa2659c79f344e89514455843bd0dd89d9c025da4
1960	3	2025-04-03 16:08:00	t	f	\\xc30d04070302ef66173d1130511d67d2350117f681593e085f011a2ff5e0ad4458765fa2a5371c919b6a6a69785f66c80c056ad67a689f02a4f088c3a7ac8c23499b496c7dbb
1961	4	2025-04-03 16:08:00	t	f	\\xc30d0407030250d5da4693a6f9156bd2370189db7bc34fc147eb6e6ca81e1d6056b90183c9c5da70c3aa56bb8fd9ef9184aa92fb6522c15d82c8628b3baa7d6ff62adb5b02a595cc
1962	3	2025-04-03 16:09:00	t	f	\\xc30d04070302e570c3a80842e3736cd235012187a85d3ca0205a64db2b0b845390ec30dced305b5947b3e5cfcaacbe41c20593350842dbffb538670c4d134f83ed7de7dd28f4
1963	4	2025-04-03 16:09:00	t	f	\\xc30d04070302450eb231e0d17b0669d237011a88ee565758ac126532bfdecfd88faadf124c446d73f57096781c9ba0d332aeaa4f4bc0a95f03e8895eae0bfbc841c38e90e93743b9
1964	3	2025-04-03 16:10:00	t	f	\\xc30d04070302a13706bd6120c8217fd23601834beb66fd2999dd2f4ca21545d39787697c3b743a1a21c8bb89c0125d3e5d2d9a2c24d44fc34ca65d53f83be00840f87412d09154
1965	4	2025-04-03 16:10:00	t	f	\\xc30d04070302228d2acdd93271f37bd23701d0d061d3386d11fe381447750468de7b0c2e7a13f825278aa7dfa5bc229775c95f6f897569bb48c722119d859cb4155869a7972ba325
1966	3	2025-04-03 16:11:00	t	f	\\xc30d04070302d77de47b6ac615026fd236016bb660bc95c32421ffc35ec7e3ed263dcf34670227ef78f7daf3275a0f6e7f002a6d037dbf756e14192559e57a5015c67f9d0ada0a
1967	4	2025-04-03 16:11:00	t	f	\\xc30d04070302ac96e6c1947f8b0d77d23701159015cdcd43ab965ff213ff5af14d41b6b58259eaffaa9f6051b3990d968ccbfaed4b42477e67e0168a4ca8da8a56fe52bc954a829c
1968	3	2025-04-03 16:12:00	t	f	\\xc30d04070302e58e9a10d77a87746cd236014b48c47cbaab9b31d4a780f5bf9997e4471ec150c984e3d22938dcb3b38e5a64aa4e17b865d734e45f19d315796e3f648e62e0d890
1969	4	2025-04-03 16:12:00	t	f	\\xc30d0407030290e92346b87b87e66bd235012a74625d3342864be276d2341d1ac0ef0a2ffdb2609134a1089002cca06a5413da6822081a65e3db33bf57c8bdd846b645becbb3
1970	3	2025-04-03 16:13:00	t	f	\\xc30d04070302844e4aa1669c1a7b64d23601f47c220ab15f1c923f1e747df0a63fd223ce7fc5be9a271799a7e200cb4836f4ad707b1d1af15b1aed7b5dbd545fc732a79eebc1fc
1971	4	2025-04-03 16:13:00	t	f	\\xc30d04070302860b0dd2db9f714368d237012381571758596862dce497e79000efe91dc410e51554e78dc1b9c0963a50a2ada8f8af5bef51dbc3824c580188a2151a6a32d41dfc57
1972	3	2025-04-03 16:14:00	t	f	\\xc30d04070302d3570089059c87857ed236012d65f384638f66d79810a345c51c3662e8f33c7090888390ec349f28d4bcf54f0faa5a7e0698ebc856618e5525eac7b649d790e6ce
1973	4	2025-04-03 16:14:00	t	f	\\xc30d04070302e30ea956e79b318a6bd2370109b0656c411acf989456e64af0e3454001fa23ef595a17199f2fdd0a5de681682b32aaf2b79d27fdaf754a8b83347b199ff650fdff9b
1974	3	2025-04-03 16:15:00	t	f	\\xc30d0407030285732c11f9af4e5476d23601fec89076a2d66400bb7c2b9fdeb3c5b8156bb420deba221783935ddf85fdb4a1ca73021bc27fc0d60cf9d6d6b2a636c5e5bca8b838
1975	4	2025-04-03 16:15:00	t	f	\\xc30d04070302cd585b29f5ff8d2171d23701737377b15a7755d6f392ca7e765fcbcb4500afdee0810cbf3f27cadc9d66be9695b475782964a45e7edae38d9fc2563b3dccfbcc86d8
1976	3	2025-04-03 16:16:00	t	f	\\xc30d0407030231b0fc422f9ed1397fd236010232b018fff1a0e238384612aa879b87ffea9184207c9e835b8dceb7ae22c5ac900c6c6ce7b938aa3343e745157abf14a5aee4d8bd
1977	4	2025-04-03 16:16:00	t	f	\\xc30d040703028d038714cb2c106472d23701ca41e60a13587ec255e27a12d0d2d804a5a4b7cebdd24218e47f0da9442898bc134fb345c779e5064db98709f33bdca5aa976ca5620a
1978	3	2025-04-03 16:17:00	t	f	\\xc30d040703026df7dddc5fcfd75b6cd2360156f81682b4008e07e7fcb1ddd112adaddc193db95fee9f67739f6f5de31eff8fc2f8dfc07f1d8d7b379463aee695e2cef529559f26
1979	4	2025-04-03 16:17:00	t	f	\\xc30d04070302ef45ad6e55a5606477d23601f36bacc48a9d46f5c36179e5b82b01215a5a647ec058742a592d25be6f6de4454b4aa3d0bbd84b05d022994c561af6d26501f70095
1980	3	2025-04-03 16:18:00	t	f	\\xc30d040703020ee14780e4344d4f6ed23601a64fd66f0c4465004b9d03b1caee564deb13c8e7624f6e869d030c2121122c585729832ae1c44f06b1780974d8bfcbe71b873e419b
1981	4	2025-04-03 16:18:00	t	f	\\xc30d04070302bbdc3b6cc80290916bd237018170667a6cca177e29fca174da9b5a4507a08d9a67fea15a2d5552758373cd60cbd1fb49c4b68c40b7763cc66447dafb71848e379734
1982	3	2025-04-03 16:19:00	t	f	\\xc30d04070302d52f2ee0c6229a4267d2360193c3718bc044965fcdd3661cc7829eeac9a2f02c5eaa129a5bf2c9b6a1d6079231f54c59ba0e735cdb1e192471903849f7976dec25
1983	4	2025-04-03 16:19:00	t	f	\\xc30d0407030254c6807c888fd1dd77d236013b12d86548cdf8cc327a22f8927ce57767f7870c800282446d6170a41bf3eee826e46e353040ba3a63665152e97f4ec3732140b22a
1984	3	2025-04-03 16:20:00	t	f	\\xc30d040703022e886ac9b323044e7bd235019c3f3c992f28419bcdede10513829a14ad16c6a6d50aa85af5182bc535d2942215d0031b5ecd45b3dc7e01a0a6d40b9a9e3a357f
1985	4	2025-04-03 16:20:00	t	f	\\xc30d04070302d6a5b329c6c7141d60d23601ba5a1963299c96031680644d2f310c8300350c9b6d5f1eca25a2a1bbc6a0b5bd5f149ffd06edce7096f5dfdeedb29d9b0d3dbcda5b
1986	3	2025-04-03 16:21:00	t	f	\\xc30d040703022d71d4f589e025c27bd23501f6753aa61ce7f1046a0f5015f1cc3d19de90c7fb3aab0bb747eb576cdcb934e89ca74933ee42f9a48dc0421f7d2784c88471544b
1987	4	2025-04-03 16:21:00	t	f	\\xc30d040703024dcf365db4bb66486cd23701816f59d8ca2baac45fa099b0da6f17f223efd590b60bf58843d35b0ca818ec7e6cbf85e427253032da76a7d61daa908dfe5045228564
1988	3	2025-04-03 16:22:00	t	f	\\xc30d040703027035e0d523fe986e63d236011eacb55b0b1cb26a358bb02a2f53db4b3d5ad47a9bbe7da2ab046fa8e72fc59f67437f8deb858f01dd01853701bf97027a0530a1bf
1989	4	2025-04-03 16:22:00	t	f	\\xc30d04070302bb4caf5de8d9483762d23701528e34aa2bbba4378048e47c2cb31325302faf270bb843fe24c291d05d51f0ece0e830b6a222182a31823671f1ad9f641f120658168c
1990	3	2025-04-03 16:23:00	t	f	\\xc30d04070302540fad9b243313d576d23601f8ecf4022a758fbf62ca945b26a52e90dd72124e6c4feb4531c6593d627059614ef9f0285868c7bd857ebc1e5238a6465f3baadeb7
1991	4	2025-04-03 16:23:00	t	f	\\xc30d0407030226c08e72b3b7b09971d236012da51193b0ea963694f51d9067ffc9a40086e1317eb0199d46e052c71f61adb2ebe44e6e2d377693fcee6377023d256d7fd9785a5f
1992	3	2025-04-03 16:24:00	t	f	\\xc30d04070302ed54584aeea058ee7fd236010aa54aaebd0cd6e1ed91d3aa37410ad7a44b0d0c6fd3990d27eb34dfb08d114d7679462fd226b4d32bee9a39a0b8392b71daefee4a
1993	4	2025-04-03 16:24:00	t	f	\\xc30d04070302e860f3538d3f674379d23701f4f78878d7de12954892d8ece6d413a2ce596458623b704ae37b46c196b096cb23c5201936fc774b83a6bf49ba27c62ade6430bab431
1994	3	2025-04-03 16:25:00	t	f	\\xc30d0407030290902f7adc7c8be57cd23601e576c3baee12dab279b8e80015862d401648fd9578e451ff770aae6ea5c464c2070c3920bb05d3a83c9fbf45e4ea4f3e8aab01bbf7
1995	4	2025-04-03 16:25:00	t	f	\\xc30d0407030299dc616c5ec2f99d78d23701e80514a5ad8886a91050e3710dd8d3882ed5c68bade2e31200abe66c4cb56fb31718e41240f3169e183ce8839e749ef8802f440288c4
1996	3	2025-04-03 16:26:00	t	f	\\xc30d04070302175ffaecd7ee3a8961d235013aa23bdafa1e12a2a53c6865a07e96b735d65c27a2f7ce1a7bf903d277910782cb25f2adf13fc8c74397691d852acadbb4073615
1997	4	2025-04-03 16:26:00	t	f	\\xc30d040703023ce0f769b5cf107b7dd237019adf80a25f8adf1fc59d767d93135020a3ecd7b271462df393043450d8e24aeaa163fa15b06ee7f465ba02754444b43efba32e306bd6
1998	3	2025-04-03 16:27:00	t	f	\\xc30d0407030275e470c563409ec46fd236015f06707f0ca234f882ccac58b27f351993c490ea228672aa686964eca998cf9573ff0f8e64cfd7e6d24c130bd992c32caedab4b4eb
1999	4	2025-04-03 16:27:00	t	f	\\xc30d04070302ced8e5e5190777fc67d2370142e5b200d83e701dfaa38ff979dd6f7d0935afd031f24edc50ad2c5181546041518147a7393c49e54715e4ef91157e4997821361e3b7
2000	3	2025-04-03 16:28:00	t	f	\\xc30d040703027e72f3295348347b6ad236015ba881c5aeca164e073a9800767dd8ed40e0976ee6ce17dba04ecffa9597a3bb41d13b79fab5cbd304addf6da0ec96db2a6b3f77b0
2001	4	2025-04-03 16:28:00	t	f	\\xc30d04070302daaafb4ba174986869d236014f5fa9f50582456ffb9935824d80c6abf762590d85c364076f6b0de18ae27896fca93036c9e72c02cfb94e8b9af4bb3c7cac8a3e8b
2002	3	2025-04-03 16:29:00	t	f	\\xc30d04070302657ca748acb5410f69d23501b8f5797b098e51041d06c6ede851b779c87277dc08a99fa4dcb0f85ca5c1ad9b38b02adb6e0628521933377efbf2c04d2a61646e
2003	4	2025-04-03 16:29:00	t	f	\\xc30d0407030234681e9297d2676b7fd23601263881b66e77367056e0e48659ab8e9a6d7fddd9958da861f40d694354150a83beb3e34b33b9683b17880c571c0e44f2c25960df6d
2004	3	2025-04-03 16:30:00	t	f	\\xc30d04070302dca3c5685034f81b65d235015c6340b3f9710824dee74aeb2bc2d10bccc2b4b0bcc3aa72c8761a2c8e4a78d799d7fd3976b27c793353f19c35c178ae2ad295ff
2005	4	2025-04-03 16:30:00	t	f	\\xc30d04070302f93e0684232f48337bd23701d9d38f7fa6f7ac9ce20c3782bae47450136f9852dd3951549ea36568d48787281f971eecba182ce9d3bc865be452f2507b9ef13d010d
2006	3	2025-04-03 16:31:00	t	f	\\xc30d040703025927ae4f466cce136bd23601d17a206d6147e2879cec1e74418fbf7e500b0b6a209b0580370fa746828083fe39cca946cacf2e6122bb091b1298241ae9b350c2f6
2007	4	2025-04-03 16:31:00	t	f	\\xc30d04070302e7b23fd93eced0fb71d23601b33a04d7713fc22c5c27301eddbaa519146fd5f0f55363f2f094ba6d329ec27153db9bc3c23ee41d3c0592d3efa3f08f113a8cff30
2008	3	2025-04-03 16:32:00	t	f	\\xc30d040703022ad19d6e34e4e83166d236017b56fcb3452b660f108adbbe1f3421beb9f231ebb46860d23eacdaf9f50e28019f27a792997491164af08bbf33915c14d72b6da9f6
2009	4	2025-04-03 16:32:00	t	f	\\xc30d04070302ee07c1adb94a7d317cd237013dc97b4ef68feb524b833d7e45d7f3c342676345ef0a0120ff2c0fb556e5535f823ed0cf8ae793d505b0ca46143d9c9677357c5a4f13
2010	3	2025-04-03 16:33:00	t	f	\\xc30d04070302fffea4e3fbacaa0365d235010fbe1cb24315b75c2d12693fe2e310a24c4c56122dd31e8f6d46e9a5949adcd1368d5ad1e6ad754d59cf10252fff478e7d8da735
2011	4	2025-04-03 16:33:00	t	f	\\xc30d04070302e67b0ea4645f99e866d236019bb5b028472a7617bc8c460b25e43004dc1293e6d4e661a86dada52ff23869243ccae556d4ad072a35ef4622dba42e3940c8e5e6b2
2012	3	2025-04-03 16:34:00	t	f	\\xc30d0407030202081b85da46965767d23601f7f6826badcfccaf3f3e41eaa985fe3132eb8db619a22f750247b50a003a1ae3c27f67cf0074a4af7d517fa7f2f048df64597467ca
2013	4	2025-04-03 16:34:00	t	f	\\xc30d040703027592af3561632d8e73d2360175901efc9e1f385449045883a48d8f0fff455ea89a0b067b44e26a984853d7dc77f47bfd4d32b5a452114434662a77508ae801df14
2014	3	2025-04-03 16:35:00	t	f	\\xc30d0407030238f3e1f786e5fcb46fd236014ade562c71bace4350a4d45ec6f39652a71526b18b2e37d76a6ac61950b54132fc594621c4cfcb5cb93981729a176e75564cd0d4c2
2015	4	2025-04-03 16:35:00	t	f	\\xc30d04070302007916da426a17c66dd23701c925fa62692517e378f068f27043083211f9a038887ebaeab8380add704fef67d8833d717efe94b70427cee2963687c1539aa492aff0
2016	3	2025-04-03 16:36:00	t	f	\\xc30d040703028309600d1945e9517bd236012f04e101af71ef70d5fa23fe678cfcd694d4af94f975ee4f5668f5489f8f6acc44948556009007c28d81f91e2fa68553eb53586e28
2017	4	2025-04-03 16:36:00	t	f	\\xc30d0407030266f87bd829f1a1627cd2370101bf4653f5bf22493d019be8bb810b16ac1347e0e25979afdeef7dde18561dce6dea1a026ec5a25e0b0b504776356530d11f66faf790
2018	3	2025-04-03 16:37:00	t	f	\\xc30d04070302a85253d0a1b6e36e75d23501938802aa8ee8f70c460f148c4959203a1a267d1716dac63c42c0eb7cafbab1e5f8c2c2667415446ed519713b0e51cba3b2674079
2019	4	2025-04-03 16:37:00	t	f	\\xc30d0407030205273f1581e4a36966d23701f52021ac7628b5dd646a1efe38dead463fd7441315d0a29601fa30301d5830414103bef6cdc9bfe03fb27e93c5e4434e619c39936bab
2020	3	2025-04-03 16:38:00	t	f	\\xc30d0407030231984362473ddfed79d23601ec2c5738b2c9ea033665d971738510b0fc321f4e39f1d2c51bf011cf57f97ccb0f4af680c6078ca6662cff482f5e916e2788e9d26b
2021	4	2025-04-03 16:38:00	t	f	\\xc30d04070302c22ea75204ec69417fd237019d9362af5c79e4991eb5a405d00d360355c0a255bf83240f973e4ad1044c784edd10c69e0a71f42046daa1398ebf8dde6a5444abc9d5
2022	3	2025-04-03 16:39:00	t	f	\\xc30d040703029d0dd3fec720e5da6bd235019041429fcbaa1929456e319bfcccc76a065ea0145b41325329529068591c5a86e4339c067039cce216254994ee8c4f3d2fe75974
2023	4	2025-04-03 16:39:00	t	f	\\xc30d040703027ea54f0b2781d43e72d23601d2a9f76a4d06a7cd01af6fa8f94f5a7c133f4138252b5c4db23492fa09fcf8d5716550f79d7f770a8d0ddfee2cfc8f9fc22de8221b
2024	3	2025-04-03 16:40:00	t	f	\\xc30d04070302a01e96317b13e51177d23601c6b7710d755847c34e1f0ab62dd4616013a9c2a938a95a29f482bb16142744079d9fad6843d858415bfd11bfdfcf19df6efcc7e7bb
2025	4	2025-04-03 16:40:00	t	f	\\xc30d04070302e6524c2d380ecd8c68d23601d0bb1b6b9c751b99824e833a307e2f02ddc16f289b1bc5aa58f19d282c2b7f489ccd90abe6867dcc28d4dab3c464b8b1f4e417fa72
2026	3	2025-04-03 16:41:00	t	f	\\xc30d04070302cf028b41429e2e4278d23501a2aa9e74d5ca92fe753cbb6ff35bd790357d4eacd836833246599156a9609596a323b1fdb5ca4b34cdeb6dc1ff02b60663d8640b
2027	4	2025-04-03 16:41:00	t	f	\\xc30d04070302215992ac27dffc2c7ad23601c41edd03b86bbf27426add7535036aef03f4f9e5a1bf55fa174b50f75546baa03fe111d5b644f146e8c4d501255c4494a983701f6a
2028	3	2025-04-03 16:42:00	t	f	\\xc30d040703025b8bb4eb5bcb9d9c6ad23601d7e4407a4ba1d2db6be6740b82d627059f6bba6eab1e25e0ba2be624380f0fc5e7d3c0a63de7433672def440a3c205c57c12ec9bb0
2029	4	2025-04-03 16:42:00	t	f	\\xc30d040703021b8f47bc560186986bd2370141735416fffbff858da38068b3db17f14eb8b21e9ab339fe967740eb17562d3954a903d9cf8815b2ad128b56c3a4523800d6a7dcaafa
2030	3	2025-04-03 16:43:00	t	f	\\xc30d0407030220e8459017972d0a78d236012bb7ecfa91981d0a5e6837310f57b031c658440645e2d222a2630cc696b25e7c313df6a03607a71c0b9535d9d07965aa83aabe830b
2031	4	2025-04-03 16:43:00	t	f	\\xc30d040703025b037157030c9acc6bd23701965d79131349be5d4a10cef48af76b4328ec983a19df75adc3491d6e851adaf25ed85c15415d25e704aaa8300b43fb7118e710ab665f
2032	3	2025-04-03 16:44:00	t	f	\\xc30d04070302d3c0980b6a759f4674d2360121bd111220597d1c3e34f74f5a72ca6abbcdcce3aba69678d08450dafdbf2dc311b584e0e310a507bb8ef015e4905a77f269d7d5fd
2033	4	2025-04-03 16:44:00	t	f	\\xc30d04070302120658ce1c25573470d23701990addab9e4cac3c64cb1a7459c0b74e28010b96864d6129d1d58b80af98148c19c1e76118f5d7541b71ba01624567ff75efa17bd63b
2034	3	2025-04-03 16:45:00	t	f	\\xc30d040703023e22c3b786aac80b70d23601302de12b7fdf51e891950341d22be2b020a5c058e9ea57d59c3ead5fadcc185f2dbe6ea94c7988879059293e23308b1afb649fe591
2035	4	2025-04-03 16:45:00	t	f	\\xc30d04070302065a2c2ce35b2a0475d23701b9378b03a65c69b6a6d2c5054663cf0569693e0746e4baee517aeaff189d43996947f3eaaf8e897f2922d20b9e1c1bef6a3bd6108dcd
2036	3	2025-04-03 16:46:00	t	f	\\xc30d04070302a3821d3a0b6598d17cd23601f5aa53a014d5fa9b5f008cc27594e0267aa47b365fc266fa30e6e472586860659008de5ec819a683de3c3f1a835766b232429f3e6a
2037	4	2025-04-03 16:46:00	t	f	\\xc30d04070302d0325abd33719a6068d237018e3edd14b9fa88f1e9d0c1b80d8c3d6688c4ef9184a7f431da3ab0b2429db521bb00ce8b1ee3a147dbe59eb7d3b816856d838c912ace
2038	3	2025-04-03 16:47:00	t	f	\\xc30d04070302bfbe243a101dd8f76cd2350137a524632a1788bd2519d263dee23ad551c3ca550f3459cbe66df87cff6be5d181ec42ded4770087f548d4e9709fc20f2fe4c9d8
2039	4	2025-04-03 16:47:00	t	f	\\xc30d0407030299e3b58671081c1975d2370135c6b5a85b4f857e5729e5e74d28e7bb33a6de680df2ca3b9b4af99043f0681d7a6c11da46442f5534627088d2d43ed214235ef30b71
2040	3	2025-04-03 16:48:00	t	f	\\xc30d04070302e5f45572702feafe64d23501493bda837f3ebe825c40f0d4439e599395ed8f55430ff0141edc81f19dff6d516110409dd91f90c78a4173dc5dce8b52fd081c72
2041	4	2025-04-03 16:48:00	t	f	\\xc30d040703021f7474321712da7276d23701cb0da075afd0e5f90f02bd1bd7fd2f0e17041ea001ba2ad487e8863fa0235fca6efe33fdc84325210fff708d5520cdb96df6ab50f494
2042	3	2025-04-03 16:49:00	t	f	\\xc30d04070302a6a900fa95d3b54672d236016cc7e87db6f712f5543309516e3443f063e15a302195c88d52029ea6cb2c845a32b207a52eb5bd370d4e7b9e0c09c53bf88d55ecad
2043	4	2025-04-03 16:49:00	t	f	\\xc30d040703028b04e6af9857c2fe75d23701a343b1190c351d02f2f4da7c89ef0e55e5ef5432c1d46bd34082b6afc189c2ea333d9370008f154a3a16ab68ebfe634b034fef7591ac
2044	3	2025-04-03 16:50:00	t	f	\\xc30d04070302aecac5ba28d996436ed23601902d59ca4269c9be3567460c4a62d5534506122fd77b0e53f61cb69667cbc34d16c35918687e78c8df135d2ea0f85b9e64d4d17705
2045	4	2025-04-03 16:50:00	t	f	\\xc30d040703022f0461a9317052c160d237015adec177e402459d9a3cf62ebcd4d9c93174bfbf7f4d6c92fb2e32cb2cd5a338b61d4d2bf9df3e88004cbb371b29279eccd5fd8c1d2b
2046	3	2025-04-03 16:51:00	t	f	\\xc30d0407030204175fdf9064d98278d2360146d57e5a755dfd8a7bf37428ef8f9b15f5e74c243e3fc45556baebf27271cc12cbc2a61b6c01bc7cb0745a1f7d72f5019c3ae8cd3e
2047	4	2025-04-03 16:51:00	t	f	\\xc30d0407030235b7090e52b966326bd2370167107acb36056b6cd88786738db1c56bbdabfad1c0544f035be550df0194e216819334e9ddfc8c8d5defe07f44f0a6df48f0a2170556
2048	3	2025-04-03 16:52:00	t	f	\\xc30d040703028a16d68ccbb1560671d236013f5817951e508de6522aba197c9a4029bbab82ab38a0fa0ba73149e276330c3be346a852c42bf7c60f37dcdb50b41c452740d6b6d3
2049	4	2025-04-03 16:52:00	t	f	\\xc30d0407030264c67a16590dc04264d2370152501cf7d780e29341cb0d4202a79849b78a88e3f3cfe845df2f0e0203e95fabc00f83cdb231f640dea338c60d8bc1b23eb3cab7d758
2050	3	2025-04-03 16:53:00	t	f	\\xc30d04070302796fc83f918d7ce36bd23601dda72b0e1896e298f1beee0a084cac2244e6e3c47610156f30e026dce297cdd7e4f52da24c42bffa0bc431f907efa48e8da42141ca
2051	4	2025-04-03 16:53:00	t	f	\\xc30d04070302dad046fbbbd579706ed237015da6b95003100faf0254be73ec5f924732aa4f7ca36d92e0900c0f6652b711ef6fb0001678fc7ec0be130ecacb52130ddc48e057c565
2052	3	2025-04-03 16:54:00	t	f	\\xc30d040703021da90ee4e9287ee96cd23501e7cae9889fa7fff13605b2f7f90abb10216272027a01f79e3ab839dbae5e146d01a6eb3b82002b6d888ee47c53cf856b8d6f0a4c
2053	4	2025-04-03 16:54:00	t	f	\\xc30d04070302d2cd151e4f28d1de6bd23601cbaca57f76072482f2bc260123c3b3edd72041e6a965c3a23e9844623523e2c5347f034b4f96fda5b1e838a2e2a0b77f5fae5e0aac
2054	3	2025-04-03 16:55:00	t	f	\\xc30d0407030268b42830b33fe91776d235016b56e2ab7fe2cb5a611acade062d23b363fac973930b23636878e8cb8befd9b3d5c6743fa7c035aed1a5df7f0660170e20790dce
2055	4	2025-04-03 16:55:00	t	f	\\xc30d040703020c7d17534619da9073d237014d53ba8076dcceb61ce337a09dd0af3ec6d379d726dafc41800c9eaae0d88333272784233439f9518e870e0bbf79dc1d7925e0518845
2056	3	2025-04-03 16:56:00	t	f	\\xc30d040703021181799e86f4a6e27fd23601e9dee8d8f77693ed6577bec3737d23ee47e393eb513ace728622c984f228d439851eac6015c292c77734c5f56088e4317364c5400d
2057	4	2025-04-03 16:56:00	t	f	\\xc30d04070302739f59614ab439f863d23701416397b5ea4ebdc8415b0d312872b7a2a36db6a7df619e4cae4ba78c24a03be82a64f0a94f1e2a8ea1227c04f04e671c328d9749a669
2058	3	2025-04-03 16:57:00	t	f	\\xc30d04070302c588202bfb59e5cf6ed23501531984b1f97d745ba90a8024c29aaf7ba1c44e4a40debd2b4ffa7520a4472f3ee321c991f7b68add892da2e0599fbe7456d395dc
2059	4	2025-04-03 16:57:00	t	f	\\xc30d040703021d0e8ef192ede17662d2370106f265b5f200c35337e340ed546e9ddd537a38497ad1ac0260aa4f66c0271534a5187e529f2d29cc133de56ffb018b0caf4c33cab7ce
2060	3	2025-04-03 16:58:00	t	f	\\xc30d04070302bd1633070d3efc8a73d2350194304b06535ffc30b4374c2355b73ec7504b80799b9c2121ad171a95651c70552ba2b726f6a0a7008f05fa0e2686b4ce8acfc298
2061	4	2025-04-03 16:58:00	t	f	\\xc30d040703024fbe6689090f913378d2370119fcb384fb4a4911623bfa7e9ecb7830c7e368fa963a1b6d5c8ebdc631763b6e7885bdac438fd0f83b847064442fef2c84a93839f1cf
2062	3	2025-04-03 16:59:00	t	f	\\xc30d040703022c1a391dde90a1be79d23601d18211b23886706da234050dbb69b3070b171725b3b1feabc162d999604e3706fd5f734f6d5d7133aee040edaa06a5a10aff8fc838
2063	4	2025-04-03 16:59:00	t	f	\\xc30d04070302b3d11bfe0dcf689e75d2370179a8da42af916e141aa5ec2a9ab9f754aedaaaff35345de978d6919fd015d1453cca521a7d9ea4e8355079eccad3179cedceb5336856
2064	3	2025-04-03 17:00:00	t	f	\\xc30d040703029bf112a896dc935163d236011fb887dd32a80e4bd424d166fbdedc9a44dc293384823a3e1cd52f27271f3f04b0ffddc261874d729377f5ac34f3470877c500451b
2065	4	2025-04-03 17:00:00	t	f	\\xc30d04070302cf08b8d4223be06361d2360122ce04861dd217c5207b68fd051a79678637e6ec29b1ebd0529d48124e96481d79a46bd6a106c2ab2eb00fda495d1802cc051820e6
2066	3	2025-04-03 17:01:00	t	f	\\xc30d04070302ea2b5b0b0cb736d069d23601d66d07dd457d5c1cc5005e8bafde9668b2e8457357a9ed580cece0f5c2473cfdc0871b9ea8cf32158796606b280ddf0f18e09a7b28
2067	4	2025-04-03 17:01:00	t	f	\\xc30d0407030231528d2cc7dc57ba60d237010dc17f4e0d86652ea536708fb235e176e69d778e5ec7e424fbbbb3f477e136cb1184aafb0854e849345ac72fe7bbc1fd09ac1c192296
2068	3	2025-04-03 17:02:00	t	f	\\xc30d0407030264ce02f9461743ca7ad2360179178d8f45bfd1cca76a9aa70942ec5178526dc933b3cd9273734b1bad7630776b76f0e7af2da8a08bae969ed1c5bcafeb8a77d481
2069	4	2025-04-03 17:02:00	t	f	\\xc30d040703023797e70862c909127fd237012cf3c58a41bfa60f9f95c255bec5a07e44c0f28978e0cf4f95041f6df7bc2ff3bcaf28279a7363e284157744eb7d3a2374faff4f1169
2070	3	2025-04-03 17:03:00	t	f	\\xc30d0407030266f402583246e7857dd23601e1fb98c4cfdd5e4baebde28d9a1b6c34d5ae3ab56a48f02ec99fd788889f34aba81fe4e8928e7d1866cc6628437d5a710b4ee4f395
2071	4	2025-04-03 17:03:00	t	f	\\xc30d040703022f4994bab9e6a6e570d23701710c800124aa4b13d4acde1a3883360f076be6d002a055e121ba35ab1897fb56eebcaf3dd5da120d7a82d3864653c0625042542ae61d
2072	3	2025-04-03 17:04:00	t	f	\\xc30d04070302c0401298487f8c8e6fd23601f6fd61c4eda7d288372868c8499f2594dea396270bf7c79602fa58e66b98812ed4d032cae84a92c50936b73d6625d489da33661454
2073	4	2025-04-03 17:04:00	t	f	\\xc30d040703024d97792a465864af69d236012265e7bc97796b7fff42816a6ffd34ef491c3a9b6576e347a8d7fc2fcc8929636030e3022791201075288110a39830ca7deb10c11c
2074	3	2025-04-03 17:05:00	t	f	\\xc30d04070302c8ccc26687da5b7d7ed2360127963d3012aeffac97edf54d75fb6beb1f2bf4d524a91265e2c583c0d144a30de53c5f4c1ea2b2307f384a1a201181a6149967bf62
2075	4	2025-04-03 17:05:00	t	f	\\xc30d0407030213922c8b1062b8a965d23701480edd081eb76107d66c461311dff5e5c4c575a8db1ce85bc294a4c299ddeacc1178d697e5df93df4e8aa645c1d3eb29eacc4b4a79fd
2076	3	2025-04-03 17:06:00	t	f	\\xc30d040703026356d1e2d3ae5c6e62d235017c5c9dae447192e745e66ee0e066dbe952c637b37d2892f8fc76ca2953b3134db555e6d133b6774c658481649c119e878f54d882
2077	4	2025-04-03 17:06:00	t	f	\\xc30d04070302d1966b8da020e6f168d23501c960ceac29634ca22338751d0646b3d51fa810cef03258c61f141bc80fc6e557558f5a004e15a2446a945e3f35d534bb59493802
2078	3	2025-04-03 17:07:00	t	f	\\xc30d0407030237ca38e13bdec04670d236017b539d70e30e3683e600c3e922fb4e77a72cee0e44b2a2d2190005a90e44d21ef9c1789629be3d052ffa5f182f3de4f591d44c1f3c
2079	4	2025-04-03 17:07:00	t	f	\\xc30d04070302803216ea08b4adda71d236010d0a66a1801a5f377d24f31ab04d384a45768795134e4fb6cdce341dab6203432c0796bdc0e7685fcb4d88b5e14cbb6c73a55f3798
2080	3	2025-04-03 17:08:00	t	f	\\xc30d04070302cc9b4ecd4bf842f974d23601419b0a7a699f578d1a902168b26d7d3b83db8125a901f306822657f56f19616d3d291e16c6e1b8233316613aad2af3ad28c7d7f282
2081	4	2025-04-03 17:08:00	t	f	\\xc30d040703025100b3f890cc68d864d23601bbf2b72d930fce22e671c092d9af5163439fa23f74e8f2bd3e072ee824602f4ca8804ab759c1310a303229c3a4c40f417880f65ca8
2082	3	2025-04-03 17:09:00	t	f	\\xc30d0407030256987522776aa7077fd236015e2dcdafebbb8b0c9f3e6d7c299b568257015b5ed1568f91f62961506939654fa3814d4bd5420eb9132d6da54d85f52b41a7c6c0db
2083	4	2025-04-03 17:09:00	t	f	\\xc30d040703022ef6aaaed037a1e067d23701746d93c71d73f14659124481e9ac23ffbfe6776aead25afb1823ebf05b8d597d870125db4fe94e47ab82837bf3a9a8ac065953523dcf
2084	3	2025-04-03 17:10:00	t	f	\\xc30d040703025b869861da1332e77bd236018b5bcd355b5558b9ea15e4e5acea41f80b8823019a8afb2da898c2580a0bcc48dfc73715a7f37777fe9dc12cfb111e251d8b11f22e
2085	4	2025-04-03 17:10:00	t	f	\\xc30d04070302512e905cc314d6e361d2370162244e5d4e5c0c7bd69f98eb8d65c5951c3ee18495ba0cfcd853a855a2582e2f71c7100bae81fca18c7d824de7d11ad174fb24c36f0b
2086	3	2025-04-03 17:11:00	t	f	\\xc30d04070302a7e4926d1c9f10f279d2360121991c0220c70a3eefe4b0dfa77d07f899b914565680bc181a06746ab0b9f87a5c175808e10c968174fba23ab4d0f3aea89ff0d8df
2087	4	2025-04-03 17:11:00	t	f	\\xc30d0407030250e2162b0e3abd6c6cd2370118c8390e10b7c29c45538724eb64454dd2b8972865b325046006b1192cfb241a78f932a8340069dc45f8694a11f22b3dd38ae502b6ae
2088	3	2025-04-03 17:12:00	t	f	\\xc30d04070302b4c6d77ac83cefcb69d235015dc78f22ade2c16a6b53379716172f5425aaa0f293eda19b53ce07db4d2eeb6706e59d3512b41ee3620f95269202df6d525645b1
2089	4	2025-04-03 17:12:00	t	f	\\xc30d040703026c96bd0a76841b2568d237019c094ac17ecc0bb77b81fb811c583fe10b525aefe45802e3ebd276425a86a8528c6388226f223634d4e506929193ba7c233e3983d165
2090	3	2025-04-03 17:13:00	t	f	\\xc30d040703026158a9bd98390ce778d23601d2e01a4e95f2a7bf6463e548fb0dfc96796b2da701a6a89672156ea0cc0f74937a3dc9e9a23424a02eead3f68046d45fcf549085a9
2091	4	2025-04-03 17:13:00	t	f	\\xc30d04070302b69327f6af1c1c4e60d236012040ddab3ac256b276dbe67d2c409242e53f466824a13d37c580d2303c5e4d6096ce53806e86720e1dc496ee3dd28d250fe819c339
2092	3	2025-04-03 17:14:00	t	f	\\xc30d04070302da43cd19f45935cc76d23601dd672c6550f6853485e7ef44a6a5e2620b5433fa1ab5e8ee93d962a2e31e2e8d39826f49e3a2bdb6ace719052f85dd630e9e03fe39
2093	4	2025-04-03 17:14:00	t	f	\\xc30d04070302cef252c657fc048e72d237014ed53fcc8be16c863ca0c6dd4fb701ddf451c19ba755054d39dd7dac938295198d5e2f1d535875f9e6b8faa781709d41a72c30687c9f
2094	3	2025-04-03 17:15:00	t	f	\\xc30d04070302301f39e7e4bcef286cd2360155fa043615e7ecbf036d48177dbd991679a4b676280b3af2ac6c9472661e68ece46e3ba0c625cdd0713cab131fe9f0472a36424864
2095	4	2025-04-03 17:15:00	t	f	\\xc30d04070302507f70ff6bc02b907cd237012ba149de313818b99cffec88c77f8dbaf715dd78b5816448644086a06383ab5a3fcb6d9f8ce11cc805b64641145718ebb0a2c44e165c
2096	3	2025-04-03 17:16:00	t	f	\\xc30d040703026fd15517dac9c20d74d2360106825a9963b31425069f757726832393ece40a36d748743e6dc5c15bd77f5715ba9429547d80bd06104c23b19e8ea9f424875c069f
2097	4	2025-04-03 17:16:00	t	f	\\xc30d0407030294897aea7d3f731773d237016a384819d4b0f6d13ef30d47c8ebb4172c23b7fb1fcfdb1078a89970bc81a49f37f69868bfcaf7fad5d6e462319a414a08bd071a2951
2098	3	2025-04-03 17:17:00	t	f	\\xc30d04070302b628d41713efd20864d236011669e99e082d5ac13bbc4db9bada4b375ab12fb74dc273601ba2555a8d533e457faa55f5ae96c2b617e528a8f86f7fbd93f975044f
2099	4	2025-04-03 17:17:00	t	f	\\xc30d0407030273f812f7ad015c2f69d23601b6d923ae54c6bccf78b5bd7024794945358adfacb7b1287a5546fe5fa2269bc712967fe9be5ab9b607f911da257a3a0de1603340ff
2100	3	2025-04-03 17:18:00	t	f	\\xc30d04070302f75b4e053fb56f356ad23501d5eb183cf6dd39c0492a0c5738aead6891e2255bbf4bbfd33167d82f9bef2f4deb0fd617ca3e67a9399478fca65d4cea5d657394
2101	4	2025-04-03 17:18:00	t	f	\\xc30d040703029efa783ae4b2453e6dd23601679178b1f02e65e742694120fbd4b30dce652c4580a401f8c5a054dd72190ad29661d1b1833a6889108af8941ba505095eda1905dc
2102	3	2025-04-03 17:19:00	t	f	\\xc30d040703021c799ec22616b2b571d2360171e6229a4ce7d4dda195c2c48b959d6ac9df225822db6e7f16070d5e7b955274e288a581387ff437eba2a4ab49a8a78b509fd551aa
2103	4	2025-04-03 17:19:00	t	f	\\xc30d0407030282cf592b14fa399179d2370101b3718232d892558b00e9e6bff9403f28753f8b70d9d3da9675ce341201b63f422e70c6deb74f24aaaf1c703a35ad4f74ca9989b143
2104	3	2025-04-03 17:20:00	t	f	\\xc30d040703026c7b1901b8f44e8d74d236017aac36aa2628ad52cf697de7a6e47c713cf7e4a4f2c8bad06cc0a02fe3a2173590a5368cb4de084274b62870ee9b373f790befe6fc
2105	4	2025-04-03 17:20:00	t	f	\\xc30d04070302a9ae1cf629d07ab57fd236012066bc9fbc4ff5bb16cb3f96e96c8cc48aa8ced0f5fc6b87e0437e042819c1f5aa3d2ca793ad0f451e0a65e09658d44027dbdb782a
2106	3	2025-04-03 17:21:00	t	f	\\xc30d04070302d5f0026525a38aa77bd23501717dfe7ad15a83f7466dc263d0e0d04a9b8e1cf36b640313a8656d6e209bbcc034f10dc1a06026c3a6860cd9e8fd4abf84b26d23
2107	4	2025-04-03 17:21:00	t	f	\\xc30d04070302493f2bcd12a3e10168d2370195280ae36ac0754b72ce6bef2e46f67e0f48085afe94195ff75a6befd2a873eb007aa8cbefd9eff982c5581fd17f323ff188eb4a9c73
2108	3	2025-04-03 17:22:00	t	f	\\xc30d04070302dbaa03483521f6e76dd23601b4fdd2ac2a2966ee8af26f2d39f8770f6098210b39e7e564135b42845202b34ab0cb84f2ec16f4c2aa82b7e24136bc1eb3db5a3294
2109	4	2025-04-03 17:22:00	t	f	\\xc30d040703029d94ad079ec3e11e64d23701a41730c605e48b5f0b7011ce812b8698245a80c597cab35e2389a83ef989981bc44de0f144349d520101515dd6134a71b4a362768421
2110	3	2025-04-03 17:23:00	t	f	\\xc30d04070302f9391d6b4c8841397bd23601670bf049a1d79ec314c1e1f1ae302b941bf68fd29cd44b2de36be182aeb4ede66875d701099e225e27f2c331baa72315913bfb0a97
2111	4	2025-04-03 17:23:00	t	f	\\xc30d04070302f3ced697c75182cc7ed237014fff180458f292ee30b78a49a77d0ad8f9d6f06e212ab6537c521911cd5927d61fc4079ae1391e22ff16a7f8c177aa542a289ee449b7
2112	3	2025-04-03 17:24:00	t	f	\\xc30d0407030288a448038a30b8726cd235014e9f9d4fafd2ab3d436f25063f1b6f07cdbfef9dcc150d7a69149d62e1c925719d07b098113270bf7296e1699822f8a327f19d84
2113	4	2025-04-03 17:24:00	t	f	\\xc30d040703029afed374172c3d9f71d23701f9da83f65a0c6be9931b39e74b3a203c22ae3490adc667f042d76d0dd57cff60702de27eba60403bbd38262a14e8a05bbaa5006b3b8e
2114	3	2025-04-03 17:25:00	t	f	\\xc30d040703022a36dd4ee5b3cc4b78d23601018a810ecd456d13d6ec585d7a0a9b7d7e1e615824917604e98df687ba6f1dd60adb0a9789ec1f9d16caf3fe81d7018da6a0ca7f1a
2115	4	2025-04-03 17:25:00	t	f	\\xc30d0407030219f297a1ccf97f8d7ad237011e5b5f3c59a5e706d7f580873b4cbfdd7731714f0741acce72b5b02cb4202d2a1ddd60ec3ab323279c1ffaf97fa27e63b735af721b32
2116	3	2025-04-03 17:26:00	t	f	\\xc30d04070302a80e465f18aff1f66ad23601b776c03a4ec164e05771e4a0976f2cc74864d374abb75f9b3852f60548d558c1610ff9a8c02993f1e8cb3d3172861e1176e970cdb4
2117	4	2025-04-03 17:26:00	t	f	\\xc30d04070302e315b156ed59ac2c74d23601d486567ab005b460ee48efb24c68f344af7e2d35ba6b2eb37f3f6dc7cd15e613fe8700e66484c80c05cfef4dadc6f04df95639f152
2118	3	2025-04-03 17:27:00	t	f	\\xc30d04070302206318327ee0bb7879d23601acec0950f366a337362858e7939a036d4e0bb15161a3d8a89d3d59f0347438336eef9c87014f698411c646cbb714300e02c7382a4c
2119	4	2025-04-03 17:27:00	t	f	\\xc30d040703024922b81bdfee40256ad23601ef4680746e762507e0f43f261e1af346467f9d6ee40d4ff46e8794afc1450d8243c6876e958918ffcced14bf8c1cb3123ef19daff7
2120	3	2025-04-03 17:28:00	t	f	\\xc30d040703023f076e161062b1136cd23601d4f7a228dddc5027209345066ffa669f27742efa951cf1c23418a6d533edc9263f3cc443b643435b41cbc9ca10a06653393419a04a
2121	4	2025-04-03 17:28:00	t	f	\\xc30d0407030233e421645649ee927dd23701e77c04c0a6f7a70d98a912b22bf1a1650a10a731e364ca38c27d6c6313939479036b3f6e8c6824c499ad05b40ee06ae718baecf4f674
2122	3	2025-04-03 17:29:00	t	f	\\xc30d04070302cd5aa344d5aec45f7ad23601bf76cb6c6c32716506b69c7c965235ad2d8faefb73050e007f0f0161e68c3e7ba19589b4c754120d38d201a202b0d7f42f0b42dd8d
2123	4	2025-04-03 17:29:00	t	f	\\xc30d040703027a048134c2217b6372d23701acfec204a2119132e9ee461f9220323f66245645706de62c545a1522ef81083f91d54dc317854523c584c8696fddf8306ebdcbd4a167
2124	3	2025-04-03 17:30:00	t	f	\\xc30d0407030226625579ffa4664672d2360106069a4e258cf1795d8d4181027477250145c3b75028b5052c2bcb3faa6250e99df21039ff5c23d6f65ad3fded9d79716394ca5234
2125	4	2025-04-03 17:30:00	t	f	\\xc30d04070302e3f6143d75ee993973d2360183500b609caacf191763fdf5003794032c1a3b7ddde0054cc89d1e3a08b31c055f26ad318d0d5d2f96eab9fd88f638316101fd44c4
2126	3	2025-04-03 17:31:00	t	f	\\xc30d0407030289dbc0c8cb8aa43077d235014bf3317a01f0dcf93d5ff6685a6448407f40b8a57df46f276509ca034948ff49020f3272240c15a4563e35607756e6248bf4a974
2127	4	2025-04-03 17:31:00	t	f	\\xc30d040703022cb0f7b29979c1d46ed23701dc7a79f6050e7c991b0c246d9bb66da4306d40cc772b0d0c83d90ceb0549c57944d222af03a875f40a2e3944d16eac2a44cc69d6a8f6
2128	3	2025-04-03 17:32:00	t	f	\\xc30d0407030272dc5a157945093063d23601c4d1fea5856065a19340e06c718d6524e84a547b5af651b263a9039de477b9b1c20a0559e2db26b57474b76030da60ed1e6c1ffed2
2129	4	2025-04-03 17:32:00	t	f	\\xc30d04070302adcff95de8dc629069d237012b76469e7c81ae0049f09ee68b594d205599a36f767bd038d355d3dfa564137a7e84030526f1b82fa902ee0ba4cce6ae42c5b261a6bb
2130	3	2025-04-03 17:33:00	t	f	\\xc30d040703020f206030abc4cc116dd23601b83a06b17d220f12488d715d13b96f47071d3973a61e860e773d0fe4f66915c9cf62df04bf76f6b7af8890f561d1d86448388912f4
2131	4	2025-04-03 17:33:00	t	f	\\xc30d040703024edcd9ef662b958e72d2370130fdf54d99d9c3644e5b1e04fe9cf40a41dda53797f72b1d161301d62d8f55dc413db1aa836fff24cfd2c06f0349591ff52fadb848c1
2132	3	2025-04-03 17:34:00	t	f	\\xc30d0407030263e4d53ed4c0ed5461d23601e3f42c35fd27527e5db21b312b31450e365097f39ae37ffd790b223b0def81f043836c572801af2ead332e853d8058545117a13ee9
2133	4	2025-04-03 17:34:00	t	f	\\xc30d040703023613faea5d8c7c036ad236011637c4f30d2ac22bbf70c5b3b7e6405496e4f79f68549ec157c7f8bbe1f70900b38d646a18d92abe1803913537e7382ef8c32db00d
2134	3	2025-04-03 17:35:00	t	f	\\xc30d04070302f367e23b88fa836670d236010a76cc1cd94655d1cfd8734dd96934a51be47959d685b4e60fd99c2d91b025c54c3c62a11c91df2b34df7c7cffa34c9523807241d1
2135	4	2025-04-03 17:35:00	t	f	\\xc30d04070302f813e7f1155f6e7370d235011c9c0e68ac9d996f4b1a93653d21e3e8afc5ca8c160aeb87ef0719b927a0da75529d9b6cb2d61811fbe158e9937650fce73a9def
2136	3	2025-04-03 17:36:00	t	f	\\xc30d040703022e547fc065241f4061d2360188b5dedb9d6967c6b730234989a5c808317f828e1904135931c8c97ca43e2113b5529307df003d8aa88ddccd89cb489fe611831e4a
2137	4	2025-04-03 17:36:00	t	f	\\xc30d040703020f5bab02d8d637f761d23701e9e1f0474e9123fce113c01baace7c23d51b7dd1d1774535c0856060e8ba029c41329a795a5f94a455c58b59837d52b83238f7e2bf06
2138	3	2025-04-03 17:37:00	t	f	\\xc30d04070302cfd1eb30bdccf62a69d23601ca94e9cf43747f8c8a071fb8280b718acd1c0e9a91c62044889ae7c9c23562310b43d55f93f86a64bc933b943c1d89d40a9f886293
2139	4	2025-04-03 17:37:00	t	f	\\xc30d040703025efc06343694f84a60d23701c670d92ab9a1edb7cc136eb582f9a19dfd9f3758218b84c75a6e80e66464720bee0fb81f3fe9c68637f06c468831dcaaf865794fc53a
2140	3	2025-04-03 17:38:00	t	f	\\xc30d04070302dbe0c9773d04317f6ad23601ca930b1561ef2a3b46fc7c2d235f37cadd900490423590a32375a7b67cffca773ec895514efa2c65f003e5792b6cdf73e256d5a399
2141	4	2025-04-03 17:38:00	t	f	\\xc30d040703021c767167bcd8a18c70d23701c95f836c8fa231733f79b0add8e2b36cc5601b2ffa5295b4154f019ee336b12894bac61b5e5157971a2ed0c7049b4b4af266efa7e9af
2142	3	2025-04-03 17:39:00	t	f	\\xc30d040703023c6ccab486383c5178d23601519ece5b970ead01598829523eeebdec7bd9486e4e8f98efe15535edf61a6424216f93fc1da65cf335409fdaa560679b28261196ad
2143	4	2025-04-03 17:39:00	t	f	\\xc30d040703020c24643d8d6d54eb78d23501a7afdfac589e7aec79b2cc591721943cd96a36436abd3c841b58a2f52edab6d17d3c9687369f307f56fb578ecc8d77b9b35aa201
2144	3	2025-04-03 17:40:00	t	f	\\xc30d0407030200dd982bb50ef86b70d2360130bd0ca74bed4daa045a8a5a1806f780def06f88c5793aed05c8911e9c2078a9916a42ca7803a54f20616dc5885d86aaa10ed5bfc5
2145	4	2025-04-03 17:40:00	t	f	\\xc30d04070302a3e9c3914ded87ed73d235019ea16b37b6e7cd4bcfb3f3fb96e34bcdd495c3a2bde81e146b37a4381bf1e44d794b363d6eee022064b6a2cfd9cd45d44e1f3dbc
2146	3	2025-04-03 17:41:00	t	f	\\xc30d040703024122a45e70af00d965d23601a3b0dd7ef1e35e09d9b5bcde10176c039d03ebf44661e0ce66dc0e5489d208ad756355e08adc462de6394fa76e604c4f0dcaff0c8a
2147	4	2025-04-03 17:41:00	t	f	\\xc30d04070302814029c43f217e2d71d23701b49114f96fa7c35e4168e2ea87682a004336fe737ba081ff33c3692eab279675ffa82c041b1e1a05b82d463aa10fd19a8dd9e092f1cd
2148	3	2025-04-03 17:42:00	t	f	\\xc30d040703029bd8b4508912803e73d23601ced2207daf960029c5cd0cc412db3b510b670c11a7e840e4d59008000f4d2822d241372c8d8829449e9d0e67fc11be4adff14116d6
2149	4	2025-04-03 17:42:00	t	f	\\xc30d040703020d342699f7b2c69372d23501c93f28b582bdaaa08d0c9be3633d8f6ee4add7b7dbdffb75fd4563976656a8fe479c6c379b91c8c19cb87157ec472dc4bee030a5
2150	3	2025-04-03 17:43:00	t	f	\\xc30d04070302bf0dfd7be9d45ab67ed236014581a2f1f0eaf461a16695eb3e349a25ce184d3a4b9c62e00da5db098ca293f2a19c8c0f772fa2cb26f22efd6c464105b6c7d5ab50
2151	4	2025-04-03 17:43:00	t	f	\\xc30d04070302f90de58d94631d6c62d23701bf94bf43fe00f7234be12b8408e5b2f35903b6fdc5cd1026739d3319fde4a88e7fc555f604b0f03993a2255ae295d938bb8de0440f8d
2152	3	2025-04-03 17:44:00	t	f	\\xc30d040703027e6d1f540098c8a06ad236015c9bb12030b9f605adf23eb2a5d9bb39635c72b1ccadff6428b9137e82165c760f89419b61d1f6345be4abc28f79a19c098ce338f6
2153	4	2025-04-03 17:44:00	t	f	\\xc30d04070302876aa563029af75d73d2370176bc2a15c73698632e17ed469fc01dcc3acf5326b2fa99955932c7cc6bf16573afe22586639f93e333a18e404ccbc623033e14c79cfb
2154	3	2025-04-03 17:45:00	t	f	\\xc30d040703021a1acda4c83b75a277d23501e9cc530d02763342257b7e8b943b9f0e0be72d6a77a13c9a36f05f8d58607123ef62041c53b11489a28f86ac3ef764bfc40e6466
2155	4	2025-04-03 17:45:00	t	f	\\xc30d040703023d1e16865192cbd278d236014ca3c9154863ed177a0f3915f967f17a81cf4962ecfeffd52bc0aded85c5605453c8396f88dc299a9c541b58f160ed4c23e7cb882b
2156	3	2025-04-03 17:46:00	t	f	\\xc30d04070302b9ef8e473d2b961c76d235013fcaf74941a224efee411cd3b3ee78dff325ff578b43b44ab0b66fb9055190ca3248a89092f53337ba2678b787382a2eb5afbadf
2157	4	2025-04-03 17:46:00	t	f	\\xc30d04070302141e49c03a48fbeb65d2360144c1b2ed128df7e42509963cf490767ab2ac791c3a7575374af1a7c500a7310364c5bcd34da59b58bf0c2049836fcdc08b716184b8
2158	3	2025-04-03 17:47:00	t	f	\\xc30d040703023eb22f2571141e6d68d23601f3e1fc56be6ae827976045a7d9b91f5835d6d5fbeff0b89b3ebdd22026438ca7d2441a7a918d42d20a099c546019794bee06318e22
2159	4	2025-04-03 17:47:00	t	f	\\xc30d04070302b9a870cd938781157fd23701c3a4114a385366270aea6a6256e4a11c91222b7ceb0272a9e5235022d81636821fdb6df59ac4593e7b9e1501d64c8f5fe942090c7115
2160	3	2025-04-03 17:48:00	t	f	\\xc30d040703029c92c77cd39a062168d2350199bfdd99fe5f2e6b52a006ff6b3247df0264423e95527aa57ea493c37338b28e017c090dc8676816855740a6e0dd2ecb2da9704c
2161	4	2025-04-03 17:48:00	t	f	\\xc30d0407030242871de94bc82be170d23701e0e5e21dafcece69e07c00d5008c8b9405f884cf9fd289aa90a244588ae75fc88efb14983820ca9757880522e1b936b80cc9d1e12089
2162	3	2025-04-03 17:49:00	t	f	\\xc30d04070302796b3164e261209a74d23601bfc21f67ac021d1c4454b16a2abc14fe37c83f60bf723084bee695c019ebc045cb5c610e7ac11291f35bd89b92f016a9e2464cb2e0
2163	4	2025-04-03 17:49:00	t	f	\\xc30d04070302a53c0cb8c0bfd3d761d23701f8d2ced2083980c3c2fa7db3065258793976a5807c0d22d7328fdb7c9c679cb7c7d00c7c0190de817c8d1eb11bc8d00e6dcc1ca09462
2164	3	2025-04-03 17:50:00	t	f	\\xc30d040703024a25ee5b78a186a578d23601369c1f89d1f0e3b6779c00802e3a5fcf280e941cc1284ddf727dc8fe07fea297dd501ca53b31bc93aed0ed502c37a64ca275298bec
2165	4	2025-04-03 17:50:00	t	f	\\xc30d0407030289e29490144b65ff63d23701e13ae8f6356e4e6eb9eb873436d69a99ab6b16d936228a00df876e9a663b9a66d71efd6ac451c2df683f56456afa4e326ce6d0dfc3f1
2166	3	2025-04-03 17:51:00	t	f	\\xc30d040703027ad2a71d2fa6f34575d2350160e818c48d848ddc68cafe7bc421e658968ae0167e21ee4cbf55db12e101da195d4b396172668ec8374b1ee15cccd62b4732877c
2167	4	2025-04-03 17:51:00	t	f	\\xc30d04070302892099c0064a1f6f7ad237017c9e7832a1387dafd5a36e9dd44140ae7a00c98d36859d9fd5762f9ef5d831e94b42690f8a55cb61f8ad869459ca62532d69916e99fb
2168	3	2025-04-03 17:52:00	t	f	\\xc30d04070302ba389076c0b9a94577d23601a03bc6c295028e2976e184891db90b41a70bc6fb98741e67b37e9d71557063653216952422c5912e16e6693a0e4977d128c953094f
2169	4	2025-04-03 17:52:00	t	f	\\xc30d040703022dd70f103cf177df7cd2370113474fa01f8b4f146e69d3887ee7aa50db18762f402a01cb076d06404328bfdb7faf221d5fc80592cefd62ba584437c3d9c43a00004a
2170	3	2025-04-03 17:53:00	t	f	\\xc30d0407030222e1e22f555bfbf17ad23601ff5c89b0b556c09a41256d7e4b4f37df3e8032e417da61a0876bd4f71bf95337bbeb41bd4930b2ac596339a45ae801e8c6c3320f19
2171	4	2025-04-03 17:53:00	t	f	\\xc30d040703027a7c3e64cb5455be79d237010f3b13625fbb3a1df76c7e04a828a059a7ebc5c28bbc7b3a7dc8c6a509094480dbaa248cce786477e6f76ac272768ae5bb4780608962
2172	3	2025-04-03 17:54:00	t	f	\\xc30d04070302fbb5a7fc708417f363d23501759bf855d43e036d5d4bdb568217342486913d9251ef5b956fadc870f7a98a73a939551dc0865af6d9501f8862692f68d611cbe1
2173	4	2025-04-03 17:54:00	t	f	\\xc30d04070302b3a9e526bf7b3ab76cd2370169f30107513ca5ed51903052b6569bf82ebcaab7a101a010fc191f3bcdb8ca959f556560e806e218383d34a4051bcb7607c494a68b1d
2174	3	2025-04-03 17:55:00	t	f	\\xc30d040703024a34232827fb7f2d77d236018d94f7381fed5acb06e0f7bc982e456f2745a6d51fe752f711ed95042bc9491ff017390cb0c2438c7454ff661408c66b9ee2c0fa0f
2175	4	2025-04-03 17:55:00	t	f	\\xc30d04070302c5bd53687d6661e473d236014e89d3a2a217fdead771872fad81ba3295868d35aff3572ad2934f895e14e03bd5590808678aa5b8ae5d7b1a159ecf7e420190857b
2176	3	2025-04-03 17:56:00	t	f	\\xc30d0407030206585f9c2a11aa7a73d235016b51be59bc1accd7a9d431b7700aa2ffcb54c965598934be916e202255ea9d7fe30d4f45b8e6bedd93378a525dc85669581f5d17
2177	4	2025-04-03 17:56:00	t	f	\\xc30d04070302c661c869ebadd1477bd23601bc27e29d8f78aaf977f30e2a094aa69d96949651e10488558f4c12ecfd9ae30d0171bdb8fec6b9a55237e6a9a1cd9f177a0da41d03
2178	3	2025-04-03 17:57:00	t	f	\\xc30d04070302cc751848c9cd93c273d2360182f2e5354f09de0fea416b842782b82ec06ece57095c38a6c04f5e2ed1750656a8e6787d510fdc94558c24f8a2d5043d273d25f4f4
2179	4	2025-04-03 17:57:00	t	f	\\xc30d0407030276b58f7ca0f09ef374d237010a494f3607daf56ea2ae47f8821c83c9df725f2fde592eb0993334fc3fff464baa76a77e4fc78e5e5b303d555dc9edd5a932007e1df0
2180	3	2025-04-03 17:58:00	t	f	\\xc30d04070302fd86b567f8315bfa73d236016224fe6b39f60b3539c8e8cf9b2d32da377ab0c285a9116793cf0413f9a4c41c638de2c10a2b37cfe0e8bb9a40e68322281b618213
2181	4	2025-04-03 17:58:00	t	f	\\xc30d04070302cb491c697469fb746ed23701f5cc295dd1c0c149fda50710a7c0d7a4ac4ca7319b313267e202f46cb604ee6d7e3f316ad99a75913ce8daffd40c990d8a1e9aa655b6
2182	3	2025-04-03 17:59:00	t	f	\\xc30d04070302d3d80fe67d80e79c7bd23601cb7950046bf11547169c59b180d6ec8a8607627703c23075a6a81087a0170deadc187e6d0b2b244cc220c7d0c28e04f50d95caa2fd
2183	4	2025-04-03 17:59:00	t	f	\\xc30d04070302143d86f962a8a00a64d236018f26dd9224516b6b39466fb674df51221cf6f04206eaa5e2fcd25936685d793099e3c6809e526025d0e785465ec52c90a1108c1bec
2184	3	2025-04-03 18:00:00	t	f	\\xc30d0407030297aef1993e6ab58467d23601ff0d1b482982e04bccbe3285e8b356e4714ed355fba0b7e050b7e883ea0214be26835d7db95e8dea97c9b9be44b749a10c217b9567
2185	4	2025-04-03 18:00:00	t	f	\\xc30d04070302a12c910e2f41b3e377d2360196c0b7baa011768fe3fba5531b230903fa2e49abb4b03d6aee1e251dd7088e02b5fff853020a810ce308ca51a4ba8ca3d91290295d
2186	3	2025-04-03 18:01:00	t	f	\\xc30d040703022f6b2acbf5f3784762d2350180667ea6169dc50b9d8137d49c974ecfc20078b385777037e1d71f5a20297703a91ae479cb8f803f8146037efdb44f743776d0f4
2187	4	2025-04-03 18:01:00	t	f	\\xc30d040703021ea06f129b91873d77d237017a79bd47ec84973a3c9b9dd7f12b2644f689bd343dadda94bdd41db54cd289869f92a417c66afd11d465621ee7012195a3e38568ab53
2188	3	2025-04-03 18:02:00	t	f	\\xc30d04070302c36515b10b8ec77f78d236019b61c0c49bb6deba45a45ee2e5e630a0bada208fdfc4d54fef21e60d972cec182b77faaf46005e82003f966b918e2b01c1e2921858
2189	4	2025-04-03 18:02:00	t	f	\\xc30d04070302f34d7c5b3f16f71c6bd23701779f85e28a8fcbcefb1f5b864d7bb1faf4d03892bb8fe00ee6d05495c16be1b26e66689f0a754184a82221cf5ef834d2a0e857795cec
2190	3	2025-04-03 18:03:00	t	f	\\xc30d0407030281cc153174627b5d6ad23501606e8641f31f5529b1204a317d9d318679cf2eb8713f8f59ec3da40b7f1264f1db37a19c30f07d540f8f2c2080923678d7ae7f21
2191	4	2025-04-03 18:03:00	t	f	\\xc30d04070302bea322cff4e0ed8677d23601428949724f449640e837352e8348484d433cad0fb6036e5d6be5872b287245b5dc679788cec58393cd2f5a5cb93efae0b143f7537f
2192	3	2025-04-03 18:04:00	t	f	\\xc30d04070302a50cc47eb70dc80b73d23601050fdcb153c30a18f668810d9938f5a6af56fa349b117a78ec0faaba6780fda5414eee9d0ea4a339b1c4cccdd7a6a0f2765dce9212
2193	4	2025-04-03 18:04:00	t	f	\\xc30d04070302ee86c3a7fff406237ad237015f0e1b4e8a3d1f8aa1eea1931343578c0a5082a1e3297bf2c6523ee7fad7b69994b04a3775ec6abd332a470c3e5af4dc4c1b0a974eae
2194	3	2025-04-03 18:05:00	t	f	\\xc30d0407030263536c4488ef75b56bd23601d91a0c5510093c6099db17016016af95310ac751c0f99bf0d57304f63b7f00813e07da24d2426d9a9b9972d2f5aa167e0ed322bcef
2195	4	2025-04-03 18:05:00	t	f	\\xc30d04070302df06ab22c79fb8b87dd236010fefb9fd300f1f49b3c5ba8a717ea9fbfa9a6b5958f0c69eb2e21352885a0f7f08420a6151bf1b9a55735a9e6926364375acaa11b3
2196	3	2025-04-03 18:06:00	t	f	\\xc30d0407030250323e06c0ba2e3370d2360133cfca66cb0bdf80f9cc7a88d149f5b20dd4106a459e847b9d8c5326283daef57a6ae11004102b7ba325f469b2e4df1185996dfcd1
2197	4	2025-04-03 18:06:00	t	f	\\xc30d04070302c8b264ab58db017264d23701bee1ba0d2a0f8a2ce37e8111100dd32ea81ad66746eb43ae364796210959b42e2089204b4c07205b0012589cecdc0a290dd543fc5088
2198	3	2025-04-03 18:07:00	t	f	\\xc30d04070302087a6d19fd908c6d79d2360117c749e62bae3aaf89d2484d96b34f6e5830b5c3964abde83b031ed65f6fea6706db25d62cea4853c57174d2f3c09794850128452c
2199	4	2025-04-03 18:07:00	t	f	\\xc30d04070302e9ebdbe9bd2260ef76d237016583fa86cee9078828c75e7fffa4c28d4ce78874535a001e29dab815ecb2ae215d8ae06bddac5393fb6b8cd6a97f08a2d8d29753ad21
2200	3	2025-04-03 18:08:00	t	f	\\xc30d04070302b0e60c9b600e61467ed2360179b7e1183464af0bbf6b263033979ad34663e6e5d235d06142bf5dbbce2bf96f8a03c05ee1dc7a8337479695f34d16c79e4e9fb8d3
2201	4	2025-04-03 18:08:00	t	f	\\xc30d04070302de5e4b419a2de0fa63d23701d2abe1de1f9de99411f84cd151470de244a0c4ccacb40e19ad5e526509d0eeeece8e63e9fb05c1d6faf747ed76f60daee375ec134b21
2202	3	2025-04-03 18:09:00	t	f	\\xc30d04070302a2dd1ca1c0f7ee6c64d236019d43993fa86155c8d957195f1794c37a70260b333fb30b3cfa00bb2f3e8717a3d6514b649d65b14ae6d3fa0a97c6babd33fd95c831
2203	4	2025-04-03 18:09:00	t	f	\\xc30d0407030295f96dfc0fc61f246cd236012de9d5799c21aa7d82b9626f15a1b0524d8ed33a51bb9cb98247ab5e171ecb0e99fcd8ac7bc3a19b263e38112fe7dac0f36f8a0f93
2204	3	2025-04-03 18:10:00	t	f	\\xc30d0407030261e78b6df38039b672d235015fc6d83fcaebc27af0a1def7b6b53d671ac0775165e5cb9b83c78627e98493cf308d5dc8096dd1f7e5c32cac88379df9c38a629a
2205	4	2025-04-03 18:10:00	t	f	\\xc30d04070302982ca122d69cae4c60d23601b028f9fbdaf87cd1cd1950230548610444d8fc237d636503b0a7e8cad7b164544f615e96a5ca2b7d7441cacd5597ce32337c2fd05f
2206	3	2025-04-03 18:11:00	t	f	\\xc30d0407030200488499854051cc7ed2360136ef69edb4368190af8ba5abab361048198833f85c7b648837b626caad2ec70ffc4514ff24e52e363bb533d9d5c9d172d56b7c3076
2207	4	2025-04-03 18:11:00	t	f	\\xc30d04070302f2bcff949044b2ca75d23701569d5f4ccb54eb9f177d841aea174efdad18fa68fbc1171c9f181a5e9f0424c4679ec73ceeb46a854af3bf6dbc1d367bda142b900ab1
2208	3	2025-04-03 18:12:00	t	f	\\xc30d040703021d19e2f66a6da99b78d23601f62734d52ee158beee346260618efda102a025d064cdb0860f9e1a600b768545f182f3b3d49b7bf1a99a3746bb7202fa722049fa70
2209	4	2025-04-03 18:12:00	t	f	\\xc30d04070302c9460d16bc14fb1e61d237019f665ef2d75cf793f2401557a99e84f57c16a1bda0a1c981276b7f4d7d44651dd27876fd5413491f5d1035dc386ef92ad2c76c0c5717
2210	3	2025-04-03 18:13:00	t	f	\\xc30d04070302c9d37dafc63bd1386ed23601a18e677751ad2a8198259f6d58ce438d7f29824d2d5f5c3e8d4564c3267822557ace7c96a6442e9eb8d29b237d4782ad8498dd2965
2211	4	2025-04-03 18:13:00	t	f	\\xc30d0407030237364d834219a0d775d236010373da0cdabc91c10da1f3c729376ba76b179dcd806c6ef53901f33d21b70f9e57106d82af542167d9878520c173c2a7096faaf697
2212	3	2025-04-03 18:14:00	t	f	\\xc30d0407030285458effba8892fa64d236010ce33f18a409786cb8586015369cf89c054af237d3db8a4cca0f6494e14a99fa9bb52d346a629fd55c9d004206aac6ac66bb53137b
2213	4	2025-04-03 18:14:00	t	f	\\xc30d0407030295bd7de85cfe7bb478d23701935b8b0bc70647fb3a1acb0966620e1afb3e3ee494b86e5ac479dfb022891154f18022a0ddb05da6e513e05e6ee14ed6e24a2b681d68
2214	3	2025-04-03 18:15:00	t	f	\\xc30d040703022edc10d5c807c8e073d2360122c967dad80a4a9f46aa44848b0ab89c5814b848bc169a6b18804625f4b28b944f2fcd2a88bb4fdaeaf10f61f2681037a4e4e1160a
2215	4	2025-04-03 18:15:00	t	f	\\xc30d040703024ec8bca484eaffa77dd23701aa0e3958e82fb4a1bf22d5d2897dbce0822e121f3178475e599f54b176883283e0ec26132ff89159deb0452a9fdba9046507370d5b1d
2216	3	2025-04-03 18:16:00	t	f	\\xc30d04070302325ec64a1d8b4c9c64d23501259126c4cb532b0fdafa458f261ebd338d06250136f5c89b9c7add6f7886517a23114a809ffd7887dc4e42257d546aef8c531ed9
2217	4	2025-04-03 18:16:00	t	f	\\xc30d04070302a343f4e22559424362d2370100929bc7e95e2717706adc24a85e2ffb6343c6397f24c486d6901b0465815f173ca8fd993bdaf9feb0f6b2fe5b99caabeaca79b2f8e5
2218	3	2025-04-03 18:17:00	t	f	\\xc30d04070302568402fcac01b9a36fd2360174427a1eede1f11a23da97719220fc24abda0f796fe32244b6a70cbad3324e3e05cc37de5d071b216ea37153f2d6a2d61534fbaa7b
2219	4	2025-04-03 18:17:00	t	f	\\xc30d04070302f9b4319a60ceef157ed2370197838848445b884d285778d5340f8842629f647a8d98562c601b86f14cf343247f248101a128fca76771e630072afbbc50fe893fa53c
2220	3	2025-04-03 18:18:00	t	f	\\xc30d0407030212d95daf9ca84d0d61d236010270915d22b858bf29f88bd9185c7657150d1853c5757695dc9cbe071360ae9d45cb7d008cb4de32f7b99cc453f439d7fbbce4487c
2221	4	2025-04-03 18:18:00	t	f	\\xc30d040703021bf38fc63f0893bc7ed237018d831758597e3091d1e04c16fe5b43aabbfc43326d3c53828a489d1f96443bc3664fa8479c444035f43c53109603863d5e2c4a947f56
2222	3	2025-04-03 18:19:00	t	f	\\xc30d040703026f9b7b799714726e70d23601fabc2fa837157dbb269cd3386cec5dfc7640d6d22c2ee5717f59fe6b064158f665748fa7a41a7e7dc621462a3088e4a6be3dc45a9d
2223	4	2025-04-03 18:19:00	t	f	\\xc30d04070302377c142b79a6a5c56ed23701a96ed66997f272f14ee61988390593b4baf0098f422f0b007f4e3489bb630800fa2fdf36d8774eced0a5d1ac8f96315e86a86a2c271c
2224	3	2025-04-03 18:20:00	t	f	\\xc30d04070302c418e7104fe668e77bd235011b6fec157f6f72398e977bdfbd33fd4fabb53e360ee1f30037cb4768d57e9dd5a47e4e8914afe4f548ef9f61552ca4b5f11cb5dd
2225	4	2025-04-03 18:20:00	t	f	\\xc30d040703028d674af96959e5177cd23601208a6f322736c046bb5ae23c104c970d8dddceab05c0b9b8180e8dfaebefa87e3c7ff9e06c7eb8343a3e94907d947576ebe3d3ad3f
2226	3	2025-04-03 18:21:00	t	f	\\xc30d040703028be6fb3c6966d4526cd23601b527344fa6a5121b98fd1bfa509d182e7841ba3155afb4e88f713c43ba6351a128629e016e53d29d370556085ffa0813932cc0fe76
2227	4	2025-04-03 18:21:00	t	f	\\xc30d04070302de33dd3382173f6070d23701e964c7782b367797feb8053b1260aa4df7726abd983e62b579c19aebd15954ec39143fc01d3105b5938ca9f8f1f7064eea36efea9274
2228	3	2025-04-03 18:22:00	t	f	\\xc30d040703028399dcf364332e9d60d2360173c08f1c0ec67a02079f8ebc32cfada29f53ff82a945658a4cf7881392cdf6bd8e3c0872987536e33c1ede034a23aff57e2046baaa
2229	4	2025-04-03 18:22:00	t	f	\\xc30d04070302c3e0d7fba4f293f771d2370171437ff93f91721d410fa160460a160d019d91a290c80f7fb3622ab9bf709d7f3f77388c1b0787aa94456da5456cd4fe0e52231f6163
2230	3	2025-04-03 18:23:00	t	f	\\xc30d040703026adfa483da46dafa6cd23601cf2660d9d409f4202d12546893c740f424c73a65af68ddc03dd978177383fbb8b9283f56036f180c9eaf1a6aa4b4d24961ab299ed8
2231	4	2025-04-03 18:23:00	t	f	\\xc30d0407030213f03061197019b46fd237011b1fae05a1235e47804ca38e1627a682d96f9c7ef63a455a7387b18de859507933e39fc29a0e97d0cf839337268c3417f0b51dae3b04
2232	3	2025-04-03 18:24:00	t	f	\\xc30d0407030295711771d14ba26172d236010dd10b9a63dc3147eee60bcd054e127bdd7444ab43e5145cb6087dd5cb91d385592c3f83fa86b8886edcc6b0a3f919ee7d9dd90cd6
2233	4	2025-04-03 18:24:00	t	f	\\xc30d040703022cc34694283fb8766dd23601309b76c15a34e44e4a8da04061a78565741a7a67689ea0894aaaa93c078278643120f2bf735de983d49f06804834cee4912aa147f2
2234	3	2025-04-03 18:25:00	t	f	\\xc30d040703024eaef7e21b52df357bd23601dd2e2da009ec9e9c504ae4db6a57d476e6c811ce0c670df88ccdeae3011653cbc70aff02e0106bb4b9627fbf2d9f82ac4c3155d64b
2235	4	2025-04-03 18:25:00	t	f	\\xc30d04070302449621f369e5048a64d23701fa9007c9f301ddcf00daf749b8dadb03d44a25c0ffdf3be8487473a5c1665e107137d811cec9c91b5869474a81848cb8137ddba6d585
2236	3	2025-04-03 18:26:00	t	f	\\xc30d04070302f01550f93440fb3572d236011bf518ba8105078f89d60a1541412c4ffe9f04c525c4a64f01798204e16a26f2cf69a6ed772559ba1edebb5697c058e7ca0732de02
2237	4	2025-04-03 18:26:00	t	f	\\xc30d04070302674e2fae397f7f2b62d23601672de016c6bf93c000aa32f6c88f0626b4cbe0c3f68d0ef3e3475bc0322324f7cdcf408f62e90ec1eb919f3a1ece2e2a3b37cc9b6b
2238	3	2025-04-03 18:27:00	t	f	\\xc30d04070302296b771ffd675add60d2350185a890258af61731ff61b9f0a372ade0c813e3af00a39962775952c4991fb20a93d716ee4ee0812da70c2b55609a6f1d2113ee20
2239	4	2025-04-03 18:27:00	t	f	\\xc30d040703029b5daa7839319d8371d237018b3822a6395fb57d43aa4717e9e2e44b070b8612938db34ba00952d68f665416e9582ad9132a041d159e4edff13d00fc5e62117ee8d2
2240	3	2025-04-03 18:28:00	t	f	\\xc30d0407030203addf50a9f6a77769d23601a8f3d81a252c2f7679a0ec30170c0a0181a92d316d7f8f02d02d6f761d10f8d4aa115e74695ed93c0644a80f7295520f99641c0cfa
2241	4	2025-04-03 18:28:00	t	f	\\xc30d040703029718994058d4b2c868d23701ee0a809558551faa389cfe4cb89b703d2dd07ed2a7d7b4ceaf521a83d7ebe20926e264d1aa82a6e033564ade7ec64010ebd29cb01ad8
2242	3	2025-04-03 18:29:00	t	f	\\xc30d04070302d7e30efc8c60c36765d2350186be71ae6be202a2ff132c06cf649ac2f71e76abb0c1cbc956c42d25b64a9544f94da05f6f4dcfcc1ad30aa223ed9c04eeacb7c3
2243	4	2025-04-03 18:29:00	t	f	\\xc30d04070302d4e74857875f0a027dd23601af2c50ea017e502ea315453cc484341256bd695bfab36d72ff65ec4f9136a4b3827e660e25bd1a72d503054719ba3ba29336e50315
2244	3	2025-04-03 18:30:00	t	f	\\xc30d04070302766e97b5e9d7ef2876d23501483468b592014aaf1ab037aba85413a430daddd52299af68db564a6929c1ff19f5d5037d91038d90ab145fae64dfa47a58f738ad
2245	4	2025-04-03 18:30:00	t	f	\\xc30d0407030208f540743168f6817fd23701cd69d5e40e2e167f48e44b33a445eb63795291fc19f5f5ae1cff01b32207ef4c522993e9f342974db0520f09cf82473117fd004324fc
2246	3	2025-04-03 18:31:00	t	f	\\xc30d040703024de2eaff532b6cf76bd23601e0029bbdc6b6d43c0845209fca71eb2a4859e31fbe09dc8e980f953a82b3ef3007f5792e8c85dc0674ef5837695c14a3345cd6924d
2247	4	2025-04-03 18:31:00	t	f	\\xc30d04070302b883a463e8913ef768d23601d2f4f1c3cba0107b25891189d2c5a6131d784f720f4be2959d1fdbce70ea70539f6a1ab4795597f8cbba5b6597a83b5533b87293be
2248	3	2025-04-03 18:32:00	t	f	\\xc30d040703020b598faa830222e664d2350104a1cd2bf3909f62bda922b830b9f614b34481ba2913081bde883f46ca0bab7cad39a60ff4c2234a83f8d31d1d1188876ef55566
2249	4	2025-04-03 18:32:00	t	f	\\xc30d04070302be5e807c4879693269d2360124459fc49e198643ce00c1ae16466e9096d0edbe6989b3acd179a49ce4dce31b2059aca842f56e7b89dfd0218018d8f09a34f47b9f
2250	3	2025-04-03 18:33:00	t	f	\\xc30d040703028c295943eb47830f6dd23601cc239d805fea0ccd5a19580e8354a70c11497744599c92e3a34bded8115f20055a5838a47d23ac7e26cfe7113eb06a2a60792b580f
2251	4	2025-04-03 18:33:00	t	f	\\xc30d0407030290963e8ffe8b94fb74d237016715379067e7778950108757411aef6b57c1f08711a8725c82b09023a578fcbdac5f2b526d350cf9c1e77cd1de791637df44afc3bd93
2252	3	2025-04-03 18:34:00	t	f	\\xc30d04070302dd6fd0aa35413e8060d23601a80a30de3d03b68b9cdfdb16d6fff02e99794b542ae85d42fb9548f9faaa37384c9a3a1d73f2b5986751fcf6cb4100cdcdcacfc72d
2253	4	2025-04-03 18:34:00	t	f	\\xc30d04070302ab9f15badbd86d5960d235012e41dee1c1834afe43796ab7db046a4f59ec16572ade5ec193701637468cd227250d217b98e18f7c527bc4ff4cda9a9343087612
2254	3	2025-04-03 18:35:00	t	f	\\xc30d040703029cf8980714cec5d766d236014ea32d68b47bbd8ac6e5dbb9b88e5c8b6fe3ad140d98c2c296eeb5871d694ab0f3bc5c0528a8bfdcb96888e7e9762ad90489988943
2255	4	2025-04-03 18:35:00	t	f	\\xc30d040703023f766dbae9d40a5467d23601b5844ad4d04c67f93ce5503bd895d0f9c3d2dceb744e2a53a6ab1780087f560a35fdf45f6e5be9b54f705ca054ea4aa86b1467aec2
2256	3	2025-04-03 18:36:00	t	f	\\xc30d040703021e82acf00ce1d1657ad23601e39d16e64fe3bb241820a9fedbba0ba989f11751ae3c70b85fc2d1c1baefde47ff7730fd2e9d414c1fe70b2a10db1cc32ce2aa32f7
2257	4	2025-04-03 18:36:00	t	f	\\xc30d040703026c9ff44cd56c1dda76d237017dde2a92e2af691028ca83f16339ce665a244e293e718ab741064e8b93327ba7109c81ca700eeb6a07e96b0f11c70246028d2cb4f949
2258	3	2025-04-03 18:37:00	t	f	\\xc30d0407030252c68a36ad3b867262d236014873b2fbcf75d9b05eb26effb75d25d431e9369e0a3214c4e16b7bf8a9028e3958abbd906cb6ad7cb9bf21c4e1e11d16fa9664d412
2259	4	2025-04-03 18:37:00	t	f	\\xc30d04070302c4f96761a73d2fec65d237018db08a7c0c6274c386c7c33d01abad19b9ce9530243c45b986c8108e441118388abc55bb67ca2a5974f6512bdc1475d20c7196580d1d
2260	3	2025-04-03 18:38:00	t	f	\\xc30d0407030211279e048acdd4d863d23601760d3b92b6d704c6587460da4e8fcbde29ef083e9a9fbfbec46b3b1ca4b5dbc40f7e4c71692e65883c9f970d86f6f28826c993b6c1
2261	4	2025-04-03 18:38:00	t	f	\\xc30d040703025504205e36ee630979d23601fa4a1ee0b2ae5f6a4e6a396e514527aeb0a6f286923027285aa2900847231e90aea64cf589f1d803b8dfc73282479dfcca1f9a35dd
2262	3	2025-04-03 18:39:00	t	f	\\xc30d040703020fc238f953500e1172d2360172ae50b9fb2233368b5bb552b5d9c5034755792471c75b89c0c302ed4777f45cd0ec7fc3b96f42338c4024d03ad73c17f1c254499d
2263	4	2025-04-03 18:39:00	t	f	\\xc30d04070302f64c1a1416855e5e7fd237019c1d83cc6e327c67446bc00fa2fbbe5a9c83534b70b0fe217e58b90b3b332d602cc7515dca84eeb23c839b71debfe1b2a3bdee047e5b
2264	3	2025-04-03 18:40:00	t	f	\\xc30d040703028e35a29311952cef69d23601d59233b86a62ddf634cece314a9530b8575224c83e13699658e974b2b6da4c8756d42138cbebdf04d307e6d7b43f30b909427ee310
2265	4	2025-04-03 18:40:00	t	f	\\xc30d0407030202f101f98a157ca360d237017f1ed5233bee009f7f3a142fc9217eed9297e2b89c6b7d2799a0722c727952249e5485f48696306b3bec8afe1b0bb4b444a8be918ffe
2266	3	2025-04-03 18:41:00	t	f	\\xc30d0407030267ca036db2ee757569d2350172b0d4d1a29f96f817fc70aaa395de99808b7791fa5164b952470edc713c68a5d85568f76b97a80ac462cbd53f87b4adae087261
2267	4	2025-04-03 18:41:00	t	f	\\xc30d04070302e55e82733c59ffa06dd237017ea0988b90b44a36dd51ddaad2e70e2353561e6d1df4c29fcf464728542088b6a6f0b85482b7625ef0a79a8d1723342750623d41a574
2268	3	2025-04-03 18:42:00	t	f	\\xc30d040703027a573920cfdd97c867d235014c45e209f30efc05269e066daef7f5c6e6c941a4e02b5159fcbf3e3483f35cf594039b538f95496b2c7b30051f095210aab2d948
2269	4	2025-04-03 18:42:00	t	f	\\xc30d04070302138527dc84efc99b78d23701481ef31e285cc22237a2bb7feaf5eae15feaa88b050c6ff0cb81bf9b8f254f3cfb629aa3634c266d641ec86e5df3463f8332d445a6c8
2270	3	2025-04-03 18:43:00	t	f	\\xc30d0407030204e7bcb392ff0a1863d236016d48c5e36defb8fb3f2e8f19dafa70f592f49512b72f2f6729876691a8c92b22d8784a2cee78c765775e8956f192e1b1920ab4e094
2271	4	2025-04-03 18:43:00	t	f	\\xc30d0407030205c90c06a0d5894a67d23601716ed1e48053bc89e3cfb9f7882c0cd52105ee31e0137b5d692c2dab9865c1863e07f7b8eceeb8adbd135f5de72574a4672b3dce12
2272	3	2025-04-03 18:44:00	t	f	\\xc30d040703028f1b38747768212860d236012c68f1177903ab93fab0fbc9f3fd6c5d364169b6047896d410f1bfac11e9317a76d3547624af0339c8c168c8d811247cb8d6285b1f
2273	4	2025-04-03 18:44:00	t	f	\\xc30d0407030254bab193cd45316179d23701deb9c62c9e3908e81ff231d10416cac492531566d6b5350972b18d3c27428a94d393475d3496d4100500dddff8b8035d1acdcbd1ebb9
2274	3	2025-04-03 18:45:00	t	f	\\xc30d04070302f8cd03d3723fd8e172d23601a26ec87293c8f73b0be3f296dad0c601718dfea47e88036e878d2a1e163aabec26774988e1fc948308a3947a3dc5399dce391295aa
2275	4	2025-04-03 18:45:00	t	f	\\xc30d040703029827ae0e03a4f80471d2360187d8e7fc46f3e3a527d57b90bdbad031bb1b3fc131139af01f52513de061d8ce9c18fbe61c225f448eed1fece8bd1f9a5b092eac46
2276	3	2025-04-03 18:46:00	t	f	\\xc30d04070302a114bf647e95624375d23501f0a9ad1f544416acdfdd3045a9d6bc6490d79b17870db1a98b1e2a6aefeb6038925fcc123d0dbcc9e2655d12b841adf8baa0ea98
2277	4	2025-04-03 18:46:00	t	f	\\xc30d04070302ebff9080eafb89bf70d23601b8d6b1e2447e32454653a82caba6e2f3541828a28139e3743cd3b46eab93a8cfc6bc62e348d5ccfc840d3ba56aaf3d5bd1be89cf32
2278	3	2025-04-03 18:47:00	t	f	\\xc30d04070302f4f308d4f527abfc6ed236011fbaa1aa386e203ddaef4759f1b2af39db98d644031b6cad346ca511025340eafe9041d584fec975a76c11a988096d7a03a7e34774
2279	4	2025-04-03 18:47:00	t	f	\\xc30d0407030265ca9b846890fdd765d237015e24a4e206ba2f697f2a6feb291e2bee320baa5f8e7c229ca4bc33b9680179cc37c9cee3fd94a72e176d1c1027e83c2eddd28a1ca8a6
2280	3	2025-04-03 18:48:00	t	f	\\xc30d04070302bd663a2c61a2519761d2350106289b4ceb5859e2442779dcff1a79241fcedc65d023c90ddaeac9fe3a05fd7d71248de8a21432bbd8bfb7cb86a2b25c2a2173d7
2281	4	2025-04-03 18:48:00	t	f	\\xc30d04070302f6265a5a205e920264d23601b42e1082ec9e5329f8b66424af7b4c82f2619868e5464b2ed6553699fea466ad6b2a37c5500a7a1f10e064ba9a9cf8217d7a051e46
2282	3	2025-04-03 18:49:00	t	f	\\xc30d040703020b06793cb96924ef62d23501303d3c8587419a796abc11ab703ec90d560f4f6507abf095bca9f0b3637cdf5208b83465aed41e83b407a5ccbd78fdb63673c457
2283	4	2025-04-03 18:49:00	t	f	\\xc30d0407030272452e35581402596bd23701ed4a6f7112dec891451263208c164d2d1d76b2290033412770a634228a69c6b87e5fb788aecc9d52fe4eb9a83b115c4cc8663f664951
2284	3	2025-04-03 18:50:00	t	f	\\xc30d0407030231fe957c057c2a3166d23501490808a71053abd5383eb4769fd0855a501bf0aed537efef6599ca33085281092333006cd4648e454b4dfd6d901078d7f5c4bd7b
2285	4	2025-04-03 18:50:00	t	f	\\xc30d040703024dc0cd30ade2f5ed6bd2370114f847904bd89b794a0bf244d032df6b93ee73e7b64dec031c7fa141d447ade3355a818169dd0e64c7994739f3f8736d137f1c0336b9
2286	3	2025-04-03 18:51:00	t	f	\\xc30d04070302c92fbc830ead661e6bd2360195a4e1711f00fd2b49745f035d17d14706ace059ba31465f3f59b59acc2a755d6225e709e01e7282c8285fe5de2bdb19d4cea5c50a
2287	4	2025-04-03 18:51:00	t	f	\\xc30d040703029e36dceadbf98ddf65d23701faac58060f3fea413d659ea10f2545afdcc52e6ab68575e916a43a86128f339eca4d2cf638a398dc3633a1b1de81a534f5cc4d2f6a54
2288	3	2025-04-03 18:52:00	t	f	\\xc30d0407030272e9824d8bfabbd861d235015b0e5f0597dc91907e17a4b459600ab3d611533bf959bf84a301e461e440080228212b0a67e9d44509cc573dcd8fc57f7877ebb0
2289	4	2025-04-03 18:52:00	t	f	\\xc30d04070302e0dbfe18435a772962d237015dd3d46329af07392804d328c6df78c8aa24aadad4c3baf1402586d4c539c5abd0faa25c72f447edc4da4fd91e40533cfb0f6dfaf3ce
2290	3	2025-04-03 18:53:00	t	f	\\xc30d040703021d5c7ca28a6970de65d2360111721470878f604832e0783cc4b69c2cfec07a6b2abd0505a77e8acb6a35b3d0127297b85e673d7bcbe35ec64d1f38506aa0b5f151
2291	4	2025-04-03 18:53:00	t	f	\\xc30d0407030208975d083bdc87d475d23701ad317ef8626e8186ef711c8ec8a431bd228e270ccf0e441e5194c241707cb8b85863dc84495682c877ecd6299e05aa916da4178cc98e
2292	3	2025-04-03 18:54:00	t	f	\\xc30d04070302409e561a3ec3faff64d23501369418091f710ef8ff9703c9d1f2ae4e9e2ef1cef352c535db8482263b2c8e8ed111dacdeeff89166f65ea90d61d75149a692347
2293	4	2025-04-03 18:54:00	t	f	\\xc30d04070302b243e7af7f71fd677ad23701ff2792cb0a07f02b86a3202cfb2d114a739f36f60a129450d4e5338a9a5499f5a9863c425cca8910e29fe3a684dbd0023c817f811632
2294	3	2025-04-03 18:55:00	t	f	\\xc30d0407030291f56c5f1b5f56777fd23601664f194788bc338b8505dfec5c8d1ee7726b3969bb0f0604cc2793431c38d9d9ce03162cee8e818e95d449f0abe5fe1b714a8814ab
2295	4	2025-04-03 18:55:00	t	f	\\xc30d04070302c141a8e7658afe5173d236018788fcb14b5b00a1b67b9cf3f5e2c73256caf55e64b97c0ec3d772f8b37fbb22349e15a6045148a38efcd82093e37b1be24bab4bcb
2296	3	2025-04-03 18:56:00	t	f	\\xc30d04070302432d5822eadcd27d72d2350185176f3b73d05d08734c10545d0166fefca61306e0571085943568e7799324724af3501e450cd41837f771fbcd82aa91e5bab355
2297	4	2025-04-03 18:56:00	t	f	\\xc30d04070302f3c3dc1f8596f3616fd237018e93dae69d63ebca9230a5c88382ad095b55eaf113f316c202583d32846a09cabea1f0e766b8a06df0a26eb1d890d8b53393eda23231
2298	3	2025-04-03 18:57:00	t	f	\\xc30d04070302427e44f4e36e7deb7ed2360170de3132798721f5d5f14851f5ce6a11696e71ac65511cbff3c6362ec89e756fb329152a8535714f896fb87edc2d8c3b3d0531d130
2299	4	2025-04-03 18:57:00	t	f	\\xc30d04070302905e3e8a871526a362d23701e8419bb63441623d025d613c91cc69a4ee433362654d8a70a783f957ec65a562a77a91ef701e4244e621106f7482182888df88699882
2300	3	2025-04-03 18:58:00	t	f	\\xc30d040703023185c5a18725668662d23601c2093cf481768721d7fa587a80f45bb87b8e4d1764248e1a8ace7bd752c2fd09ab3c006fb5fa8aa1b5737a3d7b4180577d76a80ba5
2301	4	2025-04-03 18:58:00	t	f	\\xc30d04070302438a6933392dfca170d2370131204c67fac5de7010afdb4dd3bfdd3cf5f085630cbbfa8c06e05f0de0c7b189f1cba58d1fc3beb850726b519fa8c3bacadd0f282e0d
2302	3	2025-04-03 18:59:00	t	f	\\xc30d040703028eab772c7b3c1b4572d23601e0cd68bc235edd880793fb3f3637cb31b11d8c9375048e095130cda426d8aef18ad04d7ea69e1f1621dcde9d9bb0c79a1641c05352
2303	4	2025-04-03 18:59:00	t	f	\\xc30d040703028291db408ffb88c57cd2360165f6065ec207fb26322125259afb55e497aa946fec56477bbc8805264ba879f5290b8f3dbbb229f4d235436f954dd2569471110c81
2304	3	2025-04-03 19:00:00	t	f	\\xc30d04070302f63d734c97d488677fd23601cc9f27773711904309913295a0fb735230c88c3cd441ff4fb5c2036c218679261cc388edf84cfaf1cf47db946514fd169bf8339f3b
2305	4	2025-04-03 19:00:00	t	f	\\xc30d040703026595748308ba4e907dd23701662fabb23658a4e0f91b0c213859978d434cab68b89c3e15dfb74fe7d878a414067e4f90826f92cf6ab1cde5d6659a0330adc848f1f5
2306	3	2025-04-03 19:01:00	t	f	\\xc30d0407030277fd496717db7d8575d23601d2ded9a3fa40372921f1f4139f3801a6ee17c172c921d15983e8ad79a8604a6518bd3f2893ad8a49afa151c842be968b977f16f92d
2307	4	2025-04-03 19:01:00	t	f	\\xc30d04070302ce7dfb3f871f187b7fd2360136c3b11db12d21c234e51f6c6562be18ed002d5433c263bc4f094b229ab5298fb7a0663a0fedbc81b33a9115a7f0241fee75d5d683
2308	3	2025-04-03 19:02:00	t	f	\\xc30d04070302dade82b03ca71d4074d236013145eab360ec65c963c99432ccd9983cefa04a67c4849e9840bb307f14c9421f009f24316c86c3ee74890a4c6df6d743cd0d23acf3
2309	4	2025-04-03 19:02:00	t	f	\\xc30d040703028e7507436d2ec1f37ed23701aae22415287e4c830f6faea75a04af3987c873682415b3a9dbe9ddb346adbcee2d9327456042d34202bf65ea5273f26578097b8bfbce
2310	3	2025-04-03 19:03:00	t	f	\\xc30d04070302595ee7bcc7753c0970d2360113261babcc7a6c3485a7efb27b7c87b5030859f56175d9d0d5c8cec5e8fd7753c5636bfc3282e9cd2e5eabd6be9bdce820710300ef
2311	4	2025-04-03 19:03:00	t	f	\\xc30d040703029546c14c6a4876b865d23701fd92ea23874fbc9e7e3cd4559d4e60c00f9dfda3b63ff76689acf688057d914ff26f3b549da4b7339b1728a0870edff23f06c14fa3e4
2312	3	2025-04-03 19:04:00	t	f	\\xc30d04070302ebba0b67702b191c77d2360109da0dac7594240e1199368269663642449696af587fc5bd799923bd3bb39898504f9cbcf927b334be2f795191194cb32b78122cde
2313	4	2025-04-03 19:04:00	t	f	\\xc30d0407030214090e115a2aa34564d237010ffc29891084c7dcab5213990b75cf6d08d490c2a8abd10b5f4bc20b44288effc1aed13f629be12bc84e5142ec51e5397869392b396a
2314	3	2025-04-03 19:05:00	t	f	\\xc30d04070302463223357135ff4273d23601c59d56a7a9c3bc8277096f5bbb81c408ab9d52bc4622bd7a830c4a5b8aeeb6e1fa90528cf6de8c5fa7f9dfbeae94732061e8259f7d
2315	4	2025-04-03 19:05:00	t	f	\\xc30d040703023af270cde3204b4d62d237015eb1d8d03ad06316bf3be33e6b2a7b5765c79a913045deda420c4ef400aed7483bdc2f56b91145bb3735d128dd5eeea99ad040071d44
2316	3	2025-04-03 19:06:00	t	f	\\xc30d040703026e73487d1fe3635074d23601b9ccb8794e13a29b6577a771885d6599672ba777a823e697566e320c8560ad71adc341f2c0f4b6ac78d40167054a1b0acb21d5208a
2317	4	2025-04-03 19:06:00	t	f	\\xc30d0407030296344acc5ae9913271d23601a0488f67082da1a3407ce7fa8190c1ff807a1627ab6c6f1aa8021890343b1d8d1b3dea2f89e8fe510990ec2fb50c8dc4fce0696bdc
2318	3	2025-04-03 19:07:00	t	f	\\xc30d04070302cc7b42cf44992ca46dd23601700899c4cc7bd5a065ab4541d42c73c6eb5725bbb97a248d0fbc94746a748ff5df561addad46aff1fcf96a97c542902cd4e918684a
2319	4	2025-04-03 19:07:00	t	f	\\xc30d04070302a813c790964d59a963d23701b5eb43491370c9e78bb04bf89921c06bc57422fd99d1c8f2e32dc3ae407d2ef53374341d7d58e66387e817c95013cc7122fdf7f9ec0c
2320	3	2025-04-03 19:08:00	t	f	\\xc30d04070302dd40367022eda59a6fd236011f1882a2194beda751bb5f837387a388b915c9a04a09285c237b343b3d7af31ee518c1db19d68ab72690bb2dca8ff713988e144be4
2321	4	2025-04-03 19:08:00	t	f	\\xc30d04070302fb546dbca6060f0f6ed237018f366b29d74ee8371b1709e7276357f5c926279d2dabb3440c95cccc1f767a1d76c90f358d7fe22268f76a321b89ad3dc9cfce36ea93
2322	3	2025-04-03 19:09:00	t	f	\\xc30d040703022d81f421ca91a81f67d236017e757a5cc3552a1b507ea63e432b3e01cfc64bcc8ce9652f951c84a43afa8353f4b5acebdeb33f9ae9cff56ce0dc5e1a7d7260519c
2323	4	2025-04-03 19:09:00	t	f	\\xc30d04070302c71880e27d78746d71d23701242950b0c2d0a265a57bd79900290dd42881f47e9b65dd3687a9e4f348f4fc4ac786c31499eb1ea73ebaf5ef08d78baf201c365732d0
2324	3	2025-04-03 19:10:00	t	f	\\xc30d04070302390b851f67d9ba5775d2350111c270ad9a0cc535618b8e51861ba1b813ec88b6fe00357e6c10372f54108dcb538622c670040dc0c051396c450f9939d7ad188d
2325	4	2025-04-03 19:10:00	t	f	\\xc30d04070302ee270f16daa97b4a6ed23701a3a597500acd7391d917dbc8964efbe910b9d0081653b08458e1f43ac38d93178ce4946e1007317189b2ea6c10e13c268a8388dbdb41
2326	3	2025-04-03 19:11:00	t	f	\\xc30d04070302a029f9fbf947445976d23601547e3a3af737aab423479cedcd02fe1d32ec7eabe312d0dcaa2b7c7620b5a7ede9c31bc5b5fb1723833dba390fd7489f0f480ba301
2327	4	2025-04-03 19:11:00	t	f	\\xc30d040703020871658ca209e9616fd237016a9bd8bbeb788e768f9996d2eed8f1940107362daf8a6b5b7b3713893d9ee6526b8f73a1ab94ebe73022fd3a8e62b5ad6b49f38f2cf6
2328	3	2025-04-03 19:12:00	t	f	\\xc30d0407030277a390cb81cee03f60d235015b1a5cab2fe87fa99bc4e74442eca194fc514118753cfa036c6d1a6d34458378f3da581d2fcee2b963819e6ea4c2e0a607268f9c
2329	4	2025-04-03 19:12:00	t	f	\\xc30d04070302ac125b5a665457636ed2370161bfb0829656285112d64191bb3a263da98a4a59c013b301cfb904a59e758f31f546ce16451f3d7027076e19f719fde3b632a8f4bf8b
2330	3	2025-04-03 19:13:00	t	f	\\xc30d04070302a50235624ae1a7a472d2360131d5d7e961d56f2aeeace6ee0f18e8e7c2ac1b062472b9c40ed9dad0e4baf17de5b9d2fffc6f9465e0235a0c32a0b64aec0bd05d75
2331	4	2025-04-03 19:13:00	t	f	\\xc30d04070302a11cb3eb63bc64e966d23701dd113b1436c97e7647224320523e5f558c4863f5f5a4113abb2ab391d7c734e178621214e2a20c546402f2267a8c3149405cca335478
2332	3	2025-04-03 19:14:00	t	f	\\xc30d04070302eea1f6cd6a5480d271d23601cc10cbaf7850bee5f91fe90bdfa48faff0af96c2c76c23c9716f133484df0557dd3010238c0bf12e48fe71260cbb3f7304a81f28ef
2333	4	2025-04-03 19:14:00	t	f	\\xc30d0407030220ef7d01d85b08e276d237018b4549142802ee77b717fd53e30a4191988c9efa688acda39b8a0807c4c6e2d8fc53404cba3f857a24471955b659325fb5d6238c347f
2334	3	2025-04-03 19:15:00	t	f	\\xc30d040703025bbc9734273fa53a62d236019975f1a04da84d3a71d39c1405378911de34518b06a6e9502f1b1781540d6a794f8302abbd17874f4e034139515738c661abae6ddd
2335	4	2025-04-03 19:15:00	t	f	\\xc30d040703028ea2544ea0f0d5f770d237012d2c6583312becadd3626171aea1ffa7cc79f6aa1b10b59ad9b5be5320e7d9dfdcc192d7ea65cb4684ff66445ca682c47baa2bb2bca7
2336	3	2025-04-03 19:16:00	t	f	\\xc30d04070302ffe7549f8616e2f965d236011be7bf7d20750c1789c685a7f3a51a9f783f16335313552f49f7df3b32b41b8e8e0cf38273f675a10fc85b2262200948811e8c513a
2337	4	2025-04-03 19:16:00	t	f	\\xc30d04070302067099d296f6c0d271d23701988b6389702f63c52c6ea2f355e589e3c8954e66a841ae8d6ecd3762a18d78cba23f8dc83515fd13f839653ba77b00c06ff1f62b25fa
2338	3	2025-04-03 19:17:00	t	f	\\xc30d040703028f33edb6b6a8dc7177d23601783ab034d64d8753e0df1c24244c5ae1f4b53e861fcc6fa67b9c0d522e03510072b63d97b48e99630bd9747d4d33051a64a9958bc2
2339	4	2025-04-03 19:17:00	t	f	\\xc30d040703027422781bba25d6516ed237017caa857e132ed7f9fec1776c5233e2d8e69d93338cca9a9eb2692b69a16fecd8580d7dbce9bf1c82d69bc58b41895b793df498a3fc1a
2340	3	2025-04-03 19:18:00	t	f	\\xc30d04070302a1c6ede9f358995a61d23601360b493a471f4ee635c195b0747eefa94dc5f2afd29455c3d5179e5f2da7bd7aebff899beaa1300e1a98bf947eee4b8af3693b4d53
2341	4	2025-04-03 19:18:00	t	f	\\xc30d0407030238994e91e9f0635f6cd23601bf3a68da25844e6bf563a6563e22e43d6c0e9a58601d95e7b4b7082d5a0433485209fcac1f4d6af0439f531a280816edf6be937132
2342	3	2025-04-03 19:19:00	t	f	\\xc30d040703024e5d6ca215c17a4579d236019f894afed11f32d49d89f3c34aa931d72d0e3c0988b9afc3fe6f99c65c3e6ccb5cfc79397c1199d4c5559ca6a7fa6e243d31f67f0b
2343	4	2025-04-03 19:19:00	t	f	\\xc30d0407030278d9bc996f1f06fe71d23701d82dd0078bb219948c4040a9243b2351fd7effca2e2f7d579a15204ac70710aa02c3e012cdd35e65af008432488ff30e08864b4a5f8a
2344	3	2025-04-03 19:20:00	t	f	\\xc30d040703026dc0e921786df7a764d236014eded3b71f569535d11571e209a7edc48186ac675c423c7c005a4c1a050fa2f048f771865a5a28a394aa58cd2facdae8e5c09de4e4
2345	4	2025-04-03 19:20:00	t	f	\\xc30d04070302554ca91402714f9d6ed23701b6133d135d0798a2adc3fa15199e799a661f0412949610c1a5fd82ac4ad3b995c8c8b85c32e1503db427151b79956d197bbdf3bc992d
2346	3	2025-04-03 19:21:00	t	f	\\xc30d040703024e76fcf00f002ae869d23501ab14d58386f70c3d2234b426b8eea94956c5192d286aa00da730c7ea4d8f8654437ded0a0a7c677df15f88bc3ddb48df7df5c89b
2347	4	2025-04-03 19:21:00	t	f	\\xc30d0407030226e0ad1186a3c4c268d23701e6e3296fa8926055ce818ee92d5700dd090c033477b191bd5d8b08277519500c235db291234bb693dd19de65a95a6cf84b5e4e2df0be
2348	3	2025-04-03 19:22:00	t	f	\\xc30d04070302f9796261ae98b12463d2360179290833fe0c92c2b279c0a1874b95611db2274203e6c3560a06524928604c303a95f8ff14c25964f5990a689dd34d89506d52e53f
2349	4	2025-04-03 19:22:00	t	f	\\xc30d04070302dd8114985e291ed669d2370178a6149b8d2102abc3d4a3ac59668fb78e52c09307ecb13f80eb146f0ec61a0c048dd2ebcbc71ebaa19c62379687c41cb7bd83015c32
2350	3	2025-04-03 19:23:00	t	f	\\xc30d04070302d1389c6b715a7e2373d23601435cf0929fb484e6a5605a3f4f720b7cfd837c006fc798f97a75f6a3f963c5e959386fb22c58a6e6e7f85949def300a83dec6d0304
2351	4	2025-04-03 19:23:00	t	f	\\xc30d04070302518b13a610ee8c4663d23701fabac433596aad9f638ede5b33a12f2aeba5b4245554c58756341804e0d023461947246c5722355cfc5b78dd959cbab0b213e6189534
2352	3	2025-04-03 19:24:00	t	f	\\xc30d04070302d9d4837955202df262d236010130492727447dd2eabcf771e04c9dcda05280052467f83265892b3d72c43085e87511acca7ebe2f6d858796dbdcfaa235d1d4e760
2353	4	2025-04-03 19:24:00	t	f	\\xc30d0407030296429fbd06e6ac4d6fd23701f852ef04818b91cbb4f69f6caede6b4af4d0d4f170ddfe9c6d89c662b20f60e76589872268f4f055fbb079b7ddacbfa4cc7508778a5f
2354	3	2025-04-03 19:25:00	t	f	\\xc30d04070302d40676577f951c3f62d235016bbda536a8025ee23b7b3d17a580225dab18e1fffcb10ca5a94c429d0fad190297cddec46fb81525770dacaa52c1062e098d30b9
2355	4	2025-04-03 19:25:00	t	f	\\xc30d040703027825ed65e9a2407f79d2370100b4ec796d80db69366f722d8b66b262206f67aac4dede3216d411e485c12ee177ef29feb33b9f8006474f254a18ee1ca97181a0fbda
2356	3	2025-04-03 19:26:00	t	f	\\xc30d04070302987ea797b16928c076d2360165e85ff43490b6cd64731cfeb90bfb55a82ee14f21ef83e2db8cfbee35bfc7ee2a2a4b4063e99303a7623d150318e3abbeb5eaf877
2357	4	2025-04-03 19:26:00	t	f	\\xc30d04070302add51eb502ac4f3f7ed23701c6064f695efb3b6bede05a942a3ee14082e026671e3b3986012d66dc0f05f16f5a949262bcf32bb98a8e8c7d8aa9f5f275d21fb9ba1b
2358	3	2025-04-03 19:27:00	t	f	\\xc30d0407030211610c61c5bb436b7bd23601b0109ab8edcfb629e12a81069e90efa8b9335c02136c19ebd936f444300711a247383e29007ab311dc8088267be5310f91ba388b04
2359	4	2025-04-03 19:27:00	t	f	\\xc30d0407030294f25d3c34ae289f7dd23701147233b6eb0812667cbea4b12b87fb14242c74b0bea05bfbfb2aacdf2d9535b4e665e78473c5865b4d51620b85cc925202cef789df08
2360	3	2025-04-03 19:28:00	t	f	\\xc30d0407030250774c9af2b5710663d2360103e2cbdadb14b06110e0c8d3d487db7425fba581a69847ddc82d310688d05e2ec8cd7ce1ed1e9e57c8678a7b95e0d2bca3fe748526
2361	4	2025-04-03 19:28:00	t	f	\\xc30d0407030216328a8bbb8af8e66ed237015eceb3e79ff738b4a3554d9f40bb851766ce9f33395eb1915f1c3dd0a23cc67a3e4d436da2ec5a84a9a20e006717a46cb58440747856
2362	3	2025-04-03 19:29:00	t	f	\\xc30d040703020217c92d273934aa7ad23601dd87ebb07e56358fbea777a2ebd2361c2fb7b08f446e78507ec327710e1290f1700902c3547456ebbe50e62070d8efbdcd5b06587d
2363	4	2025-04-03 19:29:00	t	f	\\xc30d04070302fac11109fc90fe246ad237014c282698913ee0950e2c48959fd1ddd330a69411038d9e1ef35456bc12a47d7c7eaca30c913bdabc0ce97287e8a3a00ad38b12397405
2364	3	2025-04-03 19:30:00	t	f	\\xc30d04070302ca059a0ef1dd6e5d75d23601cee590fa13876cde7635139938449e729c4ed364025ecb1869c0926534e431254306e807e85486a37eddfa081ad107dc155be614b2
2365	4	2025-04-03 19:30:00	t	f	\\xc30d04070302a8f4fe41d389a2ea7ad23501439d135321430f09a6992e30a6ac8ea13b9dc8675a06c6f5e1c9a5ed3027da66cabef9fbae1851e8c41e84e3b9473711dd71359d
2366	3	2025-04-03 19:31:00	t	f	\\xc30d040703028e170c8f954b55dc67d23501aaf13d55fc10efd46430dd31ffdd78c93e6ed466d8c60a620adb7f2fde4a059d52185ef9f98148141356349a3fd566ffc6bc3fe8
2367	4	2025-04-03 19:31:00	t	f	\\xc30d040703028630691cb0eb19436dd2370177f63ef0367c4a8e51412c947c5e073348eda71e34771c14cab22ab878fe041397d3a120732171748a5380da1c7d6dc33384c392e6b5
2368	3	2025-04-03 19:32:00	t	f	\\xc30d040703027c4f392e4296e55473d23601b4e7540629df4efc7763df9675056c2ad8b8d39724761c5943c79dce5f4cd6c8d401d70915f8d1372c7675e442ed8da4562684e60d
2369	4	2025-04-03 19:32:00	t	f	\\xc30d040703020b014c6f4dc370bd72d236015b93c66e4d690fc155cceaa2eb8f22d7d26fe23395698905bb18042b14486943b613e0da61fbe1c9855bf9db44019e7f2659411ef6
2370	3	2025-04-03 19:33:00	t	f	\\xc30d0407030253b4c1faa2205e266dd236015ed7e31761531a3556c2b5cc3114a05329ce093489882784602a3317cfeda8a470c1c8ef11209c5129b235ec418696432cba813e22
2371	4	2025-04-03 19:33:00	t	f	\\xc30d0407030289566d6ebf575d0169d236014a7780a295e24cad7ca0bddd79941e06b1e70f1c51ed81113f6dd9d5787a08dff035b9dce43150206e32195c94f0afe8238547921f
2372	3	2025-04-03 19:34:00	t	f	\\xc30d04070302a7cdcd41e139242b66d235010cf6f1c85176c3f8bfccdbae24d28745e91d365d569c82fc9dbdcdf0a5af0eef0ed7b2a86de800a6d6ea77c28cc6f758d2a65246
2373	4	2025-04-03 19:34:00	t	f	\\xc30d040703023a091ebb8f034afb6ad23701706ae7a68a235d90c87a48a0ce6fdbe2721d95acd46121ad7f13ba4b52cf2983302c916507ba2b96c279c7590808fec73e2dc3a6223c
2374	3	2025-04-03 19:35:00	t	f	\\xc30d040703025d6ac8bfd51546a76dd23501d5f05408911fd8fc74c7c439b49332bb82b35dd044007cc40ccf7c1f4d0bee62b65d5a249e2e2f3d0253ab6fba3e955b93060ad7
2375	4	2025-04-03 19:35:00	t	f	\\xc30d04070302f6f63a616a888df873d23701ca159cad766538403aafd840d5b135e822ef7dceab2bf046b11cb6ade1c9c1185ab258242a9e2802f3431fc9853878ef84abd30e5130
2376	3	2025-04-03 19:36:00	t	f	\\xc30d04070302606d9f15fffca04377d236018fc8c026a805cc89a0d5e5216aea5f238f786bfd9563715b609358966d985026f3fd4a58918009dd32eab0908a3070a7322922d0eb
2377	4	2025-04-03 19:36:00	t	f	\\xc30d04070302d31f261bb75c235e74d23701134c44d8cdfd63273ae7e1b6dd8354407dc163007e59b92d182ce49f6518a9a66d556e2698f2680682910183e2f56465157d1ab4304f
2378	3	2025-04-03 19:37:00	t	f	\\xc30d040703020326abb66c77cc1361d23601ae0c583c237f57d590ba485f29a2fbca569c61764db3c9d09483436ce76b2ea2ae33d241e4b98a72396d64d0f92433ad803ca93a99
2379	4	2025-04-03 19:37:00	t	f	\\xc30d04070302bde881c38f784d4464d2370198054d36f7bff603bba0583ce2e3840d6efb9bde936f0a6b139960f5d96e358921e633db84bc09753ac093c80a224df2266c29285c74
2380	3	2025-04-03 19:38:00	t	f	\\xc30d040703026d57543e3620d26e64d235013c04c1212af2f5997bdb92f57fbf2034792d096575188a09922146ce93432b958f1309b9b99169e3847924419c50573b99d2a412
2381	4	2025-04-03 19:38:00	t	f	\\xc30d040703020adbebc7d33717e97ad2370111b921b621ea6710eb46b683e733ba9387e63993044edb2f45a0f75e390d24dee415365e3dbf2a46db61dc52fd9d62db3c0e11a61053
2382	3	2025-04-03 19:39:00	t	f	\\xc30d04070302e9d53d5b33862e5b69d235015adbef1708be6b941f677a790773fd6ed9ea049a869d393a4b7e9c44dc7716de5b1e22114b632d778344a9132d27a10d029220b3
2383	4	2025-04-03 19:39:00	t	f	\\xc30d04070302fd51c64955b80dbc75d23701fd9315c968d965229c39f4d416d36fe5804320895b8fcbd36325664e366c00c65b2c4bcc011e00b51ff9856608a4b194918948dc08fa
2384	3	2025-04-03 19:40:00	t	f	\\xc30d04070302f5f6136b6a11e43c60d23601900d2831047cba1755ca70d6633d5699018d48ebfc06a569598c7390dcab299e925061c8793ba0ccaf167052ec560628b45154d6a0
2385	4	2025-04-03 19:40:00	t	f	\\xc30d04070302496ebdb85dd084ea7bd23701f15b2c38651d93b02ca75c5f67f6cc50002beb02e3118de6dd6a4cbb30fed0eb6bf4bf527af4cd568fd86341abe1aa0853660834deeb
2386	3	2025-04-03 19:41:00	t	f	\\xc30d04070302a492ec78afc5e1c172d235013e178971461fea07be4bee9f614f3af72dd661b3ca42720521c3e7e6381f2b8053928e9632efcad0f0485b3f6e668e59318d92f1
2387	4	2025-04-03 19:41:00	t	f	\\xc30d0407030231e58217d149ebea6fd23701d3986679d646b8937951105ed1a52da96a3c03307e31c40a876920d19ff06b5052e8db1761e249ec25b4d9c51dc56e3efb7d04da8e6d
2388	3	2025-04-03 19:42:00	t	f	\\xc30d04070302b044d45071f5aa5d79d2350175d04b4312c5829a94c3f97942d81b28c51ce18f69a69b02ebbf7b87bcab016d7d8bcdbd7c5363f5cf6bdd5e5362c7242c6b1c37
2389	4	2025-04-03 19:42:00	t	f	\\xc30d04070302860c14994c0072116fd236019ced3f0059dbb14f3ff24c530236d981a6c97852980f01e6fd2790ec9fde0d8fc518fda10c644954ce86b60a29424861382c7bd823
2390	3	2025-04-03 19:43:00	t	f	\\xc30d040703020d2681aecb55bd4e77d23501afad0789c1cec8108189d9a967278702f03dcdfef04a05cf246715743992e1af8ff9bfb6f3452c8426b0d8521b27b7bb17f1d553
2391	4	2025-04-03 19:43:00	t	f	\\xc30d04070302b9f722bb55b7b7746ad237017e8c0408f5417bbc5805cdf55f8c16950727caa5c5e9b6ef7dec0748457e52ef68f0b23ab1e8efecadae4cdf88d06efbf12bf0ede7d5
2392	3	2025-04-03 19:44:00	t	f	\\xc30d040703021fec892edf564e9578d2360117140067696a90c2a5272b474b15da26020cd2bab8dd5d9b1384e22ac40d45bdaa366ec9422500abc9d09437e721c303446c3d8c1e
2393	4	2025-04-03 19:44:00	t	f	\\xc30d040703026f238d34622125e76ad236015ae6c44b7e831ea2d385d813e76dbc674fda9a10266328ea065275e326a915d7769e87fa19565296d938ff4ec697b4fcbdf0b4428a
2394	3	2025-04-03 19:45:00	t	f	\\xc30d040703021d17e7248193d6dd70d236010b60873829506772c33571947693cea5368e815bf92e793bf97d08b929ecd4a1e1d65ab74d7e4cb720c31921f1a8a45875dac7b38a
2395	4	2025-04-03 19:45:00	t	f	\\xc30d040703021a724430cd9f7e8f74d23601e0bfab9f57f82e4132e5dce25767c30e2131832f37bb8c7faee4b2bd2f0a0742cd4e9c4b800ee70f6fa3986a6c19cb68527ac6cfd0
2396	3	2025-04-03 19:46:00	t	f	\\xc30d04070302d592a6b9684488dc6ed23601e2d1c560534759a1051f1d35ef5e227e86f8778b56df0e1b9b302e2c9cd4759543c6b4d6326a43161c49ebdbb76659835596db3818
2397	4	2025-04-03 19:46:00	t	f	\\xc30d040703020d8120d676f15c2c7dd237010ffdb4a1963eb33b2b7f7e502ca50bfb62ae86c46f0c1426186152c6632fb24df7acacca35ed5b898a50b98692661287355183364b78
2398	3	2025-04-03 19:47:00	t	f	\\xc30d04070302adff7a0bd7a327706ad235012dc06c8dfc7a7df7685d15bd9c83e8915c1f21dfaa0def721ac9b8307a99cfd19214b26ea1ca4918a421d9dcf6d409396be5bff9
2399	4	2025-04-03 19:47:00	t	f	\\xc30d0407030254ed7e3003595b5d67d237010f44ae8d78abe665610a4fdfd3d886a19da5e40765d22884f4c37233f6f37bd2ae77b6a1b78a0a8a29aa91c7482d73e0379c1cf91ab2
2400	3	2025-04-03 19:48:00	t	f	\\xc30d04070302854b4edcccd525bf6bd235016e85b69b7d336df9d5d6b323b8d5860ba12951de9cbeabbf5e40a6b4881c5cdbafcc9480e678a3ea726a20c36d9582a4d89f7ce5
2401	4	2025-04-03 19:48:00	t	f	\\xc30d0407030296a42948a0a4ed986dd23701d87d54999a585aa93d5ec1dd0e744a2a66b837724c0586f999662f027edec0e25e888e6d8800d605301e232217fba33a7c517f5323f1
2402	3	2025-04-03 19:49:00	t	f	\\xc30d0407030283960b2219a1c21269d23601d2a854428beda8d7115c502954f88bfad08806d9876791b60d70c8e0f525dedd6069c4ef7e84ac839e6a37b6f46744151e6cc21d36
2403	4	2025-04-03 19:49:00	t	f	\\xc30d0407030253650219087049fa7ed23701cd3c4e7eebd74d2bc9ffe7b0ccfc334d874d71e9344892571d334a9680992a3dbbbec45828e410004382a94ec963d5ed41438b41c237
2404	3	2025-04-03 19:50:00	t	f	\\xc30d040703024a1e58174914fd2966d23501777b7799eae4dfd8232d1a684f4fbc5db6fcce04b2555b54590dc290b4aeaec18dada3e26da4dc274c95534c005ba18c291bca3b
2405	4	2025-04-03 19:50:00	t	f	\\xc30d04070302f99cac429b21b4df7ed23701303cd63fff06037c9b1a6ad271dcfc322b64c6257522995c67393540fd4b0278c6dbf7cc2e72ff0ada2c08239a3afa80e6801053a698
2406	3	2025-04-03 19:51:00	t	f	\\xc30d04070302b6f7090ca23e9ac67bd236014196c1e5aa65aff0ba98dc8dd94a7327c77925ea852f9f88b8679be1fe7222ec37e6c78e84e3f4cb1acb9fddd8918a31a7c7c8c4ea
2407	4	2025-04-03 19:51:00	t	f	\\xc30d04070302be06c80f4ffbc86e7dd2360119b4e69c0146f17161ffc83c6b304b99eec5d65603affeaccda9aceace0616f7c9803fd10f0780582695d64ca80c9f48957e8afc73
2408	3	2025-04-03 19:52:00	t	f	\\xc30d0407030239585217e3c17e7675d235010319a4f3d5d6eb1784e68aec942ffd11c9f8ce0c9581596ec605a2a9c54253aba4777e112b99cdd883f27cfa26b4b7a6fbd5640e
2409	4	2025-04-03 19:52:00	t	f	\\xc30d0407030292acc222d262014c69d2370127ecabe2b3924a6f642b0a92d0eac3c43632433c9084243e7eeeb9d4057dbdfe920c96f6f8fcec526f35b60bf2c9d17486e553496c5b
2410	3	2025-04-03 19:53:00	t	f	\\xc30d04070302e775eb9429c9813e62d23501b0d3c20a7f8c87efd25ffa10f965268901ee5c5409e2efd39773e8241b7c77e402f46f1cb65651c252342a82becb443d3b3c4b73
2411	4	2025-04-03 19:53:00	t	f	\\xc30d0407030266f72a157784e46170d237011622574a3ee87122ea89bd584c0967c0b9a5de757c0f37ba0ad97dd656147807846b4d01009c0492a1746067873be87e380e78e877de
2412	3	2025-04-03 19:54:00	t	f	\\xc30d04070302e3b05bed2af4565c75d23601f4e295b4c46e1c6328ee8c80f86f47c2dca92d4109125df780d8147a949a122b9eff60ceba248a76302f7afeb06e9910973a43d496
2413	4	2025-04-03 19:54:00	t	f	\\xc30d04070302b1dd3e4a0c44335d65d23601547ee4c3083825b132fdc4a7bba6b3b815dba3aea83dca0846d0c70788cad63ad8f2b8a14ead2f0692772fda954b67d8d79cb9d39c
2414	3	2025-04-03 19:55:00	t	f	\\xc30d040703022463ebbc904b83e46bd23601d1e38dcf449af782c3933b83303e3f95e59a7ee6230694b594124b0d4b0a3fd681330b37997a9fe758b4e349568efc4884b62fcafb
2415	4	2025-04-03 19:55:00	t	f	\\xc30d04070302a686f7d8215fb43d7ed23701937ed19b1a8f79ab269a500d853e93994e72e86ecea520c44e14afffe411b41756abe85c40953b679f084b475cdd5403f875807e3aca
2416	3	2025-04-03 19:56:00	t	f	\\xc30d04070302a77288c513a742d36dd236019e8cab8ffa276e060a56a16b0b68e48c94c3a3c4c4c9d4d025319df22b50d86e8adfc37f90a4707b0339fc7712203a3cee6b1f0459
2417	4	2025-04-03 19:56:00	t	f	\\xc30d040703025e640818594fcbf37fd2370182c0dee3b33d147ffba8263d9f092f6494bf541792caba3ddbbbf878cc8ec9cdbcf6e9fea2ed27ae6845a9325b3e73801760f6365a48
2418	3	2025-04-03 19:57:00	t	f	\\xc30d04070302cfab3095c6293d9f7bd236018ee95413f572bf7c8f298032955e1e9969def4e14602b6051006389db3838544620b4de9f67ba862471a7a18c745f33cd98acd2e9a
2419	4	2025-04-03 19:57:00	t	f	\\xc30d040703024bf5193868e30b1a75d237010fab3172ba000f4b8e8f2c49e9ce7f774f2a99c0dfa9217c723774c4781a23a6f7b35694befdf5fde57ed8af8a5daf66040660c81684
2420	3	2025-04-03 19:58:00	t	f	\\xc30d040703021c00dd68876bfba963d23601580a6daca28bc7fb1332c8f8d0811e1e635d976419f533325a952cb6b1632627ec49bfac169e281bc9f1af88e597a4c3cb7b49dee2
2421	4	2025-04-03 19:58:00	t	f	\\xc30d040703029e0e2d02ed37fcb866d23701637ee838681e10544c55afb7bce37141fd7e73968c6c9c017b22ab673c49d2e7d0d913ba77d01c64b7c05e124f0d896f4a87ab5ad1dc
2422	3	2025-04-03 19:59:00	t	f	\\xc30d040703024172b42abd8b88bf60d236016ba713b56da3255d278517c0fe2665d44ecb5cf40bcbc0d64c035eb27fafd8be9a9ea18186a2daacc99adae020e52755eaa52a2581
2423	4	2025-04-03 19:59:00	t	f	\\xc30d04070302c87d331f89942de577d237013a1f483738088bdfb3c15f93bf6ef713baedd5120fa7f39f08be5cdb2bef35318bbc170251e64115abdf249f10444778b742e27476f6
2424	3	2025-04-03 20:00:00	t	f	\\xc30d040703023c9e081fec764d2576d236010d7b647e72924fd2731e6a9c820f5249965fa696cff0267814abd8286a57f9d16cc8f506c92c82bf67c510019e54910e0f1adcc2a7
2425	4	2025-04-03 20:00:00	t	f	\\xc30d0407030225883524186d957363d23601e30d040c220d40c5e97f58805d64a6abe630d67bb135ef793832eb0c5cceacdd3a471c58d84107a84d8e8a58c1dba841f5c9443262
2426	3	2025-04-03 20:01:00	t	f	\\xc30d040703020e924b81ccf9c32d79d236018a2fec22df5f4d83dc35dbd516771b2582c34ed3708cfc7622a9d1389057c160c44596933a3063631c77dabe02ff6ea756d4f18050
2427	4	2025-04-03 20:01:00	t	f	\\xc30d0407030296d076f0aaa6e01e67d2360181d3cd6ba7535928a4f7613862f2e27d339c87028435c7b12570bd4b7cb0072c9af1ccd8d2bd275a7a1ffbc79d91f04724ba684c33
2428	3	2025-04-03 20:02:00	t	f	\\xc30d0407030218f321972a0232e774d2350107a702fdfdffeab65388e3e78be4954c25fbbbed407c795a9267db0721ed7ef6cf14e74352ed228b3bc7fcb4e2a82bdf7a0d3544
2429	4	2025-04-03 20:02:00	t	f	\\xc30d040703022cb630d86ba8c02277d2360165b14b6f00dd08ed7b62bef662c0e3154f140a18478a6c6184388a659ace31389345417131acdada74be5ff49059fbe438f55960cb
2430	3	2025-04-03 20:03:00	t	f	\\xc30d04070302d997573b80a4240b66d2350156ff1a03b8a29924737a196defd731df53c1c73742e54dfd0d1e1c7e761a0f74c05360a796d8882262f824ac7ca94e78012b42ff
2431	4	2025-04-03 20:03:00	t	f	\\xc30d04070302c4f10bf5c10524e364d23601653ee8402751833e52ab52d76d8e7f1bba0ac5ada8f41ff9f27deb9381bf094b29e274f9413b2be60594036ea355a04380544cbf1c
2432	3	2025-04-03 20:04:00	t	f	\\xc30d04070302032349dc13a2abc27cd2360140b74cd1e327481079228b15d8d802b1bcb33dcbfa35e0a0947782ad29b8b4d205b2bad2e2ea00131a0f4df7550d4d3535609fa5d7
2433	4	2025-04-03 20:04:00	t	f	\\xc30d040703023e10af9f5fb74fdf6ad237014861bb158ed6faab0be6c8ea0582a9379b38cc3a7a85d40422b509772d7cdddbf4abdfadb93f724f8d56309d238ed45a8fee120294c1
2434	3	2025-04-03 20:05:00	t	f	\\xc30d04070302a09d6cbb7e16d4b67ad23601bf6aad539883247e04d0193861e02f59389bd319c997615582cc6354d977ebb57aa5ccb9a0c6829a503d8e3a4ab40d1c3d4e3564fd
2435	4	2025-04-03 20:05:00	t	f	\\xc30d0407030230b902253892d9ba77d23601f4fb6fe7d3dea5d5771f6b1688238edb2de1fa6537b779d13fb816f193265f6fc12f4a62b4cba93a89473e28422c31f8f5d23488e5
2436	3	2025-04-03 20:06:00	t	f	\\xc30d04070302c949da9b38636b0a72d23601fcf2eba013386ad3eec45662e22c83e107ca71421a912671794a87eb9bdb2578828c2b6f00fe85d26e4939b6831b2c89179722e18f
2437	4	2025-04-03 20:06:00	t	f	\\xc30d0407030270dcd75d81ea80477ad23601302fe3dd153ae22a41ccfdd78d0dbe3c90a3b0ed45cedb134d408bcfa580a7d08efa87c5be208a6d7f696ea7a354eecfacd7972603
2438	3	2025-04-03 20:07:00	t	f	\\xc30d04070302bbf89a0af9d2dcaf6bd2360157361dd28ea19fec96eac4ced63af45fa401df1bd33d66770694a59e41caf694661b19c0b23279424af2b065fb900cab3895973f88
2439	4	2025-04-03 20:07:00	t	f	\\xc30d0407030262697405bc8e91b87ed2370149dd92c14daef3a6ca008033c0fdec12703bbd267d076254b7f1acd7f47611ca853ece27eb1f85ec727829c62c90730c1eebf4a2df1a
2440	3	2025-04-03 20:08:00	t	f	\\xc30d0407030254f6a7cae33f8c2966d236011707062b32442bd3a0d4fba78fcfde2ed165bc843e0ee4e60e8a87bfdad6973b9096b25208250f32b19ab59f9a947358457f00c58f
2441	4	2025-04-03 20:08:00	t	f	\\xc30d04070302adbce24d672603b960d237013738099a18eeda429549c84a4002cd4f3f20cd60f59adaca424e69a021bfd80d057b6d19d8523f80f85cc486541ef6b63168ee71b69c
2442	3	2025-04-03 20:09:00	t	f	\\xc30d0407030237696e83ae5f448569d2360110790fa9bcf1aa53bf30a47e49ae5d3f5d4dcae645545b43b91f91d2d8ddaab86caad4dc5cdbc5aed7d0a6243297d7429cce14396d
2443	4	2025-04-03 20:09:00	t	f	\\xc30d040703021677c5aa18b5971578d23701eff0d2183cca251b501f553eee81da7c831135100cf9f0038b013195c792b727f2d923d4e6248e3ab892d8fbe8ccd70cf963d22072e0
2444	3	2025-04-03 20:10:00	t	f	\\xc30d0407030294407f6ad196439261d2350118c0f96c9092f9722226ec5a239ffc5cfcfebfad5dc589e62f4b4fd80c51bcb20eb6fb659308af231bf35db4325a7f1e610cafcb
2445	4	2025-04-03 20:10:00	t	f	\\xc30d04070302c9d937a6b70501fa78d23701ae6112fc7523f502a899a41c1abcba986e52ffe818dc98c4f6e2a7dcb6ab9c88d7945bacf82faa4cb700e5455bdc29fb3e8b445755ae
2446	3	2025-04-03 20:11:00	t	f	\\xc30d040703023c3c73e74917644f7dd236015c9be2aff3b9583af654a5b27cb9c3f7a973a03108550a24c1f09a7806e470cc6da73f5eb5b803fbe1f5ee99c0efa865ab4cfae7a5
2447	4	2025-04-03 20:11:00	t	f	\\xc30d04070302bd49a8d0ec5dc0cb7bd23601b5573a4d453191d436a10030212109d2495ff3eebf3a740a9dbbd1f73d9b8d6be1c9bac1009cc99573007b5e04614091a6999a2766
2448	3	2025-04-03 20:12:00	t	f	\\xc30d040703027db0bfec11bb149578d2360106eb23c0c5038b258aa32d0ca8685a88e3341f2c32d13edb3917898937a3b854a01c2a1e538ca647e807591b2c3c5fb7e21c6109c1
2449	4	2025-04-03 20:12:00	t	f	\\xc30d04070302ef60022a4d78ff5863d23701fc1ed7b8c0dec4f6378483618ca2a26db7e641a900f4828ef8f1d0e6c71fcc2d216e8c324fa74f660bef79337a41947deee1a4b80840
2450	3	2025-04-03 20:13:00	t	f	\\xc30d04070302cb5024ace33d50a064d235017b4d73cb9fb98e357e289ac6a2c9c3be2eca563f68d5067c2b3406bb5114dc1b512fb8c68511baf7083235cf5dace0b779eb9397
2451	4	2025-04-03 20:13:00	t	f	\\xc30d04070302d19c22221ecbbd9c65d237011bdb24f4639c483a004e2ae0b0ee5bf1e55593e10c5a4628cde3a0f3618fa2a1c87c814d84c1058d766d8897183e19932f92909b90f2
2452	3	2025-04-03 20:14:00	t	f	\\xc30d040703023be5f2e8fdfb220572d236011563bfdd7fcf658d75583ff2d78a15c7ee9580ab084bb7f8f218ad7e93e88c5d2f296552b9f8cb10cd68bffb17ef85dc0da7ca05ec
2453	4	2025-04-03 20:14:00	t	f	\\xc30d040703025dee2e6ec9f9dae379d23701fec7f68140930881fc30ceb0b933349b27965aa20294e6cffc4065d642d1c05d237c677efdf8aa68f782d76282ea3da8d15845545a92
2454	3	2025-04-03 20:15:00	t	f	\\xc30d040703028a268894b11c59a373d23601b0f25c32297c598d864e50f077714c0d4dbc493ebeffabe3def28993b455e905c1193e3bf89c16e97a092ab88765dc9924fc4cc796
2455	4	2025-04-03 20:15:00	t	f	\\xc30d04070302d04d77f1b61e5d006dd237018363dabfefc20b903fb7495dc25b5c65843dc290391c05da3413a60d6c01ec6595c7b4fee9628e021368b0664cd4d2bc895214d91e65
2456	3	2025-04-03 20:16:00	t	f	\\xc30d04070302af97e5ad6f11ccae78d23601b5f54faaa5bce820e0b9c2a885f3c1a664a023c4618457e96ef4d16da6c21bf3d38196a3b134c915944b8cdb1ae6560750bc47a5ee
2457	4	2025-04-03 20:16:00	t	f	\\xc30d0407030299ebfa46f00111d47bd23701564c16ffa38b1ad25990ea885e3ae21756ff69e17095d18dbeac83ad91658b5e4c9d22b6c206dc7267e4739c0b70dae530974abce6c3
2458	3	2025-04-03 20:17:00	t	f	\\xc30d04070302e4106d86ce0394586bd236017c8bc8e384a8a9d88f27cf1b43023d35849f9b64e7a40074705c6058bd3a301f8bfeab7f6d01f44de02a743a0245b3ab49a1701afa
2459	4	2025-04-03 20:17:00	t	f	\\xc30d040703021379567103c716da71d236010b3c3621b3492638be4bd70f6b03263cd8ee373206e49e704fce3eee1ecc92ae9df5049a59204ac5675615f5566386bb41bdfb063a
2460	3	2025-04-03 20:18:00	t	f	\\xc30d04070302c33da0c3d308bbc961d23501953a8dde2b0e1d5bc6b4b6a55a8c149f39610c97244e78cb7d843116b6ff4e0d80f5122e54608e061d30e1d8c2407e6947f69731
2461	4	2025-04-03 20:18:00	t	f	\\xc30d04070302f1dfe0663e5df86875d23701af37f16b65a67f3ba4a59e56c04dd0bff52495e39c1f09da1beaaf5f71759aa2aa6fef629e902126e28f4836f3b6c9cc932ec6669109
2462	3	2025-04-03 20:19:00	t	f	\\xc30d04070302b6a00892d4902cc760d23501d4040380bb14545edf78676e48d1bcc333e6f899dd92c7652dea8491fc31b53cbd1fd428832840e8baeb8b9a62adb9ae76a1c4b5
2463	4	2025-04-03 20:19:00	t	f	\\xc30d0407030271598bd8cc21ab336bd2360147bde50b6a180bbcecc42345e290e666b806d7c33438f6f286aff013abdb376f0e742e161ad0e347dbb7781217bc4c9d84086c620b
2464	3	2025-04-03 20:20:00	t	f	\\xc30d0407030273792e5bd6c0dbba74d2360161aba587bb71c9f22a775f9f4a3b72e4848ddc23785455f085024b7f509325b9881582f878004156057e0276dec6ae1752f80f8e3d
2465	4	2025-04-03 20:20:00	t	f	\\xc30d04070302ff6cef6701e7449062d23601afea87a793fc131f0df0fdbfa3ad2fd3297a03ba46a0df59250d2be29c0ef577c16746cb4938c7af3e39e5048171f737b3d0118e85
2466	3	2025-04-03 20:21:00	t	f	\\xc30d04070302034b5047b9881d986fd236019bde2df3f0973b74262f6fa811bb4da792847b052a19dc52219d24b8ba1606f80ebd80dd894fc28db61e1551d592446f722e56410e
2467	4	2025-04-03 20:21:00	t	f	\\xc30d0407030242ccf904e95b7e4474d237010f018809fb6e380c4acaac4c8df45d20462c07de92b1d514f03caab6b4a0a87a73406fd166edc94b80de81352835a448baae77b6cfbe
2468	3	2025-04-03 20:22:00	t	f	\\xc30d04070302fec0fa1709d26a9166d23601b54959213e5a08ca5d203f3598b76cbadde47994dcaa1cd9f523351710ff661b0d0153ca17c1869da0fe12834fab342729467b8665
2469	4	2025-04-03 20:22:00	t	f	\\xc30d04070302cbac13a3c86adb486ad23701be168df0e8f786951c03c7f71f2ad20fd75a9d874755586f80a3730a8e7f90f4e6468db568101b683e14b002e627c2c853864fc80689
2470	3	2025-04-03 20:23:00	t	f	\\xc30d04070302725c42b39888d5396cd235010a8f7780d0a35965548c1cd71ddfae21fc158888da6329164d5efd66c5bcbbf5f1fcbcbaad5216353e905ace2830d08d535e7c6a
2471	4	2025-04-03 20:23:00	t	f	\\xc30d0407030258d8e09f4a859ae27cd2360130269b9464be985bfaebaca9730ea35dd4cbef914af591686d6b748e3ff6a19b4ec0fa7994e9247bd9139217582f4a1bc7b4706d59
2472	3	2025-04-03 20:24:00	t	f	\\xc30d04070302bf0520607d6409df68d23601212df1433da534308786f4761d64f0db0e44d7af39c61d5310a7da5a3a8a34877d97d8d38c676f0b46500a30617ff991093e636f7f
2473	4	2025-04-03 20:24:00	t	f	\\xc30d0407030265359467d5caa13275d237011d826e10be7461ed4e4215fa386cadea7015e9d03a163bffcd7242491417f8bff394935445917045ff8049a015493774d5be3a26df78
2474	3	2025-04-03 20:25:00	t	f	\\xc30d04070302b0dd9232235c961976d23601f25574f1729c2328a20a6b0546f8f8b8be097b9f8f72a97f6d764f108c9e25b6d39ed392ac414d6bc7364a70caa402e962e46afeb0
2475	4	2025-04-03 20:25:00	t	f	\\xc30d040703020447aaf36a23551d64d23701cb66c77fdf5b2b82f32af33306edef37cafd824af0328dcf6db7e26836a540fde1a9332ce08b5e9a4e45c9de5c2de050cb6c0cdc815f
2476	3	2025-04-03 20:26:00	t	f	\\xc30d04070302b74d60fc3aa8bcc86cd235012ae0eb719f476ddb15da949f01f1aa8c47a94bd1c676ebb19f3a67157d7f8e6570b68b6c0e18fd94556dcb113d589104b0b83737
2477	4	2025-04-03 20:26:00	t	f	\\xc30d04070302442b3ee94aa1888d6cd23701d4406306001dc66f99c6ba86a43484c3666be30f6e076d7728ecb1c5228e48e7882e949a3ffb713fb2991d863b5a0ddffe8efb6fa7e2
2478	3	2025-04-03 20:27:00	t	f	\\xc30d040703022664e33a36c74d7a6ad23601283d51b1bd1600efe4269af283d2c7f70b2bd93e4fb85dab6d7f8ff528494ac5ee793369b2efc36c0922b379075af71fb2b095be88
2479	4	2025-04-03 20:27:00	t	f	\\xc30d04070302f51a03a6ea5e95de6ad2370130093a973e4b9d74a2710c9b4343167cb0e161b5091d2a989c479bc39632c1b98ec2edd0540eeca6c074c815dd37d3733dcd314de47e
2480	3	2025-04-03 20:28:00	t	f	\\xc30d0407030285a5ee5eaa03784777d235019a3ff5b83caecfbab35c6d1ff01bfb22797a58edd836fd40b3416efac8b611f8cc69e9ef06bc79d73c53d66225e9a254ef5789b6
2481	4	2025-04-03 20:28:00	t	f	\\xc30d04070302d9340f00f2a6591360d237019a7f0ab0251d66d2b1a149a60e5bd6b404b35ec692d738ab28db2d9533d860273ebd6509d2c600b1a218cb8e82584bad745ae952d90f
2482	3	2025-04-03 20:29:00	t	f	\\xc30d04070302d235f6fc55aab4b674d23601fcf58317c8533cf6f1320151c69063c1f5b57494626b3b599311057991ec2e1a3019e5789ee7c8ebb0007d0bfb9181bc3b01b8aac6
2483	4	2025-04-03 20:29:00	t	f	\\xc30d0407030289d50d43700769277bd23601bb73b7e5891b497625294d96905bf5d8f28e707f77ad15b428f46d9b9c8b880064bd88df391ced76110de578acb324856246f681e9
2484	3	2025-04-03 20:30:00	t	f	\\xc30d04070302cc4fa25f7725eb096ad23601b28973afa038f81cc7177cedacbf575244fb3ba274d86f0de8dd8d6bd23de09bbb4c312be641363fbb323286820f1932f51a038de4
2485	4	2025-04-03 20:30:00	t	f	\\xc30d0407030284b9c36d15180a8a6bd2370189fcb7dd2b9ebbe4540190b64d7679f522e484e14caf409c41f9d7637bdf4fdb147a35e7618730a8cfcd9913fce3fa28605d7fe429fb
2486	3	2025-04-03 20:31:00	t	f	\\xc30d04070302146c5395f991e88c63d23601bfe7de10366d0bc3766dc960873c6c42134cbfacba3e043ce8910360af53d5d3ef144612087a693697d17fa3946d8f17c962cbc072
2487	4	2025-04-03 20:31:00	t	f	\\xc30d04070302fe3f98b512a0762179d237010c70bd76fc9b8481f51d02e10ff1de39fbf8272085207a694faa38992766ddabcd1449a1f42015e280279c2bff80466a28628f803f40
2488	3	2025-04-03 20:32:00	t	f	\\xc30d04070302d62974b3a851fe2c7ad23601c0255576c5338f47f533fb5425b887bccd8f22ecae31863270a72308f15ae4ae50402cb38641dc17288472c98037c0d90c4e582448
2489	4	2025-04-03 20:32:00	t	f	\\xc30d0407030241b76bd079840a116fd23701a82991f115db1d7bddf6b9f311178e4f38643e1a377ab008c70d7de383fc1c4e16be3e66b42a28e90433fb2dcc577d9ceee511b5c4a0
2490	3	2025-04-03 20:33:00	t	f	\\xc30d040703026c1af81888e4c37b62d23601eefbdad5edffc016455e851fb2f564eaf985f180df4ee8481e05605ae209f72bc8a463f5bcaff501ad5f7c4c9e6a6e2a13267eca79
2491	4	2025-04-03 20:33:00	t	f	\\xc30d04070302c88e4e7c4cb4344966d236019734283ea4eb3e5ade4ae6c225a5759350935bd5bd29dc6c333a2c42cab96322039d6b611954ec89b121996c6d4b8ec3c3cedfe454
2492	3	2025-04-03 20:34:00	t	f	\\xc30d040703024eb359260dea9f0079d23601e223cf77ab60383a21eabc8fc9f33326afa22e877500963aeb03027882b4709db3273a96752b802a0a4daa1553ec4cf95b38933f60
2493	4	2025-04-03 20:34:00	t	f	\\xc30d040703025739fe32ba3f300866d2370143362e7dada9587d1ed4cc065ed1065a96923772d1391faabcc20b7d6740f77eb05226255092c1c4082be750fa78fdb930b89b310456
2494	3	2025-04-03 20:35:00	t	f	\\xc30d040703021fdecef287fd6cf676d23601eeb00a5dadf9ebd15ebc64ea04fee9df40bb1f52a2cfc7be4881f55e592fcb58496c38c3c876b9e81d19dee52117086e4d5a16726f
2495	4	2025-04-03 20:35:00	t	f	\\xc30d0407030211a961e4360158c663d23701abd8e0f7bab3180954042af2e39840b18a843106811074e604a9f3dcf716e2ddaf871a8ea8432c10714f298d6e0ef81acecfed61a8cc
2496	3	2025-04-03 20:36:00	t	f	\\xc30d0407030282ed81a0e47ee3ca77d23601a4dcbccceab4f800beb605cfec634850541587e1e924f5643d25a07124cc62dd6633a7278d18485b1f1a77c6abeecf31b7558395a8
2497	4	2025-04-03 20:36:00	t	f	\\xc30d0407030224d53d234eacca7468d23601ae6bd20fcf0d833071ea95f1eacd49d1bdddc4e678f178117abe02a27e6ece9e3d88ffbff1bee507ac75ab996aba7c19871e27eb3b
2498	3	2025-04-03 20:37:00	t	f	\\xc30d04070302ae6cc19ca0c8b12166d23501df42962ff4b3715dad83ceff6035c648b5fd26f8e0693dd5ed3b3ab9881f2f6105f9fa77a446560674728114a83b6ec43a88ed98
2499	4	2025-04-03 20:37:00	t	f	\\xc30d04070302a325840901a0745e65d236011a59db61a5d694a45aa5072a89949cb2bbcd0a794e5bd05f3cbe27940fa926dc5fb61b19877247bfe691712e37a5b3f57db2b1dd9c
2500	3	2025-04-03 20:38:00	t	f	\\xc30d04070302d6b3695d600ccfe36dd235012c6020f7b3562aab0c0b1528febbd949dc518fd1baf09e93e6ee97971e1ef23cc431353f54cf0b76b3ac6862f9a253922eddd8ba
2501	4	2025-04-03 20:38:00	t	f	\\xc30d04070302e78b2b2304199e2c64d236018fdd9adf8e9bc3992343a328081b2892d1e00e4667f9a578aa27054f2ffed1949c1face88fef1a69244bb09068f3ed13766bff18b6
2502	3	2025-04-03 20:39:00	t	f	\\xc30d040703028646acd9b7e2a79362d2360179ccce5af22e7da48e2f6ed44d9d0c3d5e4b3849f1af5b8b76688a15b9b528ad715291133eb7e5466b45245877cf52bb61ab37f638
2503	4	2025-04-03 20:39:00	t	f	\\xc30d040703025849bdff5bf0e0b372d236017b32c78b596d8c008015fa212c39d9085da578aae4b4895097ff78cc51bc65e25d027054490becfcb3647f6ed11bf4545c22940f99
2504	3	2025-04-03 20:40:00	t	f	\\xc30d0407030284fac3ccbbe0be2369d236013149b4ebef8bc7096a50a3baadf97ee9bf2d6968c20e6ba2ac87499655d596f3be8ba1785a285c46d8298fd39b656a1efa308e671f
2505	4	2025-04-03 20:40:00	t	f	\\xc30d040703025fa56700c386f88869d237018d2801d5853e95666784fe893e49687a6ce2337d8333737e22bf796748526a3531c7989c98be6f3bdd4ab5b4819ab4ae2d8261662c43
2506	3	2025-04-03 20:41:00	t	f	\\xc30d0407030260a41d1a115d1aed63d236012db6c94805929a027bf2aa830758f8d030cf4175cc5a75049aae356d39e2d57cbf51a1374fcb246c02d81aeba3b0b8d11ef785e8b5
2507	4	2025-04-03 20:41:00	t	f	\\xc30d04070302d392f100832100c47bd236012d0556353d4d36640a52674b36f6674cbb5e5b7ab2b5c5f4086cae6319d4807b13c6b03d5be3752c6152386e21c546bbdb64e90147
2508	3	2025-04-03 20:42:00	t	f	\\xc30d04070302c23c27a29cf9a5f96dd23501a58a9d4d6bfb8343d8f50e15b9b731b0d0a96dcc2a2f05b0cd7be34b5828b002b55da1e5e3d7676954d747c52292526c7a9c86f6
2509	4	2025-04-03 20:42:00	t	f	\\xc30d040703020bec02106fa0be7b6ed23701f45ed9b17e18fb28dc01613da547bea310df07b866143161aaa426f19945eb4f68321f33e2fe8bd022d288105642187210e7066174b5
2510	3	2025-04-03 20:43:00	t	f	\\xc30d04070302eb261c1bda292d237ed23601169560a78ff04585824d435dcc8d247fafda75bb956a6faf4c577f508a285adfe5513eb62c25459fceb1ce9a973aa57e673b35d7a6
2511	4	2025-04-03 20:43:00	t	f	\\xc30d04070302a3574ea239b94afd60d237011a3c675deb4f3e180253606b364a094295e04661f232a4e036cf9d885b5d177628f14c954fb942482c081ff093fe1c810e30c7d0a3fc
2512	3	2025-04-03 20:44:00	t	f	\\xc30d040703024e0a4cffc1d14ea27ad23501b1ebca517dc0f23949b8e673ef9b841ff6f16554733812d6db0e0f263b2dede312b195180f465d8e2e61f7a55e17e231d2bd0417
2513	4	2025-04-03 20:44:00	t	f	\\xc30d04070302e6a9ca0145bbcbc366d237015e25579a78742edf3299ca83f2a81c36bfc1ae32013abd3b5616ab3396621a13b72cd7869da89a2588d635427303708a18b88e3d82d5
2514	3	2025-04-03 20:45:00	t	f	\\xc30d04070302dcf1cb644fd5f0667fd23601eded03e6bf45364ba7c81dd31e7a05bb71a0d77f8ac2fd779c1858ba858a23cdbc7cac000ea80c41566d99df1919a9f4b21b8b8d1c
2515	4	2025-04-03 20:45:00	t	f	\\xc30d04070302d866134aedc77af07ad23701bcf6df40abe916dfc8b113bbc5cc3ec328bc9a14bc6adbc34069185825a1cf930151d024f9121c41d785985c6cdf73b1fcdf5e1f48f4
2516	3	2025-04-03 20:46:00	t	f	\\xc30d04070302386018c43ed14bce70d23601a775890cfbd1212629af3dac8c0a17f9cf4a28bc96aad0b138fe700c5d9f07ee170e0fe49b7614607f330622a496feacff694e8eaa
2517	4	2025-04-03 20:46:00	t	f	\\xc30d040703023b2111df4786859760d23701dfb741a083c9ea8dd7355753080f858305d26d6f696b80766bd0efb53275c5c4f475e48a2d443b82face7dc71ac0e82d68333a3bcc3e
2518	3	2025-04-03 20:47:00	t	f	\\xc30d040703022b1c9913ac28b6e27dd2350122caa2dff5df10f51920a7eb1fbe82682fc82c6a67a7f777806058981fe67576c9420c160283b9209deed87a5d1e895988c5b51d
2519	4	2025-04-03 20:47:00	t	f	\\xc30d04070302ddb5f6dc4ae914057bd23701cef9af435ada1634d1e96acf248f7f5776c4e1153f291dfd6dddf978bf789e7b1f5aefa64197cefdb9ab9fc7701b0b0008211115e907
2520	3	2025-04-03 20:48:00	t	f	\\xc30d0407030255ed757e5d68e60776d235015c139082f2b8ff7c213bca4aa99a6aca50b99a5e455c722f7e8ca074f473f7b16aaeaf863abc3dac55abf14607f5bed1891a590a
2521	4	2025-04-03 20:48:00	t	f	\\xc30d0407030226394c62b2da4e7d73d23701e95a7be04df0ff75783903d471d18fda155f42aad6c6d5742bfce0f01e0b1fb5ae8aa609237851217fbf6bcd3151d0193cca6b126fd9
2522	3	2025-04-03 20:49:00	t	f	\\xc30d040703020c6c8aa9f2feeeba7bd23601dc971d7bc3a0ded01f38c1a19f12834e6637f477c1a72c91181677fa153e1a1e0cfb91e4537d5d8c4aacdb8af2b99b1cf3f45907ce
2523	4	2025-04-03 20:49:00	t	f	\\xc30d0407030275c23363c81c8a2269d2370185f364c67bce7c19f6a4d2a9a889e974bbc6389dde54a9d1ee6db64c070070f890c47825b2db5273a7a811ec8b346b9889e89e541934
2524	3	2025-04-03 20:50:00	t	f	\\xc30d04070302d6f60730c9b7f28076d23601a451271522d78dc4ce2e2cb8ecc8f4365ecf07352c0b3043fc7efe315df395383bc3502584a7e813968c1c6eefac9aef877bad89b5
2525	4	2025-04-03 20:50:00	t	f	\\xc30d04070302e7c282de0cd9a15376d237019455a8a671eb00724e2c866e4d78d9049419960121498550c50ecd0ce3e4a0a4fd1f9509c920beeeb4eed32f928ab5e2efd1ce20ab77
2526	3	2025-04-03 20:51:00	t	f	\\xc30d04070302b429440875c3bf586dd23601033894471e18d479875a1a370dbbe595d8e16ed385efc354a791dbf14c14fe716f88ad805d018660026605afc278d9579594d27327
2527	4	2025-04-03 20:51:00	t	f	\\xc30d04070302bdadcb6861fcab4b69d236016726a32ade8b68524e1491f2023377b7069d0c19be1c4fc5bf3a1ac6a1077ad33f62f4be5fe9bd7f0cfa99a74cc31151648573cfdd
2528	3	2025-04-03 20:52:00	t	f	\\xc30d040703027c4ef0d2c32a64c775d2360139fa609e83787751a56176cc631753fa9c967d3d9aa9fede895303d8d9ad4960f95254be1f34a324f15fefee5873a6c68e637df70e
2529	4	2025-04-03 20:52:00	t	f	\\xc30d04070302d9d6519205e0f6d57bd23701d1c1492a266eadd16316123faffc823bc6fd58bc63071e9d84237142429ea14f96c9bcdcd2b3fcdc4d4d296106f076f114a861e4c438
2530	3	2025-04-03 20:53:00	t	f	\\xc30d040703022313fba1c96198d86dd23601527136373d42336b2107c26bd8fcf7833ef64b9a6d49f30d4e3b83d838a4a24b5553fc3f616e9957793593cd2267c331c359094480
2531	4	2025-04-03 20:53:00	t	f	\\xc30d04070302fb69e73a27244e3565d2370116ed42be1e0a48a28dd34c7929351fac6a3a0c9c5c2117e3068a6df37fcb5b1939dd3c5cd53f03614652bf31ba93ed11e89e417830f1
2532	3	2025-04-03 20:54:00	t	f	\\xc30d0407030226f39e7de021b4e27dd2350118588c802b564007ccdd75a8af37dde5aced01ab03bf9cf97d995b268f29f952c3b39751932f13e55c9136e696cd6c7e78c4c3f4
2533	4	2025-04-03 20:54:00	t	f	\\xc30d04070302719f08a71250bd026ad23701ad39eb1c1672f75ec207cc14f112dfd04aefc372b8b814dc270e1119d63221ca7d324739d3ab595db3fb19886c1c2f678c0e69e93d38
2534	3	2025-04-03 20:55:00	t	f	\\xc30d04070302f548096f02187aad68d235013746b72620270a3190cd895140a3fab6008ca3b03dc3aad053b7df754f14e97d441d21c804435e986425cf5e10184c6bcb93fcd8
2535	4	2025-04-03 20:55:00	t	f	\\xc30d04070302bc0746c20ff901ec64d23701846c9d4bc75769f86fcbf67dc2ae7b456b97e749d86a0ff1a8c216b838fdaed9da7d30ad1452144deaf6dd9440b296f5757e8c2be561
2536	3	2025-04-03 20:56:00	t	f	\\xc30d04070302d49c7c3f73fb06b070d2360152791eb80c9a4f67936f5837460d1fa4ff804ae9db1a3a728324bfa041620c888dc23abb4bdcf0b6a035999a6f108b6deaae9b05d2
2537	4	2025-04-03 20:56:00	t	f	\\xc30d04070302b8d814587383b65069d23701c5771bbc5f539cc4e44fddb2f2de736b62fbf2f2f912aa2db030a2eb822f308fd797f502fed7c086973f3a6bcf31231279378b538c44
2538	3	2025-04-03 20:57:00	t	f	\\xc30d040703020bc1e5280b9b869c79d236016598e97915532170c45523d094d73bff3d9e23a5326ea7e160ff1755ba32b6d329444f5997fd41cb7607f1e4eeb3904cb6ffc80206
2539	4	2025-04-03 20:57:00	t	f	\\xc30d04070302476f1ea4bc02c31471d23701c38a0d3f2b8c664a068a204a92a38795aa6639c90149b1b0c0b20e4f67dc3fa7fb7c738d616124677a7053e8bfaae84ea72d7cb56744
2540	3	2025-04-03 20:58:00	t	f	\\xc30d04070302d865dad4c4d1540b75d236015b0333af6d02ae9f5e118dc044bab58ebda7aae7904f1bca8e900e265055522ac2995373ad5e6225ff294d7db005a188080d53153a
2541	4	2025-04-03 20:58:00	t	f	\\xc30d04070302a278adb2a14683a06cd23701abbeee15ec73fde6959bdca6a9f3a9a7935bca013704c7d8523131898d66a905ea9911b3d243f439e761644271510475a7c501cabe19
2542	3	2025-04-03 20:59:00	t	f	\\xc30d04070302359080f046a9e1f971d23601277b86d773898dfa70ac2f2d8f4f628dea7e88a29eafad36612a1f28966f7833b7437dd5da6907bfe8b086f3c01a8d5fc5285ad08c
2543	4	2025-04-03 20:59:00	t	f	\\xc30d040703026a301b5671b19ab862d23701c9606bc2a9718e7d5bbf43a9653210af88947350534488d26dfdf393afa8d6ea0edd1c2b0dee6b4f3315c4be48f9fe3abd2e135bd3dd
2544	3	2025-04-03 21:00:00	t	f	\\xc30d04070302d86fb5d5ad770c017dd23601e7e12e0cab8663870f0dccba1313a52eb0eb1e964954690e0910bb95d9902c03bb43f0bcdf19b012e2284e62cb9171b9f2a2903297
2545	4	2025-04-03 21:00:00	t	f	\\xc30d0407030242e8f37ce34902fa61d2370122073f578d9a1152376e8b1f60ef78fb695e0da80ca8b91ad5fc07123e016b250c8d4f49e864b937372e7bfc5c69f04881f078fc8286
2546	3	2025-04-03 21:01:00	t	f	\\xc30d040703027858ec9c72e8b3b861d235017d0ca896bf25fc68f57e57ace73f369e0ca1a78607afb837bdada3f6e030879bdbfb18e70ea00b365549ba0b961b6cce38b2b75b
2547	4	2025-04-03 21:01:00	t	f	\\xc30d0407030269a97b254b355a7f69d23701e774c7628edb1597ba241ca6c33c8f7c2371126baf6a83ab17b2f820aacc41c2cbba3078274ace145a51bbab7952ddaf7e4fbc6ba5b4
2548	3	2025-04-03 21:02:00	t	f	\\xc30d040703026ec705bc1641602c70d2350105e0e9746c453c64ad32f44b6131a97afefbbef25cf4d3de63f15fd1a008d8b62291564f4ea9207f8046bea4ea912bf146bb0881
2549	4	2025-04-03 21:02:00	t	f	\\xc30d04070302e6d633249851ec7c78d23701137e61ae8a2d108fe8ac915502e4de2b8c3e261ed459fd3bf7f368d2eb7c33095c0d0a18ada7b9d00bb8a0e503804919beba309ece44
2550	3	2025-04-03 21:03:00	t	f	\\xc30d04070302d82c9360cdf492e477d235017c68d11cfc98a2d9e967bc693d4b277326d67b957c0cfb18db3d89588b3d13a9e16c8ed7aaa404a599d333e658cfda6384b27eb8
2551	4	2025-04-03 21:03:00	t	f	\\xc30d040703027998d841f3a3e75e71d23601f63ef78fda6df8542bd6ca94f334eb314aac6107f8a1481a4367132ecc6a624122e19a5590228e182467fde98e3e160ef3aebfb730
2552	3	2025-04-03 21:04:00	t	f	\\xc30d0407030287019258f63941277dd236014d66571d24bfd063b04e2aa6b0b9901ba7e2d194e597b9971eb39fc3e2abe579cb6fb81873fdba592a5ff3fa139e2f52ca19264490
2553	4	2025-04-03 21:04:00	t	f	\\xc30d04070302fb78e372ae47b48162d23701e776858ea46ce86d25fd2ae920b3f658058907d9e9034fd084680f4990ba33535622249e36261f6dd0845c9114d58d6c32c25e1be860
2554	3	2025-04-03 21:05:00	t	f	\\xc30d040703026d7361bb1e5e65a661d23601a1c160a401aaa7b48dd99d263c92f46d30b8a2f92914c123482407eec8f33478dbef358fff2d5b6f0fea1c0b14f08c9c841958e70a
2555	4	2025-04-03 21:05:00	t	f	\\xc30d0407030289ad1e42ee7609b368d23701caf05aa3b9da5d0be444035ab787fb5519662496b44ee353c1e113ef4ab67cf7183a22dc4581b14ed1574c3a7643ab3efc4f9265cf23
2556	3	2025-04-03 21:06:00	t	f	\\xc30d040703029e843f69dd4d94f97dd236013af093d6a48e1796b2583fbdfea9e49d022787759a464ab613e813bc33c941ada840f5160cce3822844f375ced575f9322a60a4acd
2557	4	2025-04-03 21:06:00	t	f	\\xc30d04070302cd218e81238580b378d237015a63acf5f6db5adf948caf7173faa0fe48a7e4e0995f5886d25e277650db0f21e4085543cf14212a95b3d84da3cb56bafb8011bd485c
2558	3	2025-04-03 21:07:00	t	f	\\xc30d0407030281f97321b12aac4764d23601418c3838a6840fd6ec1a729ff7e70101f6afb254e6b180ff469530a1f1445d9a99784975b624c905a7eed3cbe3e6165489486f5ef3
2559	4	2025-04-03 21:07:00	t	f	\\xc30d04070302fffa5cb09f5e5daa69d23501112eaf28342c82538db1035adf79164ddba0839145bbf241201df312d92417ab308dd0a8f82b128b2b81ba12e60740ea7fd14b9a
2560	3	2025-04-03 21:08:00	t	f	\\xc30d0407030227813d0396e2541e78d235014e1fde028016efb838867dd9cc7a973744d1a6467713552410c7e389716b18df4109ba318f91333844f1aafa1392d8a026cd68a9
2561	4	2025-04-03 21:08:00	t	f	\\xc30d04070302b1add44adab1437a7fd237016485b39aa35e34ceb014c364cf8c860262488a4e37a37a816aa59ae7fbf2ed4779361c1c4983a401e8d98654e67a49fc309f54763e7f
2562	3	2025-04-03 21:09:00	t	f	\\xc30d04070302c22b11f6e96db43a62d23601bf5a8352e90efa75b54007a5b62fbe4608a2c130f7ba3b7f055c6f7efe7b874ce648beba45d4287ce78d43f5004f5e58e6bff651d0
2563	4	2025-04-03 21:09:00	t	f	\\xc30d040703025dc63299bf8b08d161d2360185620e2e98bd6e0457331533f3fb1633c97c5c11b1d26d743e6e2f9ce1f8a8453912ab5623cd514972cd18ce27f451bb2f29aaeb67
2564	3	2025-04-03 21:10:00	t	f	\\xc30d04070302de4df733a8d9b1c97ed23601d46334a524977f7273e1272f0f1a240118c68e135ad0918cf85b39e4e57a840da037bfaec83fee98ece5535f7eca94851d189b1ab7
2565	4	2025-04-03 21:10:00	t	f	\\xc30d04070302669dae1c2ca9129f68d2370140b1bcd970b7d7dd502e15c671a0b66ffd6e0150f0f75e770257f07290db0f566ac21348e5c07ac374064cac64a2c76100c366c22381
2566	3	2025-04-03 21:11:00	t	f	\\xc30d040703026626973585f59f1067d23501caf062ca6890c2463308247445325a3f802f4703cc12a9e75d88d54b4318ef26df5aa0bc532ba0b99dc339beb8e7b042c3950c47
2567	4	2025-04-03 21:11:00	t	f	\\xc30d040703026a80a6e15fb78b837fd23701759875fcfe26ed7fcc22443a08e773be181b58762ce8aa7587ffa59f024d3dca133e5da71b5f094fafea044f7e74d3910fcb7cd175c7
2568	3	2025-04-03 21:12:00	t	f	\\xc30d04070302bcfb4621acee62ae75d2350184a1d8079d809e028346af234e0106ca10441a2e6363f3fd1c9228271fdcc3d9d88a715da6ce52f5e2095b1f2c3aa2756c8aa442
2569	4	2025-04-03 21:12:00	t	f	\\xc30d0407030286515c57590bcfa369d23701b307ddfc14be0a986a1df6341e438a73401d0af151fbf03775db7a6f13ed01d7012b0e3ef15eadb512d62d84f5753d8570051e2ddc7d
2570	3	2025-04-03 21:13:00	t	f	\\xc30d0407030295df15a529b934ac6ad23501ef52eb0a464611a418945584f491a4e9078d1ebf004238972438534bded663c6879b77617d194faf55d36ae0a2b83e441c4b1a90
2571	4	2025-04-03 21:13:00	t	f	\\xc30d040703024a0955971eef50397ed2370121b7d922ce38b0a806c4d12270d08e1af54fb17693aaae47ffe5f11758ab567b548bfc59f4312aff1a03a7d414e899ed2cd5e1657379
2572	3	2025-04-03 21:14:00	t	f	\\xc30d04070302da2aa3b9cb2fdddc7bd235019c3a4e5823d5c519b58be8da9745633abf8cbb2864e80a231f006559b68d8a3db3f85b2137c9c1742d45fcfdbbbdd71614e356a2
2573	4	2025-04-03 21:14:00	t	f	\\xc30d04070302f8a55200de7dffae79d23701bd88a2e709eb3ed6d4e74e44d6d75ab69970c89448bcf8ec6238dedc892270926fcc2883bc677794c53b4015b6a68fe137397c82f1dc
2574	3	2025-04-03 21:15:00	t	f	\\xc30d040703024c49d406c6693b2b73d23501b7c554a74cbdf5065329e59a28498deb5f2a3d4e29b83b009c6e6b5dbdb4805207c2c107f0785cb7be80ab85c88980904e070792
2575	4	2025-04-03 21:15:00	t	f	\\xc30d040703020a45d7d3e78d38606cd23701a85b5e09134442c14286f5b2fe1275a95364f2a36eefd5ef4b61d3b29426a7e8316e90cdc8696f919e97f3a2624e1e89155c65c3d49d
2576	3	2025-04-03 21:16:00	t	f	\\xc30d04070302d775c9eeb42592e460d235013ec6d04d4e48af54fcf6308bf9d66282f28ad094384dae670ee7e937690b8d680ad3807bb0857f312a602c434a0a9cc74b18eba2
2577	4	2025-04-03 21:16:00	t	f	\\xc30d040703027d6da2e9df1e8b107ad237014ad796882f34e96c0cb30ae700bfc3371062d486c4e7040c2abefbca20b6edf1c697052cd1bdd3be4b25deec914ab00d5745082b9b2c
2578	3	2025-04-03 21:17:00	t	f	\\xc30d04070302e51ac3bc95be740264d23601e0ecff5bc472a29cc34584cfc8aa0ed465b2a73c17a21f55fa030576ea00740b50846891b0d2cb5e5fef4ab6bcdb79eb11a1a6fb7a
2579	4	2025-04-03 21:17:00	t	f	\\xc30d0407030234d5b6bd6bba5d087cd236017dda47f95301641577d02a5b321bacf87bfc6529be3e88519b2fb769a665531b8c5cc1a9b5ee418302170d49cd7c80c390cc8335a5
2580	3	2025-04-03 21:18:00	t	f	\\xc30d04070302915ff61f935091f36cd236010afc27c3dc131b7e971fbdcb594821b883eb35288b9fe3661f284cc88c651847b4a4c7b6d6cffd8172411d7183cf94cabece0bcdce
2581	4	2025-04-03 21:18:00	t	f	\\xc30d04070302550bd5a50661296c7ad23701af3b6a317793ee6aa898d96e4e7b143d79e68088955f13c5f6fbb506b3865beb0da3f54940e4312361fab4847480c729a14ca3af7d1c
2582	3	2025-04-03 21:19:00	t	f	\\xc30d0407030247068d50b03a1c7e7cd23601f3958cbec6fc14fa86d6a97958dca149207411cf3a36ae30b734ba8ac4354d1eed5c366e3f2409c62beb58135f94edef293c96aa0d
2583	4	2025-04-03 21:19:00	t	f	\\xc30d04070302283e77bf739305d67fd2360165e980e13821def01bc97e5f136381bf793fde76ea4b7b4ffa1cf6a726b9928e1d2d1472f1c70e01667f4384ba81d441b1f9bdfc18
2584	3	2025-04-03 21:20:00	t	f	\\xc30d040703024667f8016cc019be60d23601c903fa5e8c2b2b04581d41a37f99e1c66911980a375597704417bac4ac42f976ac00b5873c40a07e90a6a10c4c56e248be3f62c4d8
2585	4	2025-04-03 21:20:00	t	f	\\xc30d04070302078d8ad0896db82160d23701e72f702c4e665b912cb6868eccdbfff09b47739a60766100b2260c824f129a6b1b884f88282cc7f2535967ec0e5f1fe82047e57ff281
2586	3	2025-04-03 21:21:00	t	f	\\xc30d0407030244f262928d2b6f1267d23501cc0c206f9c5ea6f70ba522d6a51019f183ea10eaae2b24ca24f368e8f361d062892b3f2505ff69bfa3e49248b85db20c291d242b
2587	4	2025-04-03 21:21:00	t	f	\\xc30d0407030263fdd328ee32875965d2370179d12aad829efa10eb61a94bd35efd98b6552075012cb5cfb94c03a001cf9036000bd8907336ce88811e9bb8bd9358987d00c130dc09
2588	3	2025-04-03 21:22:00	t	f	\\xc30d04070302444d110b64d9e5477bd23501a83479972226b48fd1d1420450cb5d8987886f94106ea7202fdb697eb5e5c1badd978a8bbfe938b86f096e9acd5379904fb0c0b3
2589	4	2025-04-03 21:22:00	t	f	\\xc30d040703028b55bdcbff62f6b479d236019fd9515bd0bf0679a70326e3518d2a886207fcb5ae9268a029cee818949d23cadc3bb2e3aabacd795d7803b5648c1733d5dfdb51a1
2590	3	2025-04-03 21:23:00	t	f	\\xc30d04070302a034696a7c6472b26fd23601ff520158ffb2e6b0449af24bca402a3ee28afad3918424921c4892ae8b4b233c72038bbf4f6d0993f58e77ebbebc21379f6f6c7882
2591	4	2025-04-03 21:23:00	t	f	\\xc30d04070302fa4fd5d412a7619c6dd23701d59912bc82572116e636ea719939dc21af3c5b42f1004abdafd9a708fda04d9a68e4f1de144a21fa3b2d9836674633185abf967a84d5
2592	3	2025-04-03 21:24:00	t	f	\\xc30d0407030229c378930d42b12d61d2360103383baf2138c7680b71e81d0806d20fd433b515061bfc71de30b090a893e2210e91e6a3e57209ff2506f82828a60ed9d86698dc86
2593	4	2025-04-03 21:24:00	t	f	\\xc30d040703029ae7c2b6adbe47047bd23701e84d28858a2564b4718d7b7f409a9b4359c4ec0540a93657b5797bac3a391252dbcf894902c33f1f252b04bc8fe9617a6dff47890091
2594	3	2025-04-03 21:25:00	t	f	\\xc30d040703023137fa37d2a1b9216fd23601c66c6bcf4be04a6fbbb92d4a388e3d957762dc5dad582beed38b289d551686be7ee34525c3b5b81bcacce6867f2bca8c8fafca7edb
2595	4	2025-04-03 21:25:00	t	f	\\xc30d040703025bbf33bf00ad6a607bd23701f523a64b4ce2c8cab190cb0e85604a13b88a73e530b6f03cb0bec1d70639cd35361856c4d6ac7cb2362c96bc15f36cc90816bf779e81
2596	3	2025-04-03 21:26:00	t	f	\\xc30d0407030269519ac57734b87c75d2350128c4516b6e916e9a046b61c56c37af4a0e64957067c151871409cce796fd834a0920fd506dca05485f48ee8cc05e320103e1e86f
2597	4	2025-04-03 21:26:00	t	f	\\xc30d040703023b20e0946c56bef360d236016a9a11ad630cc8f4fae6890df375639954424c95ae3bb173c5bdbe414d10cd502046910cc0f59e42f99200cc8ad3b4b722b80c93b4
2598	3	2025-04-03 21:27:00	t	f	\\xc30d0407030284147802b0530a987ed23601d22a66448a45d1c298191874dcd46f9c47a23e15fcd0d4775852ea3ac4ca7129678ffe4aea9e219ff12097f28bafb4cd5541cd4341
2599	4	2025-04-03 21:27:00	t	f	\\xc30d04070302f74aa39613fb13db6bd23701aa203c8c362a6b8816be7904d13279f564ba10f01933284af115f3d8bf72feb81e599255a4bd8aa891180ad0257d2a3bed3535bc7994
2600	3	2025-04-03 21:28:00	t	f	\\xc30d04070302c111885d71eaf7ae76d235014aab52762f18a0eaf82dc4116abe8e23aef158cf63ac1c017e3873166f55501b0341c9a6ef26c97b090e98b93288b27a0c48f121
2601	4	2025-04-03 21:28:00	t	f	\\xc30d04070302a4c2572be1de03a869d23701ae5770e3dbb05a8ac90dcfd7470b29ccd70c5f53d68667257769f88ba37e7984db5a1ca8e8f13a7385e413efe4e2658a30904d02b068
2602	3	2025-04-03 21:29:00	t	f	\\xc30d0407030271c10cdd9473df727ad236019c0aec9fca6a916904fd38c07614561905bffff63ba45ff30403b9256efe704feeee90dac4805b4acc8a8c3a84002a399891894c8e
2603	4	2025-04-03 21:29:00	t	f	\\xc30d04070302894b97d352f414fa7cd2360112f8b9089580dffb4ef0ef50491f28b67e90359f363b20a41bbc974bb2f042e1f7ac0ef815ea9f4994e8e06193f5f01afacc8529a5
2604	3	2025-04-03 21:30:00	t	f	\\xc30d040703027ac35beb1ab47c3e7ed236015dba04037d4f2f404e80dd105fbadc6bd767b16ee604d01971e0c61c4325d1e6279e11004b9549d8ca4f63d0f2bcc3b96a4b652fa5
2605	4	2025-04-03 21:30:00	t	f	\\xc30d04070302a1837ff08d2ec74961d237019e527f646aa0f863ff851ac3fa707d62e7bba7a038d235bac49a3f4120e6fbe233a74744ca2da00d35ee04f23757d4bab45c51090269
2606	3	2025-04-03 21:31:00	t	f	\\xc30d0407030276a5d3a7957e35b66cd23501571736a5e004451bdfffc45b9278593749e05f0bfa8012248f1e1c73023934bf71e63c725bef7dac1d9ffadb7d6de07d0ed6d05d
2607	4	2025-04-03 21:31:00	t	f	\\xc30d04070302f2823528a629aef47fd237010dbcade613a29eeadb829349b7ca0d5f06c743c4c8e663965602eaef818e18365372f84cdbd54aa891ef16d98a735413b05188f66dc1
2608	3	2025-04-03 21:32:00	t	f	\\xc30d040703027f0959e5878d253d70d235018f684a7c4624359bebd22dcbe2c286e72b6a020fdf9dcf933685accd9725f08a386f01cfc74d0fb6b8f16c62f04d2dc770dd5fb0
2609	4	2025-04-03 21:32:00	t	f	\\xc30d04070302af9f9a75d0f4f39165d23701353abcc2faac1e4d3a272d87d5e65c931571f79d88e09a4d8f2295ac976c6b163c84a1c6e597fb3ecd9002c19220eb0e9f55cadeb500
2610	3	2025-04-03 21:33:00	t	f	\\xc30d040703028c99915010c92b1370d23501cd5d02dbba0e3d7029b8744a72d7c6cecaae87566dc61adb8fbc01bdd7067f992651516d51c83a67e918290d6206e365230b98ba
2611	4	2025-04-03 21:33:00	t	f	\\xc30d04070302bc2619d4d04b303260d2370183f6a06703d3b0172723c516ac037eb612231002905f41f94e1edf7366ca6f5dca2e885c6e8ecf6911cc0eb00ac9f9da148823b04831
2612	3	2025-04-03 21:34:00	t	f	\\xc30d0407030220da2a24eb24bb2763d23601dd9e6e53c02bf578ff19329750c27195aa20b50d9343a1699bc853f5f1a819662beacb3445776d65920d99d4842344157def040cf3
2613	4	2025-04-03 21:34:00	t	f	\\xc30d0407030242a0462175d0e81f62d237018678d6d369a0d4b86432b7a1519355bd2d1acdff0c2b31c4622c8b9579abeea33eac02f96a5fac9450cb0ff3816249feddbed114bc29
2614	3	2025-04-03 21:35:00	t	f	\\xc30d04070302f075d1499bcfa66777d236013f72b9f3b98956cb5c7b3986e86745127948014e609e20b7a15b86c17079fc287b0aef662c9bf8cb02c326a556e942f73b19e5b59b
2615	4	2025-04-03 21:35:00	t	f	\\xc30d040703022584222abd8c1a2a7dd236016785f641a8e9fdc2fe8af13b30d67425f6a974151b2c939e6cb66dacf4acd68af1df65d5bef76d0b9af2b2b8e6d8cc7ce4801d8d9e
2616	3	2025-04-03 21:36:00	t	f	\\xc30d040703025be7dd7476940dbe66d236013fc2c359f7d6762b3945cb3fd1c08579d83e21040a5ad36ba9185c8ffe163339086ce174bcd7e8130442f63f36495a2d9f8cd25e5d
2617	4	2025-04-03 21:36:00	t	f	\\xc30d0407030278ae5860912a2ca77bd237013c0ea4071d6ec6dc5dd607a291aece45ee56fdc28556cdc0338b25b6cf2cc6ab81c88a3f633f139cea63aae9c9341017b06bba3f6029
2618	3	2025-04-03 21:37:00	t	f	\\xc30d0407030229fab503952e8b4778d236011a9037285510eddf1c45c0199e4d0339a71a7cf9b9a027fb2fb565e2a54847b1ae341b967698c6aca1613a94029e3eabe80461e310
2619	4	2025-04-03 21:37:00	t	f	\\xc30d04070302215a9750af35fc056ed236013b5d4a0e83f5b549d280c9a09e1f1d2414e35f7a565dee78527b6a33101bf985fd78bf10c48b415b392ac9f223974e7a29449ab24c
2620	3	2025-04-03 21:38:00	t	f	\\xc30d0407030262507db4f6f43ef16fd23501dc3cbbc0064df41a981ffa039dea7a0b54ba7f000497ebccae7da5d6c8ad103cee07d6d8c13c7ac3fea5278063df51395bec4306
2621	4	2025-04-03 21:38:00	t	f	\\xc30d04070302bcd86b1537cc1a0e79d23701e0ae75e17949bc03becd1892a8a507c28c5e9e222b6fd51834783daa02d7bad7c7db2797225700951e9bf8827a73320427e11a482895
2622	3	2025-04-03 21:39:00	t	f	\\xc30d04070302e0b861645c8bc69877d23601a041eb0ef8d0a1971ea908d51623663df695034015c437507d0bca5a68be89c5a496d94f2924775da07d0c1a5acd4f59ac0e34b0ab
2623	4	2025-04-03 21:39:00	t	f	\\xc30d04070302956b17ee9d3cf7177ed2370197856281692006548c9a6c536da779cf355ac24b1be7621ac333baaf01be124c20799a3dfec6558de660d20f34e9e086376b76e21545
2624	3	2025-04-03 21:40:00	t	f	\\xc30d0407030265075c15e42cc93278d23601547c8b328a4c21477bad9ac6a3c32b33e3f4729b7067a156f542fefbba242049b0dfa767d3f346888bfbec2a2834bfc7fddac27ea7
2625	4	2025-04-03 21:40:00	t	f	\\xc30d04070302ec6a4ad7e98a0d9261d2370117a10553306c1d1818bb08b09db76003eeb459d826fdb4fa73b331626785234c398d4c3a9470110e08e6383e6430f6d8c64c155e024d
2626	3	2025-04-03 21:41:00	t	f	\\xc30d04070302d4e4cce73df9f8cf74d235011f570d880b21d46eb418247efa0f9ebcd2128cf93696a1df7f575b351b5966c7cba1691bd81b445e52202c0392ff6617ff5d74b0
2627	4	2025-04-03 21:41:00	t	f	\\xc30d04070302e1ccfe9c5026e95374d2360168828c1f9c3f3e420194a0dafd54e48329980361fedfb1077ed1087e703b5864770ce6976f20b130fee5d27d580425c3f08a814513
2628	3	2025-04-03 21:42:00	t	f	\\xc30d040703027c68ddf5b26c1c9374d235013df0d83c9b80d6eea8235d6cd11b6a55e3765bc1f93dd4c8afd81cb093d7a18a81bdca9de5e5a882b8ac478ceca0acda38908025
2629	4	2025-04-03 21:42:00	t	f	\\xc30d04070302e12c478b37270a6f7bd23701dbab4ca911c5f82bb2240ed5b58e47d47f842c91db55fecbfaedaffbf9c4711ea3591dd256ecec103427a6aa6991f49e72b316307ed8
2630	3	2025-04-03 21:43:00	t	f	\\xc30d0407030253074d98886949627ed23601e6e170177cd3fc157913a9d148e71025452960aa201a98c26eefe4ea49126d1faf01329c65f1e921c47ea995ba625b8af32073ec16
2631	4	2025-04-03 21:43:00	t	f	\\xc30d04070302b7a241b1da2e89cb75d2370161b1cd596cbd0c0d17f048ddc93c176aded9d7393606e8b9b079a70489f0a9d2a3d82c7cf6e2c427711995088580ed63405a926fc595
2632	3	2025-04-03 21:44:00	t	f	\\xc30d04070302938965f6d6468cb961d23601a53006f2e6c5a083de5c35b69268c5f3fbd78ae72c40a3feab30f60ca968f056011bcce02a6c4ff53134a2733cb163d00a5456ac9a
2633	4	2025-04-03 21:44:00	t	f	\\xc30d040703025dae79392f6ec2ab62d2370159851ca3e1b7d2bbaff25ea46f8ec5fff0ec2d32a459d60ad68890e170a56d17b7651f716514f691a982f15ecc2b01d213164d5338e1
2634	3	2025-04-03 21:45:00	t	f	\\xc30d04070302839f4effc9f4dba073d23601c8773f5720ed89e7789e3f29f4088591a20f8b5c4d5be83055ca816594e31dab83ed48c88c18cb475d828d74988bbc4d17a7e53525
2635	4	2025-04-03 21:45:00	t	f	\\xc30d0407030213e2c8c1c5f5e12a7bd237019a013a8c6748bdb797c67d17df81f6d2f8e9d597bc4b46dfdcedcd5b93cfff7f5e4ee470decc2293e63f8b5c43125a21e89a0543f629
2636	3	2025-04-03 21:46:00	t	f	\\xc30d04070302ca18b267bbed1d2175d235017fbfbae0501e9865a5713b0f363cbf5ca460e88f318b115240887b004cb523dcaf060de16240f85f6031fb59feaa23c2c2ef4b1c
2637	4	2025-04-03 21:46:00	t	f	\\xc30d040703025e5ba3c1e3bd20da7ed237010bf721e4d5ec7836a7108dc76ea93a12ec8e01f771302f6b5f4943d0f3e7883289ab39abd244e9e42e492e58ebf4de3867b33b672151
2638	3	2025-04-03 21:47:00	t	f	\\xc30d0407030268ccaab0993472b772d23601d6f1a3df20480e46d56c02ed080d3d03bb6b101d995d2807db4951eafeebbb9db514c06e6c9f38e090a26d7adc42be7d1b869eb917
2639	4	2025-04-03 21:47:00	t	f	\\xc30d040703025158bcf101a483906ad23701a658b1a17f79ccc52de68ec6c542d92c6bdb638e9b04c1d45ba0b4aaafb84bcd0fe4429da5389bc47dad87d3f6ebfe90528552bfc504
2640	3	2025-04-03 21:48:00	t	f	\\xc30d0407030271d28b2660c9e95565d2350109bca92728afb854231dd9cab1911e6c6a26a07986466a5129d165dcfdc0ce1ffe0e9f0c7361d3eec2deeafe8ef8bf98586908ac
2641	4	2025-04-03 21:48:00	t	f	\\xc30d040703025507b5fa1546fef472d23601e39c39882a77f102b444eb04f71fb5709c90a5fb1f7ebc5ce0da1f7777292523a637b65d7151b4e6734a74226fe46dd3694380da19
2642	3	2025-04-03 21:49:00	t	f	\\xc30d04070302504716bc61ec671b6ad23601f9233039cbc66d4b5ce1da56c0ecb54e2eb965fac6b95d9256a78d5276c6b66978f69eb83e29b133c9b6be78fd1693f71591991b26
2643	4	2025-04-03 21:49:00	t	f	\\xc30d04070302e72cd19b8b491a9d71d237011af5cba5c2d147dfb835a0ba0e8173816db3f14acff065b659a028a3c4c5a842bd29491c3e0d2ec867c5eb234f1c6619a518d4c910c1
2644	3	2025-04-03 21:50:00	t	f	\\xc30d0407030255b9c4a494f7008869d23601261d40980b49ffe9ae6eb7f5b969f7628e8cf0c089922c4309bec157450710597aea56a56de8186492d52e9f06ee583442a37b7bb9
2645	4	2025-04-03 21:50:00	t	f	\\xc30d04070302e93a22e96bd8163379d23601cd8b967aefd50381e4d057a74bbf29674805ba46efd72176cd70c0675fda718ff693613381630ee30126b40e9bd4c9572690930adc
2646	3	2025-04-03 21:51:00	t	f	\\xc30d040703026c80da9d44ce416c7dd236012e8e4aa008e5516ac924df14846eda9d40f8b8014ee9b65f33e135d9f7a2fc10f225e5bafa89c18137ed5da326b6a832d70189d7ab
2647	4	2025-04-03 21:51:00	t	f	\\xc30d040703029ef180e48baa97ad6dd237015fda62ce2a47e1852e4d9827bd1426ec1b0463079c9c165adbb83828fca529987d3fa6f0829954ad03f211f350ac1d6342c8771b5f8d
2648	3	2025-04-03 21:52:00	t	f	\\xc30d04070302674e4302ec24e7f77fd2360186c20936db98087a0ad5fd4b2eca3d8a034f3f300ffde46afc8e2d21e88f0a723b389b6974ca21fa1cf4207ce64299b15db23a6f29
2649	4	2025-04-03 21:52:00	t	f	\\xc30d04070302d4d713caa2941fef76d23701026f9697e7b0cffe728b979d8fe3fb0dc5bbc2efde473211382d6277914a955e0c3e633f4d445ba7f76dbb23221217f979ce8a4010ec
2650	3	2025-04-03 21:53:00	t	f	\\xc30d04070302ee330000fc6264336ed23601afc7051a8e34778b409f486b7ad45d9ffa8b05244fe4503a5669a583be4ceece781393329e295503d8ff0c6e53722d0957bd89440d
2651	4	2025-04-03 21:53:00	t	f	\\xc30d0407030293e90d89467147c574d23701284289384a86d40ea8ab4ff9f86a0e3dbd7a66a13a29406170297e4f7241af019857c48ed510319767f824ccb67c00ce13892406605e
2652	3	2025-04-03 21:54:00	t	f	\\xc30d0407030263649c7dbf2f12017cd23501cf89a737b899b87e4b5c802fb4634b709038ec4b22e695a20851266501ead49d25d42d71345e556e903054dc750dc12b9b2d0d95
2653	4	2025-04-03 21:54:00	t	f	\\xc30d04070302f02ecd2ac7e1586e77d23701bdded26dcfb3f5001985709fa1c0a6408083a0b3250278ff196d369abc8b46a350c70f52805700d0cd2619835a951d0920fb324f854f
2654	3	2025-04-03 21:55:00	t	f	\\xc30d040703026c686354cf8fd4be61d236015db635fb03ae6b6797e88594dac4b1608f993e580768aa8c070461f202991263eed175a244cf9a92de0a9075d61955f7e769671772
2655	4	2025-04-03 21:55:00	t	f	\\xc30d040703021252468145827dd57cd23701474d9a80d526b8e1c8e53e7bfb419f1617fb4eecb2d87e998a403aac68744bd2bde4853e39aec3463de941c6017021b0f5a65675a853
2656	3	2025-04-03 21:56:00	t	f	\\xc30d0407030292d761e7a5fcac8c7cd23601800df8fde187599bf13bfcb4217e2d3e2ad3e6740a14dabddf3f0b3b57714d5201e1764ffa88400d5847eb4f9a222f83648b730e2a
2657	4	2025-04-03 21:56:00	t	f	\\xc30d0407030238417496e2985d2c68d237010af8fd430bd6871dfaa7bdc64ac016a9d7704b09e81944a683115c81326c91dfbc6df6e6e1a0693d1db3a790fa924e24540b71af460c
2658	3	2025-04-03 21:57:00	t	f	\\xc30d040703026416c4cd3f79cb2771d236019390ed8f465bba60337da99ca5acebf7a020b1e58397dad34de93803968a3e08b867b033508ee154952537a5c3f8e6ab824200f4f3
2659	4	2025-04-03 21:57:00	t	f	\\xc30d040703028eda6e960143d73c7dd23701e753f2bb40e48a1181a858b9a2cd8e675202bada3b840cb78e46f9d91ca28d154dabb2ba6fdaf1ffa59ef4763ef45444cf9625c8d3f0
2660	3	2025-04-03 21:58:00	t	f	\\xc30d0407030273d68f8304d673107bd23501dff4b8b671160db2788b157c66225a6094874e01a9686c60504f9e09fd53cad75f604b93269bfe4187494e84b334de33861bb82a
2661	4	2025-04-03 21:58:00	t	f	\\xc30d04070302803154f33d76f7da6ad23601b5680fe74f8d347c9870ea5441c7ff181f67b55e10d5335f66335f098ba8b09afe6aeee29283e37960ca03c5a65d2db98e7b51b3a3
2662	3	2025-04-03 21:59:00	t	f	\\xc30d04070302862691889d8bc5c46ed2350104aabe08bf6e6032d50351ad38f3ec2938f29779c1a5ca74a856cf7b4ae410d425c1741bcc1e70c1c39b21049c8bbe2967042110
2663	4	2025-04-03 21:59:00	t	f	\\xc30d04070302018ffb4c7563d96266d2350122b9431d703e38bc70204208faa0461bc7bdbfb1f3a37e47499e3476cc61618b025f7586bddde287ffa4fc517ea07936a746639f
2664	3	2025-04-03 22:00:00	t	f	\\xc30d040703028e6b2d44d189071b77d235017eb60a06b398c36435d1d32d02e37eede8a42b17f70beeb862209b85836de2cccf4b5585b6cf4b57764e1abfab3d9e900c2d3a20
2665	4	2025-04-03 22:00:00	t	f	\\xc30d04070302ae66e348202fb7c46ad23701366d622ad660ec28abdb75216fa6bfb6f6b89821665ed98f50cd1b1ad5fa1d7f4327212036ceab29b7d09626994065ad53aeba8f58d0
2666	3	2025-04-03 22:01:00	t	f	\\xc30d0407030290643c1e73af885870d23601addbacfcee28037410515feb20b5c686f64699198b684e334b1c6b564c45300b0d2286d21e24fc66cc737519907fd02edd1cbec0dc
2667	4	2025-04-03 22:01:00	t	f	\\xc30d040703025278802f404ae53368d23701dd1176486cc4888538405837b6d90be5f9093b2c0b08ac62ca5fbe238d77153652c6f8b92f5111e1948ab6e671026a238a2dc9512749
2668	3	2025-04-03 22:02:00	t	f	\\xc30d040703023d96e643289e81826dd23601efb24543e6c36758229a8f035264a176a84e60e0606240c684a0305e33a73c20dd6d2dae29c645babf192acb0ede97c79522b31e4a
2669	4	2025-04-03 22:02:00	t	f	\\xc30d04070302ffc2c2673035d18f76d2370191ae7fd1f9ab1e4b7bd4c911bdada64fbb6af3bdcd5db0b90966dd5a144459daa2e663d12375f6dca60d521bc667d9de04231ff915c9
2670	3	2025-04-03 22:03:00	t	f	\\xc30d04070302651abb7a1873a7d067d23601e0bf37e2b876bdf98f326459a733f1df90497b5d5c2e0238e017ce8970d6157c3e5b9daa3368ea13e732f1da8c58ad96fba6c2e92d
2671	4	2025-04-03 22:03:00	t	f	\\xc30d04070302aca2a55890c7976f67d23601c7d6ba8eefd3840a2941d4b09adfb28bf7e93eab420b7f1ed235f182359213fc7b28fdb4197fb86e2c59ddc5171a74686703f24e1d
2672	3	2025-04-03 22:04:00	t	f	\\xc30d0407030252f3f88d745b7c5667d23601486361d9f88cab816e08b3cf64312c705b8aa5332150828ab024d6fee25ad6c3e2d8db2ae530094c48dc2f0a80075f380a54937280
2673	4	2025-04-03 22:04:00	t	f	\\xc30d04070302c28e91b1c9a9582f68d2370198b665e16aa5748e256276a5852048bbcc2dd2f6b4fed86a0f48cc78886ff6358c88e159a95810203a7f2ae32b54c390480df71d8b2a
2674	3	2025-04-03 22:05:00	t	f	\\xc30d040703029009f240b78d0dcd62d23501cfcc8f320c2983e4dfde2a04b200c9baf0b69a915bb39c46cac68424188f8a071114242cad8db86b78dbdd54c80bda92cfd1bc38
2675	4	2025-04-03 22:05:00	t	f	\\xc30d04070302df070491d05934636ed2370128f23f77e39af4d9ef4775b0a0bb870ac27b1b5ab6952a0bcfb841cfa2a7338ee2836eb9831623945de31670531610ae5fc4506e15dd
2676	3	2025-04-03 22:06:00	t	f	\\xc30d04070302ec81b569c37500e870d236019f0f16ac1f73c7fab6c8db283ca8c85d741c3820aaca83939eff91db47da3451433905a112b32758cb92567200818ed7a71ad6381c
2677	4	2025-04-03 22:06:00	t	f	\\xc30d04070302d117d58ad2a8cb976bd236011ef23a2b3132053ad29074c84353a41da560e8568af34f88864786291b5eac01be47c8eb9a80c4c759dccaa0d0f2bf907cb364f923
2678	3	2025-04-03 22:07:00	t	f	\\xc30d04070302285c259df70b4d177fd236018ac8abd2146f7feb36912a9d0f219e26703f1291338fe4ece2306301b4f586fda65f559c692ba53f55fbab91adf0194082beba0335
2679	4	2025-04-03 22:07:00	t	f	\\xc30d040703027502254a8fd034a375d2370114102ba3e53c00b8fe63e38b28493aa60c6187275dd342fe002fa5c9cc14fae508b2fa72a0576c51770a2975bf21d63fbb0bc3f5398d
2680	3	2025-04-03 22:08:00	t	f	\\xc30d040703029c59108425ca49c07dd23601cd84fdf41c0f9ad71ae6f6e0bf45d5514b75968de7904683f3d36abe42aabb89c5e3fa2f4b6662072423951bb903de3fc2514af2c0
2681	4	2025-04-03 22:08:00	t	f	\\xc30d0407030292d07a5772f7503768d23701f54ed2a65a83400c01c65cd257ac15c24d0b63fa9c96d208da63b90247805c619b17f6312738b43f99313921fd944eb1de890bf92c11
2682	3	2025-04-03 22:09:00	t	f	\\xc30d0407030252322f19332e6c4e6bd23601d0b0613edb63612234497de3941d5794ea558212c908a5ad90939d088625ed4c89001f498e88a7a83fdb83cd3d983bd6700626fea0
2683	4	2025-04-03 22:09:00	t	f	\\xc30d040703021bc00a187a053fc17ad237012fd3d94ffa4876eea7a721e9354a0bf9bc648c6ac4866b98fb76fc16341f553bb2b45961bd0e17b508a65573750cbc78a6ca20b0c5c6
2684	3	2025-04-03 22:10:00	t	f	\\xc30d040703022af114a2d85ff20b63d235013b06f6338107bdc8762569cb88b4192a044cdd46b4a50abfe88e93272950d99071f92bb5f023212a83b32001acc28990a8e1358f
2685	4	2025-04-03 22:10:00	t	f	\\xc30d040703023d744505f7e5b4277cd23701144fa3d5756647a950912420ed1f2cad4fcc1ecb6c1565fa23088f99e9f2c646ad98f982d994db116952bb81538da59b646333e93bee
2686	3	2025-04-03 22:11:00	t	f	\\xc30d040703024c864ca76b641de766d23601cec01f38e12d149c50215b3987cddefb59eb57c3b14fe772666b3d13458233be9aca29ab04144a2ec91ea91e1fa6d8a0682e1df609
2687	4	2025-04-03 22:11:00	t	f	\\xc30d0407030297587d994bd6c2be63d23701924a646d82d1ea0ecccf58cbfeb41a7ec1e19148e51366a0cda3b2358b558c98677a9a133974354abe3a4aa025faf3f9eb4639f911cc
2688	3	2025-04-03 22:12:00	t	f	\\xc30d0407030228b3076eae99f01070d23501a73a0addfd6101dc50c0e6dafbb2485607b3b4231de2dcfd9ca5964be2b1368ab30d69c824e997fa5755cdb116b72134c98897a8
2689	4	2025-04-03 22:12:00	t	f	\\xc30d040703020c1b1a616eea5bf36cd23601b08d065a4e62a1c5fef37518bc4d03447efeee1b5c2a518451b56b7fc9ef2a0aabd92442957b4f28e60bc1747e0c9990d589278b37
2690	3	2025-04-03 22:13:00	t	f	\\xc30d040703022052f1149e21acbd78d23601640471794e4a9fb3fc9376826d10291acfa7592c6f3c8ade88a5f0b9cc10bfa607ae12bc97c406a33a655a1bfc9ad071cdf838ba93
2691	4	2025-04-03 22:13:00	t	f	\\xc30d04070302ca8271dc9d57f94568d23701e6080655b5d5e90b7e34896ae41c1f1a5019aaa9a94983d9740db32d5328de86b8d1cccac1d462777076c5693374234fd663341379aa
2692	3	2025-04-03 22:14:00	t	f	\\xc30d040703023be36bac18e78ecc64d2360189613b1caedf02806c92fb41cbc498fdbcaa02bb2d4328d5370878e36112cba5ba980a8a6e007a5bd8aabbd0f0ac110d9b00010ad9
2693	4	2025-04-03 22:14:00	t	f	\\xc30d04070302e411abc77f84f32275d23701bf531926346c7769235c1c412030e4394aaccec056a516d2705cce6c3e3eca7d831acab2148a3c6933e685343e742a7f41a8e8a3fda2
2694	3	2025-04-03 22:15:00	t	f	\\xc30d04070302ee32e53a46f1b56c76d2360112c523ea4f4b32ef3c7743a3adeb5c93e2c930c2af3525b5e8beb4e1f0807f2b451dd512a5ef73de0786ee2208b73f6938ed578507
2695	4	2025-04-03 22:15:00	t	f	\\xc30d04070302238dad0a16a9257261d2370165201a1d6bafb08934d95403f1b0960d5b04102ef77613bd9a1a156901a32f4df3475f0c494e792941e1f373de66086503504c2ede6a
2696	3	2025-04-03 22:16:00	t	f	\\xc30d04070302309b6c1d46b8a92a62d235015e0b5ed100424176ef846bb13e785624e4315756d669f0db65138487842f599f88b5334d9d4b5da42218697107c41a243f146221
2697	4	2025-04-03 22:16:00	t	f	\\xc30d040703024d231a78b4e7839f70d23701ba0222328509b7da2762284267215c2115084f570463c1972822fe3a02bd74675b9b7fb8b9063edb701211b0d93fb0614eee99c340de
2698	3	2025-04-03 22:17:00	t	f	\\xc30d04070302970b1be6c1df433673d2360173b282d6088881775d9304a1cb06bad15d643aaac7efd8caad175c88cdd5dc82de31ca77c6455de352ed297ee0d2540261aa0bd1a5
2699	4	2025-04-03 22:17:00	t	f	\\xc30d0407030221a81beee0d4b4be70d23601a92ba152e42450c1fad40e0826e2b5dda7eb83dce510eae7d2bc2296d4f1fc34014403046335da899f12a14d761e8498ae625b5bee
2700	3	2025-04-03 22:18:00	t	f	\\xc30d040703029a8ae45700a0e1bd66d236018504a951791893a8a72d82cf7d1228987733991b57aa448fa26c071298f1cc5c30542518dd6bc7f241861c1141233512e93f23ae04
2701	4	2025-04-03 22:18:00	t	f	\\xc30d0407030264a8f3c69df63b1969d237010d1fefe7a88134b411cd0886f6f7ca66249afc596b0845bd7315e4632a1157bf131ff44c4d2ecbddd8fdc145fbbb5d738bb8117cea2d
2702	3	2025-04-03 22:19:00	t	f	\\xc30d040703020fdb2765ce6274e47cd2360130cae51574db69e9fac97d4b2ceecfd160f94e9229ae7daa4c2dae3a8d0ac1db3a95ae79177393326f0f0d9f9ac2388cde6315c002
2703	4	2025-04-03 22:19:00	t	f	\\xc30d04070302c3f6f4d2fa991c1a7cd23701f18b2ace53da51966a8424910aa7334bce99e5e244ecabdebbe73c642b988d745987ac04118072c38957761f086467f6e4f10b24008b
2704	3	2025-04-03 22:20:00	t	f	\\xc30d040703028571448498212e836ad2350110b318323dc12888d4d1a4e0ba3f197c5cb00883e63060f02ffb66c347a4579c59f157ba9ca3e71b67e006e38a6a7efde386f93d
2705	4	2025-04-03 22:20:00	t	f	\\xc30d04070302adbd9d2be9b5514f69d23601af89b9f081a8b2217bdb3143214bb53e8d5bbd1424286306864bb5dc54ac3c5b6581ffffd785948c64d6e3e959079308147e725797
2706	3	2025-04-03 22:21:00	t	f	\\xc30d040703025d6caf0e272f34b97cd236011996e1244f6b51c9c424a810a15b79dddc9dfc78a4fbb8fed7c9f2804e7d4f19590c9fced7b8fb822a58c253f2d8abc0ba27402f40
2707	4	2025-04-03 22:21:00	t	f	\\xc30d04070302c075109e005f2f9b60d2360125fd4013df7f10c2e5ec28298909cdae8fa9575fe3b7ff7aa8b71bd9b1f1203b530289c4caf89a3248ee4fab6d6a42bbf6f5591091
2708	3	2025-04-03 22:22:00	t	f	\\xc30d040703022f12bda1ba8cecc166d236012ddd320c55135bdfc4e4959a4adf3c277aeb331cb86af58e4d50d85a83bdd38fdcf07d42b2fa529908098eea9cdf46b30bd8641829
2709	4	2025-04-03 22:22:00	t	f	\\xc30d04070302d4cff9994625c9717cd23701a7b82f8e4c39d08fadcff511399c186de7cb4b11e24db563936cc03f36fd1c0411761540825a5fecfd071bb30c4442c98aba3f728dbd
2710	3	2025-04-03 22:23:00	t	f	\\xc30d04070302dc53bb82cfc036ab77d2350147d2bef35efb1bdd9282327fc184482cfe3c129e471fee2545c19f1a8ccca1710c0517aca44465790673b94c0d8e736102bcde39
2711	4	2025-04-03 22:23:00	t	f	\\xc30d04070302b7045be3ce1e0a3476d2370155335ff96b96c712c048f87b19bda164dc20e09dd4eed5b51203380aa8317f214df1f80070abd403a53c36a305c5a345fe1106e2fed2
2712	3	2025-04-03 22:24:00	t	f	\\xc30d040703021e09d5efba4705e374d23501dd154dbe5520f1d1970a9130fc1b9071741a575d2a7732384583840eeaaf850e8eb7a159f4fd7844e491510a5419c8b94c9be7ae
2713	4	2025-04-03 22:24:00	t	f	\\xc30d0407030279081e09203afcd46ed236013a0402c7d313e0db6a33c46032c7d323442167eee41f216dd9379e473496b3eb7ad6607c8c2da73bbacbb59f2aaa7401065b7630b9
2714	3	2025-04-03 22:25:00	t	f	\\xc30d04070302bc5443f3c3e46a5e79d236018ef4e1648c5f98af3e407888567c565cf142eab0de400ab8846c7af92fd6681a0d4fa6a31506ffaa066b7442eea2ef41f457860b77
2715	4	2025-04-03 22:25:00	t	f	\\xc30d040703027a89cea4d8b706146bd2370122d84f958179bced1456aa25648efae2e06915b7d7699b1279de5eb073a972030a0698626471af12f1f8e1e1923ff908a9a373a0a87f
2716	3	2025-04-03 22:26:00	t	f	\\xc30d04070302c59d3ac65d46138876d235010b8fa1f2e379c605275f9e1d37b57d603c9b9e087cfbf310e97a0df6f21a56158579289d6c8c106a037f712bbe9f911b11855985
2717	4	2025-04-03 22:26:00	t	f	\\xc30d0407030260e93154e726db7366d23701a2152b834a48c9104e79794daccdb57b9cc70a73595d129b7b5337d19f7c1ecf623cac99f5794c45f5fd6c8f5de03864dc88de0af2f4
2718	3	2025-04-03 22:27:00	t	f	\\xc30d04070302b142441be54af34062d23601d23b5375ef391403b51d6636a967b80e3e9ee952a4173049454bbe7caaa8c8b35ecbf0213cede26fdffeb3927a8cf9402d89b43912
2719	4	2025-04-03 22:27:00	t	f	\\xc30d04070302c13b88336328ab0874d23701a9abf2fcd03d64913eff1ae772a6bdcd707793cf9b6d3564e2385797961a5798791c76e4231aea10f60d57885a6c2f522334ef64c9c2
2720	3	2025-04-03 22:28:00	t	f	\\xc30d040703028481cce977d8603167d236016e1cff1e95cdd8e25af67439d017b1b644d111dd12b993170217751cd05f36e09390400f1e8604658beefc50c98e5b13435db71b29
2721	4	2025-04-03 22:28:00	t	f	\\xc30d04070302f10d166b2faafc3764d237010f25896fea2d9c31c7f3748b491792601c23fc989d1d211481fae39db4b6a7c83b3341b43a524cbbbd0e2363cc225a13a8368b526ec7
2722	3	2025-04-03 22:29:00	t	f	\\xc30d0407030229289f493fb764607dd23501096b8c5c8a6374987dfd3d59e1d18edd85f69706b4cd3f1b3a4937363c18b28116fa95acef7f6cb283427164333ec4c7c089ccd0
2723	4	2025-04-03 22:29:00	t	f	\\xc30d0407030279d808e4e8e56a8275d23601caee179628ef4d20baabaebbbb7211abd3f44aaef6ed4c65125115e5f1bf2e99a8a89a5e75e922c4478d340e52ffa2e6f55690c421
2724	3	2025-04-03 22:30:00	t	f	\\xc30d04070302d148903580219e236fd23601874469448ff23e7c7b4e5cb56262c4af42a8f7f5578f0fa5fb14262c357dae5fcf4bef5aae29fd5d34109d19734e981f6b10d0ee78
2725	4	2025-04-03 22:30:00	t	f	\\xc30d04070302b1447613b97a74e064d2370115eb22dbcf8dec1a5fde88ac44d5ab19be83e4ec1f7d628e2d7e4e05e00d8784405dbced4c8efaca67b775ef83e8fa8d333a3a26330f
2726	3	2025-04-03 22:31:00	t	f	\\xc30d04070302c4e2c85011b719017cd235019912d4a49d416902966e386ac40abca75ef3a32d05c11d65deb49ead48f8ce35440d53fc3bc9e195cfbcee924d5a7186530b924d
2727	4	2025-04-03 22:31:00	t	f	\\xc30d0407030219bcff4b5278d0c473d237011caf7821da5e7b9fb6e2e9b13849a02c886828440b7578ad223fa23d031a349636a5396543122a5d3bf2e33e2eab164c3fb6e98abf43
2728	3	2025-04-03 22:32:00	t	f	\\xc30d04070302646c673c66a9a07575d23501353304ec1ea3eb0fa6327985f62e13168cbfe150f21f45352604ad0c7f30b6ff0f33f96eac1d300524fb2dc7889abda528f42956
2729	4	2025-04-03 22:32:00	t	f	\\xc30d04070302730f2b3704240ded7bd23701ec44596f9ed5739f61c1d96c6445b8d26a29e18a386bcbcc76690d8a6e1c152caa32d5a0a4d4fa152f865aea030d029197ae4cf80497
2730	3	2025-04-03 22:33:00	t	f	\\xc30d040703024842e49d7a5cf7c576d23501bead6459b0fd20f7da5ff717cd2a7240bd2782d9972b88d8549f4a9e711fb8f5cd4b098a659b7caa3240f00382572e2d7b12933d
2731	4	2025-04-03 22:33:00	t	f	\\xc30d040703024354170b7d7240ca60d237014582de005d6c232bc79b30b56e60903b639c16fc82f3df3c0268b1cff974932c3d0d1acd5dd8efa6578fd5c70bd12e8fecdd0b252bcb
2732	3	2025-04-03 22:34:00	t	f	\\xc30d04070302b9233d6fd7825fb365d23601df9f826eed60ee8db8503bf06103817e2bd44ce5a7c665b39b36616d7a39a04e3bc0987d2a3f08776fc9037778b2a3b29ed8fb7961
2733	4	2025-04-03 22:34:00	t	f	\\xc30d0407030206396812eea581fe70d236019a923ed14a7a619c1a5094bafd06ff882af9ce4cf3471f99de6a23391af01a5a49f5930d591fa78e364f013de22fb944345168afff
2734	3	2025-04-03 22:35:00	t	f	\\xc30d04070302ae89e5a43aaee30b67d23601991497b2a4b414761500b6711812e32573b064a6c2a914af6e3d869964027c23e55ad74f75b938a832ebb388db725f0386b88b52af
2735	4	2025-04-03 22:35:00	t	f	\\xc30d04070302da866c08f50db3f56cd23701ca4d89fd3d255d5f179fc71e3ecf9442b8b2119008707a4b255a441885ae4243450c7dd6b09c76c1d13f2a54ed9cc6c62c01feab4698
2736	3	2025-04-03 22:36:00	t	f	\\xc30d040703025ce6e6661235391069d23601e6fc515c2a9a5df8508fe5bac9316cef5a0dac8d7de086705d1e96dc000796d2bcd0ba69e1edf39d6bb44c24ba0948aef6643d0b63
2737	4	2025-04-03 22:36:00	t	f	\\xc30d04070302e5a94101c6c575287bd23701cb22a8de6e7b437c482c52a21b4ca50ff4a8846bf98159e30d78dd5a6bdc5ce4fc5f0325447873ebe4a8c2f1af08dafed22ad09fc8bd
2738	3	2025-04-03 22:37:00	t	f	\\xc30d040703025cbb919c3356c59360d23601aa80a4d42ef54f7ee6ef6ba6a5f8d2eb554d06330e1c6c24d107b77ba6c35370174665f4ec0bac13d7f061a0add003a7f4abd820e9
2739	4	2025-04-03 22:37:00	t	f	\\xc30d040703021056b292c3f1983c77d237014a150072c3785f799f2a042ee8e117903be35af70e687de6d2749e573f18c93c043bf33f2173d4c68d5f26c6b1051c1b2af42f623799
2740	3	2025-04-03 22:38:00	t	f	\\xc30d0407030210f5f6bedb109d3b77d23601515536b5b1a412e2975638fae5f2d6035dc2eb510bffd837ca8d3dae5433c468d5fdd0c0b85aefaafd3268a73190852dcf79a53fab
2741	4	2025-04-03 22:38:00	t	f	\\xc30d040703025859a4bbf1ef12087dd2370192f276c33f5e94eaa539f8881d88d3edfb1bb9feee0d49020bddc2a8682b1e218c39d361763a7ddcbfab5f4c6e6025af0a0c54db81fc
2742	3	2025-04-03 22:39:00	t	f	\\xc30d040703020eb5db2349cdf2b362d23601329dcbb604878c22b35c147eeda8862cc7ecadb27825af11df6b82958599e419ad482403d724b0b0dd43155e99be6bfc13677a7ec1
2743	4	2025-04-03 22:39:00	t	f	\\xc30d04070302f052b7e5f90823cc74d2360146670aa73af37d5308ae484a2f687b3a40c294a53334efe00b4633f0820d634970813c755fd543c0c9d4cdbcfccda2338641dc9dc5
2744	3	2025-04-03 22:40:00	t	f	\\xc30d0407030293b4820f70eedb8664d23501659bf5cbbf38b4d2cdaf23f49640faf2d55d07e331ef0d16d5a1128276102c88424548b8535c127996a9731a353976bdddb66066
2745	4	2025-04-03 22:40:00	t	f	\\xc30d04070302a6d346a73897488163d23701f2a83ce7c07a6b71c98d249fd53d28b23c0f13e5780c9326a77112cb5ff0ebddeb3a72cbdb9d2b7960998ce7a48fcd4f533c58f357e2
2746	3	2025-04-03 22:41:00	t	f	\\xc30d04070302b6163af34245bd407ad23601e72943ce6432b49ddf106ea782ee4b388ccfdb231d42dd85d232e20d4626882dde5accddd19f0e10b592f18df0522f3aa5170c75be
2747	4	2025-04-03 22:41:00	t	f	\\xc30d0407030261995cba0c93192863d23701ad97647941b78a3e4edcea5823e96c7b02803635bb23bd2fee848fa7554dd8453c1390949c3d0e53fccb0304b8eb0fbec85ebe65f6f2
2748	3	2025-04-03 22:42:00	t	f	\\xc30d04070302407d7787bd0f92836ed23501313c20e968df068ecf27325c374d2610fd1bf8bf5b14f00bec831b5d4006b575881b11aab1171a1b75e32b043d462dd9443956ca
2749	4	2025-04-03 22:42:00	t	f	\\xc30d040703020a9bb0e14c763c8768d23701d127918d53fbb8a48d689ad5e71cba397b390b8a2a7ef033c5e8c0bb77e0d30e672f890acf47966db0cf86675833c165d428c70809d8
2750	3	2025-04-03 22:43:00	t	f	\\xc30d04070302c79180933ba3d3ef60d23601cfcc7ad3c30f38ec5945e1c910a37c1daaff364268f578ccdaeef19d01e052b14109633552a15eeee8e3bf51d4ab49ec2c862b44af
2751	4	2025-04-03 22:43:00	t	f	\\xc30d0407030280ea630e760445bb62d2370127f7e9deb48d0ec645299aa0d5d7aed001d77134656f4b817968ec41c03bfce2f2efbcd9422938884cc05870314d71614434afa73452
2752	3	2025-04-03 22:44:00	t	f	\\xc30d04070302c60db294ff20ce1b6bd23501fca464ed1e36e3cb3113f3983b338734205ee7d718e82ee88b1d8c4f41cf3a7c521b12694e5eb4f2d0bd13711cbff5ae850b68d3
2753	4	2025-04-03 22:44:00	t	f	\\xc30d04070302438da31d3eb5a46170d23701b9504b7ff83e32101e6b3b7c59fad46dcfe246289583db0099aff540b3efeccdc63c7c6418f375002ea17b34db42ec878ddb212d2eaa
2754	3	2025-04-03 22:45:00	t	f	\\xc30d04070302df77ed36a70da5d569d236017628bb48ae33ecb5a2a73c14d2c6920938082b8aba63084d75fd406ccf01614bbc5f0e1c43d771cbfb2bbbf98e3996e0b9cb5a34e1
2755	4	2025-04-03 22:45:00	t	f	\\xc30d0407030276260fa4a14f80d766d23701ef601b2f70acc810f146227b0624993b3a39a0a8fbac29b220529a472c7952def9b7fb052c67ea3bb294865728fc59894512efe2fc0d
2756	3	2025-04-03 22:46:00	t	f	\\xc30d040703023d34ec0bf41563cf71d23601a00be8b7161adbc4bd17464255742ce15de694547887162d7ab6d9194b048cbb6fdd7d831dff26440fcf66a3f3acd1c39cea5d60f5
2757	4	2025-04-03 22:46:00	t	f	\\xc30d04070302beb44439af67394765d237014ad7f241be0020af1956cecd7f79b9299cb4f7a952509f03128ca6e3fa36ede96155362965135c735169483bf6173fc3de7c57ed9015
2758	3	2025-04-03 22:47:00	t	f	\\xc30d040703029d4075776e3e9ba971d235012edbdf036ac314a59fb1f3798fc1a00129ef78a7384140a894484a39292dba66c5c11762447c0664031aeb07c4b93456cac43d24
2759	4	2025-04-03 22:47:00	t	f	\\xc30d04070302285d683fbf93eea468d23601d7789a86e6046447b315bcb232d3d4edd0f6ad6abbf3971cc91a9d86e4e6eb31b8c212e38672710cd25fa8d5c0f8f25d3cc9477249
2760	3	2025-04-03 22:48:00	t	f	\\xc30d040703028336f80621fe9da86ed23601e94deda40be61d11690cdc7e5d2b398aecbde49518abb483b4a8014b72fb32c6dd4ed68ad9dcb87a37b463510ff61e134031d48b16
2761	4	2025-04-03 22:48:00	t	f	\\xc30d0407030268847b29d4254dd56ed23701128a2451dabd9a91fdb8ba037e5ba545e8777e9c2e4e76514df5f2b978e1472dea94353ff7e3ebd0bf780d94c0c383bac95c2f8a4715
2762	3	2025-04-03 22:49:00	t	f	\\xc30d04070302358443f14602a0136bd236015aa6f65817d42044166a694ef50421b9610595b491a294152fa85d1b3c93f421038e8301d513908ff4dd8af579bb643ca231e8e5b2
2763	4	2025-04-03 22:49:00	t	f	\\xc30d04070302300437689375897170d23701539a2c47eeb7e9e878401201987b019e6176c6d965e980ed7ef90929bf0d827e4397a87aa59d9f515c81cd508f207d99c6b32b201d06
2764	3	2025-04-03 22:50:00	t	f	\\xc30d040703024063f13f006e2b0e7dd2360114b0cf25e4e3691fbdbde7208e2049ed46420a04d2150fd65512e1a306cb9422c8a78ad7f8148ae69c39a805e953c1e6630dc0f90a
2765	4	2025-04-03 22:50:00	t	f	\\xc30d04070302dcdca6cc684b991870d237019b377e61bb2d2d38578131c56253e630bb49298b13dbcc69dc4b548de6d8c4157fd4f287b57f23dd049880289028b30dc8846b5ecd86
2766	3	2025-04-03 22:51:00	t	f	\\xc30d040703020aa8f23b462cc96e7fd23601b7a70c002e97bd25b98bff8e8638af3200abca495342464a4c1ba414f416dc53904df363504ba979c9caf258694dc709f6350b21c1
2767	4	2025-04-03 22:51:00	t	f	\\xc30d040703025c8962ab118b749278d236013de6838230bd13f1786a73fd3be6bd2159dbb3b5d644160afb24f66045e61b3ce0e07c7bfe7aacc4de47c7d102a16aef6a6de4fdd3
2768	3	2025-04-03 22:52:00	t	f	\\xc30d04070302a11e2730b72af24b60d23601c42d518e67d93eb3f70144c0d1a6c0fedb3d3ca15cba7fbf3c7c7a6963e0e574d81052bc57594dcad7a2a0ca02c697d1680a38d737
2769	4	2025-04-03 22:52:00	t	f	\\xc30d04070302ecaedc319744dc1d77d2370119ea81cf983eab3de69837d6b5027083a2ac327d6378c5c7aa30090796e7b7067149ecfb20e139f3bb567d9ee1a0962f14836bb90e22
2770	3	2025-04-03 22:53:00	t	f	\\xc30d04070302704d0da1c9f3d30174d2350154d3eb4ab24316a62f162e1b9a6c7bfc9150eb2a5883d87440443f690e01a6655886486b0a0efeeaf0415db1cc685677815e1115
2771	4	2025-04-03 22:53:00	t	f	\\xc30d040703027047033ce88b68e366d23701f2571c44b07e8dd54c5c4a3738a407b3f0addcc8abd3cbddef77e6ffafb596b89966ba5481db56a764ce47a391cb2df96e5ea14ba834
2772	3	2025-04-03 22:54:00	t	f	\\xc30d040703023f79f4c5b743943b73d23601c13095419c2da04de48d239b7d5ef604383ceafc295884933423c42faf236efc4bd32168bee2ed43cb3efebb0b9249c0212ce81bd3
2773	4	2025-04-03 22:54:00	t	f	\\xc30d04070302434d2e66496d6a7c66d2360183eaf2c62abb9ebdf534dcf10a701a80247d395dcd19482b2abd5f941940725465cf7ef39cb7c1d7c2735f08d13b8871440f9888a5
2774	3	2025-04-03 22:55:00	t	f	\\xc30d0407030295680f5f48705f3860d236010da05c9c69f3c263284b669d4dca96fe8a38e1468d568659cbb769ba17d63ca1170db49a85c2e1ff3b8995bca996986cc3acd835f1
2775	4	2025-04-03 22:55:00	t	f	\\xc30d04070302357721c916359c236ad23701ad4c941f2671521b4b340f3aba14fe9fc8c192342aed0a12f4fa1affda26ac6a4e5dc2df85004806ee17ac2165a79b8b749178991a64
2776	3	2025-04-03 22:56:00	t	f	\\xc30d040703025dade7dce7c18bcc6dd23601def50f4ef5d924a37138285ef9c8e81e55b49c48932eaea0fad37483a6abfae6588495a2dd40110c9e6a0be40a4e1ac6c1e76be447
2777	4	2025-04-03 22:56:00	t	f	\\xc30d04070302ee90211d9190d5ca66d23701e4a733eadce12f3c25e1be158a82ea7f7edab01a310ae8bc1209c9339d5f03ac23b85a815abb0d0ac74c3b9c5526b7d0ceb21fdfeeaf
2778	3	2025-04-03 22:57:00	t	f	\\xc30d040703026c471caf45e8107871d235016e30261a3e2a443d2009e6b30abaf3c4362dbcce9419d5413b09295a619e4a974ab4230d2d9ca5ec8753f6c601bd44d9dd3e379e
2779	4	2025-04-03 22:57:00	t	f	\\xc30d04070302b796b118e08a1d0865d23701b120cdc69e864e7f7ae6cc760ad0edacd01757d8f405e33824e43ea03a3ec9d51f919cee0cfddd0fb67297aba21fe38834b50919cd3c
2780	3	2025-04-03 22:58:00	t	f	\\xc30d0407030249051b6f5294115c79d23601fabcc265ee06d209b072906fdb1f6b502bfa68a65e906c0af1021a26de21baa05bcb5f91da57d636d4a0eb4c142707ed9819228e8d
2781	4	2025-04-03 22:58:00	t	f	\\xc30d04070302bc375f5685bafa1160d237012b816a8b529c029aadf62b02ac0145a0be857e323c4c6889d1b30b6eb859fcea7233109e250911f57d0c46903bbb0f25b95090fae5e3
2782	3	2025-04-03 22:59:00	t	f	\\xc30d0407030214cdfe92047f36c964d235018e158bfd5e6b84b024ab9a37e40cc452022a939668071afef9736f307d443c200b111e4f5e07829bb951269904d8134a88a9d105
2783	4	2025-04-03 22:59:00	t	f	\\xc30d040703028eb33d27059834b679d23701a85c3560d96e80e382d5067d3dc4b5ceb1aaa46d196c72df139b3d6af465da358d72cc96838ec29cd76c1e234307a1c289b358765027
2784	3	2025-04-03 23:00:00	t	f	\\xc30d04070302be1b549230f65aee71d23501678f84163be255016b17dee416c38a0079e0b1a84f69674aa25996dd78177622696b2061a258dc0fe3bab278232942e9e73b7455
2785	4	2025-04-03 23:00:00	t	f	\\xc30d04070302f776481eadee0aa860d237017ec7eb24e876b5a0349a108c3bdc1712be686cd3992f133c61be2bbe5d8539c21184433baa2a5cd02988b1ea72e8a40624ea4512f1fd
2786	3	2025-04-03 23:01:00	t	f	\\xc30d040703026a4d36b6a4d7e14575d23501960f1a97e746a5c02275df7e2585bae9bbb8faad73bccf19e9d4740102093cda7453e30214f455a4905c4ca95f280378b82dd696
2787	4	2025-04-03 23:01:00	t	f	\\xc30d04070302b99ce8780553b5fd72d2370174718ab5e838fd789e2799a86a2b71719ea30839034f0a883968ed924d1b44f5ae5a4998b886c7c338f7f7f80837ed8a287989b5f635
2788	3	2025-04-03 23:02:00	t	f	\\xc30d04070302cedfa6d280b7a31065d23601c62365b33dc71415e30a5445dd8964d312b257da9dea48159df6904b1a56a2b49f1c8d77c2aa81d63f99be6e60b7d0bb8af44901f5
2789	4	2025-04-03 23:02:00	t	f	\\xc30d040703022cef065d81f059757bd23601214dc3c61f4f752874a0fb357a2025d719a8a51e103699750623985dc39b9bddf727fc3a88038b690605af9edcd52a8ee9516a8053
2790	3	2025-04-03 23:03:00	t	f	\\xc30d04070302516acd8af50788ab64d23601fd62bb9cf9a2bc5f7b77745b12d425e603873f5c7c293bdae70e6c86a37a6211b705db9625d8c3ced70188371f932a56fd3fea994b
2791	4	2025-04-03 23:03:00	t	f	\\xc30d04070302d6915a867ec019db61d237017430152c2ea463a1d9a4fad255e1e80ce4d583ba2f4ce0b70f75f03999814a73ac42d0e045f992d4c9972380cb82479b3441206c1ac8
2792	3	2025-04-03 23:04:00	t	f	\\xc30d0407030226be7a1b88b5e1a868d23601ea96434e63b1a8ba68d0ed1dbdd84d653cd28f66942698a7fc40830bd6ab01739063901184173d075439e485a4827728a49a4af8d1
2793	4	2025-04-03 23:04:00	t	f	\\xc30d04070302ca5319dde482950569d23701433fecbc3981f57053c02767d3e813d144570ce2723885988e9a3c5d608c5873e134339c80a092d6c730378550cd49698e015b6dcd24
2794	3	2025-04-03 23:05:00	t	f	\\xc30d04070302b0440f8c398920d47ad2360144f7afc7fdc49d43a301fa2d8a206bc9b10453ebef9355b28d589a868baee9fa2b3ae2b079102a5679dc4f352ce8066efd3ecd4754
2795	4	2025-04-03 23:05:00	t	f	\\xc30d04070302a2d6c042718210ce6bd23701dfac7cc0c2c6ddf69331dde9e804899b69e4521e0fdd0ee09e10420809a9b3ac1d6b4eedddfc618cbbefe7031c7b9c7e13ab4b036d86
2796	3	2025-04-03 23:06:00	t	f	\\xc30d04070302af5547afbcd2bd706ed2350123a5ed0d72ce7b4606ddd5ca4b6c2209db40901337d30978ca793f28f2480cc18177765ea0bcab2b9399bd0e54d9cbe2bcd651b9
2797	4	2025-04-03 23:06:00	t	f	\\xc30d04070302f59ed55bf39cdb1468d236013c2eabb9064ba29875e37a0590305389ebfc522cc26354395983d07f4ff1177c82c63dcd78537a51f7e97aa53ca7e10841e27ff4f3
2798	3	2025-04-03 23:07:00	t	f	\\xc30d040703029593b81198d6f74c75d235013702789c70280c6f0b6373c6ef6cf96a7cf88999bc1a0d0e35b34f185ade4a9273833bb4021fbc80ffa4d3de3c40970dbcd57406
2799	4	2025-04-03 23:07:00	t	f	\\xc30d040703027c7f6244a5ec9d9b70d23701f6a415b7dd59268c0f4dc84689e5367f6d50685fff041cb84ae36952ee66ed8f5d1791d76b89209ea4ae01c3d023d80a6a77a55685e3
2800	3	2025-04-03 23:08:00	t	f	\\xc30d040703020997c21f880a709270d235011bd253145e7aa7dec43c8ee55f10049758ed3867fa70a805b3b3e1e0c77a889d2f7f9dbf1223279207414512f5483e62f628543a
2801	4	2025-04-03 23:08:00	t	f	\\xc30d04070302db6a18cb4d40589c7ad237013a905d063883d37a9457ec49e80472126c0dabf1a455e45f94f761621aa113f369f1e527f28d386b7d7abeda2231baf135b93d35a252
2802	3	2025-04-03 23:09:00	t	f	\\xc30d04070302f08f86ef3426a75e6fd23601484ba4b43bba65b2af85bbd86f20cdeb840bb136207d95dfb6a029ab1ce16eae23e60ba7ab5d19826b54bb60d61b63cef51a868a14
2803	4	2025-04-03 23:09:00	t	f	\\xc30d04070302eae8065585b3ee987bd23701d46d92a1c0249b96979567e1be170f2e1ab99d7c2664cabbb66594df300aeec9937cf968b9d89cd71e287d95ae5cf893dbe0ff791243
2804	3	2025-04-03 23:10:00	t	f	\\xc30d04070302a850c0a61cfc7d7b65d23501122a55d1c6cd4d6df193e4891519d8ebe3f96e3ee4a714c25632163b60c66085c605a07c9a2cdbbc869bed1ad520c1bbee041404
2805	4	2025-04-03 23:10:00	t	f	\\xc30d04070302549e14cbd339e09462d236014c21ca9270a7668752165d660b57f11670286a1239b15d89baeb5563572b2f907505cc429099c28e66d6979a928c77fe8d1154cd84
2806	3	2025-04-03 23:11:00	t	f	\\xc30d04070302179719c64cd8208977d23601d086b2113ddf5e59763398abedf6479c4cfe02c054165cd51cd8c9cd774ae141e76ecf7842206536ffe42bc28765b6c6b327b84b07
2807	4	2025-04-03 23:11:00	t	f	\\xc30d040703020e4a37f7c6a5f43167d23701137a395ba4d5f9ab406b2a1d8fe3b5b57dd7ec1933235d934fddc996f550af1d256e8a40359bcee1475a9bec50e0e4489afca4fcec32
2808	3	2025-04-03 23:12:00	t	f	\\xc30d04070302d4de9c091d4558536cd236010645dd014780b04f57cf46679e1ad016d7f3142c3c89c8d87d3a6d68798029c004ddff25b2df8e493a7fc1b3a8691859090075b7c5
2809	4	2025-04-03 23:12:00	t	f	\\xc30d04070302c20fe5a5e68bcaa67ad23701ebcb7cd53ad56e5c890412b6b298e931fdb04e308674eda9802d3ca61d055d77391415320191f8cce184f25f608435caa8ce49b2b45b
2810	3	2025-04-03 23:13:00	t	f	\\xc30d040703028b72b65af1b0893a7ad23601b172012d668dabdca8389045fa8fd0ee633c0cb861ad71ea388220cd0d21168d3b3b8daab06aa20c24a92d4a5ddd319908a794938c
2811	4	2025-04-03 23:13:00	t	f	\\xc30d0407030268b8a655a7c74e9c6bd23601e9b16225cf499225a0a59fe6a260028dc1850ac817d3f203558949ee14b42125f943c6325697883c8f76c77a2756c5c48ec69565ba
2812	3	2025-04-03 23:14:00	t	f	\\xc30d04070302e285e79bdb6df68665d23501e2b4478d78a3aa4dfa21b4652a25fa280968476c7181d49dc718178360bd21e6a094704095ff61644929ff6548c447e27d52be3d
2813	4	2025-04-03 23:14:00	t	f	\\xc30d04070302cad7a0b578e3691065d23601dc73be08952800725776a84e3fbabbe3a8b767d4bef462022c00170bb2f7bf3770211a69ec4db7050a8c7094a24f17b56a883dd755
2814	3	2025-04-03 23:15:00	t	f	\\xc30d040703028de93599214b009b6cd2360130dcdd49c47f19200dba63dcf94e1479a421ab9297be45ceca4b7fab8fb1f3483a1bb35c149579c22eaa3d1413b57333bc643e311f
2815	4	2025-04-03 23:15:00	t	f	\\xc30d040703026334a499b9868a2277d2370182f53e840481a21429ba8914385245ecaf61ec29ef4a20d4a39c83a55baa8dcaae9eec316d8d3e721b7d9fdd8631e573852cf5391a13
2816	3	2025-04-03 23:16:00	t	f	\\xc30d04070302d78fe695ee919ff66ed23501991170ad0f550daf284bce50b333010080abb1e63202dbe056d06a054c1eed6e49c1b1a84099ce5e48584d282e481481269fb0c7
2817	4	2025-04-03 23:16:00	t	f	\\xc30d0407030201cbe0e55dc6815b61d236012dcf42304bfeff1b7180d1eb175ab40e3b903f8e6dfa91c03a13828a761d482e2b19d13849c9d5265ac7e528a1ba46b74683dd618c
2818	3	2025-04-03 23:17:00	t	f	\\xc30d04070302a3232dea328b0cdb63d236017f371a8011cca7d539a5c4b76e3d01a3fca89ad022af526c12f498e24822c0b31b929395b5333b0b3029f2a491280effb6b65fea61
2819	4	2025-04-03 23:17:00	t	f	\\xc30d040703025fee0ba3ad44825a73d237010f10e6a582eeb10b88abda67df25fb1e9ebb83b5f44468f9f8159de32d99fa47887d65a8a987feee800b32687b90a104093d4e64c61d
2820	3	2025-04-03 23:18:00	t	f	\\xc30d040703027785c611bf21839062d23601ea03bbf3a832899c2c11b8eead2cb55aa8b686a84e6c4837119fbd3767c7f58035076827058665d33b8b69e4c0c3929bd3d8d0317b
2821	4	2025-04-03 23:18:00	t	f	\\xc30d040703021002aafd76dce8c261d23701050d4e9396ff390e4eb9b2a982dc26b4ca6377ac107ad890000f806c6679949c79e04e0fb0bcd5e0a13f5b0be35058d982a144e3cf2b
2822	3	2025-04-03 23:19:00	t	f	\\xc30d04070302ab98426d6e1a962b6bd23501992955e5e3af831917718732b3bbbc32c6113f46b95266f2fe54e4a3a607cab57be3ac01b5cd90edf136eca280e467109f741584
2823	4	2025-04-03 23:19:00	t	f	\\xc30d04070302bc577d7567f2a56763d2370167a33b78fe2ccf1905246197ffdbdb4dd9363af15898d9e3b4c7017222c174820470222c79c562df17c1a30e3f2b623d29a199176d8f
2824	3	2025-04-03 23:20:00	t	f	\\xc30d04070302965ca4c73062729f78d235017adb95d13f7e4cc75a49b0c487f164ba53e4a65caa9f379a5b80e4e65a47ae5ed2b0b577a4e99119d49c056a57a0a7bce527a82c
2825	4	2025-04-03 23:20:00	t	f	\\xc30d04070302488a10a4a1627cf56fd23601edcade8537ba064ee778968f037904135b4b71d6365315b4b973dc826e062cd63971602e08a1dfe7328d6365a40c1ede8a7f792d4b
2826	3	2025-04-03 23:21:00	t	f	\\xc30d04070302656f52af42b58d4978d23501aba9678d3a9aedd896538016fa9d680cd75fcbc7c82bf5f1ea1a256ee3016bad9ea965c92b550e81bd448272c7f41e8a1f517256
2827	4	2025-04-03 23:21:00	t	f	\\xc30d040703028e1f7a72aab3be2469d237014285d3eed340131f8a8a09e39ba997a10d89933035aea24d8ffe0d4faf29eafdd0a2c057da1ef2fbc0090c4eec0d50cdfa6af22cef22
2828	3	2025-04-03 23:22:00	t	f	\\xc30d04070302f29b9983a27f919c76d2360178417b90773995d56e1f53a134d0dfdcd41777a86c5bb3b907cae12efa6f6f08bbc801b8c6696c81c3714f6c4b2fe712ea73ef6871
2829	4	2025-04-03 23:22:00	t	f	\\xc30d040703023f78d3ee35b901b372d2370184ebe6b76ceba7bde06a724b400bdea20f9e715f062ae94418ff8415f7da215e87dfc97f393093bb0e531afcf4f14094bf5f2de6bc1b
2830	3	2025-04-03 23:23:00	t	f	\\xc30d0407030275af07bcf04019817fd2350157d96254b577a51ab1acd72a4a1990b9fb572978014ec74a38d02a862c7d544b2d39fe568f92a60098d5af7013de57b646fa566a
2831	4	2025-04-03 23:23:00	t	f	\\xc30d04070302590b6d4d2a084b787bd23701ba8dce6bfe68e3b2ba9f40adb391050b4f820750cb96c546006ab2007c3321a5dec832bef2cf685cde5b41ef14e373b42a6e334dc019
2832	3	2025-04-03 23:24:00	t	f	\\xc30d0407030244abeafefaebeea172d23601a4963a2b731dd62c5e228adb4fba521ac031c0e0a3a0625242b78ee14f24db22ce5d904dc6fdabb9ea6c1e53d3d4792779fd88e954
2833	4	2025-04-03 23:24:00	t	f	\\xc30d04070302c4e374eaeba1e09667d2360123dc9ee7c77937d4e4a64c1e5d5c7b2137c128da7fb956f52870327342208fe11c0f3afe272b817889b481dadb7bd8d06012589256
2834	3	2025-04-03 23:25:00	t	f	\\xc30d04070302ce9191b419e073f577d2350136a313b0ee43c7d9f017bfa9d5579ad841c7bd6aeb9caba62fe04ace5dfc432e0aec4daf46a4c11cb0d865669fdff733c6ba999c
2835	4	2025-04-03 23:25:00	t	f	\\xc30d040703021cad598569f411436ad23701b3c836f59148ab8117a5b94fb839c5e853d56dab1b0137a51bfaaf0f18540eac5dc4dd55273a480dcdca0bb3c08ebbe405fa8a7d3ed2
2836	3	2025-04-03 23:26:00	t	f	\\xc30d0407030217b0c311296bab3a6bd236015ffe3cfcfd29fc6aa47198b8704aafb400a72c32945c6ca96bce6a5385128131c356cf7a1bd61c50a4e97b68a7f74a8504140f57ea
2837	4	2025-04-03 23:26:00	t	f	\\xc30d0407030221fe646a62d9133277d23701804f560da857efbe1ff219472776c4b6110c0416e49769b51a89bd526778c6983fb686886d4cb45ec936c85a10e928bf19d2e0807eef
2838	3	2025-04-03 23:27:00	t	f	\\xc30d04070302a5714cd85e223e9164d23501e49f94e5e027d82ed850982adcd909d065476f81dc899218760bb323cd4eebc24278071ad5da72b73e770cd19760c8a17c6f4d22
2839	4	2025-04-03 23:27:00	t	f	\\xc30d04070302037c465d347850c375d2370116ef35e81f3f83dfafcf68b9da22bc1d29225565497490e938fca3d324a647c9f566cfa654f4a4d7879de8511c71a6f65707e9fe2faf
2840	3	2025-04-03 23:28:00	t	f	\\xc30d0407030204d14006956c51aa74d23501c9ff90af3c494f19b3a39737d7440898ab6ceb81099c6b02c268b30460f0b0d02366052c9b7475bc010cfd632d9d19339995262f
2841	4	2025-04-03 23:28:00	t	f	\\xc30d040703026ef84fa354e97dd27dd23701f5b91542c95e4716fddf22d6d5ad97cc26ca29234eb81a698b7161b9c476547f45b6d5bb7ccf237ab195b3ea211060bff89686c4d341
2842	3	2025-04-03 23:29:00	t	f	\\xc30d04070302fe70aacebdd0a2cf72d2360194277cb7cfdc441b3ec6541dee0adb4051ccd514cbc05f76eb092f43e171c3be6f2267fc654d56c447317b87e926420ecee7a7abee
2843	4	2025-04-03 23:29:00	t	f	\\xc30d04070302cbc9b6f5249f23ef79d237019865f09a116dff467df0398fbef0888f844c3e39db725864451199f862fba890013fe66a656b15a2bb1ec53db1302ab30d6df8712f6c
2844	3	2025-04-03 23:30:00	t	f	\\xc30d040703023515b09ae790de8862d235019a820c77cd3423d9bb5406dfecd5945cb014be134567514020abc6786fe2abc44a72ab94fe953143720eb5dd7077a81c088375df
2845	4	2025-04-03 23:30:00	t	f	\\xc30d04070302f1907186bc4473c166d237013bc37c31c60cd0cb1d4748a1437f80f53304c1c72686552544ca694612f0bd55b53fd2ddbc6d2db12b4f3d392c67e8f51b4732f0c78c
2846	3	2025-04-03 23:31:00	t	f	\\xc30d04070302ed25129e50b0b64b65d2360165bbf9af7b60d175dee8f5e30f75da48102083abf9aecb33b37a7634dc94537990be122f38e251fecde6407ab5561270f03a0ee957
2847	4	2025-04-03 23:31:00	t	f	\\xc30d040703020255561dc038a7fb68d23601fe78df36a68e92d24ae322be439a8bb7668fa3634768023c537fa9c6fbef18995ce3aaa6b5a514bcfa9951ef60f3ab200c0e1b1c16
2848	3	2025-04-03 23:32:00	t	f	\\xc30d04070302c5655e11cbeb1dfc6cd23501dd504f849656906037bf0464ea9c0393973c869d2879b9dc37a15525280784fc53a551dfcfb46b7162aefb76351a612766c370d1
2849	4	2025-04-03 23:32:00	t	f	\\xc30d040703024316efd60f1b89e977d23701aa4fb9859746a667ea5bc8e04b310d529f0865d77fd92649a0d0d4a3ec429fd57573a2ef068ab709cd2c31a0175c670f90ba7ffc61cc
2850	3	2025-04-03 23:33:00	t	f	\\xc30d04070302390cb76f078c19f57bd2360131dc8b75c8dfd2e15414a42cd03db16882630e1b8e9c9e7ef730d0bb6fc36c932e875e3efae5a775277189144be36b439a42636c53
2851	4	2025-04-03 23:33:00	t	f	\\xc30d04070302d53a220a0d83abef62d2360195569eb8f466a986787440c686668e78c891c9bdd7396db40c0c62b1b0dfa32de8ece26419fb5b43caf1fa38468927b719e531353d
2852	3	2025-04-03 23:34:00	t	f	\\xc30d040703028aa231de127875907bd23601b9f25f5b72ccfa6e6185c2203a1a3ff0323d798babf98d0644895189672d4b72890d58a3977114d2545aff46f4af23192d1b9feb13
2853	4	2025-04-03 23:34:00	t	f	\\xc30d04070302d31c46a895a2fd677ad237015485c593a58ea573d6b13c1076e8795970e63cb79de44a827d04cb979767124a606959b37939dfca041b2eb09c208c046923763e2b5e
2854	3	2025-04-03 23:35:00	t	f	\\xc30d04070302188be3ed2e732ceb75d23601bad284c5d71465b418450a5c936e15c88c84c5bdb291dd7c87a8e41035a08166b839ab322ef973fb942e1ac77812ded93be53a62f8
2855	4	2025-04-03 23:35:00	t	f	\\xc30d040703020cf89e8eab02521375d237015c12711f01e732e9b3533488366cb0a22d9c9a2cf498065e6bb099d6b48ba9009991088dc5fe70edd221ada1f295e553af3bcf7d985a
2856	3	2025-04-03 23:36:00	t	f	\\xc30d04070302d1baef813dbeb85f7dd23601b2db562a4f1f5a7dd593d3c0005751ac248c34dc2ce2ba28d4ada04086e5e5e3f0ac2c940b60a4829fd067e4aed913873218919051
2857	4	2025-04-03 23:36:00	t	f	\\xc30d04070302ca8654f512b0805c72d23601889153d745cadba8e87009ae8dc6fed1cdd56f7f86ad2f367af8df9ae955911cc2036daa8cdc9753f6662be06e779e5b16f65500cf
2858	3	2025-04-03 23:37:00	t	f	\\xc30d040703023f6fa72f11aafe4863d23601181330fa5aa6c299f01ffcc8bce64221d61ae433c78452755f418c6618f3bcb44e0cef1637fb8219d7fcd604970ffb9a04264d2b2c
2859	4	2025-04-03 23:37:00	t	f	\\xc30d04070302209e4175df0c519578d235012f9f91b71652a308f159e3ab3a013e4908c049e04420d79186f5d2265a9e130f5b976563e9fa8609d75f71c364e783f6f6d03317
2860	3	2025-04-03 23:38:00	t	f	\\xc30d04070302ec0686ad2fbd6f5472d235014d8faadd547f51245f42cdcce5aeebdd66ceb5cac4df787cc108c795ad23219079ca5ee46bec59e52c852663de18b41592e8af25
2861	4	2025-04-03 23:38:00	t	f	\\xc30d040703023b0a06987e5b48137bd237011e1e9327a9b03d6a333abcf06efafcc343293909ea65417622c9a0a16978b09c34101a862b333065c959faef0bb8ca5f487c433c5dd5
2862	3	2025-04-03 23:39:00	t	f	\\xc30d0407030235d322217f70ad786dd23601137ff78e10d771cf4edbb7c18f3199f733013d43550fd4709b24e3d33ba5aab6fa45983a2e567ca69095026dcf0185f9b836fd97c7
2863	4	2025-04-03 23:39:00	t	f	\\xc30d04070302a0abcb981740fc3866d236017db7614534d4da843050555f50d3a2dbb65fe6951275c3df7991b68e04a17d4f1e84dcb1f8c2f450c82193fe2b799cad81dd4ab39c
2864	3	2025-04-03 23:40:00	t	f	\\xc30d04070302efbb5d9592844e1d7fd23601b51837f9607ba557db24397229f24fa41e92adb6ea24cb86d4a2c4cb0fbf173c95b5eabca8284ca0a3f54074bdccf75c342d45acc5
2865	4	2025-04-03 23:40:00	t	f	\\xc30d0407030244751da5e006811c75d23701f49402c980d4c9ff2d6d508c72b7932f208201b0878a588540f6774c6c0428c55fddda8b179792be16192ac0932598d85fc5539a7fe8
2866	3	2025-04-03 23:41:00	t	f	\\xc30d04070302f0cbab333859117966d23601062b8fb1226bc376688543ac249ef063135439ce875f39b67f71120abd97f381377b5fd7a6656b02b68187553739c15c85944f7509
2867	4	2025-04-03 23:41:00	t	f	\\xc30d0407030292bcbadca9fb692967d2360149700bcdf6d036f63f175f3a1dc8348ab7398f1d245ab3483e4df079ffc56d891125433e4f3ed6f8c3bd0901bba3c6f910c3b02a42
2868	3	2025-04-03 23:42:00	t	f	\\xc30d04070302fc2a59aa2921c39165d236012f293f2c9f1cd3113aa0a876ecc7e0d7e7afa2fb6e1b53e1150400e612c6482200e8f979699ba6ffdd6244f4c76ae9b80c45c1580a
2869	4	2025-04-03 23:42:00	t	f	\\xc30d04070302456ae555bad4d52b63d23601fea9e48b5297d9a1b81764f35c1a6eaccfb62c2f4c2d164b364e9af2a80d1c7739d714bb1e6ba12da55fe36928bfb4a9cb07e4ff51
2870	3	2025-04-03 23:43:00	t	f	\\xc30d04070302c7e2943aea218c537ed236015421cc3e361378bce976a3996786f2fd4b918ede4ea15b08053e4ee216589730610f2bf591ab9c9d256d4e6683aa53c37664c16629
2871	4	2025-04-03 23:43:00	t	f	\\xc30d0407030235a5e10d9800e82164d23701833398f05ee29a9761dfbb8957f65ef21a30b8dc449306361790a62d15d921013b4e6d9ca8fed98618f905cdba51c1036567e51dd10b
2872	3	2025-04-03 23:44:00	t	f	\\xc30d040703027d3cdd5ce64c0d9873d23601ec252608cc5a9f65c618aacc6aca7dbec397ab896c9eedfe6456754c37e29aa8c6e941317fa5da059652ab9900b56406e8365819bf
2873	4	2025-04-03 23:44:00	t	f	\\xc30d04070302ada9699ddfcdcc2371d2350108f2c0f264b3bbdfd87724af20c5002c3a7406b0872c748f969ff5418b736458d61f801fce94e4cf8d3b4cba3f0d0b3a9db35a5a
2874	3	2025-04-03 23:45:00	t	f	\\xc30d04070302f898cc07d6df8e6472d236014ec62f4b7f0c5d3f45c015d3d6d1919e43b1b46fc1abea915d5267525af4a4be06679b1375281239242517eeaa0e4f33277a9a99e7
2875	4	2025-04-03 23:45:00	t	f	\\xc30d040703026cf68a5d24ecae7e73d23601b957de95b2132f760f085c12cbea2119e3204e987ed402fe370edbe6c1d4d0d9313401d2e3f27e781201f2eafd862428156819b0ef
2876	3	2025-04-03 23:46:00	t	f	\\xc30d040703023cf3ebef4adf76eb72d23501d308322df3baa65e4f6929d806287e5db4ea02acdddcbf7ff86872ac81ec8cc8bed58f8ad77bdb71b2bf79096d6e00a61ca2fa59
2877	4	2025-04-03 23:46:00	t	f	\\xc30d04070302e9c5ea024c0113a764d23601d868f55fee6b954c27aaed2b63e8283d62f9a52c4efb21e68a65ff4dfc9cb2586fc3de273d2b3dff27cf58a9f7d6fd3e0805539b25
2878	3	2025-04-03 23:47:00	t	f	\\xc30d040703020f1bf5a60753733f6ad236012477d7d57067ee9f82405ddb7e05522aab41c47bd6f7c55d144e509179af9a62cb04e91cc1981b7541482a430dca19c9ec3b5fcca0
2879	4	2025-04-03 23:47:00	t	f	\\xc30d04070302244ed0473d5ca5ea61d2370199e2b9510687ff16f8503a137e59022a9da5270ef1197a490da37ef2f5bc9d0e6a4b8765a5ed4c6868cbe0f0ae4ac3256fa633a9e8d4
2880	3	2025-04-03 23:48:00	t	f	\\xc30d040703025a4a00c439b4f2da6dd23501e4b9e2e9727a0fbf4066c8a6b92df921e494394d6cfdd3b79ce9655157113d17273b0d2359560a3af3b74032301705fce39c68d2
2881	4	2025-04-03 23:48:00	t	f	\\xc30d04070302ecc042db5effccdc7cd23701662da9389b2576a0c6909ad48e313bf352c636aa6a27a4c4dd8dcdf22a35ef7aa516bbbee96b791040a1b4d60f0644c0ca5d54fb9dd9
2882	3	2025-04-03 23:49:00	t	f	\\xc30d04070302aa00c12737e3546b7dd235014edf166af1085aa1843fd8fb381b20eb16834c71abaeb70bf57b0400334369ca87cb31081f99c209823a35ce2144ed54bfcc0f91
2883	4	2025-04-03 23:49:00	t	f	\\xc30d04070302d9742d0fb27c706b7cd237019a7b8824603ec28826f3641f3c24595fe8fceb87780637ac23a0998b75a3850472c6b142da24b15618e3710c40f46e1bd2f49fbce39d
2884	3	2025-04-03 23:50:00	t	f	\\xc30d04070302ba9456bae0af2bde7dd236011a676fa8d1db7841db04ccb3f49bfe2e6d35888e95fac89fe3147f8fc2c811da463d4017665abbfae937b0f6a8faec8dc76bba260f
2885	4	2025-04-03 23:50:00	t	f	\\xc30d04070302a36e9b889a4222e168d2370199ca8488b1afbea51a013f74caefd77e0c686813209f815589fc271c1dab6e7b14ee8db6f6f00382591564bc22aea3bbd877de8cd789
2886	3	2025-04-03 23:51:00	t	f	\\xc30d04070302fd1a118fb7545ead70d23501d940d4fdb35f01d1f625f0e5d6bdfd90f2fcd1b701455dc887329d2d597628908b0cb5a9e2cce503214d4616937ec1773dd47306
2887	4	2025-04-03 23:51:00	t	f	\\xc30d04070302381537646b3ce0297dd23601722562653a25bd8392e012262132ebb0361e3633ad87a56b3706d37b8ab8f718872e628dd8eb875a33f71511dc7daf95551d799b04
2888	3	2025-04-03 23:52:00	t	f	\\xc30d040703028b76cfd8cee5390c78d23501a70228d988b4c479ebcedb2d94b243ed879c038635424fd3f641cbacf19291ab2eec1de0c25ea2b8730e80e93c52de1df0643742
2889	4	2025-04-03 23:52:00	t	f	\\xc30d040703026feacad7038164407ed23601796bd07851500c4daf0d0be509ad6be52dc92756ab48d83440b34307cf950b94226b90e489630796516e0778f83c1cdf57b6bb258b
2890	3	2025-04-03 23:53:00	t	f	\\xc30d0407030217999f0ca103a4a27ad2360109938efaee68db74433f12bc75b4903710fa59b3b42ecfcbb1bc650051ed3257ac02322c26abbcbd53c80312a65a6e1b1ef5ebb394
2891	4	2025-04-03 23:53:00	t	f	\\xc30d04070302d2c5ea6aa0c9230163d237014475a508cff2568ec7620f6bd15bb67760594df6183a48a1d8fabd8fb940a6b6d15d7d73eeb599f73128f74b13b534c8b7abde5c9dc9
2892	3	2025-04-03 23:54:00	t	f	\\xc30d040703022269ee68b0fe239a79d23601334b604abbbb73173912f5e9230d5ed884c911ed4f6f128d6305a53da9232527bb91df10596873035c8c8a9a7991d633416bbe1994
2893	4	2025-04-03 23:54:00	t	f	\\xc30d04070302438fa4a3e2be510f69d23701c50ee37067cd0844eca0e33d17865820ed1a374ce9514892b77cc2822178cfac059ee19cc9e6cbfaee0fcc9c47ad5281e923adb11e9b
2894	3	2025-04-03 23:55:00	t	f	\\xc30d040703021178d95d5cec314b65d23601f3978cf3a9ea074dc35c8a3b03f40dba6d00f7ddad3408471b86c1765023feb70099dc2e3be5ab10cc00ae7e3cdfdbc5706f3c8ba1
2895	4	2025-04-03 23:55:00	t	f	\\xc30d0407030247a9ea0fbcfa6b0561d23701c3ed2f6a967e5de8fc3404149b8ed81f6526a726d6f74e1d34739314b13367647691736b2eae0668606d3e0e72afa3eda32ef2f44316
2896	3	2025-04-03 23:56:00	t	f	\\xc30d040703023eca82a8210ee88c68d23601b87752faeaef8cfb9cbbbb0b3d84442bc4fe71e87d93c0b6b7afdb2578f84c3b22abcbd60ca345083ec86254a8c6b5df7437c3a22d
2897	4	2025-04-03 23:56:00	t	f	\\xc30d04070302c9c38b0f8bbcf62b6ed2370149e00157033251ef0f676b546d97be8d00f0d1dfb0d30ba5c85beb9c70355ee9b70109acec9f6720ee8fed75fca4e6d0e9559bd71490
2898	3	2025-04-03 23:57:00	t	f	\\xc30d040703024805cb8b0119945a6dd23601c3675b3138631e211d8bdf144d4e53ddf67b42883d5ff55345740e2bd99305b76980f505e43911ad8269b056c6afe8ccd9da334eb7
2899	4	2025-04-03 23:57:00	t	f	\\xc30d04070302f781b3e183fbc28477d23701bf35a8b4fc146c85d6b50f8321fb21aea284f6b44b683c6c7495f1b50fa212aed0c19a6be2db16fa41557ca985ced83fcf38f54ec472
2900	3	2025-04-03 23:58:00	t	f	\\xc30d040703025a8bb045a414892363d2360183dc9a203bf416621b101070da30103ffd1a0630fa0577c77aa19c0003f5fc7b69b04526e6ba10dcd593ca192d432092bb5a803536
2901	4	2025-04-03 23:58:00	t	f	\\xc30d0407030262b24fbdf1fab37163d23701df484c682cd21c4a0807b89f137b100ff0b09951fbe02f147b8f6ef8f12a33ca715c8b805bfd2eac36607a5d30ea739214cbff37b8f1
2902	3	2025-04-03 23:59:00	t	f	\\xc30d040703026a3446c1b96213e27cd23601ccc62cce1cd9bb657f3a31c2cf3013984cb8c0a35ba064f2c2620c85a853092905b1e3187323dfca0b26e773e2698a33a53995b17b
2903	4	2025-04-03 23:59:00	t	f	\\xc30d0407030268b47bf227280c066fd236017b2762d2182d011ea86d5d3db7a7bb13308fa46ba2c3fa27989e5c53061da1f7781319e2931cec73538701c4676003975189026896
\.


--
-- TOC entry 5027 (class 0 OID 37522)
-- Dependencies: 226
-- Data for Name: ChannelDataFeed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelDataFeed" ("Id", "ChannelDataId", "ChannelId", "ChannelName", "ChannelValue", "Units", "ChannelDataLogTime", "PcbLimit", "StationId", "Active", "Minimum", "Maximum", "Average") FROM stdin;
21	22	1	PM10	41.34	mg/nm3	2020-01-01 00:00:00	100	1	t	41.34	41.34	41.34
22	23	2	PM2.5	46.17	mg/nm3	2020-01-01 00:00:00	60	1	t	46.17	46.17	46.17
2901	2902	3	Wind Speed	12.75	km/h	2025-04-03 23:59:00	20	2	t	4.99	24.41	13.13
2902	2903	4	Wind Direction	64.60	DegC	2025-04-03 23:59:00	360	2	t	5.80	355.70	175.85
\.


--
-- TOC entry 5030 (class 0 OID 37527)
-- Dependencies: 229
-- Data for Name: ChannelType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelType" ("Id", "ChannelTypeValue", "Active") FROM stdin;
1	SCALAR	t
2	VECTOR	t
3	TOTAL	t
4	FLOW	t
5	FLOWTOTALIZER	t
\.


--
-- TOC entry 5032 (class 0 OID 37532)
-- Dependencies: 231
-- Data for Name: Company; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Company" ("Id", "ShortName", "LegalName", "Address", "PinCode", "Logo", "Active", "Country", "State", "District", "CreatedOn") FROM stdin;
1	NK Square Solutions	NK Square Solutionss	somewhere i dont know	500075	\N	t	INDIA	Telangana	Hyderabad	2025-04-04 11:42:08.303568
\.


--
-- TOC entry 5034 (class 0 OID 37540)
-- Dependencies: 233
-- Data for Name: ConfigSetting; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ConfigSetting" ("Id", "GroupName", "ContentName", "ContentValue", "Active") FROM stdin;
51	NotificationGenerator	Subscription_cbd6ac03-a8b5-41b9-a704-104b6e1c22a0	{"Id":"cbd6ac03-a8b5-41b9-a704-104b6e1c22a0","ChannelId":4,"Conditions":[{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0},{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0},{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}]}	t
52	NotificationGenerator	Subscription_fa0af549-ae7c-4804-95fd-67ca4fd59bf6	{"Id":"fa0af549-ae7c-4804-95fd-67ca4fd59bf6","ChannelId":5,"Conditions":[{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0},{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0},{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}]}	t
53	NotificationGenerator	Preference	GroupAll	t
45	NotificationGenerator	Condition_039afa38-0e7a-4317-81f6-89e739a5bed9	{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0}	t
46	NotificationGenerator	Condition_3f32e537-2f22-4af4-978a-c41712480c0e	{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0}	t
47	NotificationGenerator	Condition_da0db8c3-9551-470d-9aa6-bfd2a010ff5c	{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}	t
48	NotificationGenerator	Subscription_b7507096-6dd9-4334-a640-566d82780c60	{"Id":"b7507096-6dd9-4334-a640-566d82780c60","ChannelId":1,"Conditions":[{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0},{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0},{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}]}	t
49	NotificationGenerator	Subscription_47912701-2fd4-48f9-8693-2e3bb34710de	{"Id":"47912701-2fd4-48f9-8693-2e3bb34710de","ChannelId":2,"Conditions":[{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0},{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0},{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}]}	t
50	NotificationGenerator	Subscription_97b933e7-f460-4804-8e25-8ff704dd8be8	{"Id":"97b933e7-f460-4804-8e25-8ff704dd8be8","ChannelId":3,"Conditions":[{"Id":"039afa38-0e7a-4317-81f6-89e739a5bed9","ConditionName":"Offline","ConditionType":1,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":30.0},{"Id":"3f32e537-2f22-4af4-978a-c41712480c0e","ConditionName":"Exceeded","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":0,"Threshold":30.0},{"Id":"da0db8c3-9551-470d-9aa6-bfd2a010ff5c","ConditionName":"Decreased","ConditionType":0,"Cooldown":60,"Duration":1,"Operator":1,"Threshold":10.0}]}	t
\.


--
-- TOC entry 5035 (class 0 OID 37546)
-- Dependencies: 234
-- Data for Name: KeyGenerator; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."KeyGenerator" ("Id", "KeyType", "KeyValue", "LastUpdatedOn") FROM stdin;
\.


--
-- TOC entry 5037 (class 0 OID 37552)
-- Dependencies: 236
-- Data for Name: License; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."License" ("LicenseType", "LicenseKey", "Active") FROM stdin;
WatchWare	828c52fa-cced-46e7-877b-1f4226119b3b	t
\.


--
-- TOC entry 5038 (class 0 OID 37558)
-- Dependencies: 237
-- Data for Name: MonitoringType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."MonitoringType" ("Id", "MonitoringTypeName", "Active") FROM stdin;
1	STACK	t
2	AMBIENT	t
3	WATER	t
\.


--
-- TOC entry 5054 (class 0 OID 37972)
-- Dependencies: 253
-- Data for Name: NotificationHistory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."NotificationHistory" ("Id", "ChannelName", "RaisedTime", "Message", "MetaData", "IsRead", "ChannelId", "ConditionId", "EmailSentTime", "StationId", "StationName", "MobileSentTime", "SentEmailAddresses", "SentMobileAddresses", "ConditionType") FROM stdin;
\.


--
-- TOC entry 5039 (class 0 OID 37562)
-- Dependencies: 238
-- Data for Name: Oxide; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Oxide" ("Id", "OxideName", "Limit", "Active") FROM stdin;
1	PM10	100	t
2	PM2.5	60	t
3	Wind Speed	20	t
4	Wind Direction	360	t
5	SO2	60	t
\.


--
-- TOC entry 5041 (class 0 OID 37567)
-- Dependencies: 240
-- Data for Name: Roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Roles" ("Id", "Name", "Description", "Active", "CreatedOn") FROM stdin;
1	Admin	Administrator	t	2025-04-04 11:41:23.549789
2	Customer	Customer	t	2025-04-04 11:41:23.553642
\.


--
-- TOC entry 5042 (class 0 OID 37572)
-- Dependencies: 241
-- Data for Name: ScalingFactor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ScalingFactor" ("Id", "MinInput", "MaxInput", "MinOutput", "MaxOutput", "Active") FROM stdin;
\.


--
-- TOC entry 5043 (class 0 OID 37576)
-- Dependencies: 242
-- Data for Name: ServiceLogs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ServiceLogs" ("LogId", "LogType", "Message", "SoftwareType", "Class", "LogTimestamp") FROM stdin;
2816	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.61199
2817	INFO	2 [Offline,Exceeded] Conditions met for Channel : PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.613645
2818	INFO	Processing feed with channel name : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.615193
2819	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.616922
2820	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.618883
2821	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.620262
2822	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.622245
2823	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.623996
2824	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.626061
2825	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.628356
2826	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.630304
2827	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.631879
2828	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.633379
2829	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.634823
2830	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.636632
2831	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.63833
2832	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.64077
2833	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.642662
2834	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.644267
2835	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.645919
2836	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.647299
2837	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.648998
2838	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.650972
2839	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.652548
2840	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.654326
2841	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.656819
2842	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.658932
2843	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.661044
2844	INFO	1 [Offline] Conditions met for Channel : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.663016
2845	INFO	Processing feed with channel name : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.665062
2846	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.667074
2847	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.670098
2848	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.672044
2849	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.674805
2850	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.676996
2851	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.679262
2852	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.681184
2853	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.682763
2854	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.68514
2855	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.687296
2856	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.688734
2857	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.691326
2858	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.692829
2859	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.694843
2860	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.696561
2861	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.698423
2862	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.700253
2863	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.702253
2864	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.704029
2865	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.70579
2866	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.70758
2867	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.709364
2868	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.711159
2869	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.713022
2870	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.714409
2871	INFO	2 [Offline,Exceeded] Conditions met for Channel : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.716186
2872	INFO	Starting notification processing. Total channels with met conditions: 4	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.717696
2873	INFO	Generating notification records for met conditions...	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:01.719399
2874	INFO	Processing notifications for channel: PM10 (ID: 1)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:03.79194
2875	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:03.93252
2876	INFO	Created notification record with ID: 71.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.246299
2877	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.247648
2878	INFO	Created notification record with ID: 72.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.251347
2879	INFO	Finished processing channel: PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.25273
2880	INFO	Processing notifications for channel: PM2.5 (ID: 2)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.254407
2881	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.25678
2882	INFO	Created notification record with ID: 73.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.261944
2883	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.263273
2884	INFO	Created notification record with ID: 74.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.268282
2885	INFO	Finished processing channel: PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.269483
2886	INFO	Processing notifications for channel: Wind Speed (ID: 3)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.270873
2887	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.272321
2888	INFO	Created notification record with ID: 75.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.275874
2889	INFO	Finished processing channel: Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.277163
2890	INFO	Processing notifications for channel: Wind Direction (ID: 4)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.278424
2891	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.279765
2892	INFO	Created notification record with ID: 76.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.282411
2893	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.283751
2894	INFO	Created notification record with ID: 77.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.286386
2895	INFO	Finished processing channel: Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 11:58:04.287705
2896	INFO	Config settings for NotificationGenerator count : 9	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:23.681453
2897	INFO	Service started	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.506745
2898	INFO	Service Interval not found, Using default 60seconds	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.512487
2899	INFO	Service Interval : 60000 ms	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.517431
2900	INFO	Initialized timer	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.521246
2901	INFO	Timer elapsed	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.525532
2902	INFO	NotificationProcessor Started	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:08:26.531595
2903	INFO	Loading channels datafeed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.533929
2904	INFO	4 Feeds found with Channel Name : PM10,PM2.5,Wind Speed,Wind Direction.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.55257
2905	INFO	Deserializing subscription : Subscription_cbd6ac03-a8b5-41b9-a704-104b6e1c22a0.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.592597
2906	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.756164
2907	INFO	Deserializing subscription : Subscription_fa0af549-ae7c-4804-95fd-67ca4fd59bf6.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.757494
2908	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.758832
2909	INFO	Deserializing subscription : Subscription_b7507096-6dd9-4334-a640-566d82780c60.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.760373
2910	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.76166
2911	INFO	Deserializing subscription : Subscription_47912701-2fd4-48f9-8693-2e3bb34710de.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.762844
2912	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.764123
2913	INFO	Deserializing subscription : Subscription_97b933e7-f460-4804-8e25-8ff704dd8be8.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.76538
2914	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.766747
2915	INFO	Processing feed with channel name : PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.768111
2916	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.769588
2917	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.778027
2918	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.779205
2919	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.784815
2920	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.787111
2921	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.78847
2922	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.789752
2923	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.791296
2924	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.792657
2925	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.794143
2926	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.795464
2927	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.797309
2928	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.798609
2929	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.800277
2930	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.801974
2931	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.803461
2932	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.804883
2933	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.806246
2934	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.807672
2935	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.809759
2936	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.811304
2937	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.812711
2938	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.814265
2939	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.815841
2940	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.817416
2941	INFO	2 [Offline,Exceeded] Conditions met for Channel : PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.819093
2942	INFO	Processing feed with channel name : PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.820403
2943	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.821805
2944	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.823551
2945	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.824852
2946	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.826821
2947	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.828212
2948	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.829736
2949	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.831306
2950	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.832727
2951	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.834091
2952	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.835438
2953	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.836828
2954	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.83856
2955	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.83992
2956	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.84126
2957	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.842847
2958	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.844366
2959	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.845911
2960	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.847256
2961	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.848785
2962	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.850869
2963	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.852459
2964	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.853845
2965	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.855242
2966	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.856657
2967	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.858094
2968	INFO	2 [Offline,Exceeded] Conditions met for Channel : PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.859646
2969	INFO	Processing feed with channel name : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.861097
2970	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.862406
2971	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.864148
2972	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.865539
2973	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.867283
2974	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.868628
2975	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.870009
2976	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.871398
2977	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.872768
2978	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.874131
2979	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.875592
2980	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.877239
2981	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.879211
2982	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.880509
2983	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.881854
2984	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.88313
2985	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.884442
2986	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.88579
2987	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.887061
2988	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.888464
2989	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.890195
2990	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.891507
2991	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.892973
2992	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.894984
2993	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.896744
2994	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.898272
2995	INFO	1 [Offline] Conditions met for Channel : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.899583
2996	INFO	Processing feed with channel name : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.900897
2997	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.902229
2998	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.903925
2999	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.905234
3000	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.906931
3001	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.908264
3002	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.910487
3003	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.912623
3004	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.914428
3005	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.915872
3006	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.917178
3007	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.918516
3008	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.920255
3009	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.922099
3010	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.923453
3011	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.924853
3012	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.927254
3013	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.929109
3014	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.930615
3015	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.932634
3016	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.935444
3017	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.937305
3018	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.938937
3019	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.940557
3020	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.942706
3021	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.945414
3022	INFO	2 [Offline,Exceeded] Conditions met for Channel : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.94709
3023	INFO	Starting notification processing. Total channels with met conditions: 4	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.949367
3024	INFO	Generating notification records for met conditions...	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:26.950934
3025	INFO	Processing notifications for channel: PM10 (ID: 1)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.83752
3026	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.838974
3027	INFO	Created notification record with ID: 78.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.883891
3028	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.885348
3029	INFO	Created notification record with ID: 79.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.888678
3030	INFO	Finished processing channel: PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.890105
3031	INFO	Processing notifications for channel: PM2.5 (ID: 2)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.891466
3032	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.892889
3033	INFO	Created notification record with ID: 80.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.896002
3034	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.897384
3035	INFO	Created notification record with ID: 81.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.900602
3036	INFO	Finished processing channel: PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.902021
3037	INFO	Processing notifications for channel: Wind Speed (ID: 3)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.903427
3038	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.904879
3039	INFO	Created notification record with ID: 82.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.90809
3040	INFO	Finished processing channel: Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.909524
3041	INFO	Processing notifications for channel: Wind Direction (ID: 4)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.9109
3042	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.912303
3043	INFO	Created notification record with ID: 83.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.91566
3044	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.917104
3045	INFO	Created notification record with ID: 84.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.920165
3046	INFO	Finished processing channel: Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:08:34.921549
3047	INFO	Config settings for NotificationGenerator count : 9	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:53.491613
3048	INFO	Service started	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.3536
3049	INFO	Service Interval not found, Using default 60seconds	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.355744
3050	INFO	Service Interval : 60000 ms	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.357281
3051	INFO	Initialized timer	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.358713
3052	INFO	Timer elapsed	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.360357
3053	INFO	NotificationProcessor Started	NKSS_NotificationProcessor	NKSS_NotificationProcessor.NKSS_NotificationProcessor	2025-04-11 12:09:55.361753
3054	INFO	Loading channels datafeed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.36687
3055	INFO	4 Feeds found with Channel Name : PM10,PM2.5,Wind Speed,Wind Direction.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.383674
3056	INFO	Deserializing subscription : Subscription_cbd6ac03-a8b5-41b9-a704-104b6e1c22a0.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.396475
3057	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.507558
3058	INFO	Deserializing subscription : Subscription_fa0af549-ae7c-4804-95fd-67ca4fd59bf6.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.509023
3059	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.510668
3060	INFO	Deserializing subscription : Subscription_b7507096-6dd9-4334-a640-566d82780c60.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.512023
3061	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.513432
3062	INFO	Deserializing subscription : Subscription_47912701-2fd4-48f9-8693-2e3bb34710de.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.5148
3063	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.516194
3064	INFO	Deserializing subscription : Subscription_97b933e7-f460-4804-8e25-8ff704dd8be8.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.517577
3065	INFO	Deserializing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.519005
3066	INFO	Processing feed with channel name : PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.520502
3067	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.522249
3068	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.530852
3069	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.532406
3070	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.537119
3071	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.539307
3072	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.540707
3073	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.542236
3074	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.543973
3075	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.54566
3076	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.547003
3077	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.548327
3078	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.550142
3079	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.551518
3080	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.552948
3081	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.554664
3082	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.556198
3083	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.557617
3084	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.558976
3085	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.560339
3086	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.562152
3087	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.563546
3088	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.565012
3089	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.566614
3090	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.568035
3091	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.569431
3092	INFO	2 [Offline,Exceeded] Conditions met for Channel : PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.571449
3093	INFO	Processing feed with channel name : PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.573541
3094	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.575402
3095	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.577764
3096	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.5796
3097	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.581464
3098	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.582987
3099	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.584334
3100	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.585708
3101	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.587525
3102	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.589292
3103	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.591104
3104	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.592518
3105	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.594177
3106	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.595418
3107	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.59664
3108	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.597909
3109	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.599144
3110	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.600421
3111	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.601789
3112	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.603284
3113	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.605647
3114	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.606874
3115	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.608098
3116	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.609376
3117	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.61066
3118	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.611943
3119	INFO	2 [Offline,Exceeded] Conditions met for Channel : PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.61346
3120	INFO	Processing feed with channel name : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.61477
3121	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.616337
3122	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.618096
3123	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.619305
3124	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.620903
3125	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.622093
3126	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.623346
3127	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.624637
3128	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.625894
3129	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.627584
3130	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.629483
3131	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.631087
3132	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.633022
3133	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.634385
3134	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.636102
3135	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.637518
3136	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.639421
3137	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.640846
3138	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.643329
3139	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.64491
3140	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.646929
3141	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.648816
3142	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.65086
3143	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.652411
3144	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.653871
3145	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.655242
3146	INFO	1 [Offline] Conditions met for Channel : Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.656607
3147	INFO	Processing feed with channel name : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.657997
3148	INFO	Subscription found with conditions : Offline,Exceeded,Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.659355
3149	INFO	Processing condition : Offline	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.661135
3150	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.662506
3151	INFO	No previous notification found for condition 'Offline'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.664402
3152	INFO	Evaluating condition type : LogTime	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.665792
3153	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.667139
3154	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.668493
3155	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.669844
3156	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.671213
3157	INFO	Processing condition : Exceeded	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.672579
3158	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.673892
3159	INFO	No previous notification found for condition 'Exceeded'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.67576
3160	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.677147
3161	INFO	Evaluating operator : GreaterThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.678667
3162	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.680073
3163	WARN	Condition met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.681615
3164	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.682957
3165	INFO	Processing condition : Decreased	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.684374
3166	INFO	Fetching last recent notification.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.685958
3167	INFO	No previous notification found for condition 'Decreased'. Will evaluate condition.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.687684
3168	INFO	Evaluating condition type : Value	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.689028
3169	INFO	Evaluating operator : LessThan	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.690718
3170	INFO	Condition Evaluated.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.69219
3171	INFO	Condition not met.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.693602
3172	INFO	Processing done.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.694816
3173	INFO	2 [Offline,Exceeded] Conditions met for Channel : Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.696555
3174	INFO	Starting notification processing. Total channels with met conditions: 4	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.698357
3175	INFO	Generating notification records for met conditions...	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:55.699839
3176	INFO	Processing notifications for channel: PM10 (ID: 1)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.69183
3177	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.693634
3178	INFO	Created notification record with ID: 85.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.742094
3179	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.743452
3180	INFO	Created notification record with ID: 86.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.746736
3181	INFO	Finished processing channel: PM10	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.749001
3182	INFO	Processing notifications for channel: PM2.5 (ID: 2)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.750685
3183	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.752053
3184	INFO	Created notification record with ID: 87.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.754779
3185	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.756007
3186	INFO	Created notification record with ID: 88.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.759175
3187	INFO	Finished processing channel: PM2.5	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.760393
3188	INFO	Processing notifications for channel: Wind Speed (ID: 3)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.761835
3189	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.763429
3190	INFO	Created notification record with ID: 89.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.766453
3191	INFO	Finished processing channel: Wind Speed	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.767733
3192	INFO	Processing notifications for channel: Wind Direction (ID: 4)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.76898
3193	INFO	Preparing notification for condition: Offline (ID: 039afa38-0e7a-4317-81f6-89e739a5bed9)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.770228
3194	INFO	Created notification record with ID: 90.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.77295
3195	INFO	Preparing notification for condition: Exceeded (ID: 3f32e537-2f22-4af4-978a-c41712480c0e)	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.774225
3196	INFO	Created notification record with ID: 91.	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.776846
3197	INFO	Finished processing channel: Wind Direction	NKSS_NotificationProcessor	Business.NotificationGenerator	2025-04-11 12:09:56.778703
\.


--
-- TOC entry 5044 (class 0 OID 37583)
-- Dependencies: 243
-- Data for Name: Station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Station" ("Id", "CompanyId", "Name", "IsSpcb", "IsCpcb", "Active", "MonitoringTypeId", "CreatedOn") FROM stdin;
1	1	AQMS	f	f	t	1	2025-04-04 11:42:16.759729
2	1	Weather	f	f	t	2	2025-04-04 15:41:22.107578
\.


--
-- TOC entry 5046 (class 0 OID 37591)
-- Dependencies: 245
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" ("Id", "Username", "Password", "PhoneNumber", "Email", "Active", "CreatedOn", "LastLoggedIn", "RoleId", "IsEmailVerified", "IsPhoneVerified") FROM stdin;
371951cb-d3e8-40f5-bd46-921d7d01323e	Admin	SLexxCagoj6TbdPEjOBhd2m/Z2KoCl0s6Q6iQcOB/9Y=	9959489767	lorenbhanu@gmail.com	t	2025-04-04 11:41:23.620066	2025-04-11 11:59:19.581834	1	f	f
\.


--
-- TOC entry 5077 (class 0 OID 0)
-- Dependencies: 223
-- Name: Analyzer_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Analyzer_Id_seq"', 1, true);


--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 227
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelDataFeed_Id_seq"', 2902, true);


--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 228
-- Name: ChannelData_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelData_Id_seq"', 2903, true);


--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 230
-- Name: Channel_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Channel_Id_seq"', 5, true);


--
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 232
-- Name: Company_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Company_Id_seq"', 1, true);


--
-- TOC entry 5082 (class 0 OID 0)
-- Dependencies: 235
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."KeyGenerator_Id_seq"', 1, false);


--
-- TOC entry 5083 (class 0 OID 0)
-- Dependencies: 239
-- Name: Oxide_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Oxide_Id_seq"', 5, true);


--
-- TOC entry 5084 (class 0 OID 0)
-- Dependencies: 244
-- Name: Station_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Station_Id_seq"', 2, true);


--
-- TOC entry 5085 (class 0 OID 0)
-- Dependencies: 246
-- Name: channeltype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.channeltype_id_seq', 5, true);


--
-- TOC entry 5086 (class 0 OID 0)
-- Dependencies: 247
-- Name: configsettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configsettings_id_seq', 53, true);


--
-- TOC entry 5087 (class 0 OID 0)
-- Dependencies: 248
-- Name: monitoringtype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.monitoringtype_id_seq', 3, true);


--
-- TOC entry 5088 (class 0 OID 0)
-- Dependencies: 252
-- Name: notificationhistory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificationhistory_id_seq', 91, true);


--
-- TOC entry 5089 (class 0 OID 0)
-- Dependencies: 249
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 2, true);


--
-- TOC entry 5090 (class 0 OID 0)
-- Dependencies: 250
-- Name: scalingfactor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scalingfactor_id_seq', 1, false);


--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 251
-- Name: servicelogs_logid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.servicelogs_logid_seq', 3197, true);


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
-- TOC entry 4877 (class 2606 OID 37993)
-- Name: NotificationHistory FK_NotificaitonHistory_Station; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationHistory"
    ADD CONSTRAINT "FK_NotificaitonHistory_Station" FOREIGN KEY ("StationId") REFERENCES public."Station"("Id") NOT VALID;


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


-- Completed on 2025-04-11 13:21:05

--
-- PostgreSQL database dump complete
--


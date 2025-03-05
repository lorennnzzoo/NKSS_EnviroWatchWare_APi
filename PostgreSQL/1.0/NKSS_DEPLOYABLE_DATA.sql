--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-03-04 17:24:50

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
-- TOC entry 4968 (class 0 OID 37151)
-- Dependencies: 222
-- Data for Name: Analyzer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Analyzer" ("Id", "ProtocolType", "Command", "ComPort", "BaudRate", "Parity", "DataBits", "StopBits", "IpAddress", "Port", "Manufacturer", "Model", "Active", "CommunicationType") FROM stdin;
\.


--
-- TOC entry 4975 (class 0 OID 37176)
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
-- TOC entry 4977 (class 0 OID 37181)
-- Dependencies: 231
-- Data for Name: Company; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Company" ("Id", "ShortName", "LegalName", "Address", "PinCode", "Logo", "Active", "Country", "State", "District", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4983 (class 0 OID 37207)
-- Dependencies: 237
-- Data for Name: MonitoringType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."MonitoringType" ("Id", "MonitoringTypeName", "Active") FROM stdin;
1	STACK	t
2	WATER	t
3	AMBIENT	t
\.


--
-- TOC entry 4984 (class 0 OID 37211)
-- Dependencies: 238
-- Data for Name: Oxide; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Oxide" ("Id", "OxideName", "Limit", "Active") FROM stdin;
\.


--
-- TOC entry 4987 (class 0 OID 37221)
-- Dependencies: 241
-- Data for Name: ScalingFactor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ScalingFactor" ("Id", "MinInput", "MaxInput", "MinOutput", "MaxOutput", "Active") FROM stdin;
\.


--
-- TOC entry 4989 (class 0 OID 37232)
-- Dependencies: 243
-- Data for Name: Station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Station" ("Id", "CompanyId", "Name", "IsSpcb", "IsCpcb", "Active", "MonitoringTypeId", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4970 (class 0 OID 37158)
-- Dependencies: 224
-- Data for Name: Channel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Channel" ("Id", "StationId", "Name", "LoggingUnits", "ProtocolId", "Active", "ValuePosition", "MaximumRange", "MinimumRange", "Threshold", "CpcbChannelName", "SpcbChannelName", "OxideId", "Priority", "IsSpcb", "IsCpcb", "ScalingFactorId", "OutputType", "ChannelTypeId", "ConversionFactor", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4971 (class 0 OID 37168)
-- Dependencies: 225
-- Data for Name: ChannelData; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelData" ("Id", "ChannelId", "ChannelDataLogTime", "Active", "Processed", "ChannelValue") FROM stdin;
\.


--
-- TOC entry 4972 (class 0 OID 37171)
-- Dependencies: 226
-- Data for Name: ChannelDataFeed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelDataFeed" ("Id", "ChannelDataId", "ChannelId", "ChannelName", "ChannelValue", "Units", "ChannelDataLogTime", "PcbLimit", "StationId", "Active", "Minimum", "Maximum", "Average") FROM stdin;
\.


--
-- TOC entry 4979 (class 0 OID 37189)
-- Dependencies: 233
-- Data for Name: ConfigSetting; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ConfigSetting" ("Id", "GroupName", "ContentName", "ContentValue", "Active") FROM stdin;
\.


--
-- TOC entry 4980 (class 0 OID 37195)
-- Dependencies: 234
-- Data for Name: KeyGenerator; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."KeyGenerator" ("Id", "KeyType", "KeyValue", "LastUpdatedOn") FROM stdin;
\.


--
-- TOC entry 4982 (class 0 OID 37201)
-- Dependencies: 236
-- Data for Name: License; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."License" ("LicenseType", "LicenseKey", "Active") FROM stdin;
WatchWare	mZfKvv4xWpk/rCzwKfnmiZWRtIGkjqU6LFOwdyLaUp7KNeZfqdbpMrxYzteQAL7s	t
\.


--
-- TOC entry 4986 (class 0 OID 37216)
-- Dependencies: 240
-- Data for Name: Roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Roles" ("Id", "Name", "Description", "Active", "CreatedOn") FROM stdin;
1	Admin	Administrator	t	2025-03-04 16:40:14.967192
2	Customer	Customer	t	2025-03-04 16:40:14.967192
\.


--
-- TOC entry 4988 (class 0 OID 37225)
-- Dependencies: 242
-- Data for Name: ServiceLogs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ServiceLogs" ("LogId", "LogType", "Message", "SoftwareType", "Class", "LogTimestamp") FROM stdin;
\.


--
-- TOC entry 4991 (class 0 OID 37240)
-- Dependencies: 245
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" ("Id", "Username", "Password", "PhoneNumber", "Email", "Active", "CreatedOn", "LastLoggedIn", "RoleId") FROM stdin;
\.


--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 223
-- Name: Analyzer_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Analyzer_Id_seq"', 1, false);


--
-- TOC entry 5004 (class 0 OID 0)
-- Dependencies: 227
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelDataFeed_Id_seq"', 1, false);


--
-- TOC entry 5005 (class 0 OID 0)
-- Dependencies: 228
-- Name: ChannelData_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelData_Id_seq"', 1, false);


--
-- TOC entry 5006 (class 0 OID 0)
-- Dependencies: 230
-- Name: Channel_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Channel_Id_seq"', 1, false);


--
-- TOC entry 5007 (class 0 OID 0)
-- Dependencies: 232
-- Name: Company_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Company_Id_seq"', 1, false);


--
-- TOC entry 5008 (class 0 OID 0)
-- Dependencies: 235
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."KeyGenerator_Id_seq"', 1, false);


--
-- TOC entry 5009 (class 0 OID 0)
-- Dependencies: 239
-- Name: Oxide_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Oxide_Id_seq"', 1, false);


--
-- TOC entry 5010 (class 0 OID 0)
-- Dependencies: 244
-- Name: Station_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Station_Id_seq"', 1, false);


--
-- TOC entry 5011 (class 0 OID 0)
-- Dependencies: 246
-- Name: channeltype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.channeltype_id_seq', 5, true);


--
-- TOC entry 5012 (class 0 OID 0)
-- Dependencies: 247
-- Name: configsettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configsettings_id_seq', 1, false);


--
-- TOC entry 5013 (class 0 OID 0)
-- Dependencies: 248
-- Name: monitoringtype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.monitoringtype_id_seq', 3, true);


--
-- TOC entry 5014 (class 0 OID 0)
-- Dependencies: 249
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 2, true);


--
-- TOC entry 5015 (class 0 OID 0)
-- Dependencies: 250
-- Name: scalingfactor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scalingfactor_id_seq', 1, false);


--
-- TOC entry 5016 (class 0 OID 0)
-- Dependencies: 251
-- Name: servicelogs_logid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.servicelogs_logid_seq', 1, false);


-- Completed on 2025-03-04 17:24:50

--
-- PostgreSQL database dump complete
--


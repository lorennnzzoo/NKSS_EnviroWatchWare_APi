--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-02-18 15:31:38

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
-- TOC entry 4938 (class 0 OID 36003)
-- Dependencies: 218
-- Data for Name: Analyzer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Analyzer" ("Id", "ProtocolType", "Command", "ComPort", "BaudRate", "Parity", "DataBits", "StopBits", "IpAddress", "Port", "Manufacturer", "Model", "Active", "CommunicationType") FROM stdin;
\.


--
-- TOC entry 4945 (class 0 OID 36030)
-- Dependencies: 225
-- Data for Name: ChannelType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelType" ("Id", "ChannelTypeValue", "Active") FROM stdin;
7	SCALAR	t
8	VECTOR	t
9	TOTAL	t
10	FLOW	t
11	FLOWTOTALIZER	t
\.


--
-- TOC entry 4947 (class 0 OID 36035)
-- Dependencies: 227
-- Data for Name: Company; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Company" ("Id", "ShortName", "LegalName", "Address", "PinCode", "Logo", "Active", "Country", "State", "District", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4953 (class 0 OID 36061)
-- Dependencies: 233
-- Data for Name: MonitoringType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."MonitoringType" ("Id", "MonitoringTypeName", "Active") FROM stdin;
1	STACK	t
2	WATER	t
3	AMBIENT	t
\.


--
-- TOC entry 4954 (class 0 OID 36065)
-- Dependencies: 234
-- Data for Name: Oxide; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Oxide" ("Id", "OxideName", "Limit", "Active") FROM stdin;
\.


--
-- TOC entry 4957 (class 0 OID 36075)
-- Dependencies: 237
-- Data for Name: ScalingFactor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ScalingFactor" ("Id", "MinInput", "MaxInput", "MinOutput", "MaxOutput", "Active") FROM stdin;
\.


--
-- TOC entry 4958 (class 0 OID 36079)
-- Dependencies: 238
-- Data for Name: Station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Station" ("Id", "CompanyId", "Name", "IsSpcb", "IsCpcb", "Active", "MonitoringTypeId", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4940 (class 0 OID 36010)
-- Dependencies: 220
-- Data for Name: Channel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Channel" ("Id", "StationId", "Name", "LoggingUnits", "ProtocolId", "Active", "ValuePosition", "MaximumRange", "MinimumRange", "Threshold", "CpcbChannelName", "SpcbChannelName", "OxideId", "Priority", "IsSpcb", "IsCpcb", "ScalingFactorId", "OutputType", "ChannelTypeId", "ConversionFactor", "CreatedOn") FROM stdin;
\.


--
-- TOC entry 4941 (class 0 OID 36020)
-- Dependencies: 221
-- Data for Name: ChannelData; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelData" ("Id", "ChannelId", "ChannelValue", "ChannelDataLogTime", "Active", "Processed") FROM stdin;
\.


--
-- TOC entry 4942 (class 0 OID 36025)
-- Dependencies: 222
-- Data for Name: ChannelDataFeed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChannelDataFeed" ("Id", "ChannelDataId", "ChannelId", "ChannelName", "ChannelValue", "Units", "ChannelDataLogTime", "PcbLimit", "StationId", "Active", "Minimum", "Maximum", "Average") FROM stdin;
\.


--
-- TOC entry 4949 (class 0 OID 36043)
-- Dependencies: 229
-- Data for Name: ConfigSetting; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ConfigSetting" ("Id", "GroupName", "ContentName", "ContentValue", "Active") FROM stdin;
\.


--
-- TOC entry 4950 (class 0 OID 36049)
-- Dependencies: 230
-- Data for Name: KeyGenerator; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."KeyGenerator" ("Id", "KeyType", "KeyValue", "LastUpdatedOn") FROM stdin;
\.


--
-- TOC entry 4952 (class 0 OID 36055)
-- Dependencies: 232
-- Data for Name: License; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."License" ("LicenseType", "LicenseKey", "Active") FROM stdin;
\.


--
-- TOC entry 4956 (class 0 OID 36070)
-- Dependencies: 236
-- Data for Name: Roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Roles" ("Id", "Name", "Description", "Active", "CreatedOn") FROM stdin;
1	Admin	Administrator	t	2025-02-18 15:22:33.019858
2	Customer	Customer	t	2025-02-18 15:22:33.019858
\.


--
-- TOC entry 4960 (class 0 OID 36087)
-- Dependencies: 240
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" ("Id", "Username", "Password", "PhoneNumber", "Email", "Active", "CreatedOn", "LastLoggedIn", "RoleId") FROM stdin;
\.


--
-- TOC entry 4971 (class 0 OID 0)
-- Dependencies: 219
-- Name: Analyzer_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Analyzer_Id_seq"', 1, false);


--
-- TOC entry 4972 (class 0 OID 0)
-- Dependencies: 223
-- Name: ChannelDataFeed_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelDataFeed_Id_seq"', 1, false);


--
-- TOC entry 4973 (class 0 OID 0)
-- Dependencies: 224
-- Name: ChannelData_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ChannelData_Id_seq"', 1, false);


--
-- TOC entry 4974 (class 0 OID 0)
-- Dependencies: 226
-- Name: Channel_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Channel_Id_seq"', 1, false);


--
-- TOC entry 4975 (class 0 OID 0)
-- Dependencies: 228
-- Name: Company_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Company_Id_seq"', 1, false);


--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 231
-- Name: KeyGenerator_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."KeyGenerator_Id_seq"', 1, false);


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 235
-- Name: Oxide_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Oxide_Id_seq"', 1, false);


--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 239
-- Name: Station_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Station_Id_seq"', 1, false);


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 241
-- Name: channeltype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.channeltype_id_seq', 11, true);


--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 242
-- Name: configsettings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configsettings_id_seq', 1, false);


--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 243
-- Name: monitoringtype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.monitoringtype_id_seq', 3, true);


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 244
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 2, true);


--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 245
-- Name: scalingfactor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scalingfactor_id_seq', 1, false);


-- Completed on 2025-02-18 15:31:39

--
-- PostgreSQL database dump complete
--


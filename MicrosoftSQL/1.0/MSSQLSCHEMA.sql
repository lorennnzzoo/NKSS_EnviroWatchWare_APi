USE [MSSQLNKSS]
GO
/****** Object:  Table [dbo].[Analyzer]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Analyzer](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProtocolType] [varchar](100) NOT NULL,
	[Command] [varchar](500) NULL,
	[ComPort] [varchar](50) NULL,
	[BaudRate] [int] NULL,
	[Parity] [varchar](10) NULL,
	[DataBits] [int] NULL,
	[StopBits] [varchar](10) NULL,
	[IpAddress] [varchar](100) NULL,
	[Port] [int] NULL,
	[Manufacturer] [varchar](200) NULL,
	[Model] [varchar](200) NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
	[CommunicationType] [varchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Channel]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Channel](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[StationId] [int] NOT NULL,
	[Name] [varchar](200) NOT NULL,
	[LoggingUnits] [varchar](100) NOT NULL,
	[ProtocolId] [int] NOT NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
	[ValuePosition] [int] NULL,
	[MaximumRange] [decimal](10, 2) NULL,
	[MinimumRange] [decimal](10, 2) NULL,
	[Threshold] [decimal](10, 2) NULL,
	[CpcbChannelName] [varchar](200) NULL,
	[SpcbChannelName] [varchar](200) NULL,
	[OxideId] [int] NOT NULL,
	[Priority] [int] NULL,
	[IsSpcb] [bit] NOT NULL DEFAULT ((0)),
	[IsCpcb] [bit] NOT NULL DEFAULT ((0)),
	[ScalingFactorId] [int] NULL,
	[OutputType] [varchar](10) NOT NULL,
	[ChannelTypeId] [int] NOT NULL,
	[ConversionFactor] [decimal](10, 2) NOT NULL DEFAULT ((1.00)),
	[CreatedOn] [datetime] NOT NULL DEFAULT (getdate()),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ChannelData]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ChannelData](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ChannelId] [int] NOT NULL,
	[ChannelDataLogTime] [datetime] NOT NULL,
	[Active] [bit] NULL,
	[Processed] [bit] NULL,
	[ChannelValue] [decimal](10, 2) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ChannelDataFeed]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ChannelDataFeed](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ChannelDataId] [int] NOT NULL,
	[ChannelId] [int] NOT NULL,
	[ChannelName] [varchar](50) NULL,
	[ChannelValue] [varchar](50) NULL,
	[Units] [varchar](50) NULL,
	[ChannelDataLogTime] [datetime] NULL,
	[PcbLimit] [varchar](50) NULL,
	[StationId] [int] NULL,
	[Active] [bit] NULL,
	[Minimum] [decimal](10, 2) NULL,
	[Maximum] [decimal](10, 2) NULL,
	[Average] [decimal](10, 2) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ChannelType]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ChannelType](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ChannelTypeValue] [varchar](15) NOT NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Company]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Company](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ShortName] [varchar](100) NOT NULL,
	[LegalName] [varchar](200) NOT NULL,
	[Address] [varchar](500) NULL,
	[PinCode] [varchar](50) NOT NULL,
	[Logo] [varbinary](max) NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
	[Country] [varchar](50) NOT NULL,
	[State] [varchar](50) NOT NULL,
	[District] [varchar](50) NOT NULL,
	[CreatedOn] [datetime] NOT NULL DEFAULT (getdate()),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ConfigSetting]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ConfigSetting](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[GroupName] [varchar](100) NULL,
	[ContentName] [varchar](100) NULL,
	[ContentValue] [varchar](max) NULL,
	[Active] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[KeyGenerator]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[KeyGenerator](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[KeyType] [varchar](max) NOT NULL,
	[KeyValue] [int] NOT NULL,
	[LastUpdatedOn] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[License]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[License](
	[LicenseType] [varchar](255) NOT NULL,
	[LicenseKey] [varchar](max) NOT NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[LicenseType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MonitoringType]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MonitoringType](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[MonitoringTypeName] [varchar](256) NOT NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Oxide]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Oxide](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OxideName] [varchar](200) NOT NULL,
	[Limit] [varchar](100) NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Roles](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[Description] [varchar](255) NULL,
	[Active] [bit] NOT NULL DEFAULT ((1)),
	[CreatedOn] [datetime] NOT NULL DEFAULT (getdate()),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ScalingFactor]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ScalingFactor](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[MinInput] [float] NOT NULL,
	[MaxInput] [float] NOT NULL,
	[MinOutput] [float] NOT NULL,
	[MaxOutput] [float] NOT NULL,
	[Active] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ServiceLogs]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ServiceLogs](
	[LogId] [int] IDENTITY(1,1) NOT NULL,
	[LogType] [varchar](10) NULL,
	[Message] [varchar](max) NOT NULL,
	[SoftwareType] [varchar](50) NOT NULL,
	[Class] [varchar](100) NOT NULL,
	[LogTimestamp] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[LogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Station]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Station](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CompanyId] [int] NOT NULL,
	[Name] [varchar](200) NOT NULL,
	[IsSpcb] [bit] NOT NULL DEFAULT ((0)),
	[IsCpcb] [bit] NOT NULL DEFAULT ((0)),
	[Active] [bit] NOT NULL DEFAULT ((1)),
	[MonitoringTypeId] [int] NOT NULL,
	[CreatedOn] [datetime] NOT NULL DEFAULT (getdate()),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[User]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[User](
	[Id] [uniqueidentifier] NOT NULL DEFAULT (newid()),
	[Username] [varchar](255) NOT NULL,
	[Password] [varchar](255) NOT NULL,
	[PhoneNumber] [varchar](20) NULL,
	[Email] [varchar](255) NULL,
	[Active] [bit] NULL DEFAULT ((1)),
	[CreatedOn] [datetime] NOT NULL DEFAULT (getdate()),
	[LastLoggedIn] [datetime] NULL,
	[RoleId] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[ConfigSetting] ADD  DEFAULT ((1)) FOR [Active]
GO
ALTER TABLE [dbo].[ScalingFactor] ADD  DEFAULT ((1)) FOR [Active]
GO
ALTER TABLE [dbo].[ServiceLogs] ADD  DEFAULT (getdate()) FOR [LogTimestamp]
GO
ALTER TABLE [dbo].[Channel]  WITH CHECK ADD  CONSTRAINT [FK_Channel_Analyzer] FOREIGN KEY([ProtocolId])
REFERENCES [dbo].[Analyzer] ([Id])
GO
ALTER TABLE [dbo].[Channel] CHECK CONSTRAINT [FK_Channel_Analyzer]
GO
ALTER TABLE [dbo].[Channel]  WITH CHECK ADD  CONSTRAINT [FK_Channel_ChannelType] FOREIGN KEY([ChannelTypeId])
REFERENCES [dbo].[ChannelType] ([Id])
GO
ALTER TABLE [dbo].[Channel] CHECK CONSTRAINT [FK_Channel_ChannelType]
GO
ALTER TABLE [dbo].[Channel]  WITH CHECK ADD  CONSTRAINT [FK_Channel_Oxide] FOREIGN KEY([OxideId])
REFERENCES [dbo].[Oxide] ([Id])
GO
ALTER TABLE [dbo].[Channel] CHECK CONSTRAINT [FK_Channel_Oxide]
GO
ALTER TABLE [dbo].[Channel]  WITH CHECK ADD  CONSTRAINT [FK_Channel_ScalingFactor] FOREIGN KEY([ScalingFactorId])
REFERENCES [dbo].[ScalingFactor] ([Id])
GO
ALTER TABLE [dbo].[Channel] CHECK CONSTRAINT [FK_Channel_ScalingFactor]
GO
ALTER TABLE [dbo].[Channel]  WITH CHECK ADD  CONSTRAINT [FK_Channel_Station] FOREIGN KEY([StationId])
REFERENCES [dbo].[Station] ([Id])
GO
ALTER TABLE [dbo].[Channel] CHECK CONSTRAINT [FK_Channel_Station]
GO
ALTER TABLE [dbo].[ChannelData]  WITH CHECK ADD  CONSTRAINT [FK_ChannelData_Channel] FOREIGN KEY([ChannelId])
REFERENCES [dbo].[Channel] ([Id])
GO
ALTER TABLE [dbo].[ChannelData] CHECK CONSTRAINT [FK_ChannelData_Channel]
GO
ALTER TABLE [dbo].[ChannelDataFeed]  WITH CHECK ADD  CONSTRAINT [FK_ChannelDataFeed_Channel] FOREIGN KEY([ChannelId])
REFERENCES [dbo].[Channel] ([Id])
GO
ALTER TABLE [dbo].[ChannelDataFeed] CHECK CONSTRAINT [FK_ChannelDataFeed_Channel]
GO
ALTER TABLE [dbo].[ChannelDataFeed]  WITH CHECK ADD  CONSTRAINT [FK_ChannelDataFeed_ChannelData] FOREIGN KEY([ChannelDataId])
REFERENCES [dbo].[ChannelData] ([Id])
GO
ALTER TABLE [dbo].[ChannelDataFeed] CHECK CONSTRAINT [FK_ChannelDataFeed_ChannelData]
GO
ALTER TABLE [dbo].[Station]  WITH CHECK ADD  CONSTRAINT [FK_Station_Company] FOREIGN KEY([CompanyId])
REFERENCES [dbo].[Company] ([Id])
GO
ALTER TABLE [dbo].[Station] CHECK CONSTRAINT [FK_Station_Company]
GO
ALTER TABLE [dbo].[Station]  WITH CHECK ADD  CONSTRAINT [FK_Station_MonitoringType] FOREIGN KEY([MonitoringTypeId])
REFERENCES [dbo].[MonitoringType] ([Id])
GO
ALTER TABLE [dbo].[Station] CHECK CONSTRAINT [FK_Station_MonitoringType]
GO
ALTER TABLE [dbo].[User]  WITH CHECK ADD  CONSTRAINT [FK_User_Roles] FOREIGN KEY([RoleId])
REFERENCES [dbo].[Roles] ([Id])
GO
ALTER TABLE [dbo].[User] CHECK CONSTRAINT [FK_User_Roles]
GO
ALTER TABLE [dbo].[ServiceLogs]  WITH CHECK ADD  CONSTRAINT [CHK_ServiceLogs_LogType] CHECK  (([LogType]='ERROR' OR [LogType]='WARN' OR [LogType]='INFO'))
GO
ALTER TABLE [dbo].[ServiceLogs] CHECK CONSTRAINT [CHK_ServiceLogs_LogType]
GO
/****** Object:  StoredProcedure [dbo].[InsertOrUpdateChannelDataFeed]    Script Date: 3/12/2025 12:52:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[InsertOrUpdateChannelDataFeed]
    @p_channelid INT,
    @p_channelvalue NUMERIC(18,2),
    @p_datetime DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_channeldataid INT;
    DECLARE @v_channelname NVARCHAR(255);
    DECLARE @v_chnlunits NVARCHAR(50);
    DECLARE @v_stationid INT;
    DECLARE @v_active BIT;
    DECLARE @v_min NUMERIC(18,2);
    DECLARE @v_max NUMERIC(18,2);
    DECLARE @v_avg NUMERIC(18,2);
    DECLARE @v_pcbstandard NVARCHAR(50);
    DECLARE @v_outputtype NVARCHAR(50);
    DECLARE @v_scalingfactorid INT;
    DECLARE @v_mininput NUMERIC(18,2);
    DECLARE @v_maxinput NUMERIC(18,2);
    DECLARE @v_minoutput NUMERIC(18,2);
    DECLARE @v_maxoutput NUMERIC(18,2);
    DECLARE @v_conversionfactor NUMERIC(18,2);
    DECLARE @v_threshold NUMERIC(18,2);
    DECLARE @v_minrange NUMERIC(18,2);
    DECLARE @v_maxrange NUMERIC(18,2);
    DECLARE @v_finalvalue NUMERIC(18,2);

    -- Truncate datetime to the nearest minute
    SET @p_datetime = DATEADD(SECOND, -DATEPART(SECOND, @p_datetime), @p_datetime);

    -- Fetch channel details
    SELECT 
        @v_channelname = ch.Name,
        @v_chnlunits = ch.LoggingUnits,
        @v_stationid = ch.StationId,
        @v_active = ch.Active,
        @v_outputtype = ch.OutputType,
        @v_scalingfactorid = ch.ScalingFactorId,
        @v_conversionfactor = ch.ConversionFactor,
        @v_threshold = ch.Threshold,
        @v_minrange = ch.MinimumRange,
        @v_maxrange = ch.MaximumRange,
        @v_mininput = sf.MinInput,
        @v_maxinput = sf.MaxInput,
        @v_minoutput = sf.MinOutput,
        @v_maxoutput = sf.MaxOutput
    FROM Channel ch
    LEFT JOIN ScalingFactor sf ON ch.ScalingFactorId = sf.Id
    WHERE ch.Id = @p_channelid;

    -- Process the final value
    IF @v_outputtype = 'DIGITAL'
    BEGIN
        SET @v_finalvalue = @p_channelvalue * @v_conversionfactor;

        IF @v_threshold IS NOT NULL AND @v_finalvalue > @v_threshold
        BEGIN
            SET @v_finalvalue = @v_minrange + (RAND() * (@v_maxrange - @v_minrange));
        END
    END
    ELSE IF @v_outputtype = 'ANALOG'
    BEGIN
        SET @v_finalvalue = @v_minoutput + ((@p_channelvalue - @v_mininput) * (@v_maxoutput - @v_minoutput) / (@v_maxinput - @v_mininput));

        IF @v_finalvalue < @v_minoutput SET @v_finalvalue = @v_minoutput;
        IF @v_finalvalue > @v_maxoutput SET @v_finalvalue = @v_maxoutput;

        SET @v_finalvalue = @v_finalvalue * @v_conversionfactor;

        IF @v_threshold IS NOT NULL AND @v_finalvalue > @v_threshold
        BEGIN
            SET @v_finalvalue = @v_minrange + (RAND() * (@v_maxrange - @v_minrange));
        END
    END
    
    -- Round to 2 decimal places
    SET @v_finalvalue = ROUND(@v_finalvalue, 2);

    -- Insert into ChannelData and retrieve the new ID
    INSERT INTO ChannelData (ChannelId, ChannelValue, ChannelDataLogTime, Active, Processed)
    VALUES (@p_channelid, @v_finalvalue, @p_datetime, @v_active, 0);
    
    SET @v_channeldataid = SCOPE_IDENTITY();

    IF @v_channeldataid > 0
    BEGIN
        -- Delete old ChannelDataFeed entries
        DELETE FROM ChannelDataFeed WHERE ChannelId = @p_channelid;

        -- Get Min, Max, Avg for the last hour
        SELECT @v_min = MIN(ChannelValue),
               @v_max = MAX(ChannelValue),
               @v_avg = AVG(ChannelValue)
        FROM ChannelData
        WHERE ChannelId = @p_channelid
          AND ChannelDataLogTime >= DATEADD(HOUR, -1, @p_datetime);

        -- Get PCB Standard
        SELECT @v_pcbstandard = o.Limit
        FROM Channel ch
        JOIN Oxide o ON ch.OxideId = o.Id
        WHERE ch.Id = @p_channelid;

        -- Insert into ChannelDataFeed
        INSERT INTO ChannelDataFeed (
            ChannelDataId, ChannelId, ChannelName, ChannelValue, Units,
            ChannelDataLogTime, PcbLimit, StationId, Active,
            Minimum, Maximum, Average
        )
        VALUES (
            @v_channeldataid, @p_channelid, @v_channelname, @v_finalvalue, @v_chnlunits,
            @p_datetime, @v_pcbstandard, @v_stationid, @v_active,
            @v_min, @v_max, @v_avg
        );
    END
END;
GO

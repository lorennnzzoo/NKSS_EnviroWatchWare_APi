USE [MSSQLNKSS]
GO
SET IDENTITY_INSERT [dbo].[ChannelType] ON 

INSERT [dbo].[ChannelType] ([Id], [ChannelTypeValue], [Active]) VALUES (1, N'SCALAR', 1)
INSERT [dbo].[ChannelType] ([Id], [ChannelTypeValue], [Active]) VALUES (2, N'VECTOR', 1)
INSERT [dbo].[ChannelType] ([Id], [ChannelTypeValue], [Active]) VALUES (3, N'TOTAL', 1)
INSERT [dbo].[ChannelType] ([Id], [ChannelTypeValue], [Active]) VALUES (4, N'FLOW', 1)
INSERT [dbo].[ChannelType] ([Id], [ChannelTypeValue], [Active]) VALUES (5, N'FLOWTOTALIZER', 1)
SET IDENTITY_INSERT [dbo].[ChannelType] OFF
INSERT [dbo].[License] ([LicenseType], [LicenseKey], [Active]) VALUES (N'WatchWare', N'mZfKvv4xWpk/rCzwKfnmiZWRtIGkjqU6LFOwdyLaUp7KNeZfqdbpMrxYzteQAL7s', 1)
SET IDENTITY_INSERT [dbo].[MonitoringType] ON 

INSERT [dbo].[MonitoringType] ([Id], [MonitoringTypeName], [Active]) VALUES (1, N'STACK', 1)
INSERT [dbo].[MonitoringType] ([Id], [MonitoringTypeName], [Active]) VALUES (2, N'WATER', 1)
INSERT [dbo].[MonitoringType] ([Id], [MonitoringTypeName], [Active]) VALUES (3, N'AMBIENT', 1)
SET IDENTITY_INSERT [dbo].[MonitoringType] OFF
SET IDENTITY_INSERT [dbo].[Roles] ON 

INSERT [dbo].[Roles] ([Id], [Name], [Description], [Active], [CreatedOn]) VALUES (1, N'Admin', N'Administrator', 1, CAST(N'2025-03-12 11:56:46.303' AS DateTime))
INSERT [dbo].[Roles] ([Id], [Name], [Description], [Active], [CreatedOn]) VALUES (2, N'Customer', N'Customer', 1, CAST(N'2025-03-12 11:57:00.257' AS DateTime))
SET IDENTITY_INSERT [dbo].[Roles] OFF

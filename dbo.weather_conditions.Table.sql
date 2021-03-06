USE [SportsDB]
GO
/****** Object:  Table [dbo].[weather_conditions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[weather_conditions](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[event_id] [int] NOT NULL,
	[temperature] [varchar](100) NULL,
	[temperature_units] [varchar](40) NULL,
	[humidity] [varchar](100) NULL,
	[clouds] [varchar](100) NULL,
	[wind_direction] [varchar](100) NULL,
	[wind_velocity] [varchar](100) NULL,
	[weather_code] [varchar](100) NULL,
 CONSTRAINT [PK__weather_conditio__671F4F74] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

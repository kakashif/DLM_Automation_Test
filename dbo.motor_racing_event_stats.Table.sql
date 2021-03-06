USE [SportsDB]
GO
/****** Object:  Table [dbo].[motor_racing_event_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[motor_racing_event_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[speed_average] [decimal](6, 3) NULL,
	[speed_units] [varchar](32) NULL,
	[margin_of_victory] [decimal](6, 3) NULL,
	[caution_flags] [int] NULL,
	[caution_flags_laps] [int] NULL,
	[lead_changes] [int] NULL,
	[lead_changes_drivers] [int] NULL,
	[laps_total] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

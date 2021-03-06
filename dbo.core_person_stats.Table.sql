USE [SportsDB]
GO
/****** Object:  Table [dbo].[core_person_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[core_person_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[time_played_event] [varchar](40) NULL,
	[time_played_total] [varchar](40) NULL,
	[time_played_event_average] [varchar](40) NULL,
	[events_played] [int] NULL,
	[events_started] [int] NULL,
	[position_id] [int] NULL,
 CONSTRAINT [PK__core_person_stat__5535A963] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

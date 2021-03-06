USE [SportsDB]
GO
/****** Object:  Table [dbo].[core_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[core_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[score] [varchar](100) NULL,
	[score_opposing] [varchar](100) NULL,
	[score_attempts] [varchar](100) NULL,
	[score_attempts_opposing] [varchar](100) NULL,
	[score_percentage] [varchar](100) NULL,
	[score_percentage_opposing] [varchar](100) NULL,
	[time_played_event] [varchar](40) NULL,
	[time_played_total] [varchar](40) NULL,
	[time_played_event_average] [varchar](40) NULL,
	[events_played] [int] NULL,
	[events_started] [int] NULL,
	[position_id] [int] NULL,
	[series_score] [int] NULL,
	[series_score_opposing] [int] NULL,
 CONSTRAINT [PK__core_stats__571DF1D5] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

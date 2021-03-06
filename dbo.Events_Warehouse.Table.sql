USE [SportsDB]
GO
/****** Object:  Table [dbo].[Events_Warehouse]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Events_Warehouse](
	[id] [bigint] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[league_key] [varchar](100) NULL,
	[league_name] [varchar](50) NULL,
	[scores_page_sort] [int] NULL,
	[event_key] [varchar](100) NOT NULL,
	[game2] [varchar](3) NULL,
	[status] [int] NULL,
	[league_home] [varchar](100) NULL,
	[league_away] [varchar](100) NULL,
	[conf_home] [varchar](100) NULL,
	[conf_away] [varchar](100) NULL,
	[event_status] [varchar](100) NULL,
	[start_date_time] [varchar](100) NULL,
	[actual_dt] [varchar](100) NULL,
	[start_time] [int] NULL,
	[homeTeam_id] [int] NULL,
	[homeTeam_first_name] [varchar](100) NULL,
	[homeTeam_last_name] [varchar](100) NULL,
	[homeTeam_short_name] [varchar](100) NULL,
	[homeTeam_score] [varchar](30) NULL,
	[awayTeam_id] [int] NULL,
	[awayTeam_first_name] [varchar](100) NULL,
	[awayTeam_last_name] [varchar](100) NULL,
	[awayTeam_short_name] [varchar](100) NULL,
	[awayTeam_score] [varchar](30) NULL,
	[period] [int] NULL,
	[time_remaining] [varchar](100) NULL,
	[time_elapsed] [varchar](100) NULL,
	[lineup] [varchar](6) NULL,
	[preview] [varchar](18) NULL,
	[boxScore] [varchar](11) NULL,
	[summary] [varchar](19) NULL,
	[time_certainty] [varchar](100) NULL,
	[broadcast_listing] [varchar](255) NULL,
	[awayTeam_outcome] [varchar](100) NULL,
	[homeTeam_outcome] [varchar](100) NULL,
	[event_id] [int] NULL,
	[start_date_time_EST] [datetime] NULL,
 CONSTRAINT [Pk_Events_Warehouse] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

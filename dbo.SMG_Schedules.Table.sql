USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Schedules]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Schedules](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[sub_season_type] [varchar](100) NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[away_team_key] [varchar](100) NULL,
	[home_team_key] [varchar](100) NULL,
	[away_team_score] [int] NULL,
	[home_team_score] [int] NULL,
	[winner_team_key] [varchar](100) NULL,
	[start_date_time_EST] [datetime] NULL,
	[event_status] [varchar](100) NULL,
	[tv_coverage] [varchar](100) NULL,
	[site_name] [varchar](100) NULL,
	[event_name] [varchar](100) NULL,
	[date_time] [varchar](100) NULL,
	[week] [varchar](100) NULL,
	[game_status] [varchar](100) NULL,
	[odds] [varchar](100) NULL,
	[level_id] [varchar](100) NULL,
	[level_name] [varchar](100) NULL,
	[print_status] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Schedules] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

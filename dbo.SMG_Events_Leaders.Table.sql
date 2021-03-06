USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Events_Leaders]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Events_Leaders](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[sub_season_type] [varchar](100) NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[category] [varchar](100) NOT NULL,
	[category_order] [int] NOT NULL,
	[player_value] [varchar](100) NOT NULL,
	[stat_value] [varchar](100) NOT NULL,
	[stat_order] [int] NOT NULL,
	[date_time] [varchar](100) NOT NULL,
 CONSTRAINT [IX_SMG_Events_Leaders] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[team_key] ASC,
	[player_key] ASC,
	[category] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[tennis_service_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[tennis_service_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[services_played] [int] NULL,
	[matches_played] [int] NULL,
	[aces] [int] NULL,
	[first_services_good] [int] NULL,
	[first_services_good_pct] [int] NULL,
	[first_service_points_won] [int] NULL,
	[first_service_points_won_pct] [int] NULL,
	[second_service_points_won] [int] NULL,
	[second_service_points_won_pct] [int] NULL,
	[service_games_played] [int] NULL,
	[service_games_won] [int] NULL,
	[service_games_won_pct] [int] NULL,
	[break_points_played] [int] NULL,
	[break_points_saved] [int] NULL,
	[break_points_saved_pct] [int] NULL,
	[service_points_won] [int] NULL,
	[service_points_won_pct] [int] NULL,
	[double_faults] [int] NULL,
	[first_service_top_speed] [varchar](100) NULL,
	[second_services_good] [int] NULL,
	[second_services_good_pct] [int] NULL,
	[second_service_top_speed] [varchar](100) NULL,
	[net_points_won] [int] NULL,
	[net_points_played] [int] NULL,
	[points_won] [int] NULL,
	[winners] [int] NULL,
	[unforced_errors] [int] NULL,
	[winners_forehand] [int] NULL,
	[winners_backhand] [int] NULL,
	[winners_volley] [int] NULL,
 CONSTRAINT [PK__tennis_service_s__4C6B5938] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

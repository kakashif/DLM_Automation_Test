USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_special_teams_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_special_teams_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[returns_punt_total] [varchar](100) NULL,
	[returns_punt_yards] [varchar](100) NULL,
	[returns_punt_average] [varchar](100) NULL,
	[returns_punt_longest] [varchar](100) NULL,
	[returns_punt_touchdown] [varchar](100) NULL,
	[returns_kickoff_total] [varchar](100) NULL,
	[returns_kickoff_yards] [varchar](100) NULL,
	[returns_kickoff_average] [varchar](100) NULL,
	[returns_kickoff_longest] [varchar](100) NULL,
	[returns_kickoff_touchdown] [varchar](100) NULL,
	[returns_total] [varchar](100) NULL,
	[returns_yards] [varchar](100) NULL,
	[punts_total] [varchar](100) NULL,
	[punts_yards_gross] [varchar](100) NULL,
	[punts_yards_net] [varchar](100) NULL,
	[punts_longest] [varchar](100) NULL,
	[punts_inside_20] [varchar](100) NULL,
	[punts_inside_20_percentage] [varchar](100) NULL,
	[punts_average] [varchar](100) NULL,
	[punts_blocked] [varchar](100) NULL,
	[touchbacks_total] [varchar](100) NULL,
	[touchbacks_total_percentage] [varchar](100) NULL,
	[touchbacks_kickoffs] [varchar](100) NULL,
	[touchbacks_kickoffs_percentage] [varchar](100) NULL,
	[touchbacks_punts] [varchar](100) NULL,
	[touchbacks_punts_percentage] [varchar](100) NULL,
	[touchbacks_interceptions] [varchar](100) NULL,
	[touchbacks_interceptions_percentage] [varchar](100) NULL,
	[fair_catches] [varchar](100) NULL,
	[punts_against_blocked] [int] NULL,
	[field_goals_against_attempts_1_to_19] [int] NULL,
	[field_goals_against_made_1_to_19] [int] NULL,
	[field_goals_against_attempts_20_to_29] [int] NULL,
	[field_goals_against_made_20_to_29] [int] NULL,
	[field_goals_against_attempts_30_to_39] [int] NULL,
	[field_goals_against_made_30_to_39] [int] NULL,
	[field_goals_against_attempts_40_to_49] [int] NULL,
	[field_goals_against_made_40_to_49] [int] NULL,
	[field_goals_against_attempts_50_plus] [int] NULL,
	[field_goals_against_made_50_plus] [int] NULL,
	[field_goals_against_attempts] [int] NULL,
	[extra_points_against_attempts] [int] NULL,
	[tackles] [int] NULL,
	[tackles_assists] [int] NULL,
	[punts_against_total] [varchar](100) NULL,
	[punts_against_average] [varchar](100) NULL,
	[punts_against_average_net] [varchar](100) NULL,
	[punts_against_yards_gross] [varchar](100) NULL,
	[punts_against_inside_20] [int] NULL,
	[punts_against_longest] [int] NULL,
	[touchbacks_punts_against] [int] NULL,
	[returns_punt_against_average] [varchar](100) NULL,
	[returns_punt_against_longest] [int] NULL,
	[returns_punt_against_total] [varchar](100) NULL,
	[returns_punt_against_touchdown] [int] NULL,
	[returns_punt_against_yards] [varchar](100) NULL,
	[fair_catches_against] [int] NULL,
 CONSTRAINT [PK__american_footbal__2F10007B] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

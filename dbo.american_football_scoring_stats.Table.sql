USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_scoring_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_scoring_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[touchdowns_total] [varchar](100) NULL,
	[touchdowns_passing] [varchar](100) NULL,
	[touchdowns_rushing] [varchar](100) NULL,
	[touchdowns_special_teams] [varchar](100) NULL,
	[touchdowns_defensive] [varchar](100) NULL,
	[extra_points_attempts] [varchar](100) NULL,
	[extra_points_made] [varchar](100) NULL,
	[extra_points_missed] [varchar](100) NULL,
	[extra_points_blocked] [varchar](100) NULL,
	[field_goal_attempts] [varchar](100) NULL,
	[field_goals_made] [varchar](100) NULL,
	[field_goals_missed] [varchar](100) NULL,
	[field_goals_blocked] [varchar](100) NULL,
	[safeties_against] [varchar](100) NULL,
	[two_point_conversions_attempts] [varchar](100) NULL,
	[two_point_conversions_made] [varchar](100) NULL,
	[touchbacks_total] [varchar](100) NULL,
	[safeties_against_opponent] [int] NULL,
 CONSTRAINT [PK__american_footbal__2D27B809] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

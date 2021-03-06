USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_fumbles_stats]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_fumbles_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[fumbles_committed] [varchar](100) NULL,
	[fumbles_forced] [varchar](100) NULL,
	[fumbles_recovered] [varchar](100) NULL,
	[fumbles_lost] [varchar](100) NULL,
	[fumbles_yards_gained] [varchar](100) NULL,
	[fumbles_own_committed] [varchar](100) NULL,
	[fumbles_own_recovered] [varchar](100) NULL,
	[fumbles_own_lost] [varchar](100) NULL,
	[fumbles_own_yards_gained] [varchar](100) NULL,
	[fumbles_opposing_committed] [varchar](100) NULL,
	[fumbles_opposing_recovered] [varchar](100) NULL,
	[fumbles_opposing_lost] [varchar](100) NULL,
	[fumbles_opposing_yards_gained] [varchar](100) NULL,
	[fumbles_own_touchdowns] [int] NULL,
	[fumbles_opposing_touchdowns] [int] NULL,
	[fumbles_committed_defense] [int] NULL,
	[fumbles_committed_special_teams] [int] NULL,
	[fumbles_committed_other] [int] NULL,
	[fumbles_lost_defense] [int] NULL,
	[fumbles_lost_special_teams] [int] NULL,
	[fumbles_lost_other] [int] NULL,
	[fumbles_forced_defense] [int] NULL,
	[fumbles_recovered_defense] [int] NULL,
	[fumbles_recovered_special_teams] [int] NULL,
	[fumbles_recovered_other] [int] NULL,
	[fumbles_recovered_yards_defense] [int] NULL,
	[fumbles_recovered_yards_special_teams] [int] NULL,
	[fumbles_recovered_yards_other] [int] NULL,
 CONSTRAINT [PK__american_footbal__21B6055D] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

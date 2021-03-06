USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_offensive_stats]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_offensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[offensive_plays_yards] [varchar](100) NULL,
	[offensive_plays_number] [varchar](100) NULL,
	[offensive_plays_average_yards_per] [varchar](100) NULL,
	[possession_duration] [varchar](100) NULL,
	[turnovers_giveaway] [varchar](100) NULL,
	[tackles] [int] NULL,
	[tackles_assists] [int] NULL,
	[offensive_rank] [int] NULL,
 CONSTRAINT [PK__american_footbal__239E4DCF] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

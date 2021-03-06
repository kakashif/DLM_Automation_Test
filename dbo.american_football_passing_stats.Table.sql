USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_passing_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_passing_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[passes_attempts] [varchar](100) NULL,
	[passes_completions] [varchar](100) NULL,
	[passes_percentage] [varchar](100) NULL,
	[passes_yards_gross] [varchar](100) NULL,
	[passes_yards_net] [varchar](100) NULL,
	[passes_yards_lost] [varchar](100) NULL,
	[passes_touchdowns] [varchar](100) NULL,
	[passes_touchdowns_percentage] [varchar](100) NULL,
	[passes_interceptions] [varchar](100) NULL,
	[passes_interceptions_percentage] [varchar](100) NULL,
	[passes_longest] [varchar](100) NULL,
	[passes_average_yards_per] [varchar](100) NULL,
	[passer_rating] [varchar](100) NULL,
	[receptions_total] [varchar](100) NULL,
	[receptions_yards] [varchar](100) NULL,
	[receptions_touchdowns] [varchar](100) NULL,
	[receptions_first_down] [varchar](100) NULL,
	[receptions_longest] [varchar](100) NULL,
	[receptions_average_yards_per] [varchar](100) NULL,
	[passing_rank] [int] NULL,
 CONSTRAINT [PK__american_footbal__25869641] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

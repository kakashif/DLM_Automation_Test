USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_team_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_team_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[yards_per_attempt] [varchar](100) NULL,
	[average_starting_position] [varchar](100) NULL,
	[timeouts] [varchar](100) NULL,
	[time_of_possession] [varchar](100) NULL,
	[turnover_ratio] [varchar](100) NULL,
 CONSTRAINT [PK__american_footbal__30F848ED] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

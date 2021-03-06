USE [SportsDB]
GO
/****** Object:  Table [dbo].[basketball_rebounding_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[basketball_rebounding_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[rebounds_total] [varchar](100) NULL,
	[rebounds_per_game] [varchar](100) NULL,
	[rebounds_defensive] [varchar](100) NULL,
	[rebounds_offensive] [varchar](100) NULL,
	[team_rebounds_total] [varchar](100) NULL,
	[team_rebounds_per_game] [varchar](100) NULL,
	[team_rebounds_defensive] [varchar](100) NULL,
	[team_rebounds_offensive] [varchar](100) NULL,
 CONSTRAINT [PK__basketball_rebou__4F7CD00D] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

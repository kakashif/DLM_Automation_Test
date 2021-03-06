USE [SportsDB]
GO
/****** Object:  Table [dbo].[STATS_Leagues]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[STATS_Leagues](
	[sport_id] [int] NOT NULL,
	[sport_name] [varchar](100) NOT NULL,
	[league_id] [int] NOT NULL,
	[league_name] [varchar](100) NOT NULL,
	[league_display] [varchar](100) NULL,
	[league_abbreviation] [varchar](100) NULL,
	[sub_league_id] [int] NOT NULL,
	[sub_league_name] [varchar](100) NULL,
	[sub_league_display] [varchar](100) NULL,
	[sub_league_abbreviation] [varchar](100) NULL,
	[path_sequence] [int] NOT NULL,
 CONSTRAINT [PK__STATS_Le__EA871DF33BE24DB9] PRIMARY KEY CLUSTERED 
(
	[sport_id] ASC,
	[league_id] ASC,
	[sub_league_id] ASC,
	[path_sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

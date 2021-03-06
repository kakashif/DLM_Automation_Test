USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Solo_Standings]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Solo_Standings](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[fixture_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NULL,
	[player_name] [varchar](100) NOT NULL,
	[column] [varchar](100) NOT NULL,
	[value] [varchar](100) NOT NULL,
	[date_time] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Solo_Standings] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[fixture_key] ASC,
	[player_name] ASC,
	[column] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

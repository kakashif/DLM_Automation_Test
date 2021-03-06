USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Team_Depths]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Team_Depths](
	[league_key] [varchar](100) NULL,
	[season_key] [int] NOT NULL,
	[sub_season_type] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[depth_name] [varchar](100) NOT NULL,
	[depth_position] [int] NULL,
	[date_time] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Team_Depths] PRIMARY KEY CLUSTERED 
(
	[season_key] ASC,
	[sub_season_type] ASC,
	[team_key] ASC,
	[player_key] ASC,
	[depth_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

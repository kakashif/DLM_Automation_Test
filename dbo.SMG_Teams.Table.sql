USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Teams]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Teams](
	[season_key] [int] NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[conference_key] [varchar](100) NULL,
	[division_key] [varchar](100) NULL,
	[league_key] [varchar](100) NOT NULL,
	[team_first] [varchar](100) NULL,
	[team_last] [varchar](100) NULL,
	[team_display] [varchar](100) NULL,
	[team_abbreviation] [varchar](100) NULL,
	[rgb] [varchar](100) NULL,
	[x_coordinate] [int] NULL,
	[y_coordinate] [int] NULL,
	[team_slug] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Teams] PRIMARY KEY CLUSTERED 
(
	[season_key] ASC,
	[team_key] ASC,
	[league_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

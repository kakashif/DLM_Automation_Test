USE [SportsDB]
GO
/****** Object:  Table [dbo].[Edit_Bracket_Teams]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Edit_Bracket_Teams](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[seed] [int] NOT NULL,
	[team_display] [varchar](100) NOT NULL,
	[team_name] [varchar](100) NULL,
 CONSTRAINT [PK_Edit_Bracket_Teams] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[team_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

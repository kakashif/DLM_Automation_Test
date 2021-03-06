USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_Team_Details]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_Team_Details](
	[team_key] [varchar](100) NOT NULL,
	[league_key] [varchar](100) NULL,
	[conference_key] [varchar](100) NULL,
	[division_key] [varchar](100) NULL,
	[team_first] [varchar](100) NULL,
	[team_last] [varchar](100) NULL,
	[team_display] [varchar](100) NULL,
	[team_abbreviation] [varchar](100) NULL,
	[SDI] [varchar](100) NULL,
	[TSN] [varchar](100) NULL,
 CONSTRAINT [PK_USAT_Team_Details] PRIMARY KEY CLUSTERED 
(
	[team_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

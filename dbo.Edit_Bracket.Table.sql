USE [SportsDB]
GO
/****** Object:  Table [dbo].[Edit_Bracket]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Edit_Bracket](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[match_id] [int] NOT NULL,
	[region] [varchar](100) NULL,
	[event_key] [varchar](100) NULL,
	[team_a_key] [varchar](100) NULL,
	[team_b_key] [varchar](100) NULL,
 CONSTRAINT [PK_Edit_Bracket] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[match_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

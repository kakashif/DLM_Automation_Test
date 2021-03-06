USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Players]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Players](
	[player_key] [varchar](100) NOT NULL,
	[first_name] [varchar](100) NOT NULL,
	[last_name] [varchar](100) NOT NULL,
	[college_name] [varchar](100) NULL,
	[duration] [varchar](100) NULL,
	[date_of_birth] [date] NULL,
	[shooting_batting_hand] [varchar](100) NULL,
	[throwing_hand] [varchar](100) NULL,
	[draft_team] [varchar](100) NULL,
	[acquisition] [varchar](100) NULL,
	[birth_place] [varchar](100) NULL,
	[draft_season] [int] NULL,
	[draft_round] [int] NULL,
	[draft_pick] [int] NULL,
 CONSTRAINT [PK_SMG_Players] PRIMARY KEY CLUSTERED 
(
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

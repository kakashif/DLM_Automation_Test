USE [SportsDB]
GO
/****** Object:  Table [dbo].[UGC_Bracket_Names]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UGC_Bracket_Names](
	[league_name] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[guid] [varchar](100) NOT NULL,
	[number] [int] NOT NULL,
	[bracket_key] [varchar](100) NOT NULL,
	[name] [varchar](100) NOT NULL,
	[winner_abbr] [varchar](100) NULL,
	[points_earned] [int] NULL,
	[picks_correct] [int] NULL,
	[points_remaining] [int] NULL,
	[points_round_2] [int] NULL,
	[points_round_3] [int] NULL,
	[points_sweet_16] [int] NULL,
	[points_elite_8] [int] NULL,
	[points_final_4] [int] NULL,
	[points_championship] [int] NULL,
	[completed] [int] NULL,
	[date_time] [datetime] NOT NULL,
	[center] [varchar](100) NULL,
 CONSTRAINT [PK_UGC_Bracket_Names] PRIMARY KEY CLUSTERED 
(
	[league_name] ASC,
	[season_key] ASC,
	[guid] ASC,
	[number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

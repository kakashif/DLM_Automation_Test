USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Plays_NFL]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Plays_NFL](
	[event_key] [varchar](100) NOT NULL,
	[sequence_number] [int] NOT NULL,
	[period_value] [int] NOT NULL,
	[period_time_remaining] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[play_type] [varchar](100) NOT NULL,
	[play_score] [int] NOT NULL,
	[away_score] [int] NULL,
	[home_score] [int] NULL,
	[value] [varchar](max) NOT NULL,
	[date_time] [varchar](100) NOT NULL,
	[yards] [int] NULL,
	[no_play] [varchar](100) NULL,
	[play_id] [int] NULL,
	[scoring_team_key] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Plays_NFL] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[sequence_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

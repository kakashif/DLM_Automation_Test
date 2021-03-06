USE [SportsDB]
GO
/****** Object:  Table [dbo].[USCP_football_plays]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USCP_football_plays](
	[event_key] [varchar](100) NOT NULL,
	[sequence_number] [int] NOT NULL,
	[drive_number] [int] NULL,
	[quarter_value] [int] NULL,
	[scoring_type] [varchar](100) NULL,
	[down] [int] NULL,
	[yards_to_go] [int] NULL,
	[yards_gained] [int] NULL,
	[initial_yard_line] [int] NULL,
	[initial_field_key] [varchar](100) NULL,
	[initial_position] [int] NULL,
	[resulting_yard_line] [int] NULL,
	[resulting_field_key] [varchar](100) NULL,
	[resulting_position] [int] NULL,
	[play_team_key] [varchar](100) NULL,
	[resulting_away_score] [int] NULL,
	[resulting_home_score] [int] NULL,
	[play_type] [varchar](100) NULL,
	[player_key] [varchar](100) NULL,
	[time_left] [varchar](100) NULL,
	[narrative] [varchar](max) NULL,
	[play_id] [int] NULL,
 CONSTRAINT [PK_SMG_football_plays] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[sequence_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

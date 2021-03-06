USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Transient]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Transient](
	[event_key] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NULL,
	[down] [int] NULL,
	[distance_1st_down] [varchar](100) NULL,
	[field_side] [varchar](4) NULL,
	[field_line] [int] NULL,
	[date_time] [varchar](100) NOT NULL,
	[inning_half] [varchar](100) NULL,
	[outs] [int] NULL,
	[strikes] [int] NULL,
	[balls] [int] NULL,
	[runner_on_first] [varchar](100) NULL,
	[runner_on_second] [varchar](100) NULL,
	[runner_on_third] [varchar](100) NULL,
	[away_team_key] [varchar](100) NULL,
	[home_team_key] [varchar](100) NULL,
	[pitcher_key] [varchar](100) NULL,
	[batter_key] [varchar](100) NULL,
	[last_play] [varchar](max) NULL,
	[next_batter_key] [varchar](100) NULL,
	[pitch_count] [int] NULL,
	[umpire_call] [varchar](100) NULL,
	[sequence_number] [int] NULL,
	[play_type] [varchar](100) NULL,
	[inning_value] [int] NULL,
 CONSTRAINT [IX_SMG_Transient] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[team_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

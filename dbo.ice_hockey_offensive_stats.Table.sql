USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_offensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_offensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[goals_game_winning] [varchar](100) NULL,
	[goals_game_tying] [varchar](100) NULL,
	[goals_power_play] [varchar](100) NULL,
	[goals_short_handed] [varchar](100) NULL,
	[goals_even_strength] [varchar](100) NULL,
	[goals_empty_net] [varchar](100) NULL,
	[goals_overtime] [varchar](100) NULL,
	[goals_shootout] [varchar](100) NULL,
	[goals_penalty_shot] [varchar](100) NULL,
	[assists] [varchar](100) NULL,
	[points] [varchar](100) NULL,
	[power_play_amount] [varchar](100) NULL,
	[power_play_percentage] [varchar](100) NULL,
	[shots_penalty_shot_taken] [varchar](100) NULL,
	[shots_penalty_shot_missed] [varchar](100) NULL,
	[shots_penalty_shot_percentage] [varchar](100) NULL,
	[giveaways] [varchar](100) NULL,
	[minutes_power_play] [varchar](100) NULL,
	[faceoff_wins] [varchar](100) NULL,
	[faceoff_losses] [varchar](100) NULL,
	[faceoff_win_percentage] [varchar](100) NULL,
	[scoring_chances] [varchar](100) NULL,
	[goals] [int] NULL,
	[shots] [int] NULL,
	[shots_missed] [int] NULL,
	[shots_blocked] [int] NULL,
	[shots_power_play] [int] NULL,
	[shots_short_handed] [int] NULL,
	[shots_even_strength] [int] NULL,
	[player_count] [int] NULL,
	[player_count_opposing] [int] NULL,
	[assists_game_winning] [int] NULL,
	[assists_overtime] [int] NULL,
	[assists_power_play] [int] NULL,
	[assists_short_handed] [int] NULL,
 CONSTRAINT [PK__ice_hockey_offen__02084FDA] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

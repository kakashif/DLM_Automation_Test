USE [SportsDB]
GO
/****** Object:  Table [dbo].[soccer_offensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[soccer_offensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[goals_game_winning] [varchar](100) NULL,
	[goals_game_tying] [varchar](100) NULL,
	[goals_overtime] [varchar](100) NULL,
	[goals_shootout] [varchar](100) NULL,
	[goals_total] [varchar](100) NULL,
	[assists_game_winning] [varchar](100) NULL,
	[assists_game_tying] [varchar](100) NULL,
	[assists_overtime] [varchar](100) NULL,
	[assists_total] [varchar](100) NULL,
	[points] [varchar](100) NULL,
	[shots_total] [varchar](100) NULL,
	[shots_on_goal_total] [varchar](100) NULL,
	[shots_hit_frame] [varchar](100) NULL,
	[shots_penalty_shot_taken] [varchar](100) NULL,
	[shots_penalty_shot_scored] [varchar](100) NULL,
	[shots_penalty_shot_missed] [varchar](40) NULL,
	[shots_penalty_shot_percentage] [varchar](40) NULL,
	[shots_shootout_taken] [varchar](40) NULL,
	[shots_shootout_scored] [varchar](40) NULL,
	[shots_shootout_missed] [varchar](40) NULL,
	[shots_shootout_percentage] [varchar](40) NULL,
	[giveaways] [varchar](40) NULL,
	[offsides] [varchar](40) NULL,
	[corner_kicks] [varchar](40) NULL,
	[hat_tricks] [varchar](40) NULL,
 CONSTRAINT [PK__soccer_offensive__395884C4] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_defensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ice_hockey_defensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[shots_power_play_allowed] [varchar](100) NULL,
	[shots_penalty_shot_allowed] [varchar](100) NULL,
	[goals_power_play_allowed] [varchar](100) NULL,
	[goals_penalty_shot_allowed] [varchar](100) NULL,
	[goals_against_average] [varchar](100) NULL,
	[saves] [varchar](100) NULL,
	[save_percentage] [varchar](100) NULL,
	[penalty_killing_amount] [varchar](100) NULL,
	[penalty_killing_percentage] [varchar](100) NULL,
	[shots_blocked] [varchar](100) NULL,
	[takeaways] [varchar](100) NULL,
	[shutouts] [varchar](100) NULL,
	[minutes_penalty_killing] [varchar](100) NULL,
	[hits] [varchar](100) NULL,
	[goals_empty_net_allowed] [varchar](100) NULL,
	[goals_short_handed_allowed] [varchar](100) NULL,
	[goals_shootout_allowed] [varchar](100) NULL,
	[shots_shootout_allowed] [varchar](100) NULL,
	[goaltender_wins] [int] NULL,
	[goaltender_losses] [int] NULL,
	[goaltender_ties] [int] NULL,
	[goals_allowed] [int] NULL,
	[shots_allowed] [int] NULL,
	[player_count] [int] NULL,
	[player_count_opposing] [int] NULL,
	[goaltender_losses_overtime] [int] NULL,
	[goals_overtime_allowed] [int] NULL,
	[goaltender_wins_overtime] [int] NULL,
 CONSTRAINT [PK__ice_hockey_defen__00200768] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

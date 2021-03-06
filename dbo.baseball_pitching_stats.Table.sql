USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_pitching_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[baseball_pitching_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[runs_allowed] [int] NULL,
	[singles_allowed] [int] NULL,
	[doubles_allowed] [int] NULL,
	[triples_allowed] [int] NULL,
	[home_runs_allowed] [int] NULL,
	[innings_pitched] [varchar](20) NULL,
	[hits] [int] NULL,
	[earned_runs] [int] NULL,
	[unearned_runs] [int] NULL,
	[bases_on_balls] [int] NULL,
	[bases_on_balls_intentional] [int] NULL,
	[strikeouts] [int] NULL,
	[strikeout_to_bb_ratio] [float] NULL,
	[number_of_pitches] [int] NULL,
	[era] [float] NULL,
	[inherited_runners_scored] [int] NULL,
	[pick_offs] [int] NULL,
	[errors_hit_with_pitch] [int] NULL,
	[errors_wild_pitch] [int] NULL,
	[balks] [int] NULL,
	[wins] [int] NULL,
	[losses] [int] NULL,
	[saves] [int] NULL,
	[shutouts] [int] NULL,
	[games_complete] [int] NULL,
	[games_finished] [int] NULL,
	[winning_percentage] [float] NULL,
	[event_credit] [varchar](40) NULL,
	[save_credit] [varchar](40) NULL,
	[batters_doubles_against] [int] NULL,
	[batters_triples_against] [int] NULL,
	[outs_recorded] [int] NULL,
	[batters_at_bats_against] [int] NULL,
	[number_of_strikes] [int] NULL,
	[wins_season] [int] NULL,
	[losses_season] [int] NULL,
	[saves_season] [int] NULL,
	[saves_blown_season] [int] NULL,
	[saves_blown] [int] NULL,
	[whip] [float] NULL,
 CONSTRAINT [PK__baseball_pitchin__47DBAE45] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

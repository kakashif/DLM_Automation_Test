USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_offensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[baseball_offensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[average] [float] NULL,
	[runs_scored] [int] NULL,
	[at_bats] [int] NULL,
	[hits] [int] NULL,
	[rbi] [int] NULL,
	[total_bases] [int] NULL,
	[slugging_percentage] [float] NULL,
	[bases_on_balls] [int] NULL,
	[strikeouts] [int] NULL,
	[left_on_base] [int] NULL,
	[left_in_scoring_position] [int] NULL,
	[singles] [int] NULL,
	[doubles] [int] NULL,
	[triples] [int] NULL,
	[home_runs] [int] NULL,
	[grand_slams] [int] NULL,
	[at_bats_per_rbi] [float] NULL,
	[plate_appearances_per_rbi] [float] NULL,
	[at_bats_per_home_run] [float] NULL,
	[plate_appearances_per_home_run] [float] NULL,
	[sac_flies] [int] NULL,
	[sac_bunts] [int] NULL,
	[grounded_into_double_play] [int] NULL,
	[moved_up] [int] NULL,
	[on_base_percentage] [float] NULL,
	[stolen_bases] [int] NULL,
	[stolen_bases_caught] [int] NULL,
	[stolen_bases_average] [float] NULL,
	[hit_by_pitch] [int] NULL,
	[reached_base_defensive_interference] [int] NULL,
	[on_base_plus_slugging] [float] NULL,
	[plate_appearances] [int] NULL,
	[hits_extra_base] [int] NULL,
	[pick_offs_against] [int] NULL,
	[sacrifices] [int] NULL,
	[outs_fly] [int] NULL,
	[outs_ground] [int] NULL,
	[reached_base_error] [int] NULL,
	[reached_base_fielder_choice] [int] NULL,
	[double_plays_against] [int] NULL,
	[triple_plays_against] [int] NULL,
	[strikeouts_looking] [int] NULL,
	[bases_on_balls_intentional] [int] NULL,
 CONSTRAINT [PK__baseball_offensi__45F365D3] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

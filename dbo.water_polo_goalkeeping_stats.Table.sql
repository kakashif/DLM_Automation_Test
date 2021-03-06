USE [SportsDB]
GO
/****** Object:  Table [dbo].[water_polo_goalkeeping_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[water_polo_goalkeeping_stats](
	[id] [int] NOT NULL,
	[saves_total] [int] NULL,
	[shots_total] [int] NULL,
	[save_percentage] [int] NULL,
	[action_shots_saves_total] [int] NULL,
	[action_shots_total] [int] NULL,
	[action_shots_save_percentage] [int] NULL,
	[center_shots_saves_total] [int] NULL,
	[center_shots_total] [int] NULL,
	[center_shots_save_percentage] [int] NULL,
	[extra_player_shots_saves_total] [int] NULL,
	[extra_player_shots_total] [int] NULL,
	[extra_player_shots_save_percentage] [int] NULL,
	[five_meter_shots_saves_total] [int] NULL,
	[five_meter_shots_total] [int] NULL,
	[five_meter_shots_save_percentage] [int] NULL,
	[penalty_shots_saves_total] [int] NULL,
	[penalty_shots_total] [int] NULL,
	[penalty_shots_save_percentage] [int] NULL,
	[counter_attack_shots_saves_total] [int] NULL,
	[counter_attack_shots_save_percentage] [int] NULL,
 CONSTRAINT [PK_water_polo_goalkeeping_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

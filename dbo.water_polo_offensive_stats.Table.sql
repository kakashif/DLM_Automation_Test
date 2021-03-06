USE [SportsDB]
GO
/****** Object:  Table [dbo].[water_polo_offensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[water_polo_offensive_stats](
	[id] [int] NOT NULL,
	[goals_made] [int] NULL,
	[goal_attempts] [int] NULL,
	[goals_made_percentage] [int] NULL,
	[action_shots_made] [int] NULL,
	[action_shots_attempts] [int] NULL,
	[center_shots_made] [int] NULL,
	[center_shots_attempts] [int] NULL,
	[extra_player_shots_made] [int] NULL,
	[extra_player_shots_attempts] [int] NULL,
	[five_meter_shots_made] [int] NULL,
	[five_meter_shots_attempts] [int] NULL,
	[penalty_shots_made] [int] NULL,
	[penalty_shots_attempts] [int] NULL,
	[counter_attack_shots_made] [int] NULL,
	[counter_attack_shots_attempts] [int] NULL,
	[assists] [int] NULL,
 CONSTRAINT [PK_water_polo_offensive_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

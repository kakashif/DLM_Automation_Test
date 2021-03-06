USE [SportsDB]
GO
/****** Object:  Table [dbo].[ice_hockey_faceoff_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ice_hockey_faceoff_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[player_count] [int] NULL,
	[player_count_opposing] [int] NULL,
	[faceoff_wins] [int] NULL,
	[faceoff_losses] [int] NULL,
	[faceoff_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_power_play_wins] [int] NULL,
	[faceoffs_power_play_losses] [int] NULL,
	[faceoffs_power_play_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_short_handed_wins] [int] NULL,
	[faceoffs_short_handed_losses] [int] NULL,
	[faceoffs_short_handed_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_even_strength_wins] [int] NULL,
	[faceoffs_even_strength_losses] [int] NULL,
	[faceoffs_even_strength_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_offensive_zone_wins] [int] NULL,
	[faceoffs_offensive_zone_losses] [int] NULL,
	[faceoffs_offensive_zone_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_defensive_zone_wins] [int] NULL,
	[faceoffs_defensive_zone_losses] [int] NULL,
	[faceoffs_defensive_zone_win_percentage] [decimal](5, 2) NULL,
	[faceoffs_neutral_zone_wins] [int] NULL,
	[faceoffs_neutral_zone_losses] [int] NULL,
	[faceoffs_neutral_zone_win_percentage] [decimal](5, 2) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

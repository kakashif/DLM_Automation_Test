USE [SportsDB]
GO
/****** Object:  Table [dbo].[tennis_player_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tennis_player_stats](
	[id] [int] NOT NULL,
	[net_points_won] [int] NULL,
	[net_points_played] [int] NULL,
	[points_won] [int] NULL,
	[winners] [int] NULL,
	[unforced_errors] [int] NULL,
	[winners_forehand] [int] NULL,
	[winners_backhand] [int] NULL,
	[winners_volley] [int] NULL,
 CONSTRAINT [PK_tennis_player_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

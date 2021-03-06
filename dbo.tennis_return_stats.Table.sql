USE [SportsDB]
GO
/****** Object:  Table [dbo].[tennis_return_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tennis_return_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[returns_played] [int] NULL,
	[matches_played] [int] NULL,
	[first_service_return_points_won] [int] NULL,
	[first_service_return_points_won_pct] [int] NULL,
	[second_service_return_points_won] [int] NULL,
	[second_service_return_points_won_pct] [int] NULL,
	[return_games_played] [int] NULL,
	[return_games_won] [int] NULL,
	[return_games_won_pct] [int] NULL,
	[break_points_played] [int] NULL,
	[break_points_converted] [int] NULL,
	[break_points_converted_pct] [int] NULL,
	[net_points_won] [int] NULL,
	[net_points_played] [int] NULL,
	[points_won] [int] NULL,
	[winners] [int] NULL,
	[unforced_errors] [int] NULL,
	[winners_forehand] [int] NULL,
	[winners_backhand] [int] NULL,
	[winners_volley] [int] NULL,
 CONSTRAINT [PK__tennis_return_st__4A8310C6] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

USE [SportsDB]
GO
/****** Object:  UserDefinedTableType [dbo].[GamesTable]    Script Date: 10/28/2015 2:03:48 PM ******/
CREATE TYPE [dbo].[GamesTable] AS TABLE(
	[sub_season_type] [varchar](50) NULL,
	[event_key] [varchar](100) NULL,
	[event_status] [varchar](50) NULL,
	[week] [int] NULL,
	[start_date_time] [datetime] NULL,
	[awayTeam_first_name] [varchar](50) NULL,
	[awayTeam_last_name] [varchar](50) NULL,
	[awayTeam_score] [int] NULL,
	[awayTeam_Outcome] [varchar](20) NULL,
	[awayTeam_rank] [varchar](5) NULL,
	[homeTeam_first_name] [varchar](50) NULL,
	[homeTeam_last_name] [varchar](50) NULL,
	[homeTeam_score] [int] NULL,
	[homeTeam_Outcome] [varchar](20) NULL,
	[homeTeam_rank] [varchar](5) NULL,
	[away_team_key] [varchar](50) NULL,
	[away_team_id] [int] NULL,
	[home_team_id] [int] NULL,
	[home_team_key] [varchar](50) NULL,
	[homeTeam_abbr] [varchar](50) NULL,
	[awayTeam_abbr] [varchar](50) NULL,
	[tv] [varchar](255) NULL,
	[line] [varchar](10) NULL,
	[game2] [varchar](3) NULL,
	[boxScore] [varchar](11) NULL,
	[preview] [varchar](18) NULL,
	[summary] [varchar](19) NULL
)
GO

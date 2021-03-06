USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Rosters]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Rosters](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[uniform_number] [varchar](100) NULL,
	[position_regular] [varchar](100) NULL,
	[height] [varchar](100) NULL,
	[weight] [varchar](100) NULL,
	[status] [varchar](100) NULL,
	[subphase_type] [varchar](100) NULL,
	[phase_status] [varchar](100) NULL,
	[head_shot] [varchar](100) NULL,
	[filename] [varchar](100) NULL,
 CONSTRAINT [PK__SMG_Rost__44683E477584DF69] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[team_key] ASC,
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [IX_SMG_Rosters] UNIQUE NONCLUSTERED 
(
	[season_key] ASC,
	[league_key] ASC,
	[team_key] ASC,
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

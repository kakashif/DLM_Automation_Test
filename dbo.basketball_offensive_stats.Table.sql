USE [SportsDB]
GO
/****** Object:  Table [dbo].[basketball_offensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[basketball_offensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[field_goals_made] [int] NULL,
	[field_goals_attempted] [int] NULL,
	[field_goals_percentage] [varchar](100) NULL,
	[field_goals_per_game] [varchar](100) NULL,
	[field_goals_attempted_per_game] [varchar](100) NULL,
	[field_goals_percentage_adjusted] [varchar](100) NULL,
	[three_pointers_made] [int] NULL,
	[three_pointers_attempted] [int] NULL,
	[three_pointers_percentage] [varchar](100) NULL,
	[three_pointers_per_game] [varchar](100) NULL,
	[three_pointers_attempted_per_game] [varchar](100) NULL,
	[free_throws_made] [varchar](100) NULL,
	[free_throws_attempted] [varchar](100) NULL,
	[free_throws_percentage] [varchar](100) NULL,
	[free_throws_per_game] [varchar](100) NULL,
	[free_throws_attempted_per_game] [varchar](100) NULL,
	[points_scored_total] [varchar](100) NULL,
	[points_scored_per_game] [varchar](100) NULL,
	[assists_total] [varchar](100) NULL,
	[assists_per_game] [varchar](100) NULL,
	[turnovers_total] [varchar](100) NULL,
	[turnovers_per_game] [varchar](100) NULL,
	[points_scored_off_turnovers] [varchar](100) NULL,
	[points_scored_in_paint] [varchar](100) NULL,
	[points_scored_on_second_chance] [varchar](100) NULL,
	[points_scored_on_fast_break] [varchar](100) NULL,
 CONSTRAINT [PK__basketball_offen__4D94879B] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

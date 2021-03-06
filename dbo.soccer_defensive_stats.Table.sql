USE [SportsDB]
GO
/****** Object:  Table [dbo].[soccer_defensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[soccer_defensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[shots_penalty_shot_allowed] [varchar](100) NULL,
	[goals_penalty_shot_allowed] [varchar](100) NULL,
	[goals_against_average] [varchar](100) NULL,
	[goals_against_total] [varchar](100) NULL,
	[saves] [varchar](100) NULL,
	[save_percentage] [varchar](100) NULL,
	[catches_punches] [varchar](100) NULL,
	[shots_on_goal_total] [varchar](100) NULL,
	[shots_shootout_total] [varchar](100) NULL,
	[shots_shootout_allowed] [varchar](100) NULL,
	[shots_blocked] [varchar](100) NULL,
	[shutouts] [varchar](100) NULL,
 CONSTRAINT [PK__soccer_defensive__3587F3E0] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

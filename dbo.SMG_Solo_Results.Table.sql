USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Solo_Results]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Solo_Results](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[round] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[player_name] [varchar](100) NULL,
	[column] [varchar](100) NOT NULL,
	[value] [varchar](max) NOT NULL,
	[date_time] [datetime] NULL,
 CONSTRAINT [PK_SMG_Solo_Results] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[event_key] ASC,
	[round] ASC,
	[team_key] ASC,
	[player_key] ASC,
	[column] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

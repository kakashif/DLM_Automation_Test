USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Team_Records]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Team_Records](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[wins] [int] NOT NULL,
	[losses] [int] NOT NULL,
	[ties] [int] NOT NULL,
	[start_date_time_EST] [datetime] NOT NULL,
 CONSTRAINT [PK_SMG_Team_Records_1] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[team_key] ASC,
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

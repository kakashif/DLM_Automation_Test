USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Event_Tags]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Event_Tags](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[score] [varchar](100) NULL,
	[schedule] [varchar](100) NULL,
	[suspender] [varchar](100) NULL,
	[mobile] [varchar](100) NULL,
 CONSTRAINT [PK_SMG_Event_Tags] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Transactions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Transactions](
	[date] [date] NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NOT NULL,
	[transaction] [varchar](max) NOT NULL,
	[league_key] [varchar](100) NOT NULL,
 CONSTRAINT [PK__temp_SMG__7CD77A4D595645FF] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[team_key] ASC,
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

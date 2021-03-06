USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Odds]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Odds](
	[event_key] [varchar](100) NOT NULL,
	[team_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[value] [varchar](max) NOT NULL,
	[date_time] [datetime] NOT NULL,
	[prediction] [varchar](100) NOT NULL,
	[book] [varchar](100) NOT NULL,
	[betting] [varchar](100) NOT NULL,
	[player_key] [varchar](100) NULL,
	[league_key] [varchar](100) NOT NULL,
 CONSTRAINT [IX_temp_SMG_Odds] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[team_key] ASC,
	[book] ASC,
	[betting] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[SMG_Odds] ADD  CONSTRAINT [DF__temp_SMG_O__book__36E88E72]  DEFAULT ('5dimes') FOR [book]
GO
ALTER TABLE [dbo].[SMG_Odds] ADD  CONSTRAINT [DF__temp_SMG___betti__37DCB2AB]  DEFAULT ('schedule') FOR [betting]
GO

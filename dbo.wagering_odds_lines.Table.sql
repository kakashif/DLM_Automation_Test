USE [SportsDB]
GO
/****** Object:  Table [dbo].[wagering_odds_lines]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[wagering_odds_lines](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[bookmaker_id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[date_time] [datetime] NULL,
	[team_id] [int] NOT NULL,
	[person_id] [int] NULL,
	[rotation_key] [varchar](100) NULL,
	[comment] [varchar](256) NULL,
	[numerator] [varchar](100) NULL,
	[denominator] [varchar](100) NULL,
	[prediction] [varchar](100) NULL,
	[payout_calculation] [varchar](100) NULL,
	[payout_amount] [varchar](100) NULL,
 CONSTRAINT [PK__wagering_odds_li__55F4C372] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Periods]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Periods](
	[event_key] [varchar](100) NOT NULL,
	[period] [int] NOT NULL,
	[period_value] [varchar](100) NOT NULL,
	[away_value] [varchar](100) NOT NULL,
	[home_value] [varchar](100) NOT NULL,
 CONSTRAINT [PK_SMG_Periods] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC,
	[period] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

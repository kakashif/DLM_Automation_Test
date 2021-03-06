USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Default_Dates]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Default_Dates](
	[league_key] [varchar](100) NOT NULL,
	[page] [varchar](100) NOT NULL,
	[season_key] [int] NULL,
	[sub_season_type] [varchar](100) NULL,
	[week] [varchar](100) NULL,
	[start_date] [datetime] NULL,
	[filter] [varchar](100) NULL,
	[team_season_key] [int] NULL,
 CONSTRAINT [PK_SMG_Default_Dates] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[page] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

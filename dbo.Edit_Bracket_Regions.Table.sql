USE [SportsDB]
GO
/****** Object:  Table [dbo].[Edit_Bracket_Regions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Edit_Bracket_Regions](
	[league_name] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[region] [varchar](100) NOT NULL,
	[region_order] [int] NOT NULL,
 CONSTRAINT [PK_Edit_Bracket_Regions] PRIMARY KEY CLUSTERED 
(
	[league_name] ASC,
	[season_key] ASC,
	[region] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[STATS_Countries]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[STATS_Countries](
	[country_id] [int] NOT NULL,
	[country_name] [varchar](255) NOT NULL,
	[country_abbreviation] [varchar](100) NOT NULL,
 CONSTRAINT [PK__STATS_Co__16924E4A47540065] PRIMARY KEY CLUSTERED 
(
	[country_id] ASC,
	[country_abbreviation] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[UGC_Pool_Names]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UGC_Pool_Names](
	[league_name] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[guid] [varchar](100) NOT NULL,
	[number] [int] NOT NULL,
	[pool_key] [varchar](100) NOT NULL,
	[name] [varchar](100) NOT NULL,
	[date_time] [datetime] NOT NULL,
	[participants] [int] NULL,
	[center] [varchar](100) NULL,
	[comments] [varchar](max) NULL,
 CONSTRAINT [PK_UGC_Pool_Names] PRIMARY KEY CLUSTERED 
(
	[league_name] ASC,
	[season_key] ASC,
	[guid] ASC,
	[number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

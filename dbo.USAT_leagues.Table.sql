USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_leagues]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_leagues](
	[league_id] [int] NOT NULL,
	[league_link] [varchar](255) NULL,
	[scores_page_sort] [int] NULL,
	[league_display_name] [varchar](255) NULL,
	[cstv_league_name] [varchar](255) NULL,
	[scores_active] [bit] NULL,
	[league_scores_active] [bit] NULL,
	[league_name] [varchar](75) NULL,
 CONSTRAINT [PK_USAT_leagues] PRIMARY KEY CLUSTERED 
(
	[league_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_Post_Seasons]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_Post_Seasons](
	[event_key] [varchar](100) NOT NULL,
	[score] [varchar](100) NOT NULL,
	[schedule] [varchar](100) NOT NULL,
	[suspender] [varchar](100) NOT NULL,
	[dropdown] [varchar](100) NOT NULL,
	[season_key] [int] NULL,
 CONSTRAINT [PK_USAT_Post_Seasons] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

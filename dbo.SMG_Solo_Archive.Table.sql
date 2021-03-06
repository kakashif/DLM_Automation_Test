USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Solo_Archive]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Solo_Archive](
	[league_id] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[platform] [varchar](100) NOT NULL,
	[page] [varchar](100) NOT NULL,
	[archive] [varchar](max) NOT NULL,
 CONSTRAINT [PK__SMG_Solo__955AA11A7A9478A0] PRIMARY KEY CLUSTERED 
(
	[league_id] ASC,
	[season_key] ASC,
	[event_id] ASC,
	[platform] ASC,
	[page] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[events_sub_seasons]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[events_sub_seasons](
	[event_id] [int] NOT NULL,
	[sub_season_id] [int] NOT NULL,
 CONSTRAINT [PK_events_sub_seasons] PRIMARY KEY CLUSTERED 
(
	[event_id] ASC,
	[sub_season_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

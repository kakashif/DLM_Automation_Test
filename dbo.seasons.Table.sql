USE [SportsDB]
GO
/****** Object:  Table [dbo].[seasons]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[seasons](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[season_key] [int] NOT NULL,
	[publisher_id] [int] NOT NULL,
	[league_id] [int] NULL,
	[start_date_time] [datetime] NULL,
	[end_date_time] [datetime] NULL,
 CONSTRAINT [PK__seasons__0425A276] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

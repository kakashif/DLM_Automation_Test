USE [SportsDB]
GO
/****** Object:  Table [dbo].[sub_seasons]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[sub_seasons](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[sub_season_key] [varchar](100) NOT NULL,
	[season_id] [int] NOT NULL,
	[sub_season_type] [varchar](100) NOT NULL,
	[start_date_time] [datetime] NULL,
	[end_date_time] [datetime] NULL,
 CONSTRAINT [PK__sub_seasons__778AC167] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[SMG_Solo_Events]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SMG_Solo_Events](
	[league_key] [varchar](100) NOT NULL,
	[season_key] [int] NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[start_date_time] [datetime] NULL,
	[end_date_time] [datetime] NULL,
	[site_name] [varchar](100) NULL,
	[site_city] [varchar](100) NULL,
	[site_state] [varchar](100) NULL,
	[purse] [varchar](100) NULL,
	[site_count] [int] NULL,
	[site_size] [varchar](100) NULL,
	[site_size_unit] [varchar](100) NULL,
	[event_status] [varchar](100) NULL,
	[event_name] [varchar](200) NULL,
	[site_surface] [varchar](100) NULL,
	[winner] [varchar](100) NULL,
	[tv_coverage] [varchar](100) NULL,
	[pre_event_coverage] [varchar](max) NULL,
	[post_event_coverage] [varchar](max) NULL,
	[date_time] [datetime] NULL,
 CONSTRAINT [PK__SMG_Solo__1EEC7DB86FCC0613] PRIMARY KEY CLUSTERED 
(
	[league_key] ASC,
	[season_key] ASC,
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

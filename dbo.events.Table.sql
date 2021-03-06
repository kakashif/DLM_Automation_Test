USE [SportsDB]
GO
/****** Object:  Table [dbo].[events]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[events](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[event_key] [varchar](100) NOT NULL,
	[publisher_id] [int] NOT NULL,
	[start_date_time] [datetime] NULL,
	[site_id] [int] NULL,
	[site_alignment] [varchar](100) NULL,
	[event_status] [varchar](100) NULL,
	[duration] [varchar](100) NULL,
	[attendance] [varchar](100) NULL,
	[last_update] [datetime] NULL,
	[event_number] [varchar](32) NULL,
	[round_number] [varchar](32) NULL,
	[time_certainty] [varchar](100) NULL,
	[start_date_time_local] [datetime] NULL,
	[broadcast_listing] [varchar](255) NULL,
	[medal_event] [varchar](100) NULL,
	[series_index] [varchar](40) NULL,
 CONSTRAINT [PK__events__0EA330E9] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

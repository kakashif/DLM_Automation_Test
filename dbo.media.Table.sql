USE [SportsDB]
GO
/****** Object:  Table [dbo].[media]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[media](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[object_id] [int] NULL,
	[source_id] [int] NULL,
	[revision_id] [int] NULL,
	[media_type] [varchar](100) NULL,
	[publisher_id] [int] NOT NULL,
	[date_time] [varchar](100) NULL,
	[credit_id] [int] NOT NULL,
	[db_loading_date_time] [datetime] NULL,
	[creation_location_id] [int] NOT NULL,
 CONSTRAINT [PK__media__1367E606] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

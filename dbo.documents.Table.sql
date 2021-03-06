USE [SportsDB]
GO
/****** Object:  Table [dbo].[documents]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[documents](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[doc_id] [varchar](75) NOT NULL,
	[publisher_id] [int] NOT NULL,
	[date_time] [datetime] NULL,
	[title] [varchar](255) NULL,
	[language] [varchar](100) NULL,
	[priority] [varchar](100) NULL,
	[revision_id] [varchar](255) NULL,
	[stats_coverage] [varchar](100) NULL,
	[document_fixture_id] [int] NOT NULL,
	[source_id] [int] NULL,
	[db_loading_date_time] [datetime] NULL,
 CONSTRAINT [PK__documents__09DE7BCC] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

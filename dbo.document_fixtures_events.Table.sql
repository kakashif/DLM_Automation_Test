USE [SportsDB]
GO
/****** Object:  Table [dbo].[document_fixtures_events]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[document_fixtures_events](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[document_fixture_id] [int] NOT NULL,
	[event_id] [int] NOT NULL,
	[latest_document_id] [int] NOT NULL,
	[last_update] [datetime] NULL,
 CONSTRAINT [PK__document_fixture__60A75C0F] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

USE [SportsDB]
GO
/****** Object:  Table [dbo].[latest_revisions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[latest_revisions](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[revision_id] [varchar](255) NULL,
	[latest_document_id] [int] NOT NULL,
 CONSTRAINT [PK__latest_revisions__0B91BA14] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

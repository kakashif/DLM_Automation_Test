USE [SportsDB]
GO
/****** Object:  Table [dbo].[persons_documents]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[persons_documents](
	[person_id] [int] NOT NULL,
	[document_id] [int] NOT NULL,
 CONSTRAINT [PK_PERSONS_DOCUMENTS] PRIMARY KEY NONCLUSTERED 
(
	[person_id] ASC,
	[document_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

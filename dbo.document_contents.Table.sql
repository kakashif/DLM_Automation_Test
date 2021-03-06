USE [SportsDB]
GO
/****** Object:  Table [dbo].[document_contents]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[document_contents](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[document_id] [int] NOT NULL,
	[sportsml] [varchar](200) NULL,
	[abstract] [text] NULL,
	[sportsml_blob] [text] NULL,
	[abstract_blob] [text] NULL,
 CONSTRAINT [PK__document_content__5EBF139D] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

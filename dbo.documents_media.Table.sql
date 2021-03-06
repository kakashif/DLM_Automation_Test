USE [SportsDB]
GO
/****** Object:  Table [dbo].[documents_media]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[documents_media](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[document_id] [int] NOT NULL,
	[media_id] [int] NOT NULL,
	[media_caption_id] [int] NOT NULL,
 CONSTRAINT [PK__documents_media__68487DD7] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

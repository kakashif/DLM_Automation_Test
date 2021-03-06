USE [SportsDB]
GO
/****** Object:  Table [dbo].[media_captions]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[media_captions](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[media_id] [int] NOT NULL,
	[caption_type] [varchar](100) NULL,
	[caption] [varchar](100) NULL,
	[caption_author_id] [int] NOT NULL,
	[language] [varchar](100) NULL,
	[caption_size] [varchar](100) NULL,
 CONSTRAINT [PK__media_captions__66603565] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

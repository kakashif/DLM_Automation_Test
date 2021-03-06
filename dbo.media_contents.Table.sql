USE [SportsDB]
GO
/****** Object:  Table [dbo].[media_contents]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[media_contents](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[media_id] [int] NOT NULL,
	[object] [varchar](100) NULL,
	[format] [varchar](100) NULL,
	[mime_type] [varchar](100) NULL,
	[height] [varchar](100) NULL,
	[width] [varchar](100) NULL,
	[duration] [varchar](100) NULL,
	[file_size] [varchar](100) NULL,
	[resolution] [varchar](100) NULL,
 CONSTRAINT [PK__media_contents__0D7A0286] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

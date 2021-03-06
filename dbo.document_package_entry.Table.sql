USE [SportsDB]
GO
/****** Object:  Table [dbo].[document_package_entry]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[document_package_entry](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[document_package_id] [int] NOT NULL,
	[rank] [varchar](100) NULL,
	[document_id] [int] NOT NULL,
	[headline] [varchar](100) NULL,
	[short_headline] [varchar](100) NULL,
 CONSTRAINT [PK__document_package__6477ECF3] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

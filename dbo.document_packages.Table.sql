USE [SportsDB]
GO
/****** Object:  Table [dbo].[document_packages]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[document_packages](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[package_key] [varchar](100) NULL,
	[package_name] [varchar](100) NULL,
	[date_time] [datetime] NULL,
 CONSTRAINT [PK__document_package__628FA481] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO

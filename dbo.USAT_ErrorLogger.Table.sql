USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_ErrorLogger]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_ErrorLogger](
	[ErrorId] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[ErrorMessage] [varchar](max) NULL,
	[InnerException] [varchar](max) NULL,
	[StackTrace] [text] NULL,
	[LogTime] [datetime] NULL,
	[Machine] [varchar](50) NULL,
	[LogSource] [varchar](50) NULL,
 CONSTRAINT [PK_USAT_ErrorLogger] PRIMARY KEY CLUSTERED 
(
	[ErrorId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
